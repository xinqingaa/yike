import 'package:flutter/material.dart';
import '../../motion/motion_activity.dart';

/// Official TabBarView owns swipe and controller synchronization.
class CommonTabView extends StatelessWidget {
  const CommonTabView({
    super.key,
    required this.children,
    this.controller,
    this.swipe = true,
    this.keepAlive = true,
    this.selectedNow,
  });
  final List<Widget> children;
  final TabController? controller;
  final bool swipe;
  final bool keepAlive;
  final bool Function(int index)? selectedNow;

  @override
  Widget build(BuildContext context) {
    final tabs = controller ?? DefaultTabController.of(context);
    return TabBarView(
      controller: tabs,
      physics: swipe
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < children.length; i++)
          _TabPanel(
            key: children[i].key ?? ValueKey(i),
            keepAlive: keepAlive,
            child: AnimatedBuilder(
              animation: tabs,
              child: children[i],
              builder: (context, child) => MotionGate(
                active: tabs.index == i,
                activeNow: () => selectedNow?.call(i) ?? tabs.index == i,
                child: IgnorePointer(
                  ignoring: tabs.index != i,
                  child: ExcludeFocus(
                    excluding: tabs.index != i,
                    child: ExcludeSemantics(
                      excluding: tabs.index != i,
                      child: child!,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TabPanel extends StatefulWidget {
  const _TabPanel({super.key, required this.child, required this.keepAlive});
  final Widget child;
  final bool keepAlive;
  @override
  State<_TabPanel> createState() => _TabPanelState();
}

class _TabPanelState extends State<_TabPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;
  @override
  void didUpdateWidget(covariant _TabPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
