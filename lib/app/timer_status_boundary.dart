import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/overlay/popup_activity.dart';
import '../common/route_activity.dart';
import '../common/time.dart';
import '../common/overlay/data_card.dart';
import '../common/widgets.dart';
import '../features/focus/focus.dart';
import '../features/focus/focus_models.dart';
import '../features/focus/providers/focus_dial_presentation.dart';
import '../router/router.dart';
import '../theme/ts.dart';
import 'navigation.dart';
import 'status_layout.dart';

class _StatusEntry {
  _StatusEntry(this.session);
  FocusSession session;
  bool completed = false, exiting = false;
  Timer? timeout;
}

/// One application host. Navigator keeps its full viewport; SafeArea consumers
/// receive the measured status inset. Rows alone subscribe to timer seconds.
class TimerStatusBoundary extends ConsumerStatefulWidget {
  const TimerStatusBoundary({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<TimerStatusBoundary> createState() =>
      _TimerStatusBoundaryState();
}

class _TimerStatusBoundaryState extends ConsumerState<TimerStatusBoundary> {
  final _entries = <String, _StatusEntry>{};
  final _height = ValueNotifier<double>(0);
  late final StreamSubscription<FocusCompletion> _events;
  late final AppLifecycleListener _lifecycle;
  bool _queued = false;
  bool _active =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool get _foreground =>
      _active &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  bool get _shown =>
      _foreground &&
      ref.read(popupActivityProvider) == 0 &&
      appRouteActivity.current != null &&
      appRouteActivity.current != AppRoutes.bootstrap;
  TimerMode? get _current =>
      appRouteActivity.current == AppRoutes.home &&
          ref.read(rootTabProvider) == 0
      ? ref.read(focusDataProvider).mode
      : null;
  @override
  void initState() {
    super.initState();
    _events = ref.read(focusCompletionEventsProvider).listen(_completed);
    ref.listenManual(
      focusDataProvider.select(
        (d) => (
          d.mode,
          d.allSessions.values.map((s) => '${s.id}/${s.status}').join('|'),
        ),
      ),
      (_, _) => _schedule(),
    );
    ref.listenManual(rootTabProvider, (_, _) => _schedule());
    ref.listenManual(popupActivityProvider, (_, _) => _schedule());
    appRouteActivity.addListener(_schedule);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _active = state == AppLifecycleState.resumed;
        _schedule();
      },
    );
    _schedule();
  }

  void _completed(FocusCompletion event) {
    final entry = _entries[event.sessionId];
    if (entry == null || entry.exiting || !_shown || _current == event.mode) {
      return;
    }
    entry.session = ref.read(focusDataProvider).sessionFor(event.mode)!;
    entry.completed = true;
    entry.timeout = Timer(const Duration(milliseconds: 980), () {
      if (mounted && identical(_entries[event.sessionId], entry)) {
        setState(() => entry.exiting = true);
      }
    });
    _schedule();
  }

