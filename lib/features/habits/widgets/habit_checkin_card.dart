import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motion/content_transition.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../router/routes.dart';
import '../../../theme/ts.dart';
import '../../local_data/local_data.dart';
import '../models/habit_view.dart';
import '../providers/habits_presentation.dart';
import 'checkin_feedback.dart';
import 'habit_icon.dart';

class HabitCheckinCard extends ConsumerWidget {
  const HabitCheckinCard({super.key, required this.habit, required this.today});
  final HabitViewData habit;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = TS.of(context), id = dayId(today), start = weekStart(today);
    final weekly = habit.dates
        .where((d) => d.compareTo(dayId(start)) >= 0 && d.compareTo(id) <= 0)
        .length;
    final checked = habit.dates.contains(id);
    return CommonGlassSurface(
      borderRadius: BorderRadius.circular(ts.radius.lg),
      child: Padding(
        padding: EdgeInsets.all(ts.spacing.smPlus),
        child: Column(
          children: [
            InkWell(
              key: ValueKey('habit-detail-${habit.id}'),
              borderRadius: BorderRadius.circular(ts.radius.sm),
              onTap: () async {
                await AppPop.clearToasts();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.habitDetail, arguments: habit.id);
                }
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: ts.sizing.touch),
                child: Row(
                  children: [
                    HabitGlyph(icon: habit.icon),
                    SizedBox(width: ts.spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(habit.name, style: ts.textStyle.subtitle),
                          Text(
                            '${habit.frequency} · 本周 $weekly${habit.weekly ? '/${habit.goal}' : ''} 次',
                            style: ts.textStyle.caption,
                          ),
                        ],
                      ),
                    ),
                    const CommonIcon(name: CommonIconName.chevronRight),
                  ],
                ),
              ),
            ),
            SizedBox(height: ts.spacing.sm),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: _WeekDay(
                            date: start.add(Duration(days: i)),
                            habit: habit,
                            today: today,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: ts.spacing.sm),
                Semantics(
                  container: true,
                  selected: checked,
                  child: CheckinFeedback(
                    key: ValueKey('feedback-${habit.id}'),
                    checked: checked,
                    habitId: habit.id,
                    child: CommonIconButton(
                      key: ValueKey('check-${habit.id}'),
                      name: checked
                          ? CommonIconName.check
                          : habitIconName(habit.icon),
                      label: checked ? '取消${habit.name}打卡' : '为${habit.name}打卡',
                      variant: checked
                          ? CommonIconButtonVariant.tonal
                          : CommonIconButtonVariant.outlined,
                      onPressed: () {
                        final ticket = ref
                            .read(habitsProvider.notifier)
                            .toggle(
                              habit.id,
                              id,
                              undoDuration: ts.motion.durationToast,
                            );
                        if (ticket == null) return;
                        AppPop.toast(
                          '「${habit.name}」${checked ? '已取消打卡' : '今天已打卡'}${ref.read(localDataProvider).writeError == null ? '' : '（尚未保存）'}',
                          actionLabel: '撤销',
                          replacementKey: 'habit-checkin',
                          bottomInset:
                              ts.sizing.bottomNavigation +
                              ts.spacing.md +
                              ts.spacing.xs,
                          onAction: () {
                            if (context.mounted) {
                              ref.read(habitsProvider.notifier).undo(ticket);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.date,
    required this.habit,
    required this.today,
  });
  final DateTime date, today;
  final HabitViewData habit;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context), id = dayId(date);
    final done = habit.dates.contains(id),
        current = id == dayId(today),
        before = id.compareTo(habit.created) < 0,
        future = date.isAfter(today);
    final label = weekdayLabel(date);
    return Semantics(
      label:
          '$id，周$label，${current ? '今天，' : ''}${done
              ? '已完成'
              : before
              ? '创建前'
              : future
              ? '尚未到来'
              : '未打卡'}',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: ts.spacing.xs / 2),
          child: AnimatedContainer(
            duration: motionEnabled(context)
                ? ts.motion.durationFast
                : Duration.zero,
            curve: ts.motion.easingStandard,
            constraints: BoxConstraints(minHeight: ts.sizing.controlSm),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? ts.colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(ts.radius.sm),
              border: current
                  ? Border.all(
                      color: ts.colors.primary,
                      width: ts.border.widthHairline,
                    )
                  : null,
            ),
            child: Opacity(
              opacity: future || before ? ts.opacity.disabled : 1,
              child: Text(
                label,
                style: ts.textStyle.caption.copyWith(
                  color: done
                      ? ts.colors.onPrimary
                      : current
                      ? ts.colors.primary
                      : ts.colors.onSurfaceMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
