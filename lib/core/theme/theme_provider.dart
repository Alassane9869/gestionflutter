import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';

class ThemeSettings {
  final ThemeMode mode;
  final AppThemeColor color;

  const ThemeSettings({
    this.mode = ThemeMode.light,
    this.color = AppThemeColor.orange, // Par défaut sur Orange
  });

  ThemeSettings copyWith({ThemeMode? mode, AppThemeColor? color}) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      color: color ?? this.color,
    );
  }
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeSettings>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<ThemeSettings> {
  static const _modeKey = 'selected_theme_mode';
  static const _colorKey = 'selected_theme_color';

  @override
  ThemeSettings build() {
    _loadTheme();
    return const ThemeSettings();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    ThemeMode mode = ThemeMode.light;
    final modeStr = prefs.getString(_modeKey);
    if (modeStr == 'dark') mode = ThemeMode.dark;
    
    AppThemeColor color = AppThemeColor.orange; // Par défaut Orange
    final colorIndex = prefs.getInt(_colorKey);
    if (colorIndex != null && colorIndex < AppThemeColor.values.length) {
      color = AppThemeColor.values[colorIndex];
    }
    
    state = ThemeSettings(mode: mode, color: color);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setThemeColor(AppThemeColor color) async {
    state = state.copyWith(color: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.index);
  }
}
