import '../../focus/focus.dart';
import '../../../app/reset_data.dart';
import '../../../common/time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unified_popups/unified_popups.dart'
    show FlowSheetPage, FlowSheetController;
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
                  openPresetSettings(context);
                  return;
                }
                if (item == 'threshold') {
                  openThresholdSettings(context, prefs.threshold);
                  return;
                }
                if (item == 'interval') {
                  await AppPop.sheet<int>(
                    context,
                    title: '长休间隔',
                    material: CommonSurfaceMaterial.glass,
                    builder: (context, handle) => _IntervalSheet(
                      initial: prefs.interval,
                      onSave: (value) {
                        final saved = ref
                            .read(timingPreferencesProvider.notifier)
                            .update((p) => p.copyWith(interval: value));
                        if (saved) handle.complete(value);
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
                  context,
                  title: item == 'focus'
                      ? '专注时长'
                      : item == 'short'
                      ? '短休息'
                      : '长休息',
                  initial: initial * 60,
                  minimum: 60,
                  maximum: (item == 'focus' ? 180 : 60) * 60,
                  seconds: false,
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
    final result = await AppPop.sheet<bool>(
      context,
      title: '重置所有数据？',
      material: CommonSurfaceMaterial.glass,
      builder: (context, handle) => AppSheetContent(
        body: Text(
          '清除当前会话、历史和用户习惯，恢复默认配置与四个预置习惯。此操作无法撤销。',
          style: TS.of(context).textStyle.content,
        ),
        actions: CommonDecisionActions(
          actions: [
            CommonButton(
              label: '取消',
              kind: CommonButtonKind.secondary,
              onPressed: handle.dismiss,
            ),
            CommonButton(
              label: '确认重置',
              kind: CommonButtonKind.outlined,
              destructive: true,
              shape: CommonButtonShape.pill,
              onPressed: () => handle.complete(true),
            ),
          ],
        ),
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
      children: [
        CommonWheelPicker(
          visibleRows: 3,
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
        ),
        if (ref.watch(_saveFailed))
          Text(
            '尚未保存，请重试；关闭后可能丢失',
            style: TS
                .of(context)
                .textStyle
                .caption
                .copyWith(color: TS.of(context).colors.error),
          ),
      ],
    ),
    actions: CommonButton(
      label: '确认',
      kind: CommonButtonKind.accent,
      block: true,
      onPressed: () {
        if (!widget.onSave(ref.read(_value))) {
          ref.read(_saveFailed.notifier).set(true);
        }
      },
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

void openPresetSettings(BuildContext context) {
  final controller = FlowSheetController<void>();
  AppPop.flowSheet<void>(
    context,
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
      actions: [
        CommonButton(
          label: '完成',
          size: CommonControlSize.lg,
          shape: CommonButtonShape.pill,
          kind: CommonButtonKind.accent,
          block: true,
          onPressed: controller.closeAll,
        ),
      ],
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
    if (saved) {
      widget.controller.pop();
    } else {
      ref.read(_error.notifier).set('尚未保存，请重试；关闭后可能丢失');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return CommonFlowSheetContent(
      body: Column(
        children: [
          DurationWheels(
            value: ref.watch(_value),
            onChanged: (v) {
              ref.read(_value.notifier).set(v);
              ref.read(_error.notifier).set(null);
            },
          ),
          if (ref.watch(_error) != null)
            Text(
              ref.watch(_error)!,
              style: ts.textStyle.caption.copyWith(color: ts.colors.error),
            ),
        ],
      ),
      actions: [
        CommonButton(
          label: '清空此项',
          kind: CommonButtonKind.quiet,
          onPressed: () => _save(null),
        ),
        CommonButton(
          label: '保存',
          size: CommonControlSize.lg,
          shape: CommonButtonShape.pill,
          kind: CommonButtonKind.accent,
          block: true,
          onPressed: () => _save(ref.read(_value)),
        ),
      ],
    );
  }
}

void openThresholdSettings(BuildContext context, int initial) {
  final controller = FlowSheetController<void>();
  void custom() => controller.push(
    _SettingsFlowPage(
      id: 'threshold-custom',
      builder: (_) =>
          _ThresholdCustom(controller: controller, initial: initial),
    ),
  );
  AppPop.flowSheet<void>(
    context,
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
        children: [
          CommonWheelPicker(
            visibleRows: 3,
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
          ),
          if (ref.watch(_saveFailed))
            Text(
              '尚未保存，请重试；关闭后可能丢失',
              style: TS
                  .of(context)
                  .textStyle
                  .caption
                  .copyWith(color: TS.of(context).colors.error),
            ),
        ],
      ),
      actions: [
        CommonButton(
          label: '确认',
          size: CommonControlSize.lg,
          shape: CommonButtonShape.pill,
          kind: CommonButtonKind.accent,
          block: true,
          onPressed: () {
            final saved = ref
                .read(timingPreferencesProvider.notifier)
                .update((p) => p.copyWith(threshold: ref.read(_value)));
            if (saved) {
              widget.controller.closeAll();
            } else {
              ref.read(_saveFailed.notifier).set(true);
            }
          },
        ),
      ],
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
      children: [
        DurationWheels(
          value: ref.watch(_value),
          onChanged: (value) {
            ref.read(_value.notifier).set(value);
            ref.read(_invalid.notifier).set(false);
          },
        ),
        if (ref.watch(_invalid))
          Text(
            '至少选择 1 秒',
            style: TS
                .of(context)
                .textStyle
                .caption
                .copyWith(color: TS.of(context).colors.error),
          ),
        if (ref.watch(_saveFailed))
          Text(
            '尚未保存，请重试；关闭后可能丢失',
            style: TS
                .of(context)
                .textStyle
                .caption
                .copyWith(color: TS.of(context).colors.error),
          ),
      ],
    ),
    actions: [
      CommonButton(
        label: '确认',
        size: CommonControlSize.lg,
        shape: CommonButtonShape.pill,
        kind: CommonButtonKind.accent,
        block: true,
        onPressed: () {
          final value = ref.read(_value);
          if (value < 1) {
            ref.read(_invalid.notifier).set(true);
            return;
          }
          final saved = ref
              .read(timingPreferencesProvider.notifier)
              .update((p) => p.copyWith(threshold: value));
          if (saved) {
            widget.controller.closeAll();
          } else {
            ref.read(_saveFailed.notifier).set(true);
          }
        },
      ),
    ],
  );
}
