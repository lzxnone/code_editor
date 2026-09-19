import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/git_model.dart';
import '../services/distro_manager.dart';
import '../services/git_account_service.dart';
import '../services/git_service.dart';
import '../utils/git_decoration_utils.dart';
import '../utils/git_error_mapper.dart';

/// Git 状态管理 Provider
class GitProvider extends ChangeNotifier {
  final GitService _gitService;

  GitProvider({GitService? gitService}) : _gitService = gitService ?? GitService.instance;

  String? _rootPath;
  List<GitRepositoryInfo> _repositories = [];
  String? _currentRepoPath;
  bool _gitInstalled = true;
  String? _gitVersion;
  bool _isLoading = false;
  bool _isInitializing = false;
  bool _isInstallingGit = false;
  String? _errorMessage;
  List<GitFileStatus> _changedFiles = [];
  Map<String, GitFileStatus> _fileStatusMap = {};
  Map<String, GitFileStatusType> _dirStatusMap = {};
  String? _currentBranch;
  List<String> _branches = [];
  List<String> _tags = [];
  List<GitCommit> _commits = [];
  int _stashCount = 0;
  int _totalCommitsCount = 0;
  int _commitsLimit = 50;
  bool _isLoadingMoreCommits = false;

  // ---------------- 云端（远程仓库）状态 ----------------

  /// 当前仓库已配置的远程仓库列表
  List<GitRemote> _remotes = [];

  /// 当前分支的上游追踪状态（ahead/behind）
  GitBranchTracking? _tracking;

  /// 远端追踪分支列表（`origin/xxx`）
  List<GitRemoteBranch> _remoteBranches = [];

  /// 最近一次仓库自检结果
  GitFsckReport? _fsckReport;

  bool _isFsckRunning = false;

  /// 克隆进行中的进度
  GitOperationProgress? _cloneProgress;

  bool _isCloning = false;

  /// 冲突/中断操作状态
  GitConflictState _conflictState = GitConflictState.idle;

  /// 最近一次冲突操作的结果说明（供 UI 提示，如"因提交为空而停下"）
  String? _conflictNotice;

  bool _isFetching = false;
  bool _isPulling = false;
  bool _isPushing = false;

  /// 最近一次云端操作的实时进度（驱动内联进度条）
  GitOperationProgress? _remoteProgress;

  /// 最近一次云端操作的原始输出，供"查看详情"展开
  String _remoteLog = '';

  /// 最近一次云端操作的结构化错误
  GitErrorInfo? _lastRemoteError;

  /// 进行中的云端操作取消令牌
  HeadlessCancelToken? _remoteCancelToken;

  /// 最近一次 fetch 完成时间（用于决定是否提示用户刷新）
  DateTime? _lastFetchAt;

  // UI 内存状态缓存（保留折叠状态、输入框草稿与滚动位置）
  bool _stagedExpanded = true;
  bool _unstagedExpanded = true;
  bool _graphExpanded = true;
  bool _showTagsInSelector = false;
  String _commitMessage = '';
  double _scrollOffset = 0.0;
  bool _isCurrentRefTag = false;

  // Getters
  GitService get gitService => _gitService;
  String? get rootPath => _rootPath;
  List<GitRepositoryInfo> get repositories => List.unmodifiable(_repositories);
  String? get currentRepoPath => _currentRepoPath;
  bool get gitInstalled => _gitInstalled;
  String? get gitVersion => _gitVersion;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isInstallingGit => _isInstallingGit;
  String? get errorMessage => _errorMessage;
  List<GitFileStatus> get changedFiles => List.unmodifiable(_changedFiles);
  String? get currentBranch => _currentBranch;
  bool get isCurrentRefTag => _isCurrentRefTag;
  List<String> get branches => List.unmodifiable(_branches);
  List<String> get tags => List.unmodifiable(_tags);
  List<GitCommit> get commits => List.unmodifiable(_commits);
  int get stashCount => _stashCount;
  int get totalCommitsCount => _totalCommitsCount;
  int get commitsLimit => _commitsLimit;
  bool get isLoadingMoreCommits => _isLoadingMoreCommits;
  bool get hasMoreCommits => _totalCommitsCount > 0 ? _commits.length < _totalCommitsCount : false;

  // ---------------- 云端状态 Getters ----------------

  List<GitRemote> get remotes => List.unmodifiable(_remotes);
  GitBranchTracking? get tracking => _tracking;

  /// 远端追踪分支（用于分支选择器分区展示与检出）
  List<GitRemoteBranch> get remoteBranches => List.unmodifiable(_remoteBranches);
  GitFsckReport? get fsckReport => _fsckReport;
  bool get isFsckRunning => _isFsckRunning;
  bool get isCloning => _isCloning;
  GitOperationProgress? get cloneProgress => _cloneProgress;

  /// 冲突/中断操作状态
  GitConflictState get conflictState => _conflictState;

  /// 是否有未解决的冲突
  bool get hasConflicts => _conflictState.hasUnresolvedFiles;

  /// 是否有操作处于中断状态（含"冲突已解决待继续"）
  bool get hasPendingOperation => _conflictState.isPending;

  /// 冲突相关的提示信息（一次性，读取后由 UI 清除）
  String? get conflictNotice => _conflictNotice;
  bool get isFetching => _isFetching;
  bool get isPulling => _isPulling;
  bool get isPushing => _isPushing;
  GitOperationProgress? get remoteProgress => _remoteProgress;
  String get remoteLog => _remoteLog;
  GitErrorInfo? get lastRemoteError => _lastRemoteError;
  DateTime? get lastFetchAt => _lastFetchAt;

  /// 是否有任何云端操作正在进行（用于禁用并发按钮）
  bool get isRemoteBusy => _isFetching || _isPulling || _isPushing;

  /// 是否已配置远程仓库
  bool get hasRemote => _remotes.isNotEmpty;

  /// 默认远程仓库（优先 origin）
  GitRemote? get defaultRemote {
    if (_remotes.isEmpty) return null;
    for (final r in _remotes) {
      if (r.name == 'origin') return r;
    }
    return _remotes.first;
  }

  // ---------------- 远程目标解析 ----------------
  //
  // 「上游」与「推送目标」是两个概念：单人项目里通常都是 origin，但 fork 协作
  // 场景必须分开（从 upstream 拉、往自己的 fork 推）。这里遵循 git 自身的优先级，
  // 使用户在命令行里配过的 pushRemote / remote.pushDefault 同样在面板生效。

