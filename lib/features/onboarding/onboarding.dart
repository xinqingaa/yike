import 'package:flutter/material.dart';

import '../../common/overlay/app_pop.dart';
import '../../common/widgets.dart';
import '../../common/widgets/yike/dial.dart';
import '../../common/widgets/yike/theme_selector.dart';
import '../../theme/ts.dart';

/// Opens the introduction for a new installation and from settings.
Future<void> showYikeOnboarding() async {
  final flow = FlowSheetController<void>();
  await AppPop.flowSheet<void>(
    controller: flow,
    title: '认识一刻',
    material: CommonSurfaceMaterial.glass,
    size: const SheetSizeConfig(height: SheetDimension.fraction(.84)),
    headerStart: TextButton(onPressed: flow.closeAll, child: const Text('跳过')),
    initialPage: _IntroPage(id: 'onboarding-modes', flow: flow, themes: false),
  );
}

class _IntroPage extends FlowSheetPage<void> {
  const _IntroPage({
    required super.id,
    required this.flow,
    required this.themes,
  });
  final FlowSheetController<void> flow;
  final bool themes;

  @override
  State<_IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<_IntroPage> {
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: CommonFlowSheetContent(
      body: widget.themes ? const _ThemesPage() : const _ModesPage(),
      actions: [
        CommonButton(
          label: widget.themes ? '开始使用' : '继续',
          onPressed: widget.themes
              ? widget.flow.closeAll
              : () => widget.flow.push(
                  _IntroPage(
                    id: 'onboarding-themes',
                    flow: widget.flow,
                    themes: true,
                  ),
                ),
        ),
      ],
    ),
  );
}

class _ModesPage extends StatelessWidget {
  const _ModesPage();
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    const modes = [
      (CommonIconName.yikeModePomodoro, '番茄钟', '专注一段时间，再安排休息'),
      (CommonIconName.yikeModeStopwatch, '正计时', '从零开始，记录投入的时间'),
      (CommonIconName.yikeModeCountdown, '倒计时', '设定时长，到点提醒'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('找到适合你的节奏', style: ts.textStyle.title),
        SizedBox(height: ts.spacing.xs),
        Text('三种计时方式，陪你投入每一刻。', style: ts.textStyle.caption),
        SizedBox(height: ts.spacing.sm),
        Center(
          child: SizedBox(
            height: ts.sizing.brand * 1.5,
            child: const FittedBox(
              child: ExcludeSemantics(
                child: YikeDial(digits: '25:00', progress: 25 / 60),
              ),
            ),
          ),
        ),
        SizedBox(height: ts.spacing.sm),
        for (final mode in modes)
          Padding(
            padding: EdgeInsets.symmetric(vertical: ts.spacing.xsPlus),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: ts.sizing.touch,
                  child: CommonIcon(
                    name: mode.$1,
                    tone: CommonIconTone.primary,
                  ),
                ),
                SizedBox(width: ts.spacing.md),
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
        Text('三种模式可同时运行，切换不会结束其他计时。', style: ts.textStyle.caption),
      ],
    );
  }
}

class _ThemesPage extends StatelessWidget {
  const _ThemesPage();
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('选择你的表盘', style: ts.textStyle.title),
        SizedBox(height: ts.spacing.xs),
        Text('三种主题，三种时间的模样。', style: ts.textStyle.caption),
        SizedBox(height: ts.spacing.lg),
        const YikeThemeSelector(),
        SizedBox(height: ts.spacing.md),
        Text('主题只改变外观，计时功能相同。你可以随时在设置中更换。', style: ts.textStyle.caption),
      ],
    );
  }
}
