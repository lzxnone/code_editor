import 'dart:convert';
import 'package:code_editor/models/app_font.dart';
import 'package:code_editor/models/distro_manifest.dart';
import 'package:code_editor/models/editor_theme.dart';
import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  //外观
  static const String _keyAppThemeMode = 'app_theme_mode'; //应用主题
  static const String _keyAppThemeColor = 'app_theme_color'; //主题颜色
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
  static const String _keyTerminalBackgroundColor = 'terminal_background_color'; //终端背景颜色
  static const String _keyEnableTerminalVirtualKeyboard = 'enable_terminal_virtual_keyboard'; //终端小键盘启用
  static const String _keyTerminalKeyboardConfig = 'terminal_virtual_keyboard_config'; //终端小键盘配置JSON

  //项目配置
  static const String _keyShowHiddenFiles = 'show_hidden_files'; //显示隐藏文件

  //下载配置
  static const String _keyDownloadMirrorId = 'download_mirror_id'; //下载源镜像ID

  //语言
  static const String _keyAppLocale = 'app_locale';

  ThemeMode _appThemeMode = ThemeMode.system;
  Color _appThemeColor = Colors.blue;
  String _uiFontId = 'system_default';
  EditorTheme _editorTheme = EditorTheme.atomOneDark;
  String _editorFontId = 'jetbrains_mono';
  String _terminalFontId = 'jetbrains_mono';
  Color _terminalBackgroundColor = const Color(0xFF1E1E1E);
  double _fontSize = 14.0;
  int _indentSize = 4;
  bool _wordWrap = false;
  bool _enableVirtualKeyboard = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  String _virtualKeyboardConfigJson = VirtualKeyboardConfig.defaultJsonPretty();
  VirtualKeyboardConfig _virtualKeyboardConfig = VirtualKeyboardConfig.defaultConfiguration();
  bool _enableTerminalVirtualKeyboard = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  String _terminalKeyboardConfigJson = VirtualKeyboardConfig.defaultTerminalJsonPretty();
  VirtualKeyboardConfig _terminalKeyboardConfig = VirtualKeyboardConfig.defaultTerminalConfiguration();
  bool _showHiddenFiles = true;
  String _downloadMirrorId = 'tsinghua'; // 默认清华源
  Locale? _locale;

  bool get showHiddenFiles => _showHiddenFiles;
  String get downloadMirrorId => _downloadMirrorId;
  DistroMirror get downloadMirror => DistroRepository.getMirrorById(_downloadMirrorId);

  ThemeMode get appThemeMode => _appThemeMode;
  Color get appThemeColor => _appThemeColor;
  String get uiFontId => _uiFontId;
  AppFontItem get uiFont => AppFonts.getUiFont(_uiFontId);

  EditorTheme get editorTheme => _editorTheme;
  String get editorFontId => _editorFontId;
  AppFontItem get editorFont => AppFonts.getEditorFont(_editorFontId);

  String get terminalFontId => _terminalFontId;
  AppFontItem get terminalFont => AppFonts.getTerminalFont(_terminalFontId);
  Color get terminalBackgroundColor => _terminalBackgroundColor;

  double get fontSize => _fontSize;
  int get indentSize => _indentSize;
  bool get wordWrap => _wordWrap;
  bool get enableVirtualKeyboard => _enableVirtualKeyboard;
  String get virtualKeyboardConfigJson => _virtualKeyboardConfigJson;
  VirtualKeyboardConfig get virtualKeyboardConfig => _virtualKeyboardConfig;
  bool get enableTerminalVirtualKeyboard => _enableTerminalVirtualKeyboard;
  String get terminalKeyboardConfigJson => _terminalKeyboardConfigJson;
  VirtualKeyboardConfig get terminalKeyboardConfig => _terminalKeyboardConfig;
  Locale? get locale => _locale;

  // ==========================================
  // 小键盘配置：按作用域（编辑区 / 终端）读写两份互不干扰的配置
  // ==========================================

  /// 读取指定作用域的键盘配置
  VirtualKeyboardConfig keyboardConfigFor(KeyboardScope scope) =>
      scope == KeyboardScope.terminal ? _terminalKeyboardConfig : _virtualKeyboardConfig;

  /// 读取指定作用域的键盘配置 JSON
  String keyboardConfigJsonFor(KeyboardScope scope) =>
      scope == KeyboardScope.terminal ? _terminalKeyboardConfigJson : _virtualKeyboardConfigJson;

  /// 指定作用域的小键盘是否启用（两个开关相互独立）
  bool keyboardEnabledFor(KeyboardScope scope) =>
      scope == KeyboardScope.terminal ? _enableTerminalVirtualKeyboard : _enableVirtualKeyboard;

  static String _enablePrefKey(KeyboardScope scope) =>
      scope == KeyboardScope.terminal ? _keyEnableTerminalVirtualKeyboard : _keyEnableVirtualKeyboard;

  static String _configPrefKey(KeyboardScope scope) =>
      scope == KeyboardScope.terminal ? _keyTerminalKeyboardConfig : _keyVirtualKeyboardConfig;

  /// 设置指定作用域小键盘的启用状态
  Future<void> setKeyboardEnabled(KeyboardScope scope, bool enable) async {
    if (keyboardEnabledFor(scope) == enable) return;
    if (scope == KeyboardScope.terminal) {
      _enableTerminalVirtualKeyboard = enable;
    } else {
      _enableVirtualKeyboard = enable;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enablePrefKey(scope), enable);
    } catch (_) {}
  }

  /// 保存指定作用域的键盘配置 JSON，校验失败返回 false
  Future<bool> setKeyboardConfig(KeyboardScope scope, String jsonStr) async {
    final err = VirtualKeyboardConfig.validateJson(jsonStr, scope);
    if (err != null) {
      return false;
    }
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final config = VirtualKeyboardConfig.fromJson(decoded);
      if (scope == KeyboardScope.terminal) {
        _terminalKeyboardConfig = config;
        _terminalKeyboardConfigJson = jsonStr;
      } else {
        _virtualKeyboardConfig = config;
        _virtualKeyboardConfigJson = jsonStr;
      }
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configPrefKey(scope), jsonStr);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 将指定作用域的键盘配置恢复为该作用域的默认预设
  Future<void> resetKeyboardConfig(KeyboardScope scope) async {
    if (scope == KeyboardScope.terminal) {
      _terminalKeyboardConfig = VirtualKeyboardConfig.defaultTerminalConfiguration();
      _terminalKeyboardConfigJson = VirtualKeyboardConfig.defaultTerminalJsonPretty();
    } else {
      _virtualKeyboardConfig = VirtualKeyboardConfig.defaultConfiguration();
      _virtualKeyboardConfigJson = VirtualKeyboardConfig.defaultJsonPretty();
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_configPrefKey(scope));
    } catch (_) {}
  }

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

      final savedThemeColor = prefs.getInt(_keyAppThemeColor);
      if (savedThemeColor != null) {
        _appThemeColor = Color(savedThemeColor);
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
        final err = VirtualKeyboardConfig.validateJson(savedKeyboardConfig, KeyboardScope.editor);
        if (err == null) {
          try {
            final decoded = jsonDecode(savedKeyboardConfig) as Map<String, dynamic>;
            _virtualKeyboardConfig = VirtualKeyboardConfig.fromJson(decoded);
            _virtualKeyboardConfigJson = savedKeyboardConfig;
          } catch (_) {}
        }
      }

      //终端小键盘（独立开关 + 独立配置）
      final savedEnableTerminalKeyboard = prefs.getBool(_keyEnableTerminalVirtualKeyboard);
      if (savedEnableTerminalKeyboard != null) {
        _enableTerminalVirtualKeyboard = savedEnableTerminalKeyboard;
      }

      final savedTerminalKeyboardConfig = prefs.getString(_keyTerminalKeyboardConfig);
      if (savedTerminalKeyboardConfig != null && savedTerminalKeyboardConfig.trim().isNotEmpty) {
        final err = VirtualKeyboardConfig.validateJson(savedTerminalKeyboardConfig, KeyboardScope.terminal);
        if (err == null) {
          try {
            final decoded = jsonDecode(savedTerminalKeyboardConfig) as Map<String, dynamic>;
            _terminalKeyboardConfig = VirtualKeyboardConfig.fromJson(decoded);
            _terminalKeyboardConfigJson = savedTerminalKeyboardConfig;
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

      final savedTerminalBackground = prefs.getInt(_keyTerminalBackgroundColor);
      if (savedTerminalBackground != null) {
        _terminalBackgroundColor = Color(savedTerminalBackground);
      }

      //设置项目配置
      final savedShowHiddenFiles = prefs.getBool(_keyShowHiddenFiles);
      if (savedShowHiddenFiles != null) {
        _showHiddenFiles = savedShowHiddenFiles;
      }

      //设置下载源镜像配置
      final savedMirrorId = prefs.getString(_keyDownloadMirrorId);
      if (savedMirrorId != null && savedMirrorId.isNotEmpty) {
        _downloadMirrorId = savedMirrorId;
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

  /// 设置主题颜色（Material 3 的 seed color）
  Future<void> setAppThemeColor(Color color) async {
    if (_appThemeColor.toARGB32() == color.toARGB32()) return;
    _appThemeColor = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyAppThemeColor, color.toARGB32());
    } catch (_) {}
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

  /// 编辑区小键盘开关（等价于 `setKeyboardEnabled(KeyboardScope.editor, ...)`）
  Future<void> setEnableVirtualKeyboard(bool enable) =>
      setKeyboardEnabled(KeyboardScope.editor, enable);

  /// 编辑区小键盘配置（等价于 `setKeyboardConfig(KeyboardScope.editor, ...)`）
  Future<bool> setVirtualKeyboardConfig(String jsonStr) =>
      setKeyboardConfig(KeyboardScope.editor, jsonStr);

  /// 编辑区小键盘恢复默认
  Future<void> resetVirtualKeyboardConfig() =>
      resetKeyboardConfig(KeyboardScope.editor);

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

  /// 设置终端背景颜色
  Future<void> setTerminalBackgroundColor(Color color) async {
    if (_terminalBackgroundColor.toARGB32() == color.toARGB32()) return;
    _terminalBackgroundColor = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyTerminalBackgroundColor, color.toARGB32());
    } catch (_) {}
  }

  /// 设置是否显示隐藏文件
  Future<void> setShowHiddenFiles(bool show) async {
    if (_showHiddenFiles == show) return;
    _showHiddenFiles = show;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowHiddenFiles, show);
    } catch (_) {}
  }

  /// 设置系统安装包下载镜像源
  Future<void> setDownloadMirrorId(String mirrorId) async {
    if (_downloadMirrorId == mirrorId) return;
    _downloadMirrorId = mirrorId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDownloadMirrorId, mirrorId);
    } catch (_) {}
  }
}