  /// 缓存的分支级推送远程（`branch.<name>.pushRemote`）
  String? _branchPushRemote;

  /// 缓存的全局推送默认远程（`remote.pushDefault`）
  String? _remotePushDefault;

  /// 缓存的分支级抓取远程（`branch.<name>.remote`）
  String? _branchRemote;

  /// 解析推送目标：pushRemote → remote.pushDefault → 上游远程 → origin/第一个
  ({GitRemote? remote, GitRemoteSource source}) get pushTarget =>
      _resolvePushTarget();

  /// 本会话内用户手动指定的推送目标（覆盖 git 配置，不落盘）
  ///
  /// 做成会话级覆盖而不是写 git config：切换仓库即失效，
  /// 避免一次临时选择被永久写进仓库配置。
  String? _pushTargetOverride;

  bool get hasPushTargetOverride => _pushTargetOverride != null;

  /// 手动指定推送目标；传 null 恢复按 git 配置自动解析
  void setPushTargetOverride(String? remoteName) {
    if (_pushTargetOverride == remoteName) return;
    _pushTargetOverride = remoteName;
    notifyListeners();
  }

  ({GitRemote? remote, GitRemoteSource source}) _resolvePushTarget() {
    if (_remotes.isEmpty) {
      return (remote: null, source: GitRemoteSource.none);
    }

    // 用户在本会话中的显式选择优先级最高
    if (_pushTargetOverride != null) {
      final override = _remoteByName(_pushTargetOverride);
      if (override != null) {
        return (remote: override, source: GitRemoteSource.manualOverride);
      }
      // 兜底：正常情况下覆盖会在远程列表变化时被即时清除，
      // 这里再拦一次，避免静默回落到别的远程却不告诉用户。
      _pushTargetOverride = null;
    }

    final upstreamName = _tracking?.remoteName;
    final upstream = _remoteByName(upstreamName);
    // 分支尚未建立追踪时，其「上游」等价于 git 的 branch.<name>.remote
    final branchRemote = _remoteByName(_branchRemote);

    // 1. branch.<name>.pushRemote
    final pushRemote = _remoteByName(_branchPushRemote);
    if (pushRemote != null) {
      return (remote: pushRemote, source: GitRemoteSource.pushRemote);
    }
    // 2. remote.pushDefault
    final pushDefault = _remoteByName(_remotePushDefault);
    if (pushDefault != null) {
      return (remote: pushDefault, source: GitRemoteSource.pushDefault);
    }
    // 3. 上游 / 分支配置的远程
    if (upstream != null) {
      return (remote: upstream, source: GitRemoteSource.upstream);
    }
    if (branchRemote != null) {
      return (remote: branchRemote, source: GitRemoteSource.branchRemote);
    }
    // 4. origin / 第一个
    return (remote: defaultRemote, source: GitRemoteSource.fallback);
  }

  /// 解析抓取目标：`branch.<name>.remote` → 上游远程 → origin/第一个
  ///
  /// 必须优先于 defaultRemote：fork 场景下分支追踪的是 upstream，
  /// 若抓取固定走 origin，则 upstream/* 永不更新，ahead/behind 会一直算错。
  GitRemote? get fetchTarget {
    if (_remotes.isEmpty) return null;
    return _remoteByName(_branchRemote) ??
        _remoteByName(_tracking?.remoteName) ??
        defaultRemote;
  }

  /// 解析拉取目标：上游远程 → origin/第一个
  GitRemote? get pullTarget {
    if (_remotes.isEmpty) return null;
    return _remoteByName(_tracking?.remoteName) ?? defaultRemote;
  }

