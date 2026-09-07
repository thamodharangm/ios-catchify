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

  String get hexCode =>
      '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Harmonious curated palette with smooth chromatic flow
const List<AccentColorItem> curatedAccentColors = [
  // Purples & Violets
  AccentColorItem(name: 'Catchify Purple', color: Color(0xFF9948EF)),
  AccentColorItem(name: 'Electric Violet', color: Color(0xFF8A2BE2)),
  AccentColorItem(name: 'Deezer Violet', color: Color(0xFFA238FF)),
  AccentColorItem(name: 'Royal Velvet', color: Color(0xFF6A1B9A)),
  AccentColorItem(name: 'Midnight Indigo', color: Color(0xFF3949AB)),

  // Blues & Cyans
  AccentColorItem(name: 'Hyper Blue', color: Color(0xFF0066FF)),
  AccentColorItem(name: 'Deep Sapphire', color: Color(0xFF1565C0)),
  AccentColorItem(name: 'Tidal Cyan', color: Color(0xFF00E5FF)),
  AccentColorItem(name: 'Soft Sky', color: Color(0xFF81D4FA)),
  AccentColorItem(name: 'Aquamarine', color: Color(0xFF00E676)),

  // Greens & Limes
  AccentColorItem(name: 'Spotify Green', color: Color(0xFF1DB954)),
  AccentColorItem(name: 'Emerald Deep', color: Color(0xFF00796B)),
  AccentColorItem(name: 'Matcha Mint', color: Color(0xFF81C784)),
  AccentColorItem(name: 'Neon Lime', color: Color(0xFF39FF14)),
  AccentColorItem(name: 'Acid Lemon', color: Color(0xFFE4F422)),

  // Yellows & Oranges
  AccentColorItem(name: 'Caramel Gold', color: Color(0xFFFFB74D)),
  AccentColorItem(name: 'Solar Amber', color: Color(0xFFFF9100)),
  AccentColorItem(name: 'SoundCloud Orange', color: Color(0xFFFF5500)),
  AccentColorItem(name: 'Burnt Bronze', color: Color(0xFFD84315)),
  AccentColorItem(name: 'Peachy Warm', color: Color(0xFFFFAB91)),

  // Reds & Pinks
  AccentColorItem(name: 'YouTube Red', color: Color(0xFFFF0000)),
  AccentColorItem(name: 'Apple Red', color: Color(0xFFFC3C44)),
  AccentColorItem(name: 'Crimson Dark', color: Color(0xFFC62828)),
  AccentColorItem(name: 'Hot Coral', color: Color(0xFFFF5252)),
  AccentColorItem(name: 'Cyberpunk Pink', color: Color(0xFFFF007F)),

  // Soft / Minimalist
  AccentColorItem(name: 'Sakura Blossom', color: Color(0xFFF48FB1)),
  AccentColorItem(name: 'Lavender Cloud', color: Color(0xFFB39DDB)),
  AccentColorItem(name: 'Muted Slate', color: Color(0xFF90A4AE)),
  AccentColorItem(name: 'Light Steel', color: Color(0xFFAABBCC)),
];

/// Backwards compatibility for existing code references
final availableColors = curatedAccentColors.map((e) => e.color).toList();
