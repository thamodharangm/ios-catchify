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

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:catchify/widgets/no_artwork_cube.dart';
import 'package:catchify/widgets/spinner.dart';

class SongArtworkWidget extends StatelessWidget {
  const SongArtworkWidget({
    super.key,
    required this.size,
    required this.metadata,
    this.borderRadius = 10.0,
    this.errorWidgetIconSize = 20.0,
  });
  final double size;
  final MediaItem metadata;
  final double borderRadius;
  final double errorWidgetIconSize;

  @override
  Widget build(BuildContext context) {
    if (metadata.artUri?.scheme == 'file') {
      String? localFilePath;
      try {
        localFilePath = metadata.artUri?.toFilePath();
      } catch (_) {}

      if (localFilePath != null &&
          File(localFilePath).existsSync() &&
          File(localFilePath).lengthSync() > 0) {
        return SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              File(localFilePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackNetworkImage(),
            ),
          ),
        );
      }

      final extraArtwork = metadata.extras?['artworkPath']?.toString() ??
          metadata.extras?['artWorkPath']?.toString();
      if (extraArtwork != null &&
          !extraArtwork.startsWith('http') &&
          File(extraArtwork).existsSync() &&
          File(extraArtwork).lengthSync() > 0) {
        return SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              File(extraArtwork),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackNetworkImage(),
            ),
          ),
        );
      }

      return _buildFallbackNetworkImage();
    }

    final imageUrl = metadata.artUri?.toString() ?? '';
    if (imageUrl.isEmpty || imageUrl.startsWith('file://')) {
      return _buildFallbackNetworkImage();
    }

    final isLetterboxed =
        (imageUrl.contains('i.ytimg.com') || imageUrl.contains('img.youtube.com')) &&
        (imageUrl.contains('/hqdefault.') || imageUrl.contains('/sddefault.'));

    return CachedNetworkImage(
      width: size,
      height: size,
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) {
        Widget imageWidget = Image(image: imageProvider, fit: BoxFit.cover);
        if (isLetterboxed) {
          imageWidget = ClipRect(
            child: Transform.scale(
              scale: 1.34,
              child: imageWidget,
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: imageWidget,
        );
      },
      placeholder: (context, url) => const Spinner(),
      errorWidget: (context, url, error) => _buildFallbackNetworkImage(),
    );
  }

  Widget _buildFallbackNetworkImage() {
    final remoteUrl = metadata.extras?['highResImage']?.toString() ??
        metadata.extras?['lowResImage']?.toString() ??
        '';
    if (remoteUrl.isNotEmpty && remoteUrl.startsWith('http')) {
      final isRemoteLetterboxed =
          (remoteUrl.contains('i.ytimg.com') || remoteUrl.contains('img.youtube.com')) &&
          (remoteUrl.contains('/hqdefault.') || remoteUrl.contains('/sddefault.'));

      return CachedNetworkImage(
        width: size,
        height: size,
        imageUrl: remoteUrl,
        imageBuilder: (context, imageProvider) {
          Widget imageWidget = Image(image: imageProvider, fit: BoxFit.cover);
          if (isRemoteLetterboxed) {
            imageWidget = ClipRect(
              child: Transform.scale(
                scale: 1.34,
                child: imageWidget,
              ),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: imageWidget,
          );
        },
        placeholder: (context, url) => const Spinner(),
        errorWidget: (context, url, error) =>
            NullArtworkWidget(iconSize: errorWidgetIconSize),
      );
    }
    return NullArtworkWidget(iconSize: errorWidgetIconSize);
  }
}
