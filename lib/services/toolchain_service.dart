import 'dart:io';
import 'package:path/path.dart' as p;
import 'distro_manager.dart';

/// 单个工具链依赖规格定义
class ToolchainRequirement {
  /// 用于检测是否已安装的可执行文件名（传入 command -v）
  final String checkBinary;

  /// 用户可见的工具名称/描述
  final String displayName;

  /// Ubuntu 下的自动安装指令
  final String installCommand;

  const ToolchainRequirement({
    required this.checkBinary,
    required this.displayName,
    required this.installCommand,
  });

  /// 获取安装命令（带自动修复前缀）
  String get effectiveInstallCommand =>
      'DEBIAN_FRONTEND=noninteractive dpkg --configure -a 2>/dev/null || true; $installCommand';

  /// 兼容接口
  String? getInstallCommand([DistroFamily? family]) {
    if (family == DistroFamily.unknown) return null;
    return effectiveInstallCommand;
  }
}

/// 预编译软件源与工具链检测/安装适配服务（专为 Ubuntu 24.04 深度优化）
class ToolchainService {
  /// 已注册的常用编译器与开发工具链元数据
  static const Map<String, ToolchainRequirement> supportedTools = {
    'make': ToolchainRequirement(
      checkBinary: 'make',
      displayName: 'make 编译构建工具',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential',
    ),
    'cmake': ToolchainRequirement(
      checkBinary: 'cmake',
      displayName: 'cmake 构建套件',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y cmake build-essential',
    ),
    'gcc': ToolchainRequirement(
      checkBinary: 'gcc',
      displayName: 'GCC C 语言编译器',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential',
    ),
    'g++': ToolchainRequirement(
      checkBinary: 'g++',
      displayName: 'G++ C++ 编译器',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential',
    ),
    'python3': ToolchainRequirement(
      checkBinary: 'python3',
      displayName: 'Python 3 运行环境',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip',
    ),
    'python': ToolchainRequirement(
      checkBinary: 'python3',
      displayName: 'Python 3 运行环境',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip',
    ),
    'npm': ToolchainRequirement(
      checkBinary: 'npm',
      displayName: 'Node.js 与 NPM 环境',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm',
    ),
    'node': ToolchainRequirement(
      checkBinary: 'node',
      displayName: 'Node.js 运行环境',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm',
    ),
    'cargo': ToolchainRequirement(
      checkBinary: 'cargo',
      displayName: 'Rust 与 Cargo 工具链',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y cargo rustc',
    ),
    'rustc': ToolchainRequirement(
      checkBinary: 'rustc',
      displayName: 'Rust 编译器',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y cargo rustc',
    ),
    'go': ToolchainRequirement(
      checkBinary: 'go',
      displayName: 'Go 语言环境',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y golang-go',
    ),
    'gradle': ToolchainRequirement(
      checkBinary: 'java',
      displayName: 'Java / Gradle 运行时',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y default-jdk-headless ca-certificates-java && (find /usr/lib/jvm -mindepth 1 -maxdepth 2 -type d \\( -name lib -o -name server \\) > /etc/ld.so.conf.d/java.conf 2>/dev/null; ldconfig 2>/dev/null; update-ca-certificates -f 2>/dev/null || true)',
    ),
    'java': ToolchainRequirement(
      checkBinary: 'java',
      displayName: 'Java 运行环境 (JDK)',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y default-jdk-headless ca-certificates-java && (find /usr/lib/jvm -mindepth 1 -maxdepth 2 -type d \\( -name lib -o -name server \\) > /etc/ld.so.conf.d/java.conf 2>/dev/null; ldconfig 2>/dev/null; update-ca-certificates -f 2>/dev/null || true)',
    ),
    'maven': ToolchainRequirement(
      checkBinary: 'mvn',
      displayName: 'Maven 构建工具',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y maven default-jdk-headless',
    ),
    'mvn': ToolchainRequirement(
      checkBinary: 'mvn',
      displayName: 'Maven 构建工具',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y maven default-jdk-headless',
    ),
    'lua': ToolchainRequirement(
      checkBinary: 'lua',
      displayName: 'Lua 解释器',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y lua5.4',
    ),
    'perl': ToolchainRequirement(
      checkBinary: 'perl',
      displayName: 'Perl 解释器',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y perl',
    ),
    'php': ToolchainRequirement(
      checkBinary: 'php',
      displayName: 'PHP 命令行环境',
      installCommand: 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y php-cli',
    ),
  };

