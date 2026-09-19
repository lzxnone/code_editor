import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/distro_manifest.dart';
import '../models/git_account.dart';
import 'distro_manager.dart';
import 'internal_engine_service.dart';
import 'toolchain_service.dart';

/// Git 账号与远程凭据管理服务
class GitAccountService extends ChangeNotifier {
  static final GitAccountService instance = GitAccountService._internal();
  GitAccountService._internal();

  List<GitAccount> _accounts = [];
  bool _isLoaded = false;

  List<GitAccount> get accounts => List.unmodifiable(_accounts);
  bool get isLoaded => _isLoaded;

  /// 测试自定义配置文件目录
  @visibleForTesting
  Directory? customBaseDir;

  /// 获取配置文件路径: `<files>/config/git_accounts.json`
  Future<File> getConfigFile() async {
    final Directory baseDir;
    if (customBaseDir != null) {
      baseDir = customBaseDir!;
    } else {
      final appDir = await getApplicationSupportDirectory();
      final rootPath = p.basename(appDir.path) == 'files'
          ? appDir.path
          : p.join(appDir.path, 'files');
      baseDir = Directory(p.join(rootPath, 'config'));
    }

    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
    return File(p.join(baseDir.path, 'git_accounts.json'));
  }

  /// 获取宿主持久化保存 SSH 密钥的目录: `<files>/ssh/`
  Future<Directory> getPersistentSshDir() async {
    final Directory sshDir;
    if (customBaseDir != null) {
      sshDir = Directory(p.join(customBaseDir!.path, 'ssh'));
    } else {
      final appDir = await getApplicationSupportDirectory();
      final rootPath = p.basename(appDir.path) == 'files'
          ? appDir.path
          : p.join(appDir.path, 'files');
      sshDir = Directory(p.join(rootPath, 'ssh'));
    }
    if (!sshDir.existsSync()) {
      sshDir.createSync(recursive: true);
    }
    return sshDir;
  }

