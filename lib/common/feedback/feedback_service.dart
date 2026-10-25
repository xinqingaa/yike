import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feedback_cue.dart';
import 'feedback_options.dart';
import 'haptic_player.dart';
import 'sound_player.dart';

/// Neither channel can delay or reject a business command. No queued playback.
class FeedbackService {
  FeedbackService({required this.soundPlayer, required this.hapticPlayer});
  final SoundPlayer soundPlayer;
  final HapticPlayer hapticPlayer;
  bool _sound = true, _haptics = true;
  Map<String, FeedbackOptions> _scopes = const {};
  String? _pendingScope;
  bool _foreground = false, _disposed = false;
  Timer? _secondImpact;

  bool get foreground => _foreground && !_disposed;

  Future<void> prepare() => _safely(soundPlayer.prepare);

  void configure({
    required bool sound,
    required bool haptics,
    required Map<String, FeedbackOptions> scopes,
  }) {
    if (_sound && !sound) unawaited(_safely(() => soundPlayer.stop()));
    for (final entry in _scopes.entries) {
      if (entry.value.sound && !(scopes[entry.key]?.sound ?? false)) {
        unawaited(_safely(() => soundPlayer.stop(scope: entry.key)));
      }
    }
    _sound = sound;
    _haptics = haptics;
    _scopes = Map.unmodifiable(scopes);
    if (!haptics || !(_scopes[_pendingScope]?.haptics ?? false)) {
      _cancelSecondImpact();
    }
  }

  void setForeground(bool value) {
    _foreground = value;
    if (!value) {
      _cancelSecondImpact();
      unawaited(_safely(() => soundPlayer.stop()));
    }
  }

  void stopScope(String scope) {
    if (_pendingScope == scope) _cancelSecondImpact();
    unawaited(_safely(() => soundPlayer.stop(scope: scope)));
  }

  void play(FeedbackCue cue, {required String theme, required String scope}) {
    final options = _scopes[scope];
    if (_disposed || !_foreground || options == null) return;
    final sound = switch (cue) {
      FeedbackCue.tick ||
      FeedbackCue.lastSecondsTick => options.secondTick ? SoundCue.tick : null,
      FeedbackCue.dialSecond => SoundCue.tick,
      FeedbackCue.dialMinute => SoundCue.chime,
      FeedbackCue.chime ||
      FeedbackCue.interval ||
      FeedbackCue.preview => SoundCue.chime,
      FeedbackCue.finish => SoundCue.finish,
      _ => null,
    };
    final haptic = switch (cue) {
      FeedbackCue.dialSecond => HapticCue.selection,
      FeedbackCue.dialLimit => HapticCue.medium,
      FeedbackCue.dialMinute ||
      FeedbackCue.lastSecondsTick ||
      FeedbackCue.light ||
      FeedbackCue.interval => HapticCue.light,
      FeedbackCue.chime => HapticCue.medium,
      FeedbackCue.finish => HapticCue.heavy,
      FeedbackCue.select => HapticCue.selection,
      _ => null,
    };
    if (_sound && options.sound && sound != null) {
      unawaited(_safely(() => soundPlayer.play(theme, sound, scope: scope)));
    }
    if (_haptics && options.haptics && haptic != null) {
      unawaited(_safely(() => hapticPlayer.play(haptic)));
      if (cue == FeedbackCue.finish) {
        _cancelSecondImpact();
        _pendingScope = scope;
        _secondImpact = Timer(const Duration(milliseconds: 120), () {
          _secondImpact = null;
          _pendingScope = null;
          if (!_disposed &&
              _foreground &&
              _haptics &&
              (_scopes[scope]?.haptics ?? false)) {
            unawaited(_safely(() => hapticPlayer.play(HapticCue.heavy)));
          }
        });
      }
    }
  }

  /// Read-only inspection can follow the master gate or an existing scope.
  void select({String? scope}) {
    if (!foreground ||
        !_haptics ||
        (scope != null && !(_scopes[scope]?.haptics ?? false))) {
      return;
    }
    unawaited(_safely(() => hapticPlayer.play(HapticCue.selection)));
  }

  /// Settings audition uses only the master sound gate and never vibrates.
  void previewFinish({required String theme}) {
    if (_disposed || !_foreground || !_sound) return;
    unawaited(
      _safely(() => soundPlayer.play(theme, SoundCue.finish, scope: 'preview')),
    );
  }

  void _cancelSecondImpact() {
    _secondImpact?.cancel();
    _secondImpact = null;
    _pendingScope = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    _cancelSecondImpact();
    await _safely(soundPlayer.dispose);
  }

  static Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      /* Feedback never blocks the app. */
    }
  }
}

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  final service = FeedbackService(
    soundPlayer: SoLoudSoundPlayer(),
    hapticPlayer: SystemHapticPlayer(),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
