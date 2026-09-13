import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/views/main_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );
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
        ChangeNotifierProxyProvider<TerminalProvider, DistroProvider>(
          create: (_) => DistroProvider()..init(),
          update: (_, terminal, distro) {
            final dp = distro ?? (DistroProvider()..init());
            dp.onSystemDeleted = (deletedSystem) {
              terminal.removeSessionsForDistro(deletedSystem);
              if (!dp.hasAnySystem) {
                terminal.clearAllSessions();
              }
            };
            return dp;
          },
        ),
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
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ),
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
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                ),
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
