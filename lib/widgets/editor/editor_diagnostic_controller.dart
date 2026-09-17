import 'dart:math';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import '../../l10n/app_localizations.dart';
import '../../services/lsp/lsp_diagnostics_store.dart';
import '../../services/lsp/lsp_protocol.dart';
import '../lsp_quick_fix_dialog.dart';

class _DiagnosticInterval {
  final int start;
  final int end;
  final Color color;

  const _DiagnosticInterval(this.start, this.end, this.color);
}

class _OffsetTracker {
  int value;
  _OffsetTracker(this.value);
}

/// 编辑器代码诊断视图控制器
///
/// 专职负责：
/// 1. 依据 LSP 与本地语法诊断，计算行内波浪下划线（保持语法高亮颜色）；
/// 2. 构建底部错误与警告横幅，支持一键唤起 LSP 快捷修复。
class EditorDiagnosticController {
  const EditorDiagnosticController();

  /// 依据实时诊断结果，为当前行的代码文本施加波浪下划线（保留已有代码高亮色彩）
  TextSpan buildDiagnosticSpans({
    required BuildContext context,
    required String? filePath,
    required int index,
    required CodeLine codeLine,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    if (filePath == null || codeLine.text.isEmpty) {
      return textSpan;
    }

    final diagnostics = LspDiagnosticsStore.instance.getDiagnosticsForLine(filePath, index);
    if (diagnostics.isEmpty) {
      return textSpan;
    }

    final lineText = codeLine.text;
    final lineLen = lineText.length;

    final intervals = <_DiagnosticInterval>[];
    for (final d in diagnostics) {
      final startLine = d.range.start.line;
      final endLine = d.range.end.line;

      int startCol = 0;
      if (startLine == index) {
        startCol = d.range.start.character;
      } else if (startLine > index) {
        continue;
      }

      int endCol = lineLen;
      if (endLine == index) {
        endCol = d.range.end.character;
      } else if (endLine < index) {
        continue;
      }

      startCol = startCol.clamp(0, lineLen);
      endCol = endCol.clamp(0, lineLen);

      // LSP 有时可能返回单点（0 宽）区间，自动扩宽至至少 1 字符高亮以便视觉可见
      if (startCol == endCol) {
        if (startCol < lineLen) {
          endCol = min(startCol + 1, lineLen);
        } else if (startCol > 0) {
          startCol = startCol - 1;
        }
      }

      if (startCol < endCol) {
        Color diagColor = Colors.redAccent;
        switch (d.severity) {
          case LspDiagnosticSeverity.error:
            diagColor = Colors.redAccent;
            break;
          case LspDiagnosticSeverity.warning:
            diagColor = Colors.amberAccent;
            break;
          case LspDiagnosticSeverity.information:
            diagColor = Colors.lightBlueAccent;
            break;
          case LspDiagnosticSeverity.hint:
            diagColor = Colors.grey;
            break;
        }
        intervals.add(_DiagnosticInterval(startCol, endCol, diagColor));
      }
    }

    if (intervals.isEmpty) {
      return textSpan;
    }

    return _applyDiagnosticIntervals(textSpan, intervals, _OffsetTracker(0), style);
  }

  /// 构建底部单行诊断简报与快捷修复入口横幅
  Widget buildDiagnosticBanner({
    required BuildContext context,
    required String? filePath,
    required CodeLineEditingController? controller,
    required List<LspDiagnostic> diags,
    required int lineIndex,
  }) {
    final first = diags.first;
    final isErr = diags.any((d) => d.severity == LspDiagnosticSeverity.error);
    final color = isErr ? Colors.redAccent : Colors.amber;
    final icon = isErr ? Icons.error_outline : Icons.warning_amber_outlined;
    final l10n = AppLocalizations.of(context);
    final displayText = l10n != null
        ? l10n.diagnosticLinePrefix(lineIndex + 1, first.message)
        : 'Line ${lineIndex + 1}: ${first.message}';
    final fixButtonText = l10n?.quickFixButton ?? 'Fix';

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (filePath != null && controller != null) {
            LspQuickFixDialog.show(
              context,
              filePath: filePath,
              lineIndex: lineIndex,
              diagnostics: diags,
              controller: controller,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb, size: 12, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      fixButtonText,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber),
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

  static TextSpan _applyDiagnosticIntervals(
    TextSpan span,
    List<_DiagnosticInterval> intervals,
    _OffsetTracker tracker,
    TextStyle baseStyle,
  ) {
    final effectiveStyle = span.style ?? baseStyle;

    if (span.children != null && span.children!.isNotEmpty) {
      final newChildren = <InlineSpan>[];
      if (span.text != null && span.text!.isNotEmpty) {
        final leafSpan = TextSpan(text: span.text, style: effectiveStyle);
        newChildren.add(_processLeafTextSpan(leafSpan, intervals, tracker, effectiveStyle));
      }
      for (final child in span.children!) {
        if (child is TextSpan) {
          newChildren.add(_applyDiagnosticIntervals(child, intervals, tracker, effectiveStyle));
        } else {
          newChildren.add(child);
        }
      }
      return TextSpan(children: newChildren, style: span.style);
    }

    return _processLeafTextSpan(span, intervals, tracker, effectiveStyle);
  }

  static TextSpan _processLeafTextSpan(
    TextSpan span,
    List<_DiagnosticInterval> intervals,
    _OffsetTracker tracker,
    TextStyle baseStyle,
  ) {
    final text = span.text;
    if (text == null || text.isEmpty) {
      return span;
    }

    final startOffset = tracker.value;
    final endOffset = startOffset + text.length;
    tracker.value = endOffset;

    final intersecting = intervals.where((it) => it.end > startOffset && it.start < endOffset).toList();
    if (intersecting.isEmpty) {
      return span;
    }

    final splitPoints = <int>{startOffset, endOffset};
    for (final it in intersecting) {
      if (it.start > startOffset && it.start < endOffset) splitPoints.add(it.start);
      if (it.end > startOffset && it.end < endOffset) splitPoints.add(it.end);
    }
    final sortedPoints = splitPoints.toList()..sort();

    final chunks = <InlineSpan>[];
    for (int i = 0; i < sortedPoints.length - 1; i++) {
      final segStart = sortedPoints[i];
      final segEnd = sortedPoints[i + 1];
      if (segStart >= segEnd) continue;

      final chunkText = text.substring(segStart - startOffset, segEnd - startOffset);
      final activeInterval = intersecting.where((it) => it.start <= segStart && it.end >= segEnd).firstOrNull;

      if (activeInterval != null) {
        chunks.add(TextSpan(
          text: chunkText,
          style: (span.style ?? baseStyle).copyWith(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
            decorationColor: activeInterval.color,
          ),
        ));
      } else {
        chunks.add(TextSpan(text: chunkText, style: span.style));
      }
    }

    if (chunks.length == 1 && chunks.first is TextSpan) {
      return chunks.first as TextSpan;
    }
    return TextSpan(children: chunks, style: span.style);
  }
}
