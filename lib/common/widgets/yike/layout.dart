import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/ts.dart';
import '../../widgets.dart';

class YikePageWidth extends StatelessWidget {
  const YikePageWidth({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    widthFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: TS.of(context).layout.formMaxWidth),
      child: child,
    ),
  );
}

/// Controlled selection-only tabs. A cancelled decision restores the indicator.
class YikeSelectionBar extends StatefulWidget {
  const YikeSelectionBar({
    super.key,
    required this.items,
    required this.value,
    required this.onSelected,
    this.size = CommonPrimaryTabsSize.md,
  });
  final List<CommonTabItem> items;
  final CommonPrimaryTabsSize size;
  final String value;
  final FutureOr<void> Function(String) onSelected;
  @override
  State<YikeSelectionBar> createState() => _YikeSelectionBarState();
}

class _YikeSelectionBarState extends State<YikeSelectionBar>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: widget.items.length,
    initialIndex: widget.items.indexWhere((item) => item.value == widget.value),
    vsync: this,
  );
  void _align() {
    if (mounted) {
      final index = widget.items.indexWhere(
        (item) => item.value == widget.value,
      );
      if (_controller.index != index) {
        final ts = TS.of(context);
        _controller.animateTo(
          index,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : ts.motion.durationTabViewport,
          curve: ts.motion.easingStandard,
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant YikeSelectionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _align();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CommonPrimaryTabs(
    items: widget.items,
    size: widget.size,
    grow: true,
    controller: _controller,
    onSelectionRequested: (value) async {
      await widget.onSelected(value);
      _align();
    },
  );
}
