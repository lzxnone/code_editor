import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/git_model.dart';
import '../services/git_service.dart';
import '../utils/git_decoration_utils.dart';

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

      if (_rootPath != null) {
        refresh();
      } else {
        notifyListeners();
      }
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

      // 同步更新 repositories 列表中当前项的分支信息
      final idx = _repositories.indexWhere((r) => r.rootPath == _currentRepoPath);
      if (idx != -1) {
        _repositories[idx] = _repositories[idx].copyWith(currentBranch: _currentBranch);
      }
    } catch (e) {
      debugPrint('[GitProvider] 加载仓库详情异常: $e');
    }
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
    notifyListeners();
  }
}
