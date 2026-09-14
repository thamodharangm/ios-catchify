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
import 'package:catchify/utilities/artwork_provider.dart';

class PlaylistCollage extends StatelessWidget {
  const PlaylistCollage({
    super.key,
    required this.imageUrls,
    required this.size,
    required this.fallback,
  });

  final List<String> imageUrls;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final validUrls = imageUrls.where((url) => url.isNotEmpty).take(4).toList();

    if (validUrls.isEmpty) {
      return fallback;
    }

    if (validUrls.length < 4) {
      // 1 to 3 songs: display first song artwork full size
      return _buildImage(validUrls.first, size, size);
    }

    // Exactly 4 artworks in a clean 2x2 grid (Youtify collage concept)
    final halfSize = size / 2;
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Row(
            children: [
              _buildImage(validUrls[0], halfSize, halfSize),
              _buildImage(validUrls[1], halfSize, halfSize),
            ],
          ),
          Row(
            children: [
              _buildImage(validUrls[2], halfSize, halfSize),
              _buildImage(validUrls[3], halfSize, halfSize),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String url, double width, double height) {
    try {
      final isYouTubeLetterboxed =
          (url.contains('i.ytimg.com') || url.contains('img.youtube.com')) &&
          (url.contains('/hqdefault.') ||
              url.contains('/sddefault.') ||
              url.contains('/default.'));

      Widget img = Image(
        image: ArtworkProvider.get(url),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.black26,
          child: const Icon(Icons.music_note, color: Colors.white38, size: 16),
        ),
      );

      if (isYouTubeLetterboxed) {
        img = ClipRect(
          child: Transform.scale(
            scale: 1.34,
            child: img,
          ),
        );
      }

      return SizedBox(
        width: width,
        height: height,
        child: img,
      );
    } catch (_) {
      return Container(
        width: width,
        height: height,
        color: Colors.black26,
      );
    }
  }
}
