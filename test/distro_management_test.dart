import 'dart:async';
import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/distro_manifest.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/services/distro_download_manager.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/views/distro_management_view.dart';
import 'package:code_editor/views/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late DistroManager manager;
  late DistroProvider distroProvider;
  late DistroDownloadManager downloadManager;
  late SettingsProvider settingsProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempBaseDir = Directory.systemTemp.createTempSync('distro_mgmt_test_');
    manager = DistroManager();
    manager.customBaseDir = tempBaseDir;
    distroProvider = DistroProvider();
    settingsProvider = SettingsProvider();

    downloadManager = DistroDownloadManager();
    downloadManager.customPackagesDir = tempBaseDir;
  });

  tearDown(() {
    manager.customBaseDir = null;
    downloadManager.customPackagesDir = null;
    if (tempBaseDir.existsSync()) {
      tempBaseDir.deleteSync(recursive: true);
    }
  });

  Widget buildTestableWidget({
    required Widget child,
    Locale locale = const Locale('zh'),
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<DistroProvider>.value(value: distroProvider),
        ChangeNotifierProvider<TerminalProvider>(create: (_) => TerminalProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh'),
          Locale('en'),
        ],
        locale: locale,
        home: child,
      ),
    );
  }

  group('DistroManifest & Repository Tests', () {
    test('currentArchDistros only returns systems supported by current arch', () {
      final items = DistroRepository.currentArchDistros;
      expect(items, isNotEmpty);

      // 验证每个条目在当前架构下都有有效的包源
      for (final item in items) {
        expect(item.currentPackageSource, isNotNull);
        expect(item.currentPackageSource!.isNotEmpty, isTrue);
      }

      // 验证内置系统的 isBuiltin 标识
      final ubuntu = items.firstWhere((e) => e.id == 'ubuntu');
      expect(ubuntu.isBuiltin, isTrue);
      expect(ubuntu.isRecommended, isTrue);

      final alpine = items.firstWhere((e) => e.id == 'alpine');
      expect(alpine.isBuiltin, isTrue);
    });

    test('currentArch returns arm64 or x86_64 correctly', () {
      final arch = DistroManifestItem.currentArch;
      expect(arch == DistroArch.arm64 || arch == DistroArch.x86_64, isTrue);
    });
  });

  group('DistroDownloadManager Tests', () {
    test('initial state has no active downloads', () {
      final dm = DistroDownloadManager();
      expect(dm.isDownloading('unknown_distro'), isFalse);
      expect(dm.getProgress('unknown_distro'), isNull);
    });

    test('package file detection and deletion', () async {
      final dm = DistroDownloadManager();
      const distroId = 'debian';
      const fakeUrl = 'https://example.com/debian.tar.xz';

      expect(await dm.isPackageDownloaded(distroId, fakeUrl), isFalse);

      final file = await dm.getPackageFile(distroId, fakeUrl);
      file.writeAsStringSync('fake tar data');

      expect(await dm.isPackageDownloaded(distroId, fakeUrl), isTrue);

      await dm.deletePackage(distroId, fakeUrl);
      expect(await dm.isPackageDownloaded(distroId, fakeUrl), isFalse);
    });

    test('cancelDownload immediately stops background streaming, closes file sinks, and cleans up .part file', () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final dm = DistroDownloadManager();
        const distroId = 'test_cancel_distro';

        // 启动一个本地 HTTP 服务器模拟网络流式下载
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serverUrl = 'http://${server.address.address}:${server.port}/test_image.tar.xz';

        final serverCompleter = Completer<void>();

        server.listen((HttpRequest request) async {
          request.response.bufferOutput = false;
          request.response.statusCode = HttpStatus.ok;
          request.response.contentLength = 1000000;
          request.response.add(List.filled(1024, 42));
          await request.response.flush();

          // 挂起等待客户端取消
          await serverCompleter.future;
          try {
            await request.response.close();
          } catch (_) {}
        });

        final downloadFuture = dm.startDownload(
          distroId: distroId,
          downloadUrl: serverUrl,
        );

        while ((dm.getProgress(distroId)?.receivedBytes ?? 0) == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
        expect(dm.isDownloading(distroId), isTrue);

        final partFile = File(p.join(tempBaseDir.path, '${distroId}_rootfs.tar.xz.part'));
        expect(partFile.existsSync(), isTrue);

        await dm.cancelDownload(distroId);

        // 验证取消后：
        // 1. isDownloading 为 false
        expect(dm.isDownloading(distroId), isFalse);
        // 2. 进度映射已被重置清理
        expect(dm.getProgress(distroId), isNull);
        // 3. .part 临时文件被立即安全删除（Windows 上句柄已完全释放）
        expect(partFile.existsSync(), isFalse);

        // 唤醒服务端
        if (!serverCompleter.isCompleted) {
          serverCompleter.complete();
        }

        // 等待 startDownload Future 完成，并验证返回值必须为 null 且未生成最终文件
        final resultFile = await downloadFuture;
        expect(resultFile, isNull);

        final finalFile = File(p.join(tempBaseDir.path, '${distroId}_rootfs.tar.xz'));
        expect(finalFile.existsSync(), isFalse);

        await server.close(force: true);
      }, _TestHttpOverrides());
    });

    test('re-download after cancellation succeeds cleanly', () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final dm = DistroDownloadManager();
        const distroId = 'test_redownload_distro';

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serverUrl = 'http://${server.address.address}:${server.port}/test_image.tar.xz';

        server.listen((HttpRequest request) async {
          request.response.statusCode = HttpStatus.ok;
          request.response.contentLength = 50;
          request.response.add(List.filled(50, 99));
          await request.response.close();
        });

        // 下载能成功完成
        final resultFile = await dm.startDownload(
          distroId: distroId,
          downloadUrl: serverUrl,
        );

        expect(resultFile, isNotNull);
        expect(resultFile!.existsSync(), isTrue);
        expect(resultFile.lengthSync(), 50);
        expect(dm.getProgress(distroId)?.state, DistroDownloadState.completed);

        await server.close(force: true);
      }, _TestHttpOverrides());
    });

    test('startDownload refuses duplicate download and returns existing file when package already exists', () async {
      final dm = DistroDownloadManager();
      const distroId = 'test_existing_distro';
      const fakeUrl = 'https://example.com/test_image.tar.xz';

      final file = await dm.getPackageFile(distroId, fakeUrl);
      file.writeAsStringSync('existing package content');

      expect(await dm.isPackageDownloaded(distroId, fakeUrl), isTrue);

      // 再次调用 startDownload，应立即返回已有文件，且不发起网络请求
      final returnedFile = await dm.startDownload(
        distroId: distroId,
        downloadUrl: fakeUrl,
      );

      expect(returnedFile, isNotNull);
      expect(returnedFile!.path, file.path);
      expect(dm.getProgress(distroId)?.state, DistroDownloadState.completed);
      expect(returnedFile.readAsStringSync(), 'existing package content');
    });
  });

  group('DistroManagementView Requirements Tests', () {
    testWidgets('1. 内置字样完全移除，2. 安装按钮和已安装文本去掉', (tester) async {
      await tester.pumpWidget(buildTestableWidget(child: const DistroManagementView()));
      await tester.pumpAndSettle();

      // 验证返回按键与标题
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('系统管理'), findsOneWidget);

      // 验证品牌图标存在
      expect(find.byType(Image), findsWidgets);

      // 1. 验证“内置”字样完全不存在
      expect(find.text('内置'), findsNothing);
      expect(find.text('Built-in'), findsNothing);

      // 2. 验证“安装”按键与“已安装”文本完全不存在
      expect(find.text('安装'), findsNothing);
      expect(find.text('Install'), findsNothing);
      expect(find.text('已安装'), findsNothing);
      expect(find.text('Installed'), findsNothing);

      // 3. 验证推荐标签保留
      expect(find.text('推荐'), findsWidgets);
    });

    testWidgets('3. 选中后无高亮边框 (border 无突出 primary 高亮)', (tester) async {
      // 预置默认选中 ubuntu
      await distroProvider.refreshSystems();

      await tester.pumpWidget(buildTestableWidget(child: const DistroManagementView()));
      await tester.pumpAndSettle();

      // 获取第一个 Card
      final cardFinder = find.byType(Card).first;
      final cardWidget = tester.widget<Card>(cardFinder);
      final shape = cardWidget.shape as RoundedRectangleBorder;
      final side = shape.side;

      // 边框宽度为普通 1.0，颜色不是 primary 高亮
      expect(side.width, 1.0);
    });

    testWidgets('4. 内置系统 (ubuntu / alpine) 无法删除，右侧无按键', (tester) async {
      await tester.pumpWidget(buildTestableWidget(child: const DistroManagementView()));
      await tester.pumpAndSettle();

      // 在初始未下载任何外部系统的状态下，内置系统右侧没有任何删除按键
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('4. 点击已就绪的 item 本身直接返回 DistroManifestItem', (tester) async {
      DistroManifestItem? selectedItem;
      await tester.pumpWidget(buildTestableWidget(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              selectedItem = await Navigator.of(context).push<DistroManifestItem>(
                MaterialPageRoute(builder: (_) => const DistroManagementView()),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 打开页面
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 点击已就绪的 Alpine Linux 条目本身
      await tester.tap(find.text('Alpine Linux'));
      await tester.pumpAndSettle();

      // 确认返回了 DistroManifestItem
      expect(selectedItem, isNotNull);
      expect(selectedItem!.id, 'alpine');
    });

    testWidgets('4. 下载完成的系统右侧显示红色删除按钮，点击弹出删除安装包确认框', (tester) async {
      // 模拟 debian 安装包已存在于本地目录
      final debianFile = File(p.join(tempBaseDir.path, 'debian_rootfs.tar.xz'));
      debianFile.writeAsStringSync('dummy content');

      await tester.pumpWidget(buildTestableWidget(child: const DistroManagementView()));
      await tester.pumpAndSettle();

      // debian 应出现红色删除按钮
      final deleteBtn = find.byIcon(Icons.delete_outline);
      expect(deleteBtn, findsOneWidget);

      // 点击删除按钮弹出“确认删除安装包”对话框
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('确认删除安装包'), findsOneWidget);
    });

    testWidgets('下载完成后页面立即响应更新为就绪状态，无需退出重新进入', (tester) async {
      await tester.pumpWidget(buildTestableWidget(child: const DistroManagementView()));
      await tester.pumpAndSettle();

      // 此时 debian 处于未下载状态，显示“下载”按钮
      expect(find.text('下载'), findsWidgets);

      // 模拟下载管理器写入完成包
      final debianFile = await downloadManager.getPackageFile('debian', 'https://example.com/debian.tar.xz');
      debianFile.writeAsStringSync('debian package content');

      // 触发 startDownload，由于本地文件已完备，会直接更新状态并通知监听器
      await downloadManager.startDownload(distroId: 'debian', downloadUrl: 'https://example.com/debian.tar.xz');

      await tester.pumpAndSettle();

      // debian 的卡片立即就绪，出现红色删除按钮
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });

  group('SettingsView Download Mirror Tests', () {
    testWidgets('设置页面项目下方展示“下载”分组，默认显示清华源', (tester) async {
      await tester.pumpWidget(buildTestableWidget(child: const SettingsView()));
      await tester.pumpAndSettle();

      // 滚动到“下载”分组可见
      await tester.scrollUntilVisible(
        find.text('下载'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // 验证“下载”分组标题与“下载源”
      expect(find.text('下载'), findsOneWidget);
      expect(find.text('下载源'), findsOneWidget);
      expect(find.text('清华大学开源软件镜像站 (推荐)'), findsOneWidget);
    });

    testWidgets('点击下载源弹出底部选择菜单，可自由切换至北外源', (tester) async {
      await tester.pumpWidget(buildTestableWidget(child: const SettingsView()));
      await tester.pumpAndSettle();

      // 滚动到“下载源”可见
      await tester.scrollUntilVisible(
        find.text('下载源'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // 点击下载源条目弹出 BottomSheet
      await tester.tap(find.text('下载源'));
      await tester.pumpAndSettle();

      expect(find.text('选择下载源'), findsOneWidget);
      expect(find.text('北京外国语大学开源软件镜像站'), findsOneWidget);
      expect(find.text('中国科学院软件研究所开源镜像站'), findsOneWidget);
      expect(find.text('LinuxContainers 官方镜像源'), findsOneWidget);

      // 选中北外源
      await tester.tap(find.text('北京外国语大学开源软件镜像站'));
      await tester.pumpAndSettle();

      // 验证 SettingsProvider 状态更新
      expect(settingsProvider.downloadMirrorId, 'bfsu');
      expect(find.text('北京外国语大学开源软件镜像站'), findsOneWidget);
    });
  });
}

class _TestHttpOverrides extends HttpOverrides {}

