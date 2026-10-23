import 'package:flutter/material.dart';

import '../../theme/ts.dart';
import 'content_transition.dart';

/// An identity diff, with no initial or hidden-page entrance. Existing rows and
/// the scroll controller survive updates; only inserted/removed rows transition.
class MotionList<T> extends StatefulWidget {
  const MotionList({
    super.key,
    required this.items,
    required this.identity,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
    this.physics,
  });
  final List<T> items;
  final Object Function(T item) identity;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  @override
  State<MotionList<T>> createState() => _MotionListState<T>();
}

class _MotionListState<T> extends State<MotionList<T>> {
  final GlobalKey<SliverAnimatedListState> _list = GlobalKey();
  late final List<T> _items = [...widget.items];
  final _scroll = ScrollController();
  bool _enabled = false;
  int _epoch = 0;
  final _insertions = <Object, int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = motionEnabled(context);
    if (_enabled && !enabled) {
      // Existing controllers can finish offstage, but may not replay on return.
      _epoch++;
    }
    _enabled = enabled;
  }

  @override
  void didUpdateWidget(covariant MotionList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final duration = _enabled
        ? TS.of(context).motion.durationNormal
        : Duration.zero;
    final ids = widget.items.map(widget.identity).toSet();
    for (var i = _items.length - 1; i >= 0; i--) {
      if (!ids.contains(widget.identity(_items[i]))) {
        final removed = _items.removeAt(i);
        final epoch = _epoch;
        _insertions.remove(widget.identity(removed));
        _list.currentState?.removeItem(
          i,
          (context, animation) => _enabled && epoch == _epoch
              ? IgnorePointer(
                  child: ExcludeFocus(
                    child: ExcludeSemantics(
                      child: _row(removed, animation, removing: true),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          duration: duration,
        );
      }
    }
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (i < _items.length &&
          widget.identity(_items[i]) == widget.identity(item)) {
        _items[i] = item;
        continue;
      }
      final prior = _items.indexWhere(
        (e) => widget.identity(e) == widget.identity(item),
      );
      if (prior >= 0) {
        _items.removeAt(prior);
        _list.currentState?.removeItem(
          prior,
          (_, _) => const SizedBox.shrink(),
          duration: Duration.zero,
        );
      }
      _items.insert(i, item);
      _insertions[widget.identity(item)] = _epoch;
      _list.currentState?.insertItem(i, duration: duration);
    }
  }

  Widget _row(T item, Animation<double> animation, {bool removing = false}) {
    final phase =
        _enabled && (removing || _insertions[widget.identity(item)] == _epoch)
        ? animation
        : kAlwaysCompleteAnimation;
    return SizeTransition(
      key: ValueKey(widget.identity(item)),
      sizeFactor: phase.drive(
        CurveTween(curve: TS.of(context).motion.easingStandard),
      ),
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: phase,
        child: KeyedSubtree(
          key: ValueKey(widget.identity(item)),
          child: widget.itemBuilder(context, item),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indices = {
      for (var i = 0; i < _items.length; i++) widget.identity(_items[i]): i,
    };
    return CustomScrollView(
      controller: _scroll,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: SliverAnimatedList(
            key: _list,
            initialItemCount: _items.length,
            findChildIndexCallback: (key) =>
                key is ValueKey ? indices[key.value] : null,
            itemBuilder: (context, index, animation) =>
                _row(_items[index], animation),
          ),
        ),
      ],
    );
  }
}
