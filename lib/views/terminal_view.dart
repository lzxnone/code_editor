import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/app_font.dart';
import 'package:code_editor/models/terminal_session.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/widgets/distro_extract_dialog.dart';
import 'package:code_editor/widgets/distro_selector_dialog.dart';
import 'package:code_editor/widgets/terminal_drawer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart' as xterm;

/// 终端视图（支持多系统实例切换、全屏会话保持、右侧抽屉多会话管理与交互）
class TerminalView extends StatefulWidget {
  const TerminalView({super.key});

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // 首次或进入终端时：检测已安装系统。如果不存在任何系统，自动从软件内置导入 alpine
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final distroProvider = context.read<DistroProvider?>();
      final l10n = AppLocalizations.of(context)!;
      final defaultSessionName = l10n.sessionDefaultName;

      if (distroProvider == null) {
        context.read<TerminalProvider>().ensureInitialized(defaultName: defaultSessionName);
        return;
      }

      await distroProvider.init();
      if (!mounted) return;

      if (!distroProvider.hasAnySystem) {
        // 自动从软件内置资源导入 alpine，名称即为 alpine
        final success = await DistroExtractDialog.show(
          context: context,
          systemName: 'alpine',
          task: (onProgress, isCancelled) {
            return distroProvider.importBuiltinAlpine(
              systemName: 'alpine',
              onProgress: onProgress,
              isCancelled: isCancelled,
            );
          },
        );

        if (success && mounted) {
          final termProvider = context.read<TerminalProvider>();
          if (termProvider.isEmpty) {
            termProvider.createSession(
              name: defaultSessionName,
              distroId: 'alpine',
              activate: true,
            );
          }
        }
      } else {
        // 已有系统，确保初始化首个会话
        final termProvider = context.read<TerminalProvider>();
        if (termProvider.isEmpty) {
          final system = distroProvider.selectedSystem ?? 'alpine';
          termProvider.createSession(
            name: defaultSessionName,
            distroId: system,
            activate: true,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TerminalProvider>();
    final distroProvider = context.watch<DistroProvider?>();

    final activeSession = provider.activeSession;
    final sessions = provider.sessions;
    final activeIndex = provider.activeIndex;

    final titleText = activeSession?.name ?? l10n.sessionDefaultName;
    final currentSystem = activeSession?.distroId ?? distroProvider?.selectedSystem;
    final subtitleText = currentSystem != null ? l10n.terminalWithSystem(currentSystem) : l10n.terminal;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onSurface,
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
              titleText,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
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
          // 系统选择与管理按钮（位于会话列表左侧）
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: l10n.systemManagementTooltip,
            onPressed: () {
              DistroSelectorDialog.show(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: l10n.sessionListTooltip,
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: const TerminalDrawer(),
      body: sessions.isEmpty
          ? Center(
              child: Text(
                l10n.noActiveSessions,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : IndexedStack(
              index: (activeIndex >= 0 && activeIndex < sessions.length) ? activeIndex : 0,
              children: [
                for (final session in sessions)
                  _TerminalSessionBody(
                    key: ValueKey(session.id),
                    session: session,
                  ),
              ],
            ),
    );
  }
}

/// 单个真实交互式终端会话的终端渲染与交互容器
class _TerminalSessionBody extends StatefulWidget {
  final TerminalSession session;

  const _TerminalSessionBody({
    super.key,
    required this.session,
  });

  @override
  State<_TerminalSessionBody> createState() => _TerminalSessionBodyState();
}

class _TerminalSessionBodyState extends State<_TerminalSessionBody> {
  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final settings = context.watch<SettingsProvider?>();
    final terminalFont = settings?.terminalFont ?? AppFonts.terminalMonospace;

    final terminalStyle = xterm.TerminalStyle(
      fontSize: 13.0,
      fontFamily: terminalFont.fontFamily ?? 'monospace',
      fontFamilyFallback: terminalFont.fallback,
    );

    return Container(
      color: const Color(0xFF181818),
      child: SafeArea(
        top: false,
        child: xterm.TerminalView(
          session.terminal,
          focusNode: session.focusNode,
          autofocus: true,
          theme: xterm.TerminalThemes.defaultTheme,
          textStyle: terminalStyle,
          cursorType: xterm.TerminalCursorType.block,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        ),
      ),
    );
  }
}
