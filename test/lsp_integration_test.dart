import 'package:code_editor/services/lsp/lsp_diagnostics_store.dart';
import 'package:code_editor/services/lsp/lsp_protocol.dart';
import 'package:code_editor/services/lsp/lsp_workspace_edit_applier.dart';
import 'package:code_editor/widgets/editor/editor_lsp_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('LSP 协议与数据模型测试', () {
    test('LspPosition 与 LspRange 范围包含与行交集判断', () {
      const pos1 = LspPosition(line: 2, character: 4);
      const pos2 = LspPosition(line: 2, character: 10);
      const range = LspRange(start: pos1, end: pos2);

      expect(range.contains(2, 4), isTrue);
      expect(range.contains(2, 7), isTrue);
      expect(range.contains(2, 10), isTrue);
      expect(range.contains(2, 3), isFalse);
      expect(range.contains(2, 11), isFalse);
      expect(range.contains(1, 4), isFalse);
      expect(range.contains(3, 4), isFalse);

      expect(range.overlapsLine(2), isTrue);
      expect(range.overlapsLine(1), isFalse);
      expect(range.overlapsLine(3), isFalse);

      const multiLineRange = LspRange(
        start: LspPosition(line: 1, character: 5),
        end: LspPosition(line: 3, character: 2),
      );
      expect(multiLineRange.overlapsLine(1), isTrue);
      expect(multiLineRange.overlapsLine(2), isTrue);
      expect(multiLineRange.overlapsLine(3), isTrue);
      expect(multiLineRange.overlapsLine(0), isFalse);
      expect(multiLineRange.overlapsLine(4), isFalse);
    });

    test('LspDiagnostic 序列化与严重等级解析', () {
      final json = {
        'range': {
          'start': {'line': 5, 'character': 2},
          'end': {'line': 5, 'character': 8},
        },
        'severity': 1,
        'message': "Use of undeclared identifier 'foo'",
        'source': 'clangd',
      };

      final diag = LspDiagnostic.fromJson(json);
      expect(diag.isError, isTrue);
      expect(diag.isWarning, isFalse);
      expect(diag.message, "Use of undeclared identifier 'foo'");
      expect(diag.source, 'clangd');
      expect(diag.range.start.line, 5);
      expect(diag.range.start.character, 2);
    });

    test('LspCompletionItem 解析与文本插入兼容', () {
      final json = {
        'label': 'printf',
        'kind': 3, // Function
        'detail': 'int printf(const char *format, ...)',
        'documentation': 'Formatted output conversion.',
        'insertText': 'printf',
      };

      final item = LspCompletionItem.fromJson(json);
      expect(item.label, 'printf');
      expect(item.effectiveInsertText, 'printf');
      expect(item.detail, contains('int printf'));
      expect(item.documentation, contains('Formatted output'));
    });

    test('LspCodeAction 与 LspWorkspaceEdit 解析', () {
      final json = {
        'title': "Include <stdio.h>",
        'kind': 'quickfix',
        'isPreferred': true,
        'edit': {
          'changes': {
            'file:///workspace/main.c': [
              {
                'range': {
                  'start': {'line': 0, 'character': 0},
                  'end': {'line': 0, 'character': 0},
                },
                'newText': '#include <stdio.h>\n',
              }
            ]
          }
        }
      };

      final action = LspCodeAction.fromJson(json);
      expect(action.title, 'Include <stdio.h>');
      expect(action.isPreferred, isTrue);
      expect(action.edit, isNotNull);
      expect(action.edit!.changes.containsKey('file:///workspace/main.c'), isTrue);
      expect(action.edit!.changes['file:///workspace/main.c']!.first.newText, '#include <stdio.h>\n');
    });
  });

  group('LspDiagnosticsStore 存储与路径统一测试', () {
    final store = LspDiagnosticsStore.instance;

    setUp(() {
      store.clear();
    });

    test('多文件诊断隔离与跨平台路径匹配', () {
      const diag1 = LspDiagnostic(
        range: LspRange(
          start: LspPosition(line: 0, character: 0),
          end: LspPosition(line: 0, character: 5),
        ),
        severity: LspDiagnosticSeverity.error,
        message: 'Syntax error',
      );

      store.updateDiagnostics('D:/Project/src/main.c', [diag1]);

      // 各种变体路径均能精确匹配
      expect(store.getDiagnosticsForFile('d:/Project/src/main.c'), hasLength(1));
      expect(store.getDiagnosticsForFile('file:///D:/Project/src/main.c'), hasLength(1));
      expect(store.getDiagnosticsForFile(r'D:\Project\src\main.c'), hasLength(1));
      expect(store.getDiagnosticsForFile('D:/Project/src/other.c'), isEmpty);

      final line0Diags = store.getDiagnosticsForLine('D:/Project/src/main.c', 0);
      expect(line0Diags, hasLength(1));
      expect(line0Diags.first.message, 'Syntax error');

      final line1Diags = store.getDiagnosticsForLine('D:/Project/src/main.c', 1);
      expect(line1Diags, isEmpty);
    });

    test('getDiagnosticAt 精准定位与就近容错', () {
      const diag = LspDiagnostic(
        range: LspRange(
          start: LspPosition(line: 3, character: 5),
          end: LspPosition(line: 3, character: 10),
        ),
        severity: LspDiagnosticSeverity.warning,
        message: 'Unused variable',
      );

      store.updateDiagnostics('/workspace/test.c', [diag]);

      // 精准命中区间 [5, 10]
      expect(store.getDiagnosticAt('/workspace/test.c', 3, 6)?.message, 'Unused variable');
      // 同行就近返回
      expect(store.getDiagnosticAt('/workspace/test.c', 3, 2)?.message, 'Unused variable');
      // 不同行返回 null
      expect(store.getDiagnosticAt('/workspace/test.c', 4, 6), isNull);
    });
  });

  group('LspWorkspaceEditApplier 逆向安全应用测试', () {
    test('单行局部替换', () {
      final controller = CodeLineEditingController.fromText(
        'int main() {\n  int val = foo();\n  return 0;\n}',
      );

      final edit = LspWorkspaceEdit(
        changes: {
          'file:///src/main.c': [
            const LspTextEdit(
              range: LspRange(
                start: LspPosition(line: 1, character: 12),
                end: LspPosition(line: 1, character: 15),
              ),
              newText: 'bar',
            ),
          ],
        },
      );

      LspWorkspaceEditApplier.applyWorkspaceEdit(controller, edit, currentFilePath: '/src/main.c');
      expect(controller.codeLines[1].text, '  int val = bar();');
    });

    test('同一行多处编辑自动逆序应用，不破坏列号偏移', () {
      final controller = CodeLineEditingController.fromText(
        'AAA BBB CCC',
      );

      // 顺序为正向传入：先改 AAA 为 12345，再改 CCC 为 9
      final edits = [
        const LspTextEdit(
          range: LspRange(
            start: LspPosition(line: 0, character: 0),
            end: LspPosition(line: 0, character: 3),
          ),
          newText: '12345',
        ),
        const LspTextEdit(
          range: LspRange(
            start: LspPosition(line: 0, character: 8),
            end: LspPosition(line: 0, character: 11),
          ),
          newText: '9',
        ),
      ];

      LspWorkspaceEditApplier.applyTextEdits(controller, edits);
      // CCC 变成了 9，AAA 变成了 12345，中间 BBB 完整无损
      expect(controller.codeLines[0].text, '12345 BBB 9');
    });

    test('跨行插入与头部插入', () {
      final controller = CodeLineEditingController.fromText(
        'int x = 1;\nint y = 2;',
      );

      final edit = LspWorkspaceEdit(
        changes: {
          'file:///test.c': [
            const LspTextEdit(
              range: LspRange(
                start: LspPosition(line: 0, character: 0),
                end: LspPosition(line: 0, character: 0),
              ),
              newText: '// header\n',
            ),
          ],
        },
      );

      LspWorkspaceEditApplier.applyWorkspaceEdit(controller, edit, currentFilePath: 'test.c');
      expect(controller.codeLines[0].text, '// header');
      expect(controller.codeLines[1].text, 'int x = 1;');
      expect(controller.codeLines[2].text, 'int y = 2;');
    });
  });

  group('CodeLineSpanBuilder 波浪下划线扩展测试', () {
    testWidgets('控制器支持注入 spanBuilder 并不破坏基础文本', (tester) async {
      late BuildContext testContext;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (ctx) {
              testContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      bool spanBuilderCalled = false;
      final controller = CodeLineEditingController.fromText(
        'int a = 10;\nfloat b = 20.0;',
        const CodeLineOptions(),
        ({
          required BuildContext context,
          required int index,
          required CodeLine codeLine,
          required TextSpan textSpan,
          required TextStyle style,
        }) {
          spanBuilderCalled = true;
          return TextSpan(
            text: codeLine.text,
            style: style.copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: Colors.redAccent,
            ),
          );
        },
      );

      expect(controller.codeLines.length, 2);
      expect(controller.codeLines[0].text, 'int a = 10;');
      expect(controller.codeLines[1].text, 'float b = 20.0;');

      final span = controller.buildTextSpan(
        context: testContext,
        index: 0,
        textSpan: const TextSpan(text: 'int a = 10;'),
        style: const TextStyle(),
      );
      expect(spanBuilderCalled, isTrue);
      expect(span.style?.decoration, equals(TextDecoration.underline));
    });
  });

  group('EditorLspCoordinator 纯 LSP 协调与诊断生命周期测试', () {
    test('无 LSP 服务时打开或修改文件绝不注入任何本地伪诊断', () {
      const coordinator = EditorLspCoordinator();
      const testPath = '/test/unsupported/main.fake';
      final codeLines = CodeLines.fromText('int a = 10\nprintf("ok");');

      // 确保初始状态干净
      LspDiagnosticsStore.instance.removeForFile(testPath);
      expect(LspDiagnosticsStore.instance.getDiagnosticsForFile(testPath), isEmpty);

      // 打开文件
      coordinator.onFileOpened(testPath, 'int a = 10\nprintf("ok");', codeLines);
      expect(LspDiagnosticsStore.instance.getDiagnosticsForFile(testPath), isEmpty);

      // 修改文件
      coordinator.onFileChanged(testPath, 'int a = 10', codeLines);
      expect(LspDiagnosticsStore.instance.getDiagnosticsForFile(testPath), isEmpty);
    });

    test('文件关闭时自动清理该文件的 LSP 诊断', () {
      const coordinator = EditorLspCoordinator();
      const testPath = '/test/project/main.c';

      // 模拟 LSP 写入了诊断
      LspDiagnosticsStore.instance.updateDiagnostics(testPath, const [
        LspDiagnostic(
          range: LspRange(
            start: LspPosition(line: 0, character: 0),
            end: LspPosition(line: 0, character: 5),
          ),
          message: 'LSP compile error',
        ),
      ]);
      expect(LspDiagnosticsStore.instance.getDiagnosticsForFile(testPath), isNotEmpty);

      // 关闭文件
      coordinator.onFileClosed(testPath);
      expect(LspDiagnosticsStore.instance.getDiagnosticsForFile(testPath), isEmpty);
    });
  });
}
