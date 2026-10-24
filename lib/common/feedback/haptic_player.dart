import 'package:flutter/services.dart';
import 'feedback_cue.dart';

abstract interface class HapticPlayer {
  Future<void> play(HapticCue cue);
}

class SystemHapticPlayer implements HapticPlayer {
  @override
  Future<void> play(HapticCue cue) => switch (cue) {
    HapticCue.light => HapticFeedback.lightImpact(),
    HapticCue.medium => HapticFeedback.mediumImpact(),
    HapticCue.heavy => HapticFeedback.heavyImpact(),
    HapticCue.selection => HapticFeedback.selectionClick(),
  };
}
