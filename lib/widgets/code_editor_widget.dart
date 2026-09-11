import 'dart:convert';

import 'package:code_editor/services/file_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/dart.dart';
import 'package:path/path.dart' as p;

class CodeEditorWidget extends StatefulWidget {
  final String? rootPath;
  final String? filePath;

  const CodeEditorWidget({
    super.key,
    required this.rootPath,
    required this.filePath
  });

  @override
  State<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends State<CodeEditorWidget> {
  final CodeController _controller = CodeController();
  bool _isLoading = false;
  int _currentLoadVersion = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }

  @override
  void didUpdateWidget(covariant CodeEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath || oldWidget.rootPath != widget.rootPath) {
      _loadFileContent();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasNoProject = widget.rootPath == null || widget.rootPath!.trim().isEmpty;
    final hasNoFile = widget.filePath == null || widget.filePath!.trim().isEmpty;

    if (hasNoProject && hasNoFile) {
      return Center(
        child: Text(
          "当前未打开文件目录",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }

    if (hasNoFile) {
      return Center(
        child: Text(
          "当前未打开文件",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // atomOneDark 默认背景色为 0xFF282C34
    const editorBgColor = Color(0xFF282C34);

    return Container(
      color: editorBgColor,
      width: double.infinity,
      height: double.infinity,
      child: CodeTheme(
        data: CodeThemeData(styles: atomOneDarkTheme),
        child: SingleChildScrollView(
          child: CodeField(
            controller: _controller,
            gutterStyle: const GutterStyle(
              showLineNumbers: true,
              showFoldingHandles: true,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadFileContent() async {
    final rootPath = widget.rootPath;
    final filePath = widget.filePath;
    final hasNoProject = rootPath == null || rootPath.trim().isEmpty;
    final hasNoFile = filePath == null || filePath.trim().isEmpty;

    if (hasNoFile) {
      _controller.text = '';
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    final String fullFilePath = (hasNoProject || p.isAbsolute(filePath))
        ? filePath
        : p.join(rootPath, filePath);

    final int requestVersion = ++_currentLoadVersion;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final content = await FileService.instance.readFileContent(fullFilePath);
      if(!mounted || requestVersion != _currentLoadVersion) {
        return;
      }
      _controller.language = _resolveLanguage(fullFilePath);
      _controller.text = content;

    }catch(e) {
      if(!mounted || requestVersion != _currentLoadVersion) return;
      setState(() {
        _errorMessage = '$e';
      });
    }finally {
      if(mounted && requestVersion == _currentLoadVersion) {
        setState(() => _isLoading = false);
      }
    }
  }

  dynamic _resolveLanguage(String path) {
    if(path.endsWith('.dart')) return dart;
    if(path.endsWith('.json')) return json;
    return null;
  }
}