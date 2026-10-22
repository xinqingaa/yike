import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/overlay/app_pop.dart';
import '../common/widgets.dart';
import '../features/local_data/local_data.dart';
import '../storage/preference_writer.dart';
import '../theme/ts.dart';
import 'reset_data.dart';

class LocalDataBoundary extends ConsumerWidget {
  const LocalDataBoundary({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errors = ref.watch(
          localDataProvider.select((s) => (s.readError, s.writeError)),
        ),
        pending = ref.watch(preferenceWriterProvider);
    final ts = TS.of(context);
    if (errors.$1 != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(ts.spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errors.$1!, style: ts.textStyle.content),
                  CommonButton(
                    label: '重试读取',
                    onPressed: () => ref.invalidate(localDataProvider),
                  ),
                  CommonButton(
                    label: '重置本机数据',
                    kind: CommonButtonKind.quiet,
                    onPressed: () async {
                      final yes = await AppPop.confirm(
                        context,
                        title: '重置所有数据？',
                        content: '原本机数据将被清除，恢复默认配置与四个初始习惯。此操作无法撤销。',
                        confirmText: '确认重置',
                        danger: true,
                      );
                      if (yes && context.mounted) resetYikeData(ref);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (errors.$2 == null && pending.isEmpty) return child;
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Material(
            color: ts.colors.surface,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ts.spacing.md,
                vertical: ts.spacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '尚未保存，关闭后可能丢失',
                      style: ts.textStyle.caption.copyWith(
                        color: ts.colors.error,
                      ),
                    ),
                  ),
                  CommonButton(
                    label: '重试保存',
                    kind: CommonButtonKind.quiet,
                    onPressed: () {
                      ref.read(localDataProvider.notifier).retry();
                      ref.read(preferenceWriterProvider.notifier).retry();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
