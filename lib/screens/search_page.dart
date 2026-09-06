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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:catchify/constants/app_constants.dart';
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

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  int maxSongsInList = 15;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSuggestionRequest = 0;
  int _searchSessionId = 0;
  bool _hasSearched = false;

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
        fetchSongsList(trimmedQuery),
        searchArtists(trimmedQuery),
        getPlaylists(query: trimmedQuery, type: 'album'),
        getPlaylists(query: trimmedQuery, type: 'playlist'),
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
        _songsSearchResult = await _fetchSongsForResolvedArtist(trimmedQuery);
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

  Future<List<dynamic>> _fetchSongsForResolvedArtist(String query) async {
    final artistName = _artistsSearchResult.first['title']?.toString().trim();
    if (artistName == null || artistName.isEmpty) return [];

    final fallbackQueries = <String>{
      if (artistName.toLowerCase() != query.trim().toLowerCase()) artistName,
      '$artistName songs',
      '$artistName music',
    };

    for (final fallbackQuery in fallbackQueries) {
      final songs = await fetchSongsList(fallbackQuery);
      if (songs.isNotEmpty) return songs;
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.search)),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final bar = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 600 : double.infinity,
                  ),
                  child: CustomSearchBar(
                    controller: _searchBar,
                    focusNode: _inputNode,
                    labelText: '${context.l10n!.search}...',
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

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildBody(context, primaryColor),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Color primaryColor) {
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
          return _buildSearchHistory(context);
        }

        if (_suggestionsList.isNotEmpty && !_hasSearched) {
          return _buildSuggestions(context);
        }

        if (_hasSearched) {
          final hasNoResults = _songsSearchResult.isEmpty &&
              _artistsSearchResult.isEmpty &&
              _albumsSearchResult.isEmpty &&
              _playlistsSearchResult.isEmpty;

          if (hasNoResults) {
            return _buildNoResultsFound(context);
          }

          return _buildSearchResults(context, primaryColor);
        }

        return _buildSearchHistory(context);
      },
    );
  }

  Widget _buildSearchHistory(BuildContext context) {
    return ValueListenableBuilder<List>(
      valueListenable: searchHistoryNotifier,
      builder: (context, searchHistory, _) {
        if (searchHistory.isEmpty) {
          final screenHeight = MediaQuery.of(context).size.height;
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

        return Column(
          key: ValueKey('search-history-${searchHistory.length}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n!.recentlyPlayed,
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
                      context.l10n!.clearSearchHistory,
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
        );
      },
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return Column(
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
    );
  }

  Widget _buildNoResultsFound(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
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
              'No results found for "${_searchBar.text.trim()}"',
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

  Widget _buildSearchResults(BuildContext context, Color primaryColor) {
    final widgets = <Widget>[];

    // Artists section
    if (_artistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.artists,
          primaryColor,
          icon: FluentIcons.person_24_filled,
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
          ArtistBar(
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
        );
      }
    }

    // Songs section
    if (_songsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.songs,
          primaryColor,
          icon: FluentIcons.music_note_1_24_filled,
        ),
      );

      final songsCount = _songsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _songsSearchResult.length;

      for (var index = 0; index < songsCount; index++) {
        final song = _songsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, songsCount);
        widgets.add(
          SongBar(
            song,
            true,
            key: listItemKey('search_song', index, song),
            showMusicDuration: true,
            borderRadius: borderRadius,
            onPlay: () async {
              await audioHandler.playPlaylistSong(
                playlist: {
                  'title': _searchBar.text.trim().isNotEmpty
                      ? _searchBar.text.trim()
                      : context.l10n!.songs,
                  'list': _songsSearchResult.take(maxSongsInList).toList(),
                },
                songIndex: index,
              );
            },
          ),
        );
      }
    }

    // Albums section
    if (_albumsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.albums,
          primaryColor,
          icon: FluentIcons.album_24_filled,
        ),
      );

      final albumsCount = _albumsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _albumsSearchResult.length;

      for (var index = 0; index < albumsCount; index++) {
        final playlist = _albumsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, albumsCount);

        widgets.add(
          PlaylistBar(
            key: listItemKey('search_album', index, playlist),
            playlist['title'],
            playlistData: playlist,
            playlistId: playlist['ytid'],
            playlistArtwork: playlist['image'],
            cubeIcon: FluentIcons.cd_16_filled,
            isAlbum: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Playlists section
    if (_playlistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.playlists,
          primaryColor,
          icon: FluentIcons.text_bullet_list_24_filled,
        ),
      );

      final playlistsCount = _playlistsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _playlistsSearchResult.length;

      for (var index = 0; index < playlistsCount; index++) {
        final playlist = _playlistsSearchResult[index];
        final isLast = index == playlistsCount - 1;
        final borderRadius = getItemBorderRadius(index, playlistsCount);

        widgets.add(
          Padding(
            padding: isLast ? commonListViewBottomPadding : EdgeInsets.zero,
            child: PlaylistBar(
              key: listItemKey('search_playlist', index, playlist),
              playlist['title'],
              playlistData: playlist,
              playlistId: playlist['ytid'],
              playlistArtwork: playlist['image'],
              cubeIcon: FluentIcons.apps_list_24_filled,
              borderRadius: borderRadius,
            ),
          ),
        );
      }
    }

    return Column(
      key: ValueKey(
        'results-${_songsSearchResult.length}-${_artistsSearchResult.length}-${_albumsSearchResult.length}-${_playlistsSearchResult.length}',
      ),
      children: widgets,
    );
  }

  Future<bool?> _showConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmationMessage: context.l10n!.removeSearchQueryQuestion,
          submitMessage: context.l10n!.confirm,
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
          confirmationMessage: context.l10n!.clearSearchHistoryQuestion,
          submitMessage: context.l10n!.confirm,
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
