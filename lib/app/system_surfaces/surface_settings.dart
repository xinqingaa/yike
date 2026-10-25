import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/overlay/app_pop.dart';
import '../../common/widgets.dart';
import '../../theme/ts.dart';
import 'surface_coordinator.dart';

Future<void> openSurfaceSettings() => AppSheet<void>().show(
  title: '桌面组件',
  size: const SheetSizeConfig(height: SheetDimension.fraction(.5)),
  material: CommonSurfaceMaterial.glass,
  child: const SurfaceSettings(),
);

class SurfaceSettings extends ConsumerWidget {
  const SurfaceSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(surfaceCoordinatorProvider);
    final actions = ref.read(surfaceCoordinatorProvider.notifier);
    final ts = TS.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: ts.spacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CommonListCell(
              title: '桌面小部件',
              description: '长按主屏幕添加一刻小部件，查看专注与今日打卡。',
            ),
            if (Platform.isIOS) ...[
              CommonListCell(
                title: '实时活动',
                switchValue: status.enabled,
                onSwitchChanged: status.settingsError == null
                    ? actions.setEnabled
                    : null,
                description: !status.ready
                    ? '正在读取系统状态'
                    : !status.access.activities
                    ? '需要 iOS 16.1 或更新版本'
                    : !status.access.allowed
                    ? '系统已关闭实时活动'
                    : !status.enabled
                    ? '已关闭，不影响计时'
                    : '计时开始时显示在锁屏与动态岛',
              ),
              const CommonListCell(
                title: '完成后的展示',
                description: '全部自然完成后，锁屏结果保留约 5 分钟。后台更新可能延迟，系统也可能提前移除。',
              ),
              if (status.ready &&
                  status.access.widgets &&
                  !status.access.shared)
                const CommonListCell(
                  title: '小部件共享尚未就绪',
                  description: '当前安装未能连接共享容器，请重新安装支持小部件的版本。',
                ),
              CommonListCell(
                title: '系统设置',
                navigation: true,
                onNavigate: actions.openSettings,
              ),
            ],
            if (Platform.isAndroid)
              const CommonListCell(
                title: '时间更新',
                description: '读数旁显示更新时间；系统可能延迟刷新。暂停与继续会打开一刻安全处理。',
              ),
            if (status.error != null || status.settingsError != null) ...[
              CommonListCell(
                title: '需要重试',
                description: status.settingsError ?? status.error,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ts.spacing.md),
                child: CommonButton(
                  label: '重试更新',
                  kind: CommonButtonKind.quiet,
                  onPressed: actions.retry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
