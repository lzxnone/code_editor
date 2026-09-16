import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/notice_item.dart';
import '../providers/notice_center.dart';
import '../utils/notice_text_resolver.dart';

/// 通用「通知堆叠宿主」控件。
///
/// 把 [NoticeCenter] 里的可见通知渲染成一列卡片：
/// * 每条卡片**带动画插入**（尺寸 + 淡入 + 从右侧滑入）；
/// * 支持同时插入多条（受 [NoticeCenter.visibleLimit] 限制，超出进入队列并显示折叠提示）；
/// * 任一卡片关闭时播放退场动画，动画结束后队列首条**自动弹出补位**，
///   并且下方卡片因外层 [SizeTransition] 而平滑上移。
///
/// 控件本身不关心业务：文案由 [resolveNoticeDisplay] 依据 l10n 解析，禁止硬编码。
class NoticeHost extends StatelessWidget {
  final NoticeCenter center;

  /// 停靠位置（默认编辑区右上角）
  final AlignmentGeometry alignment;

  final EdgeInsets margin;

  /// 单张卡片最大宽度（窄屏自适应）
  final double maxWidth;

  final Duration insertDuration;
  final Duration removeDuration;

  /// 破坏性通知（[NoticeItem.confirmBeforeDismiss]）关闭前的二次确认；
  /// 返回 false 表示用户放弃关闭（卡片保留，附带动作不执行）。
  final Future<bool> Function(BuildContext context)? confirmDismissBuilder;

  const NoticeHost({
    super.key,
    required this.center,
    this.alignment = Alignment.topRight,
    this.margin = const EdgeInsets.only(top: 12, right: 12),
    this.maxWidth = 300,
    this.insertDuration = const Duration(milliseconds: 220),
    this.removeDuration = const Duration(milliseconds: 180),
    this.confirmDismissBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: center,
      builder: (context, _) {
        final visible = center.visible;
        final queuedCount = center.queued.length;
        if (visible.isEmpty && queuedCount == 0) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context);
        return Align(
          alignment: alignment,
          child: Padding(
            padding: margin,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in visible)
                  _NoticeEntry(
                    key: ValueKey<String>(item.id),
                    item: item,
                    removing: center.removingIds.contains(item.id),
                    maxWidth: maxWidth,
                    insertDuration: insertDuration,
                    removeDuration: removeDuration,
                    onDismiss: () async {
                      // 破坏性操作：先二次确认；用户放弃则卡片保留、附加动作不执行
                      if (item.confirmBeforeDismiss && confirmDismissBuilder != null) {
                        final confirmed = await confirmDismissBuilder!(context);
                        if (!confirmed) return;
                      }
                      // 用户点 × ：先执行附加动作（如取消正在进行的探测），再移除卡片
                      item.onUserDismiss?.call();
                      center.dismiss(item.id);
                    },
                    onRemoved: () => center.finalizeDismiss(item.id),
                  ),
                if (queuedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _QueueBadge(
                      label: l10n?.noticeQueueMore(queuedCount) ?? '+$queuedCount',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 单条通知：负责自身的插入/退场动画
class _NoticeEntry extends StatefulWidget {
  final NoticeItem item;
  final bool removing;
  final double maxWidth;
  final Duration insertDuration;
  final Duration removeDuration;
  final VoidCallback onDismiss;
  final VoidCallback onRemoved;

  const _NoticeEntry({
    super.key,
    required this.item,
    required this.removing,
    required this.maxWidth,
    required this.insertDuration,
    required this.removeDuration,
    required this.onDismiss,
    required this.onRemoved,
  });

  @override
  State<_NoticeEntry> createState() => _NoticeEntryState();
}

class _NoticeEntryState extends State<_NoticeEntry> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.insertDuration,
    reverseDuration: widget.removeDuration,
  );

  bool _removalNotified = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    if (widget.removing) {
      _playRemoval();
    }
  }

  @override
  void didUpdateWidget(_NoticeEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.removing && !oldWidget.removing) {
      _playRemoval();
    }
  }

  void _playRemoval() {
    if (_removalNotified) return;
    _controller.reverse().whenComplete(() {
      if (!mounted || _removalNotified) return;
      _removalNotified = true;
      widget.onRemoved();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topRight,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.18, 0),
            end: Offset.zero,
          ).animate(curved),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _NoticeCard(
              item: widget.item,
              maxWidth: widget.maxWidth,
              onDismiss: widget.onDismiss,
            ),
          ),
        ),
      ),
    );
  }
}

/// 单张通知卡片外观（与编辑器内"缩放字号胶囊"同一视觉语言）
class _NoticeCard extends StatelessWidget {
  final NoticeItem item;
  final double maxWidth;
  final VoidCallback onDismiss;

  const _NoticeCard({
    required this.item,
    required this.maxWidth,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final display = l10n != null
        ? resolveNoticeDisplay(l10n, item.text)
        : NoticeDisplay(title: item.text.runtimeType.toString());

    final isSuccess = item.kind == NoticeKind.success;
    final isFailure = item.kind == NoticeKind.failure;

    final (Color accent, Widget leading) = switch (item.kind) {
      NoticeKind.progress => (
          theme.colorScheme.primary,
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: item.progress,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      NoticeKind.success => (
          Colors.white,
          const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
        ),
      NoticeKind.failure => (
          theme.colorScheme.error,
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
        ),
      NoticeKind.info => (
          theme.colorScheme.primary,
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
        ),
    };

    final cardBgColor = isSuccess
        ? (theme.brightness == Brightness.dark
            ? const Color(0xFF1E5E2F)
            : const Color(0xFF2E7D32))
        : theme.colorScheme.surfaceContainerHighest;

    final cardBorder = isFailure
        ? const BorderSide(color: Color(0xFFE53935), width: 1.5)
        : isSuccess
            ? BorderSide(color: Colors.green.shade400.withValues(alpha: 0.6), width: 1)
            : BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45), width: 1);

    final titleColor = isSuccess ? Colors.white : theme.colorScheme.onSurface;
    final subtitleColor = isSuccess ? Colors.white70 : theme.colorScheme.onSurfaceVariant;
    final closeIconColor = isSuccess ? Colors.white70 : theme.colorScheme.onSurfaceVariant;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black38,
        color: cardBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: cardBorder,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      display.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (display.subtitle != null && display.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        display.subtitle!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                tooltip: l10n?.probeBannerClose,
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: closeIconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 队列折叠提示（还能看到"还有 N 项进行中"）
class _QueueBadge extends StatelessWidget {
  final String label;

  const _QueueBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
