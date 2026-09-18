import 'package:flutter/material.dart';

/// Git 平台类型
enum GitPlatform {
  github(
    id: 'github',
    name: 'GitHub',
    defaultServerUrl: 'https://github.com',
    apiBaseUrl: 'https://api.github.com',
    brandColor: Color(0xFF24292E),
  ),
  gitee(
    id: 'gitee',
    name: 'Gitee',
    defaultServerUrl: 'https://gitee.com',
    apiBaseUrl: 'https://gitee.com/api/v5',
    brandColor: Color(0xFFC71D23),
  ),
  gitlab(
    id: 'gitlab',
    name: 'GitLab',
    defaultServerUrl: 'https://gitlab.com',
    apiBaseUrl: 'https://gitlab.com/api/v4',
    brandColor: Color(0xFFFC6D26),
  ),
  generic(
    id: 'generic',
    name: '通用 / 自建 Git',
    defaultServerUrl: '',
    apiBaseUrl: '',
    brandColor: Color(0xFF3E4347),
  );

  final String id;
  final String name;
  final String defaultServerUrl;
  final String apiBaseUrl;
  final Color brandColor;

  const GitPlatform({
    required this.id,
    required this.name,
    required this.defaultServerUrl,
    required this.apiBaseUrl,
    required this.brandColor,
  });

  static GitPlatform fromString(String? val) {
    return GitPlatform.values.firstWhere(
      (e) => e.id == val || e.name.toLowerCase() == val?.toLowerCase(),
      orElse: () => GitPlatform.github,
    );
  }
}

/// 认证凭据类型
enum GitAuthType {
  token('token', 'PAT 个人访问令牌'),
  ssh('ssh', 'SSH 密钥对');

  final String id;
  final String label;
  const GitAuthType(this.id, this.label);

  static GitAuthType fromString(String? val) {
    return GitAuthType.values.firstWhere(
      (e) => e.id == val,
      orElse: () => GitAuthType.token,
    );
  }
}

/// Git 云端账号模型
class GitAccount {
  final String id;
  final GitPlatform platform;
  final String username;
  final String displayName;
  final String email;
  final GitAuthType authType;
  final String token;
  final String? sshKeyId;
  final String serverUrl;
  final String? avatarUrl;
  final bool isDefault;
  final DateTime createdAt;

  const GitAccount({
    required this.id,
    required this.platform,
    required this.username,
    this.displayName = '',
    this.email = '',
    this.authType = GitAuthType.token,
    this.token = '',
    this.sshKeyId,
    required this.serverUrl,
    this.avatarUrl,
    this.isDefault = false,
    required this.createdAt,
  });

  String get effectiveName => displayName.trim().isNotEmpty ? displayName.trim() : username;

  factory GitAccount.fromJson(Map<String, dynamic> json) {
    return GitAccount(
      id: json['id'] as String? ?? '',
      platform: GitPlatform.fromString(json['platform'] as String?),
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      authType: GitAuthType.fromString(json['authType'] as String?),
      token: json['token'] as String? ?? '',
      sshKeyId: json['sshKeyId'] as String?,
      serverUrl: json['serverUrl'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platform': platform.id,
      'username': username,
      'displayName': displayName,
      'email': email,
      'authType': authType.id,
      'token': token,
      'sshKeyId': sshKeyId,
      'serverUrl': serverUrl,
      'avatarUrl': avatarUrl,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  GitAccount copyWith({
    String? id,
    GitPlatform? platform,
    String? username,
    String? displayName,
    String? email,
    GitAuthType? authType,
    String? token,
    String? sshKeyId,
    String? serverUrl,
    String? avatarUrl,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return GitAccount(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      authType: authType ?? this.authType,
      token: token ?? this.token,
      sshKeyId: sshKeyId ?? this.sshKeyId,
      serverUrl: serverUrl ?? this.serverUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
