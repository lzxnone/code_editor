import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:code_editor/widgets/terminal_session_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 终端右侧抽屉（会话列表与管理）
class TerminalDrawer extends StatelessWidget {
  const TerminalDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
                    Expanded(
                      child: Text(
                        l10n.sessionDrawerTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addSession),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                      onPressed: () {
                        final distroProvider = context.read<DistroProvider?>();
                        final currentSystem = distroProvider?.selectedSystem;
                        if (currentSystem == null) {
                          DialogUtils.showToast(context, l10n.noSystemSelectedWarning);
                          return;
                        }
                        // 基于当前选择的系统创建新终端
                        provider.createSession(
                          name: l10n.sessionDefaultName,
                          distroId: currentSystem,
                          activate: false,
                        );
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
                        l10n.noSessionsInDrawerPrompt,
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
