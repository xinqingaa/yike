import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'feedback_cue.dart';

abstract interface class SoundPlayer {
  bool get ready;
  Future<void> prepare();
  Future<void> play(String theme, SoundCue cue, {required String scope});
  Future<void> stop({String? scope});
  Future<void> dispose();
}

/// Preloads short effects once. Playback never waits for initialization.
class SoLoudSoundPlayer implements SoundPlayer {
  late final SoLoud _engine = SoLoud.instance;
  final _sources = <String, AudioSource>{};
  final _voices = <SoundHandle, String>{};
  Future<void>? _preparing;
  StreamSubscription<AudioInterruptionEvent>? _interruptions;
  bool _ready = false, _disposed = false, _interrupted = false;
  bool _initialized = false;

  static const _themes = {
    'yike/mechanical': 'mechanical',
    'yike/water': 'water',
    'yike/sundial': 'sundial',
  };

  @override
  bool get ready => _ready;

  @override
  Future<void> prepare() => _preparing ??= _prepare();

  Future<void> _prepare() async {
    try {
      final session = await AudioSession.instance;
      if (_disposed) return;
      // Ambient already mixes with other audio and respects the iOS mute switch.
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.ambient,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.assistanceSonification,
          ),
        ),
      );
      if (_disposed) return;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        if (!await session.setActive(true)) return;
      }
      if (_disposed) return;
      await _engine.init();
      _initialized = true;
      if (_disposed) return;
      for (final theme in _themes.values) {
        for (final cue in SoundCue.values) {
          _sources['$theme-${cue.name}'] = await _engine.loadAsset(
            'asset/yike/sound/$theme-${cue.name}.wav',
          );
          if (_disposed) return;
        }
      }
      _interruptions = session.interruptionEventStream.listen((event) {
        _interrupted = event.begin;
        if (event.begin) unawaited(stop().catchError((Object _) {}));
      });
      _ready = true;
    } catch (_) {
      // Haptics and business commands remain available without audio.
      _ready = false;
      if (_initialized) {
        _engine.deinit();
        _initialized = false;
      }
    } finally {
      if (_disposed && _initialized) {
        _engine.deinit();
        _initialized = false;
      }
    }
  }

  @override
  Future<void> play(String theme, SoundCue cue, {required String scope}) async {
    if (!_ready || _disposed || _interrupted) return;
    final name = _themes[theme];
    final source = name == null ? null : _sources['$name-${cue.name}'];
    if (source == null) return;
    _voices.removeWhere((handle, _) => !_engine.getIsValidVoiceHandle(handle));
    _voices[_engine.play(source)] = scope;
  }

  @override
  Future<void> stop({String? scope}) async {
    if (!_initialized) return;
    final voices = _voices.entries
        .where((e) => scope == null || e.value == scope)
        .map((e) => e.key)
        .toList();
    for (final handle in voices) {
      _voices.remove(handle);
    }
    await Future.wait(voices.map(_engine.stop));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _ready = false;
    await _interruptions?.cancel();
    // A pending preload owns its native resources until it has unwound.
    await _preparing;
    if (_initialized) {
      _engine.deinit();
      _initialized = false;
    }
    _sources.clear();
    _voices.clear();
  }
}
