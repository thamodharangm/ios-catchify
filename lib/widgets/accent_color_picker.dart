/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Catchify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Catchify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/thamodharangm/catchify
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/theme/app_colors.dart';

class AccentColorPickerSheet extends StatefulWidget {
  const AccentColorPickerSheet({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
  });

  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  @override
  State<AccentColorPickerSheet> createState() => _AccentColorPickerSheetState();
}

class _AccentColorPickerSheetState extends State<AccentColorPickerSheet> {
  late Color _previewColor;
  late String _selectedCategory;
  late TextEditingController _hexController;
  late double _hue;
  late double _saturation;
  late double _value;

  static const _categories = [
    'Brands',
    'Neon',
    'Pastel',
    'AMOLED',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _previewColor = widget.initialColor;

    // Find if initialColor belongs to a category
    final matchingItem = curatedAccentColors.cast<AccentColorItem?>().firstWhere(
      (item) => item?.color.toARGB32() == widget.initialColor.toARGB32(),
      orElse: () => null,
    );
    _selectedCategory = matchingItem?.category ?? 'Brands';

    final hsv = HSVColor.fromColor(_previewColor);
    _hue = hsv.hue;
    _saturation = (hsv.saturation > 0.1) ? hsv.saturation : 0.85;
    _value = (hsv.value > 0.1) ? hsv.value : 0.95;

    _hexController = TextEditingController(text: _formatHex(_previewColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _formatHex(Color color) {
    return (color.toARGB32() & 0x00FFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
  }

  void _onColorPicked(Color color) {
    setState(() {
      _previewColor = color;
      final hsv = HSVColor.fromColor(color);
      _hue = hsv.hue;
      _saturation = (hsv.saturation > 0.1) ? hsv.saturation : 0.85;
      _value = (hsv.value > 0.1) ? hsv.value : 0.95;
      _hexController.text = _formatHex(color);
    });
  }

  void _onHueChanged(double newHue) {
    setState(() {
      _hue = newHue;
      _previewColor = HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();
      _hexController.text = _formatHex(_previewColor);
    });
  }

  void _onHexSubmitted(String val) {
    final clean = val.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final parsed = int.tryParse('FF$clean', radix: 16);
      if (parsed != null) {
        final newColor = Color(parsed);
        setState(() {
          _previewColor = newColor;
          final hsv = HSVColor.fromColor(newColor);
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onAccentColor = _previewColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    FluentIcons.color_24_filled,
                    color: _previewColor,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Accent Color',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _previewColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _previewColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '#${_formatHex(_previewColor)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _previewColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ─── Live Theme Preview Card ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _previewColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _previewColor,
                            _previewColor.withValues(alpha: 0.65),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        FluentIcons.music_note_2_24_filled,
                        color: onAccentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Preview',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Music Player & UI Highlight',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _previewColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _previewColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        FluentIcons.play_20_filled,
                        color: onAccentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      FluentIcons.heart_20_filled,
                      color: _previewColor,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: 0.55,
                    minHeight: 5,
                    backgroundColor: _previewColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(_previewColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Category Filter Chips ────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      cat == 'Brands'
                          ? 'Music Brands'
                          : cat == 'AMOLED'
                              ? 'AMOLED Dark'
                              : cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.white : colorScheme.onSurface)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: _previewColor.withValues(alpha: 0.22),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    side: BorderSide(
                      color: isSelected
                          ? _previewColor
                          : Colors.transparent,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Category Palette or Custom Input ──────────────────────────────
          if (_selectedCategory != 'Custom') ...[
            Builder(
              builder: (context) {
                final items = curatedAccentColors
                    .where((item) => item.category == _selectedCategory)
                    .toList();

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected =
                        item.color.toARGB32() == _previewColor.toARGB32();

                    return GestureDetector(
                      onTap: () => _onColorPicked(item.color),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.onSurface
                                    : Colors.white.withValues(alpha: 0.2),
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: item.color.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(
                                    FluentIcons.checkmark_20_filled,
                                    color: item.color.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white,
                                    size: 22,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ] else ...[
            // ─── Custom HEX & Sliders ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom HEX Code',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hexController,
                          maxLength: 6,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            counterText: '',
                            prefixText: '# ',
                            prefixStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _previewColor,
                              fontSize: 15,
                            ),
                            hintText: '9948EF',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onChanged: _onHexSubmitted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _previewColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Color Tone Slider',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
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
                  Slider(
                    value: _hue,
                    max: 360,
                    activeColor: _previewColor,
                    inactiveColor: colorScheme.surfaceContainerHighest,
                    onChanged: _onHueChanged,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // ─── Apply Button ──────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: () => widget.onColorSelected(_previewColor),
            icon: Icon(
              FluentIcons.checkmark_24_filled,
              color: onAccentColor,
              size: 20,
            ),
            label: Text(
              'Apply Accent Color',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: onAccentColor,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _previewColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
