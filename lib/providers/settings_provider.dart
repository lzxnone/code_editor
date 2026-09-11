import 'package:code_editor/models/editor_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _keyEditorTheme = 'editor_theme_id';
  static const String _keyAppThemeMode = 'app_theme_mode';
  static const String _keyEditorFontSize = 'editor_font_size';
  static const String _keyWordWrap = 'editor_word_wrap';
  static const String _keyAppLocale = 'app_locale';

  EditorTheme _editorTheme = EditorTheme.atomOneDark;
  ThemeMode _appThemeMode = ThemeMode.system;
  double _fontSize = 14.0;
  bool _wordWrap = true;
  Locale? _locale;

  EditorTheme get editorTheme => _editorTheme;
  ThemeMode get appThemeMode => _appThemeMode;
  double get fontSize => _fontSize;
  bool get wordWrap => _wordWrap;
  Locale? get locale => _locale;

  Future<void> init() async {
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString(_keyEditorTheme);
      _editorTheme = EditorTheme.fromId(themeId);

      final themeModeName = prefs.getString(_keyAppThemeMode);
      if (themeModeName != null) {
        _appThemeMode = ThemeMode.values.firstWhere(
          (e) => e.name == themeModeName,
          orElse: () => ThemeMode.system,
        );
      }

      final savedFontSize = prefs.getDouble(_keyEditorFontSize);
      if (savedFontSize != null && savedFontSize >= 10 && savedFontSize <= 32) {
        _fontSize = savedFontSize;
      }

      final savedWordWrap = prefs.getBool(_keyWordWrap);
      if (savedWordWrap != null) {
        _wordWrap = savedWordWrap;
      }

      final savedLocale = prefs.getString(_keyAppLocale);
      if (savedLocale != null && savedLocale.isNotEmpty) {
        _locale = Locale(savedLocale);
      } else {
        _locale = null; // null 表示跟随系统
      }

      notifyListeners();
    } catch (_) {}
  }

  Future<void> setEditorTheme(EditorTheme theme) async {
    if (_editorTheme.id == theme.id) return;
    _editorTheme = theme;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEditorTheme, theme.id);
    } catch (_) {}
  }

  Future<void> setAppThemeMode(ThemeMode mode) async {
    if (_appThemeMode == mode) return;
    _appThemeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAppThemeMode, mode.name);
    } catch (_) {}
  }

  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(10.0, 30.0);
    if (_fontSize == clamped) return;
    _fontSize = clamped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyEditorFontSize, clamped);
    } catch (_) {}
  }

  Future<void> setWordWrap(bool wrap) async {
    if (_wordWrap == wrap) return;
    _wordWrap = wrap;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyWordWrap, wrap);
    } catch (_) {}
  }

  Future<void> setLocale(Locale? newLocale) async {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (newLocale == null) {
        await prefs.remove(_keyAppLocale);
      } else {
        await prefs.setString(_keyAppLocale, newLocale.languageCode);
      }
    } catch (_) {}
  }
}
