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

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/models/home_section.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/listening_stats_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/async_loader.dart';
import 'package:catchify/utilities/listening_stats_utils.dart';
import 'package:catchify/widgets/announcement_box.dart';
import 'package:catchify/widgets/home_section_renderer.dart';
import 'package:catchify/widgets/listening_recap_card.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/section_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<HomeSection>> _homeFeedFuture;

  String _selectedMood = 'All';
  static const _moods = [
    'All',
    'Romance',
    'Party',
    'Workout',
    'Chill',
    'Feel good',
    'Energy',
    'Focus',
  ];

  /// Guard flag: ensures we only launch futures once on first mount.
  /// Prevents double-loading when GoRouter re-mounts HomePage after
  /// navigating from the language onboarding screen.
  bool _loadStarted = false;

  /// Guard flag: ensures the freshLoad from language onboarding is only
  /// consumed once, even if didChangeDependencies is called multiple times.
  bool _freshLoadConsumed = false;

  void _initFutures({bool forceRefresh = false}) {
    _homeFeedFuture = getUnifiedHomeFeed(
      forceRefresh: forceRefresh,
      mood: _selectedMood,
    );
  }

  void _onMoodSelected(String mood) {
    if (_selectedMood == mood) return;
    setState(() {
      _selectedMood = mood;
      _initFutures();
    });
  }

  @override
  void initState() {
    super.initState();
    if (!_loadStarted) {
      _loadStarted = true;
      _initFutures();
    }
    externalRecommendations.addListener(_refreshHomeFeed);
    contentLanguagePreferenceNotifier
        .addListener(_onLanguagePreferenceChanged);
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
        setState(() {
          _selectedMood = 'All';
          _initFutures(forceRefresh: true);
        });
      });
    }
  }

  @override
  void dispose() {
    externalRecommendations.removeListener(_refreshHomeFeed);
    contentLanguagePreferenceNotifier
        .removeListener(_onLanguagePreferenceChanged);
    super.dispose();
  }

  void _onLanguagePreferenceChanged() {
    if (!mounted) return;
    setState(() {
      _selectedMood = 'All';
      _initFutures(forceRefresh: true);
    });
  }

  void _refreshHomeFeed() {
    if (!mounted) return;
    setState(() {
      _initFutures(forceRefresh: true);
    });
  }

  Future<void> _onRefresh() async {
    final nextFeed = getDynamicHomeFeed(
      forceRefresh: true,
      mood: _selectedMood,
    );
    await nextFeed.catchError((_) => <HomeSection>[]);

    if (mounted) {
      setState(() {
        _homeFeedFuture = nextFeed;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: announcementURL,
                  builder: (_, _url, __) {
                    if (_url == null) return const SizedBox.shrink();
                    final isSponsorshipAnnouncement =
                        isSponsorshipAnnouncementUrl(_url);
                    final message = isSponsorshipAnnouncement
                        ? (context.l10n?.sponsorProject ?? 'Sponsor Project')
                        : (context.l10n?.newAnnouncement ?? 'New Announcement');
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
                _buildMoodChipsSection(context),
                AsyncLoader<List<HomeSection>>(
                  future: _homeFeedFuture,
                  loadingWidget: _buildFeedSkeleton(context, playlistHeight),
                  errorBuilder: (context, error, stackTrace) =>
                      _buildFeedError(context, () => _initFutures(forceRefresh: true)),
                  builder: (context, sections) {
                    if (sections.isEmpty) {
                      return _buildFeedEmpty(context);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final section in sections)
                          HomeSectionRenderer(
                            section: section,
                            playlistHeight: playlistHeight,
                          ),
                        _buildFavoritesSection(playlistHeight),
                        _buildCurrentMonthRecapSection(),
                      ],
                    );
                  },
                ),
                const MiniPlayerBottomSpace(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodChipsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _moods.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final mood = _moods[index];
            final isSelected = mood == _selectedMood;
            final colorScheme = Theme.of(context).colorScheme;
            return ChoiceChip(
              label: Text(
                mood,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
              selected: isSelected,
              selectedColor: colorScheme.primary,
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color:
                      isSelected ? colorScheme.primary : Colors.transparent,
                ),
              ),
              onSelected: (_) => _onMoodSelected(mood),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeedSkeleton(BuildContext context, double playlistHeight) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 24,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: playlistHeight,
            child: const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedError(BuildContext context, VoidCallback? retry) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.warning_24_regular,
              size: 40,
              color: colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: retry,
              icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedEmpty(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.music_note_2_24_regular,
              size: 44,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No music found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _initFutures(forceRefresh: true),
              icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesSection(double playlistHeight) {
    return ValueListenableBuilder<List<Map>>(
      valueListenable: userLikedPlaylists,
      builder: (_, likedPlaylists, __) {
        final filtered = likedPlaylists
            .where((playlist) => !isArtistPlaylist(playlist))
            .take(recommendedCubesNumber)
            .toList();
        if (filtered.isEmpty) return const SizedBox.shrink();

        final section = HomeSection(
          title: context.l10n?.backToFavorites ?? 'Back to favorites',
          subtitle: 'YOUR LIKED PLAYLISTS',
          type: HomeContentType.playlists,
          contents: filtered.map(Map<String, dynamic>.from).toList(),
        );

        return HomeSectionRenderer(
          section: section,
          playlistHeight: playlistHeight,
        );
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
              title: context.l10n?.timeMachine ?? 'Time Machine',
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
                  label:
                      Text(context.l10n?.listeningStats ?? 'Listening stats'),
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
      playlist: {
        'title': context.l10n?.timeMachine ?? 'Time Machine',
        'list': songs,
      },
      songIndex: index,
    );
  }
}
