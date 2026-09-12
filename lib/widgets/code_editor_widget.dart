import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/app_font.dart';
import 'package:code_editor/models/editor_tab_item.dart';
import 'package:code_editor/models/editor_theme.dart';
import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/file_service.dart';
import 'package:code_editor/services/file_watcher_service.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/utils/syntax_highlight_helper.dart';
import 'package:code_editor/widgets/code_editor_menu.dart';
import 'package:code_editor/widgets/virtual_keyboard_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

class CodeEditorWidget extends StatefulWidget {
  final String? rootPath;
  final String? filePath;

  const CodeEditorWidget({
    super.key,
    required this.rootPath,
    required this.filePath,
  });

  @override
  State<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends State<CodeEditorWidget> {
  static SettingsProvider _getSettingsProvider(BuildContext context, {bool listen = false}) {
    return listen ? context.watch<SettingsProvider>() : context.read<SettingsProvider>();
  }

  static TabProvider _getTabProvider(BuildContext context, {bool listen = false}) {
    return listen ? context.watch<TabProvider>() : context.read<TabProvider>();
  }

  CodeLineEditingController? _controller;
  CodeScrollController? _scrollController;
  final FocusNode _focusNode = FocusNode();
  late final CodeEditorToolbarController _toolbarController;
  bool _isLoading = false;
  int _currentLoadVersion = 0;
  String? _errorMessage;
  String? _currentLoadedPath;
  int? _currentIndentSize;
  bool _isShowingConflictDialog = false;

  EditorTabItem? _getCurrentTab() {
    final filePath = widget.filePath;
    if (filePath == null || filePath.isEmpty) return null;
    try {
      final provider = _getTabProvider(context);
      final rootPath = widget.rootPath;
      final fullFilePath = (rootPath == null || rootPath.isEmpty || p.isAbsolute(filePath))
          ? filePath
          : p.join(rootPath, filePath);
      final cleanPath = p.normalize(fullFilePath);
      return provider.openTabs.where((t) => p.equals(t.path, cleanPath)).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  void _saveCurrentTabScrollState(EditorTabItem? tab) {
    if (tab == null || _scrollController == null) return;
    if (_scrollController!.verticalScroller.hasClients) {
      tab.verticalScrollOffset = _scrollController!.verticalScroller.offset;
    }
    if (_scrollController!.horizontalScroller.hasClients) {
      tab.horizontalScrollOffset = _scrollController!.horizontalScroller.offset;
    }
  }

  void _restoreTabScrollState(EditorTabItem tab) {
    final oldScroll = _scrollController;

    final vScroller = ScrollController(initialScrollOffset: tab.verticalScrollOffset);
    final hScroller = ScrollController(initialScrollOffset: tab.horizontalScrollOffset);

    vScroller.addListener(() {
      if (vScroller.hasClients) {
        tab.verticalScrollOffset = vScroller.offset;
      }
    });
    hScroller.addListener(() {
      if (hScroller.hasClients) {
        tab.horizontalScrollOffset = hScroller.offset;
      }
    });

    _scrollController = CodeScrollController(
      verticalScroller: vScroller,
      horizontalScroller: hScroller,
    );

    oldScroll?.verticalScroller.dispose();
    oldScroll?.horizontalScroller.dispose();
    oldScroll?.dispose();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrollController == null) return;
      if (vScroller.hasClients) {
        final maxV = vScroller.position.maxScrollExtent;
        final targetV = tab.verticalScrollOffset.clamp(0.0, maxV);
        if ((vScroller.offset - targetV).abs() > 0.5) {
          vScroller.jumpTo(targetV);
        }
      }
      if (hScroller.hasClients) {
        final maxH = hScroller.position.maxScrollExtent;
        final targetH = tab.horizontalScrollOffset.clamp(0.0, maxH);
        if ((hScroller.offset - targetH).abs() > 0.5) {
          hScroller.jumpTo(targetH);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _toolbarController = CodeEditorToolbarController(focusNode: _focusNode);
    _loadFileContent();
  }

  @override
  void didUpdateWidget(covariant CodeEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath || oldWidget.rootPath != widget.rootPath) {
      if (_controller != null && oldWidget.filePath != null) {
        try {
          final provider = _getTabProvider(context);
          final oldPath = p.normalize(oldWidget.filePath!);
          final oldTab = provider.openTabs.where((t) => p.equals(t.path, oldPath)).firstOrNull;
          if (oldTab != null && oldTab.isLoaded) {
            final current = _controller!.text.replaceAll('\r\n', '\n');
            final normalizedOriginal = oldTab.originalContent.replaceAll('\r\n', '\n');
            oldTab.content = current;
            oldTab.isModified = current != normalizedOriginal;
            _saveCurrentTabScrollState(oldTab);
          }
        } catch (_) {}
      }
      _loadFileContent();
    }
  }

  @override
  void dispose() {
    try {
      _getTabProvider(context).registerSaveHandler(null);
    } catch (_) {}
    _toolbarController.hide(context);
    final currentTab = _getCurrentTab();
    _saveCurrentTabScrollState(currentTab);
    _scrollController?.verticalScroller.dispose();
    _scrollController?.horizontalScroller.dispose();
    _scrollController?.dispose();
    _controller?.removeListener(_onTextChanged);
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted || _controller == null) return;
    final currentTab = _getCurrentTab();
    if (currentTab == null || !currentTab.isLoaded) return;
    // 确保当前活跃 tab 与当前加载的控制器路径严格一致，杜绝切换过程中误写其他 tab
    if (!p.equals(currentTab.path, _currentLoadedPath ?? '')) return;

    final current = _controller!.text.replaceAll('\r\n', '\n');
    final normalizedOriginal = currentTab.originalContent.replaceAll('\r\n', '\n');
    final isModified = current != normalizedOriginal;

    // 若文本内容与脏状态均未变化（例如光标移动、选区变动、代理绑定），直接跳过
    if (currentTab.content == current && currentTab.isModified == isModified) {
      return;
    }

    currentTab.content = current;
    currentTab.isModified = isModified;

    void notifyProvider() {
      if (!mounted) return;
      try {
        final provider = _getTabProvider(context);
        provider.updateActiveTabContent(current, isModified: isModified);
      } catch (_) {}
    }

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyProvider());
    } else {
      notifyProvider();
    }
  }

