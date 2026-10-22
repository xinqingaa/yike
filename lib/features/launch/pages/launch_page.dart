import 'package:flutter/material.dart';
import '../../../common/widgets.dart';
import '../../../common/widgets/yike/dial.dart';
import '../../../theme/ts.dart';

class YikeLaunchPage extends StatelessWidget {
  const YikeLaunchPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Scaffold(
      body: CommonLaunchScreen(
        mode: CommonLaunchMode.launch,
        brandName: '一刻',
        brand: CommonBrandMark(
          name: '一刻',
          layout: CommonBrandLayout.stacked,
          mark: YikeDial(width: ts.sizing.plot * .64, brand: true),
          wordmark: Text('一刻', style: ts.textStyle.headline),
        ),
        content: Text(
          '打开，就开始这一刻',
          style: ts.textStyle.content.copyWith(color: ts.colors.onSurfaceMuted),
        ),
        footer: Text('只在本机保存', style: ts.textStyle.caption),
      ),
    );
  }
}
