import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeOption _themeOption = ThemeOption.light;
  Color _accentColor = const Color(0xFF1976D2);
  static const String _themeKey = 'theme_option';
  static const String _accentKey = 'accent_color';

  static const List<Color> availableColors = [
    Color(0xFF1976D2), Color(0xFF388E3C), Color(0xFFD32F2F),
    Color(0xFF7B1FA2), Color(0xFFFF9800), Color(0xFF00796B),
    Color(0xFFC2185B), Color(0xFF455A64), Color(0xFF512DA8),
    Color(0xFF0097A7), Color(0xFF689F38), Color(0xFFF57C00),
  ];

  ThemeOption get themeOption => _themeOption;
  Color get accentColor => _accentColor;
  bool get isDarkMode => _themeOption == ThemeOption.dark || _themeOption == ThemeOption.glass;

  ThemeProvider() { _loadTheme(); }

  ThemeData get themeData {
    switch (_themeOption) {
      case ThemeOption.light:
        return AppTheme.light(accentColor: _accentColor);
      case ThemeOption.dark:
        return AppTheme.dark(accentColor: _accentColor);
      case ThemeOption.neobrutalism:
        return AppTheme.neobrutalism();
      case ThemeOption.glass:
        return AppTheme.glass();
      case ThemeOption.minimal:
        return AppTheme.minimal();
      case ThemeOption.clay:
        return AppTheme.clay();
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeValue = prefs.getString(_themeKey) ?? 'light';
    _themeOption = ThemeOption.values.firstWhere(
      (t) => t.name == themeValue,
      orElse: () => ThemeOption.light,
    );
    final accentValue = prefs.getInt(_accentKey);
    if (accentValue != null) {
      _accentColor = Color(accentValue);
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeOption option) async {
    _themeOption = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, option.name);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final idx = ThemeOption.values.indexOf(_themeOption);
    final next = (idx + 1) % ThemeOption.values.length;
    await setTheme(ThemeOption.values[next]);
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.value);
    notifyListeners();
  }
}
