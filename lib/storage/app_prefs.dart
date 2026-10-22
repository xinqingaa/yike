/// Application preferences. MMKV is the sole production implementation.
abstract class AppPrefs {
  static const themeModeKey = 'theme_mode';
  static const themePackKey = 'theme_pack';

  String? readString(String key);
  void writeString(String key, String value);
  void remove(String key);

  String? readThemeMode() {
    final mode = readString(themeModeKey);
    return mode == 'light' || mode == 'dark' || mode == 'system' ? mode : null;
  }

  void writeThemeMode(String mode) {
    if (mode != 'light' && mode != 'dark' && mode != 'system') {
      throw ArgumentError.value(mode, 'mode', 'Must be light, dark or system.');
    }
    writeString(themeModeKey, mode);
  }
}
