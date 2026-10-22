import '../../../app/navigation.dart';
import '../providers/habits_presentation.dart';
import '../../../common/time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/widgets.dart';
import '../../../router/routes.dart';
import '../../../theme/ts.dart';
import '../widgets/habit_icon.dart';
import 'habit_editor.dart';

class CheckinPage extends ConsumerWidget {
  const CheckinPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = TS.of(context);
    final habits = ref.watch(habitsProvider);
    final active = habits.where((h) => !h.archived).toList();
    final archived = habits.where((h) => h.archived).toList();
    final today = ref.watch(todayProvider);
    final id = dayId(today);
    final done = active.where((h) => h.dates.contains(id)).length;
    return CommonDataList(
      key: const PageStorageKey('checkin-scroll'),
      itemCount: active.length + 2,
      surface: CommonDataListSurface.none,
      rounded: CommonDataListRounded.none,
      divided: false,
      padding: EdgeInsets.all(ts.spacing.lg),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('打卡', style: ts.textStyle.headline),
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
                    onPressed: () => openHabitEditor(context),
                  ),
                ],
              ),
              SizedBox(height: ts.spacing.md),
              if (active.isNotEmpty)
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Text(
                          const ['一', '二', '三', '四', '五', '六', '日'][i],
                          textAlign: TextAlign.center,
                          style: ts.textStyle.caption.copyWith(
                            color: i == today.weekday - 1
                                ? ts.colors.primary
                                : ts.colors.onSurfaceMuted,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: ts.sizing.touch + ts.spacing.sm,
                      child: Text(
                        '今天',
                        textAlign: TextAlign.center,
                        style: ts.textStyle.caption,
                      ),
                    ),
                  ],
                )
              else ...[
                Text(
                  '还没有进行中的习惯',
                  style: ts.textStyle.content.copyWith(
                    color: ts.colors.onSurfaceMuted,
                  ),
                ),
                CommonButton(
                  label: '新建习惯',
                  kind: CommonButtonKind.accent,
                  shape: CommonButtonShape.pill,
                  block: true,
                  size: CommonControlSize.lg,
                  onPressed: () => openHabitEditor(context),
                ),
              ],
            ],
          );
        }
        if (index == active.length + 1) {
          return Padding(
            padding: EdgeInsets.only(top: ts.spacing.md),
            child: CommonGroupedList(
              groups: [
                CommonListGroup(
                  id: 'archive',
                  title: '',
                  items: [
                    CommonListItem(
                      id: 'open',
                      title: '已归档习惯',
                      value: archived.isEmpty
                          ? '查看与恢复'
                          : '${archived.length} 个习惯 · 查看与恢复',
                      navigation: true,
                    ),
                  ],
                ),
              ],
              onNavigate: (_, _) => _showArchived(context, ref),
            ),
          );
        }
        final habit = active[index - 1];
        final checked = habit.dates.contains(id);
        final start = dayId(weekStart(today));
        final weeklyCount = habit.dates
            .where((d) => d.compareTo(start) >= 0 && d.compareTo(id) <= 0)
            .length;
        return Padding(
          padding: EdgeInsets.only(top: ts.spacing.sm),
          child: CommonGlassSurface(
            borderRadius: BorderRadius.circular(ts.radius.lg),
            child: Padding(
              padding: EdgeInsets.all(ts.spacing.smPlus),
              child: Column(
                children: [
                  InkWell(
                    key: ValueKey('habit-detail-${habit.id}'),
                    borderRadius: BorderRadius.circular(ts.radius.sm),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.habitDetail, arguments: habit.id),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: ts.spacing.xs),
                      child: Row(
                        children: [
                          HabitGlyph(icon: habit.icon),
                          SizedBox(width: ts.spacing.sm),
                          Expanded(
                            child: Semantics(
                              container: true,
                              button: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    habit.name,
                                    style: ts.textStyle.subtitle,
                                  ),
                                  Text(
                                    '${habit.frequency} · 本周 $weeklyCount 次',
                                    style: ts.textStyle.caption,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const CommonIcon(name: CommonIconName.chevronRight),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: ts.spacing.xs),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Center(
                            child: _WeekDot(
                              done: habit.dates.contains(
                                dayId(weekStart(today).add(Duration(days: i))),
                              ),
                              today: i == today.weekday - 1,
                              future: weekStart(
                                today,
                              ).add(Duration(days: i)).isAfter(today),
                            ),
                          ),
                        ),
                      SizedBox(width: ts.spacing.sm),
                      Semantics(
                        container: true,
                        selected: checked,
                        child: CommonIconButton(
                          key: ValueKey('check-${habit.id}'),
                          name: checked
                              ? CommonIconName.check
                              : habitIconName(habit.icon),
                          label: checked
                              ? '取消${habit.name}打卡'
                              : '为${habit.name}打卡',
                          variant: checked
                              ? CommonIconButtonVariant.tonal
                              : CommonIconButtonVariant.outlined,
                          onPressed: () {
                            ref
                                .read(habitsProvider.notifier)
                                .toggle(habit.id, id);
                            AppPop.toast(
                              context,
                              '「${habit.name}」${checked ? '已取消打卡' : '今天已打卡'}',
                              actionLabel: '撤销',
                              bottomInset:
                                  ts.sizing.bottomNavigation +
                                  ts.spacing.md +
                                  ts.spacing.xs,
                              onAction: () {
                                if (ref.read(rootTabProvider) == 1 &&
                                    dayId(ref.read(todayProvider)) == id) {
                                  ref
                                      .read(habitsProvider.notifier)
                                      .toggle(habit.id, id);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showArchived(BuildContext context, WidgetRef ref) {
    AppPop.sheet<void>(
      context,
      title: '已归档习惯',
      material: CommonSurfaceMaterial.glass,
      builder: (context, handle) => Consumer(
        builder: (context, ref, _) {
          final habits = ref
              .watch(habitsProvider)
              .where((h) => h.archived)
              .toList();
          if (habits.isEmpty) {
            return Text('没有已归档习惯', style: TS.of(context).textStyle.content);
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
                await handle.dismiss();
                if (!context.mounted) return;
                Navigator.of(
                  context,
                ).pushNamed(AppRoutes.habitDetail, arguments: habits[index].id);
              },
            ),
          );
        },
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({
    required this.done,
    required this.today,
    required this.future,
  });
  final bool done, today, future;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final square = ts.pack.id.endsWith('sundial');
    return ExcludeSemantics(
      child: Opacity(
        opacity: future ? ts.opacity.disabled : 1,
        child: Container(
          width: ts.spacing.smPlus,
          height: ts.spacing.smPlus,
          decoration: BoxDecoration(
            shape: square ? BoxShape.rectangle : BoxShape.circle,
            color: done ? ts.colors.primary : Colors.transparent,
            border: Border.all(
              color: today ? ts.colors.primary : ts.colors.onSurfaceMuted,
              width: ts.border.widthHairline,
            ),
          ),
        ),
      ),
    );
  }
}
