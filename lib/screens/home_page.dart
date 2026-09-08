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
  late Future<List> _fromTheCommunityFuture;
  late Future<List> _recommendedSongsFuture;
  late Future<List<Map<String, dynamic>>> _newReleasesFuture;
  late Future<List<Map<String, dynamic>>> _suggestedArtistsFuture;
  late Future<List<Map<String, dynamic>>> _albumsAndSinglesFuture;

  /// Guard flag: ensures we only launch futures once on first mount.
  /// Prevents double-loading when GoRouter re-mounts HomePage after
  /// navigating from the language onboarding screen.
  bool _loadStarted = false;

  /// Guard flag: ensures the freshLoad from language onboarding is only
  /// consumed once, even if didChangeDependencies is called multiple times.
  bool _freshLoadConsumed = false;

  void _initFutures({bool forceRefresh = false}) {
    _fromTheCommunityFuture = getCommunityPlaylists(
      limit: recommendedCubesNumber,
      forceRefresh: forceRefresh,
    );
    _recommendedSongsFuture = getRecommendedSongs(forceRefresh: forceRefresh);
    _newReleasesFuture = getSuggestedNewReleases(forceRefresh: forceRefresh);
    _suggestedArtistsFuture = getSuggestedArtists(forceRefresh: forceRefresh);
    _albumsAndSinglesFuture = getSuggestedAlbumsAndSingles(
      forceRefresh: forceRefresh,
    );
  }

  @override
  void initState() {
    super.initState();
    if (!_loadStarted) {
      _loadStarted = true;
      _initFutures();
    }
    externalRecommendations.addListener(_refreshRecommendedSongs);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When navigating here from language onboarding, GoRouter passes
    // extra: {'freshLoad': true}. Detect it and do one clean reload so
    // the correct language's content is shown — without a second spinner.
    // _freshLoadConsumed guards against firing on every subsequent
    // didChangeDependencies call (e.g. on Locale / Theme changes).
    if (_freshLoadConsumed) return;
    final extra = GoRouterState.of(context).extra;
    if (extra is Map && extra['freshLoad'] == true) {
      _freshLoadConsumed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _initFutures(forceRefresh: true));
      });
    }
  }

  @override
  void dispose() {
    externalRecommendations.removeListener(_refreshRecommendedSongs);
    super.dispose();
  }

  void _refreshRecommendedSongs() {
    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = getRecommendedSongs(forceRefresh: true);
    });
  }

  Future<void> _onRefresh() async {
    final fromTheCommunityFuture = getCommunityPlaylists(
      limit: recommendedCubesNumber,
      forceRefresh: true,
    );
    final recommendedSongsFuture = getRecommendedSongs(forceRefresh: true);
    final newReleasesFuture = getSuggestedNewReleases(forceRefresh: true);
    final suggestedArtistsFuture = getSuggestedArtists(forceRefresh: true);
    final albumsAndSinglesFuture = getSuggestedAlbumsAndSingles(
      forceRefresh: true,
    );

    // Ignore individual future errors so the UI stays stable on refresh.
    await Future.wait([
      fromTheCommunityFuture,
      recommendedSongsFuture,
      newReleasesFuture,
      suggestedArtistsFuture,
      albumsAndSinglesFuture,
    ]).catchError((_) => <List<dynamic>>[]);

    if (mounted) {
      setState(() {
        _fromTheCommunityFuture = fromTheCommunityFuture;
        _recommendedSongsFuture = recommendedSongsFuture;
        _newReleasesFuture = newReleasesFuture;
        _suggestedArtistsFuture = suggestedArtistsFuture;
        _albumsAndSinglesFuture = albumsAndSinglesFuture;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;
    return Scaffold(
      appBar: AppBar(title: const Text('Catchify.')),
      body: RefreshIndicator.adaptive(
        onRefresh: _onRefresh,
        color: Theme.of(context).colorScheme.primary,
        notificationPredicate: (notification) =>
            notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: commonSingleChildScrollViewPadding,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
              ValueListenableBuilder<String?>(
                valueListenable: announcementURL,
                builder: (_, _url, __) {
                  if (_url == null) return const SizedBox.shrink();
                  final isSponsorshipAnnouncement = isSponsorshipAnnouncementUrl(
                    _url,
                  );
                  final message = isSponsorshipAnnouncement
                      ? context.l10n!.sponsorProject
                      : context.l10n!.newAnnouncement;
                  final icon = isSponsorshipAnnouncement
                      ? FluentIcons.heart_24_filled
                      : FluentIcons.megaphone_24_filled;

                  return AnnouncementBox(
                    message: message,
                    url: _url,
                    icon: icon,
                    onDismiss: () async {
                      announcementURL.value = null;
                    },
                  );
                },
              ),
              _buildRecommendedSongsSection(),
              _buildFromTheCommunitySection(playlistHeight),
              _buildNewReleasesSection(context),
              _buildAlbumsAndSinglesSection(context),
              _buildSuggestedArtistsSection(context),
              _buildFavoritesSection(playlistHeight),
              _buildCurrentMonthRecapSection(),
              const MiniPlayerBottomSpace(),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildFromTheCommunitySection(double playlistHeight) {
    return AsyncLoader<List<dynamic>>(
      future: _fromTheCommunityFuture,
      loadingWidget: const SizedBox.shrink(),
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      builder: (context, playlists) => _buildPlaylistsSection(
        playlistHeight,
        playlists,
        title: context.l10n?.fromTheCommunity ?? 'From the community',
        icon: FluentIcons.people_community_24_filled,
      ),
    );
  }

  Widget _buildFavoritesSection(double playlistHeight) {
    return ValueListenableBuilder<List<Map>>(
      valueListenable: userLikedPlaylists,
      builder: (_, likedPlaylists, __) => _buildPlaylistsSection(
        playlistHeight,
        likedPlaylists
            .where((playlist) => !isArtistPlaylist(playlist))
            .take(recommendedCubesNumber)
            .toList(),
        title: context.l10n!.backToFavorites,
        icon: FluentIcons.heart_24_filled,
      ),
    );
  }

  Widget _buildPlaylistsSection(
    double playlistHeight,
    List<dynamic> playlists, {
    required String title,
    required IconData icon,
  }) {
    if (playlists.isEmpty) return const SizedBox.shrink();

    final itemsNumber = playlists.length.clamp(0, recommendedCubesNumber);
    final isLargeScreen = MediaQuery.of(context).size.width > 480;
    final useCarousel =
        !isLargeScreen && itemsNumber >= 3 && playlists.length >= 3;

    return Column(
      children: [
        SectionHeader(
          title: title,
          icon: icon,
        ),
        SizedBox(
          height: playlistHeight,
          child: useCarousel
              ? _buildCarouselView(playlists, itemsNumber, playlistHeight)
              : _buildHorizontalList(playlists, itemsNumber, playlistHeight),
        ),
        const SizedBox(height: 12),
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
      '/home/playlist/${Uri.encodeComponent(playlistId)}',
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
    if (itemCount < 3 || playlists.length < 3) {
      return _buildHorizontalList(playlists, itemCount, height);
    }
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
        return PlaylistCube(item, size: height);
      }),
    );
  }

  Widget _buildRecommendedSongsSection() {
    return AsyncLoader<List<dynamic>>(
      future: _recommendedSongsFuture,
      loadingWidget: const SizedBox.shrink(),
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
          // Each SongBar is ~66px (thumbnail 48 + 7+7 vertical padding + divider).
          // Compute height from the tallest chunk to avoid overflow or empty space.
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
      loadingWidget: const SizedBox.shrink(),
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
    final sectionTitle = context.l10n?.albumsForYou ?? 'Albums for you';

    return AsyncLoader<List<Map<String, dynamic>>>(
      future: _albumsAndSinglesFuture,
      loadingWidget: const SizedBox.shrink(),
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
    final sectionTitle = context.l10n?.newReleases ?? 'New releases';

    return AsyncLoader<List<Map<String, dynamic>>>(
      future: _newReleasesFuture,
      loadingWidget: const SizedBox.shrink(),
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      builder: (context, songs) {
        if (songs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: sectionTitle,
              icon: FluentIcons.arrow_trending_lines_24_filled,
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
