import 'dart:convert';
import 'package:code_editor/models/app_font.dart';
import 'package:code_editor/models/editor_theme.dart';
import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  //外观
  static const String _keyAppThemeMode = 'app_theme_mode'; //应用主题
  static const String _keyUiFont = 'app_ui_font'; //界面字体

  //编辑区
  static const String _keyEditorTheme = 'editor_theme_id'; //代码主题
  static const String _keyEditorFontSize = 'editor_font_size'; //代码字体大小
  static const String _keyEditorIndentSize = 'editor_indent_size'; //缩进大小
  static const String _keyWordWrap = 'editor_word_wrap';  //自动换行
  static const String _keyEnableVirtualKeyboard = 'enable_virtual_keyboard'; //小键盘启用
  static const String _keyVirtualKeyboardConfig = 'virtual_keyboard_config'; //小键盘配置JSON
  static const String _keyEditorFont = 'editor_font_family'; //代码字体

  //终端
  static const String _keyTerminalFont = 'terminal_font_family'; //终端字体

  //语言
  static const String _keyAppLocale = 'app_locale';

  ThemeMode _appThemeMode = ThemeMode.system;
  String _uiFontId = 'system_default';
  EditorTheme _editorTheme = EditorTheme.atomOneDark;
  String _editorFontId = 'monospace';
  String _terminalFontId = 'monospace';
  double _fontSize = 14.0;
  int _indentSize = 2;
  bool _wordWrap = true;
  bool _enableVirtualKeyboard = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  String _virtualKeyboardConfigJson = VirtualKeyboardConfig.defaultJsonPretty();
  VirtualKeyboardConfig _virtualKeyboardConfig = VirtualKeyboardConfig.defaultConfiguration();
  Locale? _locale;

  ThemeMode get appThemeMode => _appThemeMode;
  String get uiFontId => _uiFontId;
  AppFontItem get uiFont => AppFonts.getUiFont(_uiFontId);

  EditorTheme get editorTheme => _editorTheme;
  String get editorFontId => _editorFontId;
  AppFontItem get editorFont => AppFonts.getEditorFont(_editorFontId);

  String get terminalFontId => _terminalFontId;
  AppFontItem get terminalFont => AppFonts.getTerminalFont(_terminalFontId);

  double get fontSize => _fontSize;
  int get indentSize => _indentSize;
  bool get wordWrap => _wordWrap;
  bool get enableVirtualKeyboard => _enableVirtualKeyboard;
  String get virtualKeyboardConfigJson => _virtualKeyboardConfigJson;
  VirtualKeyboardConfig get virtualKeyboardConfig => _virtualKeyboardConfig;
  Locale? get locale => _locale;

  Future<void> init() async {
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      //设置外观
      final themeModeName = prefs.getString(_keyAppThemeMode);
      if(themeModeName != null) {
        _appThemeMode = ThemeMode.values.firstWhere(
          (e) => e.name == themeModeName,
          orElse: () => ThemeMode.system,
        );
      }

      //设置编辑区
      final themeId = prefs.getString(_keyEditorTheme);
      _editorTheme = EditorTheme.fromId(themeId);

      
      final savedFontSize = prefs.getDouble(_keyEditorFontSize);
      if(savedFontSize != null && savedFontSize >= 10 && savedFontSize <= 32) {
        _fontSize = savedFontSize;
      }

      final savedIndentSize = prefs.getInt(_keyEditorIndentSize);
      if (savedIndentSize != null && (savedIndentSize == 2 || savedIndentSize == 4 || savedIndentSize == 8)) {
        _indentSize = savedIndentSize;
      }

      final savedWordWrap = prefs.getBool(_keyWordWrap);
      if(savedWordWrap != null) {
        _wordWrap = savedWordWrap;
      }

      final savedEnableVirtualKeyboard = prefs.getBool(_keyEnableVirtualKeyboard);
      if (savedEnableVirtualKeyboard != null) {
        _enableVirtualKeyboard = savedEnableVirtualKeyboard;
      }

      final savedKeyboardConfig = prefs.getString(_keyVirtualKeyboardConfig);
      if (savedKeyboardConfig != null && savedKeyboardConfig.trim().isNotEmpty) {
        final err = VirtualKeyboardConfig.validateJson(savedKeyboardConfig);
        if (err == null) {
          try {
            final decoded = jsonDecode(savedKeyboardConfig) as Map<String, dynamic>;
            _virtualKeyboardConfig = VirtualKeyboardConfig.fromJson(decoded);
            _virtualKeyboardConfigJson = savedKeyboardConfig;
          } catch (_) {}
        }
      }

      //设置字体
      final savedUiFont = prefs.getString(_keyUiFont);
      if (savedUiFont != null && savedUiFont.isNotEmpty) {
        _uiFontId = savedUiFont;
      }

      final savedEditorFont = prefs.getString(_keyEditorFont);
      if (savedEditorFont != null && savedEditorFont.isNotEmpty) {
        _editorFontId = savedEditorFont;
      }

      final savedTerminalFont = prefs.getString(_keyTerminalFont);
      if (savedTerminalFont != null && savedTerminalFont.isNotEmpty) {
        _terminalFontId = savedTerminalFont;
      }

      //设置语言
      final savedLocale = prefs.getString(_keyAppLocale);
      if(savedLocale != null && savedLocale.isNotEmpty) {
        _locale = Locale(savedLocale);
      } else {
        _locale = null;
      }

      notifyListeners();
    }catch (_) {}
  }

  Future<void> setAppThemeMode(ThemeMode mode) async {
    if(_appThemeMode == mode) return;
    _appThemeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAppThemeMode, mode.name);
    }catch (_) {}
  }

  Future<void> setEditorTheme(EditorTheme theme) async {
    if(_editorTheme.id == theme.id) return;
    _editorTheme = theme;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEditorTheme, theme.id);
    }catch(_) {}
  }
  
  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(10.0, 30.0);
    if(_fontSize == clamped) return;
    _fontSize = clamped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyEditorFontSize, clamped);
    }catch (_) {}
  }

  Future<void> setIndentSize(int size) async {
    if (size != 2 && size != 4 && size != 8) return;
    if (_indentSize == size) return;
    _indentSize = size;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyEditorIndentSize, size);
    } catch (_) {}
  }

  Future<void> setWordWrap(bool wrap) async {
    if(_wordWrap == wrap) return;
    _wordWrap = wrap;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyWordWrap, wrap);
    }catch (_) {}
  }

  Future<void> setEnableVirtualKeyboard(bool enable) async {
    if (_enableVirtualKeyboard == enable) return;
    _enableVirtualKeyboard = enable;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnableVirtualKeyboard, enable);
    } catch (_) {}
  }

  Future<bool> setVirtualKeyboardConfig(String jsonStr) async {
    final err = VirtualKeyboardConfig.validateJson(jsonStr);
    if (err != null) {
      return false;
    }
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      _virtualKeyboardConfig = VirtualKeyboardConfig.fromJson(decoded);
      _virtualKeyboardConfigJson = jsonStr;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyVirtualKeyboardConfig, jsonStr);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetVirtualKeyboardConfig() async {
    _virtualKeyboardConfig = VirtualKeyboardConfig.defaultConfiguration();
    _virtualKeyboardConfigJson = VirtualKeyboardConfig.defaultJsonPretty();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyVirtualKeyboardConfig);
    } catch (_) {}
  }

  Future<void> setLocale(Locale? newLocale) async {
    if(_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if(newLocale == null) {
        await prefs.remove(_keyAppLocale);
      } else {
        await prefs.setString(_keyAppLocale, newLocale.languageCode);
      }
    }catch (_) {}
  }

  Future<void> setUiFontId(String fontId) async {
    if (_uiFontId == fontId) return;
    _uiFontId = fontId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUiFont, fontId);
    } catch (_) {}
  }

  Future<void> setEditorFontId(String fontId) async {
    if (_editorFontId == fontId) return;
    _editorFontId = fontId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEditorFont, fontId);
    } catch (_) {}
  }

  Future<void> setTerminalFontId(String fontId) async {
    if (_terminalFontId == fontId) return;
    _terminalFontId = fontId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTerminalFont, fontId);
    } catch (_) {}
  }
}
