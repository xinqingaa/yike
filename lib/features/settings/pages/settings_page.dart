import '../../../common/motion/content_transition.dart';
import '../../focus/focus.dart';
import '../../../app/reset_data.dart';
import '../../../common/time.dart';
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

class YikeSettingsPage extends ConsumerWidget {
  const YikeSettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = TS.of(context);
    final pack = ref.watch(themePackProvider);
    final mode = ref.watch(themeModeProvider);
    final prefs = ref.watch(timingPreferencesProvider);
    final packs = ref
        .watch(themePacksProvider)
        .where((p) => p.id.startsWith('yike/'))
        .toList();
    return Scaffold(
      appBar: CommonAppBar(
        title: '',
        dense: true,
        showBack: true,
        background: CommonAppBarSurface.transparent,
      ),
      body: YikePageWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            ts.spacing.lg,
            0,
            ts.spacing.lg,
            ts.spacing.lg,
          ),
          children: [
            Text('设置', style: ts.textStyle.titleLg),
            SizedBox(height: ts.spacing.md),
            Text('外观', style: ts.textStyle.caption),
            SizedBox(height: ts.spacing.xs),
            Text('表盘', style: ts.textStyle.subtitle),
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
            Text('显示模式', style: ts.textStyle.subtitle),
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
            CommonGroupedList(
              groups: [
                CommonListGroup(
                  id: 'pomodoro',
                  title: '番茄钟',
                  items: [
                    CommonListItem(
                      id: 'focus',
                      title: '专注时长',
                      value: durationLabel(prefs.focusMinutes * 60),
                      navigation: true,
                    ),
                    CommonListItem(
                      id: 'short',
                      title: '短休息',
                      value: durationLabel(prefs.shortMinutes * 60),
                      navigation: true,
                    ),
                    CommonListItem(
                      id: 'long',
                      title: '长休息',
                      value: durationLabel(prefs.longMinutes * 60),
                      navigation: true,
                    ),
                    CommonListItem(
                      id: 'interval',
                      title: '长休间隔',
                      value: '每 ${prefs.interval} 轮',
                      navigation: true,
                    ),
                  ],
                ),
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
                CommonListGroup(
                  id: 'feedback',
                  title: '记录与反馈',
                  items: [
                    CommonListItem(
                      id: 'threshold',
                      title: '短时记录确认阈值',
                      value: durationLabel(prefs.threshold),
                      navigation: true,
                    ),
                    CommonListItem(
                      id: 'sound',
                      title: '提示音',
                      switchValue: prefs.sound,
                    ),
                  ],
                ),
              ],
              onNavigate: (group, item) async {
                if (item == 'presets') {
                  openPresetSettings();
                  return;
                }
                if (item == 'threshold') {
                  openThresholdSettings(prefs.threshold);
                  return;
                }
                if (item == 'interval') {
                  await AppPop.sheet<int>(
                    title: '长休间隔',
                    material: CommonSurfaceMaterial.glass,
                    child: _IntervalSheet(
                      initial: prefs.interval,
                      onSave: (value) {
                        final saved = ref
                            .read(timingPreferencesProvider.notifier)
                            .update((p) => p.copyWith(interval: value));
                        return saved;
                      },
                    ),
                  );
                  return;
                }
                final initial = item == 'focus'
                    ? prefs.focusMinutes
                    : item == 'short'
                    ? prefs.shortMinutes
                    : prefs.longMinutes;
                await pickYikeDuration(
                  title: item == 'focus'
                      ? '专注时长'
                      : item == 'short'
                      ? '短休息'
                      : '长休息',
                  initial: initial * 60,
                  minimum: 60,
                  maximum: (item == 'focus' ? 180 : 60) * 60,
                  seconds: false,
                  autoSave: true,
                  onConfirm: (value) => ref
                      .read(timingPreferencesProvider.notifier)
                      .update(
                        (p) => p.copyWith(
                          focusMinutes: item == 'focus' ? value ~/ 60 : null,
                          shortMinutes: item == 'short' ? value ~/ 60 : null,
                          longMinutes: item == 'long' ? value ~/ 60 : null,
                        ),
                      ),
                );
              },
              onChanged: (_, item, value) => ref
                  .read(timingPreferencesProvider.notifier)
                  .update((p) => p.copyWith(sound: value)),
            ),
            SizedBox(height: ts.spacing.md),
            CommonDataList(
              itemCount: 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) => Semantics(
                button: true,
                child: InkWell(
                  onTap: () => _reset(context, ref),
                  child: Padding(
                    padding: EdgeInsets.all(ts.spacing.md),
                    child: Text(
                      '重置所有数据',
                      style: ts.textStyle.content.copyWith(
                        color: ts.colors.error,
                      ),
                    ),
                  ),
                ),
              ),
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
    );
  }

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

