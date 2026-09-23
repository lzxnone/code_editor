import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class FileIconUtils {
  FileIconUtils._();

  /// 根据路径/名称、扩展名以及是否为文件夹获取匹配的图标
  static IconData getIcon({
    required String name,
    bool isDirectory = false,
    bool isOpen = false,
  }) {
    if (isDirectory) {
      return isOpen ? Icons.folder_open_outlined : Icons.folder_outlined;
    }

    final lowerName = name.toLowerCase();
    if (lowerName == '.gitignore' ||
        lowerName == '.gitattributes' ||
        lowerName == '.gitmodules') {
      return Icons.commit_outlined;
    }
    if (lowerName == 'pack.mcmeta') {
      return Icons.inventory_2_outlined;
    }

    final ext = p.extension(name).toLowerCase();
    return switch (ext) {
      '.mcfunction' => Icons.integration_instructions_outlined,
      '.dart' => Icons.flutter_dash,
      '.html' || '.htm' => Icons.html,
      '.css' || '.scss' || '.sass' || '.less' => Icons.css,
      '.js' || '.mjs' || '.cjs' => Icons.javascript,
      '.ts' || '.tsx' || '.jsx' || '.vue' || '.svelte' => Icons.code,
      '.json' => Icons.data_object,
      '.yaml' ||
      '.yml' ||
      '.toml' ||
      '.ini' ||
      '.env' ||
      '.conf' ||
      '.config' ||
      '.properties' =>
        Icons.settings_suggest_outlined,
      '.xml' => Icons.code,
      '.md' || '.markdown' => Icons.article_outlined,
      '.pdf' => Icons.picture_as_pdf_outlined,
      '.py' ||
      '.pyw' ||
      '.java' ||
      '.kt' ||
      '.kts' ||
      '.c' ||
      '.cpp' ||
      '.cc' ||
      '.h' ||
      '.hpp' ||
      '.cs' ||
      '.go' ||
      '.rs' ||
      '.swift' ||
      '.rb' ||
      '.php' =>
        Icons.code,
      '.sh' || '.bash' || '.zsh' || '.bat' || '.cmd' || '.ps1' =>
        Icons.terminal,
      '.sql' || '.db' || '.sqlite' => Icons.storage_outlined,
      '.png' ||
      '.jpg' ||
      '.jpeg' ||
      '.gif' ||
      '.webp' ||
      '.svg' ||
      '.ico' ||
      '.bmp' =>
        Icons.image_outlined,
      '.mp3' || '.wav' || '.ogg' || '.flac' || '.aac' =>
        Icons.audio_file_outlined,
      '.mp4' || '.avi' || '.mov' || '.mkv' || '.flv' || '.webm' =>
        Icons.video_file_outlined,
      '.zip' || '.rar' || '.7z' || '.tar' || '.gz' =>
        Icons.folder_zip_outlined,
      '.lock' => Icons.lock_outline,
      _ => Icons.description_outlined,
    };
  }
}
