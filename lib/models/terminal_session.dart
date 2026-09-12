import 'package:flutter/material.dart';

/// 单个终端会话的数据与状态模型
class TerminalSession {
  final String id;
  String name;
  final String distroId;
  final DateTime createdAt;
  final List<String> outputLines;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final FocusNode focusNode;

  TerminalSession({
    required this.id,
    this.name = '会话',
    this.distroId = 'alpine',
    DateTime? createdAt,
    List<String>? initialOutput,
  })  : createdAt = createdAt ?? DateTime.now(),
        outputLines = initialOutput ?? <String>[],
        inputController = TextEditingController(),
        scrollController = ScrollController(),
        focusNode = FocusNode();

  /// 向终端输出追加内容
  void appendOutput(String line) {
    outputLines.add(line);
    _autoScrollToBottom();
  }

  /// 自动滚动到终端最底部
  void _autoScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 清屏
  void clear() {
    outputLines.clear();
  }

  /// 释放资源
  void dispose() {
    inputController.dispose();
    scrollController.dispose();
    focusNode.dispose();
  }
}
