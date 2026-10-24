// Temporary stage 1 acceptance support. Remove after user acceptance.
import 'package:yike/common/feedback/feedback_cue.dart';
import 'package:yike/common/feedback/sound_player.dart';
import 'package:yike/common/feedback/haptic_player.dart';

class RecordingSoundPlayer implements SoundPlayer {
  final plays = <(String, SoundCue)>[];
  bool fail = false;
  int stops = 0;
  @override
  bool ready = false;
  @override
  Future<void> prepare() async {
    ready = true;
  }

  @override
  Future<void> play(String theme, SoundCue cue, {required String scope}) async {
    if (fail) throw StateError('audio unavailable');
    plays.add((theme, cue));
  }

  @override
  Future<void> stop({String? scope}) async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    ready = false;
  }
}

class RecordingHapticPlayer implements HapticPlayer {
  final plays = <HapticCue>[];
  @override
  Future<void> play(HapticCue cue) async {
    plays.add(cue);
  }
}
