import '../l10n/app_localizations.dart';

/// Git 云端操作错误分类
///
/// 用于把底层 git 的英文 stderr 归类为可操作的错误类型，并驱动
/// 「一键修复」（如 push 被拒 → 先 Pull）与「去修账号」的按钮显隐。
///
/// 本类**不产生任何面向用户的文案**：所有 message / suggestion 均由 UI 层
/// 通过 [AppLocalizations] 按 [kind] 取词，从而保持与项目其余部分一致的
/// 中英双语能力（见 [GitErrorMapper.describe]）。
enum GitOperationErrorKind {
  /// 非 Git 错误（tarball/success 等）
  none,

  /// 令牌无效或已过期（HTTP 401）
  authFailed,

  /// 账号对该仓库没有写权限（HTTP 403，典型为推送别人的上游仓库）
  writePermissionDenied,

  /// 目标仓库不存在，或当前账号无权访问（HTTP 404）
  repositoryNotFound,

  /// 本地路径型远端在容器内不存在（本地裸仓库/目录型 remote 的路径失效）
  localRemotePathMissing,

  /// 需要代理认证（HTTP 407）
  proxyAuthRequired,

  /// 请求被服务器拒绝，通常是推送内容或引用不合法（HTTP 422）
  requestRejected,

  /// 触发平台速率限制（HTTP 429）
  rateLimited,

  /// 其他被服务端拒绝的 HTTP 状态码
  httpError,

  /// 使用账号密码而非 PAT 访问 GitHub 等平台
  passwordAuthDisabled,

  /// 域名无法解析 / 网络不可达
  networkUnreachable,

  /// SSH 公钥未被平台接受
  sshPublicKeyDenied,

  /// SSH 私钥文件权限或缺失
  sshKeyUnusable,

  /// 首次连接未知主机，主机指纹未确认
  hostKeyUnverified,

  /// 推送被拒（远端有新提交，non-fast-forward）
  nonFastForward,

  /// force-with-lease 校验失败（远端已被他人更新）
  staleForcePush,

  /// rebase/merge 冲突
  conflictDetected,

  /// 本地有未提交改动，阻止了操作
  localChangesWouldBeOverwritten,

  /// 未设置上游追踪分支
  noUpstreamConfigured,

  /// 无法获取本地/远端引用锁（.git 被占用）
  refLockFailed,

  /// 磁盘空间不足
  outOfSpace,

  /// 命令超时
  timeout,

  /// 操作未完成，且输出里没有任何真实错误信息
  operationIncomplete,

  /// 其他未归类错误
  unknown,
}

/// 错误可供用户执行的修复动作
enum GitErrorFixAction {
  /// 先拉取（rebase）再推送
  pullThenPush,

  /// 重新抓取远端状态后重试
  fetchAndRetry,

  /// 放弃本次变基
  abortRebase,

  /// 前往 Git 账号管理
  openAccountManagement,

  /// 提示用户先 Fork（在提示文案中说明，无需按钮动作）
  none,
}

/// 单条 Git 错误的**结构化**描述（不含任何本地化文案）
class GitErrorInfo {
  final GitOperationErrorKind kind;

  /// 兜底情况下从原始输出中提取的一条真实错误行（英文原文，直接展示）
  final String? rawDetail;

  /// 建议用户执行的修复动作（由 UI 渲染成按钮）
  final GitErrorFixAction fixAction;

  const GitErrorInfo({
    required this.kind,
    this.rawDetail,
    this.fixAction = GitErrorFixAction.none,
  });

  /// 是否应提供「去修账号」入口
  bool get needsAccountFix =>
      fixAction == GitErrorFixAction.openAccountManagement;

  /// 是否可通过「先 Pull 再 Push」自动修复
  bool get canPullThenPush => fixAction == GitErrorFixAction.pullThenPush;

  /// 是否可通过重新 fetch 后重试修复
  bool get canRefreshThenRetry => fixAction == GitErrorFixAction.fetchAndRetry;

