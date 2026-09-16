import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/app_font.dart';
import 'package:code_editor/models/distro_manifest.dart';
import 'package:code_editor/models/terminal_session.dart';
import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/utils/terminal_theme_helper.dart';
import 'package:code_editor/widgets/distro_extract_dialog.dart';
import 'package:code_editor/widgets/terminal_drawer.dart';
import 'package:code_editor/widgets/terminal_keyboard_sink.dart';
import 'package:code_editor/widgets/terminal_modifier_state.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:code_editor/widgets/virtual_keyboard_widget.dart';
import 'package:code_editor/widgets/terminal_selection_overlay.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:xterm/xterm.dart' show TerminalInputHandler, defaultInputHandler;

/// 终端视图（支持多系统实例切换、全屏会话保持、右侧抽屉多会话管理与交互）
class TerminalView extends StatefulWidget {
  const TerminalView({super.key});

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // 首次或进入终端时：检测已安装系统。如果不存在任何系统，自动从软件内置导入 alpine
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final distroProvider = context.read<DistroProvider?>();
      final l10n = AppLocalizations.of(context)!;
      final defaultSessionName = l10n.sessionDefaultName;

      final projectRoot = context.read<ProjectProvider?>()?.rootPath;

      if (distroProvider == null) {
        context.read<TerminalProvider>().ensureInitialized(
              defaultName: defaultSessionName,
              workspacePath: projectRoot,
            );
        return;
      }

      await distroProvider.init();
      if (!mounted) return;

