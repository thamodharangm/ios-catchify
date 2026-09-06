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
          (image.contains('/hqdefault.') || image.contains('/sddefault.'));

      Widget imageWidget = Image(
        image: provider,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _nullArtwork(),
      );

      if (isYouTubeLetterboxed) {
        // YouTube hqdefault (480x360) and sddefault (640x480) add 12.5% black bars
        // at the top and bottom because 16:9 video content is centered in a 4:3 frame.
        // Scaling by 1.34 (4/3) pushes the black bars outside the view bounds,
        // and ClipRect clips them cleanly so the real artwork fills edge-to-edge.
        imageWidget = ClipRect(
          child: Transform.scale(
            scale: 1.34,
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
