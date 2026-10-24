import '../../../storage/app_prefs.dart';
import 'local_data.dart';

final localDataPrefs = PrefsEntry<YikeData>(
  PrefsKey.snapshot,
  VersionedJsonPrefsCodec(
    schemaVersion: 2,
    fromJson: YikeData.fromJson,
    toJson: (data) => data.toJson(),
  ),
);
