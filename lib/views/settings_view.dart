import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/app_font.dart';
import 'package:code_editor/models/editor_theme.dart';
import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/internal_engine_service.dart';
import '../widgets/color_palette_dialog.dart';
import 'code_completion_management_view.dart';
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
          _buildThemeColorTile(context, provider, l10n),
          _buildUiFontTile(context, provider),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ==============================
          // 2. 编辑区分组 (Editor)
          // ==============================
          _buildSectionHeader(context, l10n.editorSection),
          _buildEditorThemeTile(context, provider, l10n),
          _buildEditorFontTile(context, provider),
          _buildFontSizeTile(context, provider, l10n),
          _buildIndentSizeTile(context, provider, l10n),
          _buildWordWrapTile(context, provider, l10n),
          _buildShowLineNumbersTile(context, provider, l10n),
          _buildPinLineNumbersTile(context, provider, l10n),
          _buildVirtualKeyboardTile(context, provider, l10n),
          _buildVirtualKeyboardConfigTile(context, provider, l10n),
          _buildCodeCompletionManagementTile(context, l10n),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ==============================
          // 3. 终端分组 (Terminal)
          // ==============================
          _buildSectionHeader(context, l10n.terminal),
          _buildTerminalBackgroundTile(context, provider, l10n),
          _buildTerminalFontTile(context, provider),
          _buildTerminalFontSizeTile(context, provider, l10n),
          _buildTerminalVirtualKeyboardTile(context, provider, l10n),
          _buildTerminalVirtualKeyboardConfigTile(context, provider, l10n),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ==============================
          // 4. 项目分组 (Project)
          // ==============================
          _buildSectionHeader(context, l10n.projectSection),
          _buildShowHiddenFilesTile(context, provider, l10n),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ==============================
          // 5. 容器分组 (Container)
          // ==============================
          _buildSectionHeader(context, l10n.containerSection),
          _buildRebuildContainerTile(context, l10n),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ==============================
          // 6. 语言分组 (Language)
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
    final l10n = AppLocalizations.of(context)!;
    final currentFont = provider.uiFont;
    return ListTile(
      leading: Icon(Icons.font_download_outlined, color: theme.colorScheme.primary),
      title: Text(l10n.uiFont),
      subtitle: Text(l10n.fontName(currentFont.id)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showFontSelector(
          context,
          title: l10n.selectUiFont,
          fonts: AppFonts.uiFonts,
          currentId: provider.uiFontId,
          previewSample: l10n.uiFontPreview,
          onSelected: (id) => provider.setUiFontId(id),
        );
      },
    );
  }

  /// 编辑区：代码字体条目
  Widget _buildEditorFontTile(BuildContext context, SettingsProvider provider) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currentFont = provider.editorFont;
    final fontName = l10n.fontName(currentFont.id);
    final subtitle = currentFont.id == 'jetbrains_mono'
        ? '$fontName (${l10n.recommended})'
        : fontName;
    return ListTile(
      leading: Icon(Icons.text_fields, color: theme.colorScheme.primary),
      title: Text(l10n.codeFont),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showFontSelector(
          context,
          title: l10n.selectCodeFont,
          fonts: AppFonts.editorFonts,
          currentId: provider.editorFontId,
          previewSample: l10n.codeFontPreview,
          showRecommendation: true,
          onSelected: (id) => provider.setEditorFontId(id),
        );
      },
    );
  }

  /// 终端：终端字体条目
  Widget _buildTerminalFontTile(BuildContext context, SettingsProvider provider) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currentFont = provider.terminalFont;
    final fontName = l10n.fontName(currentFont.id);
    final subtitle = currentFont.id == 'jetbrains_mono'
        ? '$fontName (${l10n.recommended})'
        : fontName;
    return ListTile(
      leading: Icon(Icons.font_download_outlined, color: theme.colorScheme.primary),
      title: Text(l10n.terminalFont),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showFontSelector(
          context,
          title: l10n.selectTerminalFont,
          fonts: AppFonts.terminalFonts,
          currentId: provider.terminalFontId,
          previewSample: l10n.terminalFontPreview,
          showRecommendation: true,
          onSelected: (id) => provider.setTerminalFontId(id),
        );
      },
    );
  }

  /// 终端：终端字号条目
  Widget _buildTerminalFontSizeTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(Icons.format_size, color: theme.colorScheme.primary),
      title: Text(l10n.terminalFontSize),
      subtitle: Text('${provider.terminalFontSize.toInt()} pt'),
      trailing: SizedBox(
        width: 150,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: l10n.decreaseFontSize,
              onPressed: provider.terminalFontSize > SettingsProvider.minFontSize
                  ? () => provider.setTerminalFontSize(provider.terminalFontSize - 1)
                  : null,
            ),
            Text(
              '${provider.terminalFontSize.toInt()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: l10n.increaseFontSize,
              onPressed: provider.terminalFontSize < SettingsProvider.maxFontSize
                  ? () => provider.setTerminalFontSize(provider.terminalFontSize + 1)
                  : null,
            ),
          ],
        ),
      ),
      onTap: () {
        _showTerminalFontSizeDialog(context, provider, l10n);
      },
    );
  }

  void _showTerminalFontSizeDialog(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    double tempSize = provider.terminalFontSize;
    final terminalFont = provider.terminalFont;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.terminalFontSizeDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tempSize.toInt()} pt',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempSize.clamp(SettingsProvider.minFontSize, SettingsProvider.maxFontSize),
                    min: SettingsProvider.minFontSize,
                    max: SettingsProvider.maxFontSize,
                    divisions: SettingsProvider.fontSizeDivisions,
                    label: '${tempSize.toInt()}',
                    onChanged: (val) {
                      setDialogState(() {
                        tempSize = val;
                      });
                      provider.setTerminalFontSize(val);
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: provider.terminalBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.terminalFontPreview,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: tempSize,
                        fontFamily: terminalFont.fontFamily ?? 'monospace',
                        fontFamilyFallback: terminalFont.fallback,
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

  /// 外观：主题颜色条目（点击弹出调色板）
  Widget _buildThemeColorTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final current = provider.appThemeColor;

    return ListTile(
      leading: Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
      title: Text(l10n.themeColor),
      subtitle: Text(colorToHex(current)),
      trailing: _buildColorTrailing(context, current),
      onTap: () async {
        final picked = await ColorPaletteDialog.show(
          context,
          title: l10n.selectThemeColor,
          current: current,
          palette: ColorPaletteDialog.uiPalette,
        );
        if (picked != null) {
          await provider.setAppThemeColor(picked);
        }
      },
    );
  }

  /// 终端：终端背景颜色条目（点击弹出调色板）
  Widget _buildTerminalBackgroundTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final current = provider.terminalBackgroundColor;

    return ListTile(
      leading: Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
      title: Text(l10n.terminalBackgroundColor),
      subtitle: Text(colorToHex(current)),
      trailing: _buildColorTrailing(context, current),
      onTap: () async {
        final picked = await ColorPaletteDialog.show(
          context,
          title: l10n.selectTerminalBackgroundColor,
          current: current,
          palette: ColorPaletteDialog.terminalPalette,
        );
        if (picked != null) {
          await provider.setTerminalBackgroundColor(picked);
        }
      },
    );
  }

  /// 颜色预览圆点 + 右箭头（与"代码高亮主题"条目的尾部样式一致）
  Widget _buildColorTrailing(BuildContext context, Color color) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right),
      ],
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
    bool showRecommendation = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
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
                      final isRecommended = showRecommendation && item.id == 'jetbrains_mono';
                      final fontTitle = isRecommended
                          ? '${l10n.fontName(item.id)} (${l10n.recommended})'
                          : l10n.fontName(item.id);
                      return ListTile(
                        leading: Icon(
                          item.isMonospace ? Icons.code : Icons.font_download_outlined,
                          color: isSelected ? theme.colorScheme.primary : null,
                        ),
                        title: Text(
                          fontTitle,
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
              onPressed: provider.fontSize > SettingsProvider.minFontSize
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
              onPressed: provider.fontSize < SettingsProvider.maxFontSize
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
                    value: tempSize.clamp(SettingsProvider.minFontSize, SettingsProvider.maxFontSize),
                    min: SettingsProvider.minFontSize,
                    max: SettingsProvider.maxFontSize,
                    divisions: SettingsProvider.fontSizeDivisions,
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

  /// 编辑区：显示行号条目
  Widget _buildShowLineNumbersTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return SwitchListTile(
      secondary: Icon(Icons.format_list_numbered, color: theme.colorScheme.primary),
      title: Text(l10n.showLineNumbers),
      subtitle: Text(l10n.showLineNumbersSubtitle),
      value: provider.showLineNumbers,
      onChanged: (val) => provider.setShowLineNumbers(val),
    );
  }

  /// 编辑区：固定行号条目（当显示行号开启时才可调整）
  Widget _buildPinLineNumbersTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final isEnabled = provider.showLineNumbers;

    return SwitchListTile(
      secondary: Icon(
        Icons.push_pin_outlined,
        color: isEnabled ? theme.colorScheme.primary : theme.disabledColor,
      ),
      title: Text(
        l10n.pinLineNumbers,
        style: TextStyle(
          color: isEnabled ? null : theme.disabledColor,
        ),
      ),
      subtitle: Text(
        l10n.pinLineNumbersSubtitle,
        style: TextStyle(
          color: isEnabled ? null : theme.disabledColor,
        ),
      ),
      value: provider.pinLineNumbers,
      onChanged: isEnabled ? (val) => provider.setPinLineNumbers(val) : null,
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

  /// 编辑区：代码补全与语言服务管理条目
  Widget _buildCodeCompletionManagementTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(Icons.psychology_outlined, color: theme.colorScheme.primary),
      title: Text(l10n.codeCompletionManagement),
      subtitle: Text(l10n.codeCompletionSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodeCompletionManagementView(),
          ),
        );
      },
    );
  }



  /// 终端：终端小键盘开关条目（与编辑区开关相互独立）
  Widget _buildTerminalVirtualKeyboardTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return SwitchListTile(
      secondary: Icon(Icons.keyboard_command_key, color: theme.colorScheme.primary),
      title: Text(l10n.terminalVirtualKeyboard),
      subtitle: Text(l10n.terminalVirtualKeyboardSubtitle),
      value: provider.enableTerminalVirtualKeyboard,
      onChanged: (val) => provider.setKeyboardEnabled(KeyboardScope.terminal, val),
    );
  }

  /// 终端：终端键盘配置编辑条目
  Widget _buildTerminalVirtualKeyboardConfigTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final enabled = provider.enableTerminalVirtualKeyboard;

    return ListTile(
      enabled: enabled,
      leading: Icon(Icons.tune, color: enabled ? theme.colorScheme.primary : theme.disabledColor),
      title: Text(l10n.editTerminalVirtualKeyboardConfig),
      subtitle: Text(l10n.editTerminalVirtualKeyboardConfigSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const VirtualKeyboardConfigView(
              scope: KeyboardScope.terminal,
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

  /// 项目配置：显示隐藏文件开关
  Widget _buildShowHiddenFilesTile(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    return SwitchListTile(
      secondary: Icon(Icons.visibility_outlined, color: theme.colorScheme.primary),
      title: Text(l10n.showHiddenFiles),
      subtitle: Text(l10n.showHiddenFilesSubtitle),
      value: provider.showHiddenFiles,
      onChanged: (val) {
        provider.setShowHiddenFiles(val);
      },
    );
  }

  /// 容器：销毁并重建容器条目
  Widget _buildRebuildContainerTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final dangerColor = theme.colorScheme.error;

    return ListTile(
      leading: Icon(Icons.delete_forever_outlined, color: dangerColor),
      title: Text(
        l10n.destroyAndRebuildContainer,
        style: TextStyle(
          color: dangerColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        l10n.destroyAndRebuildContainerSubtitle,
        style: TextStyle(
          color: dangerColor.withValues(alpha: 0.8),
          fontSize: 12,
        ),
      ),
      onTap: () {
        _showDestroyContainerDialog(context, l10n);
      },
    );
  }

  void _showDestroyContainerDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogTheme = Theme.of(dialogContext);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: dialogTheme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.destroyContainerConfirmTitle)),
            ],
          ),
          content: Text(l10n.destroyContainerConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialogTheme.colorScheme.error,
                foregroundColor: dialogTheme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.destroyContainerButton),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final success = await InternalEngineService.instance.rebuildEngine(context);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.containerRebuiltSuccess)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.containerRebuildFailed(''))),
          );
        }
      }
    }
  }
}
