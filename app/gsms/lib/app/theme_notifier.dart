import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeNotifier extends ChangeNotifier {
  final _settingsBox = Hive.box('settings');
  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  ThemeNotifier() {
    // Lê o tema salvo ou usa o padrão (system)
    final isDarkMode = _settingsBox.get('isDarkMode');
    if (isDarkMode == null) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;

    _themeMode = mode;
    // Salva a preferência no Hive
    // Salva null para 'system', true para 'dark', false para 'light'
    _settingsBox.put(
      'isDarkMode',
      mode == ThemeMode.system ? null : mode == ThemeMode.dark,
    );
    notifyListeners();
  }

  void toggleTheme() {
    final isDarkMode = _themeMode == ThemeMode.dark;
    setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }
}
