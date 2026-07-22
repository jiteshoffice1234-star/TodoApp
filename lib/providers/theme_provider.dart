import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = const Color(0xFF1976D2);
  static const String _themeKey = 'theme_mode';
  static const String _accentKey = 'accent_color';

  static const List<Color> availableColors = [
    Color(0xFF1976D2), // Blue
    Color(0xFF388E3C), // Green
    Color(0xFFD32F2F), // Red
    Color(0xFF7B1FA2), // Purple
    Color(0xFFFF9800), // Orange
    Color(0xFF00796B), // Teal
    Color(0xFFC2185B), // Pink
    Color(0xFF455A64), // Blue Grey
    Color(0xFF512DA8), // Deep Purple
    Color(0xFF0097A7), // Cyan
    Color(0xFF689F38), // Light Green
    Color(0xFFF57C00), // Deep Orange
  ];

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeValue = prefs.getString(_themeKey);
    if (themeValue == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeValue == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    
    final accentValue = prefs.getInt(_accentKey);
    if (accentValue != null) {
      _accentColor = Color(accentValue);
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _themeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.value);
    notifyListeners();
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;
}
