class LspLanguageConfig {
  final String id;
  final String name;
  final String languageId;
  final List<String> fileExtensions;
  final String serverCommand;
  final List<String> serverArgs;
  final String package;
  final bool enabled;

  /// 兼容别名
  String get apkPackage => package;
  String get aptPackage => package;

  const LspLanguageConfig({
    required this.id,
    required this.name,
    required this.languageId,
    required this.fileExtensions,
    required this.serverCommand,
    this.serverArgs = const [],
    required this.package,
    this.enabled = true,
  });

  factory LspLanguageConfig.fromJson(Map<String, dynamic> json) {
    final pkg = (json['package'] ?? json['aptPackage'] ?? json['apkPackage']) as String? ?? '';
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
      package: pkg,
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
      'package': package,
      'apkPackage': package,
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
    String? package,
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
      package: package ?? apkPackage ?? this.package,
      enabled: enabled ?? this.enabled,
    );
  }

  /// 官方内置语言支持模版（基于 Ubuntu 官方 apt 工具链，仅作探测与安装指引，不默认写入用户配置）
  static List<LspLanguageConfig> get builtinPresets => [
        const LspLanguageConfig(
          id: 'c_cpp',
          name: 'C / C++',
          languageId: 'cpp',
          fileExtensions: ['.c', '.cpp', '.cc', '.cxx', '.h', '.hpp'],
          serverCommand: 'clangd',
          serverArgs: ['--background-index'],
          package: 'clangd',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'python',
          name: 'Python',
          languageId: 'python',
          fileExtensions: ['.py'],
          serverCommand: 'pylsp',
          serverArgs: [],
          package: 'python3-pylsp',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'rust',
          name: 'Rust',
          languageId: 'rust',
          fileExtensions: ['.rs'],
          serverCommand: 'rust-analyzer',
          serverArgs: [],
          package: 'rust-analyzer',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'go',
          name: 'Go',
          languageId: 'go',
          fileExtensions: ['.go'],
          serverCommand: 'gopls',
          serverArgs: [],
          package: 'gopls',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'shell',
          name: 'Shell Script',
          languageId: 'shellscript',
          fileExtensions: ['.sh', '.bash'],
          serverCommand: 'bash-language-server',
          serverArgs: ['start'],
          package: 'bash-language-server',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'java',
          name: 'Java',
          languageId: 'java',
          fileExtensions: ['.java'],
          serverCommand: 'jdtls',
          serverArgs: [],
          package: 'jdtls',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'typescript',
          name: 'TypeScript',
          languageId: 'typescript',
          fileExtensions: ['.ts', '.mts', '.tsx'],
          serverCommand: 'typescript-language-server',
          serverArgs: ['--stdio'],
          package: 'typescript-language-server',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'lua',
          name: 'Lua',
          languageId: 'lua',
          fileExtensions: ['.lua'],
          serverCommand: 'lua-language-server',
          serverArgs: [],
          package: 'lua-language-server',
          enabled: true,
        ),
      ];

  /// 保持向后兼容别名
  static List<LspLanguageConfig> get defaultPresets => builtinPresets;

  /// 根据文件后缀从内置预设模版中匹配支持的语言
  static LspLanguageConfig? findBuiltinByExtension(String ext) {
    if (ext.isEmpty) return null;
    final normalized = ext.startsWith('.') ? ext.toLowerCase() : '.$ext'.toLowerCase();
    for (final preset in builtinPresets) {
      for (final item in preset.fileExtensions) {
        final itemNorm = item.startsWith('.') ? item.toLowerCase() : '.$item'.toLowerCase();
        if (itemNorm == normalized) {
          return preset;
        }
      }
    }
    return null;
  }
}