  /// 加载所有保存的账号
  Future<List<GitAccount>> loadAccounts({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) {
      return _accounts;
    }

    final file = await getConfigFile();
    if (!file.existsSync()) {
      _accounts = [];
      _isLoaded = true;
      notifyListeners();
      return _accounts;
    }

    try {
      final text = file.readAsStringSync().trim();
      if (text.isNotEmpty) {
        final dynamic raw = jsonDecode(text);
        if (raw is List) {
          _accounts = raw
              .map((e) => e is Map<String, dynamic> ? GitAccount.fromJson(e) : null)
              .whereType<GitAccount>()
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[GitAccountService] 读取账号配置异常: $e');
      _accounts = [];
    }

    _isLoaded = true;
    notifyListeners();
    return _accounts;
  }

  /// 保存并持久化账号列表
  Future<void> _saveToDisk() async {
    final file = await getConfigFile();
    final jsonList = _accounts.map((a) => a.toJson()).toList();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
    notifyListeners();
    // 账号发生变更，需要强制重新灌注容器凭据
    _credentialsSyncedThisSession = false;
    await syncContainerCredentials();
    _credentialsSyncedThisSession = true;
  }

  /// 确保容器内的 ~/.git-credentials 与本机保存的账号一致（每次 App 会话至多做一次）
  ///
  /// 云端网络操作（fetch/pull/push）执行前调用：容器被重建后凭据文件会随 rootfs
  /// 一起丢失，若不重写，git 会立刻因缺少凭据而报认证失败。
  /// 不需要每次操作都同步，因此按会话缓存；账号增删改时由 [_saveToDisk] 强制刷新。
  static bool _credentialsSyncedThisSession = false;

  Future<void> ensureContainerCredentials() async {
    if (_credentialsSyncedThisSession) return;
    try {
      await loadAccounts();
      await syncContainerCredentials();
      _credentialsSyncedThisSession = true;
    } catch (e) {
      debugPrint('[GitAccountService] 确保容器凭据异常: $e');
    }
  }

  /// 容器重建后需要重新灌注凭据
  void invalidateCredentialSync() {
    _credentialsSyncedThisSession = false;
  }

  /// 将所有已保存的账号凭据同步写入容器的 ~/.git-credentials，使容器内终端与 UI 操作均免密生效
  Future<void> syncContainerCredentials() async {
    try {
      // 仅 Android 的内置容器需要落盘凭据；宿主/桌面环境不走这条路径
      if (!Platform.isAndroid) return;

      final engine = InternalEngineService.instance;
      if (!await engine.isEngineInstalled()) return;

      final rootfs = await engine.getRootfsDir();
      final credFile = File(p.join(rootfs.path, 'root', '.git-credentials'));
      final lines = <String>[];
      for (final acc in _accounts) {
        if (acc.token.isNotEmpty) {
          final uri = Uri.tryParse(acc.serverUrl.isNotEmpty ? acc.serverUrl : acc.platform.defaultServerUrl);
          final host = uri?.host ?? 'github.com';
          final user = Uri.encodeComponent(acc.username);
          final pass = Uri.encodeComponent(acc.token);
          lines.add('https://$user:$pass@$host');
        }
      }
      credFile.parent.createSync(recursive: true);
      // 末尾补换行：git 的 store helper 按行解析，缺少结尾换行虽可容错，
      // 但会让 `cat` / `sed` 等排查手段把提示符粘在最后一行，容易误判。
      final content = lines.isEmpty ? '' : '${lines.join('\n')}\n';
      await credFile.writeAsString(content);

      // 确保全局开启 credential.helper store
      await DistroManager().runHeadlessCommand(
        systemName: DistroRepository.defaultSystemName,
        customRootDir: rootfs,
        command: 'git config --global credential.helper store',
      );
    } catch (e) {
      debugPrint('[GitAccountService] 同步容器凭据异常: $e');
    }
  }

  /// 添加或更新账号
  Future<void> saveAccount(GitAccount account) async {
    await loadAccounts();
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index >= 0) {
      _accounts[index] = account;
    } else {
      // 若这是该平台的第一个账号，默认设为默认
      final samePlatform = _accounts.where((a) => a.platform == account.platform);
      if (samePlatform.isEmpty) {
        account = account.copyWith(isDefault: true);
      }
      _accounts.add(account);
    }

    if (account.isDefault) {
      _setDefaultAccountInternal(account.id, account.platform);
    }

    await _saveToDisk();
  }

  /// 删除账号
  Future<void> deleteAccount(String accountId) async {
    await loadAccounts();
    _accounts.removeWhere((a) => a.id == accountId);
    await _saveToDisk();
  }

  /// 将某账号设为对应平台的默认账号
  Future<void> setDefaultAccount(String accountId) async {
    await loadAccounts();
    final account = _accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return;
    _setDefaultAccountInternal(accountId, account.platform);
    await _saveToDisk();
  }

  void _setDefaultAccountInternal(String targetId, GitPlatform platform) {
    for (int i = 0; i < _accounts.length; i++) {
      if (_accounts[i].platform == platform) {
        _accounts[i] = _accounts[i].copyWith(isDefault: _accounts[i].id == targetId);
      }
    }
  }

  /// 根据远程 URL 自动匹配最合适的账号（优先匹配 Host 与默认账号）
  GitAccount? findAccountForUrl(String remoteUrl) {
    if (_accounts.isEmpty) return null;
    final cleanUrl = remoteUrl.trim().toLowerCase();

    if (cleanUrl.contains('github.com')) {
      return _accounts.firstWhere(
        (a) => a.platform == GitPlatform.github && a.isDefault,
        orElse: () => _accounts.firstWhere(
          (a) => a.platform == GitPlatform.github,
          orElse: () => _accounts.first,
        ),
      );
    }

    if (cleanUrl.contains('gitee.com')) {
      return _accounts.firstWhere(
        (a) => a.platform == GitPlatform.gitee && a.isDefault,
        orElse: () => _accounts.firstWhere(
          (a) => a.platform == GitPlatform.gitee,
          orElse: () => _accounts.first,
        ),
      );
    }

    if (cleanUrl.contains('gitlab')) {
      return _accounts.firstWhere(
        (a) => a.platform == GitPlatform.gitlab && a.isDefault,
        orElse: () => _accounts.firstWhere(
          (a) => a.platform == GitPlatform.gitlab,
          orElse: () => _accounts.first,
        ),
      );
    }

    // 通用自建 Git 匹配 serverUrl 域名
    for (final acc in _accounts) {
      if (acc.serverUrl.isNotEmpty) {
        final host = Uri.tryParse(acc.serverUrl)?.host.toLowerCase();
        if (host != null && host.isNotEmpty && cleanUrl.contains(host)) {
          return acc;
        }
      }
    }

    return _accounts.where((a) => a.isDefault).firstOrNull ?? _accounts.firstOrNull;
  }

  /// 验证 Token 并从平台获取真实用户信息（用户名、邮箱、头像等）
  Future<({bool success, String? username, String? displayName, String? email, String? avatarUrl, String? error})>
      verifyTokenAndFetchUserInfo(
    GitPlatform platform,
    String token, {
    String? customServerUrl,
  }) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      return (
        success: false,
        username: null,
        displayName: null,
        email: null,
        avatarUrl: null,
        error: '令牌不能为空'
      );
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);

