import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/ts.dart';
import '../action/icon.dart';
import '../display/glass_surface.dart';

class CommonBottomNavItem {
  const CommonBottomNavItem({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final CommonIconName icon;
}

/// Root destinations use Flutter's official fixed bottom navigation component.
class CommonBottomNav extends StatelessWidget {
  const CommonBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.selection,
  }) : assert(items.length >= 2 && items.length <= 5);
  final List<CommonBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Animation<double>? selection;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final radius = BorderRadius.circular(ts.radius.lg);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        ts.spacing.md,
        ts.spacing.xs,
        ts.spacing.md,
        ts.spacing.md,
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              onTap((currentIndex - 1).clamp(0, items.length - 1)),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              onTap((currentIndex + 1).clamp(0, items.length - 1)),
          const SingleActivator(LogicalKeyboardKey.home): () => onTap(0),
          const SingleActivator(LogicalKeyboardKey.end): () =>
              onTap(items.length - 1),
        },
        child: CommonGlassSurface(
          borderRadius: radius,
          child: SizedBox(
            height: ts.sizing.bottomNavigation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth / items.length;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (selection != null)
                      AnimatedBuilder(
                        animation: selection!,
                        builder: (context, child) => Positioned(
                          left: width * selection!.value + ts.spacing.xs,
                          top: ts.spacing.xs,
                          bottom: ts.spacing.xs,
                          width: width - ts.spacing.xs * 2,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: ts.colors.tabbarSelectionTint,
                                border: Border.fromBorderSide(ts.border.glass),
                                borderRadius: BorderRadius.circular(
                                  (ts.radius.lg - ts.spacing.xs).clamp(
                                    0.0,
                                    double.infinity,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      AnimatedPositioned(
                        duration: reduceMotion
                            ? Duration.zero
                            : ts.motion.durationTabViewport,
                        curve: ts.motion.easingStandard,
                        left: width * currentIndex + ts.spacing.xs,
                        top: ts.spacing.xs,
                        bottom: ts.spacing.xs,
                        width: width - ts.spacing.xs * 2,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: ts.colors.tabbarSelectionTint,
                              border: Border.fromBorderSide(ts.border.glass),
                              borderRadius: BorderRadius.circular(
                                (ts.radius.lg - ts.spacing.xs).clamp(
                                  0.0,
                                  double.infinity,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          splashFactory: NoSplash.splashFactory,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                        ),
                        child: BottomNavigationBar(
                          type: BottomNavigationBarType.fixed,
                          currentIndex: currentIndex,
                          onTap: onTap,
                          elevation: ts.elevation.none,
                          backgroundColor: Colors.transparent,
                          selectedItemColor: ts.colors.navigationActive,
                          unselectedItemColor: ts.colors.onSurfaceMuted,
                          selectedLabelStyle: ts.textStyle.captionStrong,
                          unselectedLabelStyle: ts.textStyle.caption,
                          selectedFontSize:
                              ts.textStyle.captionStrong.fontSize!,
                          unselectedFontSize: ts.textStyle.caption.fontSize!,
                          iconSize: ts.sizing.iconMd,
                          items: [
                            for (final item in items)
                              BottomNavigationBarItem(
                                icon: CommonIcon(name: item.icon),
                                label: item.label,
                                tooltip: item.label,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