class _IntervalSheet extends ConsumerStatefulWidget {
  const _IntervalSheet({required this.initial, required this.onSave});
  final int initial;
  final bool Function(int) onSave;
  @override
  ConsumerState<_IntervalSheet> createState() => _IntervalSheetState();
}

class _IntervalSheetState extends ConsumerState<_IntervalSheet> {
  late final _value = localValueProvider(widget.initial);
  final _saveFailed = localValueProvider(false);
  @override
  Widget build(BuildContext context) => AppSheetContent(
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CommonWheelPicker(
          visibleRows: 3,
          filled: true,
          columns: [
            CommonWheelColumn(
              id: 'interval',
              label: '长休间隔',
              unit: '轮',
              numeric: true,
              options: [
                for (var i = 2; i <= 8; i++)
                  CommonWheelOption(value: i, label: '$i'),
              ],
            ),
          ],
          values: [ref.watch(_value)],
          onChanged: (v) => ref.read(_value.notifier).set(v.first as int),
          onSettled: (v) => ref
              .read(_saveFailed.notifier)
              .set(!widget.onSave(v.first as int)),
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

void openPresetSettings() {
  final controller = FlowSheetController<void>();
  AppPop.flowSheet<void>(
    controller: controller,
    title: '常用倒计时',
    pageTitles: const {'preset-edit': '编辑常用倒计时'},
    material: CommonSurfaceMaterial.glass,
    initialPage: _SettingsFlowPage(
      id: 'preset-list',
      builder: (_) => _PresetList(controller: controller),
    ),
  );
}

class _PresetList extends ConsumerWidget {
  const _PresetList({required this.controller});
  final FlowSheetController<void> controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(timingPreferencesProvider);
    final ts = TS.of(context);
    return CommonFlowSheetContent(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 4; i++)
            CommonListCell(
              title: '常用 ${i + 1}',
              value: prefs.presets[i] == null
                  ? '空'
                  : durationLabel(prefs.presets[i]!),
              navigation: true,
              onNavigate: () => controller.push(
                _SettingsFlowPage(
                  id: 'preset-edit',
                  builder: (_) => _PresetEdit(index: i, controller: controller),
                ),
              ),
            ),
          SizedBox(height: ts.spacing.md),
          CommonButton(
            label: '恢复默认',
            kind: CommonButtonKind.quiet,
            onPressed: () => ref
                .read(timingPreferencesProvider.notifier)
                .update(
                  (p) => p.copyWith(presets: const [180, 300, 600, 1200]),
                ),
          ),
        ],
      ),
    );
  }
}

class _PresetEdit extends ConsumerStatefulWidget {
  const _PresetEdit({required this.index, required this.controller});
  final int index;
  final FlowSheetController<void> controller;
  @override
  ConsumerState<_PresetEdit> createState() => _PresetEditState();
}

class _PresetEditState extends ConsumerState<_PresetEdit> {
  late final _value = localValueProvider(
    ref.read(timingPreferencesProvider).presets[widget.index] ?? 300,
  );
  final _error = localValueProvider<String?>(null);
  void _save(int? value) {
    final prefs = ref.read(timingPreferencesProvider);
    if (value != null && (value < 1 || value > 86399)) {
      ref.read(_error.notifier).set('时长必须为 1 秒至 23 小时 59 分 59 秒');
      return;
    }
    if (value != null &&
        prefs.presets.indexed.any(
          (entry) => entry.$1 != widget.index && entry.$2 == value,
        )) {
      ref.read(_error.notifier).set('这个时长已在其它常用项中');
      return;
    }
    final next = [...prefs.presets];
    next[widget.index] = value;
    final saved = ref
        .read(timingPreferencesProvider.notifier)
        .set(prefs.copyWith(presets: next));
    if (saved && value == null) widget.controller.pop();
    if (!saved) {
      ref.read(_error.notifier).set('尚未保存，请重试；关闭后可能丢失');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return CommonFlowSheetContent(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DurationWheels(
            filled: true,
            value: ref.watch(_value),
            onSettled: _save,
            onChanged: (v) {
              ref.read(_value.notifier).set(v);
              ref.read(_error.notifier).set(null);
            },
          ),
          CommonButton(
            label: '清空此项',
            kind: CommonButtonKind.quiet,
            onPressed: () => _save(null),
          ),
          MotionExpand(
            expanded: ref.watch(_error) != null,
            child: Text(
              ref.watch(_error) ?? '',
              style: ts.textStyle.caption.copyWith(color: ts.colors.error),
            ),
          ),
        ],
      ),
    );
  }
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
