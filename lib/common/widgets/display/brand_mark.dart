import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

enum CommonBrandLayout { inline, stacked }

class CommonBrandMark extends StatelessWidget {
  const CommonBrandMark({
    super.key,
    required this.name,
    this.mark,
    this.wordmark,
    this.layout = CommonBrandLayout.inline,
  });
  final String name;
  final Widget? mark;
  final Widget? wordmark;
  final CommonBrandLayout layout;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final markAsset = ts.assets.brandMark;
    final wordmarkAsset = ts.assets.brandWordmark;
    final brand =
        mark ??
        (markAsset == null
            ? null
            : Image.asset(
                markAsset,
                width: ts.sizing.brand,
                height: ts.sizing.brand,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ));
    final nameWidget = Text(name, style: ts.textStyle.titleLg);
    final text =
        wordmark ??
        (wordmarkAsset == null
            ? nameWidget
            : Image.asset(
                wordmarkAsset,
                height: ts.sizing.brand,
                semanticLabel: name,
                errorBuilder: (_, _, _) => nameWidget,
              ));
    final children = <Widget>[
      if (brand != null) ...[
        brand,
        SizedBox(
          width: layout == CommonBrandLayout.inline ? ts.spacing.sm : null,
          height: layout == CommonBrandLayout.stacked ? ts.spacing.sm : null,
        ),
      ],
      text,
    ];
    return layout == CommonBrandLayout.inline
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (brand != null) ...[brand, SizedBox(width: ts.spacing.sm)],
              Flexible(child: text),
            ],
          )
        : Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}
