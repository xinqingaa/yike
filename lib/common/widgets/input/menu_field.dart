import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../../overlay/app_pop.dart';
import '../action/button.dart';
import 'choice_option.dart';
import '../action/icon.dart';
import '../display/spinner.dart';

/// 表单中的有限选项入口；弹层唯一使用 [AppPop.dropMenu]。
class CommonMenuField<T> extends StatefulWidget {
  const CommonMenuField({
    super.key,
    required this.options,
    this.value,
    this.label,
    this.hint,
    this.enabled = true,
    this.clearable = false,
    this.loading = false,
    this.errorText,
    this.onChanged,
  });

  final List<CommonChoiceOption<T>> options;
  final T? value;
  final String? label;
  final String? hint;
  final bool enabled;
  final bool clearable;
  final bool loading;
  final String? errorText;
  final ValueChanged<T?>? onChanged;

  @override
  State<CommonMenuField<T>> createState() => _CommonMenuFieldState<T>();
}

class _CommonMenuFieldState<T> extends State<CommonMenuField<T>> {
  final PopupAnchorController _anchor = PopupAnchorController();

  bool get _interactive =>
      widget.enabled && !widget.loading && widget.onChanged != null;

  @override
  void dispose() {
    _anchor.attached.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (!_interactive) return;
    final selected = await AppPop.dropMenu<T>(
      anchor: _anchor,
      menu: DropMenu<T>.single(
        selectedValue: widget.value,
        items: [
          for (final option in widget.options)
            DropMenuItem<T>(
              value: option.value,
              label: option.label,
              disabled: !option.enabled,
              selected: option.value == widget.value,
            ),
        ],
      ),
    );
    if (mounted && selected != null) widget.onChanged?.call(selected);
  }

  String? get _selectedLabel {
    for (final option in widget.options) {
      if (option.value == widget.value) return option.label;
    }
    return null;
  }

  Widget _suffix() {
    final ts = TS.of(context);
    if (widget.loading) {
      return Padding(
        padding: EdgeInsets.all(ts.spacing.smPlus),
        child: const CommonSpinner(size: CommonControlSize.sm),
      );
    }
    if (widget.clearable && widget.value != null && _interactive) {
      return IconButton(
        tooltip: '清除',
        onPressed: () => widget.onChanged?.call(null),
        icon: CommonIcon(
          name: CommonIconName.x,
          color: ts.colors.onSurfaceMuted,
        ),
      );
    }
    return CommonIcon(
      name: CommonIconName.chevronDown,
      color: ts.colors.onSurfaceMuted,
      dimension: ts.sizing.iconSm,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final selectedLabel = _selectedLabel;
    final field = Opacity(
      opacity: widget.enabled ? ts.opacity.visible : ts.opacity.disabled,
      child: PopupAnchor(
        controller: _anchor,
        child: InkWell(
          onTap: _interactive ? _open : null,
          borderRadius: BorderRadius.circular(ts.radius.md),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: null,
              errorText: widget.errorText,
              enabled: widget.enabled,
              suffixIcon: _suffix(),
            ),
            isEmpty: selectedLabel == null,
            child: Text(
              selectedLabel ?? widget.hint ?? '',
              style: ts.textStyle.content.copyWith(
                color: selectedLabel == null ? ts.colors.onSurfaceMuted : null,
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: ts.textStyle.caption),
          SizedBox(height: ts.spacing.sm),
        ],
        field,
      ],
    );
  }
}
