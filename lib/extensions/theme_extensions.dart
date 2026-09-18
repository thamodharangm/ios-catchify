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
 */

import 'package:flutter/material.dart';
import 'package:catchify/services/settings_manager.dart';

/// Semantic extensions on [BuildContext] for ergonomic and consistent theme access.
extension ThemeContextExtension on BuildContext {
  /// The active [ThemeData] in the widget tree.
  ThemeData get theme => Theme.of(this);

  /// The active [ColorScheme] for surfaces, accents, and semantic roles.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// The active Catchify-aligned [TextTheme].
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Whether the active theme is currently dark.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Whether the active theme is pure black (OLED mode).
  bool get isPureBlack => isDarkMode && usePureBlackColor.value;
}