      if (!distroProvider.hasAnySystem) {
        // 自动从软件内置资源导入 Ubuntu 24.04（推荐主力开发环境），名称为 ubuntu
        final success = await DistroExtractDialog.show(
          context: context,
          systemName: DistroRepository.defaultSystemName,
          task: (onProgress, isCancelled) {
            return distroProvider.importBuiltinUbuntu(
              systemName: DistroRepository.defaultSystemName,
              onProgress: onProgress,
              isCancelled: isCancelled,
            );
          },
        );

        if (success && mounted) {
          final termProvider = context.read<TerminalProvider>();
          if (termProvider.isEmpty) {
            termProvider.createSession(
              name: defaultSessionName,
              distroId: DistroRepository.defaultSystemName,
              workspacePath: projectRoot,
              activate: true,
            );
          }
        }
      } else {
        // 已有系统，确保初始化首个会话
        final termProvider = context.read<TerminalProvider>();
        if (termProvider.isEmpty) {
          final system = distroProvider.selectedSystem ?? DistroRepository.defaultSystemName;
          termProvider.createSession(
            name: defaultSessionName,
            distroId: system,
            workspacePath: projectRoot,
            activate: true,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TerminalProvider>();

    final activeSession = provider.activeSession;
    final sessions = provider.sessions;
    final activeIndex = provider.activeIndex;

    final titleText = activeSession?.name ?? l10n.sessionDefaultName;
    // 副标题取自当前会话绑定的工作目录：若是内部项目则展示项目名，外部项目展示完整绝对路径
    final sessionWorkspace = activeSession?.workspacePath?.trim();
    final String? subtitleText = (sessionWorkspace != null && sessionWorkspace.isNotEmpty)
        ? (InternalProjectService.instance.isInternalProject(sessionWorkspace)
            ? p.basename(sessionWorkspace)
            : sessionWorkspace)
        : null;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titleText,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitleText != null)
              Text(
                subtitleText,
                style: TextStyle(
                  fontSize: 11.0,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // 系统选择与管理入口已收敛隐藏，统一使用默认主系统 (Ubuntu)
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: l10n.sessionListTooltip,
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: const TerminalDrawer(),
      body: sessions.isEmpty
          ? Center(
              child: Text(
                l10n.noActiveSessions,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : IndexedStack(
              index: (activeIndex >= 0 && activeIndex < sessions.length) ? activeIndex : 0,
              children: [
                for (final session in sessions)
                  _TerminalSessionBody(
                    key: ValueKey(session.id),
                    session: session,
                  ),
              ],
            ),
    );
  }
}

/// 单个真实交互式终端会话的终端渲染与交互容器
class _TerminalSessionBody extends StatefulWidget {
  final TerminalSession session;

  const _TerminalSessionBody({
    super.key,
    required this.session,
  });

  @override
  State<_TerminalSessionBody> createState() => _TerminalSessionBodyState();
}

class _TerminalSessionBodyState extends State<_TerminalSessionBody> {
  /// 小键盘修饰键的运行时状态：键盘组件与终端共用同一份
  late final TerminalModifierState _modifiers = TerminalModifierState();

  /// 终端控制器与 View GlobalKey（用于选区、手柄与上下文菜单定位）
  late final xterm.TerminalController _terminalController = xterm.TerminalController();
  final ScrollController _terminalScrollController = ScrollController();
  final GlobalKey<xterm.TerminalViewState> _terminalViewKey = GlobalKey<xterm.TerminalViewState>();

  /// 终端原有的输入处理器与输出出口（用于串联，而不是替换）
  TerminalInputHandler? _delegateInputHandler;
  void Function(String)? _delegateOnOutput;

  // 双指捏合缩放终端字号状态
  final Map<int, Offset> _pointerPositions = {};
  double? _initialPinchDistance;
  double? _initialPinchFontSize;
  double? _activeZoomFontSize;
  bool _isPinching = false;
  Offset? _initialLocalFocal;
  double _initialScrollV = 0.0;

  void _handlePointerDown(PointerDownEvent event, double currentFontSize) {
    _pointerPositions[event.pointer] = event.position;
    if (_pointerPositions.length == 2) {
      final points = _pointerPositions.values.toList();
      _initialPinchDistance = (points[0] - points[1]).distance;
      _initialPinchFontSize = _activeZoomFontSize ?? currentFontSize;

      final globalFocal = (points[0] + points[1]) / 2;
      final renderBox = context.findRenderObject() as RenderBox?;
      _initialLocalFocal = renderBox != null ? renderBox.globalToLocal(globalFocal) : globalFocal;
      _initialScrollV = _terminalScrollController.hasClients ? _terminalScrollController.offset : 0.0;

      // 双指缩放开始时，清除可能残留的选区，避免手柄或菜单错位
      _terminalController.clearSelection();

      setState(() {
        _isPinching = true;
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    _pointerPositions[event.pointer] = event.position;

    if (_pointerPositions.length >= 2 &&
        _initialPinchDistance != null &&
        _initialPinchDistance! > 10.0 &&
        _initialPinchFontSize != null &&
        _initialLocalFocal != null) {
      final points = _pointerPositions.values.toList();
      final currentDistance = (points[0] - points[1]).distance;
      final scale = currentDistance / _initialPinchDistance!;
      final rawFontSize = (_initialPinchFontSize! * scale).clamp(8.0, 32.0);
      final newFontSize = (rawFontSize * 10).round() / 10.0;
      final fontScale = newFontSize / _initialPinchFontSize!;

      final currentGlobalFocal = (points[0] + points[1]) / 2;
      final renderBox = context.findRenderObject() as RenderBox?;
      final currentLocalFocal = renderBox != null
          ? renderBox.globalToLocal(currentGlobalFocal)
          : currentGlobalFocal;

      if (_terminalScrollController.hasClients && _terminalScrollController.position.maxScrollExtent > 0) {
        final targetScrollV = (_initialScrollV + _initialLocalFocal!.dy) * fontScale - currentLocalFocal.dy;
        _terminalScrollController.jumpTo(targetScrollV.clamp(0.0, _terminalScrollController.position.maxScrollExtent));
      }

      if (_activeZoomFontSize != newFontSize) {
        setState(() {
          _activeZoomFontSize = newFontSize;
        });
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_pointerPositions.length < 2 && _isPinching) {
      _finishPinchZoom();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_pointerPositions.length < 2 && _isPinching) {
      _finishPinchZoom();
    }
  }

  void _finishPinchZoom() {
    final finalSize = _activeZoomFontSize;
    if (finalSize != null) {
      try {
        final settings = context.read<SettingsProvider?>();
        settings?.setTerminalFontSize(finalSize.roundToDouble());
      } catch (_) {}
    }
    setState(() {
      _isPinching = false;
      _initialPinchDistance = null;
      _initialPinchFontSize = null;
      _activeZoomFontSize = null;
      _initialLocalFocal = null;
      _initialScrollV = 0.0;
    });
  }

  @override
  void initState() {
    super.initState();
    final terminal = widget.session.terminal;

    // ① 按键事件（硬件键盘、小键盘 key 格）都会经过 inputHandler：
    //    把运行时修饰键叠加进事件，再交给 xterm 默认链路。
    _delegateInputHandler = terminal.inputHandler;
    terminal.inputHandler = ModifierAwareInputHandler(
      state: _modifiers,
      delegate: _delegateInputHandler ?? defaultInputHandler,
    );

    // ② 软键盘 / IME 打进来的字符不产生 KeyEvent，只能在这里改写。
    _delegateOnOutput = terminal.onOutput;
    terminal.onOutput = (data) {
      final transformed = applyModifierToTypedText(data, _modifiers.mods);
      _delegateOnOutput?.call(transformed ?? data);
      if (transformed != null) _modifiers.consume();
    };
  }

  @override
  void dispose() {
    final terminal = widget.session.terminal;
    if (terminal.inputHandler is ModifierAwareInputHandler) {
      terminal.inputHandler = _delegateInputHandler;
    }
    terminal.onOutput = _delegateOnOutput;
    _modifiers.dispose();
    _terminalScrollController.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final settings = context.watch<SettingsProvider?>();
    final terminalFont = settings?.terminalFont ?? AppFonts.terminalMonospace;
    final currentBaseFontSize = settings?.terminalFontSize ?? 13.0;
    final displayFontSize = _activeZoomFontSize ?? currentBaseFontSize;

    final terminalStyle = xterm.TerminalStyle(
      fontSize: displayFontSize,
      fontFamily: terminalFont.fontFamily ?? 'monospace',
      fontFamilyFallback: terminalFont.fallback,
    );

    // 终端小键盘：开关与配置均独立于编辑区
    final keyboardEnabled = settings?.keyboardEnabledFor(KeyboardScope.terminal) ?? false;
    final keyboardConfig = settings?.keyboardConfigFor(KeyboardScope.terminal);

    // 终端背景颜色（设置项）：容器与 xterm 主题保持一致
    final backgroundColor = settings?.terminalBackgroundColor ?? const Color(0xFF1E1E1E);

    return Container(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) => _handlePointerDown(e, currentBaseFontSize),
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                child: TerminalSelectionOverlay(
                  terminal: session.terminal,
                  controller: _terminalController,
                  terminalViewKey: _terminalViewKey,
                  scrollController: _terminalScrollController,
                  focusNode: session.focusNode,
                  child: xterm.TerminalView(
                    session.terminal,
                    key: _terminalViewKey,
                    controller: _terminalController,
                    scrollController: _terminalScrollController,
                    focusNode: session.focusNode,
                    autofocus: true,
                    theme: terminalThemeWithBackground(backgroundColor),
                    textStyle: terminalStyle,
                    cursorType: xterm.TerminalCursorType.block,
                    padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 20.0),
                  ),
                ),
              ),
            ),
            if (keyboardEnabled && keyboardConfig != null && keyboardConfig.hasKeys)
              VirtualKeyboardWidget(
                controller: null,
                focusNode: session.focusNode,
                sink: TerminalKeyboardSink(
                  terminal: session.terminal,
                  focusNode: session.focusNode,
                ),
                modifierState: _modifiers,
                config: keyboardConfig,
              ),
          ],
        ),
      ),
    );
  }
}
