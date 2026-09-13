import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/app_font.dart';
import 'package:code_editor/models/editor_theme.dart';
import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'virtual_keyboard_config_view.dart';

/// 设置页面
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  static SettingsProvider _getProvider(BuildContext context) {
    return context.watch<SettingsProvider>();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = _getProvider(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.settings),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // ==============================
          // 1. 外观分组 (Appearance)
          // ==============================
          _buildSectionHeader(context, l10n.appearanceSection),
          _buildThemeModeTile(context, provider, l10n),
          _buildUiFontTile(context, provider),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ==============================
          // 2. 编辑区分组 (Editor)
          // ==============================
          _buildSectionHeader(context, l10n.editorSection),
          _buildEditorThemeTile(context, provider, l10n),
          _buildFontSizeTile(context, provider, l10n),
          _buildEditorFontTile(context, provider),
          _buildIndentSizeTile(context, provider, l10n),
          _buildWordWrapTile(context, provider, l10n),
          _buildVirtualKeyboardTile(context, provider, l10n),
          _buildVirtualKeyboardConfigTile(context, provider, l10n),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ==============================
          // 3. 终端分组 (Terminal)
          // ==============================
          _buildSectionHeader(context, '终端'),
          _buildTerminalFontTile(context, provider),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ==============================
          // 4. 语言分组 (Language)
          // ==============================
          _buildSectionHeader(context, l10n.languageSection),
          _buildLanguageTile(context, provider, l10n),
        ],
      ),
    );
  }

  /// 一行设置区介绍标题
  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// 外观：系统/明亮/暗黑主题切换条目
  Widget _buildThemeModeTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final currentMode = provider.appThemeMode;

    final (icon, modeTitle) = switch (currentMode) {
      ThemeMode.system => (Icons.brightness_auto, l10n.followSystem),
      ThemeMode.light => (Icons.light_mode, l10n.lightMode),
      ThemeMode.dark => (Icons.dark_mode, l10n.darkMode),
    };

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(l10n.appThemeMode),
      subtitle: Text(modeTitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showThemeModeSelector(context, provider, l10n);
      },
    );
  }

  void _showThemeModeSelector(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.selectAppTheme,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              RadioGroup<ThemeMode>(
                groupValue: provider.appThemeMode,
                onChanged: (mode) {
                  if (mode != null) {
                    provider.setAppThemeMode(mode);
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text(l10n.followSystem),
                      subtitle: Text(l10n.followSystemSubtitle),
                      value: ThemeMode.system,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text(l10n.lightMode),
                      subtitle: Text(l10n.lightModeSubtitle),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text(l10n.darkMode),
                      subtitle: Text(l10n.darkModeSubtitle),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// 外观：UI 界面字体条目
  Widget _buildUiFontTile(BuildContext context, SettingsProvider provider) {
    final theme = Theme.of(context);
    final currentFont = provider.uiFont;
    return ListTile(
      leading: Icon(Icons.font_download_outlined, color: theme.colorScheme.primary),
      title: const Text('界面字体'),
      subtitle: Text(currentFont.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showFontSelector(
          context,
          title: '选择界面字体',
          fonts: AppFonts.uiFonts,
          currentId: provider.uiFontId,
          previewSample: '代码编辑器界面字体预览 Code Editor 123',
          onSelected: (id) => provider.setUiFontId(id),
        );
      },
    );
  }

  /// 编辑区：代码字体条目
  Widget _buildEditorFontTile(BuildContext context, SettingsProvider provider) {
    final theme = Theme.of(context);
    final currentFont = provider.editorFont;
    return ListTile(
      leading: Icon(Icons.text_fields, color: theme.colorScheme.primary),
      title: const Text('代码字体'),
      subtitle: Text(currentFont.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showFontSelector(
          context,
          title: '选择代码字体',
          fonts: AppFonts.editorFonts,
          currentId: provider.editorFontId,
          previewSample: 'void main() { int a = 123; } // 代码预览',
          onSelected: (id) => provider.setEditorFontId(id),
        );
      },
    );
  }

  /// 终端：终端字体条目
  Widget _buildTerminalFontTile(BuildContext context, SettingsProvider provider) {
    final theme = Theme.of(context);
    final currentFont = provider.terminalFont;
    return ListTile(
      leading: Icon(Icons.terminal, color: theme.colorScheme.primary),
      title: const Text('终端字体'),
      subtitle: Text(currentFont.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showFontSelector(
          context,
          title: '选择终端字体',
          fonts: AppFonts.terminalFonts,
          currentId: provider.terminalFontId,
          previewSample: '\$ git status -s # 终端字体预览',
          onSelected: (id) => provider.setTerminalFontId(id),
        );
      },
    );
  }

  /// 字体选择底部弹窗
  void _showFontSelector(
    BuildContext context, {
    required String title,
    required List<AppFontItem> fonts,
    required String currentId,
    required ValueChanged<String> onSelected,
    required String previewSample,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: fonts.length,
                    itemBuilder: (context, index) {
                      final item = fonts[index];
                      final isSelected = item.id == currentId;
                      return ListTile(
                        leading: Icon(
                          item.isMonospace ? Icons.code : Icons.font_download_outlined,
                          color: isSelected ? theme.colorScheme.primary : null,
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? theme.colorScheme.primary : null,
                          ),
                        ),
                        subtitle: Text(
                          previewSample,
                          style: TextStyle(
                            fontFamily: item.fontFamily,
                            fontFamilyFallback: item.fallback,
                            fontSize: 12.0,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check, color: theme.colorScheme.primary)
                            : null,
                        onTap: () {
                          onSelected(item.id);
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 编辑区：代码主题切换条目
  Widget _buildEditorThemeTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final currentTheme = provider.editorTheme;
    final themeCategory = currentTheme.isDark ? l10n.darkLabel : l10n.lightLabel;

    return ListTile(
      leading: Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
      title: Text(l10n.codeHighlightTheme),
      subtitle: Text(
        '${currentTheme.name} ($themeCategory)',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: currentTheme.backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        _showEditorThemeSelector(context, provider, l10n);
      },
    );
  }

  void _showEditorThemeSelector(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    l10n.selectCodeHighlightTheme,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: EditorTheme.presets.length,
                    itemBuilder: (context, index) {
                      final item = EditorTheme.presets[index];
                      final isSelected = item.id == provider.editorTheme.id;

                      return ListTile(
                        leading: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: item.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Aa',
                            style: TextStyle(
                              color: item.textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          item.isDark ? l10n.darkThemeCategory : l10n.lightThemeCategory,
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check, color: theme.colorScheme.primary)
                            : null,
                        selected: isSelected,
                        onTap: () {
                          provider.setEditorTheme(item);
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 编辑区：字号与缩放调节条目
  Widget _buildFontSizeTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(Icons.format_size, color: theme.colorScheme.primary),
      title: Text(l10n.codeFontSize),
      subtitle: Text('${provider.fontSize.toInt()} pt'),
      trailing: SizedBox(
        width: 150,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: l10n.decreaseFontSize,
              onPressed: provider.fontSize > 10.0
                  ? () => provider.setFontSize(provider.fontSize - 1)
                  : null,
            ),
            Text(
              '${provider.fontSize.toInt()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: l10n.increaseFontSize,
              onPressed: provider.fontSize < 30.0
                  ? () => provider.setFontSize(provider.fontSize + 1)
                  : null,
            ),
          ],
        ),
      ),
      onTap: () {
        _showFontSizeDialog(context, provider, l10n);
      },
    );
  }

  /// 编辑区：缩进大小配置条目
  Widget _buildIndentSizeTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(Icons.format_indent_increase, color: theme.colorScheme.primary),
      title: Text(l10n.indentSize),
      subtitle: Text(l10n.spacesCount(provider.indentSize)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showIndentSizeSelector(context, provider, l10n);
      },
    );
  }

  void _showIndentSizeSelector(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        const options = [2, 4, 8];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.selectIndentSize,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ...options.map((count) {
                final isSelected = provider.indentSize == count;
                return ListTile(
                  title: Text(l10n.spacesCount(count)),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  selected: isSelected,
                  onTap: () {
                    provider.setIndentSize(count);
                    Navigator.of(sheetContext).pop();
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showFontSizeDialog(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    double tempSize = provider.fontSize;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.fontSizeDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tempSize.toInt()} pt',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempSize.clamp(10.0, 30.0),
                    min: 10.0,
                    max: 30.0,
                    divisions: 20,
                    label: '${tempSize.toInt()}',
                    onChanged: (val) {
                      setDialogState(() {
                        tempSize = val;
                      });
                      provider.setFontSize(val);
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: provider.editorTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'const hello = "World";',
                      style: TextStyle(
                        color: provider.editorTheme.textColor,
                        fontSize: tempSize,
                        fontFamily: 'Consolas, Monaco, monospace',
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.done),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 编辑区：自动换行切换条目
  Widget _buildWordWrapTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return SwitchListTile(
      secondary: Icon(Icons.wrap_text, color: theme.colorScheme.primary),
      title: Text(l10n.wordWrap),
      subtitle: Text(l10n.wordWrapSubtitle),
      value: provider.wordWrap,
      onChanged: (val) => provider.setWordWrap(val),
    );
  }

  /// 编辑区：虚拟小键盘开关条目
  Widget _buildVirtualKeyboardTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return SwitchListTile(
      secondary: Icon(Icons.keyboard_outlined, color: theme.colorScheme.primary),
      title: Text(l10n.virtualKeyboard),
      subtitle: Text(l10n.virtualKeyboardSubtitle),
      value: provider.enableVirtualKeyboard,
      onChanged: (val) => provider.setEnableVirtualKeyboard(val),
    );
  }

  /// 编辑区：小键盘配置编辑条目
  Widget _buildVirtualKeyboardConfigTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      enabled: provider.enableVirtualKeyboard,
      leading: Icon(Icons.tune, color: provider.enableVirtualKeyboard ? theme.colorScheme.primary : theme.disabledColor),
      title: Text(l10n.editVirtualKeyboardConfig),
      subtitle: Text(l10n.editVirtualKeyboardConfigSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const VirtualKeyboardConfigView(
              scope: KeyboardScope.editor,
            ),
          ),
        );
      },
    );
  }



  /// 语言：应用语言选择条目
  Widget _buildLanguageTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final currentLocale = provider.locale;

    final langTitle = switch (currentLocale?.languageCode) {
      'zh' => l10n.languageChinese,
      'en' => l10n.languageEnglish,
      _ => l10n.languageFollowSystem,
    };

    return ListTile(
      leading: Icon(Icons.language, color: theme.colorScheme.primary),
      title: Text(l10n.appLanguage),
      subtitle: Text(langTitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showLanguageSelector(context, provider, l10n);
      },
    );
  }

  void _showLanguageSelector(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final currentValue = provider.locale?.languageCode ?? 'system';

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.selectLanguage,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              RadioGroup<String>(
                groupValue: currentValue,
                onChanged: (val) {
                  if (val != null) {
                    if (val == 'system') {
                      provider.setLocale(null);
                    } else {
                      provider.setLocale(Locale(val));
                    }
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      title: Text(l10n.languageFollowSystem),
                      subtitle: Text(l10n.followSystemSubtitle),
                      value: 'system',
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.languageChinese),
                      value: 'zh',
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.languageEnglish),
                      value: 'en',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
