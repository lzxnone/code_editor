import 'package:code_editor/models/app_font.dart';
import 'package:code_editor/models/distro_info.dart';
import 'package:code_editor/models/terminal_session.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/widgets/terminal_drawer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 终端视图（支持全屏会话保持、右侧抽屉多会话管理与交互）
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
    // 懒加载：进入终端 view 时，若无会话则自动创建首个会话
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TerminalProvider>().ensureInitialized();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TerminalProvider>();
    final activeSession = provider.activeSession;
    final sessions = provider.sessions;
    final activeIndex = provider.activeIndex;

    final titleText = activeSession?.name ?? '会话';
    const subtitleText = '终端';

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
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
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: '会话列表',
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: const TerminalDrawer(),
      body: sessions.isEmpty
          ? const Center(
              child: Text(
                '暂无活跃会话',
                style: TextStyle(color: Colors.grey),
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

/// 单个终端会话的终端渲染与交互容器
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

    return Container(
      color: const Color(0xFF181818),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // 点击终端空白区域自动聚焦输入框
            session.focusNode.requestFocus();
          },
          child: Column(
            children: [
              if (_buildDistroStatusBar(context, session) != null)
                _buildDistroStatusBar(context, session)!,
              // 终端输出流滚动区域
              Expanded(
                child: ListView.builder(
                  controller: session.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  itemCount: session.outputLines.length,
                  itemBuilder: (context, index) {
                    final line = session.outputLines[index];
                    final isPrompt = line.startsWith('\$');
                    return SelectableText(
                      line.isEmpty ? ' ' : line,
                      style: TextStyle(
                        fontFamily: terminalFont.fontFamily,
                        fontFamilyFallback: terminalFont.fallback,
                        fontSize: 13.0,
                        color: isPrompt ? const Color(0xFF64B5F6) : const Color(0xFFD4D4D4),
                        height: 1.35,
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
              // 终端命令行交互输入框
              Container(
                color: const Color(0xFF1E1E1E),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  children: [
                    Text(
                      '\$ ',
                      style: TextStyle(
                        color: const Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                        fontFamily: terminalFont.fontFamily,
                        fontFamilyFallback: terminalFont.fallback,
                        fontSize: 14.0,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: session.inputController,
                        focusNode: session.focusNode,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: terminalFont.fontFamily,
                          fontFamilyFallback: terminalFont.fallback,
                          fontSize: 13.0,
                        ),
                        cursorColor: const Color(0xFF4CAF50),
                        decoration: const InputDecoration(
                          hintText: '输入命令...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13.0),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                        ),
                        onSubmitted: (text) {
                          if (text.isNotEmpty) {
                            context.read<TerminalProvider>().executeCommand(session, text);
                            session.inputController.clear();
                            session.focusNode.requestFocus();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, size: 18, color: Colors.white70),
                      tooltip: '发送命令',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final text = session.inputController.text;
                        if (text.isNotEmpty) {
                          context.read<TerminalProvider>().executeCommand(session, text);
                          session.inputController.clear();
                          session.focusNode.requestFocus();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildDistroStatusBar(BuildContext context, TerminalSession session) {
    if (session.distroId != 'alpine') return null;

    final distroProvider = context.watch<DistroProvider?>();
    if (distroProvider == null) return null;
    final status = distroProvider.getStatus('alpine');

    if (status == DistroStatus.installed) return null;

    if (status == DistroStatus.installing) {
      final progress = distroProvider.getProgress('alpine');
      final msg = distroProvider.getStatusMessage('alpine');
      return Container(
        color: const Color(0xFF252526),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    msg.isNotEmpty ? msg : '正在初始化 Alpine 环境...',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              minHeight: 3,
            ),
          ],
        ),
      );
    }

    if (status == DistroStatus.error) {
      return Container(
        color: Colors.red.shade900.withValues(alpha: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                distroProvider.getStatusMessage('alpine').isNotEmpty
                    ? distroProvider.getStatusMessage('alpine')
                    : 'Alpine 初始化失败',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => distroProvider.installDistro('alpine'),
              child: const Text('重试', style: TextStyle(color: Colors.yellowAccent)),
            ),
          ],
        ),
      );
    }

    // notInstalled
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, size: 18, color: Colors.lightBlueAccent),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alpine Linux 尚未就绪',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  '内置极速解压包 (~3.9MB)，点击立即初始化即可运行',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              distroProvider.installDistro('alpine');
            },
            child: const Text('一键初始化'),
          ),
        ],
      ),
    );
  }
}
