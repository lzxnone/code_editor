import 'dart:io';

import '../toolchain_service.dart';
import 'project_probe.dart';

/// 项目探测模块接口（对标 VS Code TaskProvider / IDE 的 ProjectModel 提供者）
///
/// 总调度按**队列线性执行**驱动每个模块，每个模块依次做三个动作：
/// 1. [prepare] + [checkDependencies]：环境准备与**依赖检测**（返回缺失的依赖 key）；
/// 2. [installDependencies]：**自动补全**缺失依赖（默认实现 = 复用容器内发行版安装命令）；
/// 3. [probe]：**执行探测**，返回结构化结果。
///
/// 约定：
/// * 模块不得返回任何硬编码兜底任务；探测失败就如实返回 failed；
/// * 模块不得自行猜测执行环境，一切执行都通过 [ProjectProbe] 提供的当前系统会话；
/// * 依赖必须声明为 [requiredToolchainKeys]（键取自 [ToolchainService.supportedTools]），
///   这样"自动补全"才能拿到对应发行版的安装命令。
abstract class ProjectModule {
  /// 模块唯一标识（如 'gradle', 'cmake', 'cargo', 'npm' 等）
  String get id;

  /// 模块展示名（用于 UI 文案插值，如 'Gradle'）
  String get displayName;

  /// 该项目特有的特征标记文件（命中其中任意一个才激活本探测器）
  List<String> get triggerFiles;

  /// 是否支持"重新同步真实任务"
  bool get supportsResync => false;

  /// 需要的工具链依赖 key（对应 [ToolchainService.supportedTools] 的键）
  List<String> get requiredToolchainKeys => const [];

  /// 快速判断当前工程是否匹配本模块（毫秒级，只检测文件存在与否）
  bool shouldActivate(Directory projectDir);

  /// 环境准备（写探测脚本、准备临时目录等），在依赖检测前执行。默认无操作。
  Future<void> prepare(ProjectProbe probe) async {}

  /// 依赖检测：返回缺失的依赖 key 列表。默认实现按 [requiredToolchainKeys] 逐个检查。
  Future<List<String>> checkDependencies(ProjectProbe probe) async {
    final missing = <String>[];
    for (final key in requiredToolchainKeys) {
      final requirement = ToolchainService.supportedTools[key];
      if (requirement == null) continue;
      final installed = await probe.isToolchainInstalled(requirement);
      if (!installed) missing.add(key);
    }
    return missing;
  }

  /// 自动补全缺失依赖：默认实现调用容器内安装（按发行版家族合成命令）。
  Future<bool> installDependencies(ProjectProbe probe, List<String> missing) {
    return probe.installToolchains(missing);
  }

  /// 执行探测（结构化结果）
  Future<ModuleProbeResult> probe(ProjectProbe probe);
}