  /// 该错误是否值得给出修复动作按钮
  bool get hasFixAction => fixAction != GitErrorFixAction.none;

  @override
  String toString() => 'GitErrorInfo($kind, fix=${fixAction.name})';
}

/// 将 git stderr/stdout 归类为可操作的错误类型
class GitErrorMapper {
  GitErrorMapper._();

  /// 需要检查冲突的关键字（统一小写，与转小写后的输出比对）
  static const List<String> conflictMarkers = [
    'conflict',
    'automatic merge failed',
    'could not apply',
    'failed to merge',
    'fix conflicts',
    'needs merge',
  ];

  /// 解析命令输出，返回最贴合的错误分类
  ///
  /// [stderr] 优先；[stdout] 在 stderr 为空时兜底（git 部分提示走 stdout）。
  /// 返回结果不含本地化文案，由 UI 层按 [GitErrorInfo.kind] 取词。
  static GitErrorInfo describe(String stderr, {String stdout = ''}) {
    final raw = stderr.trim().isNotEmpty ? stderr : stdout;
    final text = raw.toLowerCase();

    if (text.trim().isEmpty) {
      return const GitErrorInfo(kind: GitOperationErrorKind.operationIncomplete);
    }

    // ---- 1. 强推租约失败（必须先于通用 non-fast-forward 判断）----
    if (text.contains('stale info') ||
        (text.contains('force-with-lease') && text.contains('rejected'))) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.staleForcePush,
        fixAction: GitErrorFixAction.fetchAndRetry,
      );
    }

    // ---- 2. 认证与权限相关（按 HTTP 状态码细分，避免归因错误）----

    // 2a. 平台已禁用密码认证
    // 典型文案：`remote: Support for password authentication was removed on August 13, 2021.`
    if (text.contains('support for password authentication was removed') ||
        text.contains('password authentication was removed') ||
        text.contains('password authentication is not')) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.passwordAuthDisabled,
        fixAction: GitErrorFixAction.openAccountManagement,
      );
    }

    // 2b. HTTP 401：凭证本身无效
    if (text.contains('401') ||
        text.contains('authentication failed') ||
        text.contains('invalid username or password') ||
        text.contains('could not read username') ||
        text.contains('permission denied, please try again') ||
        (text.contains('token') && text.contains('expired'))) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.authFailed,
        fixAction: GitErrorFixAction.openAccountManagement,
      );
    }

    // 2c. HTTP 403 / 明确的无写权限拒绝
    // 最常见场景：origin 直接指向别人的上游仓库（如 ggml-org/llama.cpp）。
    // 读取公开仓库不需要认证，因此拦截发生在推送时——此时令牌通常是好的。
    if (text.contains('403') ||
        (text.contains('permission to') && text.contains('denied')) ||
        text.contains('write access') ||
        text.contains('you do not have permission') ||
        text.contains('protected branch')) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.writePermissionDenied,
        fixAction: GitErrorFixAction.openAccountManagement,
      );
    }

    // 2d. HTTP 407：代理需要认证
    if (text.contains('407') || text.contains('proxy authentication required')) {
      return const GitErrorInfo(kind: GitOperationErrorKind.proxyAuthRequired);
    }

    // 2e. HTTP 429：速率限制
    if (text.contains('429') || text.contains('rate limit')) {
      return const GitErrorInfo(kind: GitOperationErrorKind.rateLimited);
    }

    // 2f. HTTP 422：推送内容被服务器拒绝
    if (text.contains('422')) {
      return const GitErrorInfo(kind: GitOperationErrorKind.requestRejected);
    }

    // 2h. 本地路径型远端不存在（必须先于通用 404 判断）
    // 典型输出：`fatal: '/workspace/xxx.git' does not appear to be a git repository`
    // 这跟账号、令牌、GitHub 完全无关，归到"仓库不存在"会把用户带偏。
    if (text.contains('does not appear to be a git repository') ||
        text.contains('could not read from remote repository') ||
        RegExp(r"fatal: '.*' does not exist").hasMatch(text)) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.localRemotePathMissing,
      );
    }

    // 2i. 仓库不存在 / 无权访问（HTTP 404 或 GitHub 文案）
    if (text.contains('repository not found') || text.contains('404')) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.repositoryNotFound,
        fixAction: GitErrorFixAction.openAccountManagement,
      );
    }

    // 2i. 其他 HTTP 状态码（兜底，必须放在所有具体状态码判断之后）
    // 保留具体码值，不做统一归并，便于按状态码精确排查。
    final httpMatch = RegExp(r'returned error:\s*(\d{3})').firstMatch(text);
    if (httpMatch != null) {
      return GitErrorInfo(
        kind: GitOperationErrorKind.httpError,
        rawDetail: httpMatch.group(1),
      );
    }

    // ---- 3. SSH 主机指纹未确认 ----
    if (text.contains('host key verification failed') ||
        text.contains('remote host identification has changed')) {
      return const GitErrorInfo(kind: GitOperationErrorKind.hostKeyUnverified);
    }

    // ---- 4. SSH 密钥类 ----
    if (text.contains('permission denied (publickey)') ||
        text.contains('no supported authentication methods')) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.sshPublicKeyDenied,
        fixAction: GitErrorFixAction.openAccountManagement,
      );
    }
    if (text.contains('bad permissions') ||
        text.contains('unprotected private key file') ||
        text.contains('load key') ||
        text.contains('error in libcrypto')) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.sshKeyUnusable,
        fixAction: GitErrorFixAction.openAccountManagement,
      );
    }

    // ---- 5. 网络类 ----
    if (text.contains('could not resolve host') ||
        text.contains('name or service not known') ||
        text.contains('network is unreachable') ||
        text.contains('connection timed out') ||
        text.contains('connection refused') ||
        text.contains('failed to connect') ||
        text.contains('could not resolve proxy') ||
        text.contains('operation timed out') ||
        text.contains('ssl certificate problem') ||
        text.contains('gnutls_handshake')) {
      return const GitErrorInfo(kind: GitOperationErrorKind.networkUnreachable);
    }

    // ---- 6. 冲突（rebase/merge 中途）----
    // `could not apply` 是 rebase 冲突的标志性输出。
    if (conflictMarkers.any(text.contains) ||
        text.contains('merge conflict') ||
        text.contains('needs merge')) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.conflictDetected,
        fixAction: GitErrorFixAction.abortRebase,
      );
    }

    // ---- 7. 推送被拒（non-fast-forward）----
    if (text.contains('non-fast-forward') ||
        text.contains('failed to push some refs') ||
        text.contains('updates were rejected') ||
        text.contains('fetch first') ||
        text.contains('tip of your current branch is behind')) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.nonFastForward,
        fixAction: GitErrorFixAction.pullThenPush,
      );
    }

    // ---- 8. 未设置上游 ----
    if (text.contains('has no upstream branch') ||
        text.contains('no upstream configured') ||
        text.contains('set-upstream')) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.noUpstreamConfigured,
      );
    }

    // ---- 9. 本地改动会被覆盖 ----
    if (text.contains('would be overwritten') ||
        text.contains('your local changes') ||
        text.contains('commit your changes or stash them') ||
        text.contains('cannot pull with rebase')) {
      return const GitErrorInfo(
        kind: GitOperationErrorKind.localChangesWouldBeOverwritten,
      );
    }

    // ---- 10. 引用锁 ----
    if ((text.contains('unable to create') && text.contains('.lock')) ||
        text.contains('index.lock') ||
        text.contains('another git process')) {
      return const GitErrorInfo(kind: GitOperationErrorKind.refLockFailed);
    }

    // ---- 11. 磁盘空间 ----
    if (text.contains('no space left on device') || text.contains('disk full')) {
      return const GitErrorInfo(kind: GitOperationErrorKind.outOfSpace);
    }

    // ---- 12. 超时 ----
    if (text.contains('超时') ||
        text.contains('timed out') ||
        text.contains('timeout')) {
      return const GitErrorInfo(kind: GitOperationErrorKind.timeout);
    }

    // ---- 兜底：输出里没有任何可识别的错误 ----
    // 典型情况：fetch/push 只留下了 "Enumerating objects: N, done." 这类进度行，
    // 说明命令是被超时或连接中断打断的，而不是 git 主动报错。
    // 绝不能把进度行当作错误原因展示给用户——那会把排查方向彻底带偏。
    final meaningful = firstMeaningfulLine(raw);
    if (meaningful == null) {
      return const GitErrorInfo(kind: GitOperationErrorKind.operationIncomplete);
    }

    return GitErrorInfo(
      kind: GitOperationErrorKind.unknown,
      rawDetail: meaningful,
    );
  }

  /// 便捷判断：命令输出是否代表冲突
  static bool isConflict(String stderr, {String stdout = ''}) {
    final text = '${stderr.toLowerCase()}\n${stdout.toLowerCase()}';
    return conflictMarkers.any(text.contains);
  }

  /// git 进度输出的阶段名前缀（白名单）
  ///
  /// 必须用白名单：如果把 `^[A-Za-z]+:\s` 当作通用模式，`fatal:` / `error:`
  /// 也会被误判成进度行，从而把真正的错误信息丢掉。
  static const List<String> _progressPhases = [
    'enumerating objects',
    'counting objects',
    'compressing objects',
    'receiving objects',
    'resolving deltas',
    'writing objects',
    'updating files',
  ];

  /// 进度类行（不含真正的错误信息），例如：
  /// `remote: Enumerating objects: 2233, done.`
  /// `Receiving objects:  45% (450/1000)`
  /// `Resolving deltas: 100% (7/7), done.`
  static bool _isProgressLine(String line) {
    final t = line.trim().toLowerCase();
    if (t.isEmpty) return false;
    for (final phase in _progressPhases) {
      if (t.startsWith(phase)) return true;
    }
    return false;
  }

  /// 从多行输出中挑出第一条真正的错误信息；若全是进度噪音则返回 null
  static String? firstMeaningfulLine(String raw) {
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      // 去掉 `remote: ` 前缀后再判断，因为 GitHub 的进度与错误都带这个前缀
      final body = t.startsWith('remote:') ? t.substring('remote:'.length).trim() : t;
      if (body.isEmpty) continue;
      if (_isProgressLine(body)) continue;
      return body.length > 300 ? '${body.substring(0, 300)}…' : body;
    }
    return null;
  }
}

