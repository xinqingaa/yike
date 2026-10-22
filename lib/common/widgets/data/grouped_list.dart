import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../composition/density.dart';
import '../display/card.dart';
import 'list_cell.dart';

class CommonListItem {
  const CommonListItem({
    required this.id,
    required this.title,
    this.description,
    this.value,
    this.leading,
    this.navigation = false,
    this.switchValue,
    this.disabled = false,
  });
  final String id;
  final String title;
  final String? description;
  final String? value;
  final Widget? leading;
  final bool navigation;
  final bool? switchValue;
  final bool disabled;
}

class CommonListGroup {
  const CommonListGroup({
    required this.id,
    required this.title,
    required this.items,
  });
  final String id;
  final String title;
  final List<CommonListItem> items;
}

/// In-flow groups, suitable as items of an outer lazy list. No nested scrolling.
class CommonGroupedList extends StatelessWidget {
  const CommonGroupedList({
    super.key,
    required this.groups,
    this.onNavigate,
    this.onChanged,
    this.density = CommonDensity.regular,
  });
  final List<CommonListGroup> groups;
  final void Function(String groupId, String itemId)? onNavigate;
  final void Function(String groupId, String itemId, bool value)? onChanged;
  final CommonDensity density;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final group in groups)
          Padding(
            key: ValueKey(group.id),
            padding: EdgeInsets.only(bottom: ts.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ts.spacing.none,
                    vertical: ts.spacing.sm,
                  ),
                  child: Text(group.title, style: ts.textStyle.captionStrong),
                ),
                CommonCard(
                  padding: EdgeInsets.zero,
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < group.items.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: ts.border.widthHairline,
                            color: ts.colors.divider,
                          ),
                        CommonListCell(
                          key: ValueKey('${group.id}/${group.items[i].id}'),
                          title: group.items[i].title,
                          description: group.items[i].description,
                          value: group.items[i].value,
                          leading: group.items[i].leading,
                          navigation: group.items[i].navigation,
                          switchValue: group.items[i].switchValue,
                          disabled: group.items[i].disabled,
                          density: density,
                          onNavigate: onNavigate == null
                              ? null
                              : () => onNavigate!(group.id, group.items[i].id),
                          onSwitchChanged: onChanged == null
                              ? null
                              : (value) => onChanged!(
                                  group.id,
                                  group.items[i].id,
                                  value,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
