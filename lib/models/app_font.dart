/// 字体定义与预设常量
class AppFontItem {
  final String id;
  final String name;
  final String? fontFamily;
  final List<String> fallback;
  final bool isMonospace;

  const AppFontItem({
    required this.id,
    required this.name,
    this.fontFamily,
    this.fallback = const [],
    this.isMonospace = false,
  });
}

/// 集中管理的字体常量表（方便随时追加网络/本地下载的字体）
class AppFonts {
  // ==========================================
  // 1. 外观 UI 字体选项
  // ==========================================
  static const AppFontItem uiDefault = AppFontItem(
    id: 'system_default',
    name: '系统默认 (System Default)',
    fontFamily: null,
    fallback: [
      'PingFang SC',
      'Noto Sans SC',
      'Microsoft YaHei',
      'WenQuanYi Micro Hei',
      'sans-serif',
    ],
  );

  static const AppFontItem uiSansSerif = AppFontItem(
    id: 'sans_serif',
    name: '无衬线体 (Sans-Serif)',
    fontFamily: 'sans-serif',
    fallback: [
      'PingFang SC',
      'Noto Sans SC',
      'Microsoft YaHei',
      'sans-serif',
    ],
  );

  static const AppFontItem uiSerif = AppFontItem(
    id: 'serif',
    name: '衬线体 (Serif / 宋体)',
    fontFamily: 'serif',
    fallback: [
      'Songti SC',
      'SimSun',
      'serif',
    ],
  );

  static const AppFontItem uiJetBrainsMono = AppFontItem(
    id: 'jetbrains_mono',
    name: 'JetBrains Mono',
    fontFamily: 'JetBrains Mono',
    fallback: [
      'PingFang SC',
      'Noto Sans SC',
      'Microsoft YaHei',
      'sans-serif',
    ],
  );

  static const AppFontItem uiFiraCode = AppFontItem(
    id: 'fira_code',
    name: 'Fira Code',
    fontFamily: 'Fira Code',
    fallback: [
      'PingFang SC',
      'Noto Sans SC',
      'Microsoft YaHei',
      'sans-serif',
    ],
  );

  /// 外观 UI 可选字体列表
  static const List<AppFontItem> uiFonts = [
    uiDefault,
    uiSansSerif,
    uiSerif,
    uiJetBrainsMono,
    uiFiraCode,
  ];

  // ==========================================
  // 2. 代码编辑区字体选项
  // ==========================================
  static const AppFontItem editorMonospace = AppFontItem(
    id: 'monospace',
    name: '系统等宽 (System Monospace)',
    fontFamily: 'monospace',
    fallback: [
      'Consolas',
      'Menlo',
      'Monaco',
      'Courier New',
      'monospace',
    ],
    isMonospace: true,
  );

  static const AppFontItem editorConsolas = AppFontItem(
    id: 'consolas',
    name: 'Consolas',
    fontFamily: 'Consolas',
    fallback: ['monospace'],
    isMonospace: true,
  );

  static const AppFontItem editorCourierNew = AppFontItem(
    id: 'courier_new',
    name: 'Courier New',
    fontFamily: 'Courier New',
    fallback: ['Courier', 'monospace'],
    isMonospace: true,
  );

  static const AppFontItem editorMenlo = AppFontItem(
    id: 'menlo',
    name: 'Menlo / Monaco',
    fontFamily: 'Menlo',
    fallback: ['Monaco', 'monospace'],
    isMonospace: true,
  );

  /// 预设的开源编程字体配置（用户后续下载字体包放入 assets/fonts/ 并配置 pubspec 后即可即开即用）
  static const AppFontItem editorJetBrainsMono = AppFontItem(
    id: 'jetbrains_mono',
    name: 'JetBrains Mono (推荐)',
    fontFamily: 'JetBrains Mono',
    fallback: ['monospace'],
    isMonospace: true,
  );

  static const AppFontItem editorFiraCode = AppFontItem(
    id: 'fira_code',
    name: 'Fira Code',
    fontFamily: 'Fira Code',
    fallback: ['monospace'],
    isMonospace: true,
  );

  /// 代码编辑区可选字体列表
  static const List<AppFontItem> editorFonts = [
    editorMonospace,
    editorConsolas,
    editorCourierNew,
    editorMenlo,
    editorJetBrainsMono,
    editorFiraCode,
  ];

  // ==========================================
  // 3. 终端字体选项
  // ==========================================
  static const AppFontItem terminalMonospace = AppFontItem(
    id: 'monospace',
    name: '系统等宽 (System Monospace)',
    fontFamily: 'monospace',
    fallback: [
      'Consolas',
      'Menlo',
      'Monaco',
      'Courier New',
      'monospace',
    ],
    isMonospace: true,
  );

  static const AppFontItem terminalConsolas = AppFontItem(
    id: 'consolas',
    name: 'Consolas',
    fontFamily: 'Consolas',
    fallback: ['monospace'],
    isMonospace: true,
  );

  static const AppFontItem terminalCourierNew = AppFontItem(
    id: 'courier_new',
    name: 'Courier New',
    fontFamily: 'Courier New',
    fallback: ['Courier', 'monospace'],
    isMonospace: true,
  );

  static const AppFontItem terminalMenlo = AppFontItem(
    id: 'menlo',
    name: 'Menlo / Monaco',
    fontFamily: 'Menlo',
    fallback: ['Monaco', 'monospace'],
    isMonospace: true,
  );

  static const AppFontItem terminalJetBrainsMono = AppFontItem(
    id: 'jetbrains_mono',
    name: 'JetBrains Mono (推荐)',
    fontFamily: 'JetBrains Mono',
    fallback: ['monospace'],
    isMonospace: true,
  );

  static const AppFontItem terminalFiraCode = AppFontItem(
    id: 'fira_code',
    name: 'Fira Code',
    fontFamily: 'Fira Code',
    fallback: ['monospace'],
    isMonospace: true,
  );

  /// 终端可选字体列表
  static const List<AppFontItem> terminalFonts = [
    terminalMonospace,
    terminalConsolas,
    terminalCourierNew,
    terminalMenlo,
    terminalJetBrainsMono,
    terminalFiraCode,
  ];

  // ==========================================
  // 4. 查询辅助方法
  // ==========================================
  static AppFontItem getUiFont(String? id) {
    return uiFonts.firstWhere(
      (f) => f.id == id,
      orElse: () => uiDefault,
    );
  }

  static AppFontItem getEditorFont(String? id) {
    return editorFonts.firstWhere(
      (f) => f.id == id,
      orElse: () => editorJetBrainsMono,
    );
  }

  static AppFontItem getTerminalFont(String? id) {
    return terminalFonts.firstWhere(
      (f) => f.id == id,
      orElse: () => terminalJetBrainsMono,
    );
  }
}
