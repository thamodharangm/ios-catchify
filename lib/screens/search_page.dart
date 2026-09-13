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

import 'dart:async';
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/widgets/artist_bar.dart';
import 'package:catchify/widgets/confirmation_dialog.dart';
import 'package:catchify/widgets/custom_bar.dart';
import 'package:catchify/widgets/custom_search_bar.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/playlist_bar.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/section_title.dart';
import 'package:catchify/widgets/song_bar.dart';
import 'package:catchify/widgets/spinner.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

// Global ValueNotifier for search history to make it reactive
final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  Hive.box('user').get('searchHistory', defaultValue: []),
);

// Backward compatibility - keep the global variable for existing code
List get searchHistory => searchHistoryNotifier.value;
set searchHistory(List value) {
  searchHistoryNotifier.value = value;
}

void reloadSearchHistoryFromStorage() {
  searchHistoryNotifier.value = Hive.box(
    'user',
  ).get('searchHistory', defaultValue: []);
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  int maxSongsInList = 20;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSuggestionRequest = 0;
  int _searchSessionId = 0;
  bool _hasSearched = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _submitSearch([String? query]) async {
    if (query != null) {
      _searchBar.text = query;
      _searchBar.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchBar.text.length),
      );
    }

    _latestSuggestionRequest++;
    _debounce?.cancel();
    _suggestionsList = [];
    if (mounted) _inputNode.unfocus();
    if (mounted) setState(() {});

    await search();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value;
    final requestId = ++_latestSuggestionRequest;

    // Clear suggestions and previous results immediately if input is empty
    if (query.trim().isEmpty) {
      _latestSuggestionRequest++;
      _searchSessionId++; // Invalidate any in-flight search session
      _suggestionsList = [];
      _hasSearched = false;
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _albumsSearchResult = [];
      _playlistsSearchResult = [];
      _fetchingSongs.value = false;
      if (mounted) setState(() {});
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 300),
      () async {
        try {
          final searchSuggestions = await getSearchSuggestions(query);

          if (!mounted ||
              requestId != _latestSuggestionRequest ||
              _searchBar.text != query) {
            return;
          }

          _suggestionsList = List<String>.from(searchSuggestions);
          _hasSearched = false;
          if (mounted) setState(() {});
        } catch (_) {}
      },
    );
  }

  @override
  void dispose() {
    _searchBar.dispose();
    _inputNode.dispose();
    _fetchingSongs.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> search() async {
    final query = _searchBar.text;
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      _searchSessionId++;
      _hasSearched = false;
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _albumsSearchResult = [];
      _playlistsSearchResult = [];
      _suggestionsList = [];
      _fetchingSongs.value = false;
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;

    final currentSession = ++_searchSessionId;
    _fetchingSongs.value = true;
    _hasSearched = true;
    _songsSearchResult = [];
    _artistsSearchResult = [];
    _albumsSearchResult = [];
    _playlistsSearchResult = [];
    if (mounted) setState(() {});

    final updatedHistory = List.from(searchHistory)
      ..remove(trimmedQuery)
      ..insert(0, trimmedQuery);
    if (updatedHistory.length > 25) {
      updatedHistory.removeRange(25, updatedHistory.length);
    }
    searchHistoryNotifier.value = updatedHistory;
    unawaited(addOrUpdateData<List>('user', 'searchHistory', updatedHistory));

    try {
      final results = await Future.wait<List<dynamic>>([
        fetchSongsList(trimmedQuery).catchError((e, stackTrace) {
          logger.log('Error fetching songs for "$trimmedQuery":',
              error: e, stackTrace: stackTrace);
          return <dynamic>[];
        }),
        searchArtists(trimmedQuery).catchError((e, stackTrace) {
          logger.log('Error searching artists for "$trimmedQuery":',
              error: e, stackTrace: stackTrace);
          return <Map<String, dynamic>>[];
        }),
        getPlaylists(query: trimmedQuery, type: 'album').catchError(
            (e, stackTrace) {
          logger.log('Error searching albums for "$trimmedQuery":',
              error: e, stackTrace: stackTrace);
          return <dynamic>[];
        }),
        getPlaylists(query: trimmedQuery, type: 'playlist').catchError(
            (e, stackTrace) {
          logger.log('Error searching playlists for "$trimmedQuery":',
              error: e, stackTrace: stackTrace);
          return <dynamic>[];
        }),
      ]);

      if (!mounted ||
          currentSession != _searchSessionId ||
          _searchBar.text.trim() != trimmedQuery) {
        return;
      }

      _songsSearchResult = results[0];
      _artistsSearchResult = results[1]
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      if (_songsSearchResult.isEmpty && _artistsSearchResult.isNotEmpty) {
        _songsSearchResult = await _fetchSongsForResolvedArtist(
          trimmedQuery,
          currentSession,
        );
      }
      if (!mounted || currentSession != _searchSessionId) return;

      _albumsSearchResult = results[2];
      _playlistsSearchResult = results[3];
    } catch (e, stackTrace) {
      logger.log(
        'Error while searching online songs',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted && currentSession == _searchSessionId) {
        _fetchingSongs.value = false;
        setState(() {});
      }
    }
  }

  Future<List<dynamic>> _fetchSongsForResolvedArtist(
    String query,
    int session,
  ) async {
    final artistName = _artistsSearchResult.first['title']?.toString().trim();
    if (artistName == null || artistName.isEmpty) return [];

    final fallbackQueries = <String>{
      if (artistName.toLowerCase() != query.trim().toLowerCase()) artistName,
      '$artistName songs',
      '$artistName music',
    };

    for (final fallbackQuery in fallbackQueries) {
      if (!mounted || session != _searchSessionId) return [];
      final songs = await fetchSongsList(fallbackQuery);
      if (!mounted || session != _searchSessionId) return [];
      if (songs.isNotEmpty) return songs;
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n?.search ?? 'Search',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  final bar = ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 600 : double.infinity,
                    ),
                    child: CustomSearchBar(
                      controller: _searchBar,
                      focusNode: _inputNode,
                      labelText: '${context.l10n?.search ?? 'Search'}...',
                      onChanged: _onSearchChanged,
                      onSubmitted: (String value) {
                        _submitSearch();
                      },
                    ),
                  );
                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [bar],
                    );
                  } else {
                    return bar;
                  }
                },
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildBody(),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ValueListenableBuilder<bool>(
      valueListenable: _fetchingSongs,
      builder: (context, isFetching, _) {
        if (isFetching) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Spinner()),
          );
        }

        if (_searchBar.text.trim().isEmpty) {
          return _buildSearchHistory();
        }

        if (_suggestionsList.isNotEmpty && !_hasSearched) {
          return _buildSuggestions();
        }

        if (_hasSearched) {
          final hasNoResults = _songsSearchResult.isEmpty &&
              _artistsSearchResult.isEmpty &&
              _albumsSearchResult.isEmpty &&
              _playlistsSearchResult.isEmpty;

          if (hasNoResults) {
            return _buildNoResultsFound();
          }

          return _buildSearchResults();
        }

        return _buildSearchHistory();
      },
    );
  }

  Widget _buildSearchHistory() {
    return ValueListenableBuilder<List>(
      valueListenable: searchHistoryNotifier,
      builder: (context, searchHistory, _) {
        if (searchHistory.isEmpty) {
          final screenHeight = MediaQuery.sizeOf(context).height;
          return SizedBox(
            height: screenHeight * 0.52,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/listening-music-headphones.svg',
                width: 150,
                height: 175,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
                  BlendMode.srcIn,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            key: ValueKey('search-history-${searchHistory.length}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Localizations.localeOf(context).languageCode == 'ta'
                          ? 'தேடல் வரலாறு'
                          : '${context.l10n?.search ?? 'Search'} History',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final confirm =
                            await _showClearAllConfirmationDialog(context) ??
                                false;
                        if (confirm) {
                          searchHistoryNotifier.value = [];
                          unawaited(
                            addOrUpdateData<List>('user', 'searchHistory', []),
                          );
                        }
                      },
                      child: Text(
                        context.l10n?.clearSearchHistory ??
                            'Clear search history',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (int index = 0; index < searchHistory.length; index++)
                Builder(
                  builder: (context) {
                    final query = searchHistory[index];
                    final borderRadius = getItemBorderRadius(
                      index,
                      searchHistory.length,
                    );

                    return CustomBar(
                      query.toString(),
                      FluentIcons.history_24_regular,
                      borderRadius: borderRadius,
                      onTap: () async {
                        await _submitSearch(query.toString());
                      },
                      trailing: IconButton(
                        icon: Icon(
                          FluentIcons.dismiss_20_regular,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                        onPressed: () {
                          final updatedHistory = List.from(searchHistory)
                            ..remove(query);
                          searchHistoryNotifier.value = updatedHistory;
                          unawaited(
                            addOrUpdateData<List>(
                              'user',
                              'searchHistory',
                              updatedHistory,
                            ),
                          );
                        },
                      ),
                      onLongPress: () async {
                        final confirm =
                            await _showConfirmationDialog(context) ?? false;
                        if (confirm && searchHistory.contains(query)) {
                          final updatedHistory = List.from(searchHistory)
                            ..remove(query);
                          searchHistoryNotifier.value = updatedHistory;
                          unawaited(
                            addOrUpdateData<List>(
                              'user',
                              'searchHistory',
                              updatedHistory,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        key: ValueKey(
          'suggestions-${_suggestionsList.length}-${_searchBar.text}',
        ),
        children: [
          for (int index = 0; index < _suggestionsList.length; index++)
            Builder(
              builder: (context) {
                final query = _suggestionsList[index];
                final borderRadius = getItemBorderRadius(
                  index,
                  _suggestionsList.length,
                );

                return CustomBar(
                  query,
                  FluentIcons.search_24_regular,
                  borderRadius: borderRadius,
                  onTap: () async {
                    await _submitSearch(query);
                  },
                  trailing: IconButton(
                    icon: Icon(
                      FluentIcons.arrow_up_left_24_regular,
                      size: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                    onPressed: () {
                      _searchBar.text = query;
                      _searchBar.selection = TextSelection.fromPosition(
                        TextPosition(offset: _searchBar.text.length),
                      );
                      _onSearchChanged(query);
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Padding(
      padding: const EdgeInsets.only(top: 80, left: 16, right: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.search_24_regular,
              size: 56,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              Localizations.localeOf(context).languageCode == 'ta'
                  ? 'முடிவுகள் எதுவும் கிடைக்கவில்லை: "${_searchBar.text.trim()}"'
                  : 'No results found for "${_searchBar.text.trim()}"',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final widgets = <Widget>[];

    // Artists section
    if (_artistsSearchResult.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionTitle(
            context.l10n?.artists ?? 'Artists',
            primaryColor,
            icon: FluentIcons.person_24_filled,
          ),
        ),
      );

      final artists = _artistsSearchResult.take(3).toList();
      for (var index = 0; index < artists.length; index++) {
        final artist = Map<String, dynamic>.from(artists[index]);
        final artistId =
            artist['ytid']?.toString() ?? artist['title']?.toString() ?? '';
        if (artistId.isEmpty) continue;

        final borderRadius = getItemBorderRadius(index, artists.length);
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ArtistBar(
              key: listItemKey('search_artist', index, artist),
              artist: artist,
              borderRadius: borderRadius,
              onTap: () {
                context.push(
                  '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistId)}',
                  extra: artist,
                );
              },
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 12));
    }

    // Songs section
    if (_songsSearchResult.isNotEmpty) {
      widgets.add(_buildChunkedSongsSection());
    }

    // Albums section
    if (_albumsSearchResult.isNotEmpty) {
      widgets.add(_buildChunkedAlbumsSection());
    }

    // Playlists section
    if (_playlistsSearchResult.isNotEmpty) {
      widgets.add(_buildChunkedPlaylistsSection());
    }

    return Column(
      key: ValueKey(
        'results-${_songsSearchResult.length}-${_artistsSearchResult.length}-${_albumsSearchResult.length}-${_playlistsSearchResult.length}',
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildChunkedSongsSection() {
    final songsTitle = context.l10n?.songs ?? 'Songs';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnWidth = (screenWidth > 600) ? 380.0 : screenWidth * 0.88;
    final songsCount = _songsSearchResult.length > maxSongsInList
        ? maxSongsInList
        : _songsSearchResult.length;
    final songs = _songsSearchResult.take(songsCount).toList();

    final chunkedSongs = <List<dynamic>>[];
    for (var i = 0; i < songs.length; i += 4) {
      chunkedSongs.add(songs.sublist(i, math.min(i + 4, songs.length)));
    }

    // Dynamic row height calculation accounting for accessibility text scale
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final rowItemHeight =
        52.0 + 14.0 + math.max(0.0, (textScale - 1.0) * 26.0);
    final maxChunkLength =
        chunkedSongs.map((c) => c.length).fold<int>(0, math.max);
    final gridHeight = maxChunkLength * rowItemHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: songsTitle,
            icon: FluentIcons.music_note_1_24_filled,
            actionButton: IconButton(
              tooltip: context.l10n?.play ?? 'Play',
              onPressed: () async {
                if (songs.isEmpty) return;
                await audioHandler.playPlaylistSong(
                  playlist: {
                    'title': _searchBar.text.trim().isNotEmpty
                        ? _searchBar.text.trim()
                        : songsTitle,
                    'list': songs,
                  },
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
        ),
        SizedBox(
          height: gridHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chunkedSongs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                      key: listItemKey('search_song', globalIndex, song),
                      child: SongBar(
                        song,
                        true,
                        key: ValueKey('search_song_${ytid}_$globalIndex'),
                        showMusicDuration: true,
                        backgroundColor: Colors.transparent,
                        barPadding: const EdgeInsetsDirectional.symmetric(
                          vertical: 7,
                          horizontal: 4,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        onPlay: () async {
                          await audioHandler.playPlaylistSong(
                            playlist: {
                              'title': _searchBar.text.trim().isNotEmpty
                                  ? _searchBar.text.trim()
                                  : songsTitle,
                              'list': songs,
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

  Widget _buildChunkedAlbumsSection() {
    final albumsTitle = context.l10n?.albums ?? 'Albums';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnWidth = (screenWidth > 600) ? 380.0 : screenWidth * 0.88;
    final albumsCount = _albumsSearchResult.length > maxSongsInList
        ? maxSongsInList
        : _albumsSearchResult.length;
    final albums = _albumsSearchResult.take(albumsCount).toList();

    final chunkedAlbums = <List<dynamic>>[];
    for (var i = 0; i < albums.length; i += 4) {
      chunkedAlbums.add(albums.sublist(i, math.min(i + 4, albums.length)));
    }

    // PlaylistBar has 60px artwork + 14px padding = 74px minimum base height
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final rowItemHeight =
        60.0 + 14.0 + math.max(0.0, (textScale - 1.0) * 28.0);
    final maxChunkLength =
        chunkedAlbums.map((c) => c.length).fold<int>(0, math.max);
    final gridHeight = maxChunkLength * rowItemHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: albumsTitle,
            icon: FluentIcons.album_24_filled,
          ),
        ),
        SizedBox(
          height: gridHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chunkedAlbums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, colIndex) {
              final chunk = chunkedAlbums[colIndex];
              return SizedBox(
                width: columnWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(chunk.length, (rowIndex) {
                    final playlist = chunk[rowIndex];
                    final globalIndex = colIndex * 4 + rowIndex;
                    return RepaintBoundary(
                      key: listItemKey('search_album', globalIndex, playlist),
                      child: PlaylistBar(
                        playlist['title'],
                        playlistData: playlist,
                        playlistId: playlist['ytid'],
                        playlistArtwork:
                            playlist['highResImage'] ?? playlist['image'],
                        cubeIcon: FluentIcons.cd_16_filled,
                        isAlbum: true,
                        backgroundColor: Colors.transparent,
                        barPadding: const EdgeInsetsDirectional.symmetric(
                          vertical: 7,
                          horizontal: 4,
                        ),
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildChunkedPlaylistsSection() {
    final playlistsTitle = context.l10n?.playlists ?? 'Playlists';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnWidth = (screenWidth > 600) ? 380.0 : screenWidth * 0.88;
    final playlistsCount = _playlistsSearchResult.length > maxSongsInList
        ? maxSongsInList
        : _playlistsSearchResult.length;
    final playlists = _playlistsSearchResult.take(playlistsCount).toList();

    final chunkedPlaylists = <List<dynamic>>[];
    for (var i = 0; i < playlists.length; i += 4) {
      chunkedPlaylists.add(
        playlists.sublist(i, math.min(i + 4, playlists.length)),
      );
    }

    // PlaylistBar has 60px artwork + 14px padding = 74px minimum base height
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final rowItemHeight =
        60.0 + 14.0 + math.max(0.0, (textScale - 1.0) * 28.0);
    final maxChunkLength =
        chunkedPlaylists.map((c) => c.length).fold<int>(0, math.max);
    final gridHeight = maxChunkLength * rowItemHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: playlistsTitle,
            icon: FluentIcons.text_bullet_list_24_filled,
          ),
        ),
        SizedBox(
          height: gridHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chunkedPlaylists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, colIndex) {
              final chunk = chunkedPlaylists[colIndex];
              return SizedBox(
                width: columnWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(chunk.length, (rowIndex) {
                    final playlist = chunk[rowIndex];
                    final globalIndex = colIndex * 4 + rowIndex;
                    return RepaintBoundary(
                      key: listItemKey(
                        'search_playlist',
                        globalIndex,
                        playlist,
                      ),
                      child: PlaylistBar(
                        playlist['title'],
                        playlistData: playlist,
                        playlistId: playlist['ytid'],
                        playlistArtwork:
                            playlist['highResImage'] ?? playlist['image'],
                        cubeIcon: FluentIcons.apps_list_24_filled,
                        backgroundColor: Colors.transparent,
                        barPadding: const EdgeInsetsDirectional.symmetric(
                          vertical: 7,
                          horizontal: 4,
                        ),
                        borderRadius: BorderRadius.circular(12),
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

  Future<bool?> _showConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmationMessage: context.l10n?.removeSearchQueryQuestion ??
              'Are you sure you want to remove this search query?',
          submitMessage: context.l10n?.confirm ?? 'Confirm',
          onCancel: () {
            Navigator.of(context).pop(false);
          },
          onSubmit: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );
  }

  Future<bool?> _showClearAllConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmationMessage: context.l10n?.clearSearchHistoryQuestion ??
              'Are you sure you want to clear search history?',
          submitMessage: context.l10n?.confirm ?? 'Confirm',
          onCancel: () {
            Navigator.of(context).pop(false);
          },
          onSubmit: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );
  }
}
