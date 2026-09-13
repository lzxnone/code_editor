import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/views/terminal_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';

class CodeEditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? filePath;
  final String? rootPath;
  final bool isModified;
  final VoidCallback? onSave;
  final VoidCallback? onSaveAll;
  final VoidCallback? onRun;
  final VoidCallback? onTerminal;
  final VoidCallback? onCloseAllTabs;
  final VoidCallback? onCloseProject;
  final VoidCallback? onSettings;

  const CodeEditorAppBar({
    super.key,
    required this.filePath,
    this.rootPath,
    this.isModified = false,
    this.onSave,
    this.onSaveAll,
    this.onRun,
    this.onTerminal,
    this.onCloseAllTabs,
    this.onCloseProject,
    this.onSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final path = filePath;

    final String titleText;
    final String? subtitleText;
    if (path != null && path.isNotEmpty) {
      final base = p.basename(path);
      titleText = isModified ? '* $base' : base;

      if (rootPath != null && rootPath!.trim().isNotEmpty) {
        final cleanRoot = p.normalize(rootPath!.trim());
        final cleanFile = p.normalize(path.trim());
        final dirPath = p.dirname(cleanFile);

        if (dirPath == cleanRoot || !p.isWithin(cleanRoot, cleanFile)) {
          subtitleText = '/';
        } else {
          final rel = p.relative(dirPath, from: cleanRoot);
          final formattedRel = rel.replaceAll(r'\', '/');
          subtitleText = formattedRel.startsWith('/') ? formattedRel : '/$formattedRel';
        }
      } else {
        subtitleText = '/';
      }
    } else {
      titleText = '';
      subtitleText = null;
    }

    final isDark = theme.brightness == Brightness.dark;

    return CodeEditorTapRegion(
      child: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titleText,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitleText != null)
              Text(
                subtitleText,
                style: TextStyle(
                  fontSize: 11.0,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.play_arrow),
              tooltip: l10n.run,
              onPressed: onRun ?? () {},
            ),
          ),
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.save_outlined),
              tooltip: l10n.save,
              onPressed: onSave ?? () {},
            ),
          ),
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.terminal),
              tooltip: '终端',
              onPressed: onTerminal ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const TerminalView(),
                      ),
                    );
                  },
            ),
          ),
          _MoreMenuButton(
            onSaveAll: onSaveAll,
            onCloseAllTabs: onCloseAllTabs,
            onCloseProject: onCloseProject,
            onSettings: onSettings,
          ),
        ],
      ),
    );
  }
}

/// 基于 OverlayEntry 的右上角更多菜单组件（带对齐右上角缩放淡入淡出动画，非模态不关闭键盘）
class _MoreMenuButton extends StatefulWidget {
  final VoidCallback? onSaveAll;
  final VoidCallback? onCloseAllTabs;
  final VoidCallback? onCloseProject;
  final VoidCallback? onSettings;

  const _MoreMenuButton({
    this.onSaveAll,
    this.onCloseAllTabs,
    this.onCloseProject,
    this.onSettings,
  });

  @override
  State<_MoreMenuButton> createState() => _MoreMenuButtonState();
}

class _MoreMenuButtonState extends State<_MoreMenuButton> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  OverlayEntry? _barrierEntry;
  OverlayEntry? _menuEntry;
  final GlobalKey _buttonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _forceRemoveEntries();
    super.dispose();
  }

  void _forceRemoveEntries() {
    if (_barrierEntry != null && _barrierEntry!.mounted) {
      _barrierEntry!.remove();
    }
    _barrierEntry = null;

    if (_menuEntry != null && _menuEntry!.mounted) {
      _menuEntry!.remove();
    }
    _menuEntry = null;
  }

  void _closeMenu({VoidCallback? onClosed}) async {
    if (_menuEntry == null) {
      onClosed?.call();
      return;
    }
    try {
      await _animController.reverse();
    } catch (_) {}
    if (mounted) {
      _forceRemoveEntries();
      onClosed?.call();
    }
  }

  void _showMenu() {
    _forceRemoveEntries();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final onSurfaceColor = theme.colorScheme.onSurface;

    _barrierEntry = OverlayEntry(
      builder: (ctx) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _closeMenu(),
        ),
      ),
    );

    _menuEntry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          top: offset.dy + size.height + 4,
          right: 8,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.topRight,
              child: Material(
                color: theme.colorScheme.surface,
                surfaceTintColor: theme.colorScheme.surfaceTint,
                elevation: 6,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 1.0,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMenuItem(
                        icon: Icons.save_as_outlined,
                        title: l10n.saveAll,
                        iconColor: onSurfaceColor,
                        onTap: () {
                          _closeMenu(onClosed: widget.onSaveAll);
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.close_fullscreen_outlined,
                        title: l10n.closeAllTabs,
                        iconColor: onSurfaceColor,
                        onTap: () {
                          _closeMenu(onClosed: widget.onCloseAllTabs);
                        },
                      ),
                      Divider(
                        height: 9,
                        thickness: 0.8,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      _buildMenuItem(
                        icon: Icons.folder_off_outlined,
                        title: l10n.closeProject,
                        iconColor: onSurfaceColor,
                        onTap: () {
                          _closeMenu(onClosed: widget.onCloseProject);
                        },
                      ),
                      Divider(
                        height: 9,
                        thickness: 0.8,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      _buildMenuItem(
                        icon: Icons.settings,
                        title: l10n.settings,
                        iconColor: onSurfaceColor,
                        onTap: () {
                          _closeMenu(onClosed: widget.onSettings);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insertAll([_barrierEntry!, _menuEntry!]);
    _animController.forward(from: 0.0);
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isDestructive ? theme.colorScheme.error : iconColor,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.0,
                color: isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: IconButton(
        key: _buttonKey,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.more_vert),
        tooltip: l10n.more,
        onPressed: _showMenu,
      ),
    );
  }
}
