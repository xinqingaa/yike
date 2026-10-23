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
  });

  final List<CommonTabItem> items;
  final TabController? controller;
  final bool grow;
  final bool centered;
  final bool showDivider;
  final bool disabled;
  final CommonPrimaryTabsSize size;
  final ValueChanged<String>? onSelected;

  /// With grow=true, requests selection without moving the controller first.
  final ValueChanged<String>? onSelectionRequested;

  @override
  Widget build(BuildContext context) {
    assert(
      onSelectionRequested == null ||
          (grow && controller != null && onSelected == null),
    );
    final ts = TS.of(context);
    final compact = size == CommonPrimaryTabsSize.sm;
    final trackHeight = compact ? ts.sizing.controlSm : ts.sizing.controlMd;
    final trackRadius = BorderRadius.circular(
      compact ? ts.radius.sm : ts.radius.md,
    );

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
      labelStyle: compact ? ts.textStyle.captionStrong : ts.textStyle.label,
      unselectedLabelStyle: compact
          ? ts.textStyle.captionStrong
          : ts.textStyle.label,
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
              padding: EdgeInsets.symmetric(horizontal: ts.spacing.md),
              child: onSelectionRequested == null
                  ? Text(item.label)
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );

    final track = CommonGlassSurface(
      key: const ValueKey('primary-tabs-track'),
      borderRadius: trackRadius,
      child: Padding(
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
                                        onTap: () => onSelectionRequested!(
                                          items[i].value,
                                        ),
                                        borderRadius: trackRadius,
                                        child: Center(
                                          child: Text(
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
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
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
