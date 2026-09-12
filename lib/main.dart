import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()..init()),
        ChangeNotifierProxyProvider<ProjectProvider, TabProvider>(
          create: (_) => TabProvider()..init(),
          update: (_, project, tab) =>
              (tab ?? (TabProvider()..init()))..bindProjectProvider(project),
        ),
        ChangeNotifierProvider(create: (_) => TerminalProvider()),
        ChangeNotifierProvider(create: (_) => DistroProvider()..checkAllStatuses()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false, 
            locale: settings.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
            themeMode: settings.appThemeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
              fontFamily: settings.uiFont.fontFamily,
              fontFamilyFallback: settings.uiFont.fallback,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              fontFamily: settings.uiFont.fontFamily,
              fontFamilyFallback: settings.uiFont.fallback,
            ),
            home: const MainView(),
          );
        },
      ),
    );
  }
}
