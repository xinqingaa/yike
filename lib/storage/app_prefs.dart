/// Application preferences. MMKV is the sole production implementation.
abstract class AppPrefs {
  static const themeModeKey = 'theme_mode';
  static const themePackKey = 'theme_pack';

  String? readString(String key);
  void writeString(String key, String value);
  void remove(String key);

  String? readThemeMode() {
    final mode = readString(themeModeKey);
    return mode == 'light' || mode == 'dark' ? mode : null;
  }

  void writeThemeMode(String mode) {
    if (mode != 'light' && mode != 'dark') {
      throw ArgumentError.value(mode, 'mode', 'Must be light or dark.');
    }
    writeString(themeModeKey, mode);
  }
}
