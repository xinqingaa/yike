import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/overlay/app_pop.dart';
import '../common/state/local_value.dart';
import '../common/overlay/popup_activity.dart';
import '../common/widgets.dart';
import '../features/local_data/local_data.dart';
import '../storage/preference_writer.dart';
import '../theme/ts.dart';
import '../theme/yike_motion.dart';

/// Coordinates one persistent popup without changing the navigator's constraints.
class UnsavedStatus extends ConsumerStatefulWidget {
  const UnsavedStatus({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<UnsavedStatus> createState() => _UnsavedStatusState();
}

class _UnsavedStatusState extends ConsumerState<UnsavedStatus> {
  final _shown = ValueNotifier(true);
  AppStatusPopup? _popup;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(popupActivityProvider, (_, _) => _schedule());
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _sync();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _sync() {
    final data = ref.read(localDataProvider);
    final modalOpen = ref.read(popupActivityProvider) > 0;
    final failed =
        data.readError == null &&
        (data.writeError != null ||
            ref.read(preferenceWriterProvider).isNotEmpty);
    final popup = _popup;
    if (popup != null) {
      if (data.readError != null || (!failed && modalOpen)) {
        unawaited(popup.dismiss());
      } else {
        _shown.value = failed;
        popup.suspend(modalOpen);
      }
      return;
    }
    if (!failed || modalOpen) return;
    _shown.value = true;
    final container = ProviderScope.containerOf(context);
    final opened = AppPop.status(
      content: UncontrolledProviderScope(
        container: container,
        child: _UnsavedBar(
          shown: _shown,
          onHidden: () {
            if (mounted && !_shown.value) unawaited(_popup?.dismiss());
          },
        ),
      ),
    );
    _popup = opened;
    opened?.dismissed.then((_) {
      if (identical(_popup, opened)) _popup = null;
      if (mounted) _schedule();
    });
  }

  @override
  void dispose() {
    final closing = _popup;
    if (closing == null) {
      _shown.dispose();
    } else {
      unawaited(closing.dismiss());
      closing.dismissed.then((_) => _shown.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      localDataProvider.select((s) => (s.readError, s.writeError)),
      (_, _) => _schedule(),
    );
    ref.listen(preferenceWriterProvider, (_, _) => _schedule());
    _schedule();
    return widget.child;
  }
}

class _UnsavedBar extends ConsumerStatefulWidget {
  const _UnsavedBar({required this.shown, required this.onHidden});
  final ValueNotifier<bool> shown;
  final VoidCallback onHidden;
  @override
  ConsumerState<_UnsavedBar> createState() => _UnsavedBarState();
}

class _UnsavedBarState extends ConsumerState<_UnsavedBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this);
  final _collapsed = localValueProvider(false);
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    widget.shown.addListener(_sync);
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !widget.shown.value) {
        widget.onHidden();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _animation.duration = TS.of(context).motion.durationNormal;
    _sync();
  }

  void _sync() {
    final target = widget.shown.value ? 1.0 : 0.0;
    if (_reduced) {
      _animation.value = target;
      if (target == 0) widget.onHidden();
    } else if (target == 1) {
      _animation.forward();
    } else {
      _animation.reverse();
    }
  }

  @override
  void dispose() {
    widget.shown.removeListener(_sync);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.all(ts.spacing.sm),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) => IgnorePointer(
            ignoring: !widget.shown.value,
            child: ExcludeSemantics(
              excluding: !widget.shown.value,
              child: Opacity(
                opacity: _animation.value,
                child: FractionalTranslation(
                  translation: Offset(
                    0,
                    -YikeMotion.contentTravel * (1 - _animation.value),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
          child: Material(
            key: const ValueKey('unsaved-status'),
            elevation: ts.elevation.none,
            color: ts.colors.surface,
            shape: RoundedRectangleBorder(
              side: ts.border.defaultBorder,
              borderRadius: BorderRadius.circular(ts.radius.md),
            ),
            child: Padding(
              padding: EdgeInsets.all(ts.spacing.sm),
              child: ref.watch(_collapsed)
                  ? CommonButton(
                      label: '未保存',
                      kind: CommonButtonKind.quiet,
                      onPressed: () => ref.read(_collapsed.notifier).set(false),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            '尚未保存，关闭后可能丢失',
                            style: ts.textStyle.caption.copyWith(
                              color: ts.colors.error,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: ts.spacing.sm,
                          children: [
                            CommonButton(
                              label: '重试保存',
                              kind: CommonButtonKind.quiet,
                              onPressed: () {
                                ref.read(localDataProvider.notifier).retry();
                                ref
                                    .read(preferenceWriterProvider.notifier)
                                    .retry();
                              },
                            ),
                            CommonButton(
                              label: '收起提示',
                              kind: CommonButtonKind.quiet,
                              onPressed: () =>
                                  ref.read(_collapsed.notifier).set(true),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
