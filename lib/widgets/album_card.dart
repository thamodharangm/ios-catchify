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
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:catchify/widgets/playlist_cube.dart';

class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.size = 140.0,
  });

  final Map album;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fullTitle = album['title']?.toString() ?? '';

    final isSingle = album['isSingle'] == true;
    var displayTitle = fullTitle;
    var subtitle = '';

    if (fullTitle.contains(' - ')) {
      final parts = fullTitle.split(' - ');
      displayTitle = parts[0].replaceAll('(Single)', '').trim();
      final artistPart = parts.sublist(1).join(' - ').trim();
      subtitle = isSingle ? '$artistPart • Single' : artistPart;
    } else {
      subtitle = isSingle ? 'Single' : 'Album';
    }

    return SizedBox(
      width: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PlaylistCube(
              album,
              size: size,
              borderRadius: 14,
              cubeIcon: FluentIcons.album_24_filled,
            ),
            const SizedBox(height: 8),
            Text(
              displayTitle,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
