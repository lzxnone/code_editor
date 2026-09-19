import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 按"主题色 + 亮暗 + 界面字体"构建应用主题。
///
/// 抽成纯函数便于单测：换一个 seed 应得到不同的 colorScheme。
ThemeData buildAppTheme({
  required Color seedColor,
  required Brightness brightness,
  String? fontFamily,
  List<String>? fontFamilyFallback,
}) {
  final isLight = brightness == Brightness.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      ),
    ),
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    // 窄屏（320~360dp）下给对话框留出边距，避免内容顶满屏幕两侧造成溢出。
    // 这里刻意用固定值而非按屏宽判断：ThemeData 是纯函数，便于单测且无副作用。
    dialogTheme: const DialogThemeData(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    ),
  );
}
