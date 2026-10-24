import 'package:flutter/foundation.dart';

/// Per-source preferences. Master switches are applied by FeedbackService.
@immutable
class FeedbackOptions {
  const FeedbackOptions({
    this.sound = true,
    this.haptics = true,
    this.secondTick = false,
    this.beatMinutes = 5,
  });
  final bool sound, haptics, secondTick;
  final int beatMinutes;

  FeedbackOptions copyWith({
    bool? sound,
    bool? haptics,
    bool? secondTick,
    int? beatMinutes,
  }) => FeedbackOptions(
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    secondTick: secondTick ?? this.secondTick,
    beatMinutes: beatMinutes ?? this.beatMinutes,
  );
}
