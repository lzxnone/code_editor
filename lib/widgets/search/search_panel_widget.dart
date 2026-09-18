import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/models/search_model.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/search_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/utils/file_icon_utils.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

class SearchPanelWidget extends StatefulWidget {
  /// 一次性加载并展示的文件数量上限
  static const int defaultFilesPageSize = 20;

  /// 每个文件内部一次性加载并展示的查询匹配行数量上限
  static const int defaultFileMatchesPageSize = 20;

  const SearchPanelWidget({super.key});

  @override
  State<SearchPanelWidget> createState() => _SearchPanelWidgetState();
}

class _SearchPanelWidgetState extends State<SearchPanelWidget> {
  late final TextEditingController _searchController;
  late final TextEditingController _replaceController;
  late final ScrollController _scrollController;
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _replaceFocusNode = FocusNode();
  SearchProvider? _fallbackProvider;

  SearchProvider _getEffectiveProvider(BuildContext context, {bool listen = false}) {
    final fromContext = listen ? context.watch<SearchProvider?>() : context.read<SearchProvider?>();
    return fromContext ?? (_fallbackProvider ??= SearchProvider());
  }

  @override
  void initState() {
    super.initState();
    final searchProvider = _getEffectiveProvider(context, listen: false);
    _searchController = TextEditingController(text: searchProvider.query);
    _replaceController = TextEditingController(text: searchProvider.replaceText);
    _scrollController = ScrollController(
      initialScrollOffset: searchProvider.scrollOffset,
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final searchProvider = _getEffectiveProvider(context, listen: false);
      searchProvider.scrollOffset = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      final searchProvider = _getEffectiveProvider(context, listen: false);
      searchProvider.scrollOffset = _scrollController.offset;
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    _searchFocusNode.dispose();
    _replaceFocusNode.dispose();
    _fallbackProvider?.dispose();
    super.dispose();
  }

  final MenuController _menuController = MenuController();
  final MenuController _replaceMenuController = MenuController();

  /// 替换框右侧更多选项弹出菜单（保留大小写）
  Widget _buildReplaceOptionsMenu(
    SearchProvider searchProvider,
    SearchOptions options,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final hasActiveFilter = options.preserveCase;
    final colorScheme = theme.colorScheme;

    return MenuAnchor(
      controller: _replaceMenuController,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        elevation: const WidgetStatePropertyAll(4),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 4),
        ),
      ),
      menuChildren: [
        StatefulBuilder(
          builder: (context, setMenuState) {
            final curOptions = searchProvider.options;
            return SizedBox(
              width: 220,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 保留大小写
                  InkWell(
                    onTap: () {
                      searchProvider.togglePreserveCase();
                      setMenuState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              'AB',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: curOptions.preserveCase
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.preserveCase,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Switch(
                            value: curOptions.preserveCase,
                            onChanged: (val) {
                              searchProvider.togglePreserveCase();
                              setMenuState(() {});
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
      builder: (context, controller, child) {
        return Tooltip(
          message: l10n.replaceMoreOptions,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                Icons.more_vert,
                size: 18,
                color: hasActiveFilter
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 搜索框右侧更多选项弹出菜单（区分大小写、全字匹配、正则表达式）
  Widget _buildSearchOptionsMenu(
    SearchProvider searchProvider,
    SearchOptions options,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final hasActiveFilter = options.caseSensitive || options.wholeWord || options.isRegex;
    final colorScheme = theme.colorScheme;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        elevation: const WidgetStatePropertyAll(4),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 4),
        ),
      ),
      menuChildren: [
        StatefulBuilder(
          builder: (context, setMenuState) {
            final curOptions = searchProvider.options;
            return SizedBox(
              width: 220,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 区分大小写
                  InkWell(
                    onTap: () {
                      searchProvider.toggleCaseSensitive();
                      setMenuState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: curOptions.caseSensitive
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.matchCase,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Switch(
                            value: curOptions.caseSensitive,
                            onChanged: (val) {
                              searchProvider.toggleCaseSensitive();
                              setMenuState(() {});
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 全字匹配
                  InkWell(
                    onTap: () {
                      searchProvider.toggleWholeWord();
                      setMenuState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              'ab',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                                decorationThickness: 2,
                                color: curOptions.wholeWord
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.matchWholeWord,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Switch(
                            value: curOptions.wholeWord,
                            onChanged: (val) {
                              searchProvider.toggleWholeWord();
                              setMenuState(() {});
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 正则表达式
                  InkWell(
                    onTap: () {
                      searchProvider.toggleRegex();
                      setMenuState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '.*',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: curOptions.isRegex
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.useRegularExpression,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Switch(
                            value: curOptions.isRegex,
                            onChanged: (val) {
                              searchProvider.toggleRegex();
                              setMenuState(() {});
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
      builder: (context, controller, child) {
        return Tooltip(
          message: l10n.searchMoreOptions,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                Icons.more_vert,
                size: 18,
                color: hasActiveFilter
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightedSnippet(LineMatch match, ThemeData theme) {
    // 替换换行与制表符，保证单行代码片段整洁
    final cleanLine = match.lineContent.replaceAll('\t', '  ').replaceAll(RegExp(r'[\r\n]'), ' ');
    final start = match.matchStart.clamp(0, cleanLine.length);
    final end = match.matchEnd.clamp(0, cleanLine.length);

    // 匹配处定位显示策略：
    // 若匹配前文本较长，从匹配处往前保留极少量（约4个字符）并加省略号，使显示区域直接聚焦于匹配高亮处
    const int prefixContextLen = 4;
    const int suffixContextLen = 40;

    String before;
    if (start > prefixContextLen) {
      final sub = cleanLine.substring(start - prefixContextLen, start);
      before = '…$sub';
    } else {
      before = cleanLine.substring(0, start);
    }

    final matched = (start <= end) ? cleanLine.substring(start, end) : '';

    String after;
    if (cleanLine.length - end > suffixContextLen) {
      final sub = cleanLine.substring(end, end + suffixContextLen);
      after = '$sub…';
    } else {
      after = (end <= cleanLine.length) ? cleanLine.substring(end) : '';
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.clip,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
          color: theme.colorScheme.onSurface,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: matched,
            style: const TextStyle(
              backgroundColor: Color(0xFFFFEB3B),
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  /// 在文件名搜索模式下，定位到匹配处开始显示并高亮
  Widget _buildFileNameHighlightedTitle(
    String fileName,
    LineMatch? match,
    ThemeData theme,
  ) {
    if (match == null || match.matchStart < 0 || match.matchEnd > fileName.length || match.matchStart >= match.matchEnd) {
      return Text(
        fileName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    }

    final start = match.matchStart.clamp(0, fileName.length);
    final end = match.matchEnd.clamp(0, fileName.length);

    // 名称过长时，直接从匹配处（前留最多 4 个字符）开始显示
    const int prefixContextLen = 4;
    const int suffixContextLen = 40;

    String before;
    if (start > prefixContextLen) {
      final sub = fileName.substring(start - prefixContextLen, start);
      before = '…$sub';
    } else {
      before = fileName.substring(0, start);
    }

    final matched = fileName.substring(start, end);

    String after;
    if (fileName.length - end > suffixContextLen) {
      final sub = fileName.substring(end, end + suffixContextLen);
      after = '$sub…';
    } else {
      after = fileName.substring(end);
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.clip,
      text: TextSpan(
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: theme.colorScheme.onSurface,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: matched,
            style: const TextStyle(
              backgroundColor: Color(0xFFFFEB3B),
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  String _getSearchErrorMessage(SearchResult result, AppLocalizations l10n) {
    if (result.errorCode == SearchErrorCode.invalidRegex ||
        result.errorMessage == '无效的正则表达式') {
      return l10n.searchError(l10n.invalidRegularExpression);
    }
    if (result.errorCode == SearchErrorCode.projectDirNotFound ||
        result.errorMessage == '项目目录不存在') {
      return l10n.searchError(l10n.projectDirectoryNotFound);
    }
    return l10n.searchError(result.errorMessage ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final searchProvider = _getEffectiveProvider(context, listen: true);
    final tabProvider = context.read<TabProvider?>();
    final options = searchProvider.options;
    final result = searchProvider.result;

    // 如果 Provider 中的滚动偏移已被重置为 0（如发起新查询），将列表同步回顶部
    if (searchProvider.scrollOffset == 0.0 && _scrollController.hasClients && _scrollController.offset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _scrollController.offset > 0) {
          _scrollController.jumpTo(0.0);
        }
      });
    }

    // 内存数据实时双向同步校验
    if (_searchController.text != options.query) {
      _searchController.value = _searchController.value.copyWith(
        text: options.query,
        selection: TextSelection.collapsed(offset: options.query.length),
      );
    }
    if (_replaceController.text != options.replaceText) {
      _replaceController.value = _replaceController.value.copyWith(
        text: options.replaceText,
        selection: TextSelection.collapsed(offset: options.replaceText.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部标题栏
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
          ),
          child: SafeArea(
            bottom: false,
            left: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.drawerTabSearch,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: l10n.searchRefresh,
                    icon: const Icon(Icons.refresh),
                    onPressed: () => searchProvider.triggerSearch(),
                  ),
                  if (options.mode == SearchMode.fileName && result.fileResults.isNotEmpty) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: l10n.expandAll,
                      icon: const Icon(Icons.unfold_more),
                      onPressed: () => searchProvider.loadAllFiles(),
                    ),
                  ],
                  if (options.mode == SearchMode.text && result.fileResults.isNotEmpty) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: l10n.expandAll,
                      icon: const Icon(Icons.unfold_more),
                      onPressed: () => searchProvider.expandAll(),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: l10n.collapseAll,
                      icon: const Icon(Icons.unfold_less),
                      onPressed: () => searchProvider.collapseAll(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // 搜索与替换输入操作区
        Padding(
          padding: const EdgeInsets.fromLTRB(6.0, 8.0, 6.0, 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 搜索输入行
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 展开/折叠替换输入栏按钮
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => searchProvider.toggleReplaceExpanded(),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        options.isReplaceExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),

                  // 搜索输入框与内嵌模式切换按钮
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              keyboardType: TextInputType.multiline,
                              minLines: 1,
                              maxLines: 4,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: l10n.searchHint,
                                hintStyle: TextStyle(
                                  fontSize: 12.5,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                border: InputBorder.none,
                              ),
                              onChanged: (val) => searchProvider.setQuery(val),
                            ),
                          ),
                          if (options.query.isNotEmpty)
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () {
                                _searchController.clear();
                                searchProvider.setQuery('');
                                _searchFocusNode.requestFocus();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Icon(
                                  Icons.clear,
                                  size: 15,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),

                          // 搜索模式切换（内容搜索 vs 文件名搜索）- 纯切换按钮，点击只改变图标，不改变背景选中颜色
                          Tooltip(
                            message: options.mode == SearchMode.fileName
                                ? l10n.searchModeFileName
                                : l10n.searchModeText,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () {
                                searchProvider.setMode(
                                  options.mode == SearchMode.text
                                      ? SearchMode.fileName
                                      : SearchMode.text,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Icon(
                                  options.mode == SearchMode.fileName
                                      ? Icons.insert_drive_file_outlined
                                      : Icons.text_fields,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),

                  // 更多选项菜单按钮（区分大小写、全字匹配、正则表达式）
                  _buildSearchOptionsMenu(searchProvider, options, theme, l10n),
                ],
              ),

              // 可折叠展开的替换输入行
              if (options.isReplaceExpanded) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 22), // 对齐上方展开箭头与间距 (18 + 4)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replaceController,
                                focusNode: _replaceFocusNode,
                                keyboardType: TextInputType.multiline,
                                minLines: 1,
                                maxLines: 4,
                                style: const TextStyle(fontSize: 12.5),
                                decoration: InputDecoration(
                                  hintText: l10n.replaceHint,
                                  hintStyle: TextStyle(
                                    fontSize: 12.5,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) => searchProvider.setReplaceText(val),
                              ),
                            ),
                            if (options.replaceText.isNotEmpty)
                              InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  _replaceController.clear();
                                  searchProvider.setReplaceText('');
                                  _replaceFocusNode.requestFocus();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(3.0),
                                  child: Icon(
                                    Icons.clear,
                                    size: 15,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 2),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),

                    // 全局一键替换全部按钮（与右侧更多按钮上下对齐）
                    Tooltip(
                      message: l10n.replaceAllInProject,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: (result.totalMatches > 0 && tabProvider != null)
                            ? () async {
                                final confirmed = await DialogUtils.showConfirmDialog(
                                  context,
                                  title: l10n.confirmReplaceAllTitle,
                                  message: l10n.confirmReplaceAllMessage(
                                    result.totalMatches,
                                    result.fileResults.length,
                                    options.replaceText,
                                  ),
                                  confirmText: l10n.replaceSingleMatch,
                                );
                                if (!confirmed || !context.mounted) return;

                                final count = await searchProvider.replaceAllMatches(
                                  tabProvider: tabProvider,
                                );
                                if (context.mounted && count > 0) {
                                  DialogUtils.showSuccessToast(
                                    context,
                                    l10n.replaceSuccess(count),
                                  );
                                }
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(
                            Icons.find_replace,
                            size: 18,
                            color: result.totalMatches > 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // 更多替换选项菜单按钮（保留大小写）
                    _buildReplaceOptionsMenu(searchProvider, options, theme, l10n),
                  ],
                ),
              ],
            ],
          ),
        ),

        // 加载进度指示器
        if (searchProvider.isLoading)
          const LinearProgressIndicator(minHeight: 2),

        // 状态摘要信息
        if (!searchProvider.isLoading && options.query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    result.errorMessage != null
                        ? _getSearchErrorMessage(result, l10n)
                        : (result.totalMatches > 0
                            ? l10n.searchResultStats(result.fileResults.length, result.totalMatches)
                            : l10n.noSearchResults),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: result.errorMessage != null
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                if (result.durationMs > 0)
                  Text(
                    '${result.durationMs}ms',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),

        const Divider(height: 1),

        // 搜索结果树形列表（按需分页懒加载，彻底消除顶部空白与大列表渲染卡顿）
        Expanded(
          child: result.fileResults.isEmpty
              ? (options.query.isEmpty
                  ? const SizedBox.shrink()
                  : Center(
                      child: Text(
                        l10n.noSearchResults,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ))
              : Builder(
                  builder: (context) {
                    final allFiles = result.fileResults;
                    final visibleFilesCount = allFiles.length < searchProvider.displayedFilesLimit
                        ? allFiles.length
                        : searchProvider.displayedFilesLimit;
                    final visibleFiles = allFiles.take(visibleFilesCount).toList();
                    final hasMoreFiles = allFiles.length > visibleFilesCount;
                    final remainingFilesCount = allFiles.length - visibleFilesCount;
                    final isFileNameMode = options.mode == SearchMode.fileName;

                    // 将搜索树状结构扁平化为一维条目列表，供单一 ListView.builder 进行真正的行级虚拟化
                    final List<_SearchRowItem> flattenedItems = [];
                    if (isFileNameMode) {
                      for (final file in visibleFiles) {
                        flattenedItems.add(_SearchFileNameRowItem(file));
                      }
                    } else {
                      for (final file in visibleFiles) {
                        flattenedItems.add(_SearchFileHeaderRowItem(file));
                        if (file.isExpanded) {
                          final currentMatchesLimit = searchProvider.getFileMatchesLimit(
                            file.filePath,
                            SearchPanelWidget.defaultFileMatchesPageSize,
                          );
                          final allMatches = file.matches;
                          final visibleMatchesCount = allMatches.length < currentMatchesLimit
                              ? allMatches.length
                              : currentMatchesLimit;
                          for (var i = 0; i < visibleMatchesCount; i++) {
                            flattenedItems.add(_SearchMatchLineRowItem(file, allMatches[i]));
                          }
                          if (allMatches.length > visibleMatchesCount) {
                            flattenedItems.add(
                              _SearchLoadMoreMatchesRowItem(
                                file,
                                allMatches.length - visibleMatchesCount,
                              ),
                            );
                          }
                        }
                      }
                    }

                    if (hasMoreFiles) {
                      flattenedItems.add(_SearchLoadMoreFilesRowItem(remainingFilesCount));
                    }

                    return MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: ListView.builder(
                        key: const PageStorageKey('project_search_results_list'),
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: flattenedItems.length,
                        itemBuilder: (context, index) {
                          final item = flattenedItems[index];
                          return switch (item) {
                            _SearchFileNameRowItem(:final file) => _buildFileNameTile(
                                context,
                                theme,
                                file,
                                tabProvider,
                              ),
                            _SearchFileHeaderRowItem(:final file) => _buildFileHeaderTile(
                                context,
                                theme,
                                l10n,
                                file,
                                searchProvider,
                                tabProvider,
                                options,
                              ),
                            _SearchMatchLineRowItem(:final file, :final match) =>
                              _buildMatchLineTile(
                                context,
                                theme,
                                l10n,
                                file,
                                match,
                                searchProvider,
                                tabProvider,
                                options,
                              ),
                            _SearchLoadMoreMatchesRowItem(
                              :final file,
                              :final remainingMatchesCount
                            ) =>
                              _buildLoadMoreMatchesTile(
                                theme,
                                l10n,
                                file,
                                remainingMatchesCount,
                                searchProvider,
                              ),
                            _SearchLoadMoreFilesRowItem(:final remainingFilesCount) =>
                              _buildLoadMoreFilesTile(
                                theme,
                                l10n,
                                remainingFilesCount,
                                searchProvider,
                              ),
                          };
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 加载更多文件条目
  Widget _buildLoadMoreFilesTile(
    ThemeData theme,
    AppLocalizations l10n,
    int remainingFilesCount,
    SearchProvider searchProvider,
  ) {
    return InkWell(
      onTap: () {
        searchProvider.loadMoreFiles(SearchPanelWidget.defaultFilesPageSize);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.expand_more, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.searchLoadMoreFiles(remainingFilesCount),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建文件名/目录名匹配模式的单项条目
  Widget _buildFileNameTile(
    BuildContext context,
    ThemeData theme,
    FileSearchResult fileResult,
    TabProvider? tabProvider,
  ) {
    final match = fileResult.matches.isNotEmpty ? fileResult.matches.first : null;
    final iconData = FileIconUtils.getIcon(
      name: fileResult.fileName,
      isDirectory: fileResult.isDirectory,
    );
    final dirName = p.dirname(fileResult.relativePath);
    final hasDir = dirName != '.' && dirName.isNotEmpty;

    return InkWell(
      onTap: () async {
        if (fileResult.isDirectory) {
          final projectProvider = context.read<ProjectProvider?>();
          if (projectProvider != null) {
            final cleanRoot = projectProvider.rootPath;
            if (cleanRoot != null) {
              final updatedOpenPaths = List<String>.from(projectProvider.openDirectoryPaths);
              if (!updatedOpenPaths.contains(fileResult.filePath)) {
                updatedOpenPaths.add(fileResult.filePath);
              }
              await projectProvider.toggleDirectory(
                FileItem(
                  path: fileResult.filePath,
                  name: fileResult.fileName,
                  relativePath: fileResult.relativePath,
                  isDirectory: true,
                ),
                true,
              );
            }
          }
        } else {
          if (tabProvider != null) {
            await tabProvider.openFile(fileResult.filePath);
          }
        }
        if (context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10.0,
          vertical: 6.0,
        ),
        child: Row(
          children: [
            Icon(
              iconData,
              size: 18,
              color: fileResult.isDirectory
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFileNameHighlightedTitle(
                    fileResult.fileName,
                    match,
                    theme,
                  ),
                  if (hasDir)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        dirName,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建文本匹配模式下的文件分组头部条目
  Widget _buildFileHeaderTile(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    FileSearchResult fileResult,
    SearchProvider searchProvider,
    TabProvider? tabProvider,
    SearchOptions options,
  ) {
    final isExpanded = fileResult.isExpanded;
    final dirName = p.dirname(fileResult.relativePath);
    final hasDir = dirName != '.' && dirName.isNotEmpty;
    final iconData = FileIconUtils.getIcon(
      name: fileResult.fileName,
      isDirectory: fileResult.isDirectory,
    );

    return InkWell(
      onTap: () => searchProvider.toggleFileExpanded(fileResult),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10.0,
          vertical: 6.0,
        ),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Icon(
              iconData,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            // 主标题文件名，副标题相对路径（一上一下）
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileResult.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (hasDir)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        dirName,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // 匹配次数 Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${fileResult.matchCount}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // 该文件折叠项全部展开按钮：一键展开并展示该文件内所有匹配行
            IconButton(
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
                padding: const EdgeInsets.all(4),
              ),
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              iconSize: 16,
              icon: const Icon(Icons.unfold_more_rounded),
              tooltip: l10n.searchExpandAllMatchesInFile,
              onPressed: () {
                searchProvider.expandAndLoadAllMatchesForFile(fileResult);
              },
            ),

            // 文件级全部替换按钮：仅在展开替换输入框时展示
            if (options.mode == SearchMode.text && options.isReplaceExpanded)
              IconButton(
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.all(4),
                ),
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
                iconSize: 16,
                icon: const Icon(Icons.find_replace),
                tooltip: l10n.replaceAllInFile,
                onPressed: tabProvider == null
                    ? null
                    : () async {
                        final confirmed = await DialogUtils.showConfirmDialog(
                          context,
                          title: l10n.confirmReplaceFileTitle,
                          message: l10n.confirmReplaceFileMessage(
                            fileResult.fileName,
                            fileResult.matchCount,
                            options.replaceText,
                          ),
                          confirmText: l10n.replaceSingleMatch,
                        );
                        if (!confirmed || !context.mounted) return;

                        final count = await searchProvider.replaceFileMatches(
                          file: fileResult,
                          tabProvider: tabProvider,
                        );
                        if (context.mounted && count > 0) {
                          DialogUtils.showSuccessToast(
                            context,
                            l10n.replaceSuccess(count),
                          );
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }

  /// 构建具体代码匹配行条目
  Widget _buildMatchLineTile(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    FileSearchResult fileResult,
    LineMatch match,
    SearchProvider searchProvider,
    TabProvider? tabProvider,
    SearchOptions options,
  ) {
    return InkWell(
      onTap: () async {
        if (tabProvider != null) {
          // 1. 打开文件并切换 tab
          await tabProvider.openFile(fileResult.filePath);
          // 2. 发送行定位与选区高亮事件
          tabProvider.navigateTo(
            filePath: fileResult.filePath,
            line: match.lineNumber - 1,
            column: match.matchStart,
            length: match.matchEnd - match.matchStart,
          );
        }
        // 3. 移动端抽屉收起（保留宽屏适配）
        if (context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36.0, 4.0, 10.0, 4.0),
        child: Row(
          children: [
            // 行号
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 28),
              child: Text(
                '${match.lineNumber}:',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // 代码文本摘要（黄色高亮匹配部分）
            Expanded(
              child: _buildHighlightedSnippet(match, theme),
            ),

            // 行单项替换按钮：仅在展开替换输入框时展示
            if (options.mode == SearchMode.text && options.isReplaceExpanded)
              IconButton(
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.all(3),
                ),
                constraints: const BoxConstraints(
                  minWidth: 22,
                  minHeight: 22,
                ),
                iconSize: 15,
                icon: const Icon(Icons.redo),
                tooltip: l10n.replaceSingleMatch,
                onPressed: tabProvider == null
                    ? null
                    : () async {
                        final success = await searchProvider.replaceSingleMatch(
                          file: fileResult,
                          match: match,
                          tabProvider: tabProvider,
                        );
                        if (context.mounted && success) {
                          DialogUtils.showSuccessToast(
                            context,
                            l10n.replaceSuccess(1),
                          );
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }

  /// 构建文件内更多匹配项加载按钮条目
  Widget _buildLoadMoreMatchesTile(
    ThemeData theme,
    AppLocalizations l10n,
    FileSearchResult fileResult,
    int remainingMatchesCount,
    SearchProvider searchProvider,
  ) {
    return InkWell(
      onTap: () {
        searchProvider.loadMoreMatches(
          fileResult.filePath,
          SearchPanelWidget.defaultFileMatchesPageSize,
          SearchPanelWidget.defaultFileMatchesPageSize,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36.0, 6.0, 10.0, 8.0),
        child: Row(
          children: [
            Icon(
              Icons.more_horiz,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.searchLoadMoreMatches(remainingMatchesCount),
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 扁平化虚拟条目抽象基类
sealed class _SearchRowItem {}

/// 文件名检索模式条目
class _SearchFileNameRowItem extends _SearchRowItem {
  final FileSearchResult file;
  _SearchFileNameRowItem(this.file);
}

/// 文本内容检索模式下的文件分组头部条目
class _SearchFileHeaderRowItem extends _SearchRowItem {
  final FileSearchResult file;
  _SearchFileHeaderRowItem(this.file);
}

/// 文本内容检索模式下的具体代码匹配行条目
class _SearchMatchLineRowItem extends _SearchRowItem {
  final FileSearchResult file;
  final LineMatch match;
  _SearchMatchLineRowItem(this.file, this.match);
}

/// 文件内加载更多匹配项条目
class _SearchLoadMoreMatchesRowItem extends _SearchRowItem {
  final FileSearchResult file;
  final int remainingMatchesCount;
  _SearchLoadMoreMatchesRowItem(this.file, this.remainingMatchesCount);
}

/// 搜索结果底部加载更多文件条目
class _SearchLoadMoreFilesRowItem extends _SearchRowItem {
  final int remainingFilesCount;
  _SearchLoadMoreFilesRowItem(this.remainingFilesCount);
}
