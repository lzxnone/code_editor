import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../models/notice_item.dart';
import '../../models/run_task.dart';
import 'gradle_ide_model.dart';
import 'project_module.dart';
import 'project_probe.dart';

/// Gradle 项目模块：通过 init script 获取**结构化模型**来搜索真实任务。
///
/// 与旧实现的区别：
/// * 不再解析 `gradle tasks --all` 的人类可读文本（正则/分组启发式全部删除）；
/// * 不再返回任何硬编码兜底任务：探测失败就如实返回失败分类 + 细节；
/// * 先在后台上完成工具链定位与探测脚本准备（warmUp），再正式探测（probe）。
class GradleProjectModule extends ProjectModule {
  /// 探测模型文件（init script 输出，位于工程 .code_editor 内，容器内同为 /workspace）
  static const String modelFileName = 'gradle_ide_model.json';

  /// init script 在工程内的落盘路径（相对工程根）
  static const String initScriptRelativePath = '.code_editor/code_editor_model.init.gradle';

  @override
  String get id => 'gradle';

  @override
  String get displayName => 'Gradle';

  @override
  bool get supportsResync => true;

  /// Gradle 依赖：`gradle` 这条工具链需求的 checkBinary 就是 `java`
  /// （Gradle 本身是 JVM 程序，没有 JDK 连启动都做不到，所以自动补全 = 装 JDK）。
  @override
  List<String> get requiredToolchainKeys => const ['gradle'];

  @override
  List<String> get triggerFiles => const [
        'build.gradle',
        'build.gradle.kts',
        'settings.gradle',
        'settings.gradle.kts',
        'gradlew',
      ];

  @override
  bool shouldActivate(Directory projectDir) {
    return triggerFiles.any((f) => File(p.join(projectDir.path, f)).existsSync());
  }

  /// 环境准备：把结构化探测脚本写入工程 .code_editor/
  @override
  Future<void> prepare(ProjectProbe probe) async {
    await _ensureInitScript(probe.projectDir);
  }

