import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/widgets/terminal_session_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 终端右侧抽屉（会话列表与管理）
class TerminalDrawer extends StatelessWidget {
  const TerminalDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TerminalProvider>();
    final sessions = provider.sessions;
    final activeIndex = provider.activeIndex;

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 抽屉头部：使用与文件树一致的 primaryContainer 背景色并沉浸延伸至顶部状态栏
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 4.0, bottom: 4.0),
                child: Row(
                  children: [
                    Text(
                      '会话',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: '添加终端',
                      onPressed: () {
                        // 直接添加终端，但不跳转
                        provider.createSession(name: '会话', distroId: 'alpine', activate: false);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
            // 终端项目列表
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Text(
                        '暂无会话，请点击右上角添加',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13.0,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      itemCount: sessions.length,
                      onReorderItem: (oldIndex, newIndex) {
                        provider.reorderSessions(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return TerminalSessionItemWidget(
                          key: ValueKey(session.id),
                          session: session,
                          index: index,
                          isSelected: index == activeIndex,
                        );
                      },
                    ),
            ),
          ],
        ),
    );
  }
}
