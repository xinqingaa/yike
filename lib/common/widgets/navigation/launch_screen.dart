import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/button.dart';
import '../display/brand_mark.dart';

enum CommonLaunchMode { welcome, launch }

/// Flutter content page. Native pre-first-frame splash resources are separate.
class CommonLaunchScreen extends StatelessWidget {
  const CommonLaunchScreen({
    super.key,
    this.brandName = '品牌',
    this.title = '开始新的一天',
    this.description = '留一点时间给重要的事',
    this.actionLabel = '开始',
    this.busy = false,
    this.mode = CommonLaunchMode.welcome,
    this.onStart,
    this.brand,
    this.illustration,
    this.content,
    this.actions,
  });
  final String brandName;
  final String title;
  final String description;
  final String actionLabel;
  final bool busy;
  final CommonLaunchMode mode;
  final VoidCallback? onStart;
  final Widget? brand;
  final Widget? illustration;
  final Widget? content;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final asset = ts.assets.launchImage;
    return ColoredBox(
      color: ts.colors.surface,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  minHeight: constraints.hasBoundedHeight
                      ? constraints.maxHeight
                      : 0,
                ),
                child: Padding(
                  padding: EdgeInsets.all(ts.spacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      brand ??
                          CommonBrandMark(
                            name: brandName,
                            layout: CommonBrandLayout.stacked,
                          ),
                      if (illustration != null || asset != null) ...[
                        SizedBox(height: ts.spacing.lg),
                        illustration ??
                            Image.asset(
                              asset!,
                              height: ts.sizing.avatarLg,
                              excludeFromSemantics: true,
                            ),
                      ],
                      if (mode == CommonLaunchMode.welcome) ...[
                        SizedBox(height: ts.spacing.lg),
                        Text(
                          title,
                          style: ts.textStyle.title,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ts.spacing.lg),
                        Text(
                          description,
                          style: ts.textStyle.content.copyWith(
                            color: ts.colors.onSurfaceMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (content != null) ...[
                          SizedBox(height: ts.spacing.lg),
                          content!,
                        ],
                        SizedBox(height: ts.spacing.lg),
                        actions ??
                            CommonButton(
                              label: actionLabel,
                              loading: busy,
                              onPressed: onStart,
                            ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
