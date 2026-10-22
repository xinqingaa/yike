import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_prefs.dart';

final appPrefsProvider = Provider<AppPrefs>((ref) {
  throw StateError('Initialize MMKV and override appPrefsProvider at startup.');
}, dependencies: const []);
