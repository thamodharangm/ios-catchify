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

import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/main.dart';
import 'package:catchify/models/home_section.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/widgets/album_card.dart';
import 'package:catchify/widgets/artist_card.dart';
import 'package:catchify/widgets/playlist_cube.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/song_bar.dart';
import 'package:catchify/widgets/song_card.dart';

class HomeSectionRenderer extends StatelessWidget {
  const HomeSectionRenderer({
    super.key,
    required this.section,
    this.playlistHeight,
  });

  final HomeSection section;
  final double? playlistHeight;

  IconData _resolveIcon(String title, HomeContentType type) {
    final lower = title.toLowerCase();
    if (lower.contains('quick')) return FluentIcons.flash_24_filled;
    if (lower.contains('trending')) return FluentIcons.arrow_trending_lines_24_filled;
    if (lower.contains('recommended') || lower.contains('for you') || lower.contains('mixed')) {
      return FluentIcons.sparkle_24_filled;
    }
    if (lower.contains('favorite')) return FluentIcons.heart_24_filled;
    if (lower.contains('artist')) return FluentIcons.person_star_24_filled;
    if (lower.contains('album') || lower.contains('single')) return FluentIcons.album_24_filled;
    if (lower.contains('community') || lower.contains('globe')) return FluentIcons.globe_24_filled;
    if (lower.contains('new')) return FluentIcons.sparkle_24_filled;

    switch (type) {
      case HomeContentType.songs:
        return FluentIcons.music_note_2_24_filled;
      case HomeContentType.albums:
        return FluentIcons.album_24_filled;
      case HomeContentType.artists:
        return FluentIcons.person_star_24_filled;
      case HomeContentType.playlists:
        return FluentIcons.list_24_filled;
      case HomeContentType.mixed:
      case HomeContentType.unknown:
        return FluentIcons.apps_24_filled;
    }
  }

  void _openPlaylist(BuildContext context, Map playlist) {
    final playlistId =
        playlist['ytid']?.toString() ?? playlist['id']?.toString();
    if (playlistId == null || playlistId.isEmpty || playlistId == 'null') {
      return;
    }
    if (isArtistPlaylist(playlist)) {
      context.push(
        '/home/artist/${Uri.encodeComponent(playlistId)}',
        extra: playlist,
      );
      return;
    }
    context.push(
      '/home/playlist/${Uri.encodeComponent(playlistId)}',
      extra: playlist,
    );
  }

