import 'package:flutter/material.dart';

import '../common/widgets.dart';
import '../theme/ts.dart';

class BootstrapPage extends StatelessWidget {
  const BootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Scaffold(
      backgroundColor: ts.colors.background,
      appBar: CommonAppBar(title: 'Yike', showAction: false),
      body: ListView(
        padding: EdgeInsets.all(ts.spacing.md),
        children: [
          Text('等待 PBWork Handoff', style: ts.textStyle.title),
          SizedBox(height: ts.spacing.sm),
          Text(
            'MCP 已绑定到本工程。把 PBWork 定稿提示词交给 agent 后，先只读理解 Evidence、按 Screen 输出实现计划并等待批准。',
            style: ts.textStyle.caption,
          ),
          SizedBox(height: ts.spacing.lg),
          CommonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('验证命令', style: ts.textStyle.subtitle),
                SizedBox(height: ts.spacing.sm),
                Text('node tool/verify.mjs', style: ts.textStyle.content),
                Text('node tool/ds-theme.mjs', style: ts.textStyle.content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
