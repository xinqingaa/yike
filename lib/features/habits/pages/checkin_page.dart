import '../../../app/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motion/motion_list.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../router/routes.dart';
import '../../../theme/ts.dart';
import '../models/habit_view.dart';
import '../providers/habits_presentation.dart';
import '../widgets/habit_icon.dart';
import '../widgets/habit_checkin_card.dart';
import 'habit_editor.dart';

class CheckinPage extends ConsumerWidget {
  const CheckinPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = TS.of(context);
    final habits = ref.watch(habitsProvider);
    final targets = ref.watch(habitReminderTargetsProvider);
    final active = [
      ...habits.where((h) => !h.archived && targets.contains(h.id)),
      ...habits.where((h) => !h.archived && !targets.contains(h.id)),
    ];
    final archived = habits.where((h) => h.archived).length;
    final today = ref.watch(todayProvider);
    final done = active.where((h) => h.dates.contains(dayId(today))).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            ts.spacing.lg,
            ts.spacing.lg,
            ts.spacing.lg,
            ts.spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '打卡',
                      key: const ValueKey('checkin-header'),
                      style: ts.textStyle.headline,
                    ),
                    Text(
                      '今天 $done / ${active.length} · ${active.isEmpty
                          ? '还没有习惯'
                          : done == active.length
                          ? '今天都完成了'
                          : '还剩 ${active.length - done} 个'}',
                      style: ts.textStyle.content.copyWith(
                        color: ts.colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              CommonIconButton(
                name: CommonIconName.plus,
                label: '新建习惯',
                variant: CommonIconButtonVariant.text,
                onPressed: () => openHabitEditor(),
              ),
            ],
          ),
        ),
        Expanded(
          child: MotionList<Object>(
            key: const PageStorageKey('checkin-scroll'),
            scrollToStartToken: targets.join('|'),
            items: [if (active.isEmpty) 'empty', ...active, 'archive'],
            identity: (item) => item is HabitViewData ? item.id : item,
            padding: EdgeInsets.fromLTRB(
              ts.spacing.lg,
              0,
              ts.spacing.lg,
              ts.spacing.lg,
            ),
            itemBuilder: (context, item) {
              if (item == 'empty') {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: ts.spacing.lg),
                  child: Text(
                    '还没有进行中的习惯，点击右上角新建。',
                    style: ts.textStyle.content,
                  ),
                );
              }
              if (item == 'archive') {
                return Padding(
                  padding: EdgeInsets.only(top: ts.spacing.md),
                  child: CommonListCell(
                    title: '已归档习惯',
                    value: archived == 0 ? '查看与恢复' : '$archived 个习惯 · 查看与恢复',
                    navigation: true,
                    onNavigate: () => _showArchived(context, ref),
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.only(top: ts.spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (targets.contains((item as HabitViewData).id))
                      Text('提醒的习惯', style: ts.textStyle.caption),
                    HabitCheckinCard(habit: item, today: today),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showArchived(BuildContext context, WidgetRef ref) {
    final navigator = Navigator.of(context);
    final sheet = AppSheet<void>();
    sheet.show(
      title: '已归档习惯',
      material: CommonSurfaceMaterial.glass,
      child: Consumer(
        builder: (context, ref, _) {
          final ts = TS.of(context);
          final habits = ref
              .watch(habitsProvider)
              .where((h) => h.archived)
              .toList();
          if (habits.isEmpty) {
            return Text('没有已归档习惯', style: ts.textStyle.content);
          }
          return CommonDataList(
            itemCount: habits.length,
            shrinkWrap: true,
            surface: CommonDataListSurface.none,
            itemBuilder: (context, index) => CommonListCell(
              title: habits[index].name,
              description: habits[index].frequency,
              value: '查看与恢复',
              navigation: true,
              leading: HabitGlyph(icon: habits[index].icon),
              onNavigate: () async {
                await sheet.dismiss();
                if (navigator.mounted) {
                  navigator.pushNamed(
                    AppRoutes.habitDetail,
                    arguments: habits[index].id,
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