  GitRemote? _remoteByName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final r in _remotes) {
      if (r.name == name) return r;
    }
    return null;
  }

  /// 待推送的提交数（无上游时为 0，UI 应改为展示"发布分支"）
  int get aheadCount => _tracking?.ahead ?? 0;

  /// 待拉取的提交数
  int get behindCount => _tracking?.behind ?? 0;

  /// 当前分支是否需要建立上游追踪关系
  bool get needsPublishBranch {
    final branch = _currentBranch;
    if (branch == null || branch.isEmpty) return false;
    if (_tracking == null) return false;
    return !_tracking!.hasUpstream || _tracking!.isGone;
  }

  bool get stagedExpanded => _stagedExpanded;
  bool get unstagedExpanded => _unstagedExpanded;
  bool get graphExpanded => _graphExpanded;
  bool get showTagsInSelector => _showTagsInSelector;
  String get commitMessage => _commitMessage;
  double get scrollOffset => _scrollOffset;

  void setStagedExpanded(bool val) => _stagedExpanded = val;
  void setUnstagedExpanded(bool val) => _unstagedExpanded = val;
  void setGraphExpanded(bool val) => _graphExpanded = val;
  void setShowTagsInSelector(bool val) => _showTagsInSelector = val;
  void setCommitMessage(String val) => _commitMessage = val;
  void setScrollOffset(double val) => _scrollOffset = val;

  bool get hasProject => _rootPath != null && _rootPath!.trim().isNotEmpty;
  bool get hasRepository => _repositories.isNotEmpty;
  bool get isGitRepo => hasRepository;

  GitRepositoryInfo? get currentRepo {
    if (_currentRepoPath == null) return null;
    return _repositories.where((r) => r.rootPath == _currentRepoPath).firstOrNull;
  }

  /// 暂存区文件列表
  List<GitFileStatus> get stagedFiles => _changedFiles.where((f) => f.isStaged).toList();

  /// 未暂存文件列表（含修改与未跟踪）
  List<GitFileStatus> get unstagedFiles => _changedFiles.where((f) => !f.isStaged).toList();

  /// 总变动文件数量（供活动栏与角标展示）
  int get totalChangedCount => _changedFiles.length;

  /// 根据文件绝对路径或相对路径 O(1) 获取 Git 变更状态（用于文件树文件名染色与字母标识）
  GitFileStatus? getFileStatus(String filePath) {
    if (_fileStatusMap.isEmpty) return null;
    final normalized = p.normalize(filePath);
    final direct = _fileStatusMap[normalized];
    if (direct != null) return direct;
    return _fileStatusMap[normalized.toLowerCase()];
  }

  /// 根据目录绝对路径 O(1) 获取最高优先级 Git 变更状态类别（用于文件夹名称染色与彩色圆点）
  GitFileStatusType? getDirectoryStatus(String dirPath) {
    if (_dirStatusMap.isEmpty) return null;
    final normalized = p.normalize(dirPath);
    final direct = _dirStatusMap[normalized];
    if (direct != null) return direct;
    return _dirStatusMap[normalized.toLowerCase()];
  }

  /// 绑定项目根路径（响应 ProjectProvider 切换）
  void bindRootPath(String? newRootPath) {
    final normalized = newRootPath != null && newRootPath.trim().isNotEmpty
        ? p.normalize(newRootPath.trim())
        : null;

    if (_rootPath != normalized) {
      _rootPath = normalized;
      _repositories = [];
      _currentRepoPath = null;
      _changedFiles = [];
      _rebuildStatusMaps();
      _currentBranch = null;
      _branches = [];
      _tags = [];
      _commits = [];
      _stashCount = 0;
      _errorMessage = null;
      _clearRemoteState();

      if (_rootPath != null) {
        refresh();
      } else {
        notifyListeners();
      }
    }
  }

  /// 响应底层运行容器被销毁重建：立即失效环境缓存，清空内存仓库与分支状态，恢复未安装引导
  void onContainerReset() {
    _gitService.invalidateEnvStatus();
    // 容器 rootfs 被重建后 ~/.git-credentials 一并丢失，需重新灌注
    GitAccountService.instance.invalidateCredentialSync();
    _gitInstalled = false;
    _gitVersion = null;
    _repositories = [];
    _currentRepoPath = null;
    _changedFiles = [];
    _rebuildStatusMaps();
    _currentBranch = null;
    _branches = [];
    _tags = [];
    _commits = [];
    _stashCount = 0;
    _errorMessage = '底层容器已重置，需重新安装 Git 工具链';
    _isLoading = false;
    _clearRemoteState();
    notifyListeners();
  }

  /// 清空云端相关状态（切换项目 / 容器重置 / 切换仓库时调用）
  void _clearRemoteState() {
    _remotes = [];
    _tracking = null;
    _remoteBranches = [];
    _fsckReport = null;
    _isFsckRunning = false;
    _cloneProgress = null;
    _isCloning = false;
    _conflictState = GitConflictState.idle;
    _conflictNotice = null;
    _isFetching = false;
    _isPulling = false;
    _isPushing = false;
    _remoteProgress = null;
    _remoteLog = '';
    _lastRemoteError = null;
    _lastFetchAt = null;
    _remoteCancelToken = null;
    _branchPushRemote = null;
    _remotePushDefault = null;
    _branchRemote = null;
    _pushTargetOverride = null;
  }

  /// 读取与远程目标解析相关的 git 配置
  ///
  /// 这些值决定 push/fetch 走哪个远程；必须与仓库同步刷新，
  /// 否则用户在命令行改过 pushRemote 后面板不会跟随。
  Future<void> _loadRemoteTargetConfig() async {
    if (_currentRepoPath == null) return;
    final branch = _currentBranch ?? '';
    try {
      _branchPushRemote = await _gitService.getBranchPushRemote(_currentRepoPath!, branch);
      _remotePushDefault = await _gitService.getRemotePushDefault(_currentRepoPath!);
      _branchRemote = await _gitService.getBranchRemote(_currentRepoPath!, branch);
    } catch (e) {
      debugPrint('[GitProvider] 读取远程目标配置异常: $e');
    }
  }

  int _refreshSeq = 0;

  /// 刷新 Git 状态与仓库信息
  Future<void> refresh() async {
    final seq = ++_refreshSeq;

    if (_rootPath == null || _rootPath!.isEmpty) {
      _repositories = [];
      _currentRepoPath = null;
      _changedFiles = [];
      _rebuildStatusMaps();
      _currentBranch = null;
      _branches = [];
      _tags = [];
      _commits = [];
      _stashCount = 0;
      _isLoading = false;
      _clearRemoteState();
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. 校验 Git 命令行工具环境
      final env = await _gitService.checkGitInstalled();
      if (seq != _refreshSeq) return;

      _gitInstalled = env.isInstalled;
      _gitVersion = env.version;
      if (!env.isInstalled) {
        _errorMessage = env.errorMessage ?? '未检测到 Git 命令行工具';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 2. 探测工程根目录及子目录下的仓库列表
      final detected = await _gitService.detectRepositories(_rootPath!);
      if (seq != _refreshSeq) return;

      _repositories = detected;

      // 3. 确定当前活跃选中的仓库
      if (_repositories.isNotEmpty) {
        // 如果当前没有选中或先前选中的已不存在，优先选根仓库，否则选第 1 个
        if (_currentRepoPath == null || !_repositories.any((r) => r.rootPath == _currentRepoPath)) {
          final rootRepo = _repositories.where((r) => r.isRoot).firstOrNull;
          _currentRepoPath = rootRepo != null ? rootRepo.rootPath : _repositories.first.rootPath;
        }

        // 4. 加载当前活跃仓库的状态与分支
        await _loadCurrentRepoDetails();
        if (seq != _refreshSeq) return;
      } else {
        _currentRepoPath = null;
        _changedFiles = [];
        _rebuildStatusMaps();
        _currentBranch = null;
        _clearRemoteState();
      }
    } catch (e) {
      if (seq == _refreshSeq) {
        _errorMessage = '加载 Git 状态异常: $e';
      }
    } finally {
      if (seq == _refreshSeq) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// 切换当前选中的活跃仓库
  Future<void> switchRepository(String repoPath) async {
    final normalized = p.normalize(repoPath);
    if (_currentRepoPath == normalized) return;

    if (_repositories.any((r) => r.rootPath == normalized)) {
      _currentRepoPath = normalized;
      _isLoading = true;
      notifyListeners();

      await _loadCurrentRepoDetails();

      _isLoading = false;
      notifyListeners();
    }
  }

  /// 初始化本地 Git 仓库
  Future<GitCommandResult> initRepository({
    String? targetPath,
    String defaultBranch = 'main',
  }) async {
    final path = targetPath ?? _rootPath;
    if (path == null || path.isEmpty) {
      return GitCommandResult.error('未指定有效的仓库初始化路径');
    }

    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _gitService.initRepository(
        path,
        defaultBranch: defaultBranch,
      );

      if (result.success) {
        // 初始化成功后自动重新扫描并选中该仓库
        await refresh();
      } else {
        _errorMessage = result.stderr.isNotEmpty ? result.stderr : '初始化 Git 仓库失败';
      }

      return result;
    } catch (e) {
      _errorMessage = '初始化异常: $e';
      return GitCommandResult.error(e.toString());
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// 安装 Git
  Future<GitCommandResult> installGit({void Function(String output)? onProgress}) async {
    _isInstallingGit = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _gitService.installGit(onProgress: onProgress);
      if (result.success) {
        await refresh();
      } else {
        _errorMessage = result.stderr.isNotEmpty ? result.stderr : '安装 Git 失败';
      }
      return result;
    } catch (e) {
      _errorMessage = '安装 Git 异常: $e';
      return GitCommandResult.error(e.toString());
    } finally {
      _isInstallingGit = false;
      notifyListeners();
    }
  }

  /// 暂存指定文件
  Future<GitCommandResult> stageFile(String relativePath) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.stageFile(_currentRepoPath!, relativePath);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 取消暂存指定文件
  Future<GitCommandResult> unstageFile(String relativePath) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.unstageFile(_currentRepoPath!, relativePath);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 全部暂存
  Future<GitCommandResult> stageAll() async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.stageAll(_currentRepoPath!);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 全部取消暂存
  Future<GitCommandResult> unstageAll() async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.unstageAll(_currentRepoPath!);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 放弃单个文件的更改
  Future<GitCommandResult> discardFile(GitFileStatus file) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final isUntracked = file.statusType == GitFileStatusType.untracked;
    final res = await _gitService.discardFile(
      _currentRepoPath!,
      file.relativePath,
      isUntracked: isUntracked,
      isStaged: file.isStaged,
    );
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 全部放弃未暂存更改
  Future<GitCommandResult> discardAllUnstaged() async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.discardAllUnstaged(_currentRepoPath!);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 全部放弃已暂存更改
  Future<GitCommandResult> discardAllStaged() async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.discardAllStaged(_currentRepoPath!);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 提交当前暂存区的更改
  Future<GitCommandResult> commit(String message, {bool amend = false}) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.commit(_currentRepoPath!, message, amend: amend);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 切换分支
  Future<GitCommandResult> switchBranch(String branchName) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.checkoutBranch(_currentRepoPath!, branchName);
    if (res.success) {
      _currentBranch = branchName;
      _isCurrentRefTag = false;
      // 推送目标是按分支解析的：换了分支就必须重新解析，
      // 否则在 main 上选的远程会被带到 feature 分支上（可能推错仓库）。
      _pushTargetOverride = null;
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 创建并可选检出新分支
  Future<GitCommandResult> createBranch(String branchName, {bool checkout = true}) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.createBranch(_currentRepoPath!, branchName, checkout: checkout);
    if (res.success) {
      if (checkout) _pushTargetOverride = null;
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 删除本地分支
  Future<GitCommandResult> deleteBranch(String branchName, {bool force = false}) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.deleteBranch(_currentRepoPath!, branchName, force: force);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 撤销上一次提交
  Future<GitCommandResult> undoLastCommit() async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.undoLastCommit(_currentRepoPath!);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 贮藏当前更改
  Future<GitCommandResult> stash({String? message}) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.stash(_currentRepoPath!, message: message);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 恢复最近贮藏
  Future<GitCommandResult> stashPop() async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.stashPop(_currentRepoPath!);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 添加文件到 .gitignore
  Future<bool> addToGitignore(String relativePath) async {
    if (_currentRepoPath == null) return false;
    final success = await _gitService.addToGitignore(_currentRepoPath!, relativePath);
    if (success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return success;
  }

  /// 创建新标签
  Future<GitCommandResult> createTag(String tagName, {String? message}) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.createTag(_currentRepoPath!, tagName, message: message);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 删除本地标签
  Future<GitCommandResult> deleteTag(String tagName) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.deleteTag(_currentRepoPath!, tagName);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 检出指定标签
  Future<GitCommandResult> switchTag(String tagName) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.checkoutTag(_currentRepoPath!, tagName);
    if (res.success) {
      _currentBranch = tagName;
      _isCurrentRefTag = true;
      // 标签检出后处于 detached HEAD，同样需要重新解析推送目标
      _pushTargetOverride = null;
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 分页加载更多提交历史
  Future<void> loadMoreCommits({int count = 50}) async {
    if (_currentRepoPath == null || _isLoadingMoreCommits) return;
    _isLoadingMoreCommits = true;
    notifyListeners();
    try {
      _commitsLimit += count;
      _commits = await _gitService.getLog(_currentRepoPath!, maxCount: _commitsLimit);
      if (_commits.length > _totalCommitsCount) {
        _totalCommitsCount = _commits.length;
      }
    } catch (e) {
      debugPrint('[GitProvider] 加载更多提交异常: $e');
    } finally {
      _isLoadingMoreCommits = false;
      notifyListeners();
    }
  }

  /// 全量加载所有提交历史并解除分页限制
  Future<void> loadAllCommits() async {
    if (_currentRepoPath == null || _isLoadingMoreCommits) return;
    _isLoadingMoreCommits = true;
    notifyListeners();
    try {
      final target = _totalCommitsCount > 0 ? _totalCommitsCount : 2000;
      _commitsLimit = target;
      _commits = await _gitService.getLog(_currentRepoPath!, maxCount: _commitsLimit);
      _totalCommitsCount = _commits.length;
    } catch (e) {
      debugPrint('[GitProvider] 全量加载提交异常: $e');
    } finally {
      _isLoadingMoreCommits = false;
      notifyListeners();
    }
  }

  /// 内部辅助：加载当前仓库的分支、提交历史与文件变更列表
  Future<void> _loadCurrentRepoDetails() async {
    if (_currentRepoPath == null) return;
    try {
      final refInfo = await _gitService.getCurrentRefInfo(_currentRepoPath!);
      _currentBranch = refInfo.name;
      _isCurrentRefTag = refInfo.isTag;
      _branches = await _gitService.getLocalBranches(_currentRepoPath!);
      _tags = await _gitService.getTags(_currentRepoPath!);
      _changedFiles = await _gitService.getGitStatus(_currentRepoPath!);
      _rebuildStatusMaps();
      _commitsLimit = 50;
      _totalCommitsCount = await _gitService.getTotalCommitsCount(_currentRepoPath!);
      _commits = await _gitService.getLog(_currentRepoPath!, maxCount: _commitsLimit);
      if (_commits.length > _totalCommitsCount) {
        _totalCommitsCount = _commits.length;
      }
      _stashCount = await _gitService.getStashCount(_currentRepoPath!);

      // 加载远程仓库列表与上游追踪状态（ahead/behind）
      _remotes = await _gitService.getRemotes(_currentRepoPath!);
      _tracking = await _gitService.getBranchTracking(_currentRepoPath!);
      _remoteBranches = await _gitService.getRemoteBranches(_currentRepoPath!);
      // 远程目标解析依赖 branch.<name>.* 与 remote.pushDefault
      await _loadRemoteTargetConfig();
      // 冲突/中断状态：pull 撞冲突后必须立刻能呈现给用户
      await _loadConflictState();

      // 同步更新 repositories 列表中当前项的分支信息
      final idx = _repositories.indexWhere((r) => r.rootPath == _currentRepoPath);
      if (idx != -1) {
        _repositories[idx] = _repositories[idx].copyWith(
          currentBranch: _currentBranch,
          remotes: _remotes,
          tracking: _tracking,
        );
      }
    } catch (e) {
      debugPrint('[GitProvider] 加载仓库详情异常: $e');
    }
  }

  // ==========================================================================
  //  云端（远程仓库）操作
  // ==========================================================================

  /// 仅刷新远端相关状态（不重跑提交历史等重活），用于网络操作完成后的即时反馈
  Future<void> _loadRemoteStateOnly() async {
    if (_currentRepoPath == null) return;
    try {
      _remotes = await _gitService.getRemotes(_currentRepoPath!);
      _tracking = await _gitService.getBranchTracking(_currentRepoPath!);
      // fetch/push 都可能带来新的远端分支，必须一并刷新
      _remoteBranches = await _gitService.getRemoteBranches(_currentRepoPath!);
      // 首次 push --set-upstream 会写入 branch.<name>.remote，需重新读取
      await _loadRemoteTargetConfig();
    } catch (e) {
      debugPrint('[GitProvider] 刷新远端状态异常: $e');
    }
  }

  /// 把一次云端命令的执行结果转换为结构化错误并记录原始输出
  void _recordRemoteResult(GitRemoteCommandResult res) {
    _remoteLog = res.combinedOutput.trim();
    if (res.success || res.cancelled) {
      _lastRemoteError = null;
      return;
    }
    _lastRemoteError = GitErrorMapper.describe(res.stderr, stdout: res.stdout);
  }

  void _beginRemoteOperation() {
    _remoteProgress = null;
    _remoteLog = '';
    _lastRemoteError = null;
    _remoteCancelToken = HeadlessCancelToken();
  }

  /// 云端网络操作前的准备：确保容器内凭据文件是最新的
  ///
  /// 容器重建会连同 rootfs 一起丢掉 ~/.git-credentials，若不重写就会出现
  /// "凭据明明配好了却报认证失败" 的迷惑现象。
  Future<void> _prepareRemoteOperation() async {
    try {
      await GitAccountService.instance.ensureContainerCredentials();
    } catch (e) {
      debugPrint('[GitProvider] 凭据灌注异常: $e');
    }
  }

  void _endRemoteOperation() {
    _remoteCancelToken = null;
    _remoteProgress = null;
  }

  void _onProgress(GitOperationProgress progress) {
    _remoteProgress = progress;
    notifyListeners();
  }

  /// 请求取消当前进行中的云端操作
  void cancelRemoteOperation() {
    _remoteCancelToken?.cancel();
    notifyListeners();
  }

  /// 抓取远端更新
  Future<GitRemoteCommandResult> fetchRemote({String? remote}) async {
    if (_currentRepoPath == null) {
      return GitRemoteCommandResult.error('未选择仓库');
    }
    if (isRemoteBusy) {
      return GitRemoteCommandResult.error('已有云端操作正在进行，请稍候');
    }

    _isFetching = true;
    _beginRemoteOperation();
    await _prepareRemoteOperation();
    notifyListeners();

    try {
      final res = await _gitService.fetch(
        _currentRepoPath!,
        rootPath: _rootPath,
        // 修复：原先直接取 defaultRemote，fork 场景下会永远抓 origin
        // 而漏掉上游，导致 upstream/* 过期、ahead/behind 长期算错。
        remote: remote ?? fetchTarget?.name,
        onProgress: _onProgress,
        cancelToken: _remoteCancelToken,
      );
      _recordRemoteResult(res);
      if (res.success) _lastFetchAt = DateTime.now();
      // fetch 会改变 ahead/behind，必须即时刷新远端状态
      await _loadRemoteStateOnly();
      // fetch 本身不产生冲突，但用户可能在中断状态下点它，这里顺带校正状态
      await _reloadConflictStateAndNotify();
      return res;
    } finally {
      _isFetching = false;
      _endRemoteOperation();
      notifyListeners();
    }
  }

  /// 拉取远端改动（rebase 方式）
  ///
  /// [remote]/[branch] 缺省时使用当前分支的上游。
  Future<GitRemoteCommandResult> pull({
    String? remote,
    String? branch,
  }) async {
    if (_currentRepoPath == null) {
      return GitRemoteCommandResult.error('未选择仓库');
    }
    if (isRemoteBusy) {
      return GitRemoteCommandResult.error('已有云端操作正在进行，请稍候');
    }

    final targetRemote = remote ?? pullTarget?.name;
    final targetBranch = branch ?? _tracking?.upstreamBranch;

    _isPulling = true;
    _beginRemoteOperation();
    await _prepareRemoteOperation();
    notifyListeners();

    try {
      final res = await _gitService.pullRebase(
        _currentRepoPath!,
        rootPath: _rootPath,
        remote: targetRemote,
        branch: targetBranch,
        onProgress: _onProgress,
        cancelToken: _remoteCancelToken,
      );
      _recordRemoteResult(res);
      if (res.success) {
        // pull 会改动工作区与提交历史，需完整刷新
        await _loadCurrentRepoDetails();
        notifyListeners();
      } else {
        await _loadRemoteStateOnly();
        // 失败很可能正是因为撞了冲突：必须立刻探测，否则冲突横幅不会出现，
        // 用户根本找不到解决入口（只有下次完整刷新才会暴露）
        await _reloadConflictStateAndNotify();
      }
      return res;
    } finally {
      _isPulling = false;
      _endRemoteOperation();
      notifyListeners();
    }
  }

  /// 推送当前分支到远端
  ///
  /// [setUpstream] 用于首次发布分支；[forceWithLease] 为唯一允许的强制方式。
  Future<GitRemoteCommandResult> push({
    String? remote,
    String? branch,
    bool? setUpstream,
    bool forceWithLease = false,
  }) async {
    if (_currentRepoPath == null) {
      return GitRemoteCommandResult.error('未选择仓库');
    }
    if (isRemoteBusy) {
      return GitRemoteCommandResult.error('已有云端操作正在进行，请稍候');
    }

    // 推送目标遵循 git 自身优先级：pushRemote → pushDefault → 上游 → origin
    final targetRemote = remote ?? pushTarget.remote?.name;
    final targetBranch = branch ?? _currentBranch;
    final shouldSetUpstream = setUpstream ?? needsPublishBranch;

    _isPushing = true;
    _beginRemoteOperation();
    await _prepareRemoteOperation();
    notifyListeners();

    try {
      final res = await _gitService.push(
        _currentRepoPath!,
        rootPath: _rootPath,
        remote: targetRemote,
        branch: targetBranch,
        setUpstream: shouldSetUpstream,
        forceWithLease: forceWithLease,
        onProgress: _onProgress,
        cancelToken: _remoteCancelToken,
      );
      _recordRemoteResult(res);
      if (res.success) {
        await _loadRemoteStateOnly();
      } else {
        // 推送失败也可能是中断状态导致的，同样校正一次
        await _reloadConflictStateAndNotify();
      }
      return res;
    } finally {
      _isPushing = false;
      _endRemoteOperation();
      notifyListeners();
    }
  }

  /// 推送被拒后的一键修复：先 pull(rebase) 再 push
  Future<({bool success, GitRemoteCommandResult? pullResult, GitRemoteCommandResult? pushResult})>
      pullThenPush() async {
    if (_currentRepoPath == null) {
      return (success: false, pullResult: null, pushResult: null);
    }

    final pullRes = await pull();
    if (!pullRes.success) {
      return (success: false, pullResult: pullRes, pushResult: null);
    }

    final pushRes = await push();
    return (success: pushRes.success, pullResult: pullRes, pushResult: pushRes);
  }

  // ------------------------------ 远端仓库管理 ------------------------------

  /// 重新加载远程仓库列表
  Future<void> reloadRemotes() async {
    if (_currentRepoPath == null) return;
    _remotes = await _gitService.getRemotes(_currentRepoPath!);
    // 远程集合变化可能使会话级选择失效（被删除/改名），
    // 这里即时清除而不是等到读取时才发现，避免状态长期不一致。
    if (_pushTargetOverride != null && _remoteByName(_pushTargetOverride) == null) {
      _pushTargetOverride = null;
    }
    notifyListeners();
  }

  /// 添加远程仓库
  Future<GitCommandResult> addRemote(
    String name,
    String url, {
    String? pushUrl,
  }) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.addRemote(
      _currentRepoPath!,
      name,
      url,
      pushUrl: pushUrl,
    );
    if (res.success) await reloadRemotes();
    return res;
  }

  /// 移除远程仓库
  Future<GitCommandResult> removeRemote(String name) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.removeRemote(_currentRepoPath!, name);
    if (res.success) {
      await reloadRemotes();
      // 移除远程仓库会影响上游追踪关系
      _tracking = await _gitService.getBranchTracking(_currentRepoPath!);
      notifyListeners();
    }
    return res;
  }

  /// 重命名远程仓库
  Future<GitCommandResult> renameRemote(String oldName, String newName) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.renameRemote(_currentRepoPath!, oldName, newName);
    if (res.success) {
      await reloadRemotes();
      _tracking = await _gitService.getBranchTracking(_currentRepoPath!);
      notifyListeners();
    }
    return res;
  }

  /// 修改远程仓库地址
  Future<GitCommandResult> setRemoteUrl(
    String name,
    String url, {
    bool push = false,
  }) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.setRemoteUrl(
      _currentRepoPath!,
      name,
      url,
      push: push,
    );
    if (res.success) await reloadRemotes();
    return res;
  }

  /// 清理远端已删除的追踪分支
  Future<GitCommandResult> pruneRemote(String name) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.pruneRemote(_currentRepoPath!, name);
    if (res.success) await reloadRemotes();
    return res;
  }

  /// 自检：验证远端地址的连通性与认证是否可用
  Future<GitRemoteCommandResult> checkRemoteAuth(String url) async {
    if (_currentRepoPath == null) {
      return GitRemoteCommandResult.error('未选择仓库');
    }
    _beginRemoteOperation();
    await _prepareRemoteOperation();
    notifyListeners();
    try {
      final res = await _gitService.checkRemoteAuth(
        _currentRepoPath!,
        url,
        rootPath: _rootPath,
        cancelToken: _remoteCancelToken,
      );
      _recordRemoteResult(res);
      return res;
    } finally {
      _endRemoteOperation();
      notifyListeners();
    }
  }

  /// 清除最近一次云端错误提示
  void clearRemoteError() {
    _lastRemoteError = null;
    _remoteLog = '';
    notifyListeners();
  }

  // ==========================================================================
  //  冲突解决
  // ==========================================================================

  /// 重新读取冲突与中断操作状态
  Future<void> _loadConflictState() async {
    if (_currentRepoPath == null) {
      _conflictState = GitConflictState.idle;
      return;
    }
    try {
      final operation = _gitService.getPendingOperation(_currentRepoPath!);
      if (operation == GitPendingOperation.none) {
        _conflictState = GitConflictState.idle;
        return;
      }
      final files = await _gitService.getConflictedFiles(_currentRepoPath!);
      _conflictState = GitConflictState(operation: operation, files: files);
    } catch (e) {
      debugPrint('[GitProvider] 读取冲突状态异常: $e');
      _conflictState = GitConflictState.idle;
    }
  }

  /// 手动刷新冲突状态（冲突面板打开时调用）
  Future<void> refreshConflictState() async {
    await _loadConflictState();
    notifyListeners();
  }

  /// 重新探测冲突状态并通知 UI
  ///
  /// 先做一次极轻量的文件系统探测（无进程开销），只有确实处于中断状态时
  /// 才去解析冲突文件列表 —— 这样可以挂在每次网络操作失败之后而不付代价。
  Future<void> _reloadConflictStateAndNotify() async {
    if (_currentRepoPath == null) return;
    final operation = _gitService.getPendingOperation(_currentRepoPath!);
    if (operation == GitPendingOperation.none) {
      if (_conflictState.isPending) {
        _conflictState = GitConflictState.idle;
        notifyListeners();
      }
      return;
    }
    await _loadConflictState();
    notifyListeners();
  }

  /// 把文件标记为已解决（`git add`）
  Future<GitCommandResult> markConflictResolved(GitConflictedFile file) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.markResolved(
      _currentRepoPath!,
      file.relativePath,
    );
    await _afterConflictAction(res);
    return res;
  }

  /// 整文件采用某一侧
  ///
  /// [useOurs] 的含义随操作类型变化（rebase 下 ours 是基线），
  /// 文案由 UI 按 [conflictState] 的 operation 决定。
  Future<GitCommandResult> takeConflictSide(
    GitConflictedFile file, {
    required bool useOurs,
  }) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.checkoutConflictSide(
      _currentRepoPath!,
      file.relativePath,
      useOurs: useOurs,
    );
    await _afterConflictAction(res);
    return res;
  }

  /// 重新生成冲突标记（改坏了用它恢复）
  Future<GitCommandResult> recreateConflictMarkers(
    GitConflictedFile file,
  ) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.recreateConflictMarkers(
      _currentRepoPath!,
      file.relativePath,
    );
    if (res.success) {
      await _loadConflictState();
      notifyListeners();
    }
    return res;
  }

  /// 删除冲突文件（modify/delete 冲突中选择"确认删除"）
  Future<GitCommandResult> removeConflictedFile(GitConflictedFile file) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.removeConflictedFile(
      _currentRepoPath!,
      file.relativePath,
    );
    await _afterConflictAction(res);
    return res;
  }

  /// 继续被中断的操作
  ///
  /// 若仍有未解决文件，直接拒绝 —— 否则 git 会立刻再次停下，
  /// 用户会以为是"继续没生效"。
  Future<GitCommandResult> continueOperation() async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    if (_conflictState.files.isNotEmpty) {
      return GitCommandResult.error('仍有未解决的冲突文件，请先全部标记为已解决');
    }
    final res = await _gitService.continueOperation(
      _currentRepoPath!,
      _conflictState.operation,
    );

    if (!res.success &&
        _gitService.isOperationStoppedForEmptyCommit(res.stderr + res.stdout)) {
      // 提交为空导致再次停下：这是正常现象，但必须明确告诉用户可以跳过
      _conflictNotice = 'emptyCommit';
      await _loadConflictState();
      notifyListeners();
      return res;
    }

    await _afterConflictAction(res, fullReload: true);
    return res;
  }

  /// 跳过当前提交
  Future<GitCommandResult> skipOperation() async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.skipOperation(
      _currentRepoPath!,
      _conflictState.operation,
    );
    await _afterConflictAction(res, fullReload: true);
    return res;
  }

  /// 放弃被中断的操作
  Future<GitCommandResult> abortOperation() async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.abortOperation(
      _currentRepoPath!,
      _conflictState.operation,
    );
    await _afterConflictAction(res, fullReload: true);
    return res;
  }

  /// 清除一次性提示
  void clearConflictNotice() {
    _conflictNotice = null;
    notifyListeners();
  }

  /// 冲突操作后的统一刷新
  ///
  /// [fullReload] 表示操作可能改写了提交历史（continue/skip/abort），
  /// 此时必须完整刷新而非只刷新远端状态。
  Future<void> _afterConflictAction(
    GitCommandResult res, {
    bool fullReload = false,
  }) async {
    if (!res.success) return;
    if (fullReload) {
      await _loadCurrentRepoDetails();
    } else {
      await _loadConflictState();
    }
    notifyListeners();
  }

  // ---------------------------- 远端分支检出 ----------------------------

  /// 基于远端分支检出（或切换到已有的）本地分支
  ///
  /// 本地已有同名分支时直接切换；否则以远端分支为起点创建并建立追踪关系。
  Future<GitCommandResult> checkoutRemoteBranch(
    GitRemoteBranch branch, {
    bool forceCreate = false,
  }) async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.checkoutRemoteBranch(
      _currentRepoPath!,
      branch.remoteName,
      branch.branchName,
      forceCreate: forceCreate,
    );
    if (res.success) {
      _pushTargetOverride = null;
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  // ---------------------------- 仓库自检 ----------------------------

  /// 执行仓库完整性自检
  Future<GitFsckReport?> runFsck() async {
    if (_currentRepoPath == null) return null;
    if (_isFsckRunning) return _fsckReport;

    _isFsckRunning = true;
    notifyListeners();
    try {
      _fsckReport = await _gitService.fsck(_currentRepoPath!);
      return _fsckReport;
    } catch (e) {
      debugPrint('[GitProvider] 仓库自检异常: $e');
      return null;
    } finally {
      _isFsckRunning = false;
      notifyListeners();
    }
  }

  /// 清除自检结果
  void clearFsckReport() {
    _fsckReport = null;
    notifyListeners();
  }

  // ---------------------------- 克隆 ----------------------------

  /// 克隆远端仓库到指定项目的内部目录
  ///
  /// [parentDir] 为克隆父目录（通常是项目根），克隆完成后目标目录为
  /// `parentDir/<targetDirName>`。
  Future<GitRemoteCommandResult> cloneRepository({
    required String parentDir,
    required String url,
    required String targetDirName,
    String? branch,
    int? depth,
    HeadlessCancelToken? cancelToken,
  }) async {
    if (_isCloning) {
      return GitRemoteCommandResult.error('已有克隆任务正在进行');
    }

    _isCloning = true;
    _cloneProgress = null;
    _lastRemoteError = null;
    _remoteLog = '';
    _remoteCancelToken = cancelToken ?? HeadlessCancelToken();
    notifyListeners();

    try {
      await _prepareRemoteOperation();
      final res = await _gitService.clone(
        parentDir,
        url,
        targetDirName,
        rootPath: parentDir,
        branch: branch,
        depth: depth,
        onProgress: _onCloneProgress,
        cancelToken: _remoteCancelToken,
      );
      _remoteLog = res.combinedOutput.trim();
      if (!res.success && !res.cancelled) {
        _lastRemoteError = GitErrorMapper.describe(res.stderr, stdout: res.stdout);
      }
      return res;
    } finally {
      _isCloning = false;
      _cloneProgress = null;
      _remoteCancelToken = null;
      notifyListeners();
    }
  }

  void _onCloneProgress(GitOperationProgress progress) {
    _cloneProgress = progress;
    notifyListeners();
  }

  /// 取消进行中的克隆
  void cancelClone() {
    if (!_isCloning) return;
    _remoteCancelToken?.cancel();
    notifyListeners();
  }

  /// 放弃进行中的 rebase（冲突后的退出路径）
  Future<GitCommandResult> abortRebase() async {
    if (_currentRepoPath == null) return GitCommandResult.error('未选择仓库');
    final res = await _gitService.abortRebase(_currentRepoPath!);
    if (res.success) {
      await _loadCurrentRepoDetails();
      notifyListeners();
    }
    return res;
  }

  /// 仓库是否正处于 rebase 中间状态
  bool get isRebaseInProgress =>
      _currentRepoPath != null && _gitService.isRebaseInProgress(_currentRepoPath!);

  /// 贮藏本地改动后拉取（不自动 pop，避免冲突被静默带入工作区）
  ///
  /// 拉取成功后本地改动仍在 stash 栈中，由用户在需要时手动恢复，
  /// 这样"贮藏"这个动作始终对用户可见、可回退。
  Future<({bool success, GitRemoteCommandResult? pullResult, GitCommandResult? stashResult})>
      stashAndPull() async {
    if (_currentRepoPath == null) {
      return (success: false, pullResult: null, stashResult: null);
    }

    final stashRes = await _gitService.stash(
      _currentRepoPath!,
      message: 'Auto-stash before pull',
    );
    if (!stashRes.success) {
      return (success: false, pullResult: null, stashResult: stashRes);
    }
    await _loadCurrentRepoDetails();

    final pullRes = await pull();
    return (
      success: pullRes.success,
      pullResult: pullRes,
      stashResult: stashRes,
    );
  }

  /// 预先计算文件和目录的 Git 状态映射，将文件树每帧查询时间复杂度从 O(N*M) 降至 O(1)
  void _rebuildStatusMaps() {
    final fileMap = <String, GitFileStatus>{};
    final dirMap = <String, GitFileStatusType>{};

    for (final file in _changedFiles) {
      final normalizedFilePath = p.normalize(file.path);
      fileMap[normalizedFilePath] = file;
      fileMap[normalizedFilePath.toLowerCase()] = file;

      // 自底向上聚合所有祖先目录状态（高优先级覆盖低优先级）
      var currentDir = p.dirname(normalizedFilePath);
      while (currentDir.isNotEmpty && currentDir != '.' && currentDir != p.dirname(currentDir)) {
        final currentType = dirMap[currentDir];
        if (currentType == null ||
            GitDecorationUtils.getPriority(file.statusType) >
                GitDecorationUtils.getPriority(currentType)) {
          dirMap[currentDir] = file.statusType;
          dirMap[currentDir.toLowerCase()] = file.statusType;
        }

        // 避免向上越界超出仓库根目录或项目根目录
        if (_currentRepoPath != null &&
            (currentDir == p.normalize(_currentRepoPath!) ||
                currentDir.toLowerCase() == p.normalize(_currentRepoPath!).toLowerCase())) {
          break;
        }
        if (_rootPath != null &&
            (currentDir == p.normalize(_rootPath!) ||
                currentDir.toLowerCase() == p.normalize(_rootPath!).toLowerCase())) {
          break;
        }
        final parent = p.dirname(currentDir);
        if (parent == currentDir) break;
        currentDir = parent;
      }
    }

    _fileStatusMap = fileMap;
    _dirStatusMap = dirMap;
  }

  /// 测试辅助方法
  @visibleForTesting
  void setStateForTesting({
    String? rootPath,
    List<GitRepositoryInfo>? repositories,
    String? currentRepoPath,
    bool? gitInstalled,
    bool? isLoading,
    bool? isInitializing,
    List<GitFileStatus>? changedFiles,
    String? currentBranch,
    bool? isCurrentRefTag,
    List<String>? branches,
    List<String>? tags,
    List<GitCommit>? commits,
    int? stashCount,
    int? totalCommitsCount,
    int? commitsLimit,
    String? errorMessage,
    bool? stagedExpanded,
    bool? unstagedExpanded,
    bool? graphExpanded,
    bool? showTagsInSelector,
    String? commitMessage,
    double? scrollOffset,
    List<GitRemote>? remotes,
    GitBranchTracking? tracking,
    bool? isFetching,
    bool? isPulling,
    bool? isPushing,
    GitOperationProgress? remoteProgress,
    String? remoteLog,
    GitErrorInfo? lastRemoteError,
    DateTime? lastFetchAt,
  }) {
    if (rootPath != null) _rootPath = rootPath;
    if (repositories != null) _repositories = repositories;
    if (currentRepoPath != null) _currentRepoPath = currentRepoPath;
    if (gitInstalled != null) _gitInstalled = gitInstalled;
    if (isLoading != null) _isLoading = isLoading;
    if (isInitializing != null) _isInitializing = isInitializing;
    if (changedFiles != null) {
      _changedFiles = changedFiles;
      _rebuildStatusMaps();
    }
    if (currentBranch != null) _currentBranch = currentBranch;
    if (isCurrentRefTag != null) _isCurrentRefTag = isCurrentRefTag;
    if (branches != null) _branches = branches;
    if (tags != null) _tags = tags;
    if (commits != null) {
      _commits = commits;
      if (totalCommitsCount == null) {
        _totalCommitsCount = commits.length;
      }
    }
    if (stashCount != null) _stashCount = stashCount;
    if (totalCommitsCount != null) _totalCommitsCount = totalCommitsCount;
    if (commitsLimit != null) _commitsLimit = commitsLimit;
    if (errorMessage != null) _errorMessage = errorMessage;
    if (stagedExpanded != null) _stagedExpanded = stagedExpanded;
    if (unstagedExpanded != null) _unstagedExpanded = unstagedExpanded;
    if (graphExpanded != null) _graphExpanded = graphExpanded;
    if (showTagsInSelector != null) _showTagsInSelector = showTagsInSelector;
    if (commitMessage != null) _commitMessage = commitMessage;
    if (scrollOffset != null) _scrollOffset = scrollOffset;
    if (remotes != null) _remotes = remotes;
    if (tracking != null) _tracking = tracking;
    if (isFetching != null) _isFetching = isFetching;
    if (isPulling != null) _isPulling = isPulling;
    if (isPushing != null) _isPushing = isPushing;
    if (remoteProgress != null) _remoteProgress = remoteProgress;
    if (remoteLog != null) _remoteLog = remoteLog;
    if (lastRemoteError != null) _lastRemoteError = lastRemoteError;
    if (lastFetchAt != null) _lastFetchAt = lastFetchAt;
    notifyListeners();
  }
}
