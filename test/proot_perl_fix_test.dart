import 'dart:io';
import 'package:code_editor/services/distro_installer.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late Directory tempRootDir;

  setUp(() {
    tempBaseDir = Directory.systemTemp.createTempSync('proot_perl_fix_test_');
    tempRootDir = Directory(p.join(tempBaseDir.path, 'debian', 'rootfs'))..createSync(recursive: true);
  });

  tearDown(() {
    if (tempBaseDir.existsSync()) {
      tempBaseDir.deleteSync(recursive: true);
    }
  });

  group('PRoot Perl Fix Tests', () {
    test('ensureDpkgConfiguration creates /etc/dpkg/dpkg.cfg.d/01_proot with force-unsafe-io', () async {
      // 1. Initially without /etc/dpkg, should do nothing
      await DistroInstaller.ensureDpkgConfiguration(tempRootDir);
      expect(Directory(p.join(tempRootDir.path, 'etc', 'dpkg')).existsSync(), isFalse);

      // 2. With /etc/dpkg present, should create 01_proot
      final dpkgDir = Directory(p.join(tempRootDir.path, 'etc', 'dpkg'))..createSync(recursive: true);
      await DistroInstaller.ensureDpkgConfiguration(tempRootDir);

      final prootCfg = File(p.join(dpkgDir.path, 'dpkg.cfg.d', '01_proot'));
      expect(prootCfg.existsSync(), isTrue);
      expect(prootCfg.readAsStringSync(), equals('force-unsafe-io\n'));
    });

    test('buildLaunchConfig places .l2s inside rootDir and migrates legacy .l2s', () async {
      // Setup legacy external .l2s directory
      final legacyL2sDir = Directory(p.join(tempBaseDir.path, 'debian', '.l2s'))..createSync(recursive: true);
      File(p.join(legacyL2sDir.path, 'meta_link_1')).writeAsStringSync('stand-in-content');

      // Setup /bin/sh inside rootDir so targetShell resolves cleanly
      final binDir = Directory(p.join(tempRootDir.path, 'bin'))..createSync(recursive: true);
      File(p.join(binDir.path, 'sh')).writeAsStringSync('#!/bin/sh');

      final launchConfig = await DistroManager().buildLaunchConfig(
        systemName: 'debian',
        customRootDir: tempRootDir,
      );

      // Verify guest environment has PROOT_L2S_DIR=/.l2s
      expect(launchConfig.arguments, contains('PROOT_L2S_DIR=/.l2s'));

      // Verify host environment PROOT_L2S_DIR points to rootDir/.l2s
      final targetL2sDir = Directory(p.join(tempRootDir.path, '.l2s'));
      expect(targetL2sDir.existsSync(), isTrue);
      expect(launchConfig.environment['PROOT_L2S_DIR'], equals(targetL2sDir.path));

      // Verify legacy file was migrated
      final migratedFile = File(p.join(targetL2sDir.path, 'meta_link_1'));
      expect(migratedFile.existsSync(), isTrue);
      expect(migratedFile.readAsStringSync(), equals('stand-in-content'));
    });
  });
}