  /// 从命令行文本中提取所有潜在调用的工具关键字
  static List<ToolchainRequirement> detectRequiredTools(String command) {
    if (command.trim().isEmpty) return const [];

    final List<ToolchainRequirement> detected = [];
    final seen = <String>{};

    // 按语句分隔符拆解：&&, ||, ;, |, 换行
    final statements = command.split(RegExp(r'&&|\|\||;|\||\n'));
    for (var stmt in statements) {
      stmt = stmt.trim();
      if (stmt.isEmpty) continue;

      // 提取语句开头的可执行文件名或路径（支持前置 sudo、sh、bash，支持 ./gradlew、/usr/bin/make 等）
      final match = RegExp(r'^(?:sudo\s+)?(?:(?:sh|bash)\s+)?([a-zA-Z0-9_\.\-\+\/\\]+)').firstMatch(stmt);
      if (match != null) {
        var rawBin = match.group(1)!;
        // 归一化提取二进制文件名
        var binName = rawBin.split(RegExp(r'[/\\]')).last;
        if (binName == 'gradlew' || binName == 'gradle') {
          binName = 'gradle';
        }

        if (supportedTools.containsKey(binName)) {
          final req = supportedTools[binName]!;
          if (!seen.contains(req.checkBinary)) {
            seen.add(req.checkBinary);
            detected.add(req);
          }
        }
      }
    }

    return detected;
  }

  /// 检查目标发行版根文件系统中是否已经物理安装了指定工具
  static bool isToolInstalledInRootfs(Directory rootDir, String checkBinary) {
    // 候选二进制名称
    final binariesToCheck = <String>[checkBinary];
    if (checkBinary == 'python3') binariesToCheck.add('python');
    if (checkBinary == 'node') binariesToCheck.add('nodejs');
    if (checkBinary == 'npm') binariesToCheck.add('npm');

    final candidateSubDirs = [
      ['usr', 'bin'],
      ['bin'],
      ['usr', 'local', 'bin'],
      ['sbin'],
      ['usr', 'sbin'],
      ['root', '.cargo', 'bin'],
      ['root', '.local', 'bin'],
      ['root', 'go', 'bin'],
      ['usr', 'lib', 'jvm', 'default-java', 'bin'],
    ];

    for (final bin in binariesToCheck) {
      for (final subDir in candidateSubDirs) {
        final fullPath = p.joinAll([rootDir.path, ...subDir, bin]);
        try {
          final type = FileSystemEntity.typeSync(fullPath, followLinks: false);
          if (type != FileSystemEntityType.notFound) {
            return true;
          }
        } catch (_) {}
      }
    }

    if (checkBinary == 'java') {
      final jvmDir = Directory(p.join(rootDir.path, 'usr', 'lib', 'jvm'));
      if (jvmDir.existsSync()) {
        try {
          for (final entry in jvmDir.listSync()) {
            if (entry is Directory) {
              final javaBin = File(p.join(entry.path, 'bin', 'java'));
              if (javaBin.existsSync()) return true;
            }
          }
        } catch (_) {}
      }
    }
    return false;
  }

