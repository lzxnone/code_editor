import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/notice_item.dart';
import '../models/run_task.dart';
import 'distro_manager.dart';
import 'project_modules/cargo_project_module.dart';
import 'project_modules/cmake_project_module.dart';
import 'project_modules/dart_project_module.dart';
import 'project_modules/gradle_project_module.dart';
import 'project_modules/make_project_module.dart';
import 'project_modules/npm_project_module.dart';
import 'project_modules/project_module.dart';
import 'project_modules/project_probe.dart';
import 'project_modules/single_file_task_detector.dart';

/// 项目任务总调度（对标 VS Code Task Service / IDE 的 ProjectModel 协调器）
///
/// 一次探测 = 下面这套流程走完一遍：
/// 1. **模块发现**（按特征文件激活，快）；
/// 2. 命中的模块**全部入队**；
/// 3. **队列线性执行**：一次只跑一个模块，无论成功/失败都接着跑下一个，直到队列空；
/// 4. 每个模块依次做三个动作：**依赖检测 → 自动补全 → 执行探测**；
/// 5. 每个模块探测完成即通过 [onModuleResult] 回调上抛（UI 增量写入"类型→任务数组"）。
///
/// 队列串行还有一个关键收益：同一时刻只有一个模块在装依赖，
/// 不会出现 apt/apk 争抢同一把包管理器锁的问题。
class ProjectTaskDispatcher {
  static final ProjectTaskDispatcher instance = ProjectTaskDispatcher();

  final List<ProjectModule> _modules = [];

  ProjectTaskDispatcher({List<ProjectModule>? customModules}) {
    if (customModules != null) {
      _modules.addAll(customModules);
    } else {
      _registerDefaultModules();
    }
  }

  void _registerDefaultModules() {
    _modules.addAll([
      GradleProjectModule(),
      CMakeProjectModule(),
      CargoProjectModule(),
      NpmProjectModule(),
      MakeProjectModule(),
      DartProjectModule(),
    ]);
  }

  List<ProjectModule> get modules => List.unmodifiable(_modules);

  void registerModule(ProjectModule module) {
    _modules.removeWhere((m) => m.id == module.id);
    _modules.add(module);
  }

  ProjectModule? getModule(String id) {
    for (final module in _modules) {
      if (module.id == id) return module;
    }
    return null;
  }

  /// 当前项目中所有被激活的模块（模块发现阶段）
  List<ProjectModule> getActiveModules(Directory projectDir) =>
      _modules.where((m) => m.shouldActivate(projectDir)).toList();

  /// 创建一次探测会话（不执行）
  ProjectProbe createProbe({
    required String projectRoot,
    String? currentFilePath,
    required String? systemName,
    DistroManager? distroManager,
    String? onlyModuleId,
    Duration? budget,
  }) {
    return ProjectProbe(
      request: ProjectProbeRequest(
        projectDir: Directory(projectRoot),
        currentFilePath: currentFilePath,
        systemName: systemName ?? '',
        onlyModuleId: onlyModuleId,
      ),
      distroManager: distroManager ?? DistroManager(),
      budget: budget ?? ProjectProbe.defaultBudget,
    );
  }

