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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart' show audioHandler;
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/async_loader.dart';
import 'package:catchify/widgets/lyrics_display_widget.dart';
import 'package:catchify/widgets/song_artwork.dart';

/// Displays the now-playing artwork (front) and synced lyrics (back) in a
/// flip card. Converted to StatefulWidget so the lyrics Future is cached
/// per-song (keyed on the ytid extracted from MediaItem.id). Previously this
/// was a StatelessWidget calling getSongLyrics() directly in build(), which
/// created a brand-new Future on every rebuild, causing FutureBuilder to
/// reset to loading state and breaking lyric sync.
class NowPlayingArtwork extends StatefulWidget {
  const NowPlayingArtwork({
    super.key,
    required this.size,
    required this.metadata,
    required this.lyricsController,
  });

  final Size size;
  final MediaItem metadata;
  final FlipCardController lyricsController;

  @override
  State<NowPlayingArtwork> createState() => _NowPlayingArtworkState();
}

class _NowPlayingArtworkState extends State<NowPlayingArtwork> {
  Future<String?>? _lyricsFuture;
  String? _cachedSongKey;
  bool _fetchedWithDuration = false;

  /// Returns a stable key that uniquely identifies the current track.
  /// Prefers the ytid stored in MediaItem.id; falls back to "artist - title".
  String _songKey(MediaItem metadata) {
    final id = metadata.id;
    // MediaItem.id is usually the ytid (11-char YouTube video ID).
    // Use artist+title as a secondary key so we still invalidate correctly
    // when the id is reused across different tracks (very rare).
    return id.isNotEmpty ? id : '${metadata.artist ?? ""} - ${metadata.title}';
  }

  void _fetchLyricsIfNeeded(MediaItem metadata) {
    final key = _songKey(metadata);
    final dur = metadata.duration?.inSeconds;
    final hasDuration = dur != null && dur > 0;

    // Fetch if song key changed, or if previous fetch had no duration and now duration is known
    if (key != _cachedSongKey || (!_fetchedWithDuration && hasDuration)) {
      _cachedSongKey = key;
      _fetchedWithDuration = hasDuration;
      _lyricsFuture = getSongLyrics(
        metadata.artist,
        metadata.title,
        duration: dur,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLyricsIfNeeded(widget.metadata);
  }

  @override
  void didUpdateWidget(NowPlayingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchLyricsIfNeeded(widget.metadata);
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = 24.0;
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = widget.size.width;
    final screenHeight = widget.size.height;
    final isLandscape = screenWidth > screenHeight;
    final isDesktop = screenWidth > 800;
    final imageSize = isDesktop
        ? screenHeight * 0.38
        : isLandscape
            ? screenHeight * 0.45
            : screenWidth < 360
                ? screenWidth * 0.75
                : screenWidth < 600
                    ? screenWidth * 0.80
                    : screenWidth * 0.65;

    return FlipCard(
      rotateSide: RotateSide.right,
      onTapFlipping: !offlineMode.value,
      controller: widget.lyricsController,
      animationDuration: const Duration(milliseconds: 300),
      frontWidget: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SongArtworkWidget(
            metadata: widget.metadata,
            size: imageSize,
            errorWidgetIconSize: widget.size.width / 8,
            borderRadius: borderRadius,
          ),
        ),
      ),
      backWidget: Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: AsyncLoader<String?>(
            // Use the cached future — never re-created on rebuild, only on
            // actual song change. This is the core fix for the sync bug.
            future: _lyricsFuture!,
            emptyWidget: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.text_quote_24_regular,
                    size: 48,
                    color: colorScheme.onSecondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n!.lyricsNotAvailable,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            errorBuilder: (ctx, error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.text_quote_24_regular,
                    size: 48,
                    color: colorScheme.onSecondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n!.lyricsNotAvailable,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            builder: (context, lyrics) {
              if (lyrics == null || lyrics.isEmpty) {
                return Center(
                  child: Text(
                    context.l10n!.lyricsNotAvailable,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                );
              }
              final songId = widget.metadata.extras?['ytid']?.toString() ??
                  (widget.metadata.id.isNotEmpty ? widget.metadata.id : null);
              return LyricsDisplayWidget(
                lyrics: lyrics,
                positionDataStream: audioHandler.positionDataStream,
                songId: songId,
              );
            },
          ),
        ),
      ),
    );
  }
}
