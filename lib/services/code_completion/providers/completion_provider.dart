import 'dart:async';
import '../core/completion_types.dart';

/// 补全数据源提供者抽象契约
abstract class CompletionProvider {
  /// 提供者唯一标识
  String get id;

  /// 是否为异步远程数据源（如 LSP）
  bool get isAsync => false;

  /// 依据上下文提供补全候选项
  FutureOr<List<SmartPrompt>> provideCompletions(CompletionContext context);

  /// 释放资源
  void dispose() {}
}