  Future<bool> _saveFile({bool showToast = false}) async {
    final currentPath = widget.filePath;
    if (currentPath == null || currentPath.isEmpty || _controller == null) {
      return false;
    }
    final rootPath = widget.rootPath;
    final String fullFilePath = (rootPath == null || rootPath.isEmpty || p.isAbsolute(currentPath))
        ? currentPath
        : p.join(rootPath, currentPath);

    try {
      FileWatcherService.instance.markRecentlySaved(fullFilePath);
      final content = _controller!.text.replaceAll('\r\n', '\n');
      await FileService.instance.saveFile(fullFilePath, content);
      if (mounted) {
        try {
          final provider = _getTabProvider(context);
          final tab = provider.activeTab;
          if (tab != null) {
            tab.content = content;
            tab.originalContent = content;
            tab.isModified = false;
          }
          provider.setModified(false);
        } catch (_) {}
        if (showToast) {
          final l10n = AppLocalizations.of(context);
          DialogUtils.showSuccessToast(context, l10n?.saveSuccess ?? '保存成功');
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        DialogUtils.showErrorToast(
          context,
          l10n?.saveFailed(e.toString()) ?? '保存失败: $e',
        );
      }
      return false;
    }
  }

  void _syncExternalContentIfChanged(TabProvider provider) {
    final activeTab = provider.activeTab;
    if (activeTab == null || _controller == null || _currentLoadedPath == null) return;
    if (!activeTab.isLoaded) return;
    // 仅在当前编辑器已经加载了当前激活 tab 的内容时，才响应外部变动。杜绝标签切换过程中的状态混淆！
    if (!p.equals(activeTab.path, _currentLoadedPath!)) return;

    // 1. 外部修改冲突处理（本地已修改，外部也发生修改）
    if (activeTab.hasExternalConflict && !_isShowingConflictDialog) {
      _isShowingConflictDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final result = await DialogUtils.showFileConflictDialog(
          context,
          fileName: activeTab.name,
        );
        if (!mounted) return;
        _isShowingConflictDialog = false;
        final reload = result == FileConflictResult.reloadFromDisk;
        await provider.resolveConflict(activeTab, reloadFromDisk: reload);
        if (reload && mounted && p.equals(activeTab.path, _currentLoadedPath!)) {
          _controller?.removeListener(_onTextChanged);
          _controller?.text = activeTab.content;
          _controller?.addListener(_onTextChanged);
          setState(() {});
        }
      });
      return;
    }

