import '../../../common/motion/content_transition.dart';
import '../../focus/focus.dart';
import '../../../app/reset_data.dart';
import '../../../app/notifications/notification_settings.dart';
import '../../../app/system_surfaces/surface_settings.dart';
import '../../../common/time.dart';
import '../../../common/feedback/feedback_cue.dart';
import '../providers/sound_audition.dart';
import '../widgets/settings_header.dart';
import '../widgets/pomodoro_settings.dart';
import '../widgets/countdown_preset_editor.dart';
import '../../../common/feedback/feedback_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/state/local_value.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/widgets.dart';
import '../../../common/widgets/yike/dial.dart';
import '../../../common/widgets/yike/layout.dart';
import '../../../router/routes.dart';
import '../../../theme/ts.dart';
import '../../../common/overlay/duration_sheet.dart';

class YikeSettingsPage extends ConsumerStatefulWidget {
  const YikeSettingsPage({super.key, this.openCountdownPresets = false});
  final bool openCountdownPresets;
  @override
  ConsumerState<YikeSettingsPage> createState() => _YikeSettingsPageState();
}

class _YikeSettingsPageState extends ConsumerState<YikeSettingsPage>
    with SingleTickerProviderStateMixin {
  final _navigation = SettingsScrollController();
  final _auditionAnchor = PopupAnchorController();
  late final _tabs = TabController(
    length: settingsSections.length,
    vsync: this,
  );
  final _section = localValueProvider(0);
  late final AppLifecycleListener _lifecycle;
  bool _scrollScheduled = false;

  double get _headerHeight =>
      TS.of(context).sizing.controlMd + TS.of(context).spacing.sm * 2;

  @override
  void initState() {
    super.initState();
    _navigation.scroll.addListener(_scrolled);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) {
          ref.read(soundAuditionProvider.notifier).stop();
        }
      },
    );
    if (widget.openCountdownPresets) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollTo(countdownSettingsSection, animate: false);
        openPresetSettings();
      });
    }
  }

  void _setSection(int index) {
    if (ref.read(_section) == index) return;
    ref.read(_section.notifier).set(index);
    _tabs.animateTo(
      index,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : TS.of(context).motion.durationNormal,
      curve: TS.of(context).motion.easingGentle,
    );
  }

  void _scrolled() {
    if (_scrollScheduled || _navigation.target != null) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (mounted &&
          _navigation.scroll.hasClients &&
          _navigation.target == null) {
        _setSection(
          _navigation.active(_headerHeight, current: ref.read(_section)),
        );
      }
    });
  }

  Future<void> _scrollTo(int index, {bool animate = true}) async {
    ref.read(soundAuditionProvider.notifier).stop();
    _setSection(index);
    final epoch = ++_navigation.epoch;
    _navigation.target = index;
    final offset = _navigation.offsetFor(index, _headerHeight);
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _navigation.scroll.jumpTo(offset);
    } else {
      await _navigation.scroll.animateTo(
        offset,
        duration: TS.of(context).motion.durationSlow,
        curve: TS.of(context).motion.easingGentle,
      );
    }
    if (!mounted || epoch != _navigation.epoch) return;
    _navigation.target = null;
  }

  @override
  void dispose() {
    _navigation.scroll.removeListener(_scrolled);
    _navigation.dispose();
    _auditionAnchor.attached.dispose();
    _tabs.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  Widget _group(CommonListGroup group, {bool primary = false}) =>
      CommonGroupedList(
        groups: [group],
        headingStyle: primary
            ? TS.of(context).textStyle.titleSm
            : TS
                  .of(context)
                  .textStyle
                  .captionStrong
                  .copyWith(
                    letterSpacing: 0,
                    color: TS.of(context).colors.onSurfaceMuted,
                  ),
        onNavigate: _navigate,
        onChanged: _change,
      );

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final prefs = ref.watch(timingPreferencesProvider);
    final playing = ref.watch(soundAuditionProvider);
    ref.watch(_section);
    final groups = <Widget>[
      _appearance(),
      PomodoroSettings(onNavigate: (item) => _navigate('pomodoro', item)),
      _group(
        CommonListGroup(
          id: 'countdown',
          title: '倒计时',
          items: [
            CommonListItem(
              id: 'presets',
              title: '常用倒计时',
              value: '${prefs.presets.whereType<int>().length} 项',
              navigation: true,
            ),
          ],
        ),
        primary: true,
      ),
      _sounds(prefs, playing),
      _group(
        CommonListGroup(
          id: 'general',
          title: '通用',
          items: [
            const CommonListItem(
              id: 'notifications',
              title: '通知提醒',
              navigation: true,
            ),
            const CommonListItem(
              id: 'systemSurfaces',
              title: '桌面组件',
              navigation: true,
            ),
            CommonListItem(
              id: 'threshold',
              title: '短时记录确认阈值',
              value: durationLabel(prefs.threshold),
              navigation: true,
            ),
          ],
        ),
        primary: true,
      ),
    ];
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const CommonAppBar(
          title: '设置',
          dense: true,
        ).preferredSize,
        child: AnimatedBuilder(
          animation: _navigation.scroll,
          builder: (context, _) => CommonAppBar(
            title: '设置',
            dense: true,
            showBack: true,
            glassProgress: settingsHeaderProgress(_navigation.scroll),
            background: CommonAppBarSurface.transparent,
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _navigation.interrupt();
            _scrolled();
          }
          return false;
        },
        child: CustomScrollView(
          key: _navigation.viewport,
          controller: _navigation.scroll,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: SettingsHeader(
                ts: ts,
                controller: _tabs,
                scroll: _navigation.scroll,
                onSelected: (index) => _scrollTo(index),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                ts.spacing.lg,
                ts.spacing.sm,
                ts.spacing.lg,
                ts.spacing.lg + MediaQuery.viewPaddingOf(context).bottom,
              ),
              sliver: SliverToBoxAdapter(
                child: YikePageWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < groups.length; i++)
                        Padding(
                          key: _navigation.sections[i],
                          padding: EdgeInsets.only(bottom: ts.spacing.lg),
                          child: groups[i],
                        ),
                      CommonButton(
                        key: const ValueKey('settings-reset'),
                        label: '重置所有数据',
                        kind: CommonButtonKind.outlined,
                        destructive: true,
                        block: true,
                        onPressed: () {
                          ref.read(soundAuditionProvider.notifier).stop();
                          _reset(context, ref);
                        },
                      ),
                      SizedBox(height: ts.spacing.lg),
                      Text(
                        '一刻 · 只在本机保存',
                        textAlign: TextAlign.center,
                        style: ts.textStyle.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sounds(TimingPreferences prefs, SoundCue? playing) {
    final ts = TS.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopupAnchor(
          controller: _auditionAnchor,
          child: _group(
            CommonListGroup(
              id: 'feedback',
              title: '声音',
              items: [
                CommonListItem(
                  id: 'sound',
                  title: '声音总开关',
                  switchValue: prefs.sound,
                ),
                CommonListItem(
                  id: 'haptics',
                  title: '触感总开关',
                  switchValue: prefs.haptics,
                ),
                CommonListItem(
                  id: 'audition',
                  title: '试听提示音',
                  value: playing == null
                      ? '滴答 / 间隔 / 完成'
                      : '${_soundLabel(playing)} · 试听中',
                  navigation: true,
                  disabled: !prefs.sound,
                ),
              ],
            ),
            primary: true,
          ),
        ),
        SizedBox(height: ts.spacing.md),
        _group(
          CommonListGroup(
            id: 'pomodoro',
            title: '番茄钟反馈',
            items: _feedbackItems(prefs, prefs.pomodoroFeedback),
          ),
        ),
        _group(
          CommonListGroup(
            id: 'stopwatch',
            title: '正计时反馈',
            items: _feedbackItems(prefs, prefs.stopwatchFeedback),
          ),
        ),
        _group(
          CommonListGroup(
            id: 'countdown',
            title: '倒计时反馈',
            items: _feedbackItems(prefs, prefs.countdownFeedback),
          ),
        ),
        _group(
          CommonListGroup(
            id: 'habits',
            title: '打卡反馈',
            items: _feedbackItems(prefs, prefs.habitFeedback, timer: false),
          ),
        ),
      ],
    );
  }

  Widget _appearance() {
    final ts = TS.of(context);
    final pack = ref.watch(themePackProvider),
        mode = ref.watch(themeModeProvider);
    final packs = ref
        .watch(themePacksProvider)
        .where((p) => p.id.startsWith('yike/'))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: ts.spacing.sm),
          child: Text('外观', style: ts.textStyle.titleSm),
        ),
        SizedBox(height: ts.spacing.sm),
        Text('表盘', style: ts.textStyle.caption.copyWith(letterSpacing: 0)),
        SizedBox(height: ts.spacing.sm),
        Row(
          children: [
            for (var i = 0; i < packs.length; i++) ...[
              if (i > 0) SizedBox(width: ts.spacing.sm),
              Expanded(
                child: Semantics(
                  selected: pack.id == packs[i].id,
                  button: true,
                  child: InkWell(
                    key: ValueKey('theme-${packs[i].id}'),
                    onTap: () => ref
                        .read(themePackProvider.notifier)
                        .select(packs[i].id),
                    borderRadius: BorderRadius.circular(ts.radius.md),
                    child: Container(
                      padding: EdgeInsets.all(ts.spacing.sm),
                      decoration: BoxDecoration(
                        color: ts.colors.surface,
                        border: Border.fromBorderSide(
                          pack.id == packs[i].id
                              ? ts.border.focus
                              : ts.border.defaultBorder,
                        ),
                        borderRadius: BorderRadius.circular(ts.radius.md),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: ts.sizing.brand,
                            child: FittedBox(
                              child: YikeDial(
                                tokens: ts.forPack(packs[i]),
                                digits: '12:34',
                                progress: 12.5 / 60,
                              ),
                            ),
                          ),
                          SizedBox(height: ts.spacing.sm),
                          Text(
                            const ['机械', '水位', '日影'][i],
                            style: ts.textStyle.label,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: ts.spacing.md),
        Text('显示模式', style: ts.textStyle.caption.copyWith(letterSpacing: 0)),
        SizedBox(height: ts.spacing.sm),
        YikeSelectionBar(
          items: const [
            CommonTabItem(value: 'light', label: '浅色'),
            CommonTabItem(value: 'dark', label: '深色'),
            CommonTabItem(value: 'system', label: '跟随系统'),
          ],
          value: mode.name,
          onSelected: (value) => ref
              .read(themeModeProvider.notifier)
              .setMode(ThemeMode.values.byName(value)),
        ),
        SizedBox(height: ts.spacing.md),
      ],
    );
  }

  String _soundLabel(SoundCue cue) => switch (cue) {
    SoundCue.tick => '每秒滴答',
    SoundCue.chime => '间隔提示',
    SoundCue.finish => '完成提示',
  };

  Future<void> _openAudition() async {
    final playing = ref.read(soundAuditionProvider);
    final selected = await AppPop.dropMenu<int>(
      anchor: _auditionAnchor,
      material: CommonSurfaceMaterial.glass,
      menu: DropMenu<int>.single(
        selectedValue: playing?.index,
        items: [
          for (final cue in SoundCue.values)
            DropMenuItem(
              value: cue.index,
              label: _soundLabel(cue),
              selected: playing == cue,
            ),
          if (playing != null) const DropMenuItem(value: 3, label: '停止试听'),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    final audition = ref.read(soundAuditionProvider.notifier);
    if (selected == 3) {
      audition.stop();
    } else {
      audition.toggle(SoundCue.values[selected]);
    }
  }

  Future<void> _navigate(String group, String item) async {
    if (item == 'audition') {
      await _openAudition();
      return;
    }
    ref.read(soundAuditionProvider.notifier).stop();
    final prefs = ref.read(timingPreferencesProvider);
    if (item == 'systemSurfaces') {
      await openSurfaceSettings();
      return;
    }
    if (item == 'notifications') {
      await openNotificationSettings();
      return;
    }
    if (item == 'presets') {
      await openPresetSettings();
      return;
    }
    if (item == 'threshold') {
      openThresholdSettings(prefs.threshold);
      return;
    }
    if (item == 'beatMinutes') {
      await AppPop.sheet<void>(
        title: '节拍间隔',
        material: CommonSurfaceMaterial.glass,
        child: _BeatMinutesSheet(mode: TimerMode.values.byName(group)),
      );
      return;
    }
    if (const ['interval', 'shortInterval', 'totalRounds'].contains(item)) {
      final initial = item == 'interval'
          ? prefs.interval
          : item == 'shortInterval'
          ? prefs.shortInterval
          : prefs.totalRounds;
      await AppPop.sheet<void>(
        title: item == 'interval'
            ? '长休间隔'
            : item == 'shortInterval'
            ? '短休频率'
            : '总专注轮数',
        material: CommonSurfaceMaterial.glass,
        child: _RoundsSheet(
          initial: initial,
          total: item == 'totalRounds',
          onSave: (value) => ref
              .read(timingPreferencesProvider.notifier)
              .update(
                (p) => p.copyWith(
                  interval: item == 'interval' ? value : null,
                  shortInterval: item == 'shortInterval' ? value : null,
                  totalRounds: item == 'totalRounds' ? value : null,
                ),
              ),
        ),
      );
      return;
    }
    await pickYikeDuration(
      title: item == 'focus'
          ? '专注时长'
          : item == 'short'
          ? '短休息'
          : '长休息',
      initial: item == 'focus'
          ? prefs.focusSeconds
          : item == 'short'
          ? prefs.shortSeconds
          : prefs.longSeconds,
      minimum: 1,
      maximum: maxFocusSeconds,
      hours: false,
      seconds: true,
      autoSave: true,
      onConfirm: (value) => ref
          .read(timingPreferencesProvider.notifier)
          .update(
            (p) => p.copyWith(
              focusSeconds: item == 'focus' ? value : null,
              shortSeconds: item == 'short' ? value : null,
              longSeconds: item == 'long' ? value : null,
            ),
          ),
    );
  }

  void _change(String group, String item, bool value) {
    ref.read(timingPreferencesProvider.notifier).update((p) {
      if (group == 'feedback') {
        return p.copyWith(
          sound: item == 'sound' ? value : null,
          haptics: item == 'haptics' ? value : null,
        );
      }
      FeedbackOptions change(FeedbackOptions options) => options.copyWith(
        sound: item == 'sound' ? value : null,
        haptics: item == 'haptics' ? value : null,
        secondTick: item == 'secondTick' ? value : null,
      );
      if (group == 'habits') {
        return p.copyWith(habitFeedback: change(p.habitFeedback));
      }
      final mode = TimerMode.values.byName(group);
      return p.withFeedback(mode, change(p.feedbackFor(mode)));
    });
  }

  List<CommonListItem> _feedbackItems(
    TimingPreferences master,
    FeedbackOptions options, {
    bool timer = true,
  }) => [
    CommonListItem(
      id: 'sound',
      title: '提示音',
      switchValue: options.sound,
      disabled: !master.sound,
    ),
    CommonListItem(
      id: 'haptics',
      title: '触感',
      switchValue: options.haptics,
      disabled: !master.haptics,
    ),
    if (timer)
      CommonListItem(
        id: 'secondTick',
        title: '每秒滴答',
        switchValue: options.secondTick,
        disabled: !master.sound || !options.sound,
      ),
    if (timer)
      CommonListItem(
        id: 'beatMinutes',
        title: '节拍间隔',
        value: options.beatMinutes == 0 ? '关闭' : '${options.beatMinutes} 分钟',
        navigation: true,
      ),
  ];

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ts = TS.of(context);
    final sheet = AppSheet<bool>();
    final result = await sheet.show(
      title: '重置所有数据？',
      material: CommonSurfaceMaterial.glass,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '清除当前会话、历史和用户习惯，恢复默认配置与四个预置习惯。此操作无法撤销。',
            style: ts.textStyle.content,
          ),
          SizedBox(height: ts.spacing.md),
          CommonDecisionActions(
            actions: [
              CommonButton(
                label: '取消',
                kind: CommonButtonKind.secondary,
                onPressed: sheet.dismiss,
              ),
              CommonButton(
                label: '确认重置',
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
    if (result != true || !context.mounted) return;
    if (!resetYikeData(ref)) return;
    Navigator.of(context).popUntil(
      (route) => route.settings.name == AppRoutes.home || route.isFirst,
    );
  }
}

class _BeatMinutesSheet extends ConsumerWidget {
  const _BeatMinutesSheet({required this.mode});
  final TimerMode mode;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppSheetContent(
    body: CommonRadioGroup<int>(
      value: ref.watch(
        timingPreferencesProvider.select(
          (p) => p.feedbackFor(mode).beatMinutes,
        ),
      ),
      options: [
        for (final value in const [0, 1, 5, 10, 15])
          CommonChoiceOption(
            value: value,
            label: value == 0 ? '关闭' : '$value 分钟',
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          ref
              .read(timingPreferencesProvider.notifier)
              .update(
                (p) => p.withFeedback(
                  mode,
                  p.feedbackFor(mode).copyWith(beatMinutes: value),
                ),
              );
        }
      },
    ),
  );
}

class _RoundsSheet extends ConsumerStatefulWidget {
  const _RoundsSheet({
    required this.initial,
    required this.total,
    required this.onSave,
  });
  final int initial;
  final bool total;
  final bool Function(int) onSave;
  @override
  ConsumerState<_RoundsSheet> createState() => _RoundsSheetState();
}

class _RoundsSheetState extends ConsumerState<_RoundsSheet> {
  late final _value = localValueProvider(widget.initial);
  final _error = localValueProvider(false);
  @override
  Widget build(BuildContext context) => AppSheetContent(
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CommonWheelPicker(
          filled: true,
          visibleRows: MediaQuery.sizeOf(context).height < 700 ? 3 : 5,
          columns: [
            CommonWheelColumn(
              id: 'rounds',
              label: widget.total ? '总专注轮数' : '休息频率',
              options: [
                CommonWheelOption(
                  value: 0,
                  label: widget.total ? '不限轮数' : '关闭',
                ),
                for (var i = 1; i <= maxPomodoroRounds; i++)
                  CommonWheelOption(
                    value: i,
                    label: widget.total ? '$i 轮' : '每 $i 轮',
                  ),
              ],
            ),
          ],
          values: [ref.watch(_value)],
          onChanged: (values) =>
              ref.read(_value.notifier).set(values.first as int),
          onSettled: (values) => ref
              .read(_error.notifier)
              .set(!widget.onSave(values.first as int)),
        ),
        MotionExpand(
          expanded: ref.watch(_error),
          child: Text(
            '尚未保存，请重试',
            style: TS
                .of(context)
                .textStyle
                .caption
                .copyWith(color: TS.of(context).colors.error),
          ),
        ),
      ],
    ),
  );
}

Future<void> openPresetSettings() => AppPop.sheet<void>(
  title: '常用倒计时',
  material: CommonSurfaceMaterial.glass,
  child: const CountdownPresetEditor(),
);

// The shared FlowSheet owns the step stack; Riverpod owns every editable value.
class _SettingsFlowPage extends FlowSheetPage<void> {
  const _SettingsFlowPage({required super.id, required this.builder});
  final WidgetBuilder builder;
  @override
  State<_SettingsFlowPage> createState() => _SettingsFlowPageState();
}

class _SettingsFlowPageState extends State<_SettingsFlowPage> {
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Builder(builder: widget.builder),
  );
}

void openThresholdSettings(int initial) {
  final controller = FlowSheetController<void>();
  void custom() => controller.push(
    _SettingsFlowPage(
      id: 'threshold-custom',
      builder: (_) =>
          _ThresholdCustom(controller: controller, initial: initial),
    ),
  );
  AppPop.flowSheet<void>(
    controller: controller,
    title: '记录确认阈值',
    pageTitles: const {'threshold-custom': '自定义时长'},
    material: CommonSurfaceMaterial.glass,
    headerStart: CommonIconButton(
      name: CommonIconName.slidersHorizontal,
      label: '自定义时长',
      variant: CommonIconButtonVariant.tonal,
      onPressed: custom,
    ),
    initialPage: _SettingsFlowPage(
      id: 'threshold-options',
      builder: (_) =>
          _ThresholdOptions(controller: controller, initial: initial),
    ),
  );
}

class _ThresholdOptions extends ConsumerStatefulWidget {
  const _ThresholdOptions({required this.controller, required this.initial});
  final FlowSheetController<void> controller;
  final int initial;
  @override
  ConsumerState<_ThresholdOptions> createState() => _ThresholdOptionsState();
}

class _ThresholdOptionsState extends ConsumerState<_ThresholdOptions> {
  late final _value = localValueProvider(widget.initial);
  final _saveFailed = localValueProvider(false);
  @override
  Widget build(BuildContext context) {
    final options = {5, 10, 60, 180, 300, 600, widget.initial}.toList()..sort();
    return CommonFlowSheetContent(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommonWheelPicker(
            visibleRows: 3,
            filled: true,
            columns: [
              CommonWheelColumn(
                id: 'threshold',
                label: '记录确认阈值',
                options: [
                  for (final value in options)
                    CommonWheelOption(
                      value: value,
                      label: durationLabel(value),
                    ),
                ],
              ),
            ],
            values: [ref.watch(_value)],
            onChanged: (v) => ref.read(_value.notifier).set(v.first as int),
            onSettled: (v) {
              final saved = ref
                  .read(timingPreferencesProvider.notifier)
                  .update((p) => p.copyWith(threshold: v.first as int));
              ref.read(_saveFailed.notifier).set(!saved);
            },
          ),
          MotionExpand(
            expanded: ref.watch(_saveFailed),
            child: Text(
              '尚未保存，请重试；关闭后可能丢失',
              style: TS
                  .of(context)
                  .textStyle
                  .caption
                  .copyWith(color: TS.of(context).colors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdCustom extends ConsumerStatefulWidget {
  const _ThresholdCustom({required this.controller, required this.initial});
  final FlowSheetController<void> controller;
  final int initial;
  @override
  ConsumerState<_ThresholdCustom> createState() => _ThresholdCustomState();
}

class _ThresholdCustomState extends ConsumerState<_ThresholdCustom> {
  late final _value = localValueProvider(widget.initial);
  final _invalid = localValueProvider(false);
  final _saveFailed = localValueProvider(false);
  @override
  Widget build(BuildContext context) => CommonFlowSheetContent(
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DurationWheels(
          filled: true,
          onSettled: (value) {
            ref.read(_invalid.notifier).set(value < 1);
            if (value < 1) return;
            final saved = ref
                .read(timingPreferencesProvider.notifier)
                .update((p) => p.copyWith(threshold: value));
            ref.read(_saveFailed.notifier).set(!saved);
          },
          value: ref.watch(_value),
          onChanged: (value) {
            ref.read(_value.notifier).set(value);
            ref.read(_invalid.notifier).set(false);
          },
        ),
        MotionExpand(
          expanded: ref.watch(_invalid),
          child: Text(
            '至少选择 1 秒',
            style: TS
                .of(context)
                .textStyle
                .caption
                .copyWith(color: TS.of(context).colors.error),
          ),
        ),
        MotionExpand(
          expanded: ref.watch(_saveFailed),
          child: Text(
            '尚未保存，请重试；关闭后可能丢失',
            style: TS
                .of(context)
                .textStyle
                .caption
                .copyWith(color: TS.of(context).colors.error),
          ),
        ),
      ],
    ),
  );
}
