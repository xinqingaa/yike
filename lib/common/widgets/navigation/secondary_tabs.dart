import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import 'tab_item.dart';

/// 二级页内分区：官方 [TabBar]，选中态使用文字下方朝上的小三角。
class CommonSecondaryTabs extends StatelessWidget {
  const CommonSecondaryTabs({
    super.key,
    required this.items,
    this.controller,
    this.grow = false,
    this.centered = false,
    this.showDivider = false,
  });

  final List<CommonTabItem> items;
  final TabController? controller;
  final bool grow;
  final bool centered;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final labelStyle = ts.textStyle.label;
    final labelHeight =
        MediaQuery.textScalerOf(context).scale(labelStyle.fontSize!) *
        labelStyle.height!;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: ts.border.hairline) : null,
      ),
      child: TabBar(
        controller: controller,
        isScrollable: !grow,
        tabAlignment: grow
            ? TabAlignment.fill
            : centered
            ? TabAlignment.center
            : TabAlignment.start,
        labelColor: ts.colors.secondaryTabActive,
        unselectedLabelColor: ts.colors.onSurfaceMuted,
        labelStyle: labelStyle,
        unselectedLabelStyle: labelStyle,
        labelPadding: EdgeInsets.symmetric(horizontal: ts.spacing.sm),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: _CaretIndicator(
          color: ts.colors.secondaryIndicator,
          size: ts.sizing.caret,
          offset: -ts.layout.insetSmNegative,
          labelHeight: labelHeight,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tabs: [
          for (final item in items)
            Tab(height: ts.sizing.controlMd, text: item.label),
        ],
      ),
    );
  }
}

class _CaretIndicator extends Decoration {
  const _CaretIndicator({
    required this.color,
    required this.size,
    required this.offset,
    required this.labelHeight,
  });

  final Color color;
  final double size;
  final double offset;
  final double labelHeight;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _CaretPainter(
    color: color,
    size: size,
    offset: offset,
    labelHeight: labelHeight,
  );
}

class _CaretPainter extends BoxPainter {
  const _CaretPainter({
    required this.color,
    required this.size,
    required this.offset,
    required this.labelHeight,
  });

  final Color color;
  final double size;
  final double offset;
  final double labelHeight;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final bounds = offset & configuration.size!;
    final labelBottom = bounds.center.dy + labelHeight / 2;
    final center = Offset(bounds.center.dx, labelBottom + this.offset);
    final halfWidth = size;
    final path = Path()
      ..moveTo(center.dx - halfWidth, center.dy)
      ..lineTo(center.dx, center.dy - size)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }
}
