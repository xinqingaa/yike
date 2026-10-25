import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/clock.dart';
import '../../common/identity.dart';
import '../../common/overlay/app_pop.dart';
import '../../common/system_surfaces/surface_adapter.dart';
import '../../common/system_surfaces/surface_models.dart';
import '../../common/system_surfaces/surface_preferences.dart';
import '../../features/focus/focus.dart';
import '../../features/local_data/local_data.dart';
import '../../storage/providers.dart';
import '../../theme/ts.dart';
import '../external_targets.dart';
import '../../router/navigator_key.dart';
import 'surface_projection.dart';

class SurfaceStatus {
  const SurfaceStatus({
    this.access = const SurfaceAccess(),
    this.enabled = true,
    this.ready = false,
    this.error,
    this.settingsError,
  });
  final SurfaceAccess access;
  final bool enabled, ready;
  final String? error, settingsError;
}

class SurfaceCoordinator extends Notifier<SurfaceStatus> {
  late SystemSurfaceAdapter _adapter;
  SurfacePreferences? _preferences;
  bool _disposed = false, _initialized = false, _busy = false, _dirty = false;
  bool _resetting = false, _prefsSaved = false;
  Future<void>? _draining;
  int _revision = 0, _generation = 0;
  DateTime? _minute;
  final _intents = <SurfaceIntent>[];
  final _tokens = <String, String>{};
  final _states = <String, String>{};
  @override
  SurfaceStatus build() {
    _adapter = ref.read(systemSurfaceAdapterProvider);
    _revision = ref.read(clockProvider)().microsecondsSinceEpoch;
    _updateTokens(ref.read(localDataProvider));
    ref.onDispose(() {
      _disposed = true;
      _adapter.dispose();
    });
    ref.listen(localDataProvider, (before, after) {
      _updateTokens(after);
      if (before?.readError != after.readError ||
          before?.writeError != after.writeError ||
          before?.data.habits != after.data.habits ||
          before?.data.focus.records != after.data.focus.records ||
          before == null ||
          surfaceSessionIdentity(before.data.focus) !=
              surfaceSessionIdentity(after.data.focus)) {
        reconcile();
      }
      if (_intents.isNotEmpty) _consumeIntents();
    });
    ref.listen(themePackProvider, (_, _) => reconcile());
    ref.listen(themeModeProvider, (_, _) => reconcile());
    ref.listen(clockPulseProvider, (_, now) {
      if (_minute == null ||
          now.year != _minute!.year ||
          now.month != _minute!.month ||
          now.day != _minute!.day ||
          now.hour != _minute!.hour ||
          now.minute != _minute!.minute ||
          now.timeZoneOffset != _minute!.timeZoneOffset) {
        _minute = now;
        reconcile();
      }
    });
    final lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(localDataProvider.notifier).advance(ref.read(clockProvider)());
        unawaited(refresh());
        _consumeIntents();
      },
    );
    ref.onDispose(lifecycle.dispose);
    Future.microtask(_initialize);
    return const SurfaceStatus();
  }

  void _updateTokens(LocalDataState value) {
    final sessions = value.readError == null
        ? value.data.focus.allSessions.values
        : const <Never>[];
    final ids = sessions.map((s) => s.id).toSet();
    _tokens.removeWhere((key, _) => !ids.contains(key));
    _states.removeWhere((key, _) => !ids.contains(key));
    for (final s in sessions) {
      final identity = '${s.stage}/${s.status}';
      if (_states[s.id] != identity) {
        _states[s.id] = identity;
        _tokens[s.id] = ref.read(identityProvider)();
      }
    }
  }

  Future<void> _initialize() async {
    if (_disposed) return;
    _readPreferences();
    try {
      await _adapter.initialize(receive);
      if (_disposed) return;
      _initialized = true;
      await refresh();
      _consumeIntents();
    } catch (_) {
      if (!_disposed) _status(error: '桌面组件准备失败，请重试');
    }
  }

  void _readPreferences() {
    try {
      _preferences ??=
          ref.read(appPrefsProvider).read(surfacePreferences) ??
          SurfacePreferences(ref.read(identityProvider)());
      _savePreferences();
    } catch (_) {
      _prefsSaved = false;
      _status(settingsError: '组件设置无法读取，原数据已保留；请重试或重置本机数据');
    }
  }

  bool _savePreferences() {
    try {
      ref.read(appPrefsProvider).write(surfacePreferences, _preferences!);
      _prefsSaved = true;
      _status();
      return true;
    } catch (_) {
      _prefsSaved = false;
      _status(settingsError: '组件设置尚未保存，请重试');
      return false;
    }
  }

  void _status({String? error, String? settingsError, SurfaceAccess? access}) {
    if (_disposed) return;
    state = SurfaceStatus(
      access: access ?? state.access,
      ready: _initialized,
      enabled: _preferences?.liveEnabled ?? true,
      error: error,
      settingsError:
          settingsError ?? (_prefsSaved ? null : state.settingsError),
    );
  }

  Future<void> refresh() async {
    try {
      final access = await _adapter.access();
      if (!_disposed) {
        _status(access: access);
        reconcile();
      }
    } catch (_) {
      _status(error: '无法读取系统组件状态，请重试');
    }
  }

  Future<void> retry() async {
    _readPreferences();
    _consumeIntents();
    if (!_initialized) {
      await _initialize();
    } else {
      await refresh();
    }
  }

  void setEnabled(bool enabled) {
    if (_preferences == null) return;
    _preferences = SurfacePreferences(
      _preferences!.epoch,
      liveEnabled: enabled,
      consumed: _preferences!.consumed,
    );
    _savePreferences();
    reconcile();
  }

  Future<void> openSettings() async {
    try {
      await _adapter.openSettings();
    } catch (_) {
      _status(error: '无法打开系统设置，请手动打开一刻的系统设置');
    }
  }

  void reconcile() {
    _dirty = true;
    _generation++;
    if (_busy || _disposed || !_initialized || _resetting) return;
    _draining = _drain();
    unawaited(_draining);
  }

  Future<void> _drain() async {
    _busy = true;
    try {
      while (_dirty && !_disposed && !_resetting) {
        _dirty = false;
        final pack = ref.read(themePackProvider);
        String hex(Color color) =>
            color.toARGB32().toRadixString(16).padLeft(8, '0');
        final palette = <String, String>{};
        for (final entry in {'light': pack.light, 'dark': pack.dark}.entries) {
          palette['${entry.key}Accent'] = hex(entry.value.primary);
          palette['${entry.key}Background'] = hex(entry.value.background);
          palette['${entry.key}Foreground'] = hex(entry.value.onBackground);
        }
        final generation = _generation;
        final snapshot = surfaceProjection(
          ref.read(localDataProvider),
          ref.read(clockProvider)(),
          epoch: _preferences?.epoch ?? '',
          revision: ++_revision,
          ready: _prefsSaved,
          liveEnabled: _preferences?.liveEnabled ?? false,
          theme: pack.id,
          appearance: ref.read(themeModeProvider).name,
          palette: palette,
          tokens: _tokens,
        );
        await _adapter.publish(snapshot);
        if (!_disposed && generation == _generation) _status();
      }
    } catch (_) {
      _status(error: '桌面组件或实时活动更新失败，请重试');
    } finally {
      _busy = false;
      if (_dirty && !_disposed && !_resetting) reconcile();
    }
  }

  void receive(String raw) {
    final intent = SurfaceIntent.decode(raw);
    if (intent == null || _disposed) return;
    if (intent.isCommand) {
      _intents.add(intent);
      _consumeIntents();
    }
    ref.read(externalTargetsProvider.notifier).enqueue(intent);
  }

  void _message(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && appNavigatorKey.currentContext != null) {
        AppPop.toast(message);
      }
    });
  }

  bool _consuming = false;
  void _consumeIntents() {
    if (_consuming ||
        _disposed ||
        _resetting ||
        !_prefsSaved ||
        _preferences == null ||
        ref.read(localDataProvider).readError != null) {
      return;
    }
    _consuming = true;
    try {
      while (_intents.isNotEmpty) {
        final intent = _intents.removeAt(0);
        if (intent.epoch != _preferences!.epoch ||
            _preferences!.consumed.contains(intent.commandKey)) {
          continue;
        }
        ref.read(localDataProvider.notifier).advance(ref.read(clockProvider)());
        final mode = TimerMode.values.byName(intent.mode!);
        final s = ref.read(localDataProvider).data.focus.sessionFor(mode);
        if (s == null ||
            s.id != intent.session ||
            s.stage.name != intent.stage ||
            s.status.name != intent.expected ||
            _tokens[s.id] != intent.token) {
          _message('计时状态已更新，请查看当前状态');
          reconcile();
          continue;
        }
        final consumed = [..._preferences!.consumed, intent.commandKey];
        _preferences = SurfacePreferences(
          _preferences!.epoch,
          liveEnabled: _preferences!.liveEnabled,
          consumed: consumed
              .skip(consumed.length > 64 ? consumed.length - 64 : 0)
              .toList(),
        );
        // Reserve receipt before the business write; retry never replays intent.
        if (!_savePreferences()) {
          reconcile();
          break;
        }
        final result = ref
            .read(focusActionsProvider)
            .commandResult(
              mode,
              intent.session!,
              intent.action == 'pause'
                  ? FocusCommand.pause
                  : FocusCommand.resume,
              expectedStage: TimerStage.values.byName(intent.stage!),
              feedback: false,
            );
        if (!result.accepted) _message('计时状态已更新，请查看当前状态');
        reconcile();
      }
    } finally {
      _consuming = false;
    }
  }

  /// Invalidates commands synchronously; native clear waits for in-flight writes.
  bool beginReset() {
    _generation++;
    _resetting = true;
    _intents.clear();
    _tokens.clear();
    _states.clear();
    ref.read(externalTargetsProvider.notifier).clear();
    _preferences = SurfacePreferences(ref.read(identityProvider)());
    final saved = _savePreferences();
    unawaited(_finishReset());
    return saved;
  }

  Future<void> _finishReset() async {
    try {
      await _draining;
      await _adapter.clear();
    } catch (_) {
      _status(error: '旧组件清理失败，请重试');
    } finally {
      _resetting = false;
      reconcile();
    }
  }
}

final surfaceCoordinatorProvider =
    NotifierProvider<SurfaceCoordinator, SurfaceStatus>(
      SurfaceCoordinator.new,
      dependencies: [
        appPrefsProvider,
        localDataProvider,
        systemSurfaceAdapterProvider,
        themePackProvider,
        themeModeProvider,
        focusActionsProvider,
        externalTargetsProvider,
      ],
    );
