import 'package:flutter/material.dart';

/// Official TabBarView owns swipe and controller synchronization.
class CommonTabView extends StatelessWidget {
  const CommonTabView({
    super.key,
    required this.children,
    this.controller,
    this.swipe = true,
    this.keepAlive = true,
  });
  final List<Widget> children;
  final TabController? controller;
  final bool swipe;
  final bool keepAlive;

  @override
  Widget build(BuildContext context) => TabBarView(
    controller: controller,
    physics: swipe
        ? const PageScrollPhysics()
        : const NeverScrollableScrollPhysics(),
    children: [
      for (var i = 0; i < children.length; i++)
        _TabPanel(
          key: children[i].key ?? ValueKey(i),
          keepAlive: keepAlive,
          child: children[i],
        ),
    ],
  );
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
