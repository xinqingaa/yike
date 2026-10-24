import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/feedback/feedback_cue.dart';
import 'package:yike/common/feedback/feedback_service.dart';
import 'package:yike/common/feedback/feedback_options.dart';
import 'package:yike/common/feedback/haptic_player.dart';
import 'package:yike/common/feedback/sound_player.dart';

class _Sounds implements SoundPlayer {
  final calls = <(String, SoundCue)>[];
  @override
  bool get ready => true;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> play(String theme, SoundCue cue, {required String scope}) async {
    calls.add((theme, cue));
  }

  @override
  Future<void> stop({String? scope}) async {}
  @override
  Future<void> dispose() async {}
}

class _Haptics implements HapticPlayer {
  final calls = <HapticCue>[];
  @override
  Future<void> play(HapticCue cue) async {
    calls.add(cue);
  }
}

void main() {
  test(
    'settings audition plays theme finish without local gates or haptics; master and lifecycle still gate it',
    () async {
      final sounds = _Sounds(), haptics = _Haptics();
      final service = FeedbackService(
        soundPlayer: sounds,
        hapticPlayer: haptics,
      );
      service.setForeground(true);
      service.configure(
        sound: true,
        haptics: true,
        scopes: const {'countdown': FeedbackOptions(sound: false)},
      );
      service.previewFinish(theme: 'yike/water');
      expect(sounds.calls, [('yike/water', SoundCue.finish)]);
      expect(haptics.calls, isEmpty);
      service.configure(sound: false, haptics: true, scopes: const {});
      service.previewFinish(theme: 'yike/mechanical');
      service.configure(sound: true, haptics: true, scopes: const {});
      service.setForeground(false);
      service.previewFinish(theme: 'yike/mechanical');
      expect(sounds.calls, hasLength(1));
      await service.dispose();
    },
  );
}
