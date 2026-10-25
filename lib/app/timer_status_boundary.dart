import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
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
import '../theme/yike_geometry.dart';
import '../theme/yike_motion.dart';
import 'timer_status_progress.dart';
import 'timer_status_state.dart';
import 'navigation.dart';
import 'status_layout.dart';

/// A floating application host. Only other overlays observe its measured height;
/// the navigator and page safe areas keep their original constraints.
class TimerStatusBoundary extends ConsumerStatefulWidget {
  const TimerStatusBoundary({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<TimerStatusBoundary> createState() =>
      _TimerStatusBoundaryState();
}

class _TimerStatusBoundaryState extends ConsumerState<TimerStatusBoundary>
    with SingleTickerProviderStateMixin {
  final _status =
      NotifierProvider.autoDispose<TimerStatusController, TimerStatusState>(
        TimerStatusController.new,
      );
  TimerStatusController get _controller => ref.read(_status.notifier);
  Map<String, TimerStatusEntry> get _entries => ref.read(_status).entries;
  bool get _collapsed => ref.read(_status).collapsed;
  bool get _dragging => ref.read(_status).dragging;
  final _invalidCompletions = <String>{};
  final _contentHeight = ValueNotifier<double>(0);
  late final AnimationController _fold = AnimationController(
    vsync: this,
    duration: YikeMotion.statusFold,
  );
  void _setCollapsed(bool value) {
    _controller.collapse(value);
    _schedule();
    final target = value ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fold.value = target;
    } else {
      _fold.animateTo(target, curve: Curves.easeOutCubic);
    }
  }

  late final StreamSubscription<FocusCompletion> _events;
  late final AppLifecycleListener _lifecycle;
  bool _queued = false;
  bool get _foreground =>
      ref.read(_status).foreground &&
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
        _controller.foreground(state == AppLifecycleState.resumed);
        _fold.stop();
        if (state == AppLifecycleState.resumed) {
          _fold.value = _collapsed ? 1 : 0;
        }
        _schedule();
      },
    );
    _schedule();
  }

  void _completed(FocusCompletion event) {
    final entry = _entries[event.sessionId];
    if (entry == null ||
        entry.exiting ||
        !_shown ||
        _collapsed ||
        _dragging ||
        _fold.value > .01 ||
        _current == event.mode) {
      return;
    }
    _controller.complete(ref.read(focusDataProvider).sessionFor(event.mode)!);
    _schedule();
  }

  void _schedule() {
    if (!mounted) return;
    for (final entry in _entries.values.toList()) {
      if (entry.completed &&
          (!_shown ||
              _collapsed ||
              _dragging ||
              _current == entry.session.mode)) {
        _invalidCompletions.add(entry.session.id);
      }
    }
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted) return;
      _controller.reconcile(
        ref.read(focusDataProvider),
        shown: _shown,
        currentMode: _current,
        folded: _collapsed || _dragging || _fold.value > .01,
        invalidCompletions: Set.of(_invalidCompletions),
      );
      _invalidCompletions.clear();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _remove(TimerStatusEntry entry) {
    if (mounted) _controller.remove(entry.session.id);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && !_dragging) {
      _fold.stop();
      _fold.value = _collapsed ? 1 : 0;
    }
  }

  @override
  void dispose() {
    unawaited(_events.cancel());
    _lifecycle.dispose();
    appRouteActivity.removeListener(_schedule);
    _fold.dispose();
    _contentHeight.dispose();
    super.dispose();
  }

  Widget _expanded(List<TimerStatusEntry> entries, bool shown) {
    final ts = TS.of(context);
    return Material(
      color: Colors.transparent,
      child: Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: '收起计时'): () => _setCollapsed(true),
        },
        child: _StatusMeasure(
          onSize: (size) {
            if (mounted) _contentHeight.value = size.height;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: ts.spacing.xs,
                    bottom: ts.spacing.xxs,
                  ),
                  child: Center(
                    child: Container(
                      key: const ValueKey('timer-status-drag-handle'),
                      width: ts.spacing.xl,
                      height: ts.border.widthHairline * 3,
                      decoration: BoxDecoration(
                        color: ts.colors.onSurfaceMuted.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(ts.radius.full),
                      ),
                    ),
                  ),
                ),
              ),
              for (final entry in entries)
                _TimerStatusRow(
                  key: ValueKey(entry.session.id),
                  entry: entry,
                  open: () => _open(entry.session),
                  onRemoved: () => _remove(entry),
                  motionActive:
                      shown && !_collapsed && !_dragging && !entry.exiting,
                  interactive: () =>
                      _shown &&
                      !_collapsed &&
                      !_dragging &&
                      _fold.value < .01 &&
                      !entry.exiting &&
                      _current != entry.session.mode,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _capsule(int count) {
    final ts = TS.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('timer-status-capsule'),
        onTap: () => _setCollapsed(false),
        child: Semantics(
          button: true,
          label: '展开计时，$count 项',
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CommonIcon(
                name: CommonIconName.clock,
                dimension: ts.sizing.iconSm,
                tone: CommonIconTone.primary,
              ),
              SizedBox(width: ts.spacing.sm),
              Text('$count', style: ts.textStyle.numericContent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surface(
    double width,
    double pillWidth,
    List<TimerStatusEntry> entries,
    bool shown,
    bool reduced,
  ) {
    final ts = TS.of(context);
    final expanded = TickerMode(
      enabled: _foreground,
      child: _expanded(entries, shown),
    );
    final capsule = _capsule(entries.where((e) => !e.exiting).length);
    return ValueListenableBuilder<double>(
      valueListenable: _contentHeight,
      builder: (context, measuredHeight, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: measuredHeight),
        duration: reduced ? Duration.zero : YikeMotion.statusResize,
        builder: (context, height, _) => AnimatedBuilder(
          animation: _fold,
          builder: (context, _) {
            final t = _fold.value;
            return CommonGlassSurface(
              borderRadius: BorderRadius.circular(
                lerpDouble(ts.radius.md, ts.radius.full, t)!,
              ),
              child: ClipRect(
                child: SizedBox(
                  width: lerpDouble(width, pillWidth, t),
                  height: lerpDouble(
                    height,
                    math.max(
                      ts.sizing.touch,
                      MediaQuery.textScalerOf(
                                context,
                              ).scale(ts.textStyle.numericContent.fontSize!) *
                              (ts.textStyle.numericContent.height ?? 1.5) +
                          ts.spacing.xs * 2,
                    ),
                    t,
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        width: width,
                        child: IgnorePointer(
                          ignoring: _collapsed || _dragging || t > .01,
                          child: ExcludeFocus(
                            excluding: _collapsed || _dragging,
                            child: ExcludeSemantics(
                              excluding: _collapsed || _dragging,
                              child: Opacity(
                                opacity: (1 - t * 2).clamp(0.0, 1.0),
                                child: expanded,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !_collapsed || _dragging,
                          child: ExcludeFocus(
                            excluding: !_collapsed || _dragging,
                            child: ExcludeSemantics(
                              excluding: !_collapsed || _dragging,
                              child: Opacity(
                                opacity: ((t - .5) * 2).clamp(0.0, 1.0),
                                child: capsule,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_status);
    final ts = TS.of(context), media = MediaQuery.of(context);
    final reduced = media.disableAnimations, shown = _shown;
    final entries = _entries.values.toList()
      ..sort((a, b) => a.session.mode.index.compareTo(b.session.mode.index));
    final visible =
        shown &&
        entries.isNotEmpty &&
        (!_collapsed || entries.any((entry) => !entry.exiting));
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: media.padding.top,
          left: ts.spacing.sm,
          right: ts.spacing.sm,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: YikeGeometry.statusMaximumWidth,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final pillWidth =
                      (YikeGeometry.statusPillWidth +
                              media.textScaler.scale(
                                ts.textStyle.numericContent.fontSize!,
                              ) -
                              ts.textStyle.numericContent.fontSize!)
                          .clamp(0.0, width);
                  return _StatusMeasure(
                    onSize: (size) {
                      if (mounted) {
                        ref
                            .read(timerStatusInsetProvider.notifier)
                            .set(size.height);
                      }
                    },
                    child: IgnorePointer(
                      ignoring: !visible,
                      child: ExcludeFocus(
                        excluding: !visible,
                        child: ExcludeSemantics(
                          excluding: !visible,
                          child: AnimatedOpacity(
                            opacity: visible ? 1 : 0,
                            duration: reduced
                                ? Duration.zero
                                : YikeMotion.statusFade,
                            child: Align(
                              heightFactor: visible ? 1 : 0,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: ts.spacing.xs,
                                ),
                                child: GestureDetector(
                                  key: const ValueKey('timer-status-surface'),
                                  onVerticalDragStart: (_) {
                                    _fold.stop();
                                    _controller.drag(true);
                                    _schedule();
                                  },
                                  onVerticalDragUpdate: (d) {
                                    _fold.value =
                                        (_fold.value -
                                                d.delta.dy /
                                                    YikeMotion.statusDragTravel)
                                            .clamp(0.0, 1.0);
                                  },
                                  onVerticalDragCancel: () =>
                                      _setCollapsed(_collapsed),
                                  onVerticalDragEnd: (d) {
                                    final velocity = d.primaryVelocity ?? 0;
                                    _setCollapsed(
                                      velocity < -250 ||
                                          (velocity <= 250 &&
                                              _fold.value >= .5),
                                    );
                                  },
                                  child: _surface(
                                    width,
                                    pillWidth,
                                    entries,
                                    shown,
                                    reduced,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
    required this.motionActive,
  });
  final bool motionActive;
  final bool Function() interactive;
  final TimerStatusEntry entry;
  final VoidCallback open, onRemoved;
  @override
  ConsumerState<_TimerStatusRow> createState() => _TimerStatusRowState();
}

class _TimerStatusRowState extends ConsumerState<_TimerStatusRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: YikeMotion.statusEnter,
    reverseDuration: YikeMotion.statusExit,
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
    final paused = s.status == TimerStatus.paused;
    final detail = completed
        ? s.resting
              ? '休息结束'
              : '已完成'
        : s.mode == TimerMode.pomodoro && !s.resting
        ? '第 ${s.round} 轮'
        : null;
    final label =
        '$title，${completed
            ? '已完成，'
            : paused
            ? '已暂停，'
            : ''}${s.mode == TimerMode.stopwatch ? '已专注' : '剩余'} $time';
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
                      horizontal: ts.spacing.smPlus,
                      vertical: ts.spacing.xxs,
                    ),
                    child: Semantics(
                      key: ValueKey('timer-status-${s.mode.name}'),
                      label: label,
                      liveRegion: completed,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ExcludeSemantics(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            text: title,
                                            children: [
                                              if (detail != null)
                                                TextSpan(
                                                  text: ' · $detail',
                                                  style: ts.textStyle.micro,
                                                ),
                                            ],
                                          ),
                                          style: ts.textStyle.bodySm,
                                        ),
                                      ),
                                      SizedBox(width: ts.spacing.sm),
                                      Text(
                                        time,
                                        style: ts.textStyle.numericContent,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: ts.spacing.sm),
                                ExcludeSemantics(
                                  child: TimerStatusProgress(
                                    session: s,
                                    active: widget.motionActive,
                                    completed: completed,
                                    height: ts.border.widthHairline * 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: ts.spacing.xs),
                          if (completed)
                            SizedBox(
                              width: ts.sizing.touch,
                              height: ts.sizing.touch,
                              child: CommonIcon(
                                name: CommonIconName.check,
                                tone: CommonIconTone.primary,
                                dimension: ts.sizing.iconSm,
                              ),
                            )
                          else
                            CommonIconButton(
                              icon: paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              label: '${paused ? '继续' : '暂停'}$title',
                              size: CommonControlSize.sm,
                              variant: CommonIconButtonVariant.text,
                              tone: CommonIconButtonTone.primary,
                              onPressed: () {
                                if (!widget.interactive()) return;
                                ref
                                    .read(focusActionsProvider)
                                    .command(
                                      s.mode,
                                      s.id,
                                      paused
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
