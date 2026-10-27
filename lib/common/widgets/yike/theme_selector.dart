import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/ts.dart';
import 'dial.dart';

/// The shared theme choice shown in settings and the first-use introduction.
class YikeThemeSelector extends ConsumerWidget {
  const YikeThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = TS.of(context);
    final selected = ref.watch(themePackProvider);
    final packs = ref
        .watch(themePacksProvider)
        .where((pack) => pack.id.startsWith('yike/'))
        .toList();
    return Row(
      children: [
        for (var i = 0; i < packs.length; i++) ...[
          if (i > 0) SizedBox(width: ts.spacing.sm),
          Expanded(
            child: Semantics(
              selected: selected.id == packs[i].id,
              button: true,
              child: InkWell(
                key: ValueKey('theme-${packs[i].id}'),
                onTap: () =>
                    ref.read(themePackProvider.notifier).select(packs[i].id),
                borderRadius: BorderRadius.circular(ts.radius.md),
                child: Container(
                  padding: EdgeInsets.all(ts.spacing.sm),
                  decoration: BoxDecoration(
                    color: ts.colors.surface,
                    border: Border.fromBorderSide(
                      selected.id == packs[i].id
                          ? ts.border.focus
                          : ts.border.defaultBorder,
                    ),
                    borderRadius: BorderRadius.circular(ts.radius.md),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: ts.sizing.brand,
                        child: FittedBox(
                          child: YikeDial(
                            tokens: ts.forPack(packs[i]),
                            digits: '12:34',
                            progress: 12.5 / 60,
                          ),
                        ),
                      ),
                      SizedBox(height: ts.spacing.sm),
                      Text(
                        const ['机械', '水位', '日影'][i],
                        style: ts.textStyle.label,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
