import 'package:flutter/material.dart';

import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../../../theme/yike_motion.dart';

const settingsSections = ['外观', '番茄钟', '倒计时', '声音', '通用'];
const countdownSettingsSection = 2;

double settingsHeaderProgress(ScrollController scroll) {
  final raw =
      ((scroll.hasClients ? scroll.offset : 0.0) /
              YikeMotion.settingsGlassTravel)
          .clamp(0.0, 1.0);
  return raw * raw * (3 - 2 * raw);
}

class SettingsHeader extends SliverPersistentHeaderDelegate {
  SettingsHeader({
    required this.ts,
    required this.controller,
    required this.onSelected,
    required this.scroll,
  });
  final TS ts;
  final TabController controller;
  final ValueChanged<int> onSelected;
  final ScrollController scroll;

  @override
  double get minExtent => ts.sizing.controlMd + ts.spacing.sm * 2;
  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => AnimatedBuilder(
    animation: scroll,
    builder: (context, _) {
      final progress = settingsHeaderProgress(scroll);
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ts.spacing.lg * (1 - progress),
          vertical: ts.spacing.sm * (1 - progress),
        ),
        child: CommonGlassSurface(
          clear: true,
          reveal: progress,
          edges: CommonGlassEdges.bottom,
          borderRadius: BorderRadius.circular(ts.radius.md * (1 - progress)),
          child: Center(
            child: CommonPrimaryTabs(
              key: const ValueKey('settings-navigation'),
              items: [
                for (var i = 0; i < settingsSections.length; i++)
                  CommonTabItem(value: '$i', label: settingsSections[i]),
              ],
              controller: controller,
              grow: true,
              fitLabels: true,
              compactLabels: true,
              showSurface: false,
              clear: true,
              glassReveal: progress,
              onSelected: (value) => onSelected(int.parse(value)),
            ),
          ),
        ),
      );
    },
  );

  @override
  bool shouldRebuild(covariant SettingsHeader oldDelegate) =>
      ts != oldDelegate.ts ||
      controller != oldDelegate.controller ||
      scroll != oldDelegate.scroll;
}

/// One continuous list with a stable anchor for every settings section.
class SettingsScrollController {
  final scroll = ScrollController();
  final viewport = GlobalKey();
  final sections = List.generate(settingsSections.length, (_) => GlobalKey());
  int? target;
  int epoch = 0;

  double offsetFor(int index, double headerHeight) {
    if (index == 0) return 0;
    final box = sections[index].currentContext?.findRenderObject();
    final root = viewport.currentContext?.findRenderObject();
    if (box is! RenderBox || root is! RenderBox) return scroll.offset;
    return (scroll.offset +
            box.localToGlobal(Offset.zero, ancestor: root).dy -
            headerHeight)
        .clamp(0.0, scroll.position.maxScrollExtent);
  }

  int active(double headerHeight, {required int current}) {
    if (scroll.offset <= 0) return 0;
    if (scroll.position.extentAfter < 1) return sections.length - 1;
    final root = viewport.currentContext?.findRenderObject();
    if (root is! RenderBox) return 0;
    var selected = 0;
    final tops = <double>[];
    for (var i = 0; i < sections.length; i++) {
      final box = sections[i].currentContext?.findRenderObject();
      final top = box is RenderBox
          ? box.localToGlobal(Offset.zero, ancestor: root).dy
          : double.infinity;
      tops.add(top);
      if (top <= headerHeight) selected = i;
    }
    if (selected > current && tops[selected] > headerHeight - 8) return current;
    if (selected < current && tops[current] < headerHeight + 8) return current;
    return selected;
  }

  void interrupt() {
    target = null;
    epoch++;
  }

  void dispose() => scroll.dispose();
}
