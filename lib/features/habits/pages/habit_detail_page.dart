import '../../../common/motion/content_transition.dart';
import '../providers/habits_presentation.dart';
import '../../../common/time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/widgets.dart';
import '../../../common/widgets/yike/layout.dart';
import '../../../theme/ts.dart';
import '../widgets/habit_icon.dart';
import '../widgets/habit_heatmap.dart';
import 'habit_editor.dart';

class HabitDetailPage extends ConsumerWidget {
  const HabitDetailPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    final habit = ref
        .watch(habitsProvider)
        .where((h) => h.id == id)
        .firstOrNull;
    final ts = TS.of(context);
    final today = ref.watch(todayProvider);
    final todayKey = dayId(today);
    final first = today.subtract(const Duration(days: 364));
    final week = dayId(weekStart(today));
    final month = dayId(DateTime.utc(today.year, today.month));
    final weekCount =
        habit?.dates
            .where((d) => d.compareTo(week) >= 0 && d.compareTo(todayKey) <= 0)
            .length ??
        0;
    final monthCount =
        habit?.dates
            .where((d) => d.compareTo(month) >= 0 && d.compareTo(todayKey) <= 0)
            .length ??
        0;
    final yearCount =
        habit?.dates
            .where(
              (d) =>
                  d.compareTo(dayId(first)) >= 0 && d.compareTo(todayKey) <= 0,
            )
            .length ??
        0;
    final effectiveStart = habit == null || habit.created.compareTo(week) < 0
        ? week
        : habit.created;
    final effectiveEnd =
        habit?.archivedOn != null && habit!.archivedOn!.compareTo(todayKey) <= 0
        ? DateTime.parse(habit.archivedOn!).subtract(const Duration(days: 1))
        : today;
    final target = habit == null
        ? 0
        : habit.weekly
        ? habit.goal
        : (effectiveEnd.difference(DateTime.parse(effectiveStart)).inDays + 1)
              .clamp(0, 7);
    Future<void> manage(String action) async {
      if (habit == null) return;
      if (action == 'archive') {
        ref
            .read(habitsProvider.notifier)
            .save(
              habit.copyWith(restore: habit.archived, archivedOn: todayKey),
            );
        Navigator.of(context).pop();
      } else {
        final confirm = await AppPop.confirm(
          title: '删除这个习惯？',
          content: '「${habit.name}」及全部打卡记录会被删除，此操作无法撤销。',
          confirmText: '确认删除',
          danger: true,
          material: CommonSurfaceMaterial.glass,
        );
        if (confirm) {
          ref.read(habitsProvider.notifier).remove(habit.id);
          if (context.mounted) Navigator.of(context).pop();
        }
      }
    }

