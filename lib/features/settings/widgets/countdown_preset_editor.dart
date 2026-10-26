import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motion/content_transition.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/overlay/duration_sheet.dart';
import '../../../common/state/local_value.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../../focus/focus.dart';

class CountdownPresetEditor extends ConsumerStatefulWidget {
  const CountdownPresetEditor({super.key});
  @override
  ConsumerState<CountdownPresetEditor> createState() =>
      _CountdownPresetEditorState();
}

class _CountdownPresetEditorState extends ConsumerState<CountdownPresetEditor> {
  final _expanded = localValueProvider<int?>(null);
  final _restoreError = localValueProvider(false);

  Future<void> _restore() async {
    final confirmed = await AppPop.confirm(
      title: '恢复常用倒计时？',
      content: '四个常用项将恢复为 3、5、10、20 分钟，当前自定义时长会被替换。',
      cancelText: '保留当前',
      confirmText: '恢复默认',
      material: CommonSurfaceMaterial.glass,
    );
    if (!mounted || !confirmed) return;
    final saved = ref
        .read(timingPreferencesProvider.notifier)
        .update((p) => p.copyWith(presets: const [180, 300, 600, 1200]));
    ref.read(_restoreError.notifier).set(!saved);
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context), prefs = ref.watch(timingPreferencesProvider);
    final expanded = ref.watch(_expanded);
    return AppSheetContent(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++) ...[
            CommonPressableSurface(
              key: ValueKey('preset-row-$i'),
              selected: expanded == i,
              onPressed: () =>
                  ref.read(_expanded.notifier).set(expanded == i ? null : i),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ts.spacing.sm,
                  vertical: ts.spacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('常用 ${i + 1}', style: ts.textStyle.content),
                    ),
                    Text(
                      prefs.presets[i] == null
                          ? '空'
                          : durationLabel(prefs.presets[i]!),
                      style: ts.textStyle.caption,
                    ),
                    SizedBox(width: ts.spacing.sm),
                    AnimatedRotation(
                      turns: expanded == i ? .5 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : ts.motion.durationNormal,
                      child: CommonIcon(
                        name: CommonIconName.chevronDown,
                        dimension: ts.sizing.iconSm,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            MotionExpand(
              expanded: expanded == i,
              child: _PresetDurationEditor(
                index: i,
                expanded: expanded == i,
                onCleared: () => ref.read(_expanded.notifier).set(null),
              ),
            ),
          ],
        ],
      ),
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MotionExpand(
            expanded: ref.watch(_restoreError),
            child: Text(
              '尚未保存，请重试',
              style: ts.textStyle.caption.copyWith(color: ts.colors.error),
            ),
          ),
          CommonButton(
            label: '恢复默认',
            kind: CommonButtonKind.secondary,
            shape: CommonButtonShape.pill,
            block: true,
            onPressed: _restore,
          ),
        ],
      ),
    );
  }
}

class _PresetDurationEditor extends ConsumerStatefulWidget {
  const _PresetDurationEditor({
    required this.index,
    required this.expanded,
    required this.onCleared,
  });
  final int index;
  final bool expanded;
  final VoidCallback onCleared;
  @override
  ConsumerState<_PresetDurationEditor> createState() =>
      _PresetDurationEditorState();
}

class _PresetDurationEditorState extends ConsumerState<_PresetDurationEditor> {
  late final _value = localValueProvider(
    ref.read(timingPreferencesProvider).presets[widget.index] ?? 300,
  );
  final _error = localValueProvider<String?>(null);

  void _save(int? value) {
    if (!widget.expanded) return;
    final prefs = ref.read(timingPreferencesProvider);
    if (widget.index == 0 && value == null) return;
    if (value != null &&
        prefs.presets.indexed.any(
          (entry) => entry.$1 != widget.index && entry.$2 == value,
        )) {
      ref.read(_error.notifier).set('这个时长已在其它常用项中');
      return;
    }
    final next = [...prefs.presets];
    next[widget.index] = value;
    final saved = ref
        .read(timingPreferencesProvider.notifier)
        .update((p) => p.copyWith(presets: next));
    ref.read(_error.notifier).set(saved ? null : '尚未保存，请重试；关闭后可能丢失');
    if (value == null && saved) widget.onCleared();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    ref.listen(
      timingPreferencesProvider.select((p) => p.presets[widget.index]),
      (_, value) {
        ref.read(_value.notifier).set(value ?? 300);
        ref.read(_error.notifier).set(null);
      },
    );
    return Padding(
      padding: EdgeInsets.only(bottom: ts.spacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DurationWheels(
            filled: true,
            hours: false,
            maximum: maxFocusSeconds,
            value: ref.watch(_value),
            onSettled: widget.expanded ? _save : null,
            onChanged: (value) {
              ref.read(_value.notifier).set(value);
              ref.read(_error.notifier).set(null);
            },
          ),
          if (widget.expanded && widget.index != 0)
            CommonButton(
              label: '清空此项',
              kind: CommonButtonKind.quiet,
              onPressed: () => _save(null),
            ),
          MotionExpand(
            expanded: ref.watch(_error) != null,
            child: Text(
              ref.watch(_error) ?? '',
              style: ts.textStyle.caption.copyWith(color: ts.colors.error),
            ),
          ),
        ],
      ),
    );
  }
}
