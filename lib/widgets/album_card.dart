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
 *
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/thamodharangm/catchify
 */

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:catchify/widgets/playlist_cube.dart';

class AlbumCard extends StatefulWidget {
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
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fullTitle = widget.album['title']?.toString() ?? '';

    final isSingle = widget.album['isSingle'] == true;
    final rawArtist = widget.album['artist']?.toString().trim() ?? '';
    final rawYear = widget.album['year']?.toString().trim() ?? '';

    var displayTitle = fullTitle;
    var subtitle = '';

    if (fullTitle.contains(' - ')) {
      final parts = fullTitle.split(' - ');
      displayTitle = parts[0].replaceAll('(Single)', '').trim();
      final artistPart = parts.sublist(1).join(' - ').trim();
      subtitle = isSingle ? '$artistPart • Single' : artistPart;
    } else {
      displayTitle = fullTitle;
      if (rawArtist.isNotEmpty) {
        if (rawYear.isNotEmpty) {
          subtitle = '$rawArtist • $rawYear';
        } else {
          subtitle = isSingle ? '$rawArtist • Single' : '$rawArtist • Album';
        }
      } else {
        subtitle = isSingle ? 'Single' : 'Album';
      }
    }

    return SizedBox(
      width: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: _pressed ? 0.94 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Artwork with soft shadow
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PlaylistCube(
                  widget.album,
                  size: widget.size,
                  borderRadius: 16,
                  cubeIcon: FluentIcons.album_24_filled,
                ),
              ),
              const SizedBox(height: 8),
              // Album/Song title — full opacity, w600
              Text(
                displayTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              // Subtitle — 80% opacity secondary hierarchy
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.80),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

