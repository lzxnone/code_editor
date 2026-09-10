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
    if(_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return CodeTheme(
      data: CodeThemeData(styles: atomOneDarkTheme),
      child: CodeField(
        controller: _controller,
        gutterStyle: const GutterStyle(
          showLineNumbers: true,
          showFoldingHandles: true,
        ),
      ),
    );
  }

  Future<void> _loadFileContent() async {
    String? fullFilePath;
    final filePath = widget.filePath;
    final rootPath = widget.rootPath;

    if (filePath != null && filePath.isNotEmpty) {
      if (rootPath != null && rootPath.isNotEmpty && !p.isAbsolute(filePath)) {
        fullFilePath = p.join(rootPath, filePath);
      } else {
        fullFilePath = filePath;
      }
    }

    if(fullFilePath == null) {
      _controller.text = '';
      if(mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

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
        _errorMessage = '读取文件失败: $e';
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