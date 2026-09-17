import 'package:path/path.dart' as p;

/// PRoot 容器路径与宿主文件路径双向映射器
///
/// 在 Android 手机端 PRoot 架构中：
/// - 宿主端文件真实路径例如：`/data/data/com.example/files/workspace/main.c` 或 Windows 开发测试路径
/// - PRoot 启动参数将工作区绑定挂载至容器内部 `/workspace`
/// - 发送给 LSP 服务端（如 clangd）的文档 URI 需映射为 `file:///workspace/...`
/// - 接收 LSP 服务端诊断或引用返回的容器 URI 需反向还原为宿主绝对路径
class PRootPathMapper {
  const PRootPathMapper();

  /// 转换宿主文件路径为容器内部映射的 URI
  static String toGuestUri(String hostFilePath, String workspaceRoot) {
    if (workspaceRoot.isEmpty) {
      return _toFileUri(hostFilePath);
    }

    final normHost = p.normalize(hostFilePath).replaceAll('\\', '/');
    final normRoot = p.normalize(workspaceRoot).replaceAll('\\', '/');

    if (normHost == normRoot) {
      return 'file:///workspace';
    }

    if (normHost.startsWith('$normRoot/')) {
      final relative = normHost.substring(normRoot.length + 1);
      return 'file:///workspace/$relative';
    }

    if (normHost.startsWith(normRoot)) {
      final relative = normHost.substring(normRoot.length).replaceFirst(RegExp(r'^/'), '');
      return 'file:///workspace/$relative';
    }

    return _toFileUri(hostFilePath);
  }

  /// 转换宿主文件路径为容器内部真实绝对路径（例如 /workspace/src/main.c）
  static String toGuestPath(String hostFilePath, String workspaceRoot) {
    final uri = toGuestUri(hostFilePath, workspaceRoot);
    if (uri.startsWith('file://')) {
      return uri.substring('file://'.length);
    }
    return uri;
  }

  /// 将容器内部的 URI 反向还原为宿主文件绝对路径
  static String fromGuestUriToHostPath(String guestUri, String workspaceRoot) {
    final normUri = guestUri.replaceAll('\\', '/');
    if (normUri.startsWith('file:///workspace/')) {
      final relative = normUri.substring('file:///workspace/'.length);
      return p.join(workspaceRoot, relative).replaceAll('\\', '/');
    }
    if (normUri == 'file:///workspace') {
      return workspaceRoot.replaceAll('\\', '/');
    }
    if (normUri.startsWith('file:///')) {
      // 普通 file:/// 协议，若未挂载至 /workspace 则直接去除 file:// 前缀
      return normUri.substring('file://'.length);
    }
    return guestUri;
  }

  static String _toFileUri(String path) {
    final normalized = p.normalize(path).replaceAll('\\', '/');
    if (normalized.startsWith('file://')) return normalized;
    if (normalized.startsWith('/')) return 'file://$normalized';
    return 'file:///$normalized';
  }
}
