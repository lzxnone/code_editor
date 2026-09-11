import 'dart:convert';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/editor_theme.dart';
import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/utils/syntax_highlight_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

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

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ==============================
          // 2. 编辑区分组 (Editor)
          // ==============================
          _buildSectionHeader(context, l10n.editorSection),
          _buildEditorThemeTile(context, provider, l10n),
          _buildFontSizeTile(context, provider, l10n),
          _buildWordWrapTile(context, provider, l10n),
          _buildVirtualKeyboardTile(context, provider, l10n),
          _buildVirtualKeyboardConfigTile(context, provider, l10n),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ==============================
          // 3. 语言分组 (Language)
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
        _showKeyboardConfigDialog(context, provider, l10n);
      },
    );
  }

  void _showKeyboardConfigDialog(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final codeController = CodeLineEditingController.fromText(provider.virtualKeyboardConfigJson);
    String? validationError;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final activeTheme = provider.editorTheme;

            return AlertDialog(
              title: Text(l10n.virtualKeyboardDialogTitle),
              content: SizedBox(
                width: 680,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (validationError != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.error, width: 0.8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                validationError!,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Flexible(
                      child: Container(
                        height: 360,
                        decoration: BoxDecoration(
                          color: activeTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: validationError != null
                                ? theme.colorScheme.error
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CodeEditor(
                          controller: codeController,
                          wordWrap: false,
                          style: CodeEditorStyle(
                            fontSize: 13,
                            textColor: activeTheme.textColor,
                            backgroundColor: activeTheme.backgroundColor,
                            cursorColor: activeTheme.cursorColor,
                            cursorLineColor: activeTheme.cursorLineColor,
                            selectionColor: activeTheme.selectionColor,
                            fontFamily: 'Consolas, Monaco, "Courier New", monospace',
                            codeTheme: CodeHighlightTheme(
                              languages: SyntaxHighlightHelper.getLanguagesForFile('config.json'),
                              theme: activeTheme.highlightTheme,
                            ),
                          ),
                          indicatorBuilder: (context, editingController, chunkController, notifier) {
                            return Row(
                              children: [
                                DefaultCodeLineNumber(
                                  controller: editingController,
                                  notifier: notifier,
                                  textStyle: TextStyle(
                                    color: activeTheme.gutterTextColor,
                                    fontSize: 12,
                                    fontFamily: 'Consolas, Monaco, "Courier New", monospace',
                                  ),
                                  focusedTextStyle: TextStyle(
                                    color: activeTheme.focusedGutterTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Consolas, Monaco, "Courier New", monospace',
                                  ),
                                ),
                                DefaultCodeChunkIndicator(
                                  width: 16,
                                  controller: chunkController,
                                  notifier: notifier,
                                  painter: DefaultCodeChunkIndicatorPainter(
                                    color: activeTheme.gutterTextColor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.restore, size: 16),
                          label: Text(l10n.resetDefault),
                          onPressed: () {
                            setDialogState(() {
                              codeController.text = VirtualKeyboardConfig.defaultJsonPretty();
                              validationError = null;
                            });
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.format_align_left, size: 16),
                          label: Text(l10n.formatJson),
                          onPressed: () {
                            final err = VirtualKeyboardConfig.validateJson(codeController.text);
                            if (err != null) {
                              setDialogState(() {
                                validationError = err;
                              });
                            } else {
                              try {
                                final decoded = jsonDecode(codeController.text);
                                const encoder = JsonEncoder.withIndent('  ');
                                setDialogState(() {
                                  codeController.text = encoder.convert(decoded);
                                  validationError = null;
                                });
                              } catch (_) {}
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final jsonText = codeController.text;
                    final err = VirtualKeyboardConfig.validateJson(jsonText);
                    if (err != null) {
                      setDialogState(() {
                        validationError = err;
                      });
                      return;
                    }

                    final success = await provider.setVirtualKeyboardConfig(jsonText);
                    if (success && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      DialogUtils.showSuccessToast(context, l10n.configSavedSuccess);
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
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
