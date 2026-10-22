import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/local_value.dart';

import '../../../theme/ts.dart';
import '../action/icon.dart';

/// 对齐 pbwork `SearchBar`。
///
/// 有内容时显示清除按钮，对齐原型 clearable。
class CommonSearchBar extends ConsumerStatefulWidget {
  const CommonSearchBar({
    super.key,
    this.controller,
    this.hint = '搜索',
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController? controller;
  final String hint;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  ConsumerState<CommonSearchBar> createState() => _CommonSearchBarState();
}

class _CommonSearchBarState extends ConsumerState<CommonSearchBar> {
  TextEditingController? _owned;
  late TextEditingController _controller;
  late NotifierProvider<ControllerText, String> _textProvider;
  void _watchController() {
    _textProvider = NotifierProvider.autoDispose<ControllerText, String>(
      () => ControllerText(_controller),
    );
  }

  TextEditingController get _effective => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _owned = TextEditingController();
    }
    _controller = _effective;
    _watchController();
  }

  @override
  void didUpdateWidget(covariant CommonSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final previousText = _controller.text;
      if (oldWidget.controller == null) {
        _owned?.dispose();
        _owned = null;
      }
      if (widget.controller == null) {
        _owned = TextEditingController(text: previousText);
      }
      _controller = _effective;
      _watchController();
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final hasText = ref.watch(_textProvider).isNotEmpty;

    return SizedBox(
      height: ts.sizing.controlLg,
      child: Opacity(
        opacity: widget.enabled ? ts.opacity.visible : ts.opacity.disabled,
        child: TextField(
          controller: _controller,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          textInputAction: TextInputAction.search,
          style: ts.textStyle.content,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: CommonIcon(
              name: CommonIconName.search,
              dimension: ts.sizing.iconCompact,
              color: ts.colors.onSurfaceMuted,
            ),
            suffixIcon: hasText && widget.enabled
                ? IconButton(
                    tooltip: '清除',
                    onPressed: _clear,
                    icon: CommonIcon(
                      name: CommonIconName.x,
                      dimension: ts.sizing.iconCompact,
                      color: ts.colors.onSurfaceMuted,
                    ),
                  )
                : null,
            filled: true,
            fillColor: ts.colors.surfaceVariant,
          ),
        ),
      ),
    );
  }
}
