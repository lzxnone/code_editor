import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/virtual_keyboard_config.dart';

/// 编辑或添加虚拟小键盘按键的独立弹窗
class KeyEditDialog extends StatefulWidget {
  final KeyboardScope scope;
  final KeyboardKeyItem? initialKey;

  const KeyEditDialog({
    super.key,
    required this.scope,
    this.initialKey,
  });

  @override
  State<KeyEditDialog> createState() => _KeyEditDialogState();
}

class _KeyEditDialogState extends State<KeyEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _labelController;
  late TextEditingController _valueInputController;
  late TextEditingController _pairValueController;
  late TextEditingController _cursorOffsetController;

  String? _selectedIcon;
  late String _selectedAction;
  String? _selectedPresetValue;

  /// 终端特殊键：所选 TerminalKey 枚举名
  String? _selectedNamedKey;

  /// 终端特殊键：下方三个修饰键控件组成的组合
  KeyboardKeyMods _selectedMods = KeyboardKeyMods.none;

  /// 终端修饰键动作：所选的 ctrl / alt / shift
  String _selectedModifierValue = 'ctrl';

  /// 终端指令快捷键：发送后是否自动回车
  bool _autoEnter = false;

  bool get _isTerminal => widget.scope == KeyboardScope.terminal;

  @override
  void initState() {
    super.initState();
    final init = widget.initialKey;

    _labelController = TextEditingController(text: init?.label ?? '');
    _valueInputController = TextEditingController(text: init?.value ?? '');
    // 成对符号不再依赖预设列表，改为自由输入，默认给出最常用的圆括号
    _pairValueController = TextEditingController(
      text: (init != null && init.action == 'pair' && init.value.isNotEmpty) ? init.value : '()',
    );
    _cursorOffsetController = TextEditingController(
      text: (init?.cursorOffset ?? (init?.action == 'pair' ? -1 : 0)).toString(),
    );

    _selectedIcon = (init?.icon != null && KeyboardIconHelper.getIcon(init!.icon) != null)
        ? init.icon
        : null;

    final availableActions = widget.scope == KeyboardScope.editor
        ? KeyboardScopeHelper.editorActions
        : KeyboardScopeHelper.terminalActions;

    if (init != null && availableActions.any((a) => a.action == init.action)) {
      _selectedAction = init.action;
    } else {
      _selectedAction = availableActions.first.action;
    }

    _syncPresetValueFromInitial();
  }

  void _syncPresetValueFromInitial() {
    final init = widget.initialKey;
    final currentVal = init?.value ?? '';

    _autoEnter = init?.autoEnter ?? false;
    _selectedMods = (init != null && init.action == 'key') ? init.mods : KeyboardKeyMods.none;

    // 终端修饰键动作取值
    _selectedModifierValue = KeyboardScopeHelper.terminalModifierValues.contains(currentVal)
        ? currentVal
        : KeyboardScopeHelper.terminalModifierValues.first;

    // 终端特殊键取值（支持 31 命名键与 keyA~keyZ）
    _selectedNamedKey = (init != null &&
            init.action == 'key' &&
            KeyboardScopeHelper.terminalSupportedKeyNames.contains(currentVal))
        ? currentVal
        : KeyboardScopeHelper.terminalNamedKeys.first.value;

    if (_selectedAction == 'command') {
      _selectedPresetValue = KeyboardScopeHelper.editorCommands.any((c) => c.value == currentVal)
          ? currentVal
          : KeyboardScopeHelper.editorCommands.first.value;
    } else {
      _selectedPresetValue = null;
    }
  }

  /// 动作在下拉中的显示名（终端作用域下 input 即"指令快捷键"）
  String _actionLabel(AppLocalizations l10n, String action) {
    if (_isTerminal && action == 'input') {
      return l10n.keyboardActionInputTerminal;
    }
    return l10n.keyboardActionName(action);
  }

  /// 按键标签留空时的兜底文案：特殊键用「修饰符+紧凑键名」，其余沿用 value
  String _fallbackLabel(String value, KeyboardKeyMods mods) {
    if (_selectedAction != 'key') return value;
    final prefix = [
      if (mods.ctrl) 'Ctrl',
      if (mods.alt) 'Alt',
      if (mods.shift) 'Shift',
    ];
    final short = KeyboardScopeHelper.terminalKeyShortLabel(value);
    return prefix.isEmpty ? short : '${prefix.join('+')}+$short';
  }

  /// 终端特殊键下拉：按分组插入不可选的标题项
  List<DropdownMenuItem<String?>> _buildNamedKeyItems(AppLocalizations l10n) {
    final items = <DropdownMenuItem<String?>>[];
    TerminalKeyGroup? lastGroup;

    for (final option in KeyboardScopeHelper.terminalSelectableKeys) {
      if (option.group != lastGroup) {
        lastGroup = option.group;
        items.add(
          DropdownMenuItem<String?>(
            value: null,
            enabled: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _groupLabel(l10n, option.group),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      }
      items.add(
        DropdownMenuItem<String?>(
          value: option.value,
          child: Row(
            children: [
              Icon(KeyboardIconHelper.getIcon(option.icon), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  // 字母键在每种语言下都显示同一个拉丁字母，无需走 l10n
                  KeyboardScopeHelper.isLetterKeyName(option.value)
                      ? KeyboardScopeHelper.terminalKeyShortLabel(option.value)
                      : l10n.keyboardKeyName(option.value),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return items;
  }

  String _groupLabel(AppLocalizations l10n, TerminalKeyGroup group) {
    switch (group) {
      case TerminalKeyGroup.navigation:
        return l10n.keyboardKeyGroupNavigation;
      case TerminalKeyGroup.editing:
        return l10n.keyboardKeyGroupEditing;
      case TerminalKeyGroup.functionKeys:
        return l10n.keyboardKeyGroupFunctionKeys;
      case TerminalKeyGroup.letters:
        return l10n.keyboardKeyGroupLetters;
    }
  }

  /// 下方三个修饰键控件之一；切换后立即重新校验，避免出现静默无效的组合
  Widget _buildModifierChip(AppLocalizations l10n, String modifier, bool selected) {
    return FilterChip(
      label: Text(l10n.keyboardModifierName(modifier)),
      selected: selected,
      onSelected: (value) {
        setState(() {
          KeyboardKeyMods mods = _selectedMods;
          switch (modifier) {
            case 'ctrl':
              mods = mods.copyWith(ctrl: value);
              break;
            case 'alt':
              mods = mods.copyWith(alt: value);
              break;
            case 'shift':
              mods = mods.copyWith(shift: value);
              break;
          }
          _selectedMods = mods;
        });
        _formKey.currentState?.validate();
      },
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _valueInputController.dispose();
    _pairValueController.dispose();
    _cursorOffsetController.dispose();
    super.dispose();
  }

  void _onActionChanged(String? newAction) {
    if (newAction == null || newAction == _selectedAction) return;
    setState(() {
      _selectedAction = newAction;
      if (_selectedAction == 'pair') {
        if (_pairValueController.text.trim().isEmpty) {
          _pairValueController.text = '()';
        }
        if (_cursorOffsetController.text.isEmpty || _cursorOffsetController.text == '0') {
          _cursorOffsetController.text = '-1';
        }
        // 标签留空时由 _onSave 回退为成对符号内容，与 input 行为一致
      } else if (_selectedAction == 'command') {
        _selectedPresetValue = KeyboardScopeHelper.editorCommands.first.value;
      } else if (_selectedAction == 'modifier') {
        _selectedModifierValue = KeyboardScopeHelper.terminalModifierValues.first;
      } else if (_selectedAction == 'key') {
        _selectedNamedKey ??= KeyboardScopeHelper.terminalNamedKeys.first.value;
      } else {
        _selectedPresetValue = null;
      }
    });
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final String label = _labelController.text.trim();
    String value;
    int cursorOffset = 0;
    KeyboardKeyMods mods = KeyboardKeyMods.none;
    bool autoEnter = false;

    switch (_selectedAction) {
      case 'input':
        value = _valueInputController.text;
        if (_isTerminal) autoEnter = _autoEnter;
        break;
      case 'pair':
        value = _pairValueController.text.trim();
        cursorOffset = int.tryParse(_cursorOffsetController.text.trim()) ?? -1;
        break;
      case 'key':
        value = _selectedNamedKey ?? '';
        mods = _selectedMods;
        break;
      case 'modifier':
        value = _selectedModifierValue;
        break;
      default:
        value = _selectedPresetValue ?? '';
    }

    final keyItem = KeyboardKeyItem(
      label: label.isNotEmpty ? label : _fallbackLabel(value, mods),
      icon: (_selectedIcon != null && _selectedIcon!.isNotEmpty) ? _selectedIcon : null,
      action: _selectedAction,
      value: value,
      cursorOffset: cursorOffset,
      mods: mods,
      autoEnter: autoEnter,
    );

    Navigator.of(context).pop(keyItem);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final availableActions = widget.scope == KeyboardScope.editor
        ? KeyboardScopeHelper.editorActions
        : KeyboardScopeHelper.terminalActions;

    return AlertDialog(
      title: Text(widget.initialKey == null ? l10n.keyboardAddKeyTitle : l10n.keyboardEditKeyTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 显示标签 Label
                TextFormField(
                  controller: _labelController,
                  decoration: InputDecoration(
                    labelText: l10n.keyboardLabelFormField,
                    hintText: l10n.keyboardLabelFormFieldHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (val) {
                    if ((val == null || val.trim().isEmpty) &&
                        (_selectedIcon == null || _selectedIcon!.isEmpty) &&
                        _selectedAction == 'input' &&
                        _valueInputController.text.trim().isEmpty) {
                      return l10n.keyboardLabelOrIconRequiredError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 内置图标选择 Icon
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _selectedIcon,
                  decoration: InputDecoration(
                    labelText: l10n.keyboardIconFormField,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.keyboardNoIconOption, overflow: TextOverflow.ellipsis),
                    ),
                    ...KeyboardIconHelper.supportedIconKeys.map(
                      (iconKey) => DropdownMenuItem<String?>(
                        value: iconKey,
                        child: Row(
                          children: [
                            Icon(KeyboardIconHelper.getIcon(iconKey), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.keyboardIconName(iconKey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedIcon = val;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // 动作类型 Action
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedAction,
                  decoration: InputDecoration(
                    labelText: l10n.keyboardActionFormField,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: availableActions.map(
                    (actionOption) => DropdownMenuItem<String>(
                      value: actionOption.action,
                      child: Text(
                        _actionLabel(l10n, actionOption.action),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ).toList(),
                  onChanged: _onActionChanged,
                ),
                const SizedBox(height: 14),

                // 动作值 Value 控件联动
                if (_selectedAction == 'input') ...[
                  TextFormField(
                    controller: _valueInputController,
                    decoration: InputDecoration(
                      labelText: l10n.keyboardValueFormField,
                      hintText: l10n.keyboardValueFormFieldHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return l10n.keyboardValueRequiredError;
                      }
                      return null;
                    },
                  ),
                  // 终端指令快捷键：发送后补回车，实现"一格执行命令"
                  if (_isTerminal)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(l10n.keyboardAutoEnter),
                      value: _autoEnter,
                      onChanged: (val) => setState(() => _autoEnter = val),
                    ),
                ]
                else if (_selectedAction == 'pair')
                  TextFormField(
                    controller: _pairValueController,
                    decoration: InputDecoration(
                      labelText: l10n.keyboardPairValueFormField,
                      hintText: l10n.keyboardPairValueFormFieldHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (val) {
                      final v = val?.trim() ?? '';
                      if (v.isEmpty) {
                        return l10n.keyboardPairValueRequiredError;
                      }
                      final half = v.length ~/ 2;
                      // 长度不足 2 或左右完全相同（如 "((" ）无法构成有效的前后半段
                      if (v.length < 2 ||
                          (v.length.isEven && v.substring(0, half) == v.substring(half))) {
                        return l10n.keyboardPairValueInvalidError;
                      }
                      return null;
                    },
                  )
                else if (_selectedAction == 'command')
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedPresetValue,
                    decoration: InputDecoration(
                      labelText: l10n.keyboardCommandPresetFormField,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: KeyboardScopeHelper.editorCommands.map(
                      (cmd) => DropdownMenuItem<String>(
                        value: cmd.value,
                        child: Row(
                          children: [
                            Icon(KeyboardIconHelper.getIcon(cmd.icon), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.keyboardCommandName(cmd.value),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPresetValue = val;
                      });
                    },
                  )
                else if (_selectedAction == 'modifier')
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedModifierValue,
                    decoration: InputDecoration(
                      labelText: l10n.keyboardModifierPresetFormField,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: KeyboardScopeHelper.terminalModifierValues
                        .map(
                          (m) => DropdownMenuItem<String>(
                            value: m,
                            child: Text(l10n.keyboardModifierName(m), overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _selectedModifierValue = val;
                      });
                    },
                  )
                else if (_selectedAction == 'key') ...[
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _selectedNamedKey,
                    decoration: InputDecoration(
                      labelText: l10n.keyboardKeyFormField,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _buildNamedKeyItems(l10n),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _selectedNamedKey = val;
                      });
                    },
                    validator: (val) {
                      final name = val ?? '';
                      if (name.isEmpty || !KeyboardScopeHelper.isSupportedTerminalKey(name)) {
                        return l10n.keyboardKeyInvalidError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // 单独提供三个修饰键：与下拉里选中的键叠加成 Ctrl+C 这类组合
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildModifierChip(l10n, 'ctrl', _selectedMods.ctrl),
                      _buildModifierChip(l10n, 'alt', _selectedMods.alt),
                      _buildModifierChip(l10n, 'shift', _selectedMods.shift),
                    ],
                  ),
                ],

                // 仅当 action == pair 时显示 cursorOffset
                if (_selectedAction == 'pair') ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cursorOffsetController,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    decoration: InputDecoration(
                      labelText: l10n.keyboardCursorOffsetFormField,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return l10n.keyboardCursorOffsetRequiredError;
                      }
                      if (int.tryParse(val.trim()) == null) {
                        return l10n.keyboardCursorOffsetIntegerError;
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _onSave,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
