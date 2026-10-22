import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

enum CommonDataListSurface { none, standard, raised }

enum CommonDataListRounded { none, sm, md, lg }

/// Flutter 原生列表；PBWork `data-list` 的 item slot 翻译为 builder。
class CommonDataList extends StatelessWidget {
  const CommonDataList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.divided = true,
    this.inset = false,
    this.surface = CommonDataListSurface.standard,
    this.rounded = CommonDataListRounded.md,
    this.elevated = false,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.controller,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final bool divided;
  final bool inset;
  final CommonDataListSurface surface;
  final CommonDataListRounded rounded;
  final bool elevated;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  double _radius(TS ts) => switch (rounded) {
    CommonDataListRounded.none => ts.radius.none,
    CommonDataListRounded.sm => ts.radius.sm,
    CommonDataListRounded.md => ts.radius.md,
    CommonDataListRounded.lg => ts.radius.lg,
  };

  Color? _surfaceColor(TS ts) => switch (surface) {
    CommonDataListSurface.none => null,
    CommonDataListSurface.standard => ts.colors.surface,
    CommonDataListSurface.raised => ts.colors.surfaceRaised,
  };

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final effectivePadding = inset
        ? (padding ?? EdgeInsets.zero).add(
            EdgeInsets.symmetric(horizontal: ts.spacing.md),
          )
        : padding;
    final list = divided
        ? ListView.separated(
            controller: controller,
            shrinkWrap: shrinkWrap,
            physics: physics,
            padding: effectivePadding,
            itemCount: itemCount,
            itemBuilder: itemBuilder,
            separatorBuilder:
                separatorBuilder ??
                (_, _) => Divider(
                  height: ts.border.widthHairline,
                  thickness: ts.border.widthHairline,
                  color: ts.colors.border,
                ),
          )
        : ListView.builder(
            controller: controller,
            shrinkWrap: shrinkWrap,
            physics: physics,
            padding: effectivePadding,
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );

    if (_surfaceColor(ts) == null &&
        !elevated &&
        _radius(ts) == ts.radius.none) {
      return list;
    }
    return Material(
      color: _surfaceColor(ts) ?? Colors.transparent,
      elevation: elevated ? ts.elevation.card : ts.elevation.none,
      shadowColor: ts.colors.scrim,
      borderRadius: BorderRadius.circular(_radius(ts)),
      clipBehavior: Clip.antiAlias,
      child: list,
    );
  }
}