    try {
      final Uri targetUri;
      final Map<String, String> headers = {
        'User-Agent': 'CodeEditorApp-Mobile/1.0',
        'Accept': 'application/json',
      };

      switch (platform) {
        case GitPlatform.github:
          targetUri = Uri.parse('${GitPlatform.github.apiBaseUrl}/user');
          headers['Authorization'] = 'Bearer $cleanToken';
          headers['Accept'] = 'application/vnd.github+json';
          break;

        case GitPlatform.gitee:
          targetUri = Uri.parse('${GitPlatform.gitee.apiBaseUrl}/user?access_token=$cleanToken');
          break;

        case GitPlatform.gitlab:
        case GitPlatform.generic:
          final base = (customServerUrl != null && customServerUrl.trim().isNotEmpty)
              ? customServerUrl.trim().replaceAll(RegExp(r'/+$'), '')
              : GitPlatform.gitlab.defaultServerUrl;
          targetUri = Uri.parse('$base/api/v4/user');
          headers['PRIVATE-TOKEN'] = cleanToken;
          break;
      }

      final request = await client.getUrl(targetUri);
      headers.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close();

      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic data = jsonDecode(body);
        if (data is Map<String, dynamic>) {
          final username = (data['login'] ?? data['username'] ?? '').toString();
          final displayName = (data['name'] ?? username).toString();
          final email = (data['email'] ?? '').toString();
          final avatarUrl = (data['avatar_url'] ?? data['avatarUrl'] ?? '').toString();
          return (
            success: true,
            username: username.isNotEmpty ? username : displayName,
            displayName: displayName,
            email: email,
            avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
            error: null,
          );
        }
      }