    return Scaffold(
      appBar: CommonAppBar(
        title: '',
        showBack: true,
        background: CommonAppBarSurface.transparent,
        showAction: habit != null,
        actionText: '编辑',
        actionLabel: '编辑习惯',
        onAction: habit == null ? null : () => openHabitEditor(habit: habit),
      ),
      body: YikePageWidth(
        child: habit == null
            ? Padding(
                padding: EdgeInsets.all(ts.spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('这个习惯不存在或已删除。', style: ts.textStyle.content),
                    CommonButton(
                      label: '返回打卡',
                      kind: CommonButtonKind.quiet,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: EdgeInsets.all(ts.spacing.lg),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(ts.spacing.smPlus),
                        decoration: BoxDecoration(
                          color: ts.colors.primarySoft,
                          borderRadius: BorderRadius.circular(ts.radius.md),
                        ),
                        child: HabitGlyph(icon: habit.icon),
                      ),
                      SizedBox(width: ts.spacing.md),
                      Expanded(
                        child: MotionContent(
                          identity: habit.name,
                          alignment: Alignment.centerLeft,
                          child: Text(habit.name, style: ts.textStyle.titleLg),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ts.spacing.md),
                  MotionContent(
                    identity: habit.frequency,
                    alignment: Alignment.centerLeft,
                    child: Text(habit.frequency, style: ts.textStyle.caption),
                  ),
                  MotionExpand(
                    expanded: habit.reminder,
                    child: Text(
                      '提醒 ${(habit.reminderMinutes ~/ 60).toString().padLeft(2, '0')}:${(habit.reminderMinutes % 60).toString().padLeft(2, '0')}',
                      style: ts.textStyle.caption,
                    ),
                  ),
                  MotionExpand(
                    expanded: habit.archived,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: ts.spacing.sm),
                        Text(
                          '已归档 · ${habit.archivedOn}',
                          style: ts.textStyle.content,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ts.spacing.lg),
                  Row(
                    children: [
                      _stat(
                        ts,
                        '本周',
                        '$weekCount/$target',
                        habit.weekly ? '次' : '天',
                      ),
                      _stat(ts, '本月', '$monthCount', habit.weekly ? '次' : '天'),
                      _stat(ts, '最近一年', '$yearCount', habit.weekly ? '次' : '天'),
                    ],
                  ),
                  MotionExpand(
                    expanded: habit.weekly,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: ts.spacing.lg),
                        Text('本周进度', style: ts.textStyle.subtitle),
                        SizedBox(height: ts.spacing.md),
                        Row(
                          children: [
                            for (var i = 0; i < habit.goal; i++)
                              Padding(
                                padding: EdgeInsets.only(right: ts.spacing.sm),
                                child: AnimatedContainer(
                                  duration: motionEnabled(context)
                                      ? ts.motion.durationFast
                                      : Duration.zero,
                                  width: ts.sizing.iconMd,
                                  height: ts.sizing.iconMd,
                                  decoration: BoxDecoration(
                                    shape: ts.pack.id.endsWith('sundial')
                                        ? BoxShape.rectangle
                                        : BoxShape.circle,
                                    color: i < weekCount
                                        ? ts.colors.primary
                                        : Colors.transparent,
                                    border: Border.fromBorderSide(
                                      ts.border.defaultBorder,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: ts.spacing.sm),
                        Text(
                          weekCount >= habit.goal
                              ? '本周目标已完成'
                              : '本周 还差 ${habit.goal - weekCount} 次达成周目标',
                          style: ts.textStyle.caption,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ts.spacing.lg),
                  Text('完成记录', style: ts.textStyle.subtitle),
                  SizedBox(height: ts.spacing.md),
                  CommonHeatmap(
                    label: '最近一年完成 $yearCount 次',
                    showLabel: false,
                    days: [
                      for (var i = 0; i < 365; i++)
                        CommonHeatmapDay(
                          date: dayId(first.add(Duration(days: i))),
                          value:
                              habit.dates.contains(
                                dayId(first.add(Duration(days: i))),
                              )
                              ? 1
                              : 0,
                        ),
                    ],
                    plotBuilder: (context, weeks, maximum) => HabitHeatmapPlot(
                      weeks: weeks,
                      habit: habit,
                      today: todayKey,
                    ),
                    legend: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                dayId(first),
                                style: ts.textStyle.micro,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                todayKey,
                                style: ts.textStyle.micro,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ts.spacing.sm),
                        const HabitHeatmapLegend(),
                      ],
                    ),
                  ),
                  SizedBox(height: ts.spacing.lg),
                  CommonCard(
                    key: const ValueKey('habit-management'),
                    padding: EdgeInsets.zero,
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        CommonListCell(
                          key: const ValueKey('manage/archive'),
                          title: habit.archived ? '恢复习惯' : '归档习惯',
                          description: habit.archived
                              ? '保留已有记录'
                              : '保留记录，从打卡页隐藏',
                          navigation: true,
                          onNavigate: () => manage('archive'),
                        ),
                        const CommonDivider(),
                        CommonListCell(
                          key: const ValueKey('manage/delete'),
                          title: '删除习惯',
                          navigation: true,
                          onNavigate: () => manage('delete'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _stat(TS ts, String label, String value, String unit) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ts.textStyle.caption),
        SizedBox(height: ts.spacing.sm),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: value, style: ts.textStyle.numericTitle),
              TextSpan(text: ' $unit', style: ts.textStyle.caption),
            ],
          ),
        ),
      ],
    ),
  );
}
