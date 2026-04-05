import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModePrefsKey = 'theme_mode';

final themeModeProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadThemeMode();
    return ThemeMode.dark;
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeModePrefsKey);

    if (saved == 'light') {
      state = ThemeMode.light;
      return;
    }
    if (saved == 'dark') {
      state = ThemeMode.dark;
      return;
    }

    state = ThemeMode.dark;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeModePrefsKey,
      mode == ThemeMode.light ? 'light' : 'dark',
    );
  }

  Future<void> toggleMode(bool isLightMode) async {
    await setThemeMode(isLightMode ? ThemeMode.light : ThemeMode.dark);
  }
}
