import '../models/habit_view.dart';
import '../providers/habits_presentation.dart';
import '../../../common/time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unified_popups/unified_popups.dart'
    show SheetSizeConfig, SheetDimension;
import '../../../common/state/local_value.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/widgets.dart';
import '../../../common/widgets/yike/layout.dart';
import '../../../theme/ts.dart';
import '../widgets/habit_icon.dart';

Future<bool?> openHabitEditor(BuildContext context, {HabitViewData? habit}) =>
    AppPop.sheet<bool>(
      context,
      title: habit == null ? '新建习惯' : '编辑习惯',
      material: CommonSurfaceMaterial.glass,
      size: SheetSizeConfig(
        height: SheetDimension.fraction(TS.of(context).sizing.panelLarge),
      ),
      builder: (context, handle) =>
          HabitEditor(habit: habit, onSaved: () => handle.complete(true)),
    );

class HabitEditor extends ConsumerStatefulWidget {
  const HabitEditor({super.key, this.habit, required this.onSaved});
  final HabitViewData? habit;
  final VoidCallback onSaved;
  @override
  ConsumerState<HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<HabitEditor> {
  late final initial =
      widget.habit ??
      HabitViewData(
        id: 'habit-${DateTime.now().microsecondsSinceEpoch}',
        name: '',
        created: dayId(ref.read(todayProvider)),
      );
  late final _draft = localValueProvider(initial);
  final _submitted = localValueProvider(false);
  late final _name = TextEditingController(text: initial.name);
  late final _time = TextEditingController(
    text:
        '${(initial.reminderMinutes ~/ 60).toString().padLeft(2, '0')}:${(initial.reminderMinutes % 60).toString().padLeft(2, '0')}',
  );
  final _timeError = localValueProvider<String?>(null);
  @override
  void dispose() {
    _name.dispose();
    _time.dispose();
    super.dispose();
  }

  void _change(HabitViewData value) => ref.read(_draft.notifier).set(value);
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final draft = ref.watch(_draft);
    final submitted = ref.watch(_submitted);
    final nameError = submitted && draft.name.trim().isEmpty
        ? '写一个习惯名称'
        : draft.name.trim().characters.length > 30
        ? '名称最多 30 个字符'
        : null;
    return YikeSheetBody(
      expand: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommonTextField(
            controller: _name,
            label: '习惯名称',
            showLabel: true,
            hint: '比如，读 20 页书',
            errorText: nameError,
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
          if (draft.weekly) ...[
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
              onChanged: (v) => _change(draft.copyWith(goal: v.first as int)),
            ),
          ],
          SizedBox(height: ts.spacing.lg),
          CommonListCell(
            title: '提醒',
            switchValue: draft.reminder,
            onSwitchChanged: (v) => _change(draft.copyWith(reminder: v)),
          ),
          if (draft.reminder)
            CommonTextField(
              controller: _time,
              label: '提醒时间',
              showLabel: true,
              keyboardType: TextInputType.datetime,
              errorText: ref.watch(_timeError),
              onChanged: (value) {
                final parts = value.split(':');
                final h = parts.length == 2 ? int.tryParse(parts.first) : null;
                final m = parts.length == 2 ? int.tryParse(parts.last) : null;
                if (h == null ||
                    m == null ||
                    h < 0 ||
                    h > 23 ||
                    m < 0 ||
                    m > 59) {
                  ref.read(_timeError.notifier).set('输入有效时间，例如 21:00');
                } else {
                  ref.read(_timeError.notifier).set(null);
                  _change(draft.copyWith(reminderMinutes: h * 60 + m));
                }
              },
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
          final draft = ref.read(_draft);
          ref.read(_submitted.notifier).set(true);
          if (draft.name.trim().isEmpty ||
              draft.name.trim().characters.length > 30 ||
              (draft.reminder && ref.read(_timeError) != null)) {
            return;
          }
          ref
              .read(habitsProvider.notifier)
              .save(draft.copyWith(name: draft.name.trim()));
          widget.onSaved();
        },
      ),
    );
  }
}
