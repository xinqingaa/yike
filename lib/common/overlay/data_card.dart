import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';
import '../../theme/ts.dart';
import 'popup_activity.dart';
import 'popup_theme.dart';
import '../widgets/display/glass_surface.dart';

/// One nonmodal inspection card per owning page. Scrolling remains available.
final class AppDataCard with WidgetsBindingObserver {
  static final _instances = <AppDataCard>{};
  static void closeAll() {
    for (final card in _instances.toList()) {
      card.close();
    }
  }

  AppDataCard() {
    _instances.add(this);
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) close();
  }

  PopupHandle<void>? _handle;
  int _revision = 0;
  Future<void> show({
    required PopupAnchorController anchor,
    required Widget child,
  }) async {
    close();
    final revision = _revision;
    final context = popupHostContext(), ts = TS.of(popupHostContext());
    final themes = InheritedTheme.capture(from: context, to: null);
    final popup = Pop.menu<void>(
      MenuConfig<void>(
        anchor: anchor,
        placement: MenuPlacement.auto,
        barrier: const PopupBarrierConfig.hidden(),
        style: PopupMenuStyle(
          padding: EdgeInsets.all(ts.spacing.md),
          borderRadius: BorderRadius.circular(ts.radius.md),
          surface: PopupTheme.surface(context, CommonSurfaceMaterial.glass),
        ),
        animationConfig: PopupAnimationConfig(
          type: PopupAnimationType.fade,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : ts.motion.durationFast,
        ),
        builder: (_, _) => themes.wrap(
          TapRegion(
            onTapOutside: (_) {
              if (_revision == revision) close();
            },
            child: Material(
              type: MaterialType.transparency,
              child: IntrinsicWidth(child: SingleChildScrollView(child: child)),
            ),
          ),
        ),
      ),
    );
    final handle = popup.handleOrNull;
    _handle = handle;
    await popup.result;
    await handle?.dismissed;
    if (_revision == revision) _handle = null;
  }

  void close() {
    _revision++;
    final handle = _handle;
    _handle = null;
    if (handle != null) unawaited(handle.dismiss());
  }

  void dispose() {
    _instances.remove(this);
    WidgetsBinding.instance.removeObserver(this);
    close();
  }
}

/// Keeps menu anchors and selection feedback local to their actual date/column.
class DataCardTarget extends StatefulWidget {
  const DataCardTarget({
    super.key,
    required this.card,
    required this.content,
    required this.builder,
    this.onShow,
  });
  final AppDataCard card;
  final WidgetBuilder content;
  final Widget Function(BuildContext, VoidCallback, bool) builder;
  final VoidCallback? onShow;
  @override
  State<DataCardTarget> createState() => _DataCardTargetState();
}

class _DataCardTargetState extends State<DataCardTarget> {
  final _anchor = PopupAnchorController();
  bool _open = false;
  void _show() async {
    if (_open || !TickerMode.valuesOf(context).enabled) return;
    widget.onShow?.call();
    setState(() => _open = true);
    await widget.card.show(anchor: _anchor, child: widget.content(context));
    if (mounted) setState(() => _open = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_open && !TickerMode.valuesOf(context).enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) widget.card.close();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopupAnchor(
    controller: _anchor,
    child: widget.builder(context, _show, _open),
  );
}
