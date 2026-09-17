/*
 *     Copyright (C) 2026 Thamodharan Ganesan
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
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/thamodharangm/catchify
 */

import 'package:flutter/material.dart';

/// Centralized Catchify Design System Tokens.
/// Defines consistent spacing, radii, dimensions, and typography metrics.
abstract final class AppTokens {
  // ── Spacing ──
  static const double pagePadding = 16.0;
  static const double cardGap = 12.0;
  static const double sectionGap = 28.0;
  static const double chipGap = 8.0;
  static const double titleBottomGap = 10.0;
  static const double rowGap = 8.0;
  static const double itemSpacing = 12.0;

  // ── Radii ──
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusCard = 14.0;
  static const double radiusLarge = 16.0;
  static const double radiusSheet = 24.0;
  static const double radiusPill = 999.0;

  static final BorderRadius borderRadiusSmall = BorderRadius.circular(radiusSmall);
  static final BorderRadius borderRadiusMedium = BorderRadius.circular(radiusMedium);
  static final BorderRadius borderRadiusCard = BorderRadius.circular(radiusCard);
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(radiusLarge);
  static final BorderRadius borderRadiusSheet = BorderRadius.circular(radiusSheet);
  static final BorderRadius borderRadiusPill = BorderRadius.circular(radiusPill);

  // ── Card Dimensions ──
  static const double songCardSize = 140.0;
  static const double albumCardSize = 140.0;
  static const double playlistCardSize = 150.0;
  static const double artistAvatarSize = 88.0;
  static const double artistCardWidth = 104.0;
  static const double songRowArtworkSize = 52.0;
  static const double miniPlayerHeight = 68.0;
  static const double miniPlayerArtworkSize = 48.0;

  // ── Edge Insets ──
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: pagePadding);
  static const EdgeInsets shelfPadding = EdgeInsets.symmetric(horizontal: pagePadding);
  static const EdgeInsets chipListPadding = EdgeInsets.symmetric(horizontal: pagePadding);
  static const EdgeInsets headerPadding = EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, titleBottomGap);
}
