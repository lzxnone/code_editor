import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/git_provider.dart';
import 'package:code_editor/providers/notice_center.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/search_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/services/background_task/background_task_scheduler.dart';
import 'package:code_editor/views/main_view.dart';
import 'package:code_editor/utils/app_theme.dart';
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
        ChangeNotifierProxyProvider<SettingsProvider, ProjectProvider>(
          create: (_) => ProjectProvider()..init(),
          update: (_, settings, project) {
            final pp = project ?? (ProjectProvider()..init());
            pp.updateShowHiddenFiles(settings.showHiddenFiles);
            return pp;
          },
        ),
        ChangeNotifierProxyProvider<ProjectProvider, GitProvider>(
          create: (_) => GitProvider(),
          update: (_, project, git) =>
              (git ?? GitProvider())..bindRootPath(project.rootPath),
        ),
        ChangeNotifierProxyProvider2<ProjectProvider, GitProvider, TabProvider>(
          create: (_) => TabProvider()..init(),
          update: (_, project, git, tab) =>
              (tab ?? (TabProvider()..init()))
                ..bindProjectProvider(project)
                ..bindGitProvider(git),
        ),
        ChangeNotifierProxyProvider<ProjectProvider, SearchProvider>(
          create: (_) => SearchProvider(),
          update: (_, project, search) =>
              (search ?? SearchProvider())..bindRootPath(project.rootPath),
        ),
        ChangeNotifierProvider(create: (_) => TerminalProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final nc = NoticeCenter();
            BackgroundTaskScheduler.instance.attachNoticeCenter(nc);
            return nc;
          },
        ),
        ChangeNotifierProvider(
          create: (context) => RunProvider(noticeCenter: context.read<NoticeCenter>()),
        ),
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
            theme: buildAppTheme(
              seedColor: settings.appThemeColor,
              brightness: Brightness.light,
              fontFamily: settings.uiFont.fontFamily,
              fontFamilyFallback: settings.uiFont.fallback,
            ),
            darkTheme: buildAppTheme(
              seedColor: settings.appThemeColor,
              brightness: Brightness.dark,
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
