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
  late TextEditingController _cursorOffsetController;

  String? _selectedIcon;
  late String _selectedAction;
  String? _selectedPresetValue;

  @override
  void initState() {
    super.initState();
    final init = widget.initialKey;

    _labelController = TextEditingController(text: init?.label ?? '');
    _valueInputController = TextEditingController(text: init?.value ?? '');
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
    final currentVal = widget.initialKey?.value ?? '';
    if (_selectedAction == 'command') {
      if (KeyboardScopeHelper.editorCommands.any((c) => c.value == currentVal)) {
        _selectedPresetValue = currentVal;
      } else {
        _selectedPresetValue = KeyboardScopeHelper.editorCommands.first.value;
      }
    } else if (_selectedAction == 'pair') {
      if (KeyboardScopeHelper.editorPairs.any((p) => p.value == currentVal)) {
        _selectedPresetValue = currentVal;
      } else {
        _selectedPresetValue = KeyboardScopeHelper.editorPairs.first.value;
      }
    } else if (_selectedAction == 'modifier') {
      if (KeyboardScopeHelper.terminalModifiers.any((m) => m.value == currentVal)) {
        _selectedPresetValue = currentVal;
      } else {
        _selectedPresetValue = KeyboardScopeHelper.terminalModifiers.first.value;
      }
    } else if (_selectedAction == 'terminal_key') {
      if (KeyboardScopeHelper.terminalKeys.any((k) => k.value == currentVal)) {
        _selectedPresetValue = currentVal;
      } else {
        _selectedPresetValue = KeyboardScopeHelper.terminalKeys.first.value;
      }
    } else {
      _selectedPresetValue = null;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _valueInputController.dispose();
    _cursorOffsetController.dispose();
    super.dispose();
  }

  void _onActionChanged(String? newAction) {
    if (newAction == null || newAction == _selectedAction) return;
    setState(() {
      _selectedAction = newAction;
      if (_selectedAction == 'pair') {
        _selectedPresetValue = KeyboardScopeHelper.editorPairs.first.value;
        if (_cursorOffsetController.text.isEmpty || _cursorOffsetController.text == '0') {
          _cursorOffsetController.text = '-1';
        }
        if (_labelController.text.isEmpty) {
          _labelController.text = _selectedPresetValue!;
        }
      } else if (_selectedAction == 'command') {
        _selectedPresetValue = KeyboardScopeHelper.editorCommands.first.value;
      } else if (_selectedAction == 'modifier') {
        _selectedPresetValue = KeyboardScopeHelper.terminalModifiers.first.value;
      } else if (_selectedAction == 'terminal_key') {
        _selectedPresetValue = KeyboardScopeHelper.terminalKeys.first.value;
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

    if (_selectedAction == 'input') {
      value = _valueInputController.text;
    } else {
      value = _selectedPresetValue ?? '';
    }

    if (_selectedAction == 'pair') {
      cursorOffset = int.tryParse(_cursorOffsetController.text.trim()) ?? -1;
    }

    final keyItem = KeyboardKeyItem(
      label: label.isNotEmpty ? label : value,
      icon: (_selectedIcon != null && _selectedIcon!.isNotEmpty) ? _selectedIcon : null,
      action: _selectedAction,
      value: value,
      cursorOffset: cursorOffset,
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
                              child: Text(iconKey, overflow: TextOverflow.ellipsis),
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
                      child: Text(actionOption.label, overflow: TextOverflow.ellipsis),
                    ),
                  ).toList(),
                  onChanged: _onActionChanged,
                ),
                const SizedBox(height: 14),

                // 动作值 Value 控件联动
                if (_selectedAction == 'input')
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
                  )
                else if (_selectedAction == 'pair')
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedPresetValue,
                    decoration: InputDecoration(
                      labelText: l10n.keyboardPairPresetFormField,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: KeyboardScopeHelper.editorPairs.map(
                      (pair) => DropdownMenuItem<String>(
                        value: pair.value,
                        child: Text('${pair.label} (${pair.value})', overflow: TextOverflow.ellipsis),
                      ),
                    ).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPresetValue = val;
                        if (_labelController.text.isEmpty && val != null) {
                          _labelController.text = val;
                        }
                      });
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
                        child: Text('${cmd.label} [${cmd.value}]', overflow: TextOverflow.ellipsis),
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
                    initialValue: _selectedPresetValue,
                    decoration: InputDecoration(
                      labelText: l10n.keyboardModifierPresetFormField,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: KeyboardScopeHelper.terminalModifiers.map(
                      (m) => DropdownMenuItem<String>(
                        value: m.value,
                        child: Text(m.label, overflow: TextOverflow.ellipsis),
                      ),
                    ).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPresetValue = val;
                      });
                    },
                  )
                else if (_selectedAction == 'terminal_key')
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedPresetValue,
                    decoration: InputDecoration(
                      labelText: l10n.keyboardTerminalKeyPresetFormField,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: KeyboardScopeHelper.terminalKeys.map(
                      (k) => DropdownMenuItem<String>(
                        value: k.value,
                        child: Text(k.label, overflow: TextOverflow.ellipsis),
                      ),
                    ).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPresetValue = val;
                      });
                    },
                  ),

                // 仅当 action == pair 时显示 cursorOffset
                if (_selectedAction == 'pair') ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cursorOffsetController,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    decoration: InputDecoration(
                      labelText: l10n.keyboardCursorOffsetFormField,
                      helperText: l10n.keyboardCursorOffsetHelper,
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
