import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/overlay/popup_activity.dart';
import '../../../common/feedback/feedback_service.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../../../theme/yike_geometry.dart';
import '../models/focus_view.dart';
import '../providers/focus_presentation.dart';
import '../providers/focus_dial_presentation.dart';

class LapPanel extends ConsumerStatefulWidget {
  const LapPanel({
    super.key,
    required this.sessionId,
    required this.close,
    required this.onFinish,
    required this.onCancel,
  });
  final String sessionId;
  final VoidCallback close;
  final Future<void> Function() onFinish, onCancel;
  @override
  ConsumerState<LapPanel> createState() => _LapPanelState();
}

class _LapPanelState extends ConsumerState<LapPanel>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _stack = GlobalKey(), _pause = GlobalKey(), _tag = GlobalKey();
  final _flights = <_LapFlight>[];
  late final AnimationController _bounce;
  int _unseen = 0;
  bool _closing = false;
  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(vsync: this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final flight in _flights) {
      flight.controller.dispose();
    }
    _bounce.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopFlights();
  }

  void _stopFlights() {
    _bounce.reset();
    if (_flights.isEmpty) return;
    final old = List<_LapFlight>.of(_flights);
    setState(_flights.clear);
    for (final flight in old) {
      flight.controller.dispose();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) &&
        (_flights.isNotEmpty || _bounce.isAnimating)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _stopFlights();
      });
    }
  }

  void _closeIfGone() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.close();
    });
  }

  void _lap() {
    final actions = ref.read(focusActionsProvider);
    final before = ref.read(focusDataProvider).sessionFor(TimerMode.stopwatch);
    if (before?.id != widget.sessionId) return;
    actions.command(TimerMode.stopwatch, widget.sessionId, FocusCommand.lap);
    final after = ref.read(focusDataProvider).sessionFor(TimerMode.stopwatch);
    if (after?.id != widget.sessionId ||
        after!.laps.length <= before!.laps.length) {
      return;
    }
    if (_scroll.hasClients && _scroll.offset > TS.of(context).sizing.touch) {
      final delta = _scroll.position.maxScrollExtent - _scroll.offset;
      setState(() => _unseen++);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(
            (_scroll.position.maxScrollExtent - delta).clamp(
              0,
              _scroll.position.maxScrollExtent,
            ),
          );
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fly();
    });
  }

  double _rowHeight(BuildContext context) {
    final ts = TS.of(context);
    return math.max(
      ts.sizing.controlLg,
      MediaQuery.textScalerOf(
                context,
              ).scale(ts.textStyle.numericContent.fontSize!) *
              (ts.textStyle.numericContent.height ?? 1) +
          ts.spacing.md * 2,
    );
  }

  void _fly() {
    if (MediaQuery.disableAnimationsOf(context) ||
        !ref.read(feedbackServiceProvider).foreground ||
        _flights.length >= 3 ||
        ref.read(popupActivityProvider) > 1) {
      return;
    }
    final box = _stack.currentContext?.findRenderObject(),
        source = _pause.currentContext?.findRenderObject(),
        target = _tag.currentContext?.findRenderObject();
    if (box is! RenderBox || source is! RenderBox || target is! RenderBox) {
      return;
    }
    final start = box.globalToLocal(
      source.localToGlobal(source.size.center(Offset.zero)),
    );
    final end = box.globalToLocal(
      target.localToGlobal(target.size.center(Offset.zero)),
    );
    final controller = AnimationController(
      vsync: this,
      duration: TS.of(context).motion.durationSlow,
    );
    final flight = _LapFlight(controller, start, end);
    setState(() => _flights.add(flight));
    controller.forward().whenCompleteOrCancel(() {
      if (!mounted || !_flights.contains(flight)) return;
      setState(() => _flights.remove(flight));
      controller.dispose();
      _bounce.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    _bounce.duration = ts.motion.durationFast;
    final alive = ref.watch(
      focusDataProvider.select(
        (d) => d.sessionFor(TimerMode.stopwatch)?.id == widget.sessionId,
      ),
    );
    final value = ref
        .watch(focusDialPresentationProvider(TimerMode.stopwatch))
        .view;
    if (!alive) {
      _closeIfGone();
      return const SizedBox.shrink();
    }
    ref.listen(popupActivityProvider, (_, depth) {
      if (depth > 1) _stopFlights();
    });
    final laps = value.laps;
    final durations = [
      for (var i = 0; i < laps.length; i++)
        laps[i] - (i == 0 ? 0 : laps[i - 1]),
    ];
    final fastest = durations.isEmpty ? 0 : durations.reduce(math.min),
        slowest = durations.isEmpty ? 0 : durations.reduce(math.max);
    final current = value.seconds - (laps.lastOrNull ?? 0);
    final rowHeight = _rowHeight(context);
    return SafeArea(
      left: false,
      child: Stack(
        key: _stack,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.all(ts.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '计圈 · 已记 ${laps.length} 圈',
                        style: ts.textStyle.subtitle,
                      ),
                    ),
                    CommonIconButton(
                      name: CommonIconName.x,
                      label: '关闭计圈',
                      material: CommonSurfaceMaterial.glass,
                      variant: CommonIconButtonVariant.text,
                      onPressed: widget.close,
                    ),
                  ],
                ),
                SizedBox(height: ts.spacing.md),
                Row(
                  children: [
                    Expanded(child: Text('总计时', style: ts.textStyle.caption)),
                    if (laps.isNotEmpty)
                      ExcludeSemantics(
                        child: AnimatedBuilder(
                          animation: _bounce,
                          builder: (context, child) => Transform.scale(
                            scale:
                                1 +
                                YikeGeometry.lapBounce *
                                    math.sin(_bounce.value * math.pi),
                            child: child,
                          ),
                          child: SizedBox(
                            key: _tag,
                            child: CommonGlassSurface(
                              borderRadius: BorderRadius.circular(
                                ts.radius.full,
                              ),
                              tint: ts.colors.primarySoft,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: ts.spacing.md,
                                  vertical: ts.spacing.sm,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CustomPaint(
                                      size: Size.square(ts.spacing.smPlus),
                                      painter: _LapMarkPainter(ts),
                                    ),
                                    SizedBox(width: ts.spacing.sm),
                                    Text(
                                      '${laps.length} 圈',
                                      style: ts.textStyle.captionStrong,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        timerDigits(value.seconds),
                        style: ts.textStyle.numericTitle,
                      ),
                    ),
                    SizedBox(width: ts.spacing.sm),
                    Text(
                      value.finished
                          ? '已完成'
                          : value.paused
                          ? '已暂停'
                          : '计时中',
                      style: ts.textStyle.caption,
                    ),
                  ],
                ),
                SizedBox(height: ts.spacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value.finished
                            ? '末段 · 未计圈'
                            : '当前第 ${laps.length + 1} 圈',
                        style: ts.textStyle.caption,
                      ),
                    ),
                    Text(
                      timerDigits(current),
                      style: ts.textStyle.numericContent,
                    ),
                  ],
                ),
                if (durations.length >= 2) ...[
                  SizedBox(height: ts.spacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stat('最快', fastest),
                      _stat('平均', (laps.last / laps.length).floor()),
                      _stat('最慢', slowest),
                    ],
                  ),
                ],
                SizedBox(height: ts.spacing.md),
                const CommonDivider(),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: ts.spacing.sm),
                  child: _columns(
                    Text('圈次', style: ts.textStyle.caption),
                    Text('单圈', style: ts.textStyle.caption),
                    Text('累计', style: ts.textStyle.caption),
                  ),
                ),
                if (_unseen > 0)
                  CommonButton(
                    label: '新增 $_unseen 圈，回到最新',
                    kind: CommonButtonKind.quiet,
                    onPressed: () {
                      _scroll.jumpTo(0);
                      setState(() => _unseen = 0);
                    },
                  ),
                Expanded(
                  child: laps.isEmpty
                      ? Center(
                          child: Text('还没有计圈', style: ts.textStyle.caption),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (_unseen > 0 && n.metrics.pixels <= 0) {
                              setState(() => _unseen = 0);
                            }
                            return false;
                          },
                          child: ListView.builder(
                            key: const ValueKey('lap-panel-list'),
                            controller: _scroll,
                            itemExtent: rowHeight,
                            itemCount: laps.length,
                            itemBuilder: (context, index) {
                              final i = laps.length - index - 1;
                              final labels = durations.length < 2
                                  ? ''
                                  : '${durations[i] == fastest ? ' 最快' : ''}${durations[i] == slowest ? ' 最慢' : ''}';
                              return Semantics(
                                label:
                                    '第 ${i + 1} 圈，单圈 ${durationLabel(durations[i])}，累计 ${durationLabel(laps[i])}$labels',
                                excludeSemantics: true,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: _columns(
                                    Text(
                                      '${i + 1}$labels',
                                      key: ValueKey('lap-label-${i + 1}'),
                                      style: ts.textStyle.caption.copyWith(
                                        color: labels.isEmpty
                                            ? ts.colors.onSurfaceMuted
                                            : ts.colors.primary,
                                      ),
                                    ),
                                    Text(
                                      timerDigits(durations[i]),
                                      key: ValueKey('lap-duration-${i + 1}'),
                                      style: ts.textStyle.numericContent,
                                    ),
                                    Text(
                                      timerDigits(laps[i]),
                                      key: ValueKey('lap-total-${i + 1}'),
                                      style: ts.textStyle.numericContent,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                SizedBox(height: ts.spacing.sm),
                const CommonDivider(),
                SizedBox(height: ts.spacing.md),
                if (value.finished)
                  CommonButton(
                    label: '完成',
                    kind: CommonButtonKind.accent,
                    size: CommonControlSize.lg,
                    onPressed: () async {
                      await widget.onFinish();
                    },
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: CommonButton(
                          key: const ValueKey('lap-panel-lap'),
                          label: '计圈',
                          kind: CommonButtonKind.secondary,
                          size: CommonControlSize.lg,
                          onPressed: value.paused ? null : _lap,
                        ),
                      ),
                      SizedBox(width: ts.spacing.sm),
                      Expanded(
                        child: KeyedSubtree(
                          key: _pause,
                          child: CommonButton(
                            key: const ValueKey('lap-panel-pause'),
                            label: value.paused ? '继续' : '暂停',
                            kind: CommonButtonKind.accent,
                            size: CommonControlSize.lg,
                            onPressed: () => ref
                                .read(focusActionsProvider)
                                .command(
                                  TimerMode.stopwatch,
                                  widget.sessionId,
                                  value.paused
                                      ? FocusCommand.resume
                                      : FocusCommand.pause,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: ts.spacing.sm,
                    children: [
                      CommonButton(
                        label: '结束并记录',
                        kind: CommonButtonKind.quiet,
                        onPressed: widget.onFinish,
                      ),
                      CommonButton(
                        label: '取消计时',
                        kind: CommonButtonKind.quiet,
                        destructive: true,
                        onPressed: widget.onCancel,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          for (final flight in _flights)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: flight.controller,
                    builder: (context, _) {
                      final t = flight.controller.value;
                      final point =
                          Offset.lerp(flight.start, flight.end, t)! -
                          Offset(
                            0,
                            YikeGeometry.lapArc *
                                t *
                                (1 - t) *
                                (flight.start.dy - flight.end.dy).abs(),
                          );
                      return Stack(
                        children: [
                          Positioned(
                            left: point.dx - ts.spacing.sm,
                            top: point.dy - ts.spacing.sm,
                            child: CustomPaint(
                              key: const ValueKey('lap-flight-mark'),
                              size: Size.square(ts.spacing.md),
                              painter: _LapMarkPainter(ts),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, int seconds) {
    final ts = TS.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ts.textStyle.caption),
          Text(timerDigits(seconds), style: ts.textStyle.numericContent),
        ],
      ),
    );
  }

  Widget _columns(Widget label, Widget lap, Widget total) {
    final ts = TS.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(flex: 3, child: label),
        SizedBox(width: ts.spacing.xs),
        Expanded(
          flex: 3,
          child: Align(alignment: Alignment.centerRight, child: lap),
        ),
        SizedBox(width: ts.spacing.sm),
        Expanded(
          flex: 3,
          child: Align(alignment: Alignment.centerRight, child: total),
        ),
      ],
    );
  }
}

class _LapFlight {
  _LapFlight(this.controller, this.start, this.end);
  final AnimationController controller;
  final Offset start, end;
}

class _LapMarkPainter extends CustomPainter {
  _LapMarkPainter(this.ts);
  final TS ts;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ts.colors.primary;
    if (ts.pack.id.endsWith('water')) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * .5, 0)
          ..cubicTo(
            size.width * .2,
            size.height * .4,
            0,
            size.height * .8,
            size.width * .5,
            size.height,
          )
          ..cubicTo(
            size.width,
            size.height * .8,
            size.width * .8,
            size.height * .4,
            size.width * .5,
            0,
          )
          ..close(),
        paint,
      );
    } else if (ts.pack.id.endsWith('sundial')) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * .2, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width * .8, size.height)
          ..lineTo(0, size.height)
          ..close(),
        paint,
      );
    } else {
      canvas.drawCircle(size.center(Offset.zero), size.shortestSide / 2, paint);
      canvas.drawCircle(
        size.center(Offset.zero),
        size.shortestSide * .15,
        paint..color = ts.colors.surface,
      );
    }
  }

  @override
  bool shouldRepaint(_LapMarkPainter old) => old.ts != ts;
}
