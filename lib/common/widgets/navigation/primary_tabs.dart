import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import 'liquid_glass_decoration.dart';
import 'tab_item.dart';
import '../display/glass_surface.dart';

enum CommonPrimaryTabsSize { md, sm }

/// 一级页内分区：官方 [TabBar] 承担布局、交互和选中面动画。
class CommonPrimaryTabs extends StatelessWidget {
  const CommonPrimaryTabs({
    super.key,
    required this.items,
    this.controller,
    this.grow = false,
    this.centered = false,
    this.showDivider = false,
    this.onSelected,
    this.onSelectionRequested,
    this.disabled = false,
    this.size = CommonPrimaryTabsSize.md,
    this.glassReveal = 1,
    this.clear = false,
    this.compactLabels = false,
    this.showSurface = true,
    this.fitLabels = false,
  });

  final List<CommonTabItem> items;
  final TabController? controller;
  final bool grow;
  final bool centered;
  final bool showDivider;
  final bool disabled;
  final CommonPrimaryTabsSize size;
  final double glassReveal;
  final bool clear, compactLabels, showSurface;

  /// Fits equal-width, single-line labels with one shared downscale factor.
  final bool fitLabels;
  final ValueChanged<String>? onSelected;

  /// With grow=true, requests selection without moving the controller first.
  final ValueChanged<String>? onSelectionRequested;

  @override
  Widget build(BuildContext context) {
    assert(
      onSelectionRequested == null ||
          (grow && controller != null && onSelected == null),
    );
    assert(!fitLabels || grow);
    final ts = TS.of(context);
    final compact = size == CommonPrimaryTabsSize.sm;
    final trackHeight = compact ? ts.sizing.controlSm : ts.sizing.controlMd;
    final trackRadius = BorderRadius.circular(
      clear
          ? ts.radius.md + (ts.radius.xl - ts.radius.md) * glassReveal
          : compact
          ? ts.radius.sm
          : ts.radius.md,
    );
    final labelStyle = compact
        ? ts.textStyle.captionStrong
        : ts.textStyle.label;
    var labelSize = Size.zero;
    if (fitLabels) {
      for (final item in items) {
        final painter = TextPainter(
          text: TextSpan(text: item.label, style: labelStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        )..layout();
        labelSize = Size(
          labelSize.width > painter.width ? labelSize.width : painter.width,
          labelSize.height > painter.height ? labelSize.height : painter.height,
        );
        painter.dispose();
      }
    }
    Widget label(String value, {TextStyle? style}) {
      final text = Text(
        value,
        style: style,
        maxLines: fitLabels ? 1 : null,
        softWrap: fitLabels ? false : null,
      );
      return fitLabels
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox.fromSize(
                size: labelSize,
                child: Center(child: text),
              ),
            )
          : text;
    }

    final tabBar = TabBar(
      onTap: (index) => onSelected?.call(items[index].value),
      controller: controller,
      isScrollable: !grow,
      tabAlignment: grow
          ? TabAlignment.fill
          : centered
          ? TabAlignment.center
          : TabAlignment.start,
      labelColor: ts.colors.sectionTabActive,
      unselectedLabelColor: ts.colors.onSurfaceMuted,
      labelStyle: labelStyle,
      unselectedLabelStyle: labelStyle,
      labelPadding: EdgeInsets.zero,
      dividerColor: Colors.transparent,
      dividerHeight: 0,
      indicatorWeight: 0,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorPadding: EdgeInsets.symmetric(vertical: ts.spacing.xs),
      indicatorAnimation: TabIndicatorAnimation.linear,
      indicator: LiquidGlassDecoration(
        surfaceColor: ts.colors.primaryTabsSelectionTint,
        opacity: ts.opacity.translucent,
        borderRadius: BorderRadius.circular(
          compact ? ts.radius.xs : ts.radius.sm,
        ),
        shadow: ts.elevation.floating,
      ),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      tabs: [
        for (final item in items)
          Tab(
            height: trackHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compactLabels ? ts.spacing.sm : ts.spacing.md,
              ),
              child: onSelectionRequested == null
                  ? label(item.label)
                  : const SizedBox.expand(),
            ),
          ),
      ],
    );

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: ts.spacing.xs),
      child: SizedBox(
        width: double.infinity,
        height: trackHeight,
        child: IgnorePointer(
          ignoring: disabled,
          child: ExcludeFocus(
            excluding: disabled,
            child: Opacity(
              opacity: disabled ? ts.opacity.disabled : 1,
              child: onSelectionRequested == null
                  ? tabBar
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ExcludeSemantics(
                          child: ExcludeFocus(
                            child: IgnorePointer(child: tabBar),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: controller!.animation!,
                          builder: (context, _) => Row(
                            children: [
                              for (var i = 0; i < items.length; i++)
                                Expanded(
                                  child: Semantics(
                                    selected: controller!.index == i,
                                    button: true,
                                    child: InkWell(
                                      onTap: () =>
                                          onSelectionRequested!(items[i].value),
                                      borderRadius: trackRadius,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: !fitLabels
                                              ? ts.spacing.none
                                              : compactLabels
                                              ? ts.spacing.sm
                                              : ts.spacing.md,
                                        ),
                                        child: Center(
                                          child: label(
                                            items[i].label,
                                            style:
                                                (compact
                                                        ? ts
                                                              .textStyle
                                                              .captionStrong
                                                        : ts.textStyle.label)
                                                    .copyWith(
                                                      color: Color.lerp(
                                                        ts
                                                            .colors
                                                            .onSurfaceMuted,
                                                        ts
                                                            .colors
                                                            .sectionTabActive,
                                                        (1 -
                                                                (controller!
                                                                            .animation!
                                                                            .value -
                                                                        i)
                                                                    .abs())
                                                            .clamp(0, 1),
                                                      ),
                                                    ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
    final track = showSurface
        ? CommonGlassSurface(
            key: const ValueKey('primary-tabs-track'),
            reveal: glassReveal,
            clear: clear,
            borderRadius: trackRadius,
            child: content,
          )
        : content;

    return showDivider
        ? DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: ts.border.hairline),
            ),
            child: track,
          )
        : track;
  }
}