  /// 执行探测会话：模块发现 → 入队 → 线性三动作执行 → 汇总报告
  ///
  /// [onModuleResult] 在每个模块结束时回调一次（成功/失败都会回调），
  /// 供 UI 立即把结果写入该模块对应的任务类型，并更新它自己的那条弹窗。
  Future<ProjectProbeReport> run(
    ProjectProbe probe, {
    void Function(ProjectModule module, ModuleProbeResult result)? onModuleResult,
  }) async {
    final projectDir = probe.projectDir;
    if (!projectDir.existsSync()) {
      return ProjectProbeReport.empty(probe.systemName);
    }

    // 0. 无可用系统 -> 不探测（也绝不触碰任何 rootfs 目录）
    if (!await isUsableSystem(probe.distroManager, probe.systemName)) {
      debugPrint('[ProjectTaskDispatcher] 无可用系统 (systemName=${probe.systemName})，跳过项目任务探测');
      return ProjectProbeReport.empty(probe.systemName);
    }

    // 1. 模块发现 + 入队
    final active = _resolveActiveModules(projectDir, probe.onlyModuleId);
    if (active.isEmpty) {
      return ProjectProbeReport.empty(probe.systemName);
    }
    final queue = ListQueue<ProjectModule>()..addAll(active);
    final refs = [for (final m in active) ProbeModuleRef(m.id, m.displayName)];

    // 开始计时：整轮探测的时间预算从这里起算
    probe.startBudget();

    probe.reportProgress(ProbeProgress(
      phase: ProbePhase.queued,
      queue: refs,
    ));

    final results = <String, ModuleProbeResult>{};
    var abortedByBudget = false;

    // 2. 线性执行队列
    while (queue.isNotEmpty) {
      if (probe.isCancelled) break;

      // 预算检查点 1：模块之间（绝不在安装中途强杀，避免半装状态）
      if (probe.isBudgetExceeded) {
        abortedByBudget = true;
        break;
      }

      final module = queue.removeFirst();
      final ref = ProbeModuleRef(module.id, module.displayName);

      void report(ProbePhase phase) {
        probe.reportProgress(ProbeProgress(
          phase: phase,
          queue: refs,
          current: ref,
        ));
      }

      ModuleProbeResult result;

      try {
        // 动作 1：环境准备 + 依赖检测
        report(ProbePhase.checkingDependency);
        await module.prepare(probe);
        var missing = await module.checkDependencies(probe);

        // 动作 2：自动补全缺失依赖（队列串行 => 同一时刻只有一次安装）
        result = ModuleProbeResult.ok(module.id, const <RunTask>[]);
        if (missing.isNotEmpty) {
          if (probe.isCancelled) {
            result = ModuleProbeResult.cancelled(module.id);
          } else if (probe.isBudgetExceeded) {
            // 预算检查点 2：安装前（一次安装可能长达 10 分钟，不该在预算将尽时开跑）
            abortedByBudget = true;
            result = ModuleProbeResult.skippedByBudget(module.id);
          } else {
            report(ProbePhase.installingDependency);
            probe.setInstallLine(null);
            final installed = await module.installDependencies(probe, missing);
            if (probe.isCancelled) {
              result = ModuleProbeResult.cancelled(module.id);
            } else if (!installed) {
              result = ModuleProbeResult.failed(
                module.id,
                failure: NoticeFailure.dependencyInstallFailed,
                detail: missing.first,
              );
            } else {
              missing = await module.checkDependencies(probe);
              if (missing.isNotEmpty) {
                result = ModuleProbeResult.failed(
                  module.id,
                  failure: NoticeFailure.toolchainMissing,
                  detail: missing.first,
                );
              }
            }
            probe.setInstallLine(null);
          }
        }

        // 动作 3：执行探测（只有前两步没有失败/跳过时才探测）
        if (result.status != ModuleProbeStatus.ok) {
          // 依赖安装失败 / 预算跳过 / 已取消：不再执行探测
        } else if (probe.isCancelled) {
          result = ModuleProbeResult.cancelled(module.id);
        } else if (probe.isBudgetExceeded) {
          abortedByBudget = true;
          result = ModuleProbeResult.skippedByBudget(module.id);
        } else {
          report(ProbePhase.probing);
          result = await module.probe(probe);
        }
      } catch (e, stack) {
        if (probe.isCancelled) {
          result = ModuleProbeResult.cancelled(module.id);
        } else {
          debugPrint('[ProjectTaskDispatcher] ${module.id} 探测异常: $e\n$stack');
          result = ModuleProbeResult.failed(
            module.id,
            failure: NoticeFailure.executionFailed,
            detail: '$e',
          );
        }
      }

      results[module.id] = result;
      onModuleResult?.call(module, result);

      // 无论成功/失败都继续下一个（除非被取消）
      if (probe.isCancelled) break;
    }

    // 用户取消：队列里剩下的模块统一标记为"已取消"，确保完整结算与状态收尾
    if (probe.isCancelled) {
      while (queue.isNotEmpty) {
        final skippedModule = queue.removeFirst();
        final cancelledResult = ModuleProbeResult.cancelled(skippedModule.id);
        results[skippedModule.id] = cancelledResult;
        onModuleResult?.call(skippedModule, cancelledResult);
      }
    }

    // 预算中止：队列里剩下的模块统一标记为"预算跳过"，并让 UI 收掉它们的进度卡片
    if (abortedByBudget) {
      debugPrint('[ProjectTaskDispatcher] 探测超出时间预算(${probe.budget})，'
          '跳过剩余 ${queue.length} 个模块');
      while (queue.isNotEmpty) {
        final skippedModule = queue.removeFirst();
        final skippedResult = ModuleProbeResult.skippedByBudget(skippedModule.id);
        results[skippedModule.id] = skippedResult;
        onModuleResult?.call(skippedModule, skippedResult);
      }
    }

    // 3. 汇总（含"当前打开文件的单文件运行"任务，置于最前）
    probe.reportProgress(ProbeProgress(
      phase: ProbePhase.finalizing,
      queue: refs,
    ));

    final tasks = <RunTask>[];
    for (final module in active) {
      final result = results[module.id];
      if (result == null || result.status != ModuleProbeStatus.ok) continue;
      tasks.addAll(result.tasks);
    }

    final currentFilePath = probe.currentFilePath;
    if (!probe.isCancelled && currentFilePath != null && currentFilePath.isNotEmpty) {
      final single = detectSingleFileTask(projectDir.path, currentFilePath);
      if (single != null) tasks.insert(0, single);
    }

    probe.progress.value = null;

    return ProjectProbeReport(
      systemName: probe.systemName,
      detectedTasks: probe.isCancelled ? const <RunTask>[] : tasks,
      moduleResults: results,
      finishedAt: DateTime.now(),
      totalModules: refs.length,
      abortedByBudget: abortedByBudget,
    );
  }

