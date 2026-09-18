import 'package:flutter/material.dart';
import '../../models/git_model.dart';

/// VS Code 风格 Git 提交历史拓扑图绘制器
class GitGraphPainter extends CustomPainter {
  final GitCommit commit;
  final bool isFirstCommit;
  final ColorScheme colorScheme;

  static const double laneWidth = 14.0;
  static const double startOffset = 14.0;

  // 经典多分支着色调色板
  static const List<Color> laneColors = [
    Color(0xFF2196F3), // 蓝
    Color(0xFF4CAF50), // 绿
    Color(0xFFFF9800), // 橙
    Color(0xFFE91E63), // 粉红
    Color(0xFF9C27B0), // 紫
    Color(0xFF00BCD4), // 青
    Color(0xFFFFEB3B), // 黄
    Color(0xFF795548), // 棕
  ];

  static Color getLaneColor(int lane) {
    return laneColors[lane % laneColors.length];
  }

  const GitGraphPainter({
    required this.commit,
    required this.isFirstCommit,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final nodeX = startOffset + commit.lane * laneWidth;
    final nodeColor = getLaneColor(commit.lane);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // 1. 绘制穿透此行的其他活跃通道
    for (final lane in commit.activeLanes) {
      if (lane == commit.lane) continue;
      final x = startOffset + lane * laneWidth;
      linePaint.color = getLaneColor(lane);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    // 2. 绘制进入当前节点的连线（如果不是首个展示的提交，说明上方有子提交连入）
    if (!isFirstCommit) {
      linePaint.color = nodeColor;
      canvas.drawLine(Offset(nodeX, 0), Offset(nodeX, centerY), linePaint);
    }

    // 3. 绘制当前节点连向父提交的连线
    for (final targetLane in commit.outgoingLanes) {
      final targetX = startOffset + targetLane * laneWidth;
      linePaint.color = nodeColor;

      if (targetLane == commit.lane) {
        // 直线向下连到下一行
        canvas.drawLine(Offset(nodeX, centerY), Offset(nodeX, size.height), linePaint);
      } else {
        // 跨分支弧线（贝塞尔平滑曲线）
        final path = Path();
        path.moveTo(nodeX, centerY);
        final controlY = centerY + (size.height - centerY) * 0.5;
        path.cubicTo(nodeX, controlY, targetX, controlY, targetX, size.height);
        canvas.drawPath(path, linePaint);
      }
    }

    // 4. 绘制提交节点
    final bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.surface;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = nodeColor;

    // 节点外围背景微隔离圈，防止与连线黏连
    canvas.drawCircle(Offset(nodeX, centerY), 6.5, bgPaint);

    if (commit.isHead) {
      // HEAD 节点：外圈光环 + 内部实心
      final haloPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = nodeColor;
      canvas.drawCircle(Offset(nodeX, centerY), 6.0, haloPaint);
      canvas.drawCircle(Offset(nodeX, centerY), 3.2, dotPaint);
    } else {
      // 普通节点：实心圆
      canvas.drawCircle(Offset(nodeX, centerY), 4.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GitGraphPainter oldDelegate) {
    return oldDelegate.commit != commit ||
        oldDelegate.isFirstCommit != isFirstCommit ||
        oldDelegate.colorScheme != colorScheme;
  }
}
