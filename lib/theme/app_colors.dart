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

import 'package:flutter/material.dart';

class AccentColorItem {
  const AccentColorItem({
    required this.name,
    required this.color,
  });

  final String name;
  final Color color;
}

/// Exactly 12 curated premier music accent colors
const List<AccentColorItem> curatedAccentColors = [
  AccentColorItem(name: 'Catchify Purple', color: Color(0xFF9948EF)),
  AccentColorItem(name: 'Electric Violet', color: Color(0xFF8A2BE2)),
  AccentColorItem(name: 'Hyper Blue', color: Color(0xFF0066FF)),
  AccentColorItem(name: 'Tidal Cyan', color: Color(0xFF00E5FF)),
  AccentColorItem(name: 'Spotify Green', color: Color(0xFF1DB954)),
  AccentColorItem(name: 'Neon Lime', color: Color(0xFF39FF14)),
  AccentColorItem(name: 'Solar Amber', color: Color(0xFFFF9100)),
  AccentColorItem(name: 'SoundCloud Orange', color: Color(0xFFFF5500)),
  AccentColorItem(name: 'YouTube Red', color: Color(0xFFFF0000)),
  AccentColorItem(name: 'Apple Red', color: Color(0xFFFC3C44)),
  AccentColorItem(name: 'Cyberpunk Pink', color: Color(0xFFFF007F)),
  AccentColorItem(name: 'Sakura Pink', color: Color(0xFFF48FB1)),
];

/// Backwards compatibility for existing code references
final availableColors = curatedAccentColors.map((e) => e.color).toList();
