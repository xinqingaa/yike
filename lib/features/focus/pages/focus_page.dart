import 'dart:math' as math;
import '../../../common/motion/content_transition.dart';
import '../models/focus_view.dart';
import '../widgets/countdown_utility.dart';
import '../widgets/lap_list.dart';
import '../widgets/focus_panel_layout.dart';
import '../providers/focus_presentation.dart';
import '../../../common/time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/state/local_value.dart';
import '../../../common/widgets.dart';
import '../widgets/focus_dial.dart';
import '../../../router/routes.dart';
import '../../../theme/ts.dart';
import '../../../common/overlay/duration_sheet.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});
  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage>
    with TickerProviderStateMixin {
  late TabController _tabs;
  final _switching = localValueProvider(false);
  final _recordPromptOpen = localValueProvider(false);

  Future<void> _requestMode(String value) async {
    if (ref.read(_switching)) return;
    ref.read(_switching.notifier).set(true);
    try {
      await _selectMode(value);
    } finally {
      if (mounted) {
        ref.read(_switching.notifier).set(false);
      }
    }
  }

  Duration? _tabDuration;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TS.of(context).motion.durationTabViewport;
    if (_tabDuration == null) {
      _tabs = TabController(
        length: 3,
        vsync: this,
        initialIndex: ref.read(focusViewProvider).mode.index,
        animationDuration: duration,
      );
    } else if (_tabDuration != duration) {
      final previous = _tabs;
      _tabs = TabController(
        length: 3,
        vsync: this,
        initialIndex: previous.index,
        animationDuration: duration,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    _tabDuration = duration;
  }

  @override
  void dispose() {
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

  String _modeLabel(TimerMode mode) => const ['番茄钟', '正计时', '倒计时'][mode.index];

  Future<void> _selectMode(String value) async {
    _actions.calibrate();
    final next = TimerMode.values.byName(value);
    final current = ref.read(focusViewProvider);
    if (next == current.mode) return;
    if (!current.ready) {
      final ts = TS.of(context);
      final sheet = AppSheet<String>();
      final result = await sheet.show(
        title: '切换计时模式',
        material: CommonSurfaceMaterial.glass,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              current.resting
                  ? '结束当前休息后进入${_modeLabel(next)}，休息不计入专注。'
                  : current.finished
                  ? '当前阶段已完成。进入${_modeLabel(next)}后，已保存的记录会保留；放弃只离开当前阶段。'
                  : '即将进入${_modeLabel(next)}。结束会记录本次有效专注；放弃不生成本次记录。',
              style: ts.textStyle.content,
            ),
            SizedBox(height: ts.spacing.md),
            Row(
              children: [
                Expanded(
                  child: CommonButton(
                    label: '放弃',
                    kind: CommonButtonKind.outlined,
                    destructive: true,
                    onPressed: () => sheet.complete('discard'),
                  ),
                ),
                SizedBox(width: ts.spacing.smPlus),
                Expanded(
                  child: CommonButton(
                    label: '结束',
                    kind: CommonButtonKind.accent,
                    onPressed: () => sheet.complete('record'),
                  ),
                ),
              ],
            ),
          ],
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
    final ts = TS.of(context);
    final sheet = AppSheet<bool>();
    final result = await sheet.show(
      title: '放弃这次专注？',
      material: CommonSurfaceMaterial.glass,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('本次专注不会生成新记录。倒计时已完成部分会保留。', style: ts.textStyle.content),
          SizedBox(height: ts.spacing.md),
          CommonDecisionActions(
            actions: [
              CommonButton(
                label: '继续保留',
                kind: CommonButtonKind.secondary,
                onPressed: sheet.dismiss,
              ),
              CommonButton(
                label: '确认放弃',
                kind: CommonButtonKind.outlined,
                destructive: true,
                shape: CommonButtonShape.pill,
                onPressed: () => sheet.complete(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (result == true && mounted) _reset();
  }

  Future<void> _recovery() async {
    final ts = TS.of(context);
    final resting = ref.read(focusViewProvider).resting;
    final sheet = AppSheet<String>();
    final result = await sheet.show(
      title: '计时已暂停',
      material: CommonSurfaceMaterial.glass,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('已恢复到最后保存的进度，关闭期间没有计时。', style: ts.textStyle.content),
          SizedBox(height: ts.spacing.md),
          CommonButton(
            label: '继续计时',
            size: CommonControlSize.lg,
            shape: CommonButtonShape.pill,
            kind: CommonButtonKind.accent,
            onPressed: () => sheet.complete('resume'),
          ),
          SizedBox(height: ts.spacing.smPlus),
          CommonButton(
            label: resting ? '跳过休息' : '结束并记录',
            size: CommonControlSize.lg,
            shape: CommonButtonShape.pill,
            kind: CommonButtonKind.secondary,
            onPressed: () => sheet.complete('finish'),
          ),
          if (!resting)
            CommonButton(
              label: '放弃本次',
              kind: CommonButtonKind.quiet,
              onPressed: () => sheet.complete('discard'),
            ),
        ],
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
      if (_tabs.index != mode.index) {
        final ts = TS.of(context);
        _tabs.animateTo(
          mode.index,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : ts.motion.durationTabViewport,
          curve: ts.motion.easingGentle,
        );
      }
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
                disabled: ref.watch(_switching),
                onSelectionRequested: _requestMode,
              ),
            ],
          ),
        ),
        Expanded(
          child: IgnorePointer(
            ignoring: ref.watch(_switching),
            child: CommonTabView(
              controller: _tabs,
              swipe: false,
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
    final compact = MediaQuery.sizeOf(context).height < 700;
    return FocusPanelLayout(
      storageKey: PageStorageKey('focus-${value.mode.name}-scroll'),
      minimumUtilityHeight: (width) => math.max(
        CountdownUtility.heightFor(
          context,
          width,
          prefs.presets.whereType<int>().toList(),
        ),
        LapList.minimumHeight(context, compact: compact),
      ),
      dialBuilder: (width) => FocusDial(width: width, mode: value.mode),
      utilityBuilder: (width) => value.mode == TimerMode.countdown
          ? Center(
              child: CountdownUtility(
                key: const ValueKey('countdown-utility'),
                value: value,
                preferences: prefs,
                availableWidth: width,
                onRecovery: _recovery,
                onSelected: _actions.selectCountdown,
                onCustom: () async {
                  final duration = await pickYikeDuration(
                    title: '倒计时时长',
                    initial: value.seconds,
                    confirm: '确认时长',
                  );
                  if (duration != null && mounted) {
                    _actions.selectCountdown(duration);
                  }
                },
              ),
            )
          : value.mode == TimerMode.stopwatch && !value.ready
          ? LapList(
              key: ValueKey(
                ref.watch(focusDataProvider.select((data) => data.session?.id)),
              ),
              value: value,
              compact: compact,
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value.seconds >= 3600 &&
                      value.mode == TimerMode.stopwatch)
                    Text(
                      '已满 ${value.seconds ~/ 3600} 小时',
                      style: ts.textStyle.caption,
                    ),
                  if (value.mode == TimerMode.pomodoro) ...[
                    Text(
                      roundText,
                      textAlign: TextAlign.center,
                      style: ts.textStyle.content.copyWith(
                        color: ts.colors.onSurfaceMuted,
                      ),
                    ),
                    SizedBox(height: ts.spacing.sm),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: ts.spacing.xs,
                      runSpacing: ts.spacing.xs,
                      children: [
                        for (var i = 0; i < prefs.interval; i++)
                          _RoundMark(
                            active:
                                i <
                                value.round -
                                    (value.finished || value.resting ? 0 : 1),
                            current: !value.ready && i == value.round - 1,
                          ),
                      ],
                    ),
                    if (value.finished)
                      Text(
                        prefs.sound && prefs.pomodoroFeedback.sound
                            ? '提示音已开启'
                            : '提示音已关闭',
                        style: ts.textStyle.caption,
                      ),
                  ],
                  if (value.paused && value.recovered)
                    CommonButton(
                      label: '查看恢复选项',
                      kind: CommonButtonKind.quiet,
                      onPressed: _recovery,
                    ),
                ],
              ),
            ),
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: ts.sizing.actionMinInline,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (value.mode == TimerMode.stopwatch &&
                        value.status == TimerStatus.running) ...[
                      CommonButton(
                        label: '计圈',
                        size: CommonControlSize.lg,
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
              ),
            ),
          ),
          SizedBox(height: ts.spacing.sm),
          Expanded(child: Center(child: _secondaryActions(value, prefs))),
        ],
      ),
    );
  }

  Widget _secondaryActions(FocusViewData value, TimingPreferences prefs) {
    final ts = TS.of(context);
    if (value.ready) {
      return value.mode == TimerMode.pomodoro
          ? Text(
              '专注 ${prefs.focusMinutes} 分钟 · 短休 ${prefs.shortMinutes} 分钟',
              textAlign: TextAlign.center,
              style: ts.textStyle.caption,
            )
          : const SizedBox.shrink();
    }
    if (value.finished && value.mode == TimerMode.countdown) {
      return CommonButton(
        label: '再计${durationLabel(value.target, compact: true)}',
        kind: CommonButtonKind.quiet,
        onPressed: _actions.again,
      );
    }
    if (value.resting || (value.finished && value.mode == TimerMode.pomodoro)) {
      return value.finished && value.resting
          ? const SizedBox.shrink()
          : CommonButton(
              label: '跳过休息',
              kind: CommonButtonKind.quiet,
              onPressed: () => _reset(),
            );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (value.paused)
          Flexible(
            child: CommonButton(
              label: '结束并记录',
              kind: CommonButtonKind.quiet,
              onPressed: _finish,
            ),
          ),
        Flexible(
          child: CommonButton(
            label: value.mode == TimerMode.pomodoro ? '放弃本轮' : '取消计时',
            kind: CommonButtonKind.quiet,
            onPressed: _abandon,
          ),
        ),
      ],
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
    final child = AnimatedContainer(
      duration: motionEnabled(context) ? ts.motion.durationFast : Duration.zero,
      curve: ts.motion.easingGentle,
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
