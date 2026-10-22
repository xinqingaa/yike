import 'package:flutter/material.dart';

import 'app/startup.dart';
import 'storage/mmkv_app_prefs.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppStartup(openPreferences: MmkvAppPrefs.open));
}
