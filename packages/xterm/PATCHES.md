# 本地补丁说明（vendored xterm）

本目录是 `xterm` 的内置副本（vendored），来源：pub.dev `xterm 4.0.0`。
引入原因：上游 `4.0.0` 存在一个会破坏终端框选（选区无法绘制 / 复制为空）的内核缺陷，
而该缺陷位于包内部（无法在应用层通过公开 API 修正），因此内置并打补丁。

## 上游来源

- 包名 / 版本：`xterm` `4.0.0`
- 来源：`https://pub.dev/packages/xterm`（`xterm-4.0.0`）
- SHA256（pub.dev 归档）：`168dfedca77cba33fdb6f52e2cd001e9fde216e398e89335c19b524bb22da3a2`
- 复制范围：`lib/`、`pubspec.yaml`、`LICENSE`、`CHANGELOG.md`、`README.md`、`analysis_options.yaml`
  （未复制 `test/`、`example/`、`bin/`、`media/`、`script/`）

## 补丁清单

### 1. `lib/src/utils/circular_buffer.dart` → `IndexAwareCircularBuffer.trimStart()`

**上游缺陷**：原实现只调整 `_startIndex` / `_length`，既不 `_detach()` 被裁掉的元素，
也不同步 `_absoluteStartIndex`：

```dart
void trimStart(int count) {
  if (count > _length) count = _length;
  _startIndex += count;
  _startIndex %= _array.length;
  _length -= count;
}
```

后果一：`IndexedItem.index`（`_absoluteIndex - _absoluteStartIndex`）不再等于元素在列表中的位置，
而是整体偏移“被裁掉的行数”。`BufferLine.index` 正是 `CellAnchor.y` / `CellAnchor.offset` 的来源，
而同一个 `y` 在 xterm 内部被当作 `lines[y]` 下标使用（`RenderTerminal._paintSelection`、
`Buffer.createAnchorFromOffset`、`Buffer.getText(range)`、`TerminalController.selection`），
于是锚点与行坐标系自相矛盾：选区画不出来、复制得到空串或**别的行**。

后果二：被裁掉的行从不 `_detach()`，仍 `attached == true` 且留在 `_array` 中，
旧锚点既不失效、又会静默指向其它行（“僵尸锚点”）。

**触发链**：shell 的 `clear` / `Ctrl+L` 发出 `ESC[3J`（ED3，xterm-256color 带 `E3` 能力）
→ `Terminal.eraseScrollbackOnly()` → `Buffer.clearScrollback()` → `trimStart(scrollBack)`。
之后终端“再也无法框选”，且错误一直残留到会话销毁。

**修复**：委托给上游自身已验证的 `remove(0, count)` —— 它会 `_detach()` 被移除的元素，
并用 `_move()` 重新校准存活元素的绝对索引，两个后果一并消除。代价是“只调窗口”变成
O(存活元素) 的搬移，而调用场景（清空回滚缓冲）是低频操作。

守护测试：`test/xterm_trim_start_patch_test.dart`

## 重新 vendor / 升级流程

1. 删除本目录（`packages/xterm`）。
2. 从 pub cache 或 `pub.dev` 解包目标版本，按上面“复制范围”复制到本目录。
3. 依据本文件的“补丁清单”重新应用补丁（对照上游最新 `trimStart()` 实现）。
4. 更新本文件顶部的版本 / 来源 / SHA256。
5. 运行守护测试：`flutter test test/xterm_trim_start_patch_test.dart`。
   若上游已自行修复该缺陷，可删除补丁并保留测试（测试断言的是不变式，不是补丁本身）。
6. `flutter pub get` 后跑一遍终端相关测试：
   `flutter test test/terminal_selection_and_menu_test.dart test/terminal_test.dart test/toolchain_service_test.dart`
