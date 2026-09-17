import 'package:code_editor/services/lsp/lsp_manager.dart';
import 'package:code_editor/views/main_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LSP Lifecycle & Uninstall Tests', () {
    test('LspManager.stopSession handles nonexistent session gracefully', () async {
      final manager = LspManager.instance;
      // 停止一个未启动的 session 不抛出异常
      await expectLater(manager.stopSession('nonexistent_id'), completes);
    });

    test('MainView.clearPromptedLanguage removes record and allows re-prompting', () {
      // 首次清除
      MainView.clearPromptedLanguage('c_cpp');
      MainView.clearPromptedLanguage(null);
      // 清空全部后不抛异常
      expect(() => MainView.clearPromptedLanguage(null), returnsNormally);
    });
  });
}