  void _openArtist(BuildContext context, Map<String, dynamic> artist) {
    final artistId =
        artist['ytid']?.toString() ?? artist['title']?.toString() ?? '';
    if (artistId.isEmpty) return;
    context.push(
      '/home/artist/${Uri.encodeComponent(artistId)}',
      extra: artist,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final effectivePlaylistHeight =
        playlistHeight ?? (MediaQuery.sizeOf(context).height * 0.25 / 1.1);
    final icon = _resolveIcon(section.title, section.type);

    final showPlayAll =
        section.type == HomeContentType.songs && section.contents.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: section.title,
          icon: icon,
          actionButton: showPlayAll
              ? IconButton(
                  onPressed: () async {
                    await audioHandler.playPlaylistSong(
                      playlist: {
                        'title': section.title,
                        'list': section.contents,
                      },
                      songIndex: 0,
                    );
                  },
                  icon: Icon(
                    FluentIcons.play_circle_24_filled,
                    color: Theme.of(context).colorScheme.primary,
                    size: 30,
                  ),
                )
              : null,
        ),
        if (section.isChunkedSongs)
          _buildChunkedSongs(context, screenWidth)
        else
          switch (section.type) {
            HomeContentType.songs => _buildSongCards(context),
            HomeContentType.albums => _buildAlbumCards(context),
            HomeContentType.artists => _buildArtistCards(context),
            HomeContentType.playlists =>
              _buildPlaylistCubes(context, effectivePlaylistHeight),
            HomeContentType.mixed ||
            HomeContentType.unknown =>
              _buildMixedCards(context, effectivePlaylistHeight),
          },
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildChunkedSongs(BuildContext context, double screenWidth) {
    final columnWidth = (screenWidth > 600) ? 380.0 : screenWidth * 0.88;
    final chunkedSongs = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < section.contents.length; i += 4) {
      chunkedSongs.add(
        section.contents.sublist(i, math.min(i + 4, section.contents.length)),
      );
    }

    return SizedBox(
      height: chunkedSongs
              .map((c) => c.length)
              .fold<int>(0, math.max) *
          66.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chunkedSongs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, colIndex) {
          final chunk = chunkedSongs[colIndex];
          return SizedBox(
            width: columnWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(chunk.length, (rowIndex) {
                final song = chunk[rowIndex];
                final globalIndex = colIndex * 4 + rowIndex;
                final ytid = song['ytid'];
                return RepaintBoundary(
                  key: listItemKey('home_dyn_chunk', globalIndex, song),
                  child: SongBar(
                    song,
                    true,
                    key: ValueKey(ytid ?? globalIndex),
                    backgroundColor: Colors.transparent,
                    barPadding: const EdgeInsetsDirectional.symmetric(
                      vertical: 7,
                      horizontal: 4,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    onPlay: () async {
                      await audioHandler.playPlaylistSong(
                        playlist: {
                          'title': section.title,
                          'list': section.contents,
                        },
                        songIndex: globalIndex,
                      );
                    },
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongCards(BuildContext context) {
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: section.contents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = section.contents[index];
          final rank = song['chartRank'] as int?;
          return RepaintBoundary(
            key: listItemKey('home_dyn_song', index, song),
            child: SongCard(
              song: song,
              rank: rank,
              onTap: () async {
                await audioHandler.playPlaylistSong(
                  playlist: {
                    'title': section.title,
                    'list': section.contents,
                  },
                  songIndex: index,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbumCards(BuildContext context) {
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: section.contents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final album = section.contents[index];
          return RepaintBoundary(
            key: listItemKey('home_dyn_album', index, album),
            child: AlbumCard(
              album: album,
              onTap: () => _openPlaylist(context, album),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistCards(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: section.contents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final artist = section.contents[index];
          return RepaintBoundary(
            key: listItemKey('home_dyn_artist', index, artist),
            child: ArtistCard(artist: artist),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistCubes(BuildContext context, double height) {
    final items = section.contents;
    final itemsNumber = items.length.clamp(0, recommendedCubesNumber);
    final isLargeScreen = MediaQuery.sizeOf(context).width > 480;
    final useCarousel =
        !isLargeScreen && itemsNumber >= 3 && items.length >= 3;

    return SizedBox(
      height: height,
      child: useCarousel
          ? CarouselView.weighted(
              flexWeights: const <int>[3, 2, 1],
              itemSnapping: true,
              onTap: (index) {
                if (index >= 0 && index < items.length) {
                  _openPlaylist(context, items[index]);
                }
              },
              children: List.generate(itemsNumber, (index) {
                final item = items[index];
                return RepaintBoundary(
                  key: listItemKey('home_dyn_pl_carousel', index, item),
                  child: PlaylistCube(item, size: height),
                );
              }),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: itemsNumber,
              itemBuilder: (context, index) {
                final item = items[index];
                return RepaintBoundary(
                  key: listItemKey('home_dyn_pl_item', index, item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openPlaylist(context, item),
                      child: PlaylistCube(item, size: height),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMixedCards(BuildContext context, double height) {
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: section.contents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = section.contents[index];
          final contentType = item['contentType'] as String? ?? '';

          if (contentType == 'artist' || item['isArtist'] == true) {
            return RepaintBoundary(
              key: listItemKey('home_dyn_mix_art', index, item),
              child: Center(child: ArtistCard(artist: item)),
            );
          } else if (contentType == 'album' || item['isAlbum'] == true) {
            return RepaintBoundary(
              key: listItemKey('home_dyn_mix_alb', index, item),
              child: AlbumCard(
                album: item,
                onTap: () => _openPlaylist(context, item),
              ),
            );
          } else if (contentType == 'playlist' ||
              item['source'] == 'youtube-music-playlist') {
            return RepaintBoundary(
              key: listItemKey('home_dyn_mix_pl', index, item),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openPlaylist(context, item),
                child: PlaylistCube(item, size: 140),
              ),
            );
          } else {
            return RepaintBoundary(
              key: listItemKey('home_dyn_mix_sng', index, item),
              child: SongCard(
                song: item,
                onTap: () async {
                  await audioHandler.playPlaylistSong(
                    playlist: {
                      'title': section.title,
                      'list': section.contents,
                    },
                    songIndex: index,
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }
}