  List<ProjectModule> _resolveActiveModules(Directory projectDir, String? onlyModuleId) {
    if (onlyModuleId == null) return getActiveModules(projectDir);
    final module = getModule(onlyModuleId);
    if (module == null || !module.shouldActivate(projectDir)) return const [];
    return [module];
  }

  /// 便捷入口：只关心任务列表时使用
  Future<List<RunTask>> detect({
    required String projectRoot,
    String? currentFilePath,
    String? systemName,
    DistroManager? distroManager,
    String? onlyModuleId,
  }) async {
    final probe = createProbe(
      projectRoot: projectRoot,
      currentFilePath: currentFilePath,
      systemName: systemName,
      distroManager: distroManager,
      onlyModuleId: onlyModuleId,
    );
    final report = await run(probe);
    probe.dispose();
    return report.detectedTasks;
  }

  /// 单模块重新同步（系统探测的特例：只跑一个模块）
  Future<ProjectProbeReport> syncModule({
    required String moduleId,
    required String projectRoot,
    String? currentFilePath,
    String? systemName,
    DistroManager? distroManager,
    void Function(ProjectModule module, ModuleProbeResult result)? onModuleResult,
  }) {
    final probe = createProbe(
      projectRoot: projectRoot,
      currentFilePath: currentFilePath,
      systemName: systemName,
      distroManager: distroManager,
      onlyModuleId: moduleId,
    );
    return run(probe, onModuleResult: onModuleResult).whenComplete(probe.dispose);
  }

  /// 判断给定系统名是否可用于执行探测：
  /// 1. 名称必须非空；
  /// 2. 必须是一个「已安装就绪」的系统实例（rootfs 内具备 etc 与 bin）；
  /// 3. 平台信息不可用（如单元测试环境）时按不可用处理，宁可不探测也不误探测。
  static Future<bool> isUsableSystem(DistroManager manager, String? systemName) async {
    final name = systemName?.trim();
    if (name == null || name.isEmpty) return false;
    try {
      return await manager.isSystemInstalled(name);
    } catch (e) {
      debugPrint('[ProjectTaskDispatcher] 系统可用性校验失败 (systemName=$name): $e');
      return false;
    }
  }

  /// 探测单文件运行指令（基于当前打开的文件），已独立封装至 [SingleFileTaskDetector]
  static RunTask? detectSingleFileTask(String projectRoot, String currentFilePath) =>
      SingleFileTaskDetector.detect(projectRoot, currentFilePath);
}
