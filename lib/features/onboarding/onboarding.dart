import 'package:flutter/material.dart';

import '../../common/overlay/app_pop.dart';
import '../../common/widgets.dart';
import '../../common/widgets/yike/theme_selector.dart';
import '../../theme/ts.dart';
import '../../theme/yike_brand.dart';

/// Opens the single-page introduction for a new installation and from settings.
Future<void> showYikeOnboarding() async {
  final popup = AppCustom<void>();
  await popup.show(
    child: _Introduction(onClose: popup.dismiss, onStart: popup.complete),
  );
}

class _Introduction extends StatelessWidget {
  const _Introduction({required this.onClose, required this.onStart});
  final VoidCallback onClose;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return SafeArea(
      minimum: EdgeInsets.all(ts.spacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ts.layout.formMaxWidth,
              maxHeight: constraints.maxHeight * ts.sizing.panelLarge,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: CommonGlassSurface(
                key: const ValueKey('onboarding-glass'),
                borderRadius: BorderRadius.circular(ts.radius.xl),
                backdropBlendMode: BlendMode.src,
                child: Padding(
                  padding: EdgeInsets.all(ts.spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            YikeBrand.markFor(Theme.of(context).brightness),
                            width: ts.sizing.avatarSm,
                            height: ts.sizing.avatarSm,
                            excludeFromSemantics: true,
                          ),
                          SizedBox(width: ts.spacing.sm),
                          Expanded(
                            child: Text('认识一刻', style: ts.textStyle.label),
                          ),
                          CommonIconButton(
                            icon: Icons.close_rounded,
                            label: '跳过',
                            variant: CommonIconButtonVariant.text,
                            onPressed: onClose,
                          ),
                        ],
                      ),
                      SizedBox(height: ts.spacing.sm),
                      Flexible(
                        child: SingleChildScrollView(
                          key: const ValueKey('onboarding-body'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('找到适合你的节奏', style: ts.textStyle.headline),
                              SizedBox(height: ts.spacing.xs),
                              Text(
                                '打开，就开始这一刻。',
                                style: ts.textStyle.content.copyWith(
                                  color: ts.colors.onSurfaceMuted,
                                ),
                              ),
                              SizedBox(height: ts.spacing.lg),
                              const _ModeSummary(),
                              SizedBox(height: ts.spacing.lg),
                              Text('选择你的表盘', style: ts.textStyle.label),
                              SizedBox(height: ts.spacing.smPlus),
                              const YikeThemeSelector(),
                              SizedBox(height: ts.spacing.smPlus),
                              Text(
                                '主题只改变外观，随时可以在设置中更换。',
                                style: ts.textStyle.caption.copyWith(
                                  color: ts.colors.onSurfaceMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: ts.spacing.lg),
                      CommonButton(
                        label: '开始使用',
                        size: CommonControlSize.lg,
                        shape: CommonButtonShape.pill,
                        block: true,
                        onPressed: onStart,
                      ),
                      SizedBox(height: ts.spacing.sm),
                      Text(
                        '无需登录 · 只在本机保存',
                        textAlign: TextAlign.center,
                        style: ts.textStyle.caption.copyWith(
                          color: ts.colors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSummary extends StatelessWidget {
  const _ModeSummary();

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    const modes = [
      (CommonIconName.yikeModePomodoro, '番茄钟', '专注一段时间，再安排休息'),
      (CommonIconName.yikeModeStopwatch, '正计时', '从零开始，记录投入的时间'),
      (CommonIconName.yikeModeCountdown, '倒计时', '设定时长，到点提醒'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final mode in modes)
          Padding(
            padding: EdgeInsets.symmetric(vertical: ts.spacing.xsPlus),
            child: Row(
              children: [
                Container(
                  width: ts.sizing.touch,
                  height: ts.sizing.touch,
                  decoration: BoxDecoration(
                    color: ts.colors.primarySoft.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(ts.radius.md),
                  ),
                  child: Center(
                    child: CommonIcon(
                      name: mode.$1,
                      tone: CommonIconTone.primary,
                    ),
                  ),
                ),
                SizedBox(width: ts.spacing.smPlus),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.$2, style: ts.textStyle.label),
                      SizedBox(height: ts.spacing.xs / 2),
                      Text(mode.$3, style: ts.textStyle.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: ts.spacing.sm),
        Text(
          '三种模式可同时运行，切换不会结束其他计时。',
          style: ts.textStyle.caption.copyWith(color: ts.colors.onSurfaceMuted),
        ),
      ],
    );
  }
}
