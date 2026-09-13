import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 颜色 → `#RRGGBB` 文本（用于工具提示与设置项副标题）
String colorToHex(Color color) {
  final argb = color.toARGB32();
  final rgb = argb & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// 通用交互式调色板弹窗：
///
/// 包含 HSV 2D 饱和度/明度调色区、色相滑条、HEX 十六进制编辑、
/// 当前/新色对比预览，以及经典预设色板。
class ColorPaletteDialog extends StatefulWidget {
  const ColorPaletteDialog({
    super.key,
    required this.title,
    required this.current,
    required this.palette,
  });

  final String title;
  final Color current;
  final List<Color> palette;

  /// 界面主题色板：Material 主色 + 中性色
  static const List<Color> uiPalette = [
    Color(0xFFF44336),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF673AB7),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF03A9F4),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFCDDC39),
    Color(0xFFFFEB3B),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFF9E9E9E),
    Color(0xFF000000),
  ];

  /// 终端背景色板：常用深色配色 + 少量浅色
  static const List<Color> terminalPalette = [
    Color(0xFF000000),
    Color(0xFF0D1117),
    Color(0xFF101418),
    Color(0xFF181818),
    Color(0xFF1E1E1E),
    Color(0xFF1E1E2E),
    Color(0xFF212121),
    Color(0xFF263238),
    Color(0xFF282C34),
    Color(0xFF2B2B2B),
    Color(0xFF2D2D30),
    Color(0xFF303030),
    Color(0xFF1B2B34),
    Color(0xFF002B36),
    Color(0xFF073642),
    Color(0xFF3C3836),
    Color(0xFFF5F5F5),
    Color(0xFFFFFFFF),
  ];

  static Future<Color?> show(
    BuildContext context, {
    required String title,
    required Color current,
    required List<Color> palette,
  }) {
    return showDialog<Color>(
      context: context,
      builder: (_) => ColorPaletteDialog(
        title: title,
        current: current,
        palette: palette,
      ),
    );
  }

  @override
  State<ColorPaletteDialog> createState() => _ColorPaletteDialogState();
}

class _ColorPaletteDialogState extends State<ColorPaletteDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late Color _currentColor;
  late TextEditingController _hexController;
  bool _isInternalHexUpdate = false;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.current;
    final hsv = HSVColor.fromColor(widget.current);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController = TextEditingController(text: colorToHex(widget.current));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateColor(Color color, {bool updateHex = true}) {
    final hsv = HSVColor.fromColor(color);
    setState(() {
      _currentColor = color;
      if (hsv.saturation > 0 || color.toARGB32() != Colors.black.toARGB32()) {
        _hue = hsv.hue;
      }
      _saturation = hsv.saturation;
      _value = hsv.value;
      if (updateHex) {
        _isInternalHexUpdate = true;
        _hexController.text = colorToHex(color);
        _isInternalHexUpdate = false;
      }
    });
  }

  void _onHexChanged(String text) {
    if (_isInternalHexUpdate) return;
    String clean = text.trim();
    if (clean.startsWith('#')) clean = clean.substring(1);
    if (clean.length == 6) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) {
        final color = Color(0xFF000000 | val);
        final hsv = HSVColor.fromColor(color);
        setState(() {
          _currentColor = color;
          if (hsv.saturation > 0 || color.toARGB32() != Colors.black.toARGB32()) {
            _hue = hsv.hue;
          }
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
      }
    }
  }

  void _onSvPan(Offset localPosition, double width, double height) {
    final s = (localPosition.dx / width).clamp(0.0, 1.0);
    final v = (1.0 - (localPosition.dy / height)).clamp(0.0, 1.0);
    setState(() {
      _saturation = s;
      _value = v;
      _currentColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
      _isInternalHexUpdate = true;
      _hexController.text = colorToHex(_currentColor);
      _isInternalHexUpdate = false;
    });
  }

  void _onHuePan(Offset localPosition, double width) {
    final h = (localPosition.dx / width * 360.0).clamp(0.0, 360.0);
    setState(() {
      _hue = h == 360.0 ? 0.0 : h;
      _currentColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
      _isInternalHexUpdate = true;
      _hexController.text = colorToHex(_currentColor);
      _isInternalHexUpdate = false;
    });
  }

  Widget _buildSaturationValuePicker(double width, double height) {
    return GestureDetector(
      onPanDown: (details) => _onSvPan(details.localPosition, width, height),
      onPanUpdate: (details) => _onSvPan(details.localPosition, width, height),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              // 色相底层
              Container(
                color: HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
              ),
              // 水平渐变（白色 -> 透明）
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.white, Color(0x00FFFFFF)],
                  ),
                ),
              ),
              // 垂直渐变（透明 -> 黑色）
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
              // 取色定位圆环指示器
              Positioned(
                left: (_saturation * width - 10).clamp(-10.0, width - 10.0),
                top: ((1.0 - _value) * height - 10).clamp(-10.0, height - 10.0),
                child: IgnorePointer(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHueSlider(double width) {
    const double sliderHeight = 22.0;
    return GestureDetector(
      onPanDown: (details) => _onHuePan(details.localPosition, width),
      onPanUpdate: (details) => _onHuePan(details.localPosition, width),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(sliderHeight / 2),
        child: SizedBox(
          width: width,
          height: sliderHeight,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(sliderHeight / 2),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: ((_hue / 360.0) * width - 10).clamp(-10.0, width - 10.0),
                top: 1,
                child: IgnorePointer(
                  child: Container(
                    width: 20,
                    height: sliderHeight - 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewAndHex(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // 初始颜色（点击可快速重置回原色）
        Tooltip(
          message: '${l10n.currentColor}: ${colorToHex(widget.current)}',
          child: InkWell(
            onTap: () => _updateColor(widget.current),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.current,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.arrow_forward, size: 18, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        // 调色后的实时新色预览
        Tooltip(
          message: '${l10n.newColor}: ${colorToHex(_currentColor)}',
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _currentColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _currentColor.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        // HEX 颜色输入框
        SizedBox(
          width: 120,
          height: 42,
          child: TextField(
            controller: _hexController,
            onChanged: _onHexChanged,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              labelText: l10n.hexColor,
              counterText: '',
            ),
            maxLength: 7,
          ),
        ),
      ],
    );
  }

  Widget _buildPresets(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final currentRgb = _currentColor.toARGB32() & 0xFFFFFF;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.presetColors,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final color in widget.palette)
              Tooltip(
                message: colorToHex(color),
                child: InkWell(
                  key: ValueKey<int>(color.toARGB32()),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _updateColor(color),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (color.toARGB32() & 0xFFFFFF) == currentRgb
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: (color.toARGB32() & 0xFFFFFF) == currentRgb ? 2.5 : 1,
                      ),
                    ),
                    child: (color.toARGB32() & 0xFFFFFF) == currentRgb
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: color.computeLuminance() > 0.5
                                ? Colors.black87
                                : Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSaturationValuePicker(280, 130),
              const SizedBox(height: 12),
              _buildHueSlider(280),
              const SizedBox(height: 12),
              _buildPreviewAndHex(context, l10n),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _buildPresets(context, l10n),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_currentColor),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
