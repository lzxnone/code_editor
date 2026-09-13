import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../models/virtual_keyboard_config.dart';
import '../providers/settings_provider.dart';
import '../utils/dialog_utils.dart';
import '../widgets/virtual_keyboard_page_drawer.dart';
import '../widgets/virtual_keyboard_page_config_section.dart';
import '../widgets/virtual_keyboard_row_tile.dart';
import '../widgets/virtual_keyboard_key_edit_dialog.dart';

/// 虚拟小键盘图形化配置视图
class VirtualKeyboardConfigView extends StatefulWidget {
  final KeyboardScope scope;

  const VirtualKeyboardConfigView({
    super.key,
    this.scope = KeyboardScope.editor,
  });

  @override
  State<VirtualKeyboardConfigView> createState() => _VirtualKeyboardConfigViewState();
}

class _VirtualKeyboardConfigViewState extends State<VirtualKeyboardConfigView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _pageScrollController = ScrollController();

  /// 当前工作区正在编辑的页面索引 (0-indexed)
  int _currentPageIndex = 0;

  /// 本地维护的工作副本，实时同步至 SettingsProvider
  late VirtualKeyboardConfig _config;

  /// 页面内部行展开状态缓存：`pageIndex` -> `Set<int>`
  final Map<int, Set<int>> _expandedRowsByPage = {};

  /// 页面滚动偏移量缓存：pageIndex -> double
  final Map<int, double> _scrollOffsetByPage = {};

  @override
  void initState() {
    super.initState();
    final settingsProvider = context.read<SettingsProvider>();
    _config = settingsProvider.virtualKeyboardConfig;
    if (_currentPageIndex >= _config.pages.length) {
      _currentPageIndex = 0;
    }
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  /// 切换当前页面并恢复该页面的滚动位置
  void _selectPage(int index) {
    if (_currentPageIndex == index) return;

    if (_pageScrollController.hasClients) {
      _scrollOffsetByPage[_currentPageIndex] = _pageScrollController.offset;
    }

    setState(() {
      _currentPageIndex = index;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageScrollController.hasClients) {
        final targetOffset = _scrollOffsetByPage[index] ?? 0.0;
        final maxScroll = _pageScrollController.position.maxScrollExtent;
        final clampedOffset = targetOffset.clamp(0.0, maxScroll);
        _pageScrollController.jumpTo(clampedOffset);
      }
    });
  }

  /// 保存并同步到 SettingsProvider
  Future<void> _syncAndSaveConfig() async {
    final settingsProvider = context.read<SettingsProvider>();
    const encoder = JsonEncoder.withIndent('  ');
    final jsonStr = encoder.convert(_config.toJson());
    await settingsProvider.setVirtualKeyboardConfig(jsonStr);
  }

  /// 恢复默认配置
  Future<void> _resetToDefault() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.keyboardResetDefaultTitle),
        content: Text(l10n.keyboardResetDefaultContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.resetDefault),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.resetVirtualKeyboardConfig();
      if (!mounted) return;
      setState(() {
        _config = settingsProvider.virtualKeyboardConfig;
        _currentPageIndex = 0;
        _expandedRowsByPage.clear();
        _scrollOffsetByPage.clear();
      });
      if (_pageScrollController.hasClients) {
        _pageScrollController.jumpTo(0.0);
      }
      DialogUtils.showToast(context, l10n.keyboardResetDefaultSuccess, type: ToastType.success);
    }
  }

  /// 添加新页面
  void _addNewPage() {
    final newPageIndex = _config.pages.length;
    if (_pageScrollController.hasClients) {
      _scrollOffsetByPage[_currentPageIndex] = _pageScrollController.offset;
    }

    setState(() {
      final newPage = KeyboardPageItem(
        count: 7,
        keys: [
          [
            const KeyboardKeyItem(label: 'New', value: 'New'),
          ],
        ],
      );
      final newPages = List<KeyboardPageItem>.from(_config.pages)..add(newPage);
      _config = _config.copyWith(pages: newPages);
      _currentPageIndex = newPageIndex;
      _expandedRowsByPage[newPageIndex] = <int>{};
      _scrollOffsetByPage[newPageIndex] = 0.0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageScrollController.hasClients) {
        _pageScrollController.jumpTo(0.0);
      }
    });

    _syncAndSaveConfig();
  }

  /// 删除指定页面
  void _deletePage(int pageIndex) {
    final l10n = AppLocalizations.of(context)!;
    if (_config.pages.length <= 1) {
      DialogUtils.showToast(context, l10n.keyboardKeepAtLeastOnePageWarning, type: ToastType.warning);
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.keyboardDeletePageTitle),
        content: Text(l10n.keyboardDeletePageContent(pageIndex + 1)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() {
          final newPages = List<KeyboardPageItem>.from(_config.pages)..removeAt(pageIndex);
          _config = _config.copyWith(pages: newPages);

          _expandedRowsByPage.remove(pageIndex);
          _scrollOffsetByPage.remove(pageIndex);

          if (_currentPageIndex >= newPages.length) {
            _currentPageIndex = newPages.length - 1;
          }
        });
        _syncAndSaveConfig();
      }
    });
  }

  /// 页面拖拽重排序
  void _reorderPages(int oldIndex, int newIndex) {
    setState(() {
      final newPages = List<KeyboardPageItem>.from(_config.pages);
      final item = newPages.removeAt(oldIndex);
      newPages.insert(newIndex, item);

      final oldExpanded = _expandedRowsByPage.remove(oldIndex);
      final oldOffset = _scrollOffsetByPage.remove(oldIndex);

      if (_currentPageIndex == oldIndex) {
        _currentPageIndex = newIndex;
      } else if (_currentPageIndex > oldIndex && _currentPageIndex <= newIndex) {
        _currentPageIndex -= 1;
      } else if (_currentPageIndex < oldIndex && _currentPageIndex >= newIndex) {
        _currentPageIndex += 1;
      }

      if (oldExpanded != null) {
        _expandedRowsByPage[newIndex] = oldExpanded;
      }
      if (oldOffset != null) {
        _scrollOffsetByPage[newIndex] = oldOffset;
      }

      _config = _config.copyWith(pages: newPages);
    });
    _syncAndSaveConfig();
  }

  /// 修改当前页的 count（减小时，最大行按键数不能大于目标按键数）
  void _updateCurrentPageCount(int newCount) {
    if (newCount < 1 || newCount > 12) return;
    final page = _config.pages[_currentPageIndex];

    if (newCount < page.count) {
      int maxKeysInRows = 0;
      for (final row in page.keys) {
        if (row.length > maxKeysInRows) {
          maxKeysInRows = row.length;
        }
      }
      if (maxKeysInRows > newCount) {
        final l10n = AppLocalizations.of(context)!;
        DialogUtils.showToast(
          context,
          l10n.keyboardRowMaxKeysWarning(maxKeysInRows),
          type: ToastType.warning,
        );
        return;
      }
    }

    setState(() {
      final updatedPage = page.copyWith(count: newCount);
      final newPages = List<KeyboardPageItem>.from(_config.pages);
      newPages[_currentPageIndex] = updatedPage;
      _config = _config.copyWith(pages: newPages);
    });
    _syncAndSaveConfig();
  }

  /// 向当前页添加一行
  void _addNewRow() {
    setState(() {
      final page = _config.pages[_currentPageIndex];
      final newKeys = List<List<KeyboardKeyItem>>.from(page.keys);
      newKeys.add([]);
      final updatedPage = page.copyWith(keys: newKeys);
      final newPages = List<KeyboardPageItem>.from(_config.pages);
      newPages[_currentPageIndex] = updatedPage;
      _config = _config.copyWith(pages: newPages);
    });
    _syncAndSaveConfig();
  }

  /// 删除当前页的指定行（带二次确认弹窗）
  void _deleteRow(int rowIndex) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.keyboardDeleteRowTitle),
        content: Text(l10n.keyboardDeleteRowContent(rowIndex + 1)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() {
          final page = _config.pages[_currentPageIndex];
          final newKeys = List<List<KeyboardKeyItem>>.from(page.keys)..removeAt(rowIndex);
          final updatedPage = page.copyWith(keys: newKeys);
          final newPages = List<KeyboardPageItem>.from(_config.pages);
          newPages[_currentPageIndex] = updatedPage;
          _config = _config.copyWith(pages: newPages);

          final expandedSet = _expandedRowsByPage[_currentPageIndex];
          if (expandedSet != null) {
            expandedSet.remove(rowIndex);
          }
        });
        _syncAndSaveConfig();
      }
    });
  }

  /// 行拖动重排序
  void _reorderRows(int oldIndex, int newIndex) {
    setState(() {
      final page = _config.pages[_currentPageIndex];
      final newKeys = List<List<KeyboardKeyItem>>.from(page.keys);
      final row = newKeys.removeAt(oldIndex);
      newKeys.insert(newIndex, row);

      final updatedPage = page.copyWith(keys: newKeys);
      final newPages = List<KeyboardPageItem>.from(_config.pages);
      newPages[_currentPageIndex] = updatedPage;
      _config = _config.copyWith(pages: newPages);
    });
    _syncAndSaveConfig();
  }

  /// 添加或编辑按键
  Future<void> _openKeyEditDialog({
    required int rowIndex,
    int? keyIndex,
    KeyboardKeyItem? initialKey,
  }) async {
    final page = _config.pages[_currentPageIndex];
    if (keyIndex == null) {
      final currentRowKeysCount = page.keys[rowIndex].length;
      if (currentRowKeysCount >= page.count) {
        final l10n = AppLocalizations.of(context)!;
        DialogUtils.showToast(
          context,
          l10n.keyboardRowReachedMaxWarning(page.count),
          type: ToastType.warning,
        );
        return;
      }
    }

    final result = await showDialog<KeyboardKeyItem>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => KeyEditDialog(
        scope: widget.scope,
        initialKey: initialKey,
      ),
    );

    if (result != null) {
      setState(() {
        final currentPage = _config.pages[_currentPageIndex];
        final newKeys = List<List<KeyboardKeyItem>>.from(
          currentPage.keys.map((row) => List<KeyboardKeyItem>.from(row)),
        );

        if (keyIndex == null) {
          newKeys[rowIndex].add(result);
        } else {
          newKeys[rowIndex][keyIndex] = result;
        }

        final updatedPage = currentPage.copyWith(keys: newKeys);
        final newPages = List<KeyboardPageItem>.from(_config.pages);
        newPages[_currentPageIndex] = updatedPage;
        _config = _config.copyWith(pages: newPages);
      });
      _syncAndSaveConfig();
    }
  }

  /// 删除按键（带二次确认弹窗）
  void _deleteKey(int rowIndex, int keyIndex) {
    final page = _config.pages[_currentPageIndex];
    if (rowIndex >= page.keys.length || keyIndex >= page.keys[rowIndex].length) return;
    final keyItem = page.keys[rowIndex][keyIndex];
    final keyName = keyItem.label.isNotEmpty ? keyItem.label : keyItem.value;

    final l10n = AppLocalizations.of(context)!;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.keyboardDeleteKeyTitle),
        content: Text(l10n.keyboardDeleteKeyContent(keyName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() {
          final currentPage = _config.pages[_currentPageIndex];
          final newKeys = List<List<KeyboardKeyItem>>.from(
            currentPage.keys.map((row) => List<KeyboardKeyItem>.from(row)),
          );
          newKeys[rowIndex].removeAt(keyIndex);

          final updatedPage = currentPage.copyWith(keys: newKeys);
          final newPages = List<KeyboardPageItem>.from(_config.pages);
          newPages[_currentPageIndex] = updatedPage;
          _config = _config.copyWith(pages: newPages);
        });
        _syncAndSaveConfig();
      }
    });
  }

  /// 行内按键拖动重排序
  void _reorderKeys(int rowIndex, int oldIndex, int newIndex) {
    setState(() {
      final page = _config.pages[_currentPageIndex];
      final newKeys = List<List<KeyboardKeyItem>>.from(
        page.keys.map((row) => List<KeyboardKeyItem>.from(row)),
      );
      final item = newKeys[rowIndex].removeAt(oldIndex);
      newKeys[rowIndex].insert(newIndex, item);

      final updatedPage = page.copyWith(keys: newKeys);
      final newPages = List<KeyboardPageItem>.from(_config.pages);
      newPages[_currentPageIndex] = updatedPage;
      _config = _config.copyWith(pages: newPages);
    });
    _syncAndSaveConfig();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currentPage = (_currentPageIndex < _config.pages.length)
        ? _config.pages[_currentPageIndex]
        : _config.pages.first;

    final scopeName = widget.scope == KeyboardScope.editor
        ? l10n.editorScope
        : l10n.terminalScope;
    final subtitleText = l10n.virtualKeyboardPageSubtitle(scopeName, _currentPageIndex + 1);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.virtualKeyboardConfigTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitleText,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.keyboardRestoreDefaultTooltip,
            onPressed: _resetToDefault,
          ),
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            tooltip: l10n.keyboardPageManagementTooltip,
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: VirtualKeyboardPageDrawer(
        pages: _config.pages,
        currentPageIndex: _currentPageIndex,
        onAddNewPage: _addNewPage,
        onSelectPage: _selectPage,
        onDeletePage: _deletePage,
        onReorderPages: _reorderPages,
      ),
      body: ListView(
        controller: _pageScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 板块一：当前页配置
          VirtualKeyboardPageConfigSection(
            count: currentPage.count,
            onCountChanged: _updateCurrentPageCount,
          ),
          const SizedBox(height: 20),

          // 板块二：页面按键行管理
          _buildPageKeysSection(theme, l10n, currentPage),
        ],
      ),
    );
  }

  /// 板块二：按键行管理
  Widget _buildPageKeysSection(ThemeData theme, AppLocalizations l10n, KeyboardPageItem currentPage) {
    final expandedRows = _expandedRowsByPage.putIfAbsent(_currentPageIndex, () => <int>{});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.keyboard_alt_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.keyboardPageKeysSectionTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.keyboardAddNewRow),
              onPressed: _addNewRow,
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (currentPage.keys.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.keyboard_outlined, size: 48, color: theme.hintColor.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Text(l10n.keyboardEmptyPageKeysHint, style: TextStyle(color: theme.hintColor)),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.keyboardAddNewRow),
                  onPressed: _addNewRow,
                ),
              ],
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: currentPage.keys.length,
            onReorderItem: _reorderRows,
            itemBuilder: (context, rowIndex) {
              final rowKeys = currentPage.keys[rowIndex];
              final isExpanded = expandedRows.contains(rowIndex);

              return VirtualKeyboardRowTile(
                key: ValueKey('page_${_currentPageIndex}_row_$rowIndex'),
                pageIndex: _currentPageIndex,
                rowIndex: rowIndex,
                rowKeys: rowKeys,
                isExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  if (expanded) {
                    expandedRows.add(rowIndex);
                  } else {
                    expandedRows.remove(rowIndex);
                  }
                },
                onAddKey: () => _openKeyEditDialog(rowIndex: rowIndex),
                onDeleteRow: () => _deleteRow(rowIndex),
                onReorderKeys: (oldIdx, newIdx) => _reorderKeys(rowIndex, oldIdx, newIdx),
                onEditKey: (keyIdx, keyItem) => _openKeyEditDialog(
                  rowIndex: rowIndex,
                  keyIndex: keyIdx,
                  initialKey: keyItem,
                ),
                onDeleteKey: (keyIdx) => _deleteKey(rowIndex, keyIdx),
              );
            },
          ),
      ],
    );
  }
}
