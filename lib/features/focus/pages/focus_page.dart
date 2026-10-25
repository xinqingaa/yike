import '../../../app/navigation.dart';
import '../../../common/route_activity.dart';
import '../../../common/overlay/popup_activity.dart';
import 'dart:math' as math;
import '../../../common/motion/content_transition.dart';
import '../models/focus_view.dart';
import '../widgets/countdown_utility.dart';
import '../widgets/lap_panel.dart';
import '../widgets/focus_panel_layout.dart';
import '../providers/focus_presentation.dart';
import '../providers/focus_dial_presentation.dart';
import '../../../common/time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/state/local_value.dart';
import '../../../common/widgets.dart';
import '../widgets/focus_dial.dart';
import '../../../router/routes.dart';
import '../../../theme/ts.dart';
import '../../../theme/yike_geometry.dart';
import '../widgets/dial_adjuster.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});
  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage>
    with TickerProviderStateMixin {
  late TabController _tabs;
  final _dial = DialAdjustmentController();

  final _switching = localValueProvider(false);
  final _recordPromptOpen = localValueProvider(false);

  Future<void> _requestMode(String value) async {
    _dial.finish();
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
    appRouteActivity.removeListener(_presentPending);
    _dial.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    appRouteActivity.addListener(_presentPending);
    _presentPending();
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
    _actions.switchMode(TimerMode.values.byName(value));
    _presentPending();
  }

  final _recoveryPresented = <String>{};
  void _presentPending() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !ModalRoute.of(context)!.isCurrent ||
          ref.read(rootTabProvider) != 0 ||
          ref.read(popupActivityProvider) != 0 ||
          ref.read(_recordPromptOpen)) {
        return;
      }
      final session = ref.read(focusDataProvider).session;
      if ((session?.recovered ?? false) &&
          _recoveryPresented.add(session!.id)) {
        _recovery();
      } else if (session?.promptShort ?? false) {
        _shortRecord();
      }
    });
  }

  Future<bool> _shortRecord() async {
    if (ref.read(_recordPromptOpen)) return false;
    if (!_actions.prepareFinish()) return true;
    ref.read(_recordPromptOpen.notifier).set(true);
    final value = ref.read(focusViewProvider);
    final sessionId = ref.read(focusDataProvider).session!.id;
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
      if (!_actions.command(value.mode, sessionId, FocusCommand.record)) {
        return false;
      }
    } else {
      _actions.command(value.mode, sessionId, FocusCommand.dismissPrompt);
    }
    return accepted;
  }

  Future<void> _finish() async {
    final s = ref.read(focusDataProvider).session;
    if (s != null && await _shortRecord() && mounted) {
      _actions.command(s.mode, s.id, FocusCommand.finish);
    }
  }

  Future<void> _abandon() async {
    final session = ref.read(focusDataProvider).session;
    if (session == null) return;
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
    if (result == true && mounted) {
      _actions.command(session.mode, session.id, FocusCommand.discard);
    }
  }

  Future<void> _recovery() async {
    final ts = TS.of(context);
    final session = ref.read(focusDataProvider).session;
    if (session == null) return;
    final resting = session.resting;
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
    if (!mounted || ref.read(focusDataProvider).session?.id != session.id) {
      return;
    }
    if (result == 'resume') {
      _actions.command(session.mode, session.id, FocusCommand.resume);
    }
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
    if (_dial.value) return;
    _actions.calibrate();
    final value = ref.read(focusViewProvider);
    final session = ref.read(focusDataProvider).session;
    if (value.finished) {
      if (value.mode == TimerMode.pomodoro && !value.resting) {
        if (await _shortRecord() && mounted && session != null) {
          _actions.command(session.mode, session.id, FocusCommand.beginBreak);
        }
      } else {
        if (value.mode == TimerMode.stopwatch && !await _shortRecord()) return;
        if (session != null) {
          _actions.command(session.mode, session.id, FocusCommand.discard);
        }
      }
    } else if (value.ready) {
      _actions.start();
    } else if (value.paused) {
      _actions.resume();
    } else {
      _actions.pause();
    }
  }

  bool _lapPanelOpen = false;
  Future<void> _openLaps() async {
    if (_lapPanelOpen) return;
    _actions.calibrate();
    final session = ref.read(focusDataProvider).session;
    if (session == null || session.mode != TimerMode.stopwatch) return;
    _lapPanelOpen = true;
    final sheet = AppSheet<void>();
    try {
      await sheet.show(
        timerPanel: true,
        direction: SheetDirection.right,
        showCloseButton: false,
        size: SheetSizeConfig(
          width: const SheetDimension.fraction(YikeGeometry.lapPanelWidth),
          height: const SheetDimension.fraction(1),
        ),
        drag: const SheetDragConfig(showHandle: false),
        material: CommonSurfaceMaterial.glass,
        child: LapPanel(
          sessionId: session.id,
          close: sheet.dismiss,
          onFinish: () async {
            if (ref.read(focusViewProvider).finished) {
              await _primary();
            } else {
              await _finish();
            }
          },
          onCancel: _abandon,
        ),
      );
    } finally {
      _lapPanelOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    ref.listen(rootTabProvider, (_, next) {
      if (next == 0) _presentPending();
    });
    ref.listen(popupActivityProvider, (_, next) {
      if (next == 0) _presentPending();
    });
    ref.listen(
      focusDataProvider.select(
        (d) => (d.mode, d.session?.id, d.session?.promptShort),
      ),
      (_, next) => _presentPending(),
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
                    child: _dim(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateWeekLabel(dayId(today)),
                            style: ts.textStyle.caption,
                          ),
                          Text(
                            '今天已专注 ${durationLabel(todaySeconds)}',
                            style: ts.textStyle.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                  CommonIconButton(
                    name: CommonIconName.settings,
                    label: '设置',
                    variant: CommonIconButtonVariant.text,
                    onPressed: () {
                      _dial.finish();
                      Navigator.of(context).pushNamed(AppRoutes.settings);
                    },
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
                  _panel(ref.watch(focusDialPresentationProvider(mode)).view),
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
    final selectedPreset = value.mode == TimerMode.countdown
        ? ref.watch(
            focusDataProvider.select((data) {
              final slot = data.countdownPreset;
              return data.preferences.presets
                  .take(slot)
                  .whereType<int>()
                  .length;
            }),
          )
        : 0;
    final label = value.finished
        ? value.resting
              ? '准备下一轮'
              : value.mode != TimerMode.pomodoro
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
      compactUtility: value.mode == TimerMode.stopwatch,
      storageKey: PageStorageKey('focus-${value.mode.name}-scroll'),
      minimumUtilityHeight: (width) => math.max(
        CountdownUtility.heightFor(
          context,
          width,
          prefs.presets.whereType<int>().toList(),
        ),
        FocusPanelLayout.minimumAccessoryHeight(context, compact: compact),
      ),
      dialBuilder: (width) =>
          FocusDial(width: width, mode: value.mode, adjustment: _dial),
      utilityBuilder: (width) => _dim(
        value.mode == TimerMode.countdown
            ? Center(
                child: CountdownUtility(
                  key: const ValueKey('countdown-utility'),
                  value: value,
                  preferences: prefs,
                  availableWidth: width,
                  onRecovery: _recovery,
                  selectedIndex: selectedPreset,
                  onSelected: (seconds) {
                    _dial.finish();
                    _actions.selectCountdownPreset(seconds);
                  },
                  onEdit: () {
                    _dial.finish();
                    Navigator.of(context).pushNamed(
                      AppRoutes.settings,
                      arguments: const SettingsRouteArguments(
                        openCountdownPresets: true,
                      ),
                    );
                  },
                ),
              )
            : value.mode == TimerMode.stopwatch
            ? value.ready
                  ? const SizedBox.shrink()
                  : Center(
                      child: CommonButton(
                        key: const ValueKey('stopwatch-laps-entry'),
                        label: '计圈记录 · ${value.laps.length} 圈 ›',
                        kind: CommonButtonKind.quiet,
                        onPressed: _openLaps,
                      ),
                    )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    Flexible(
                      child: SizedBox(
                        width: ts.sizing.actionMinInline,
                        child: ListenableBuilder(
                          listenable: _dial,
                          builder: (context, _) => CommonButton(
                            key: const ValueKey('focus-primary'),
                            label: label,
                            kind: CommonButtonKind.accent,
                            size: CommonControlSize.lg,
                            shape: CommonButtonShape.pill,
                            block: true,
                            onPressed: _dial.value ? null : _primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: ts.spacing.sm),
          Expanded(child: Center(child: _dim(_secondaryActions(value, prefs)))),
        ],
      ),
    );
  }

  Widget _dim(Widget child) => ListenableBuilder(
    listenable: _dial,
    builder: (context, child) => AnimatedOpacity(
      opacity: _dial.value ? .35 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : TS.of(context).motion.durationFast,
      child: child,
    ),
    child: child,
  );

  Widget _secondaryActions(FocusViewData value, TimingPreferences prefs) {
    final ts = TS.of(context);
    if (value.ready) {
      return value.mode == TimerMode.pomodoro
          ? Text(
              '专注 ${durationLabel(value.target)} · 短休 ${durationLabel(prefs.shortSeconds)}',
              textAlign: TextAlign.center,
              style: ts.textStyle.caption,
            )
          : const SizedBox.shrink();
    }
    if (value.mode == TimerMode.stopwatch && value.finished) {
      return const SizedBox.shrink();
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
        if (value.paused || value.mode == TimerMode.stopwatch)
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
