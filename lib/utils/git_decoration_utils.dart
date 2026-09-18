import 'package:flutter/material.dart';
import '../models/git_model.dart';

/// VS Code 风格的 Git 状态装饰工具类
class GitDecorationUtils {
  /// 获取状态对应的文字/圆点颜色（自适应暗黑与明亮主题）
  static Color getStatusColor(GitFileStatusType type, {required bool isDark}) {
    switch (type) {
      case GitFileStatusType.modified:
        // VS Code Modified 经典暖沙金/琥珀色
        return isDark ? const Color(0xFFE2C08D) : const Color(0xFFB58900);
      case GitFileStatusType.untracked:
      case GitFileStatusType.added:
        // VS Code Untracked / Added 浅草绿
        return isDark ? const Color(0xFF73C991) : const Color(0xFF2E7D32);
      case GitFileStatusType.deleted:
        // VS Code Deleted 砖红
        return isDark ? const Color(0xFFE06C75) : const Color(0xFFC62828);
      case GitFileStatusType.unmerged:
        // VS Code Merge Conflict 醒目亮红
        return isDark ? const Color(0xFFFF5370) : const Color(0xFFD32F2F);
      case GitFileStatusType.renamed:
      case GitFileStatusType.copied:
        // 青色
        return isDark ? const Color(0xFF56B6C2) : const Color(0xFF00838F);
      case GitFileStatusType.typeChange:
        return isDark ? const Color(0xFFE5C07B) : const Color(0xFF8A6D3B);
      case GitFileStatusType.ignored:
        return isDark ? const Color(0xFF7F848E) : const Color(0xFF9E9E9E);
      case GitFileStatusType.unknown:
        return isDark ? const Color(0xFFABB2BF) : const Color(0xFF616161);
    }
  }

  /// 获取文件在右侧显示的状态缩写字母（如 M, U, A, D, !）
  static String? getStatusLetter(GitFileStatusType type) {
    switch (type) {
      case GitFileStatusType.modified:
        return 'M';
      case GitFileStatusType.untracked:
        return 'U';
      case GitFileStatusType.added:
        return 'A';
      case GitFileStatusType.deleted:
        return 'D';
      case GitFileStatusType.unmerged:
        return '!';
      case GitFileStatusType.renamed:
        return 'R';
      case GitFileStatusType.copied:
        return 'C';
      case GitFileStatusType.typeChange:
        return 'T';
      case GitFileStatusType.ignored:
      case GitFileStatusType.unknown:
        return null;
    }
  }

  /// 状态优先级（用于目录层级聚合：冲突 > 删除 > 修改 > 新增 > 未跟踪 > 其他）
  static int getPriority(GitFileStatusType type) {
    switch (type) {
      case GitFileStatusType.unmerged:
        return 50;
      case GitFileStatusType.deleted:
        return 40;
      case GitFileStatusType.modified:
        return 30;
      case GitFileStatusType.added:
        return 20;
      case GitFileStatusType.untracked:
        return 15;
      case GitFileStatusType.renamed:
      case GitFileStatusType.copied:
      case GitFileStatusType.typeChange:
        return 10;
      case GitFileStatusType.ignored:
        return 5;
      case GitFileStatusType.unknown:
        return 0;
    }
  }
}