  void _schedule() {
    if (!mounted) return;
    for (final entry in _entries.values.toList()) {
      if (entry.completed && (!_shown || _current == entry.session.mode)) {
        _entries.remove(entry.session.id);
        entry.timeout?.cancel();
      }
    }
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted) return;
      final data = ref.read(focusDataProvider);
      setState(() {
        for (final entry in _entries.values.toList()) {
          if (entry.completed && !_shown) {
            _entries.remove(entry.session.id);
            entry.timeout?.cancel();
            continue;
          }
          final latest = data.sessionFor(entry.session.mode);
          final eligible =
              _current != entry.session.mode && latest?.id == entry.session.id;
          if (entry.completed) {
            if (!_shown || !eligible) {
              entry.exiting = true;
              entry.timeout?.cancel();
            }
          } else if (!eligible || latest?.status == TimerStatus.finished) {
            entry.exiting = true;
          } else {
            entry.session = latest!;
            entry.exiting = false;
          }
        }
        for (final s in data.allSessions.values) {
          if (s.mode != _current && s.status != TimerStatus.finished) {
            _entries.putIfAbsent(s.id, () => _StatusEntry(s));
          }
        }
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _remove(_StatusEntry entry) {
    if (!mounted || !entry.exiting) return;
    setState(() {
      _entries.remove(entry.session.id);
      entry.timeout?.cancel();
    });
  }

  void _open(FocusSession session) {
    if (!_shown) return;
    AppDataCard.closeAll();
    appNavigatorKey.currentState?.popUntil(
      (r) => r.settings.name == AppRoutes.home,
    );
    ref.read(focusActionsProvider).switchMode(session.mode);
    ref.read(rootTabProvider.notifier).set(0);
  }

  @override
  void dispose() {
    unawaited(_events.cancel());
    _lifecycle.dispose();
    appRouteActivity.removeListener(_schedule);
    for (final entry in _entries.values) {
      entry.timeout?.cancel();
    }
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context), media = MediaQuery.of(context);
    final reduced = media.disableAnimations;
    final shown = _shown;
    final entries = _entries.values.toList()
      ..sort((a, b) => a.session.mode.index.compareTo(b.session.mode.index));
    return Stack(
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _height,
          child: widget.child,
          builder: (context, height, child) => MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(top: media.padding.top + height),
            ),
            child: child!,
          ),
        ),
        Positioned(
          top: media.padding.top,
          left: 0,
          right: 0,
          child: _StatusMeasure(
            onSize: (size) {
              if (mounted && _height.value != size.height) {
                _height.value = size.height;
                ref.read(timerStatusInsetProvider.notifier).set(size.height);
              }
            },
            child: TickerMode(
              enabled: _foreground,
              child: IgnorePointer(
                ignoring: !shown,
                child: ExcludeFocus(
                  excluding: !shown,
                  child: ExcludeSemantics(
                    excluding: !shown,
                    child: _StatusResize(
                      reduced: reduced,
                      alignment: Alignment.topCenter,
                      child: AnimatedOpacity(
                        opacity: shown ? 1 : 0,
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        child: Align(
                          heightFactor: shown && entries.isNotEmpty ? 1 : 0,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: ts.spacing.sm,
                              vertical: ts.spacing.xs,
                            ),
                            child: CommonGlassSurface(
                              borderRadius: BorderRadius.circular(ts.radius.md),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final entry in entries)
                                    _TimerStatusRow(
                                      key: ValueKey(entry.session.id),
                                      entry: entry,
                                      open: () => _open(entry.session),
                                      onRemoved: () => _remove(entry),
                                      interactive: () =>
                                          _shown &&
                                          !entry.exiting &&
                                          _current != entry.session.mode,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerStatusRow extends ConsumerStatefulWidget {
  const _TimerStatusRow({
    super.key,
    required this.entry,
    required this.open,
    required this.onRemoved,
    required this.interactive,
  });
  final bool Function() interactive;
  final _StatusEntry entry;
  final VoidCallback open, onRemoved;
  @override
  ConsumerState<_TimerStatusRow> createState() => _TimerStatusRowState();
}

class _TimerStatusRowState extends ConsumerState<_TimerStatusRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 220),
  );
  @override
  void initState() {
    super.initState();
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && widget.entry.exiting) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onRemoved();
        });
      }
    });
  }

  void _sync() {
    final target = widget.entry.exiting ? 0.0 : 1.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = target;
      if (target == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onRemoved();
        });
      }
    } else {
      if (widget.entry.exiting) {
        _animation.reverse();
      } else {
        _animation.forward();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _TimerStatusRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context), entry = widget.entry;
    final presentation = ref.watch(
      focusDialPresentationProvider(entry.session.mode),
    );
    final s = presentation.session?.id == entry.session.id
        ? presentation.session!
        : entry.session;
    final view = presentation.session?.id == s.id
        ? presentation.view
        : FocusData(sessions: {s.mode: s}, mode: s.mode).view;
    final title = s.resting
        ? s.stage == TimerStage.longBreak
              ? '长休'
              : '短休'
        : const ['番茄钟', '正计时', '倒计时'][s.mode.index];
    final completed = entry.completed;
    final time = timerDigits(view.seconds);
    final label = completed
        ? '$title · 已完成 ✓'
        : '$title${s.mode == TimerMode.pomodoro && !s.resting ? ' · 第 ${s.round} 轮' : ''} · ${s.status == TimerStatus.paused
              ? '已暂停'
              : s.mode == TimerMode.stopwatch
              ? '已用'
              : '剩余'} $time';
    return SizeTransition(
      sizeFactor: _animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _animation,
        child: IgnorePointer(
          ignoring: entry.exiting,
          child: ExcludeFocus(
            excluding: entry.exiting,
            child: ExcludeSemantics(
              excluding: entry.exiting,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (widget.interactive()) widget.open();
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ts.spacing.md,
                      vertical: ts.spacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                liveRegion: completed,
                                child: Text(label, style: ts.textStyle.caption),
                              ),
                              SizedBox(height: ts.spacing.xs),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  end: completed ? 1 : s.elapsedMs / s.limitMs,
                                ),
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                builder: (context, value, _) =>
                                    CommonProgress(value: value * 100),
                              ),
                            ],
                          ),
                        ),
                        if (!completed)
                          CommonButton(
                            label: s.status == TimerStatus.paused ? '继续' : '暂停',
                            kind: CommonButtonKind.quiet,
                            onPressed: () {
                              if (!widget.interactive()) return;
                              ref
                                  .read(focusActionsProvider)
                                  .command(
                                    s.mode,
                                    s.id,
                                    s.status == TimerStatus.paused
                                        ? FocusCommand.resume
                                        : FocusCommand.pause,
                                  );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMeasure extends SingleChildRenderObjectWidget {
  const _StatusMeasure({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _StatusMeasureRender(onSize);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _StatusMeasureRender renderObject,
  ) => renderObject.onSize = onSize;
}

class _StatusMeasureRender extends RenderProxyBox {
  _StatusMeasureRender(this.onSize);
  ValueChanged<Size> onSize;
  Size? _previous;
  @override
  void performLayout() {
    super.performLayout();
    if (_previous == size) return;
    _previous = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(measured));
  }
}

class _StatusResize extends StatelessWidget {
  const _StatusResize({
    required this.reduced,
    required this.child,
    this.alignment = Alignment.topCenter,
  });
  final bool reduced;
  final Widget child;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => reduced
      ? child
      : AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: alignment,
          child: child,
        );
}
