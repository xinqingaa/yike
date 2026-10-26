import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/feedback/feedback_cue.dart';
import '../../../common/feedback/feedback_service.dart';
import '../../../theme/ts.dart';
import '../../../theme/yike_motion.dart';
import '../../focus/focus.dart';

class SoundAudition extends Notifier<SoundCue?> {
  Timer? _pulse, _end;

  @override
  SoundCue? build() {
    final service = ref.read(feedbackServiceProvider);
    ref.onDispose(() {
      _pulse?.cancel();
      _end?.cancel();
      service.stopPreview();
    });
    ref.listen(timingPreferencesProvider.select((p) => p.sound), (_, sound) {
      if (!sound) stop();
    });
    ref.listen(themePackProvider, (_, _) => stop());
    return null;
  }

  void stop() {
    _pulse?.cancel();
    _end?.cancel();
    ref.read(feedbackServiceProvider).stopPreview();
    state = null;
  }

  void toggle(SoundCue cue) {
    final wasPlaying = state == cue;
    stop();
    if (wasPlaying || !ref.read(timingPreferencesProvider).sound) return;
    final service = ref.read(feedbackServiceProvider);
    if (!service.foreground) return;
    final theme = ref.read(themePackProvider).id;
    state = cue;
    service.previewSound(theme: theme, cue: cue);
    if (cue == SoundCue.tick) {
      _pulse = Timer.periodic(YikeMotion.auditionTick, (_) {
        if (!service.foreground) {
          stop();
          return;
        }
        service.previewSound(theme: theme, cue: cue);
      });
    }
    _end = Timer(
      cue == SoundCue.tick
          ? YikeMotion.auditionTicks
          : YikeMotion.auditionSingle,
      stop,
    );
  }
}

final soundAuditionProvider =
    NotifierProvider.autoDispose<SoundAudition, SoundCue?>(
      SoundAudition.new,
      dependencies: [
        feedbackServiceProvider,
        timingPreferencesProvider,
        themePackProvider,
      ],
    );
