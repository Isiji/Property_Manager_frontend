import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:property_manager_frontend/theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = AppTheme.primaryBlue;
  String _fontFamily = "Poppins";

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  String get fontFamily => _fontFamily;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('themeMode') ?? 'system';
    final colorValue = prefs.getInt('accentColor') ?? AppTheme.primaryBlue.value;
    final font = prefs.getString('font') ?? 'Poppins';

    _themeMode = theme == 'dark'
        ? ThemeMode.dark
        : theme == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
    _accentColor = Color(colorValue);
    _fontFamily = font;
    notifyListeners();
  }

  Future<void> updateTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('themeMode', mode.name);
    notifyListeners();
  }

  Future<void> updateAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('accentColor', color.value);
    notifyListeners();
  }

  Future<void> updateFont(String font) async {
    _fontFamily = font;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('font', font);
    notifyListeners();
  }
}
