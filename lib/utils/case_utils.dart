/// 大小写保留与变换工具类（用于替换时的 Preserve Case 逻辑）
class CaseUtils {
  /// 根据原匹配字符串的大小写模式，将替换字符串转换为对应的大小写风格
  static String applyPreserveCase({
    required String original,
    required String replacement,
  }) {
    if (original.isEmpty || replacement.isEmpty) {
      return replacement;
    }

    // 1. 全大写 (ALL UPPERCASE): 例如 "FOO" -> "BAR"
    if (original == original.toUpperCase() && original != original.toLowerCase()) {
      return replacement.toUpperCase();
    }

    // 2. 全小写 (all lowercase): 例如 "foo" -> "bar"
    if (original == original.toLowerCase() && original != original.toUpperCase()) {
      return replacement.toLowerCase();
    }

    // 3. 首字母大写 (Title Case / Capitalized): 例如 "Foo" -> "Bar"
    final isFirstUpper = original[0] == original[0].toUpperCase() &&
        original[0] != original[0].toLowerCase();
    final isRestLower = original.length > 1 &&
        original.substring(1) == original.substring(1).toLowerCase();

    if (isFirstUpper && (original.length == 1 || isRestLower)) {
      if (replacement.length == 1) {
        return replacement.toUpperCase();
      }
      return replacement[0].toUpperCase() + replacement.substring(1).toLowerCase();
    }

    // 其他情况保留原 replacement
    return replacement;
  }
}