/// 错误类型 → 本地化文案的映射
///
/// 放在 UI 可达的扩展里，使 [GitErrorMapper] 本身保持纯逻辑、无 l10n 依赖。
extension GitOperationErrorKindL10n on GitOperationErrorKind {
  /// 面向用户的简短说明
  String message(AppLocalizations l10n) {
    switch (this) {
      case GitOperationErrorKind.none:
        return l10n.gitErrUnknown;
      case GitOperationErrorKind.authFailed:
        return l10n.gitErrAuthFailed;
      case GitOperationErrorKind.writePermissionDenied:
        return l10n.gitErrWritePermissionDenied;
      case GitOperationErrorKind.repositoryNotFound:
        return l10n.gitErrRepositoryNotFound;
      case GitOperationErrorKind.localRemotePathMissing:
        return l10n.gitErrLocalRemoteMissing;
      case GitOperationErrorKind.proxyAuthRequired:
        return l10n.gitErrProxyAuthRequired;
      case GitOperationErrorKind.requestRejected:
        return l10n.gitErrRequestRejected;
      case GitOperationErrorKind.rateLimited:
        return l10n.gitErrRateLimited;
      case GitOperationErrorKind.httpError:
        return l10n.gitErrHttpError;
      case GitOperationErrorKind.passwordAuthDisabled:
        return l10n.gitErrPasswordAuthDisabled;
      case GitOperationErrorKind.networkUnreachable:
        return l10n.gitErrNetworkUnreachable;
      case GitOperationErrorKind.sshPublicKeyDenied:
        return l10n.gitErrSshPublicKeyDenied;
      case GitOperationErrorKind.sshKeyUnusable:
        return l10n.gitErrSshKeyUnusable;
      case GitOperationErrorKind.hostKeyUnverified:
        return l10n.gitErrHostKeyUnverified;
      case GitOperationErrorKind.nonFastForward:
        return l10n.gitErrNonFastForward;
      case GitOperationErrorKind.staleForcePush:
        return l10n.gitErrStaleForcePush;
      case GitOperationErrorKind.conflictDetected:
        return l10n.gitErrConflictDetected;
      case GitOperationErrorKind.localChangesWouldBeOverwritten:
        return l10n.gitErrLocalChanges;
      case GitOperationErrorKind.noUpstreamConfigured:
        return l10n.gitErrNoUpstream;
      case GitOperationErrorKind.refLockFailed:
        return l10n.gitErrRefLockFailed;
      case GitOperationErrorKind.outOfSpace:
        return l10n.gitErrOutOfSpace;
      case GitOperationErrorKind.timeout:
        return l10n.gitErrTimeout;
      case GitOperationErrorKind.operationIncomplete:
        return l10n.gitErrIncomplete;
      case GitOperationErrorKind.unknown:
        return l10n.gitErrUnknown;
    }
  }