      final dynamic errJson = jsonDecode(body);
      final errMsg = errJson is Map ? (errJson['message'] ?? errJson['error_description'] ?? body) : body;
      return (
        success: false,
        username: null,
        displayName: null,
        email: null,
        avatarUrl: null,
        error: '验证失败 (${response.statusCode}): $errMsg',
      );
    } catch (e) {
      debugPrint('[GitAccountService] 验证 Token 网络异常: $e');
      return (
        success: false,
        username: null,
        displayName: null,
        email: null,
        avatarUrl: null,
        error: '网络连接异常: $e',
      );
    } finally {
      client.close();
    }
  }

  /// 备份容器内的 SSH 密钥至宿主持久化目录，防止容器重置/重建丢失
  Future<void> _backupSshKeysToHost(Directory rootfs) async {
    try {
      final sshDir = await getPersistentSshDir();
      final privFile = File(p.join(rootfs.path, 'root', '.ssh', 'id_ed25519'));
      final pubFile = File(p.join(rootfs.path, 'root', '.ssh', 'id_ed25519.pub'));

      if (privFile.existsSync()) {
        privFile.copySync(p.join(sshDir.path, 'id_ed25519'));
      }
      if (pubFile.existsSync()) {
        pubFile.copySync(p.join(sshDir.path, 'id_ed25519.pub'));
      }
    } catch (e) {
      debugPrint('[GitAccountService] 备份 SSH 密钥到宿主异常: $e');
    }
  }

  /// 当容器重建时，将宿主持久化目录的 SSH 密钥还原至容器内
  Future<bool> _restoreSshKeysToContainer(Directory rootfs, Directory hostSshDir) async {
    try {
      final containerSshDir = Directory(p.join(rootfs.path, 'root', '.ssh'));
      if (!containerSshDir.existsSync()) {
        containerSshDir.createSync(recursive: true);
      }

      final hostPriv = File(p.join(hostSshDir.path, 'id_ed25519'));
      final hostPub = File(p.join(hostSshDir.path, 'id_ed25519.pub'));

      if (hostPriv.existsSync()) {
        hostPriv.copySync(p.join(containerSshDir.path, 'id_ed25519'));
      }
      if (hostPub.existsSync()) {
        hostPub.copySync(p.join(containerSshDir.path, 'id_ed25519.pub'));
      }

      // 修复容器内文件权限（私钥 600，公钥 644，目录 700）
      await DistroManager().runHeadlessCommand(
        systemName: DistroRepository.defaultSystemName,
        customRootDir: rootfs,
        command: 'chmod 700 /root/.ssh 2>/dev/null; chmod 600 /root/.ssh/id_ed25519 2>/dev/null; chmod 644 /root/.ssh/id_ed25519.pub 2>/dev/null || true',
        timeout: const Duration(seconds: 10),
      );
      return true;
    } catch (e) {
      debugPrint('[GitAccountService] 还原 SSH 密钥至容器异常: $e');
      return false;
    }
  }

  /// 读取 SSH 公钥内容（若容器重建，自动从宿主持久化目录恢复）
  Future<String?> getSshPublicKey() async {
    try {
      final sshDir = await getPersistentSshDir();
      final hostPubFile = File(p.join(sshDir.path, 'id_ed25519.pub'));

      final engine = InternalEngineService.instance;
      if (await engine.isEngineInstalled()) {
        final rootfs = await engine.getRootfsDir();
        final containerSshDir = Directory(p.join(rootfs.path, 'root', '.ssh'));
        final containerPubFile = File(p.join(containerSshDir.path, 'id_ed25519.pub'));

        // 1. 若容器内已存在公钥，返回公钥，并确保宿主已备份
        if (containerPubFile.existsSync()) {
          final content = containerPubFile.readAsStringSync().trim();
          if (!hostPubFile.existsSync() && content.isNotEmpty) {
            await _backupSshKeysToHost(rootfs);
          }
          return content;
        }

        // 2. 若容器被重置/重建（容器内无密钥），但宿主持久化目录存有备份，自动还原进容器！
        if (hostPubFile.existsSync()) {
          await _restoreSshKeysToContainer(rootfs, sshDir);
          return hostPubFile.readAsStringSync().trim();
        }

        // 尝试 rsa
        final rsaPubFile = File(p.join(containerSshDir.path, 'id_rsa.pub'));
        if (rsaPubFile.existsSync()) {
          return rsaPubFile.readAsStringSync().trim();
        }
      }

      // 3. 若容器未安装或未运行，宿主持久化目录若有公钥，直接返回展示
      if (hostPubFile.existsSync()) {
        return hostPubFile.readAsStringSync().trim();
      }

      return null;
    } catch (e) {
      debugPrint('[GitAccountService] 获取 SSH 公钥异常: $e');
      return null;
    }
  }

  /// 在容器内一键生成 Ed25519 SSH 密钥对（生成后自动持久化备份到宿主目录）
  Future<({bool success, String? publicKey, String? error})> generateSshKeyPair({String? email}) async {
    try {
      final engine = InternalEngineService.instance;
      if (!await engine.isEngineInstalled()) {
        return (success: false, publicKey: null, error: '内置运行容器未安装');
      }

      final rootfs = await engine.getRootfsDir();
      final comment = email?.trim().isNotEmpty == true ? email!.trim() : 'code-editor-mobile';
      final cmd = '''
${ToolchainService.dpkgAutoHealPrefix}
if ! command -v ssh-keygen >/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends openssh-client
fi
if ! command -v ssh-keygen >/dev/null 2>&1; then
  echo "未找到 ssh-keygen 命令，自动安装 openssh-client 失败，请检查网络后重试" >&2
  exit 1
fi
mkdir -p /root/.ssh && chmod 700 /root/.ssh
rm -f /root/.ssh/id_ed25519 /root/.ssh/id_ed25519.pub
ssh-keygen -t ed25519 -N "" -C "$comment" -f /root/.ssh/id_ed25519
chmod 600 /root/.ssh/id_ed25519
cat /root/.ssh/id_ed25519.pub
''';

      final res = await DistroManager().runHeadlessCommand(
        systemName: DistroRepository.defaultSystemName,
        customRootDir: rootfs,
        command: cmd,
        timeout: const Duration(seconds: 120),
      );

      if (res != null && res.exitCode == 0) {
        // 同步备份至宿主持久化目录，确保容器重置时不会丢失
        await _backupSshKeysToHost(rootfs);
        final pubKey = await getSshPublicKey();
        return (success: true, publicKey: pubKey, error: null);
      } else {
        final errText = res?.stderr.toString().trim();
        final outText = res?.stdout.toString().trim();
        final errMsg = (errText != null && errText.isNotEmpty)
            ? errText
            : ((outText != null && outText.isNotEmpty) ? outText : '生成 SSH 密钥失败');
        return (success: false, publicKey: null, error: errMsg);
      }
    } catch (e) {
      debugPrint('[GitAccountService] 生成 SSH 密钥异常: $e');
      return (success: false, publicKey: null, error: e.toString());
    }
  }
}
