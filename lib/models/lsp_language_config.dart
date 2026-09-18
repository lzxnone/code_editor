class LspLanguageConfig {
  final String id;
  final String name;
  final String languageId;
  final List<String> fileExtensions;
  final String serverCommand;
  final List<String> serverArgs;
  final String package;
  final String? installCommand;
  final String? uninstallCommand;
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
    this.installCommand,
    this.uninstallCommand,
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
      installCommand: json['installCommand'] as String?,
      uninstallCommand: json['uninstallCommand'] as String?,
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
      'installCommand': installCommand,
      'uninstallCommand': uninstallCommand,
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
    String? installCommand,
    String? uninstallCommand,
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
      installCommand: installCommand ?? this.installCommand,
      uninstallCommand: uninstallCommand ?? this.uninstallCommand,
      enabled: enabled ?? this.enabled,
    );
  }

  /// 官方内置语言支持模版（基于 Ubuntu 官方 apt 工具链与各语言官方分发渠道，仅作探测与安装指引，不默认写入用户配置）
  static List<LspLanguageConfig> get builtinPresets => [
        const LspLanguageConfig(
          id: 'c_cpp',
          name: 'C / C++',
          languageId: 'cpp',
          fileExtensions: ['.c', '.cpp', '.cc', '.cxx', '.h', '.hpp', '.hxx', '.hh'],
          serverCommand: 'clangd',
          serverArgs: ['--background-index'],
          package: 'clangd',
          installCommand: 'apt-get update && apt-get install -y --no-install-recommends clangd',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'python',
          name: 'Python',
          languageId: 'python',
          fileExtensions: ['.py', '.pyw', '.pyi'],
          serverCommand: 'pylsp',
          serverArgs: [],
          package: 'python3-pylsp',
          installCommand: 'apt-get update && apt-get install -y --no-install-recommends python3-pylsp',
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
          installCommand: 'apt-get update && apt-get install -y --no-install-recommends rust-analyzer',
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
          installCommand: 'apt-get update && apt-get install -y --no-install-recommends gopls',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'shell',
          name: 'Shell Script',
          languageId: 'shellscript',
          fileExtensions: ['.sh', '.bash', '.zsh', '.ksh'],
          serverCommand: 'bash-language-server',
          serverArgs: ['start'],
          package: 'bash-language-server',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm shellcheck shfmt && npm install -g bash-language-server',
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
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends default-jdk curl tar && mkdir -p /opt/jdtls && curl -sSL https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz | tar -xz -C /opt/jdtls && ln -sf /opt/jdtls/bin/jdtls /usr/local/bin/jdtls',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'javascript',
          name: 'JavaScript',
          languageId: 'javascript',
          fileExtensions: ['.js', '.jsx', '.mjs', '.cjs'],
          serverCommand: 'typescript-language-server',
          serverArgs: ['--stdio'],
          package: 'typescript-language-server',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g typescript-language-server typescript',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'typescript',
          name: 'TypeScript',
          languageId: 'typescript',
          fileExtensions: ['.ts', '.mts', '.cts', '.tsx'],
          serverCommand: 'typescript-language-server',
          serverArgs: ['--stdio'],
          package: 'typescript-language-server',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g typescript-language-server typescript',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'html',
          name: 'HTML',
          languageId: 'html',
          fileExtensions: ['.html', '.htm', '.xhtml'],
          serverCommand: 'vscode-html-language-server',
          serverArgs: ['--stdio'],
          package: 'vscode-langservers-extracted',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g vscode-langservers-extracted',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'css',
          name: 'CSS / SCSS / LESS',
          languageId: 'css',
          fileExtensions: ['.css', '.scss', '.less'],
          serverCommand: 'vscode-css-language-server',
          serverArgs: ['--stdio'],
          package: 'vscode-langservers-extracted',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g vscode-langservers-extracted',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'json',
          name: 'JSON',
          languageId: 'json',
          fileExtensions: ['.json', '.jsonc'],
          serverCommand: 'vscode-json-language-server',
          serverArgs: ['--stdio'],
          package: 'vscode-langservers-extracted',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g vscode-langservers-extracted',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'yaml',
          name: 'YAML',
          languageId: 'yaml',
          fileExtensions: ['.yaml', '.yml'],
          serverCommand: 'yaml-language-server',
          serverArgs: ['--stdio'],
          package: 'yaml-language-server',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g yaml-language-server',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'markdown',
          name: 'Markdown',
          languageId: 'markdown',
          fileExtensions: ['.md', '.markdown'],
          serverCommand: 'vscode-markdown-languageserver',
          serverArgs: ['--stdio'],
          package: 'vscode-markdown-languageserver',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g vscode-markdown-languageserver',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'cmake',
          name: 'CMake',
          languageId: 'cmake',
          fileExtensions: ['.cmake', 'CMakeLists.txt'],
          serverCommand: 'cmake-language-server',
          serverArgs: [],
          package: 'cmake-language-server',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends python3-pip && pip3 install --break-system-packages cmake-language-server',
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
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends curl tar gzip && ARCH=\$(dpkg --print-architecture) && if [ "\$ARCH" = "arm64" ]; then LARCH="arm64"; else LARCH="x64"; fi && mkdir -p /opt/lua-language-server && curl -sSL https://github.com/LuaLS/lua-language-server/releases/download/3.13.6/lua-language-server-3.13.6-linux-\$LARCH.tar.gz | tar -xz -C /opt/lua-language-server && ln -sf /opt/lua-language-server/bin/lua-language-server /usr/local/bin/lua-language-server',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'php',
          name: 'PHP',
          languageId: 'php',
          fileExtensions: ['.php', '.phtml', '.php3', '.php4', '.php5'],
          serverCommand: 'intelephense',
          serverArgs: ['--stdio'],
          package: 'intelephense',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g intelephense',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'ruby',
          name: 'Ruby',
          languageId: 'ruby',
          fileExtensions: ['.rb', '.rake', '.gemspec'],
          serverCommand: 'solargraph',
          serverArgs: ['stdio'],
          package: 'solargraph',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends ruby ruby-dev build-essential && gem install solargraph',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'kotlin',
          name: 'Kotlin',
          languageId: 'kotlin',
          fileExtensions: ['.kt', '.kts'],
          serverCommand: 'kotlin-language-server',
          serverArgs: [],
          package: 'kotlin-language-server',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends default-jre curl unzip && mkdir -p /opt/kotlin-language-server && curl -sSL https://github.com/fwcd/kotlin-language-server/releases/latest/download/server.zip -o /tmp/kls.zip && unzip -o /tmp/kls.zip -d /opt/kotlin-language-server && ln -sf /opt/kotlin-language-server/bin/kotlin-language-server /usr/local/bin/kotlin-language-server && rm -f /tmp/kls.zip',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'swift',
          name: 'Swift',
          languageId: 'swift',
          fileExtensions: ['.swift'],
          serverCommand: 'sourcekit-lsp',
          serverArgs: [],
          package: 'sourcekit-lsp',
          installCommand: 'echo "Please install swift toolchain containing sourcekit-lsp for your Linux distro."',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'csharp',
          name: 'C#',
          languageId: 'csharp',
          fileExtensions: ['.cs'],
          serverCommand: 'csharp-ls',
          serverArgs: [],
          package: 'csharp-ls',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends dotnet-sdk-8.0 && dotnet tool install --global csharp-ls && ln -sf /root/.dotnet/tools/csharp-ls /usr/local/bin/csharp-ls',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'dart',
          name: 'Dart',
          languageId: 'dart',
          fileExtensions: ['.dart'],
          serverCommand: 'dart',
          serverArgs: ['language-server', '--protocol=lsp'],
          package: 'dart',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends apt-transport-https curl gnupg && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/dart.gpg --yes && echo "deb [signed-by=/usr/share/keyrings/dart.gpg] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" > /etc/apt/sources.list.d/dart_stable.list && apt-get update && apt-get install -y dart',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'sql',
          name: 'SQL',
          languageId: 'sql',
          fileExtensions: ['.sql'],
          serverCommand: 'sql-language-server',
          serverArgs: ['up', '--method', 'stdio'],
          package: 'sql-language-server',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g sql-language-server',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'xml',
          name: 'XML',
          languageId: 'xml',
          fileExtensions: ['.xml', '.svg', '.plist', '.xsd', '.xaml'],
          serverCommand: 'lemminx',
          serverArgs: [],
          package: 'lemminx',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends default-jre curl && ARCH=\$(dpkg --print-architecture) && curl -sSL -o /usr/local/bin/lemminx "https://download.eclipse.org/lemminx/releases/0.27.0/lemminx-linux-\$ARCH" && chmod +x /usr/local/bin/lemminx',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'dockerfile',
          name: 'Dockerfile',
          languageId: 'dockerfile',
          fileExtensions: ['.dockerfile', 'Dockerfile'],
          serverCommand: 'docker-langserver',
          serverArgs: ['--stdio'],
          package: 'dockerfile-language-server-nodejs',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g dockerfile-language-server-nodejs',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'toml',
          name: 'TOML',
          languageId: 'toml',
          fileExtensions: ['.toml'],
          serverCommand: 'taplo',
          serverArgs: ['lsp', 'stdio'],
          package: 'taplo',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends curl gzip && ARCH=\$(dpkg --print-architecture) && if [ "\$ARCH" = "arm64" ]; then TARCH="aarch64"; else TARCH="x86_64"; fi && curl -sSL "https://github.com/tamasfe/taplo/releases/download/0.9.3/taplo-full-linux-\$TARCH.gz" | gzip -d > /usr/local/bin/taplo && chmod +x /usr/local/bin/taplo',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'r',
          name: 'R',
          languageId: 'r',
          fileExtensions: ['.r', '.R'],
          serverCommand: 'R',
          serverArgs: ['--slave', '-e', 'languageserver::run()'],
          package: 'r-base',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends r-base && R -e "install.packages(\'languageserver\', repos=\'https://cloud.r-project.org\')"',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'perl',
          name: 'Perl',
          languageId: 'perl',
          fileExtensions: ['.pl', '.pm'],
          serverCommand: 'perl',
          serverArgs: ['-MPerl::LanguageServer', '-e', 'Perl::LanguageServer::run'],
          package: 'libperl-languageserver-perl',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends libperl-languageserver-perl',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'zig',
          name: 'Zig',
          languageId: 'zig',
          fileExtensions: ['.zig'],
          serverCommand: 'zls',
          serverArgs: [],
          package: 'zls',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends curl xz-utils && ARCH=\$(dpkg --print-architecture) && if [ "\$ARCH" = "arm64" ]; then ZARCH="aarch64"; else ZARCH="x86_64"; fi && curl -sSL "https://zigtools.org/zls/downloads/\$ZARCH-linux/bin/zls" -o /usr/local/bin/zls && chmod +x /usr/local/bin/zls',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'vue',
          name: 'Vue',
          languageId: 'vue',
          fileExtensions: ['.vue'],
          serverCommand: 'vue-language-server',
          serverArgs: ['--stdio'],
          package: '@vue/language-server',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g @vue/language-server typescript',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'svelte',
          name: 'Svelte',
          languageId: 'svelte',
          fileExtensions: ['.svelte'],
          serverCommand: 'svelteserver',
          serverArgs: ['--stdio'],
          package: 'svelte-language-server',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g svelte-language-server typescript',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'tex',
          name: 'LaTeX',
          languageId: 'latex',
          fileExtensions: ['.tex', '.latex', '.sty', '.cls'],
          serverCommand: 'texlab',
          serverArgs: [],
          package: 'texlab',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends curl tar gzip && ARCH=\$(dpkg --print-architecture) && if [ "\$ARCH" = "arm64" ]; then TARCH="aarch64"; else TARCH="x86_64"; fi && curl -sSL "https://github.com/latex-lsp/texlab/releases/latest/download/texlab-\$TARCH-linux.tar.gz" | tar -xz -C /usr/local/bin/ && chmod +x /usr/local/bin/texlab',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'graphql',
          name: 'GraphQL',
          languageId: 'graphql',
          fileExtensions: ['.graphql', '.gql'],
          serverCommand: 'graphql-lsp',
          serverArgs: ['server', '-m', 'stream'],
          package: 'graphql-language-service-cli',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g graphql-language-service-cli',
          enabled: true,
        ),
        const LspLanguageConfig(
          id: 'protobuf',
          name: 'Protocol Buffers',
          languageId: 'proto',
          fileExtensions: ['.proto'],
          serverCommand: 'bufls',
          serverArgs: ['serve'],
          package: 'bufls',
          installCommand:
              'apt-get update && apt-get install -y --no-install-recommends npm && npm install -g @bufbuild/buf && ln -sf \$(which buf) /usr/local/bin/bufls',
          enabled: true,
        ),
      ];

  /// 保持向后兼容别名
  static List<LspLanguageConfig> get defaultPresets => builtinPresets;

  /// 根据文件后缀或特殊文件名从内置预设模版中匹配支持的语言
  static LspLanguageConfig? findBuiltinByExtension(String ext, {String? filename}) {
    final cleanName = filename?.trim().toLowerCase();
    if (cleanName != null && cleanName.isNotEmpty) {
      for (final preset in builtinPresets) {
        for (final item in preset.fileExtensions) {
          if (!item.startsWith('.') && item.toLowerCase() == cleanName) {
            return preset;
          }
        }
      }
    }

    if (ext.isEmpty) return null;
    final normalized = ext.startsWith('.') ? ext.toLowerCase() : '.$ext'.toLowerCase();
    for (final preset in builtinPresets) {
      for (final item in preset.fileExtensions) {
        if (item.startsWith('.')) {
          final itemNorm = item.toLowerCase();
          if (itemNorm == normalized) {
            return preset;
          }
        }
      }
    }
    return null;
  }
}