  /// 建议的下一步操作
  String suggestion(AppLocalizations l10n) {
    switch (this) {
      case GitOperationErrorKind.none:
        return '';
      case GitOperationErrorKind.authFailed:
        return l10n.gitErrAuthFailedHint;
      case GitOperationErrorKind.writePermissionDenied:
        return l10n.gitErrWritePermissionDeniedHint;
      case GitOperationErrorKind.repositoryNotFound:
        return l10n.gitErrRepositoryNotFoundHint;
      case GitOperationErrorKind.localRemotePathMissing:
        return l10n.gitErrLocalRemoteMissingHint;
      case GitOperationErrorKind.proxyAuthRequired:
        return l10n.gitErrProxyAuthRequiredHint;
      case GitOperationErrorKind.requestRejected:
        return l10n.gitErrRequestRejectedHint;
      case GitOperationErrorKind.rateLimited:
        return l10n.gitErrRateLimitedHint;
      case GitOperationErrorKind.httpError:
        return l10n.gitErrHttpErrorHint;
      case GitOperationErrorKind.passwordAuthDisabled:
        return l10n.gitErrPasswordAuthDisabledHint;
      case GitOperationErrorKind.networkUnreachable:
        return l10n.gitErrNetworkUnreachableHint;
      case GitOperationErrorKind.sshPublicKeyDenied:
        return l10n.gitErrSshPublicKeyDeniedHint;
      case GitOperationErrorKind.sshKeyUnusable:
        return l10n.gitErrSshKeyUnusableHint;
      case GitOperationErrorKind.hostKeyUnverified:
        return l10n.gitErrHostKeyUnverifiedHint;
      case GitOperationErrorKind.nonFastForward:
        return l10n.gitErrNonFastForwardHint;
      case GitOperationErrorKind.staleForcePush:
        return l10n.gitErrStaleForcePushHint;
      case GitOperationErrorKind.conflictDetected:
        return l10n.gitErrConflictDetectedHint;
      case GitOperationErrorKind.localChangesWouldBeOverwritten:
        return l10n.gitErrLocalChangesHint;
      case GitOperationErrorKind.noUpstreamConfigured:
        return l10n.gitErrNoUpstreamHint;
      case GitOperationErrorKind.refLockFailed:
        return l10n.gitErrRefLockFailedHint;
      case GitOperationErrorKind.outOfSpace:
        return l10n.gitErrOutOfSpaceHint;
      case GitOperationErrorKind.timeout:
        return l10n.gitErrTimeoutHint;
      case GitOperationErrorKind.operationIncomplete:
        return l10n.gitErrIncompleteHint;
      case GitOperationErrorKind.unknown:
        return l10n.gitErrUnknownHint;
    }
  }
}
