class LspLanguageConfig {
  final String id;
  final String name;
  final String languageId;
  final List<String> fileExtensions;
  final String serverCommand;
  final List<String> serverArgs;
  final String apkPackage;
  final bool enabled;

  const LspLanguageConfig({
    required this.id,
    required this.name,
    required this.languageId,
    required this.fileExtensions,
    required this.serverCommand,
    this.serverArgs = const [],
    required this.apkPackage,
    this.enabled = true,
  });

  factory LspLanguageConfig.fromJson(Map<String, dynamic> json) {
    return LspLanguageConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      languageId: json['languageId'] as String? ?? '',
      fileExtensions: (json['fileExtensions'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      serverCommand: json['serverCommand'] as String? ?? '',
      serverArgs: (json['serverArgs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      apkPackage: json['apkPackage'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'languageId': languageId,
      'fileExtensions': fileExtensions,
      'serverCommand': serverCommand,
      'serverArgs': serverArgs,
      'apkPackage': apkPackage,
      'enabled': enabled,
    };
  }

  LspLanguageConfig copyWith({
    String? id,
    String? name,
    String? languageId,
    List<String>? fileExtensions,
    String? serverCommand,
    List<String>? serverArgs,
    String? apkPackage,
    bool? enabled,
  }) {
    return LspLanguageConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      languageId: languageId ?? this.languageId,
      fileExtensions: fileExtensions ?? this.fileExtensions,
      serverCommand: serverCommand ?? this.serverCommand,
      serverArgs: serverArgs ?? this.serverArgs,
      apkPackage: apkPackage ?? this.apkPackage,
      enabled: enabled ?? this.enabled,
    );
  }

  /// 官方默认预设语言列表
  static List<LspLanguageConfig> get defaultPresets => [
        const LspLanguageConfig(
          id: 'c_cpp',
          name: 'C / C++',
          languageId: 'cpp',
          fileExtensions: ['.c', '.cpp', '.cc', '.cxx', '.h', '.hpp'],
          serverCommand: 'clangd',
          serverArgs: ['--background-index'],
          apkPackage: 'clang-extra-tools',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'python',
          name: 'Python',
          languageId: 'python',
          fileExtensions: ['.py'],
          serverCommand: 'pylsp',
          serverArgs: [],
          apkPackage: 'py3-lsp-server',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'rust',
          name: 'Rust',
          languageId: 'rust',
          fileExtensions: ['.rs'],
          serverCommand: 'rust-analyzer',
          serverArgs: [],
          apkPackage: 'rust-analyzer',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'go',
          name: 'Go',
          languageId: 'go',
          fileExtensions: ['.go'],
          serverCommand: 'gopls',
          serverArgs: [],
          apkPackage: 'gopls',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'shell',
          name: 'Shell Script',
          languageId: 'shellscript',
          fileExtensions: ['.sh', '.bash'],
          serverCommand: 'bash-language-server',
          serverArgs: ['start'],
          apkPackage: 'bash-language-server',
          enabled: true,
        ),
      ];
}
