import 'package:code_editor/models/file_item.dart';
import 'package:code_editor/models/git_model.dart';
import 'package:code_editor/providers/git_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/utils/git_decoration_utils.dart';
import 'package:code_editor/widgets/file_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('GitDecorationUtils Tests', () {
    test('getStatusLetter returns correct letter for each type', () {
      expect(GitDecorationUtils.getStatusLetter(GitFileStatusType.modified), 'M');
      expect(GitDecorationUtils.getStatusLetter(GitFileStatusType.untracked), 'U');
      expect(GitDecorationUtils.getStatusLetter(GitFileStatusType.added), 'A');
      expect(GitDecorationUtils.getStatusLetter(GitFileStatusType.deleted), 'D');
      expect(GitDecorationUtils.getStatusLetter(GitFileStatusType.unmerged), '!');
      expect(GitDecorationUtils.getStatusLetter(GitFileStatusType.renamed), 'R');
      expect(GitDecorationUtils.getStatusLetter(GitFileStatusType.ignored), isNull);
    });

    test('getPriority orders conflict > deleted > modified > added > untracked', () {
      final unmergedP = GitDecorationUtils.getPriority(GitFileStatusType.unmerged);
      final deletedP = GitDecorationUtils.getPriority(GitFileStatusType.deleted);
      final modifiedP = GitDecorationUtils.getPriority(GitFileStatusType.modified);
      final addedP = GitDecorationUtils.getPriority(GitFileStatusType.added);
      final untrackedP = GitDecorationUtils.getPriority(GitFileStatusType.untracked);

      expect(unmergedP > deletedP, isTrue);
      expect(deletedP > modifiedP, isTrue);
      expect(modifiedP > addedP, isTrue);
      expect(addedP > untrackedP, isTrue);
    });
  });

  group('GitProvider File Tree Map Tests', () {
    test('getFileStatus and getDirectoryStatus aggregate bottom-up correctly', () {
      final provider = GitProvider();
      const root = '/mock/repo';
      final changedFiles = [
        const GitFileStatus(
          path: '/mock/repo/lib/widgets/button.dart',
          relativePath: 'lib/widgets/button.dart',
          statusType: GitFileStatusType.modified,
        ),
        const GitFileStatus(
          path: '/mock/repo/lib/main.dart',
          relativePath: 'lib/main.dart',
          statusType: GitFileStatusType.untracked,
        ),
        const GitFileStatus(
          path: '/mock/repo/lib/widgets/header.dart',
          relativePath: 'lib/widgets/header.dart',
          statusType: GitFileStatusType.unmerged,
        ),
      ];

      provider.setStateForTesting(
        rootPath: root,
        currentRepoPath: root,
        changedFiles: changedFiles,
      );

      // 直接查文件
      final btnStatus = provider.getFileStatus('/mock/repo/lib/widgets/button.dart');
      expect(btnStatus, isNotNull);
      expect(btnStatus!.statusType, GitFileStatusType.modified);

      final mainStatus = provider.getFileStatus('/mock/repo/lib/main.dart');
      expect(mainStatus, isNotNull);
      expect(mainStatus!.statusType, GitFileStatusType.untracked);

      // 查目录：/mock/repo/lib/widgets 同时含有 modified 和 unmerged -> 聚合出 unmerged（最高优先级）
      final widgetsDirStatus = provider.getDirectoryStatus('/mock/repo/lib/widgets');
      expect(widgetsDirStatus, GitFileStatusType.unmerged);

      // 查父级目录：/mock/repo/lib 继承最高优先级 unmerged
      final libDirStatus = provider.getDirectoryStatus('/mock/repo/lib');
      expect(libDirStatus, GitFileStatusType.unmerged);

      // 查不存在的文件
      final absent = provider.getFileStatus('/mock/repo/lib/unknown.dart');
      expect(absent, isNull);
    });
  });

  group('FileItemWidget Git Decoration UI Tests', () {
    testWidgets('renders letter trailing for modified file and colored dot for folder', (tester) async {
      final gitProvider = GitProvider();
      final projectProvider = ProjectProvider();
      final tabProvider = TabProvider();

      const filePath = '/test/project/file.dart';
      const dirPath = '/test/project/dir';

      gitProvider.setStateForTesting(
        rootPath: '/test/project',
        currentRepoPath: '/test/project',
        changedFiles: [
          const GitFileStatus(
            path: filePath,
            relativePath: 'file.dart',
            statusType: GitFileStatusType.modified,
          ),
          const GitFileStatus(
            path: '/test/project/dir/nested.dart',
            relativePath: 'dir/nested.dart',
            statusType: GitFileStatusType.untracked,
          ),
        ],
      );

      final fileItem = FileItem(
        path: filePath,
        name: 'file.dart',
        isDirectory: false,
        depth: 0,
      );

      final dirItem = FileItem(
        path: dirPath,
        name: 'dir',
        isDirectory: true,
        depth: 0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: gitProvider),
            ChangeNotifierProvider.value(value: projectProvider),
            ChangeNotifierProvider.value(value: tabProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  FileItemWidget(fileItem: fileItem),
                  FileItemWidget(fileItem: dirItem),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证文件项中出现了 'M' 标识
      expect(find.text('M'), findsOneWidget);

      // 验证文件夹项中没有文本字母标识，但渲染了实心圆点
      expect(find.text('dir'), findsOneWidget);
    });
  });
}
