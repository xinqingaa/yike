import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

class CommonFilterItem {
  const CommonFilterItem({required this.value, required this.label});

  final String value;
  final String label;
}

/// 三级快捷筛选：只维护一个当前值，不拥有视图区或高级筛选入口。
class CommonFilterBar extends StatelessWidget {
  const CommonFilterBar({
    super.key,
    required this.items,
    required this.selected,
    this.onSelected,
  });

  final List<CommonFilterItem> items;
  final String selected;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return SizedBox(
      height: ts.sizing.controlMd + ts.spacing.xs,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(width: ts.spacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          final active = selected == item.value;
          return ChoiceChip(
            label: Text(item.label),
            selected: active,
            onSelected: onSelected == null
                ? null
                : (_) => onSelected!(item.value),
            showCheckmark: false,
            backgroundColor: Colors.transparent,
            selectedColor: ts.colors.surfaceVariant,
            disabledColor: Colors.transparent,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ts.radius.sm),
            ),
            labelStyle: ts.textStyle.label.copyWith(
              color: active ? ts.colors.onSurface : ts.colors.onSurfaceMuted,
            ),
          );
        },
      ),
    );
  }
}
