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
import 'package:catchify/utilities/artwork_provider.dart';
import 'package:catchify/widgets/no_artwork_cube.dart';

class PlaylistArtwork extends StatelessWidget {
  const PlaylistArtwork({
    super.key,
    required this.playlistArtwork,
    this.playlistTitle,
    this.cubeIcon = FluentIcons.text_bullet_list_24_filled,
    this.iconSize,
    this.size = 220,
  });

  final String? playlistArtwork;
  final String? playlistTitle;
  final IconData cubeIcon;
  final double? iconSize;
  final double size;

  Widget _nullArtwork() => NullArtworkWidget(
    icon: cubeIcon,
    iconSize: iconSize ?? (size * 0.3), // Default to 30% of container size
    size: size,
    title: playlistTitle,
  );

  @override
  Widget build(BuildContext context) {
    final image = playlistArtwork;
    if (image == null) return _nullArtwork();

    try {
      final provider = ArtworkProvider.get(image);
      final isYouTubeLetterboxed =
          (image.contains('i.ytimg.com') || image.contains('img.youtube.com')) &&
          (image.contains('/vi/') ||
           image.contains('/hqdefault.') ||
           image.contains('/sddefault.') ||
           image.contains('/hq720.') ||
           image.contains('/mqdefault.') ||
           image.contains('/maxresdefault.'));

      Widget imageWidget = Image(
        image: provider,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _nullArtwork(),
      );

      if (isYouTubeLetterboxed) {
        // YouTube video thumbnails (16:9 widescreen or 4:3) contain top and bottom
        // letterbox bars (black spaces). Scaling by 1.36 inside ClipRect pushes
        // the top and bottom black bars outside the view bounds and clips them cleanly,
        // ensuring the real artwork fills edge-to-edge without top/bottom empty space.
        imageWidget = ClipRect(
          child: Transform.scale(
            scale: 1.36,
            child: imageWidget,
          ),
        );
      }

      return SizedBox(
        width: size,
        height: size,
        child: imageWidget,
      );
    } catch (_) {
      return _nullArtwork();
    }
  }
}
