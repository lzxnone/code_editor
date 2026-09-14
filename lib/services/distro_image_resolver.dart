import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/distro_manifest.dart';

/// LXC 镜像源索引行条目
class DistroIndexEntry {
  final String distribution;
  final String release;
  final String arch;
  final String variant;
  final String buildDate;
  final String path;

  const DistroIndexEntry({
    required this.distribution,
    required this.release,
    required this.arch,
    required this.variant,
    required this.buildDate,
    required this.path,
  });

  factory DistroIndexEntry.fromLine(String line) {
    final parts = line.trim().split(';');
    if (parts.length < 6) {
      throw FormatException('Invalid index line: $line');
    }
    return DistroIndexEntry(
      distribution: parts[0],
      release: parts[1],
      arch: parts[2],
      variant: parts[3],
      buildDate: parts[4],
      path: parts[5],
    );
  }
}

/// 发行版镜像真实下载链接解析器（遵循 LinuxContainers 标准 index-system 规范）
class DistroImageResolver {
  static final DistroImageResolver _instance = DistroImageResolver._internal();
  factory DistroImageResolver() => _instance;
  DistroImageResolver._internal();

  /// 缓存的解析结果 (key: "mirrorId:distroId:arch", value: url)
  final Map<String, String> _resolvedUrlCache = {};

  /// 缓存的 index-system 纯文本内容 (key: mirrorId, value: (cachedTime, content))
  final Map<String, (DateTime, String)> _indexContentCache = {};

  /// 索引缓存有效期 (1 小时)
  static const Duration cacheTtl = Duration(hours: 1);

  @visibleForTesting
  String? customIndexContent;

  /// 清空指定系统或所有缓存
  void invalidateCache({String? distroId}) {
    if (distroId != null) {
      _resolvedUrlCache.removeWhere((key, _) => key.contains(':$distroId:'));
    } else {
      _resolvedUrlCache.clear();
      _indexContentCache.clear();
    }
  }

  /// 将系统架构枚举映射为 LXC 索引架构命名（arm64 -> arm64, x86_64 -> amd64）
  static String toLxcArch(DistroArch arch) {
    switch (arch) {
      case DistroArch.arm64:
        return 'arm64';
      case DistroArch.x86_64:
        return 'amd64';
    }
  }

  /// 动态解析指定发行版在指定镜像源上的最新真实下载 URL
  Future<String> resolveDownloadUrl({
    required DistroManifestItem item,
    required DistroArch arch,
    required DistroMirror mirror,
    bool forceRefresh = false,
  }) async {
    // 内置系统直接返回静态资源路径
    if (item.isBuiltin) {
      return item.packages[arch] ?? '';
    }

    final spec = item.lxcSpec;
    if (spec == null) {
      return item.packages[arch] ?? '';
    }

    final cacheKey = '${mirror.id}:${item.id}:${arch.name}';
    if (!forceRefresh && _resolvedUrlCache.containsKey(cacheKey)) {
      return _resolvedUrlCache[cacheKey]!;
    }

    // 1. 获取对应镜像源的 meta/1.0/index-system 索引
    final indexContent = await _fetchIndexContent(mirror, forceRefresh: forceRefresh);

    // 2. 解析为条目列表
    final entries = parseIndex(indexContent);
    final targetArch = toLxcArch(arch);

    // 3. 匹配符合发行版、版本、变体及 CPU 架构的条目
    final matching = entries.where((e) =>
      e.distribution.toLowerCase() == spec.distribution.toLowerCase() &&
      e.release.toLowerCase() == spec.release.toLowerCase() &&
      e.arch.toLowerCase() == targetArch.toLowerCase() &&
      e.variant.toLowerCase() == spec.variant.toLowerCase(),
    ).toList();

    if (matching.isEmpty) {
      throw HttpException(
        'Image not found in mirror ${mirror.name}: ${spec.distribution}/${spec.release}/$targetArch',
      );
    }

    // 4. 按 buildDate 降序排序，取最新一次构建
    matching.sort((a, b) => b.buildDate.compareTo(a.buildDate));
    final latestEntry = matching.first;

    // 5. 组合目标真实 URL
    final base = mirror.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final relPath = latestEntry.path.replaceAll(RegExp(r'^/+'), '');
    final fullUrl = '$base/$relPath' 'rootfs.tar.xz';

    _resolvedUrlCache[cacheKey] = fullUrl;
    return fullUrl;
  }

  /// 解析 index-system 纯文本内容为条目列表
  static List<DistroIndexEntry> parseIndex(String content) {
    final lines = content.split('\n');
    final List<DistroIndexEntry> list = [];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      try {
        list.add(DistroIndexEntry.fromLine(trimmed));
      } catch (_) {}
    }
    return list;
  }

  /// 从网络拉取镜像源的 meta/1.0/index-system
  Future<String> _fetchIndexContent(DistroMirror mirror, {bool forceRefresh = false}) async {
    if (customIndexContent != null) {
      return customIndexContent!;
    }

    final now = DateTime.now();
    if (!forceRefresh && _indexContentCache.containsKey(mirror.id)) {
      final (cachedAt, text) = _indexContentCache[mirror.id]!;
      if (now.difference(cachedAt) < cacheTtl) {
        return text;
      }
    }

    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

      final indexUrl = '${mirror.baseUrl.replaceAll(RegExp(r'/+$'), '')}/meta/1.0/index-system';
      final request = await client.getUrl(Uri.parse(indexUrl));
      final response = await request.close().timeout(const Duration(seconds: 20));

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Failed to fetch mirror index from ${mirror.name}: HTTP ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      _indexContentCache[mirror.id] = (now, body);
      return body;
    } finally {
      client?.close();
    }
  }
}