    // 2. 未修改文件外部静默热更新
    if (!activeTab.isModified && activeTab.content != _controller!.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controller == null || !p.equals(activeTab.path, _currentLoadedPath!)) return;
        _controller?.removeListener(_onTextChanged);
        _controller?.text = activeTab.content;
        _controller?.addListener(_onTextChanged);
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final tabProvider = _getTabProvider(context, listen: true);
      _syncExternalContentIfChanged(tabProvider);
    } catch (_) {}

    final l10n = AppLocalizations.of(context);
    final hasNoProject = widget.rootPath == null || widget.rootPath!.trim().isEmpty;
    final hasNoFile = widget.filePath == null || widget.filePath!.trim().isEmpty;

    if (hasNoProject && hasNoFile) {
      return Center(
        child: Text(
          l10n?.noOpenDirectory ?? "当前未打开项目",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }

    if (hasNoFile) {
      return Center(
        child: Text(
          l10n?.noOpenFile ?? "当前未打开文件",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    // 获取独立的代码编辑器主题与字号（若处于无 Provider 测试环境则安全降级）
    EditorTheme activeTheme = EditorTheme.atomOneDark;
    double activeFontSize = 14.0;
    bool activeWordWrap = true;
    bool enableVirtualKeyboard = false;
    VirtualKeyboardConfig? keyboardConfig;
    AppFontItem activeEditorFont = AppFonts.editorMonospace;
    try {
      final settings = _getSettingsProvider(context, listen: true);
      activeTheme = settings.editorTheme;
      activeFontSize = settings.fontSize;
      activeWordWrap = settings.wordWrap;
      enableVirtualKeyboard = settings.enableVirtualKeyboard;
      keyboardConfig = settings.virtualKeyboardConfig;
      activeEditorFont = settings.editorFont;
      if (_currentIndentSize != null && _currentIndentSize != settings.indentSize) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadFileContent();
        });
      }
    } catch (_) {}

    return Container(
      color: activeTheme.backgroundColor,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: CodeEditor(
              key: ValueKey(_currentLoadedPath),
              controller: controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              wordWrap: activeWordWrap,
              toolbarController: _toolbarController,
              style: CodeEditorStyle(
                fontSize: activeFontSize,
                textColor: activeTheme.textColor,
                backgroundColor: activeTheme.backgroundColor,
                cursorColor: activeTheme.cursorColor,
                cursorLineColor: activeTheme.cursorLineColor,
                selectionColor: activeTheme.selectionColor,
                fontFamily: activeEditorFont.fontFamily,
                fontFamilyFallback: activeEditorFont.fallback,
                codeTheme: CodeHighlightTheme(
                  languages: SyntaxHighlightHelper.getLanguagesForFile(_currentLoadedPath ?? widget.filePath),
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
                        fontSize: (activeFontSize - 1).clamp(9.0, 30.0),
                        fontFamily: activeEditorFont.fontFamily,
                        fontFamilyFallback: activeEditorFont.fallback,
                      ),
                      focusedTextStyle: TextStyle(
                        color: activeTheme.focusedGutterTextColor,
                        fontSize: (activeFontSize - 1).clamp(9.0, 30.0),
                        fontWeight: FontWeight.bold,
                        fontFamily: activeEditorFont.fontFamily,
                        fontFamilyFallback: activeEditorFont.fallback,
                      ),
                    ),
                    DefaultCodeChunkIndicator(
                      width: 20,
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
          if (enableVirtualKeyboard && keyboardConfig != null)
            VirtualKeyboardWidget(
              controller: controller,
              focusNode: _focusNode,
              config: keyboardConfig,
            ),
        ],
      ),
    );
  }

  Future<void> _loadFileContent() async {
    final rootPath = widget.rootPath;
    final filePath = widget.filePath;
    final hasNoProject = rootPath == null || rootPath.trim().isEmpty;
    final hasNoFile = filePath == null || filePath.trim().isEmpty;

    if (hasNoFile) {
      _currentLoadedPath = null;
      _controller?.removeListener(_onTextChanged);
      _controller?.dispose();
      _controller = null;
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            final provider = _getTabProvider(context);
            provider.setModified(false);
            provider.registerSaveHandler(null);
          } catch (_) {}
        });
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    final String fullFilePath = (hasNoProject || p.isAbsolute(filePath))
        ? filePath
        : p.join(rootPath, filePath);

    int activeIndentSize = 2;
    try {
      activeIndentSize = _getSettingsProvider(context).indentSize;
    } catch (_) {}

    if (_currentLoadedPath != null &&
        p.equals(_currentLoadedPath!, fullFilePath) &&
        _controller != null &&
        _currentIndentSize == activeIndentSize) {
      return;
    }

    final provider = _getTabProvider(context);
    final cleanPath = p.normalize(fullFilePath);
    final tab = provider.openTabs.where((t) => p.equals(t.path, cleanPath)).firstOrNull;

    // 内存复用极速通道：若标签页已经在内存中，直接同步切换控制器，0毫秒响应，彻底免去 isLoading 转圈与销毁重建
    if (tab != null && tab.isLoaded) {
      final oldController = _controller;
      oldController?.removeListener(_onTextChanged);

      final normalizedContent = tab.content.replaceAll('\r\n', '\n');
      final normalizedOriginal = tab.originalContent.replaceAll('\r\n', '\n');
      tab.content = normalizedContent;
      tab.originalContent = normalizedOriginal;

      final newController = CodeLineEditingController.fromText(
        normalizedContent,
        CodeLineOptions(indentSize: activeIndentSize),
      );

      _controller = newController;
      _currentLoadedPath = fullFilePath;
      _currentIndentSize = activeIndentSize;
      _errorMessage = null;
      _isLoading = false;

      // 必须在 _controller 和 tab 状态准备就绪后再挂载文本监听，避免初始化阶段被误判为脏
      newController.addListener(_onTextChanged);

      oldController?.dispose();

      _restoreTabScrollState(tab);

      try {
        provider.setModified(tab.isModified);
        provider.registerSaveHandler(() => _saveFile());
      } catch (_) {}

      if (mounted) {
        setState(() {});
      }
      return;
    }

    // 首次冷加载文件（未在内存中）：
    final int requestVersion = ++_currentLoadVersion;

    // 仅在当前未展示任何代码时才显示 loading，已有代码切换时保持编辑器容器，避免白屏闪烁
    if (_controller == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final rawDiskContent = await FileService.instance.readFileContent(fullFilePath);
      final diskContent = rawDiskContent.replaceAll('\r\n', '\n');

      if (!mounted || requestVersion != _currentLoadVersion) {
        return;
      }

      final oldController = _controller;
      oldController?.removeListener(_onTextChanged);

      final newController = CodeLineEditingController.fromText(
        diskContent,
        CodeLineOptions(indentSize: activeIndentSize),
      );

      _controller = newController;
      _currentLoadedPath = fullFilePath;
      _currentIndentSize = activeIndentSize;
      _errorMessage = null;

      if (tab != null) {
        tab.content = diskContent;
        tab.originalContent = diskContent;
        tab.isLoaded = true;
        tab.isModified = false;
      }

      newController.addListener(_onTextChanged);
      oldController?.dispose();

      if (tab != null) {
        _restoreTabScrollState(tab);
      }

      if (mounted) {
        try {
          provider.setModified(tab?.isModified ?? false);
          provider.registerSaveHandler(() => _saveFile());
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted || requestVersion != _currentLoadVersion) return;
      _errorMessage = '$e';
    } finally {
      if (mounted && requestVersion == _currentLoadVersion) {
        setState(() => _isLoading = false);
      }
    }
  }
}