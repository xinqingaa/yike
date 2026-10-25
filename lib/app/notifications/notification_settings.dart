import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/widgets.dart';
import '../../common/overlay/app_pop.dart';
import '../../features/local_data/local_data.dart';
import '../../theme/ts.dart';
import 'notification_coordinator.dart';

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
    final unavailable = !enabled
        ? '前台可提醒，后台未开启'
        : !status.ready
        ? '通知尚未准备就绪'
        : !status.access.allowed
        ? '前台可提醒，系统通知未授权'
        : !status.access.alert
        ? '系统横幅已关闭，请检查系统设置'
        : Platform.isAndroid && !status.access.exact
        ? '后台已开启；计时未获精确授权，可能延迟'
        : '后台已开启；送达受系统设置影响';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact)
          CommonListCell(
            title: '通知提醒',
            switchValue: enabled,
            onSwitchChanged: actions.setEnabled,
          ),
        Text(unavailable, style: ts.textStyle.caption),
        if (compact)
          CommonButton(
            label: '后台提醒设置',
            kind: CommonButtonKind.quiet,
            onPressed: () => AppSheet<void>().show(
              title: '通知提醒',
              child: const NotificationSettings(),
            ),
          ),
        if (!compact) ...[
          if (enabled && Platform.isAndroid && !status.access.exact)
            CommonButton(
              label: '允许精确计时提醒',
              kind: CommonButtonKind.quiet,
              onPressed: actions.exactPermission,
            ),
          CommonButton(
            label: '系统通知设置',
            kind: CommonButtonKind.quiet,
            onPressed: actions.openSettings,
          ),
          if (enabled && !status.access.sound)
            Text('系统通知声音未启用', style: ts.textStyle.caption),
          if (status.access.disabledChannels.isNotEmpty)
            Text(
              '已禁用渠道：${status.access.disabledChannels.join('、')}',
              style: ts.textStyle.caption,
            ),
          if (status.error != null) ...[
            Text(
              status.error!,
              style: ts.textStyle.caption.copyWith(color: ts.colors.error),
            ),
            CommonButton(
              label: '重试通知',
              kind: CommonButtonKind.quiet,
              onPressed: actions.refresh,
            ),
          ],
          if (enabled && status.ready) ...[
            Text('逐习惯预约（按最近日期，最多 60 个请求）', style: ts.textStyle.caption),
            for (final h in data.habits.where((h) => h.reminder && !h.archived))
              Text(
                '${h.name}：${status.coverage[h.id]?.isNotEmpty == true ? '${status.coverage[h.id]!.first} 至 ${status.coverage[h.id]!.last}，${status.coverage[h.id]!.length} 次' : '尚未排入'}',
                style: ts.textStyle.caption,
              ),
            Text(
              '未排入的习惯 ${data.habits.where((h) => h.reminder && !h.archived && !(status.coverage[h.id]?.isNotEmpty ?? false)).length} 个。长期不打开应用，不能保证持续提醒。',
              style: ts.textStyle.caption,
            ),
          ],
        ],
      ],
    );
  }
}
