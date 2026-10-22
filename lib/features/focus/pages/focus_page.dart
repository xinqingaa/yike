import '../models/focus_view.dart';
import '../providers/focus_presentation.dart';
import '../../../common/time.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/state/local_value.dart';
import '../../../common/widgets.dart';
import '../../../common/widgets/yike/dial.dart';
import '../../../common/widgets/yike/layout.dart';
import '../../../router/routes.dart';
import '../../../theme/ts.dart';
import '../../../common/overlay/duration_sheet.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});
  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    initialIndex: ref.read(focusViewProvider).mode.index,
    vsync: this,
  )..addListener(_tabChanged);
  final _switching = localValueProvider(false);
  final _recordPromptOpen = localValueProvider(false);

  void _tabChanged() {
    if (!_tabs.indexIsChanging &&
        _tabs.offset.abs() < .001 &&
        _tabs.index != ref.read(focusViewProvider).mode.index) {
      _requestMode(TimerMode.values[_tabs.index].name);
    }
  }

  Future<void> _requestMode(String value) async {
    if (ref.read(_switching)) return;
    ref.read(_switching.notifier).set(true);
    try {
      await _selectMode(value);
    } finally {
      if (mounted) {
        _tabs.animateTo(ref.read(focusViewProvider).mode.index);
        ref.read(_switching.notifier).set(false);
      }
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(focusViewProvider).recovered) {
        _recovery();
      } else if (mounted &&
          (ref.read(focusDataProvider).session?.promptShort ?? false)) {
        _shortRecord();
      }
    });
  }

  FocusActions get _actions => ref.read(focusActionsProvider);
  void _reset([TimerMode? mode]) {
    if (mode == null) {
      _actions.discard();
    } else {
      _actions.switchMode(mode);
    }
  }

  Future<void> _selectMode(String value) async {
    final next = TimerMode.values.byName(value);
    final current = ref.read(focusViewProvider);
    if (next == current.mode) return;
    if (!current.ready) {
      final result = await AppPop.sheet<String>(
        context,
        title: '切换计时模式？',
        material: CommonSurfaceMaterial.glass,
        builder: (context, handle) => YikeSheetBody(
          body: Text(
            '先结束当前阶段再切换。短于设置阈值时会再次确认是否记录，休息不计入专注。',
            style: TS.of(context).textStyle.content,
          ),
          actions: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              CommonButton(
                label: '结束并切换',
                size: CommonControlSize.lg,
                shape: CommonButtonShape.pill,
                kind: CommonButtonKind.accent,
                onPressed: () => handle.complete('record'),
              ),
              CommonButton(
                label: '放弃并切换',
                size: CommonControlSize.lg,
                shape: CommonButtonShape.pill,
                destructive: true,
                kind: CommonButtonKind.outlined,
                onPressed: () => handle.complete('discard'),
              ),
              CommonButton(
                label: '取消',
                size: CommonControlSize.lg,
                shape: CommonButtonShape.pill,
                kind: CommonButtonKind.quiet,
                onPressed: handle.dismiss,
              ),
            ],
          ),
        ),
      );
      if (!mounted || result == null) return;
      if (result == 'record' && !await _shortRecord()) return;
      _actions.switchMode(next, record: result == 'record');
      return;
    }
    _actions.switchMode(next);
  }

  Future<bool> _shortRecord() async {
    if (ref.read(_recordPromptOpen)) return false;
    if (!_actions.prepareFinish()) return true;
    ref.read(_recordPromptOpen.notifier).set(true);
    final value = ref.read(focusViewProvider);
    final elapsed = value.mode == TimerMode.stopwatch
        ? value.seconds
        : value.target - value.seconds;
    final threshold = ref.read(timingPreferencesProvider).threshold;
    final accepted = await AppPop.confirm(
      context,
      title: '记录这次短时专注？',
      content:
          '本次专注 ${durationLabel(elapsed)}，少于设置的 ${durationLabel(threshold)}确认阈值。仍然记录吗？',
      cancelText: '暂不结束',
      confirmText: '仍然记录',
      material: CommonSurfaceMaterial.glass,
    );
    if (!mounted) return false;
    ref.read(_recordPromptOpen.notifier).set(false);
    if (accepted) {
      _actions.acceptShort();
    } else {
      _actions.dismissPrompt();
    }
    return accepted;
  }

  Future<void> _finish() async {
    if (await _shortRecord() && mounted) _actions.finish();
  }

  Future<void> _abandon() async {
    final result = await AppPop.sheet<bool>(
      context,
      title: '放弃这次专注？',
      material: CommonSurfaceMaterial.glass,
      builder: (context, handle) => YikeSheetBody(
        body: Text(
          '本次专注不会生成新记录。倒计时已完成部分会保留。',
          style: TS.of(context).textStyle.content,
        ),
        actions: CommonDecisionActions(
          actions: [
            CommonButton(
              label: '继续保留',
              kind: CommonButtonKind.secondary,
              onPressed: handle.dismiss,
            ),
            CommonButton(
              label: '确认放弃',
              kind: CommonButtonKind.outlined,
              destructive: true,
              shape: CommonButtonShape.pill,
              onPressed: () => handle.complete(true),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) _reset();
  }

  Future<void> _recovery() async {
    final result = await AppPop.sheet<String>(
      context,
      title: '计时已暂停',
      material: CommonSurfaceMaterial.glass,
      builder: (context, handle) => YikeSheetBody(
        body: Text(
          '已恢复到最后保存的进度，关闭期间没有计时。',
          style: TS.of(context).textStyle.content,
        ),
        actions: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommonButton(
              label: '继续计时',
              size: CommonControlSize.lg,
              shape: CommonButtonShape.pill,
              kind: CommonButtonKind.accent,
              onPressed: () => handle.complete('resume'),
            ),
            CommonButton(
              label: ref.read(focusViewProvider).resting ? '跳过休息' : '结束并记录',
              size: CommonControlSize.lg,
              shape: CommonButtonShape.pill,
              kind: CommonButtonKind.secondary,
              onPressed: () => handle.complete('finish'),
            ),
            if (!ref.read(focusViewProvider).resting)
              CommonButton(
                label: '放弃本次',
                kind: CommonButtonKind.quiet,
                onPressed: () => handle.complete('discard'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'resume') _actions.resume();
    if (result == 'finish') {
      if (ref.read(focusViewProvider).resting) {
        _actions.discard();
      } else {
        await _finish();
      }
    }
    if (result == 'discard') await _abandon();
  }

  Future<void> _primary() async {
    _actions.calibrate();
    final value = ref.read(focusViewProvider);
    if (value.finished) {
      if (value.mode == TimerMode.pomodoro && !value.resting) {
        if (await _shortRecord() && mounted) _actions.beginBreak();
      } else {
        _actions.discard();
      }
    } else if (value.ready) {
      _actions.start();
    } else if (value.paused) {
      _actions.resume();
    } else {
      _actions.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final value = ref.watch(focusViewProvider);
    ref.listen(
      focusDataProvider.select((d) => d.session?.promptShort ?? false),
      (before, after) {
        if (after && before != after) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !ref.read(_recordPromptOpen)) _shortRecord();
          });
        }
      },
    );
    ref.listen(focusViewProvider.select((value) => value.mode), (_, mode) {
      if (_tabs.index != mode.index) _tabs.animateTo(mode.index);
    });
    final prefs = ref.watch(timingPreferencesProvider);
    final today = ref.watch(todayProvider);
    final todaySeconds = ref
        .watch(focusRecordsProvider)
        .where((r) => r.date == dayId(today))
        .fold<num>(0, (sum, r) => sum + r.seconds);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            ts.spacing.lg,
            ts.spacing.lg,
            ts.spacing.lg,
            0,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${today.month}月${today.day}日星期${const ['一', '二', '三', '四', '五', '六', '日'][today.weekday - 1]}',
                          style: ts.textStyle.caption,
                        ),
                        Text(
                          '今天已专注 ${durationLabel(todaySeconds)}',
                          style: ts.textStyle.caption,
                        ),
                      ],
                    ),
                  ),
                  CommonIconButton(
                    name: CommonIconName.settings,
                    label: '设置',
                    variant: CommonIconButtonVariant.text,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),
                ],
              ),
              CommonPrimaryTabs(
                items: const [
                  CommonTabItem(value: 'pomodoro', label: '番茄钟'),
                  CommonTabItem(value: 'stopwatch', label: '正计时'),
                  CommonTabItem(value: 'countdown', label: '倒计时'),
                ],
                grow: true,
                controller: _tabs,
                onSelected: _requestMode,
              ),
            ],
          ),
        ),
        Expanded(
          child: IgnorePointer(
            ignoring: ref.watch(_switching),
            child: CommonTabView(
              controller: _tabs,
              children: [
                for (final mode in TimerMode.values)
                  _panel(
                    mode == value.mode
                        ? value
                        : FocusViewData(
                            mode: mode,
                            seconds: mode == TimerMode.stopwatch
                                ? 0
                                : mode == TimerMode.countdown
                                ? 300
                                : prefs.focusMinutes * 60,
                            target: mode == TimerMode.stopwatch
                                ? 0
                                : mode == TimerMode.countdown
                                ? 300
                                : prefs.focusMinutes * 60,
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(FocusViewData value) {
    final ts = TS.of(context);
    final prefs = ref.watch(timingPreferencesProvider);
    final label = value.finished
        ? value.resting
              ? '准备下一轮'
              : value.mode == TimerMode.countdown
              ? '完成'
              : '开始休息'
        : value.status == TimerStatus.running
        ? '暂停'
        : value.paused
        ? '继续'
        : value.mode == TimerMode.pomodoro
        ? '开始专注'
        : value.mode == TimerMode.stopwatch
        ? '开始计时'
        : '开始 ${durationLabel(value.seconds)}';
    final roundText = value.stage == TimerStage.longBreak
        ? '${prefs.interval} 轮全部完成 · 好好休息'
        : value.resting
        ? '第 ${value.round} 轮已完成 · 休息一下'
        : value.finished
        ? '第 ${value.round} 轮已完成'
        : value.ready
        ? '第 ${value.round} 轮'
        : '第 ${value.round} 轮专注';
    return LayoutBuilder(
      builder: (context, constraints) {
        final dialHeight = ts.sizing.plot * ts.artworkAspectRatio;
        final minimum = math.max(
          constraints.maxHeight,
          dialHeight + ts.sizing.controlLg * 3 + ts.spacing.lg * 2,
        );
        return SingleChildScrollView(
          key: PageStorageKey('focus-${value.mode.name}-scroll'),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimum),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ts.spacing.lg,
                  0,
                  ts.spacing.lg,
                  ts.spacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: ts.pack.id.endsWith('mechanical')
                          ? ts.spacing.xl
                          : ts.spacing.md,
                    ),
                    Center(
                      child: YikeDial(
                        digits: timerDigits(value.seconds),
                        caption: value.caption,
                        progress: value.progress,
                        paused: value.paused,
                        resting: value.resting,
                        completed: value.finished,
                        countdown: value.mode == TimerMode.countdown,
                      ),
                    ),
                    if (value.seconds > 3600 &&
                        value.mode != TimerMode.countdown)
                      Text(
                        value.mode == TimerMode.stopwatch
                            ? '已满 ${value.seconds ~/ 3600} 小时'
                            : '另有 ${durationLabel(value.seconds - 3600)}',
                        textAlign: TextAlign.center,
                        style: ts.textStyle.caption,
                      ),
                    const Spacer(),
                    if (value.finished)
                      Text(
                        prefs.sound ? '提示音已开启' : '提示音已关闭',
                        textAlign: TextAlign.center,
                        style: ts.textStyle.caption,
                      ),
                    if (value.mode == TimerMode.pomodoro) ...[
                      SizedBox(height: ts.spacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              roundText,
                              style: ts.textStyle.content.copyWith(
                                color: ts.colors.onSurfaceMuted,
                              ),
                            ),
                          ),
                          SizedBox(width: ts.spacing.sm),
                          for (var i = 0; i < prefs.interval; i++)
                            Padding(
                              padding: EdgeInsets.only(right: ts.spacing.xs),
                              child: _RoundMark(
                                active:
                                    i <
                                    value.round -
                                        (value.finished || value.resting
                                            ? 0
                                            : 1),
                                current: !value.ready && i == value.round - 1,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: ts.spacing.xl),
                    ],
                    if (value.mode == TimerMode.stopwatch && !value.ready) ...[
                      SizedBox(height: ts.spacing.sm),
                      SizedBox(
                        height: ts.sizing.controlSm * 2,
                        child: CommonScrollableDataList(
                          itemCount: value.laps.length + 1,
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            final current = index == 0;
                            final lapIndex = value.laps.length - index;
                            final total = current
                                ? value.seconds
                                : value.laps[lapIndex];
                            final previous = lapIndex > 0
                                ? value.laps[lapIndex - 1]
                                : 0;
                            return Row(
                              children: [
                                Text(
                                  '第 ${value.laps.length + 1 - index} 圈',
                                  style: ts.textStyle.caption,
                                ),
                                SizedBox(width: ts.spacing.lg),
                                Text(
                                  timerDigits(total - previous),
                                  style: ts.textStyle.numericContent,
                                ),
                                const Spacer(),
                                Text(
                                  current
                                      ? value.paused
                                            ? '已暂停'
                                            : '进行中'
                                      : '累计 ${timerDigits(total)}',
                                  style: ts.textStyle.caption,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: ts.spacing.md),
                    ],
                    if (value.mode == TimerMode.countdown && value.ready) ...[
                      SizedBox(height: ts.spacing.lg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: ts.spacing.xs,
                        runSpacing: ts.spacing.xs,
                        children: [
                          for (final preset in prefs.presets.whereType<int>())
                            CommonChip(
                              label: durationLabel(preset, compact: true),
                              selected: value.target == preset,
                              tone: value.target == preset
                                  ? CommonChipTone.primary
                                  : CommonChipTone.secondary,
                              onTap: () => _actions.selectCountdown(preset),
                            ),
                          CommonButton(
                            label: '自定义',
                            kind: CommonButtonKind.quiet,
                            onPressed: () async {
                              final duration = await pickYikeDuration(
                                context,
                                title: '倒计时时长',
                                initial: value.seconds,
                                confirm: '确认时长',
                              );
                              if (duration != null) {
                                _actions.selectCountdown(duration);
                              }
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: ts.spacing.lg),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (value.mode == TimerMode.stopwatch &&
                            value.status == TimerStatus.running) ...[
                          CommonButton(
                            label: '计圈',
                            kind: CommonButtonKind.secondary,
                            shape: CommonButtonShape.pill,
                            onPressed: _actions.lap,
                          ),
                          SizedBox(width: ts.spacing.sm),
                        ],
                        Flexible(
                          child: SizedBox(
                            width: ts.sizing.actionMinInline,
                            child: CommonButton(
                              key: const ValueKey('focus-primary'),
                              label: label,
                              kind: CommonButtonKind.accent,
                              size: CommonControlSize.lg,
                              shape: CommonButtonShape.pill,
                              block: true,
                              onPressed: _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ts.spacing.sm),
                    if (value.paused && value.recovered)
                      CommonButton(
                        label: '查看恢复选项',
                        kind: CommonButtonKind.quiet,
                        onPressed: _recovery,
                      ),
                    if (value.resting ||
                        (value.finished && value.mode == TimerMode.pomodoro))
                      CommonButton(
                        label: value.finished && value.resting ? '' : '跳过休息',
                        disabled: value.finished && value.resting,
                        kind: CommonButtonKind.quiet,
                        onPressed: () => _reset(),
                      )
                    else if (value.finished &&
                        value.mode == TimerMode.countdown)
                      CommonButton(
                        label:
                            '再计${durationLabel(value.target, compact: true)}',
                        kind: CommonButtonKind.quiet,
                        onPressed: _actions.again,
                      )
                    else if (!value.ready)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (value.paused)
                            Flexible(
                              child: CommonButton(
                                label: '结束并记录',
                                size: CommonControlSize.lg,
                                shape: CommonButtonShape.pill,
                                kind: CommonButtonKind.quiet,
                                onPressed: _finish,
                              ),
                            ),
                          Flexible(
                            child: CommonButton(
                              label: value.mode == TimerMode.pomodoro
                                  ? '放弃本轮'
                                  : '取消计时',
                              kind: CommonButtonKind.quiet,
                              onPressed: _abandon,
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        height: ts.sizing.controlMd,
                        child: Center(
                          child: value.mode == TimerMode.pomodoro
                              ? Text(
                                  '专注 ${prefs.focusMinutes} 分钟 · 短休 ${prefs.shortMinutes} 分钟',
                                  style: ts.textStyle.caption,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoundMark extends StatelessWidget {
  const _RoundMark({required this.active, required this.current});
  final bool active, current;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final water = ts.pack.id.endsWith('water');
    final child = Container(
      width: water ? ts.spacing.sm : ts.spacing.smPlus,
      height: water ? ts.spacing.sm : ts.spacing.xs,
      decoration: BoxDecoration(
        color: active
            ? ts.colors.primary
            : current
            ? Colors.transparent
            : ts.colors.onSurfaceMuted,
        border: current
            ? Border.all(
                color: ts.colors.primary,
                width: ts.border.widthHairline,
              )
            : null,
        borderRadius: BorderRadius.circular(
          water ? ts.radius.full : ts.radius.none,
        ),
      ),
    );
    return Transform.rotate(
      angle: ts.pack.id.endsWith('sundial') ? -.15 : 0,
      child: child,
    );
  }
}
