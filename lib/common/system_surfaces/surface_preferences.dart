import '../../storage/app_prefs.dart';

class SurfacePreferences {
  const SurfacePreferences(
    this.epoch, {
    this.liveEnabled = true,
    this.consumed = const [],
  });
  final String epoch;
  final bool liveEnabled;
  final List<String> consumed;
  Map<String, Object> toJson() => {
    'epoch': epoch,
    'liveEnabled': liveEnabled,
    'consumed': consumed,
  };
  factory SurfacePreferences.fromJson(Map<String, dynamic> json) {
    final epoch = json['epoch'];
    if (epoch is! String ||
        epoch.isEmpty ||
        json['liveEnabled'] is! bool ||
        json['consumed'] is! List ||
        (json['consumed'] as List).length > 64 ||
        (json['consumed'] as List).any((v) => v is! String)) {
      throw const FormatException('Invalid surface preferences');
    }
    return SurfacePreferences(
      epoch,
      liveEnabled: json['liveEnabled'] as bool,
      consumed: List<String>.from(json['consumed'] as List),
    );
  }
}

final surfacePreferences = PrefsEntry<SurfacePreferences>(
  PrefsKey.systemSurfaces,
  VersionedJsonPrefsCodec(
    schemaVersion: 1,
    fromJson: SurfacePreferences.fromJson,
    toJson: (p) => p.toJson(),
  ),
);