  @override
  Future<ModuleProbeResult> probe(ProjectProbe probe) async {
    if (probe.isCancelled) return ModuleProbeResult.cancelled(id);

    final projectDir = probe.projectDir;

    // 系统任务不落盘：每次都跑真实自省（模块结果只写入内存任务表）
    // 1. 没有 wrapper 时必须存在 gradle 可执行文件（JDK 由总调度的依赖检测/自动补全保证）
    final hasWrapper = _wrapperExists(projectDir);
    if (!hasWrapper) {
      final hasGradle = await probe.hasCommand('gradle');
      if (!hasGradle) {
        return ModuleProbeResult.failed(
          id,
          failure: NoticeFailure.toolchainMissing,
          detail: 'gradle',
        );
      }
    }
    final execCmd = hasWrapper ? 'sh ./gradlew' : 'gradle';

    try {
      await _ensureInitScript(projectDir);
      final modelFile = File(p.join(projectDir.path, '.code_editor', modelFileName));
      // 清理上一次的结果，避免读到陈旧模型
      if (modelFile.existsSync()) {
        try {
          modelFile.deleteSync();
        } catch (_) {}
      }

      ProcessResult? result = await _runModelCommand(probe, execCmd, offline: false);
      if (!_isSuccess(result) && !probe.isCancelled) {
        debugPrint('[GradleProjectModule] 在线结构化探测未成功 (exit=${result?.exitCode})，尝试 --offline 重试');
        final offlineResult = await _runModelCommand(probe, execCmd, offline: true);
        if (_isSuccess(offlineResult) || offlineResult?.exitCode == -1) {
          result = offlineResult;
        } else if (offlineResult != null) {
          final offlineErr = _stderrTail(offlineResult.stderr);
          result = (offlineErr != null && offlineErr.isNotEmpty) ? offlineResult : (result ?? offlineResult);
        }
      }

      if (probe.isCancelled) return ModuleProbeResult.cancelled(id);

      if (!modelFile.existsSync() || modelFile.lengthSync() == 0) {
        if (!_isSuccess(result)) {
          // exitCode == -1：容器内命令被超时 kill（DistroManager 的 onTimeout 约定）
          if (result != null && result.exitCode == -1) {
            return ModuleProbeResult.failed(id, failure: NoticeFailure.timeout);
          }
          return ModuleProbeResult.failed(
            id,
            failure: NoticeFailure.executionFailed,
            detail: _stderrTail(result?.stderr),
          );
        }
        final detail = _stderrTail(result?.stderr) ?? _stderrTail(result?.stdout);
        return ModuleProbeResult.failed(
          id,
          failure: NoticeFailure.unparsable,
          detail: detail,
        );
      }

      final raw = await modelFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return ModuleProbeResult.failed(id, failure: NoticeFailure.unparsable);
      }
      final model = GradleIdeModel.fromJson(Map<String, dynamic>.from(decoded));
      if (model.error != null && model.error!.isNotEmpty) {
        return ModuleProbeResult.failed(
          id,
          failure: NoticeFailure.executionFailed,
          detail: model.error,
        );
      }

      final tasks = model.toRunTasks(execCmd);
      if (tasks.isEmpty) {
        // 探测成功但工程确实没有任何任务：如实返回空（不伪造）
        return ModuleProbeResult.ok(id, const <RunTask>[]);
      }

      debugPrint(
          '[GradleProjectModule] 结构化探测成功: gradle=${model.gradleVersion} '
          'projects=${model.projects.length} tasks=${tasks.length}');
      return ModuleProbeResult.ok(id, tasks);
    } catch (e) {
      debugPrint('[GradleProjectModule] 结构化探测异常: $e');
      return ModuleProbeResult.failed(
        id,
        failure: NoticeFailure.unparsable,
        detail: '$e',
      );
    }
  }

  /// 缓存指纹 = 缓存 schema 版本 + 构建脚本指纹
  // 说明：系统任务不再落盘，因此构建脚本指纹与模块缓存读写一并移除。
  bool _wrapperExists(Directory projectDir) =>
      File(p.join(projectDir.path, 'gradlew')).existsSync();

  /// 把探测脚本写入工程 .code_editor/（容器内 /workspace/.code_editor/...）
  Future<void> _ensureInitScript(Directory projectDir) async {
    try {
      final content = await rootBundle.loadString('assets/gradle/code_editor_model.init.gradle');
      final target = File(p.join(projectDir.path, initScriptRelativePath));
      final parent = target.parent;
      if (!parent.existsSync()) {
        parent.createSync(recursive: true);
      }
      if (!target.existsSync() || target.readAsStringSync() != content) {
        target.writeAsStringSync(content, flush: true);
        debugPrint('[GradleProjectModule] 已写入结构化探测脚本: ${target.path}');
      }
    } catch (e) {
      debugPrint('[GradleProjectModule] 写入探测脚本失败: $e');
    }
  }

  Future<ProcessResult?> _runModelCommand(
    ProjectProbe probe,
    String execCmd, {
    required bool offline,
  }) {
    final offlineFlag = offline ? ' --offline' : '';
    // 强制英文输出（避免本地化文本影响任何诊断信息），-q 抑制无关日志；
    // 模型本体通过 .code_editor/gradle_ide_model.json 回传，不依赖 stdout。
    // 在容器（PRoot）环境中必须显式传递 --no-daemon 并关闭配置缓存（-Dorg.gradle.configuration-cache=false）：
    // 1. 避免残留孤儿 JVM 守护进程或锁文件损坏导致后续调用连接超时/拒绝；
    // 2. 避免配置缓存复用直接跳过 projectsEvaluated 项目评估导致不生成模型文件。
    return probe.runHeadless(
      'LC_ALL=C LANG=C $execCmd --no-daemon -Dorg.gradle.configuration-cache=false --console=plain -q -I $initScriptRelativePath help$offlineFlag',
      timeout: const Duration(seconds: 90),
    );
  }

  bool _isSuccess(ProcessResult? result) =>
      result != null && result.exitCode == 0;

  String? _stderrTail(Object? stderr) {
    final text = stderr?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    const maxLength = 240;
    return text.length <= maxLength ? text : '…${text.substring(text.length - maxLength)}';
  }
}
