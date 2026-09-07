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
    required this.category,
  });

  final String name;
  final Color color;
  final String category;

  String get hexCode =>
      '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

const List<AccentColorItem> curatedAccentColors = [
  // Music Brands
  AccentColorItem(
    name: 'Catchify Purple',
    color: Color(0xFF9948EF),
    category: 'Brands',
  ),
  AccentColorItem(
    name: 'Spotify Green',
    color: Color(0xFF1DB954),
    category: 'Brands',
  ),
  AccentColorItem(
    name: 'Apple Red',
    color: Color(0xFFFC3C44),
    category: 'Brands',
  ),
  AccentColorItem(
    name: 'YouTube Red',
    color: Color(0xFFFF0000),
    category: 'Brands',
  ),
  AccentColorItem(
    name: 'Tidal Cyan',
    color: Color(0xFF00E5FF),
    category: 'Brands',
  ),
  AccentColorItem(
    name: 'SoundCloud',
    color: Color(0xFFFF5500),
    category: 'Brands',
  ),
  AccentColorItem(
    name: 'Deezer Violet',
    color: Color(0xFFA238FF),
    category: 'Brands',
  ),

  // Vibrant & Neon
  AccentColorItem(
    name: 'Electric Violet',
    color: Color(0xFF8A2BE2),
    category: 'Neon',
  ),
  AccentColorItem(
    name: 'Cyberpunk Pink',
    color: Color(0xFFFF007F),
    category: 'Neon',
  ),
  AccentColorItem(
    name: 'Neon Lime',
    color: Color(0xFF39FF14),
    category: 'Neon',
  ),
  AccentColorItem(
    name: 'Solar Amber',
    color: Color(0xFFFF9100),
    category: 'Neon',
  ),
  AccentColorItem(
    name: 'Hyper Blue',
    color: Color(0xFF0066FF),
    category: 'Neon',
  ),
  AccentColorItem(
    name: 'Acid Lemon',
    color: Color(0xFFE4F422),
    category: 'Neon',
  ),
  AccentColorItem(
    name: 'Hot Coral',
    color: Color(0xFFFF5252),
    category: 'Neon',
  ),
  AccentColorItem(
    name: 'Aquamarine',
    color: Color(0xFF00E676),
    category: 'Neon',
  ),

  // Pastel & Soft
  AccentColorItem(
    name: 'Sakura Blossom',
    color: Color(0xFFF48FB1),
    category: 'Pastel',
  ),
  AccentColorItem(
    name: 'Matcha Mint',
    color: Color(0xFF81C784),
    category: 'Pastel',
  ),
  AccentColorItem(
    name: 'Lavender Cloud',
    color: Color(0xFFB39DDB),
    category: 'Pastel',
  ),
  AccentColorItem(
    name: 'Caramel Gold',
    color: Color(0xFFFFB74D),
    category: 'Pastel',
  ),
  AccentColorItem(
    name: 'Soft Sky',
    color: Color(0xFF81D4FA),
    category: 'Pastel',
  ),
  AccentColorItem(
    name: 'Peachy Warm',
    color: Color(0xFFFFAB91),
    category: 'Pastel',
  ),
  AccentColorItem(
    name: 'Muted Slate',
    color: Color(0xFF90A4AE),
    category: 'Pastel',
  ),

  // Deep AMOLED
  AccentColorItem(
    name: 'Midnight Indigo',
    color: Color(0xFF3949AB),
    category: 'AMOLED',
  ),
  AccentColorItem(
    name: 'Royal Velvet',
    color: Color(0xFF6A1B9A),
    category: 'AMOLED',
  ),
  AccentColorItem(
    name: 'Emerald Deep',
    color: Color(0xFF00796B),
    category: 'AMOLED',
  ),
  AccentColorItem(
    name: 'Crimson Dark',
    color: Color(0xFFC62828),
    category: 'AMOLED',
  ),
  AccentColorItem(
    name: 'Burnt Bronze',
    color: Color(0xFFD84315),
    category: 'AMOLED',
  ),
  AccentColorItem(
    name: 'Deep Sapphire',
    color: Color(0xFF1565C0),
    category: 'AMOLED',
  ),
];

/// Backwards compatibility for existing code references
final availableColors = curatedAccentColors.map((e) => e.color).toList();
