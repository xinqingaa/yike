import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/widgets.dart';
import '../../common/overlay/app_pop.dart';
import '../../features/local_data/local_data.dart';
import '../../theme/ts.dart';
import 'notification_coordinator.dart';

Future<void> openNotificationSettings() async {
  await AppSheet<void>().show(
    showHeader: false,
    size: const SheetSizeConfig(height: SheetDimension.fraction(.5)),
    material: CommonSurfaceMaterial.glass,
    child: const NotificationSettings(),
  );
}

class NotificationSettings extends ConsumerWidget {
  const NotificationSettings({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(notificationCoordinatorProvider);
    final data = ref.watch(localDataProvider).data;
    final actions = ref.read(notificationCoordinatorProvider.notifier);
    final ts = TS.of(context);
    final enabled = data.backgroundReminders;
    final summary = !enabled
        ? '仅在应用内提醒'
        : !status.ready
        ? '正在准备提醒'
        : !status.access.allowed
        ? '需要系统授权'
        : !status.access.alert
        ? '系统横幅已关闭'
        : Platform.isAndroid && !status.access.exact
        ? '计时提醒可能延迟'
        : '已开启后台提醒';
    if (compact) {
      return CommonListCell(
        title: '后台提醒',
        value: enabled ? '已开启' : '未开启',
        navigation: true,
        onNavigate: openNotificationSettings,
      );
    }
    final habits = data.habits.where((h) => !h.archived).toList();
    final queued = habits
        .where(
          (h) =>
              h.reminder &&
              enabled &&
              status.access.allowed &&
              (status.coverage[h.id]?.isNotEmpty ?? false),
        )
        .length;
    final permissionAction = enabled && status.ready && !status.access.allowed;
    final exactAction =
        enabled &&
        status.ready &&
        status.access.allowed &&
        Platform.isAndroid &&
        !status.access.exact;
    return SingleChildScrollView(
      key: const ValueKey('notification-settings-content'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: ts.spacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommonListCell(
              title: '后台提醒',
              description: summary,
              switchValue: enabled,
              onSwitchChanged: actions.setEnabled,
            ),
            if (permissionAction || exactAction)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ts.spacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CommonButton(
                    label: permissionAction ? '前往授权' : '允许精确提醒',
                    kind: CommonButtonKind.quiet,
                    size: CommonControlSize.sm,
                    onPressed: permissionAction
                        ? actions.openSettings
                        : actions.exactPermission,
                  ),
                ),
              ),
            CommonListCell(
              title: '系统通知设置',
              navigation: true,
              onNavigate: actions.openSettings,
              description:
                  enabled &&
                      status.ready &&
                      status.access.allowed &&
                      !status.access.sound
                  ? '通知声音未启用'
                  : null,
            ),
            if (status.access.disabledChannels.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ts.spacing.md),
                child: Text(
                  '已关闭：${status.access.disabledChannels.join('、')}',
                  style: ts.textStyle.caption,
                ),
              ),
            Divider(color: ts.colors.primarySoft, height: ts.spacing.md),
            CommonListCell(
              title: '习惯提醒',
              value: habits.isEmpty ? '暂无习惯' : '$queued 已预约',
            ),
            for (final habit in habits)
              CommonListCell(
                key: ValueKey('notification-habit-${habit.id}'),
                title: habit.name,
                description: !habit.reminder
                    ? '未开启提醒'
                    : !enabled
                    ? '后台提醒已关闭'
                    : !status.ready
                    ? '正在准备提醒'
                    : !status.access.allowed
                    ? '需要系统授权'
                    : status.coverage[habit.id]?.isNotEmpty == true
                    ? '${status.coverage[habit.id]!.first} — ${status.coverage[habit.id]!.last}'
                    : '尚未排入预约',
                value:
                    habit.reminder &&
                        enabled &&
                        status.access.allowed &&
                        (status.coverage[habit.id]?.isNotEmpty ?? false)
                    ? '${status.coverage[habit.id]!.length} 次'
                    : null,
              ),
            if (habits.any((h) => h.reminder))
              Padding(
                padding: EdgeInsets.all(ts.spacing.md),
                child: Text('再次打开应用时更新预约。', style: ts.textStyle.caption),
              ),
            if (status.error != null)
              CommonListCell(
                title: '部分提醒未就绪',
                description: status.error,
                value: '重试',
                navigation: true,
                onNavigate: actions.refresh,
              ),
          ],
        ),
      ),
    );
  }
}
