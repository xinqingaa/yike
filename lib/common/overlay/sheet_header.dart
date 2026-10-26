import 'package:flutter/material.dart';

import '../../theme/ts.dart';
import '../widgets/action/icon.dart';
import '../widgets/display/glass_surface.dart';
import '../widgets/action/icon_button.dart';

class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.title,
    this.start,
    this.close,
  });
  final String title;
  final Widget? start;
  final VoidCallback? close;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return SizedBox(
      height: ts.sizing.touch,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ts.sizing.touch),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: ts.textStyle.subtitle,
            ),
          ),
          if (start != null)
            Align(alignment: Alignment.centerLeft, child: start),
          if (close != null)
            Align(
              alignment: Alignment.centerRight,
              child: CommonIconButton(
                material: CommonSurfaceMaterial.glass,
                name: CommonIconName.x,
                label: '关闭',
                variant: CommonIconButtonVariant.tonal,
                onPressed: close,
              ),
            ),
        ],
      ),
    );
  }
}
