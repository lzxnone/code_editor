import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/editor_provider.dart';
import 'package:code_editor/views/main_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditorProvider()..init(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false, 
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        title: 'Flutter Demo',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          fontFamilyFallback: const [
            'PingFang SC',       // iOS / macOS
            'Noto Sans SC',      // Android
            'Microsoft YaHei',   // Windows
            'WenQuanYi Micro Hei', // Linux
            'sans-serif',        // Web & generic fallback
          ],
        ),
        home: const MainView(),
      ),
    );
  }
}