  /// 针对不同系统与命令生成自适应的预安装与执行组合脚本
  ///
  /// - 只有识别出明确发行版家族（Alpine/Ubuntu/Debian/Arch/Fedora）的系统，才会生成前置检测与安装包装；
  /// - 针对未识别的未知系统（[DistroFamily.unknown]）或宿主 Shell，直接原样返回指令，不作任何干预；
  /// - 若传入 [rootDir]，将优先在宿主文件系统快速检测工具是否已物理存在，已存在则直接返回原命令；
  /// - 若命令为多行脚本（包含换行符），将自动转换为 Unix LF 换行并保存至容器 `/root/.ce_task.sh` 执行，
  ///   彻底避免交互式终端在提示符处逐行错位回显；
  /// - 若工具缺失，将把工具安装逻辑一并注入引导脚本中，保证执行的平滑与终端的清爽。
  static String resolveCommand(
    String rawCommand,
    DistroFamily family, {
    Directory? rootDir,
  }) {
    if (rawCommand.trim().isEmpty) {
      return rawCommand;
    }

    // 1. 规范化统一换行符为 Unix LF，防止 Windows CRLF 导致 /bin/sh: $'\r': command not found
    final normalizedCommand = rawCommand.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final isMultiLine = normalizedCommand.contains('\n');

    // 2. 识别所需工具链
    final tools = detectRequiredTools(normalizedCommand);

    // 3. 计算实际物理缺失的工具
    List<ToolchainRequirement> missingTools = [];
    if (family != DistroFamily.unknown && tools.isNotEmpty) {
      if (rootDir != null && rootDir.existsSync()) {
        missingTools = tools
            .where((tool) => !isToolInstalledInRootfs(rootDir, tool.checkBinary))
            .toList();
      } else {
        missingTools = tools;
      }
    }

    // 4. 多行脚本（Multiline Script）模式：封装为 /root/.ce_task.sh 运行
    if (isMultiLine && rootDir != null && rootDir.existsSync()) {
      try {
        final rootHomeDir = Directory(p.join(rootDir.path, 'root'));
        if (!rootHomeDir.existsSync()) {
          rootHomeDir.createSync(recursive: true);
        }
        final taskFile = File(p.join(rootHomeDir.path, '.ce_task.sh'));
        final scriptBuffer = StringBuffer();
        scriptBuffer.writeln('#!/bin/sh');
        scriptBuffer.writeln('set -e');

        // 若存在缺失的编译工具链依赖，前置注入自动安装
        for (final tool in missingTools) {
          final installCmd = tool.getInstallCommand(family);
          if (installCmd == null || installCmd.isEmpty) continue;
          scriptBuffer.writeln("printf '\\033[1;33m[CodeEditor] 检测到未安装 %s，正在自动配置编译环境...\\033[0m\\n' '${tool.displayName}'");
          scriptBuffer.writeln(installCmd);
          scriptBuffer.writeln("printf '\\033[1;32m[CodeEditor] %s 安装就绪，继续执行任务...\\033[0m\\n' '${tool.displayName}'");
        }

        // 注入用户编写的多行脚本内容
        scriptBuffer.writeln(normalizedCommand);

        taskFile.writeAsStringSync(scriptBuffer.toString());
        return 'sh /root/.ce_task.sh';
      } catch (_) {
        // 异常降级
      }
    }

    // 5. 单行指令且未知系统：原样返回
    if (family == DistroFamily.unknown || tools.isEmpty) {
      return rawCommand;
    }

    // 6. 单行指令且所有工具已物理就绪：直接返回原命令，零污染无感直达
    if (rootDir != null && rootDir.existsSync() && missingTools.isEmpty) {
      return rawCommand;
    }

    // 7. 单行指令且存在缺失工具：构建轻量 /root/.ce_setup.sh
    if (rootDir != null && rootDir.existsSync() && missingTools.isNotEmpty) {
      try {
        final rootHomeDir = Directory(p.join(rootDir.path, 'root'));
        if (!rootHomeDir.existsSync()) {
          rootHomeDir.createSync(recursive: true);
        }
        final setupFile = File(p.join(rootHomeDir.path, '.ce_setup.sh'));
        final scriptBuffer = StringBuffer();
        scriptBuffer.writeln('#!/bin/sh');
        scriptBuffer.writeln('set -e');
        for (final tool in missingTools) {
          final installCmd = tool.getInstallCommand(family);
          if (installCmd == null || installCmd.isEmpty) continue;
          scriptBuffer.writeln("printf '\\033[1;33m[CodeEditor] 检测到未安装 %s，正在自动配置编译环境...\\033[0m\\n' '${tool.displayName}'");
          scriptBuffer.writeln(installCmd);
          scriptBuffer.writeln("printf '\\033[1;32m[CodeEditor] %s 安装就绪，继续执行任务...\\033[0m\\n' '${tool.displayName}'");
        }
        setupFile.writeAsStringSync(scriptBuffer.toString());
        return 'sh /root/.ce_setup.sh && ($rawCommand)';
      } catch (_) {
        // 异常降级
      }
    }

    // 5. 降级方案（未传 rootDir 或写入失败时的内联防护）
    final checks = <String>[];
    for (final tool in missingTools) {
      final installCmd = tool.getInstallCommand(family);
      if (installCmd == null || installCmd.isEmpty) {
        continue;
      }

      final checkScript =
          'if ! command -v ${tool.checkBinary} >/dev/null 2>&1; then '
          "printf '\\033[1;33m[CodeEditor] 检测到未安装 %s，正在自动配置编译环境...\\033[0m\\n' '${tool.displayName}'; "
          '$installCmd; '
          'if [ \$? -eq 0 ]; then '
          "printf '\\033[1;32m[CodeEditor] %s 安装就绪，继续执行任务...\\033[0m\\n' '${tool.displayName}'; "
          'else '
          "printf '\\033[1;31m[CodeEditor] %s 安装失败，请检查网络或软件源配置。\\033[0m\\n' '${tool.displayName}'; "
          'exit 1; '
          'fi; '
          'fi';
      checks.add(checkScript);
    }

    if (checks.isEmpty) {
      return rawCommand;
    }

    final preamble = checks.join(' && ');
    return '$preamble && ($rawCommand)';
  }
}
