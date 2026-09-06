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

import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/listening_stats_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/async_loader.dart';
import 'package:catchify/utilities/listening_stats_utils.dart';
import 'package:catchify/widgets/album_card.dart';
import 'package:catchify/widgets/announcement_box.dart';
import 'package:catchify/widgets/artist_card.dart';
import 'package:catchify/widgets/listening_recap_card.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/playlist_cube.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/song_bar.dart';
import 'package:catchify/widgets/song_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List> _suggestedPlaylistsFuture;
  late Future<List> _recommendedSongsFuture;
  late Future<List<Map<String, dynamic>>> _newReleasesFuture;
  late Future<List<Map<String, dynamic>>> _suggestedArtistsFuture;
  late Future<List<Map<String, dynamic>>> _albumsAndSinglesFuture;

  @override
  void initState() {
    super.initState();
    _suggestedPlaylistsFuture = getPlaylists(
      playlistsNum: recommendedCubesNumber,
    );
    _recommendedSongsFuture = getRecommendedSongs();
    _newReleasesFuture = getSuggestedNewReleases();
    _suggestedArtistsFuture = getSuggestedArtists();
    _albumsAndSinglesFuture = getSuggestedAlbumsAndSingles();
    externalRecommendations.addListener(_refreshRecommendedSongs);
  }

  @override
  void dispose() {
    externalRecommendations.removeListener(_refreshRecommendedSongs);
    super.dispose();
  }

  void _refreshRecommendedSongs() {
    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = getRecommendedSongs();
      _newReleasesFuture = getSuggestedNewReleases();
      _suggestedArtistsFuture = getSuggestedArtists();
      _albumsAndSinglesFuture = getSuggestedAlbumsAndSingles();
    });
  }

  Future<void> _onRefresh() async {
    setState(() {
      _suggestedPlaylistsFuture = getPlaylists(
        playlistsNum: recommendedCubesNumber,
      );
      _recommendedSongsFuture = getRecommendedSongs();
      _newReleasesFuture = getSuggestedNewReleases(forceRefresh: true);
      _suggestedArtistsFuture = getSuggestedArtists();
      _albumsAndSinglesFuture = getSuggestedAlbumsAndSingles();
    });
    try {
      await Future.wait([
        _suggestedPlaylistsFuture,
        _recommendedSongsFuture,
        _newReleasesFuture,
        _suggestedArtistsFuture,
        _albumsAndSinglesFuture,
      ]);
    } catch (_) {
      // Keep UI stable if background fetch errors during refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;
    return Scaffold(
      appBar: AppBar(title: const Text('Catchify.')),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: commonSingleChildScrollViewPadding,
          child: Column(
            children: [
              ValueListenableBuilder<String?>(
                valueListenable: announcementURL,
                builder: (_, _url, __) {
                  if (_url == null) return const SizedBox.shrink();
                  final isSponsorshipAnnouncement = isSponsorshipAnnouncementUrl(
                    _url,
                  );
                  final _message = isSponsorshipAnnouncement
                      ? context.l10n!.sponsorProject
                      : context.l10n!.newAnnouncement;
                  final _icon = isSponsorshipAnnouncement
                      ? FluentIcons.heart_24_filled
                      : FluentIcons.megaphone_24_filled;

                  return AnnouncementBox(
                    message: _message,
                    url: _url,
                    icon: _icon,
                    onDismiss: () async {
                      announcementURL.value = null;
                    },
                  );
                },
              ),
              _buildSuggestedPlaylists(playlistHeight),
              _buildSuggestedPlaylists(playlistHeight, showOnlyLiked: true),
              _buildCurrentMonthRecapSection(),
              _buildRecommendedSongsSection(),
              _buildNewReleasesSection(context),
              _buildSuggestedArtistsSection(context),
              _buildAlbumsAndSinglesSection(context),
              const MiniPlayerBottomSpace(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedPlaylists(
    double playlistHeight, {
    bool showOnlyLiked = false,
  }) {
    if (showOnlyLiked) {
      return ValueListenableBuilder<List<Map>>(
        valueListenable: userLikedPlaylists,
        builder: (_, likedPlaylists, __) => _buildSuggestedPlaylistsSection(
          playlistHeight,
          likedPlaylists
              .where((playlist) => !isArtistPlaylist(playlist))
              .take(recommendedCubesNumber)
              .toList(),
          showOnlyLiked: true,
        ),
      );
    }

    return AsyncLoader<List<dynamic>>(
      future: _suggestedPlaylistsFuture,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      builder: (context, playlists) =>
          _buildSuggestedPlaylistsSection(playlistHeight, playlists),
    );
  }

  Widget _buildSuggestedPlaylistsSection(
    double playlistHeight,
    List<dynamic> playlists, {
    bool showOnlyLiked = false,
  }) {
    if (playlists.isEmpty) return const SizedBox.shrink();

    final sectionTitle = showOnlyLiked
        ? context.l10n!.backToFavorites
        : context.l10n!.suggestedPlaylists;
    final itemsNumber = playlists.length.clamp(0, recommendedCubesNumber);
    final isLargeScreen = MediaQuery.of(context).size.width > 480;
    final useCarousel = !isLargeScreen && itemsNumber >= 3;

    return Column(
      children: [
        SectionHeader(
          title: sectionTitle,
          icon: showOnlyLiked
              ? FluentIcons.heart_24_filled
              : FluentIcons.list_24_filled,
        ),
        SizedBox(
          height: playlistHeight,
          child: useCarousel
              ? _buildCarouselView(playlists, itemsNumber, playlistHeight)
              : _buildHorizontalList(playlists, itemsNumber, playlistHeight),
        ),
      ],
    );
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
      '/home/playlist/$playlistId',
      extra: playlist,
    );
  }

  Widget _buildHorizontalList(
    List<dynamic> playlists,
    int itemCount,
    double height,
  ) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final item = playlists[index];
        if (item is! Map) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openPlaylist(context, item),
            child: PlaylistCube(item, size: height),
          ),
        );
      },
    );
  }

  Widget _buildCarouselView(
    List<dynamic> playlists,
    int itemCount,
    double height,
  ) {
    return CarouselView.weighted(
      flexWeights: const <int>[3, 2, 1],
      itemSnapping: true,
      onTap: (index) {
        if (index >= 0 && index < playlists.length) {
          final item = playlists[index];
          if (item is Map) {
            _openPlaylist(context, item);
          }
        }
      },
      children: List.generate(itemCount, (index) {
        final item = playlists[index];
        if (item is! Map) return const SizedBox.shrink();
        return PlaylistCube(item, size: height * 2);
      }),
    );
  }

  Widget _buildRecommendedSongsSection() {
    return AsyncLoader<List<dynamic>>(
      future: _recommendedSongsFuture,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return _buildRecommendedForYouSection(context, data);
      },
    );
  }

  Widget _buildCurrentMonthRecapSection() {
    return ValueListenableBuilder<bool>(
      valueListenable: wrappedEnabled,
      builder: (_, isEnabled, __) {
        if (!isEnabled) return const SizedBox.shrink();

        final currentMonthKey = listeningStatsMonthKey(DateTime.now());
        final monthStats = listeningStatsService.monthStats(currentMonthKey);
        final songs = listeningStatsService.monthTopSongs(currentMonthKey);
        final displayMinutes = monthDisplayMinutes(monthStats);
        if (displayMinutes <= 0 && songs.isEmpty) {
          return const SizedBox.shrink();
        }

        final previewSongs = songs.take(wrappedShareSongsLimit).toList();
        final periodLabel = formatMonthPeriodLabel(
          Localizations.localeOf(context),
          currentMonthKey,
        );

        return Column(
          children: [
            SectionHeader(
              title: context.l10n!.timeMachine,
              icon: FluentIcons.data_trending_24_filled,
            ),
            ListeningRecapCard(
              periodLabel: periodLabel,
              minutes: displayMinutes,
              songs: previewSongs,
              onSongTap: (index) => _playRecapSongs(previewSongs, index),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push('/home/timeMachine'),
                  icon: const Icon(FluentIcons.arrow_right_24_regular),
                  label: Text(context.l10n!.listeningStats),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _playRecapSongs(
    List<Map<String, dynamic>> songs,
    int index,
  ) async {
    if (songs.isEmpty) return;
    await audioHandler.playPlaylistSong(
      playlist: {'title': context.l10n!.timeMachine, 'list': songs},
      songIndex: index,
    );
  }

  Widget _buildRecommendedForYouSection(
    BuildContext context,
    List<dynamic> data,
  ) {
    final recommendedTitle = context.l10n!.recommendedForYou;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnWidth = (screenWidth > 600) ? 380.0 : screenWidth * 0.88;

    final chunkedSongs = <List<dynamic>>[];
    for (var i = 0; i < data.length; i += 4) {
      chunkedSongs.add(data.sublist(i, math.min(i + 4, data.length)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: recommendedTitle,
          icon: FluentIcons.sparkle_24_filled,
          actionButton: IconButton(
            onPressed: () async {
              if (data.isEmpty) return;
              await audioHandler.playPlaylistSong(
                playlist: {'title': recommendedTitle, 'list': data},
                songIndex: 0,
              );
            },
            icon: Icon(
              FluentIcons.play_circle_24_filled,
              color: Theme.of(context).colorScheme.primary,
              size: 30,
            ),
          ),
        ),
        SizedBox(
          height: 280,
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
                    final ytid = song is Map ? song['ytid'] : null;
                    return RepaintBoundary(
                      key: listItemKey('home_recommended', globalIndex, song),
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
                              'title': recommendedTitle,
                              'list': data,
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
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSuggestedArtistsSection(BuildContext context) {
    return AsyncLoader<List<Map<String, dynamic>>>(
      future: _suggestedArtistsFuture,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      builder: (context, artists) {
        if (artists.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: context.l10n!.artists,
              icon: FluentIcons.person_star_24_filled,
            ),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: artists.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final artist = artists[index];
                  return RepaintBoundary(
                    key: listItemKey('home_artist', index, artist),
                    child: ArtistCard(artist: artist),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildAlbumsAndSinglesSection(BuildContext context) {
    final isTamil = Localizations.localeOf(context).languageCode == 'ta';
    final sectionTitle =
        isTamil ? 'ஆல்பங்கள் & சிங்கிள்கள்' : 'Albums & Singles';

    return AsyncLoader<List<Map<String, dynamic>>>(
      future: _albumsAndSinglesFuture,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      builder: (context, albums) {
        if (albums.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: sectionTitle,
              icon: FluentIcons.album_24_filled,
            ),
            SizedBox(
              height: 204,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: albums.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final album = albums[index];
                  return RepaintBoundary(
                    key: listItemKey('home_album_single', index, album),
                    child: AlbumCard(
                      album: album,
                      onTap: () => _openPlaylist(context, album),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildNewReleasesSection(BuildContext context) {
    final isTamil = Localizations.localeOf(context).languageCode == 'ta';
    final sectionTitle = isTamil ? 'புதிய வெளியீடுகள்' : 'New Releases';

    return AsyncLoader<List<Map<String, dynamic>>>(
      future: _newReleasesFuture,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      builder: (context, songs) {
        if (songs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: sectionTitle,
              icon: FluentIcons.sparkle_24_filled,
              actionButton: IconButton(
                onPressed: () async {
                  if (songs.isEmpty) return;
                  await audioHandler.playPlaylistSong(
                    playlist: {'title': sectionTitle, 'list': songs},
                    songIndex: 0,
                  );
                },
                icon: Icon(
                  FluentIcons.play_circle_24_filled,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
              ),
            ),
            SizedBox(
              height: 204,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: songs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return RepaintBoundary(
                    key: listItemKey('home_new_release', index, song),
                    child: SongCard(
                      song: song,
                      onTap: () async {
                        await audioHandler.playPlaylistSong(
                          playlist: {'title': sectionTitle, 'list': songs},
                          songIndex: index,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
