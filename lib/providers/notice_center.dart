import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notice_item.dart';

/// 通知中心：负责"可见槽位 + 等待队列"的调度与状态流转。
///
/// 设计要点（业务无关，可被任意后台任务复用）：
/// * [push] 插入一条通知：可视槽位未满立即展示，否则进入队列；
/// * [dismiss] 关闭一条：先标记为"正在移除"（让 UI 播放退场动画），
///   动画结束回调 [finalizeDismiss] 真正移除，并**自动把队列首条补位弹出**；
/// * [complete] 标记完成：成功类可带 [NoticeItem.autoCloseAfter] 延时自动关闭；
///   失败类 [NoticeItem.sticky] 不自动关闭，避免失败被静默吞掉。
///
/// 注意：本类只持有纯数据，不含 Widget、不含任何用户可见字符串。
class NoticeCenter extends ChangeNotifier {
  NoticeCenter({this.visibleLimit = 3});

  /// 同时可见的最大通知条数（其余排队，关闭后自动补位）
  final int visibleLimit;

  final List<NoticeItem> _visible = [];
  final List<NoticeItem> _queued = [];
  final Set<String> _removing = {};
  final Map<String, Timer> _autoCloseTimers = {};

  /// 当前可见通知（索引 0 在最上方，最新插入的在上）
  List<NoticeItem> get visible => List.unmodifiable(_visible);

  /// 等待补位的通知（先进先出）
  List<NoticeItem> get queued => List.unmodifiable(_queued);

  /// 正在播放退场动画的通知 id
  Set<String> get removingIds => Set.unmodifiable(_removing);

  bool get isEmpty => _visible.isEmpty && _queued.isEmpty;

  /// 插入一条通知；返回其 id
  String push(NoticeItem item) {
    // 同 id 重复插入：视为就地更新，避免出现两张同源卡片
    if (_indexOf(item.id) != -1) {
      update(
        item.id,
        kind: item.kind,
        text: item.text,
        progress: item.progress,
      );
      return item.id;
    }

    if (_visible.length < visibleLimit) {
      _visible.insert(0, item);
    } else {
      _queued.add(item);
    }
    notifyListeners();
    return item.id;
  }

  /// 就地更新（不改变位置、不重播插入动画）
  void update(
    String id, {
    NoticeKind? kind,
    NoticeText? text,
    double? progress,
    bool clearProgress = false,
  }) {
    final idx = _indexOf(id);
    if (idx == -1) return;
    final isVisible = idx < _visible.length;
    final list = isVisible ? _visible : _queued;
    final i = isVisible ? idx : idx - _visible.length;

    final current = list[i];
    final next = current.copyWith(
      kind: kind,
      text: text,
      progress: progress,
      clearProgress: clearProgress,
    );
    if (next == current) return;
    list[i] = next;
    notifyListeners();
  }

  /// 标记某条通知"已完成"（成功可自动关闭；失败请传 sticky 语义的 item）
  void complete(
    String id, {
    required NoticeKind kind,
    NoticeText? text,
    Duration? autoCloseAfter,
    bool sticky = false,
    bool? confirmBeforeDismiss,
    bool clearProgress = true,
  }) {
    final idx = _indexOf(id);
    if (idx == -1) return;
    final isVisible = idx < _visible.length;
    final list = isVisible ? _visible : _queued;
    final i = isVisible ? idx : idx - _visible.length;

    list[i] = list[i].copyWith(
      kind: kind,
      text: text,
      sticky: sticky,
      autoCloseAfter: autoCloseAfter,
      confirmBeforeDismiss: confirmBeforeDismiss,
      clearProgress: clearProgress,
    );
    notifyListeners();

    _autoCloseTimers.remove(id)?.cancel();
    if (!sticky && autoCloseAfter != null && isVisible) {
      _autoCloseTimers[id] = Timer(autoCloseAfter, () => dismiss(id));
    }
  }

  /// 请求关闭：可见条目先播放退场动画（由 UI 在动画结束后调用 [finalizeDismiss]）；
  /// 仍在队列中的条目直接移除，并补位。
  void dismiss(String id) {
    _autoCloseTimers.remove(id)?.cancel();

    if (_removing.contains(id)) return;

    final qIdx = _queued.indexWhere((e) => e.id == id);
    if (qIdx != -1) {
      _queued.removeAt(qIdx);
      _promoteFromQueue();
      notifyListeners();
      return;
    }

    if (_visible.any((e) => e.id == id)) {
      _removing.add(id);
      notifyListeners();
    }
  }

  /// 退场动画结束回调：真正移除并立即把队列首条补位弹出
  void finalizeDismiss(String id) {
    final removed = _visible.indexWhere((e) => e.id == id);
    _removing.remove(id);
    if (removed != -1) {
      _visible.removeAt(removed);
    }
    _promoteFromQueue();
    notifyListeners();
  }

  /// 关闭全部（同时清理队列与所有自动关闭定时器）
  void dismissAll() {
    for (final timer in _autoCloseTimers.values) {
      timer.cancel();
    }
    _autoCloseTimers.clear();
    _removing.clear();
    _visible.clear();
    _queued.clear();
    notifyListeners();
  }

  void _promoteFromQueue() {
    while (_visible.length < visibleLimit && _queued.isNotEmpty) {
      _visible.add(_queued.removeAt(0));
    }
  }

  /// 返回 id 在 [_visible] ++ [_queued] 中的线性索引，找不到返回 -1
  int _indexOf(String id) {
    final v = _visible.indexWhere((e) => e.id == id);
    if (v != -1) return v;
    final q = _queued.indexWhere((e) => e.id == id);
    if (q != -1) return _visible.length + q;
    return -1;
  }

  @override
  void dispose() {
    for (final timer in _autoCloseTimers.values) {
      timer.cancel();
    }
    _autoCloseTimers.clear();
    super.dispose();
  }
}
