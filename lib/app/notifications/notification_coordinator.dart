import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/clock.dart';
import '../../common/notifications/notification_adapter.dart';
import '../../common/notifications/notification_models.dart';
import '../../common/notifications/notification_metadata.dart';
import '../../common/overlay/app_pop.dart';
import '../../common/overlay/popup_activity.dart';
import '../../common/time.dart';
import '../../features/local_data/local_data.dart';
import '../../features/focus/focus.dart';
import '../../storage/providers.dart';
import '../../theme/ts.dart';
import '../../router/router.dart';
import '../navigation.dart';
import '../../common/route_activity.dart';
import 'notification_plan.dart';

class NotificationStatus {
  const NotificationStatus({
    this.access = const NotificationAccess(),
    this.ready = false,
    this.error,
    this.coverage = const {},
    this.queued,
  });
  final NotificationAccess access;
  final bool ready;
  final String? error;
  final Map<String, List<String>> coverage;
  final NotificationTarget? queued;
}

class NotificationCoordinator extends Notifier<NotificationStatus> {
  late NotificationAdapter _adapter;
  late NotificationMetadata _metadata;
  final _fingerprints = <int, String>{};
  bool _disposed = false, _busy = false, _dirty = false, _initialized = false;
  bool _metadataReady = false, _resetting = false;
  Future<void>? _draining;
  bool _needsClear = false, _navigationScheduled = false;
  Map<String, List<String>> _coverageProgress = {};
  int _generation = 0;
  DateTime? _sampled;
  bool _active =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  AppLifecycleListener? _lifecycle;
  bool get _foreground =>
      _active &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  @override
  NotificationStatus build() {
    _adapter = ref.read(notificationAdapterProvider);
    ref.onDispose(() {
      _disposed = true;
      _lifecycle?.dispose();
      appRouteActivity.removeListener(navigate);
    });
    ref.listen(localDataProvider, (before, after) {
      // Pulses alone change elapsed time, not fixed finish anchors or the desired set.
      if (before?.data.habits != after.data.habits ||
          before?.data.backgroundReminders != after.data.backgroundReminders ||
          before?.data.focus.preferences != after.data.focus.preferences ||
          before?.data.focus.allSessions.values
                  .map((s) => '${s.id}/${s.status}')
                  .join('|') !=
              after.data.focus.allSessions.values
                  .map((s) => '${s.id}/${s.status}')
                  .join('|')) {
        reconcile();
      }
    });
    ref.listen(themePackProvider, (_, _) => reconcile());
    ref.listen(clockPulseProvider, (_, now) => sample(now));
    ref.listen(popupActivityProvider, (_, after) {
      if (after == 0) navigate();
    });
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) {
        _active = s == AppLifecycleState.resumed;
        _sampled = null;
        if (s == AppLifecycleState.resumed) {
          // Catch up facts before making any foreground baseline or new schedule.
          ref
              .read(localDataProvider.notifier)
              .advance(ref.read(clockProvider)());
          unawaited(refresh());
          navigate();
        }
      },
    );
    appRouteActivity.addListener(navigate);
    Future.microtask(_initialize);
    return const NotificationStatus();
  }

  Future<void> _initialize() async {
    try {
      _metadata =
          ref.read(appPrefsProvider).read(notificationMetadataPrefs) ??
          NotificationMetadata();
      _metadataReady = true;
      await _adapter.initialize(enqueue);
      if (_disposed) return;
      _initialized = true;
      _consumePast(ref.read(clockProvider)());
      await refresh();
    } catch (_) {
      _error('通知准备失败，前台计时与习惯提示仍可使用；请重试');
    }
  }

  void _error(String message) {
    if (!_disposed) {
      state = NotificationStatus(
        access: state.access,
        ready: _initialized,
        error: message,
        coverage: _coverageProgress,
        queued: state.queued,
      );
    }
  }

  void _save() =>
      ref.read(appPrefsProvider).write(notificationMetadataPrefs, _metadata);
  void _consumePast(DateTime now) {
    for (final e in _metadata.scheduledAt.entries.toList()) {
      if (e.value <= now.millisecondsSinceEpoch) {
        if (e.key.startsWith('habit/')) _metadata.consumed.add(e.key);
        _metadata.scheduledAt.remove(e.key);
      }
    }
    _save();
  }

  Future<void> refresh({bool request = false}) async {
    if (!_initialized) {
      if (!_busy) await _initialize();
      return;
    }
    try {
      final access = await _adapter.access(request: request);
      await _adapter.refreshTimezone();
      if (_disposed) return;
      state = NotificationStatus(
        access: access,
        ready: true,
        coverage: state.coverage,
        queued: state.queued,
      );
      reconcile();
    } catch (_) {
      _error('通知权限或时区读取失败，请重试');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final controller = ref.read(localDataProvider.notifier);
    controller.commit(
      ref.read(localDataProvider).data.copyWith(backgroundReminders: enabled),
    );
    if (enabled) {
      await refresh(request: true);
    } else {
      reconcile();
    }
  }

  Future<void> exactPermission() async {
    try {
      await _adapter.requestExact();
      await refresh();
    } catch (_) {
      _error('无法打开精确提醒授权，请重试或前往系统设置');
    }
  }

  Future<void> openSettings() async {
    try {
      await _adapter.openSettings();
    } catch (_) {
      _error('无法打开通知设置，请从系统设置中查看');
    }
  }

  void reconcile() {
    _generation++;
    _dirty = true;
    if (!_initialized || _busy || _disposed || _resetting) return;
    _draining = _drain();
    unawaited(_draining);
  }

  Future<void> _drain() async {
    _busy = true;
    try {
      while (_dirty && !_disposed && !_resetting) {
        _dirty = false;
        if (_needsClear) {
          await _adapter.clear();
          _metadata = NotificationMetadata();
          _fingerprints.clear();
          _save();
          _needsClear = false;
        }
        sample(ref.read(clockProvider)());
        final generation = _generation;
        _coverageProgress = {};
        final snapshot = ref.read(localDataProvider);
        if (snapshot.readError != null) return;
        final now = ref.read(clockProvider)();
        _consumePast(now);
        final desired = state.access.allowed
            ? notificationPlan(
                snapshot.data,
                now,
                _metadata,
                ref.read(themePackProvider).id,
              )
            : <NotificationRequest>[];
        _save(); // Persist allocated IDs before any platform call can succeed.
        final pending = await _adapter.pending();
        if (_disposed) return;
        if (generation != _generation) continue;
        final wanted = desired.map((r) => r.id).toSet();
        for (final id in pending.difference(wanted)) {
          await _adapter.cancelPending(id);
          _fingerprints.remove(id);
          _metadata.scheduledAt.removeWhere(
            (key, _) => _metadata.ids[key] == id,
          );
        }
        final habitIds = snapshot.data.habits.map((h) => h.id).toSet();
        for (final e in _metadata.ids.entries.toList()) {
          final target = e.key.split('/');
          if (target.first == 'habit' && !habitIds.contains(target[1])) {
            await _adapter.removeDelivered(e.value);
            _metadata.ids.remove(e.key);
            _metadata.consumed.remove(e.key);
          }
        }
        final coverage = _coverageProgress;
        for (final r in desired) {
          if (_disposed || generation != _generation) break;
          if (!r.at.isAfter(ref.read(clockProvider)())) continue;
          if (!pending.contains(r.id) ||
              _fingerprints[r.id] != '${r.fingerprint}|${state.access.exact}') {
            // Reserve the deadline before the native side effect. A crash after
            // scheduling but before its receipt cannot create a second daily chance.
            _metadata.scheduledAt[r.target.key] = r.at.millisecondsSinceEpoch;
            _save();
            await _adapter.schedule(r, exact: state.access.exact);
          }
          _fingerprints[r.id] = '${r.fingerprint}|${state.access.exact}';
          _metadata.scheduledAt[r.target.key] = r.at.millisecondsSinceEpoch;
          if (!r.timer) {
            coverage
                .putIfAbsent(r.target.identity, () => [])
                .add(r.target.date!);
          }
        }
        _save();
        if (!_disposed && generation == _generation) {
          state = NotificationStatus(
            access: state.access,
            ready: true,
            coverage: coverage,
            queued: state.queued,
          );
        }
      }
    } catch (_) {
      _error('部分通知尚未预约，请重试；已保存的计时与打卡不受影响');
    } finally {
      _busy = false;
      if (_dirty && !_disposed && !_resetting) reconcile();
    }
  }

  void sample(DateTime now) {
    final previous = _sampled;
    _sampled = now;
    if (!_metadataReady || previous == null || !_foreground) return;
    final snapshot = ref.read(localDataProvider);
    if (snapshot.readError != null) return;
    final date = dayId(now);
    final due = snapshot.data.habits.where((h) {
      final at = DateTime(
        now.year,
        now.month,
        now.day,
        h.reminderMinutes ~/ 60,
        h.reminderMinutes % 60,
      );
      final target = NotificationTarget.habit(h.id, date);
      return h.reminder &&
          !h.archived &&
          h.created.compareTo(date) <= 0 &&
          !h.dates.contains(date) &&
          !previous.isAfter(at) &&
          now.isAfter(at.subtract(const Duration(microseconds: 1))) &&
          !_metadata.consumed.contains(target.key);
    }).toList();
    if (due.isEmpty) {
      if (dayId(previous) != date) reconcile();
      return;
    }
    for (final h in due) {
      _metadata.consumed.add(NotificationTarget.habit(h.id, date).key);
    }
    try {
      _save();
    } catch (_) {
      _error('提醒去重信息尚未保存，请重试');
      return;
    }
    if (ref.read(popupActivityProvider) == 0 &&
        appRouteActivity.current != AppRoutes.bootstrap) {
      final ids = due.map((h) => h.id).toList();
      final message = due.length == 1
          ? '${due.first.name} · 今日尚未完成'
          : '${due.take(2).map((h) => h.name).join('、')}${due.length > 2 ? '等' : ''} ${due.length} 个习惯待完成';
      AppPop.toast(
        message,
        actionLabel: '查看',
        replacementKey: 'habit-reminder',
        duration: const Duration(seconds: 3),
        onAction: () => enqueueHabits(ids, date),
      );
    }
    reconcile();
  }

  void enqueueHabits(List<String> ids, String date) {
    ref.read(habitReminderTargetsProvider.notifier).set(ids.toSet());
    enqueue(NotificationTarget.habit(ids.first, date));
  }

  void enqueue(NotificationTarget target) {
    if (_disposed) return;
    state = NotificationStatus(
      access: state.access,
      ready: state.ready,
      error: state.error,
      coverage: state.coverage,
      queued: target,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => navigate());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void navigate() {
    if (_disposed || _navigationScheduled) return;
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      if (!_disposed) _navigate();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _navigate() {
    if (_disposed ||
        state.queued == null ||
        !_foreground ||
        ref.read(popupActivityProvider) > 0 ||
        ref.read(localDataProvider).readError != null ||
        appRouteActivity.current == null ||
        appRouteActivity.current == AppRoutes.bootstrap) {
      return;
    }
    final target = state.queued!;
    state = NotificationStatus(
      access: state.access,
      ready: state.ready,
      error: state.error,
      coverage: state.coverage,
    );
    AppDataCard.closeAll();
    appNavigatorKey.currentState?.popUntil(
      (r) => r.settings.name == AppRoutes.home,
    );
    if (target.kind == 'timer') {
      ref
          .read(focusActionsProvider)
          .switchMode(TimerMode.values.byName(target.identity));
      ref.read(rootTabProvider.notifier).set(0);
    } else {
      ref.read(rootTabProvider.notifier).set(1);
      final exists = ref
          .read(localDataProvider)
          .data
          .habits
          .any((h) => h.id == target.identity && !h.archived);
      if (exists) {
        final ids = ref.read(habitReminderTargetsProvider);
        ref.read(habitReminderTargetsProvider.notifier).set({
          ...ids,
          target.identity,
        });
      } else {
        AppPop.toast('该习惯已删除或归档');
      }
    }
  }

  Future<void> reset() async {
    _needsClear = true;
    _resetting = true;
    _generation++;
    try {
      await _draining;
      if (_initialized) {
        await _adapter.clear();
        _needsClear = false;
      }
      _metadata = NotificationMetadata();
      _metadataReady = true;
      _fingerprints.clear();
      _save();
    } catch (_) {
      _error('通知清理未完成，请重试');
    } finally {
      _resetting = false;
      reconcile();
    }
  }
}

final notificationCoordinatorProvider =
    NotifierProvider<NotificationCoordinator, NotificationStatus>(
      NotificationCoordinator.new,
      dependencies: [
        localDataProvider,
        appPrefsProvider,
        notificationAdapterProvider,
        themePackProvider,
        focusActionsProvider,
      ],
    );
