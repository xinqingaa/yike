import '../../../common/motion/content_transition.dart';
import '../models/habit_view.dart';
import '../../local_data/local_data.dart';
import '../providers/habit_editor_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/widgets.dart';
import '../../../common/widgets/yike/layout.dart';
import '../../../theme/ts.dart';
import '../widgets/habit_icon.dart';

Future<bool?> openHabitEditor({HabitViewData? habit}) {
  final sheet = AppSheet<bool>();
  return sheet.show(
    title: habit == null ? '新建习惯' : '编辑习惯',
    material: CommonSurfaceMaterial.glass,
    size: const SheetSizeConfig(maxHeight: SheetDimension.fraction(1)),
    child: HabitEditor(habit: habit, onSaved: () => sheet.complete(true)),
  );
}

class HabitEditor extends ConsumerStatefulWidget {
  const HabitEditor({super.key, this.habit, required this.onSaved});
  final HabitViewData? habit;
  final VoidCallback onSaved;
  @override
  ConsumerState<HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<HabitEditor> {
  late final _editor = habitEditorProvider(widget.habit);
  late final _name = TextEditingController(text: ref.read(_editor).draft.name);
  late final _time = TextEditingController(text: ref.read(_editor).timeText);
  @override
  void dispose() {
    _name.dispose();
    _time.dispose();
    super.dispose();
  }

  void _change(HabitViewData value) => ref.read(_editor.notifier).change(value);
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final editor = ref.watch(_editor);
    final draft = editor.draft;
    return AppSheetContent(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MotionExpand(
            expanded:
                ref.watch(localDataProvider.select((s) => s.writeError)) !=
                null,
            child: Text(
              '尚未保存，请重试保存；关闭后可能丢失',
              style: ts.textStyle.caption.copyWith(color: ts.colors.error),
            ),
          ),
          CommonTextField(
            controller: _name,
            label: '习惯名称',
            showLabel: true,
            hint: '比如，读 20 页书',
            errorText: editor.nameError,
            onChanged: (value) => _change(draft.copyWith(name: value)),
          ),
          SizedBox(height: ts.spacing.md),
          Text('图标', style: ts.textStyle.caption),
          SizedBox(height: ts.spacing.sm),
          Wrap(
            spacing: ts.spacing.sm,
            runSpacing: ts.spacing.sm,
            children: [
              for (final icon in HabitIcon.values)
                CommonIconButton(
                  name: habitIconName(icon),
                  label: habitIconLabel(icon),
                  variant: draft.icon == icon
                      ? CommonIconButtonVariant.tonal
                      : CommonIconButtonVariant.outlined,
                  onPressed: () => _change(draft.copyWith(icon: icon)),
                ),
            ],
          ),
          SizedBox(height: ts.spacing.md),
          Text('频率', style: ts.textStyle.captionStrong),
          SizedBox(height: ts.spacing.sm),
          YikeSelectionBar(
            items: const [
              CommonTabItem(value: 'daily', label: '每天'),
              CommonTabItem(value: 'weekly', label: '每周'),
            ],
            value: draft.weekly ? 'weekly' : 'daily',
            onSelected: (v) => _change(draft.copyWith(weekly: v == 'weekly')),
          ),
          MotionExpand(
            expanded: draft.weekly,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: ts.spacing.md),
                Text('每周目标', style: ts.textStyle.caption),
                CommonWheelPicker(
                  columns: [
                    CommonWheelColumn(
                      id: 'goal',
                      label: '每周次数',
                      unit: '次',
                      numeric: true,
                      options: [
                        for (var i = 1; i <= 7; i++)
                          CommonWheelOption(value: i, label: '$i'),
                      ],
                    ),
                  ],
                  values: [draft.goal],
                  onChanged: (v) =>
                      _change(draft.copyWith(goal: v.first as int)),
                ),
              ],
            ),
          ),
          SizedBox(height: ts.spacing.lg),
          CommonListCell(
            title: '提醒',
            switchValue: draft.reminder,
            onSwitchChanged: (v) => _change(draft.copyWith(reminder: v)),
          ),
          MotionExpand(
            expanded: draft.reminder,
            child: CommonTextField(
              controller: _time,
              label: '提醒时间',
              showLabel: true,
              keyboardType: TextInputType.datetime,
              errorText: editor.timeError,
              onChanged: (value) =>
                  ref.read(_editor.notifier).changeTime(value),
            ),
          ),
          SizedBox(height: ts.spacing.lg),
        ],
      ),
      actions: CommonButton(
        label: '保存',
        key: const ValueKey('habit-save'),
        kind: CommonButtonKind.accent,
        size: CommonControlSize.lg,
        block: true,
        shape: CommonButtonShape.pill,
        onPressed: () {
          if (ref.read(_editor.notifier).submit()) widget.onSaved();
        },
      ),
    );
  }
}
