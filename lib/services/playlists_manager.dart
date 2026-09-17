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

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart'
    show appStartupStopwatch, checkAndLogColdStartPerf, homeCacheMs, logger;
import 'package:catchify/models/home_section.dart';
import 'package:catchify/services/artist_service.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/home_feed_composer.dart';
import 'package:catchify/services/personalization_service.dart';
import 'package:catchify/services/playlist_download_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/formatter.dart';
import 'package:catchify/utilities/playlist_utils.dart';
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

List<Map> playlists = [];
final userPlaylists = ValueNotifier<List<String>>(
  List<String>.from(Hive.box('user').get('playlists', defaultValue: [])),
);
final userCustomPlaylists = ValueNotifier<List<Map>>(
  List<Map>.from(Hive.box('user').get('customPlaylists', defaultValue: [])),
);
final userLikedPlaylists = ValueNotifier<List<Map>>(
  List<Map>.from(Hive.box('user').get('likedPlaylists', defaultValue: [])),
);
final userPlaylistFolders = ValueNotifier<List<Map>>(
  List<Map>.from(Hive.box('user').get('playlistFolders', defaultValue: [])),
);
final pinnedPlaylistIds = ValueNotifier<List<String>>(
  List<String>.from(
    Hive.box('user').get('pinnedPlaylistIds', defaultValue: <String>[]),
  ),
);
final onlinePlaylists = ValueNotifier<List<Map>>([]);

bool isArtistPlaylist(dynamic playlist) =>
    PlaylistUtils.isArtistPlaylist(playlist);

List<Map> getLikedPlaylistItems({bool includeArtists = false}) {
  return userLikedPlaylists.value
      .where((playlist) => includeArtists || !isArtistPlaylist(playlist))
      .toList();
}

List<Map> getLikedArtistItems({bool offlineOnly = false}) {
  final artists = <Map>[];
  for (final playlist in userLikedPlaylists.value.where(isArtistPlaylist)) {
    if (!offlineOnly) {
      artists.add(playlist);
      continue;
    }

    final offlineArtist = _findOfflinePlaylist(
      playlist['ytid']?.toString() ?? '',
    );
    if (offlineArtist != null) {
      artists.add(offlineArtist);
    }
  }
  return artists;
}

void reloadPlaylistLibraryStateFromStorage() {
  final userBox = Hive.box('user');
  userPlaylists.value = List<String>.from(
    userBox.get('playlists', defaultValue: []),
  );
  userCustomPlaylists.value = List<Map>.from(
    userBox.get('customPlaylists', defaultValue: []),
  );
  userLikedPlaylists.value = List<Map>.from(
    userBox.get('likedPlaylists', defaultValue: []),
  );
  userPlaylistFolders.value = List<Map>.from(
    userBox.get('playlistFolders', defaultValue: []),
  );
  pinnedPlaylistIds.value = List<String>.from(
    userBox.get('pinnedPlaylistIds', defaultValue: <String>[]),
  );
}

void _updateOnlineCache(Map? p) {
  if (p != null && !onlinePlaylists.value.any((x) => x['ytid'] == p['ytid'])) {
    onlinePlaylists.value = [...onlinePlaylists.value, p];
  }
}

Map? _searchAppPlaylistsById(String id) {
  for (final p in userCustomPlaylists.value) {
    if (p['ytid']?.toString() == id) return p;
  }
  for (final f in userPlaylistFolders.value) {
    for (final p in (f['playlists'] as List? ?? [])) {
      if (p['ytid']?.toString() == id) return p as Map;
    }
  }
  for (final p in userLikedPlaylists.value) {
    if (p['ytid']?.toString() == id) return p;
  }
  for (final p in onlinePlaylists.value) {
    if (p['ytid']?.toString() == id) return p;
  }
  for (final p in offlinePlaylistService.offlinePlaylists.value) {
    if (p['ytid']?.toString() == id) return p as Map;
  }
  for (final p in playlists) {
    if (p['ytid']?.toString() == id) return p;
  }
  return null;
}

List<Map> resolvePinnedPlaylists(List<String> ids) {
  if (ids.isEmpty) return [];
  final result = <Map>[];
  for (final id in ids) {
    final match = _searchAppPlaylistsById(id);
    if (match != null) result.add(match);
  }
  return result;
}

const pinnedPlaylistsLimit = 5;

var _playlistLikeUpdateToken = 0;
final _latestPlaylistLikeUpdateTokens = <String, int>{};

Future<List<dynamic>> getUserPlaylists() async {
  final futures = userPlaylists.value.map((playlistID) async {
    try {
      final plist = await ytMusicClient.music.getPlaylist(playlistID);
      return {
        'ytid': plist.id,
        'title': plist.title,
        'image': plist.thumbnailUrl,
        'source': 'youtube-music-playlist',
        'list': [],
      };
    } catch (e, stackTrace) {
      logger.log(
        'Error occurred while fetching the playlist:',
        error: e,
        stackTrace: stackTrace,
      );
      return {
        'ytid': playlistID,
        'title': 'Failed playlist',
        'image': null,
        'source': 'youtube-music-playlist',
        'list': [],
      };
    }
  });

  final results = await Future.wait(futures);
  for (final result in results) {
    _updateOnlineCache(result);
  }
  return results.toList();
}

Future<String> addUserPlaylist(String input, BuildContext context) async {
  String? playlistId = input;

  if (input.startsWith('http://') || input.startsWith('https://')) {
    playlistId = extractYoutubePlaylistId(input);

    if (playlistId == null) {
      return '${context.l10n!.notYTlist}!';
    }
  }

  try {
    if (playlistExistsAnywhere(playlistId)) {
      return '${context.l10n!.playlistAlreadyExists}!';
    }

    final playlist = await ytMusicClient.music.getPlaylist(playlistId);
    if (playlist.title.isEmpty) {
      return '${context.l10n!.invalidYouTubePlaylist}!';
    }

    userPlaylists.value = [...userPlaylists.value, playlistId];
    unawaited(addOrUpdateData<List>('user', 'playlists', userPlaylists.value));
    return '${context.l10n!.addedSuccess}!';
  } catch (e, stackTrace) {
    logger.log('Error adding user playlist', error: e, stackTrace: stackTrace);
    return '${context.l10n!.error}: $e';
  }
}

(String message, String playlistId) createCustomPlaylist(
  String playlistName,
  String? image,
  BuildContext context,
) {
  final newPlaylistId = PlaylistUtils.generateCustomPlaylistId();
  final creationTime = DateTime.now().millisecondsSinceEpoch;
  final customPlaylist = {
    'ytid': newPlaylistId,
    'title': playlistName,
    'source': 'user-created',
    if (image != null) 'image': image,
    'list': [],
    'createdAt': creationTime,
  };
  userCustomPlaylists.value = [...userCustomPlaylists.value, customPlaylist];
  unawaited(
    addOrUpdateData<List>('user', 'customPlaylists', userCustomPlaylists.value),
  );
  return ('${context.l10n!.addedSuccess}!', newPlaylistId);
}

(String message, String playlistId) createCustomPlaylistWithSongs(
  String playlistName,
  List<Map> songs, {
  String? image,
}) {
  final newPlaylistId = PlaylistUtils.generateCustomPlaylistId();
  final creationTime = DateTime.now().millisecondsSinceEpoch;
  final customPlaylist = {
    'ytid': newPlaylistId,
    'title': playlistName,
    'source': 'user-created',
    if (image != null) 'image': image,
    'list': songs,
    'createdAt': creationTime,
  };
  userCustomPlaylists.value = [...userCustomPlaylists.value, customPlaylist];
  unawaited(
    addOrUpdateData<List>('user', 'customPlaylists', userCustomPlaylists.value),
  );
  return ('Playlist created', newPlaylistId);
}

String addSongInCustomPlaylist(
  BuildContext context,
  String playlistId,
  Map song, {
  int? indexToInsert,
}) {
  final found = _findCustomPlaylist(playlistId);
  final customPlaylist = found?.playlist;
  final isFromFolder = found?.isFromFolder ?? false;

  if (customPlaylist != null) {
    final List<dynamic> playlistSongs = customPlaylist['list'];
    if (playlistSongs.any(
      (playlistElement) => playlistElement['ytid'] == song['ytid'],
    )) {
      return context.l10n!.songAlreadyInPlaylist;
    }
    if (indexToInsert != null) {
      final safeIndex = indexToInsert.clamp(0, playlistSongs.length);
      playlistSongs.insert(safeIndex, song);
    } else {
      playlistSongs.add(song);
    }
    if (isFromFolder) {
      userPlaylistFolders.value = List<Map>.from(userPlaylistFolders.value);
      unawaited(
        addOrUpdateData<List>(
          'user',
          'playlistFolders',
          userPlaylistFolders.value,
        ),
      );
    } else {
      userCustomPlaylists.value = List<Map>.from(userCustomPlaylists.value);
      unawaited(
        addOrUpdateData<List>(
          'user',
          'customPlaylists',
          userCustomPlaylists.value,
        ),
      );
    }

    return context.l10n!.songAdded;
  } else {
    logger.log('Custom playlist not found for ytid: $playlistId');
    return context.l10n!.error;
  }
}

List<Map> getUserCustomPlaylists() {
  return [
    ...userCustomPlaylists.value
        .where((p) => p['source'] == 'user-created')
        .cast<Map>(),
    for (final folder in userPlaylistFolders.value)
      ...(folder['playlists'] as List<dynamic>? ?? [])
          .where((p) => p['source'] == 'user-created')
          .cast<Map>(),
  ];
}

String addSongsInCustomPlaylist(
  BuildContext context,
  String playlistId,
  List<dynamic> songs,
) {
  final found = _findCustomPlaylist(playlistId);
  final customPlaylist = found?.playlist;
  final isFromFolder = found?.isFromFolder ?? false;

  if (customPlaylist != null) {
    final List<dynamic> playlistSongs = customPlaylist['list'];

    final newSongs = <dynamic>[];
    for (final song in songs) {
      final alreadyExists = playlistSongs.any(
        (playlistElement) => playlistElement['ytid'] == song['ytid'],
      );
      if (!alreadyExists) {
        playlistSongs.add(song);
        newSongs.add(song);
      }
    }

    if (newSongs.isNotEmpty) {
      if (isFromFolder) {
        userPlaylistFolders.value = List<Map>.from(userPlaylistFolders.value);
        unawaited(
          addOrUpdateData<List>(
            'user',
            'playlistFolders',
            userPlaylistFolders.value,
          ),
        );
      } else {
        userCustomPlaylists.value = List<Map>.from(userCustomPlaylists.value);
        unawaited(
          addOrUpdateData<List>(
            'user',
            'customPlaylists',
            userCustomPlaylists.value,
          ),
        );
      }
      offlinePlaylistService.checkAndAutoMarkOffline(customPlaylist);
      return context.l10n!.addedSuccess;
    } else {
      return context.l10n!.songAlreadyInPlaylist;
    }
  } else {
    logger.log('Custom playlist not found for ytid: $playlistId');
    return context.l10n!.error;
  }
}

bool removeSongFromPlaylist(
  Map playlist,
  Map songToRemove, {
  int? removeOneAtIndex,
}) {
  try {
    if (playlist['list'] == null) return false;

    final playlistSongs = List<dynamic>.from(playlist['list']);
    if (removeOneAtIndex != null) {
      if (removeOneAtIndex < 0 || removeOneAtIndex >= playlistSongs.length) {
        return false;
      }
      playlistSongs.removeAt(removeOneAtIndex);
    } else {
      final initialLength = playlistSongs.length;
      playlistSongs.removeWhere((song) => song['ytid'] == songToRemove['ytid']);
      if (playlistSongs.length == initialLength) return false;
    }

    playlist['list'] = playlistSongs;

    try {
      if (playlist['source'] == 'user-created') {
        final playlistId = playlist['ytid']?.toString();
        final isInFolder =
            playlistId != null &&
            userPlaylistFolders.value.any((folder) {
              final folderPlaylists =
                  folder['playlists'] as List<dynamic>? ?? [];
              return folderPlaylists.any(
                (p) => p['ytid']?.toString() == playlistId,
              );
            });

        if (isInFolder) {
          userPlaylistFolders.value = List<Map>.from(userPlaylistFolders.value);
          unawaited(
            addOrUpdateData<List>(
              'user',
              'playlistFolders',
              userPlaylistFolders.value,
            ),
          );
        } else {
          userCustomPlaylists.value = List<Map>.from(userCustomPlaylists.value);
          unawaited(
            addOrUpdateData<List>(
              'user',
              'customPlaylists',
              userCustomPlaylists.value,
            ),
          );
        }
      } else {
        final playlistId = playlist['ytid']?.toString();

        final likedIndex = userLikedPlaylists.value.indexWhere(
          (p) => p['ytid']?.toString() == playlistId,
        );
        if (likedIndex != -1) {
          final updatedLiked = List<Map>.from(userLikedPlaylists.value);
          updatedLiked[likedIndex] = {
            ...updatedLiked[likedIndex],
            'list': playlistSongs,
          };
          userLikedPlaylists.value = updatedLiked;
          unawaited(
            addOrUpdateData<List>(
              'user',
              'likedPlaylists',
              userLikedPlaylists.value,
            ),
          );
        }

        if (playlistId != null && playlistId.isNotEmpty) {
          unawaited(
            addOrUpdateData<List>(
              'cache',
              'playlistSongs$playlistId',
              playlistSongs,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error saving playlist changes',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }

    return true;
  } catch (e, stackTrace) {
    logger.log(
      'Error while removing song from playlist: ',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

void removeUserPlaylist(String playlistId) {
  final normalizedId = playlistId.trim();
  if (normalizedId.isEmpty) return;

  final updatedPlaylists = List<String>.from(userPlaylists.value)
    ..removeWhere((id) => id == normalizedId);
  userPlaylists.value = updatedPlaylists;

  final foldersChanged = _removePlaylistFromFolders(normalizedId);
  final likedChanged = _removePlaylistFromLikedPlaylists(normalizedId);
  _unpinPlaylist(normalizedId);

  unawaited(addOrUpdateData<List>('user', 'playlists', userPlaylists.value));
  if (foldersChanged) {
    unawaited(
      addOrUpdateData<List>(
        'user',
        'playlistFolders',
        userPlaylistFolders.value,
      ),
    );
  }
  if (likedChanged) {
    unawaited(
      addOrUpdateData<List>('user', 'likedPlaylists', userLikedPlaylists.value),
    );
  }
}

void removeUserPlaylistEntry(Map playlist) {
  final playlistId = playlist['ytid']?.toString().trim() ?? '';
  if (playlistId.isEmpty) return;

  final source = playlist['source']?.toString();
  if (PlaylistUtils.isCustomPlaylist(playlist)) {
    removeUserCustomPlaylist(playlistId);
    return;
  }

  if (source == 'user-youtube') {
    removeUserPlaylist(playlistId);
    return;
  }

  final existsInCustom = userCustomPlaylists.value.any(
    (p) => p['ytid']?.toString() == playlistId,
  );

  if (existsInCustom) {
    removeUserCustomPlaylist(playlistId);
  } else {
    removeUserPlaylist(playlistId);
  }
}

void removeUserCustomPlaylist(dynamic playlist) {
  try {
    final playlistId = (playlist is Map ? playlist['ytid'] : playlist)
        ?.toString()
        .trim();
    if (playlistId == null || playlistId.isEmpty) return;

    final updatedPlaylists = List<Map>.from(userCustomPlaylists.value)
      ..removeWhere((p) => p['ytid']?.toString() == playlistId);
    userCustomPlaylists.value = updatedPlaylists;

    final foldersChanged = _removePlaylistFromFolders(playlistId);
    final likedChanged = _removePlaylistFromLikedPlaylists(playlistId);
    _unpinPlaylist(playlistId);

    unawaited(
      addOrUpdateData<List>(
        'user',
        'customPlaylists',
        userCustomPlaylists.value,
      ),
    );
    if (foldersChanged) {
      unawaited(
        addOrUpdateData<List>(
          'user',
          'playlistFolders',
          userPlaylistFolders.value,
        ),
      );
    }
    if (likedChanged) {
      unawaited(
        addOrUpdateData<List>(
          'user',
          'likedPlaylists',
          userLikedPlaylists.value,
        ),
      );
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error removing custom playlist',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

bool _removePlaylistFromFolders(String playlistId) {
  var changed = false;
  final updatedFolders = List<Map>.from(userPlaylistFolders.value);

  for (final folder in updatedFolders) {
    final folderPlaylists = List<Map>.from(folder['playlists'] ?? []);
    final previousLength = folderPlaylists.length;
    folderPlaylists.removeWhere(
      (playlist) => playlist['ytid']?.toString() == playlistId,
    );

    if (folderPlaylists.length != previousLength) {
      folder['playlists'] = folderPlaylists;
      changed = true;
    }
  }

  if (changed) {
    userPlaylistFolders.value = updatedFolders;
  }

  return changed;
}

bool _removePlaylistFromLikedPlaylists(String playlistId) {
  final updatedLikedPlaylists = _deduplicateLikedPlaylists(
    userLikedPlaylists.value,
  )..removeWhere((playlist) => playlist['ytid']?.toString() == playlistId);

  if (_likedPlaylistIdsAreEqual(
    userLikedPlaylists.value,
    updatedLikedPlaylists,
  )) {
    return false;
  }
  userLikedPlaylists.value = List<Map>.from(updatedLikedPlaylists);
  return true;
}

String createPlaylistFolder(String folderName, [BuildContext? context]) {
  if (folderName.trim().isEmpty) {
    return context?.l10n?.enterFolderName ?? 'Please enter a folder name';
  }

  final exists = userPlaylistFolders.value.any(
    (folder) =>
        folder['name'].toString().toLowerCase() ==
        folderName.trim().toLowerCase(),
  );

  if (exists) {
    return context?.l10n?.folderAlreadyExists ?? 'Folder already exists';
  }

  final newFolder = {
    'id': DateTime.now().millisecondsSinceEpoch.toString(),
    'name': folderName.trim(),
    'playlists': <Map>[],
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };

  userPlaylistFolders.value = [...userPlaylistFolders.value, newFolder];
  unawaited(
    addOrUpdateData<List>('user', 'playlistFolders', userPlaylistFolders.value),
  );
  return context?.l10n?.addedSuccess ?? 'Added successfully';
}

String renamePlaylistFolder(
  String folderId,
  String newName, [
  BuildContext? context,
]) {
  if (newName.trim().isEmpty) {
    return context?.l10n?.enterFolderName ?? 'Please enter a folder name';
  }

  final updatedFolders = List<Map>.from(userPlaylistFolders.value);
  final folderIndex = updatedFolders.indexWhere((f) => f['id'] == folderId);

  if (folderIndex == -1) {
    return context?.l10n?.error ?? 'Error';
  }

  final exists = updatedFolders.any(
    (folder) =>
        folder['id'] != folderId &&
        folder['name'].toString().toLowerCase() == newName.trim().toLowerCase(),
  );

  if (exists) {
    return context?.l10n?.folderAlreadyExists ?? 'Folder already exists';
  }

  updatedFolders[folderIndex]['name'] = newName.trim();
  userPlaylistFolders.value = updatedFolders;

  unawaited(
    addOrUpdateData<List>('user', 'playlistFolders', userPlaylistFolders.value),
  );
  return context?.l10n?.folderUpdated ?? 'Folder updated successfully';
}

String movePlaylistToFolder(
  Map playlist,
  String? folderId,
  BuildContext context,
) {
  try {
    final updatedFolders = List<Map>.from(userPlaylistFolders.value);
    final updatedCustomPlaylists = List<Map>.from(userCustomPlaylists.value);
    final updatedYoutubePlaylists = List<String>.from(userPlaylists.value);

    for (final folder in updatedFolders) {
      final folderPlaylists = List<Map>.from(
        folder['playlists'] ?? [],
      )..removeWhere((p) => p['ytid'] != null && p['ytid'] == playlist['ytid']);
      folder['playlists'] = folderPlaylists;
    }

    if (folderId != null) {
      final targetFolder = updatedFolders.firstWhere(
        (folder) => folder['id'] == folderId,
        orElse: () => {},
      );

      if (targetFolder.isNotEmpty) {
        final folderPlaylists = List<Map>.from(targetFolder['playlists'] ?? [])
          ..add(playlist);
        targetFolder['playlists'] = folderPlaylists;

        if (playlist['source'] == 'user-created') {
          updatedCustomPlaylists.removeWhere(
            (p) => p['ytid'] == playlist['ytid'],
          );
        } else if (playlist['source'] == 'user-youtube') {
          updatedYoutubePlaylists.removeWhere((p) => p == playlist['ytid']);
        }
      } else {
        logger.log(
          'Target folder with id $folderId not found for moving playlist',
        );
        return context.l10n!.error;
      }
    } else {
      if (playlist['source'] == 'user-created') {
        if (!updatedCustomPlaylists.any((p) => p['ytid'] == playlist['ytid'])) {
          updatedCustomPlaylists.add(playlist);
        }
      } else if (playlist['source'] == 'user-youtube') {
        if (!updatedYoutubePlaylists.contains(playlist['ytid'])) {
          updatedYoutubePlaylists.add(playlist['ytid']);
        }
      }
    }

    userPlaylistFolders.value = updatedFolders;
    userCustomPlaylists.value = updatedCustomPlaylists;
    userPlaylists.value = updatedYoutubePlaylists;

    unawaited(
      addOrUpdateData<List>(
        'user',
        'playlistFolders',
        userPlaylistFolders.value,
      ),
    );
    unawaited(
      addOrUpdateData<List>(
        'user',
        'customPlaylists',
        userCustomPlaylists.value,
      ),
    );
    unawaited(addOrUpdateData<List>('user', 'playlists', userPlaylists.value));

    return '${context.l10n!.addedSuccess}!';
  } catch (e, stackTrace) {
    logger.log(
      'Error moving playlist to folder',
      error: e,
      stackTrace: stackTrace,
    );
    return context.l10n!.error;
  }
}

String deletePlaylistFolder(String folderId, [BuildContext? context]) {
  try {
    final updatedFolders = List<Map>.from(userPlaylistFolders.value);
    final folderToDelete = updatedFolders.firstWhere(
      (folder) => folder['id'] == folderId,
      orElse: () => {},
    );

    if (folderToDelete.isNotEmpty) {
      final folderPlaylists = List<Map>.from(folderToDelete['playlists'] ?? []);
      final updatedCustomPlaylists = List<Map>.from(userCustomPlaylists.value);
      final updatedYoutubePlaylists = List<String>.from(userPlaylists.value);

      for (final playlist in folderPlaylists) {
        if (playlist['source'] == 'user-created') {
          if (playlist['ytid'] != null &&
              !updatedCustomPlaylists.any(
                (p) => p['ytid'] == playlist['ytid'],
              )) {
            updatedCustomPlaylists.add(playlist);
          }
        } else if (playlist['source'] == 'user-youtube') {
          if (playlist['ytid'] != null &&
              !updatedYoutubePlaylists.contains(playlist['ytid'])) {
            updatedYoutubePlaylists.add(playlist['ytid']);
          }
        }
      }

      updatedFolders.removeWhere((folder) => folder['id'] == folderId);

      userPlaylistFolders.value = updatedFolders;
      userCustomPlaylists.value = updatedCustomPlaylists;
      userPlaylists.value = updatedYoutubePlaylists;

      unawaited(
        addOrUpdateData<List>(
          'user',
          'playlistFolders',
          userPlaylistFolders.value,
        ),
      );
      unawaited(
        addOrUpdateData<List>(
          'user',
          'customPlaylists',
          userCustomPlaylists.value,
        ),
      );
      unawaited(
        addOrUpdateData<List>('user', 'playlists', userPlaylists.value),
      );

      return context?.l10n?.folderDeleted ?? 'Folder deleted successfully';
    }
    return context?.l10n?.error ?? 'Error';
  } catch (e, stackTrace) {
    logger.log(
      'Error deleting playlist folder',
      error: e,
      stackTrace: stackTrace,
    );
    return context?.l10n?.error ?? 'Error';
  }
}

List<Map> getPlaylistsInFolder(String folderId) {
  try {
    final folder = userPlaylistFolders.value.firstWhere(
      (folder) => folder['id'] == folderId,
      orElse: () => {},
    );
    return List<Map>.from(folder['playlists'] ?? []);
  } catch (e, stackTrace) {
    logger.log(
      'Error getting playlists in folder',
      error: e,
      stackTrace: stackTrace,
    );
    return [];
  }
}

List<Map> getPlaylistsNotInFolders() {
  final playlistsInFolders = <String>{};
  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    for (final playlist in folderPlaylists) {
      if (playlist['ytid'] != null) {
        playlistsInFolders.add(playlist['ytid']);
      }
    }
  }

  return userCustomPlaylists.value
      .where((playlist) {
        final playlistId = playlist['ytid'];
        return playlistId == null || !playlistsInFolders.contains(playlistId);
      })
      .toList()
      .cast<Map>();
}

Future<List> getPlaylists({
  String? query,
  int? playlistsNum,
  String type = 'all',
  bool forceRefresh = false,
}) async {
  if (playlistsNum == null && query == null) {
    logger.log('No playlists query or limit provided');
    return [];
  }

  if (query != null && playlistsNum == null) {
    final lowercaseQuery = query.toLowerCase();
    final filteredPlaylists = playlists.where((playlist) {
      final title = playlist['title'].toLowerCase();
      final matchesQuery = title.contains(lowercaseQuery);
      final matchesType =
          type == 'all' ||
          (type == 'album' && playlist['isAlbum'] == true) ||
          (type == 'playlist' && playlist['isAlbum'] != true);
      return matchesQuery && matchesType;
    }).toList();

    if (filteredPlaylists.isNotEmpty) {
      return filteredPlaylists;
    }

    if (type == 'album') {
      try {
        final albums = await ytMusicClient.music.searchAlbums(query);
        if (albums.isNotEmpty) return albums;
        final cleanQuery = formatSongTitle(query);
        if (cleanQuery.isNotEmpty &&
            cleanQuery.toLowerCase() != query.toLowerCase()) {
          final retryAlbums =
              await ytMusicClient.music.searchAlbums(cleanQuery);
          if (retryAlbums.isNotEmpty) return retryAlbums;
        }
      } catch (e, st) {
        logger.log(
          'Error in ytMusicClient.searchAlbums for "$query":',
          error: e,
          stackTrace: st,
        );
      }
      return [];
    } else if (type == 'playlist') {
      try {
        final ytmPlaylists = await ytMusicClient.music.searchPlaylists(query);
        if (ytmPlaylists.isNotEmpty) return ytmPlaylists;
        final cleanQuery = formatSongTitle(query);
        if (cleanQuery.isNotEmpty &&
            cleanQuery.toLowerCase() != query.toLowerCase()) {
          final retryPlaylists =
              await ytMusicClient.music.searchPlaylists(cleanQuery);
          if (retryPlaylists.isNotEmpty) return retryPlaylists;
        }
      } catch (e, st) {
        logger.log(
          'Error in ytMusicClient.searchPlaylists for "$query":',
          error: e,
          stackTrace: st,
        );
      }
      return [];
    }

    try {
      final ytmPlaylists = await ytMusicClient.music.searchPlaylists(query);
      if (ytmPlaylists.isNotEmpty) return ytmPlaylists;
    } catch (_) {}
    return [];
  }

  if (playlistsNum != null && query == null) {
    return getCommunityPlaylists(
      limit: playlistsNum,
      forceRefresh: forceRefresh,
    );
  }

  if (type != 'all') {
    return playlists.where((playlist) {
      return type == 'album'
          ? playlist['isAlbum'] == true
          : playlist['isAlbum'] != true;
    }).toList();
  }

  return playlists;
}

bool _isForbiddenVideoPlaylist(String title) {
  final lower = title.toLowerCase();
  return lower.contains('video song') ||
      lower.contains('video songs') ||
      lower.contains('1080p') ||
      lower.contains('4k') ||
      lower.contains('hd video') ||
      lower.contains('top weekly videos') ||
      lower.contains('mashup') ||
      lower.contains('status') ||
      lower.contains('whatsapp') ||
      lower.contains('full movie') ||
      lower.contains('short') ||
      lower.contains('reels');
}

Future<List<Map<String, dynamic>>> getCommunityPlaylists({
  int limit = 20,
  bool forceRefresh = false,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'ta';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;

  final cacheKey = 'ytm_home_from_the_community_v4_$prefLang';
  var livePlaylists = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        livePlaylists = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (livePlaylists.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Prioritize official YouTube Music community & featured playlists from category page
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final catCommunity = catShelves['communityPlaylists'] ?? const [];
        for (final pl in catCommunity) {
          final title = pl['title']?.toString() ?? '';
          if (_isForbiddenVideoPlaylist(title)) continue;
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          livePlaylists.add({
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
            'source': 'youtube-music-playlist',
          });
        }

        if (livePlaylists.length < limit) {
          final featured = catShelves['featuredPlaylists'] ?? const [];
          for (final pl in featured) {
            final title = pl['title']?.toString() ?? '';
            if (_isForbiddenVideoPlaylist(title)) continue;
            final rawThumb = pl['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            livePlaylists.add({
              ...pl,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
              'source': 'youtube-music-playlist',
            });
          }
        }

        // 2. Language community hit playlists directly from YouTube Music (filtered)
        if (livePlaylists.length < limit) {
          final searchPlaylists = await ytMusicClient.music
              .searchPlaylists('$prefLang hits playlist', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Map<String, dynamic>>[]);

          for (final pl in searchPlaylists) {
            final title = pl['title']?.toString() ?? '';
            if (_isForbiddenVideoPlaylist(title)) continue;
            final rawThumb = pl['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            livePlaylists.add({
              ...pl,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
              'source': 'youtube-music-playlist',
            });
          }
        }
      }

      // 3. Supplement with YouTube Music home feed playlists if needed
      if (livePlaylists.length < limit) {
        final homePlaylists = await ytMusicClient.music
            .getHomePlaylists(hl: rawLang, limit: limit)
            .timeout(const Duration(seconds: 8))
            .catchError((_) => <Map<String, dynamic>>[]);
        for (final pl in homePlaylists) {
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          livePlaylists.add({
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
          });
        }
      }

      // Deduplicate playlists by ytid
      final seenIds = <String>{};
      livePlaylists = livePlaylists.where((p) {
        final id = p['ytid']?.toString() ?? '';
        return id.isNotEmpty && seenIds.add(id);
      }).toList();

      if (livePlaylists.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, livePlaylists));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching dynamic YTM community playlists for $prefLang:',
        error: e,
        stackTrace: st,
      );
    }
  }

  if (livePlaylists.isNotEmpty) {
    for (final p in livePlaylists) {
      if (!playlists.any((item) => item['ytid'] == p['ytid'])) {
        playlists.add(p);
      }
    }
    return livePlaylists.take(limit).toList();
  }

  return const [];
}

Future<List<Map<String, dynamic>>> searchArtists(
  String query, {
  int limit = 5,
  bool verifiedOnly = true,
}) async {
  return searchVerifiedArtists(query, limit: limit);
}

const Map<String, String> artistLanguageCodeToName = {
  'ta': 'Tamil',
  'hi': 'Hindi',
  'te': 'Telugu',
  'ml': 'Malayalam',
  'kn': 'Kannada',
  'pa': 'Punjabi',
  'en': 'English',
  'mr': 'Marathi',
  'bn': 'Bengali',
  'gu': 'Gujarati',
  'ur': 'Urdu',
  'or': 'Odia',
  'as': 'Assamese',
  'sa': 'Sanskrit',
  'kok': 'Konkani',
};


Future<List<Map<String, dynamic>>> getSuggestedArtists({
  int limit = 20,
  bool forceRefresh = false,
}) async {
  var isOffline = false;
  try {
    isOffline = offlineMode.value;
  } catch (_) {}

  var likedArtists = <Map<String, dynamic>>[];
  try {
    likedArtists = getLikedArtistItems(offlineOnly: isOffline)
        .map(Map<String, dynamic>.from)
        .toList();
  } catch (_) {}

  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'ta';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;

  final cacheKey = 'dynamic_home_artists_v3_$prefLang';
  var liveArtists = <Map<String, dynamic>>[];

  if (!forceRefresh && !isOffline && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveArtists = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (liveArtists.isEmpty && !isOffline) {
    try {
      // 1. Fetch live Top Artists from YouTube Music Charts
      final chartsArtists = await ytMusicClient.music
          .getChartsArtists(hl: rawLang)
          .timeout(const Duration(seconds: 6))
          .catchError((_) => <Map<String, dynamic>>[]);

      for (final artist in chartsArtists) {
        final rawThumb = artist['image']?.toString();
        final highResThumb = rawThumb != null
            ? formatArtworkResolution(rawThumb, 512)
            : rawThumb;
        liveArtists.add({
          'ytid': artist['id'],
          'title': artist['name'],
          'image': highResThumb,
          'lowResImage': artist['image'],
          'highResImage': highResThumb,
          'subscribers': artist['subscribers'],
          'source': 'youtube-artist',
          'isArtist': true,
          'isVerifiedArtist': true,
        });
      }

      // 2. Also fetch top language verified artists to personalize for preferred language
      if (prefLang.toLowerCase() != 'english') {
        try {
          final langArtists = await ytMusicClient.music
              .searchArtists(prefLang)
              .timeout(const Duration(seconds: 5));

          for (final artist in langArtists) {
            final rawThumb = artist.thumbnailUrl;
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 512)
                : rawThumb;
            liveArtists.insert(0, {
              'ytid': artist.id,
              'title': artist.name,
              'image': highResThumb,
              'lowResImage': rawThumb,
              'highResImage': highResThumb,
              'source': 'youtube-artist',
              'isArtist': true,
              'isVerifiedArtist': true,
            });
          }
        } catch (_) {}
      }

      if (liveArtists.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveArtists));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching dynamic YTM artists for $prefLang:',
        error: e,
        stackTrace: st,
      );
    }
  }

  final combined = [
    ...likedArtists,
    ...liveArtists,
  ];

  final seenIds = <String>{};
  final seenTitles = <String>{};
  final result = <Map<String, dynamic>>[];

  for (final artist in combined) {
    final ytid = artist['ytid']?.toString() ?? '';
    final title = (artist['title']?.toString() ?? '').toLowerCase().trim();
    if (ytid.isNotEmpty && !seenIds.add(ytid)) continue;
    if (title.isNotEmpty && !seenTitles.add(title)) continue;
    result.add(artist);
    if (result.length >= limit) break;
  }

  return result;
}

/// Fetches and caches the complete category page shelves (Songs, Featured playlists, Community playlists, Albums)
/// directly from YouTube Music InnerTube (FEmusic_moods_and_genres_category).
Future<Map<String, List<Map<String, dynamic>>>> getLanguageCategoryShelves(
  String language, {
  bool forceRefresh = false,
}) async {
  final cleanLang = language.trim().toLowerCase();
  final cacheKey = 'ytm_cat_shelves_v2_$cleanLang';

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is Map && cached.isNotEmpty) {
        final res = <String, List<Map<String, dynamic>>>{};
        cached.forEach((k, v) {
          if (v is List) {
            res[k.toString()] =
                v.whereType<Map>().map(Map<String, dynamic>.from).toList();
          }
        });
        if ((res['songs']?.isNotEmpty ?? false) ||
            (res['featuredPlaylists']?.isNotEmpty ?? false) ||
            (res['communityPlaylists']?.isNotEmpty ?? false) ||
            (res['albums']?.isNotEmpty ?? false)) {
          return res;
        }
      }
    } catch (_) {}
  }

  try {
    final shelves = await ytMusicClient.music
        .getCategoryPageShelves(mood: language)
        .timeout(const Duration(seconds: 8));

    if ((shelves['songs']?.isNotEmpty ?? false) ||
        (shelves['featuredPlaylists']?.isNotEmpty ?? false) ||
        (shelves['communityPlaylists']?.isNotEmpty ?? false) ||
        (shelves['albums']?.isNotEmpty ?? false)) {
      if (Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, shelves));
      }
      return shelves;
    }
  } catch (e, st) {
    logger.log(
      'Error fetching category shelves for $language:',
      error: e,
      stackTrace: st,
    );
  }

  return const {};
}

Future<List<Map<String, dynamic>>> getSuggestedAlbumsAndSingles({
  int limit = 20,
  bool forceRefresh = false,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'ta';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;

  final cacheKey = 'dynamic_home_albums_v5_$prefLang';
  var liveAlbums = <Map<String, dynamic>>[];

  // 1. Try cache if not forcing refresh and cache box is open
  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveAlbums = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  // 2. Fetch live official new album releases from YouTube Music
  if (liveAlbums.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Prioritize official albums directly from YouTube Music category page
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final catAlbums = catShelves['albums'] ?? const [];
        for (final album in catAlbums) {
          final rawThumb = album['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          liveAlbums.add({
            ...album,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
          });
        }

        // 2. Supplement with language-specific new albums from YouTube Music search if needed
        if (liveAlbums.length < limit) {
          final langAlbums = await ytMusicClient.music
              .searchAlbums('$prefLang new albums', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Map<String, dynamic>>[]);

          for (final album in langAlbums) {
            final rawThumb = album['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            liveAlbums.add({
              ...album,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
            });
          }
        }

        // 2. Supplement with soundtrack / movie albums if space
        if (liveAlbums.length < limit) {
          final langSoundtracks = await ytMusicClient.music
              .searchAlbums('$prefLang soundtrack', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Map<String, dynamic>>[]);

          for (final album in langSoundtracks) {
            final rawThumb = album['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            liveAlbums.add({
              ...album,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
            });
          }
        }
      }

      // 3. Supplement with general YouTube Music new releases if needed
      if (liveAlbums.length < limit) {
        final ytmNewReleases = await ytMusicClient.music
            .getNewReleases(hl: rawLang, limit: limit)
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Map<String, dynamic>>[]);

        for (final album in ytmNewReleases) {
          final rawThumb = album['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          liveAlbums.add({
            ...album,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
          });
        }
      }

      // Deduplicate
      final seenIds = <String>{};
      liveAlbums = liveAlbums.where((a) {
        final id = a['ytid']?.toString() ?? '';
        return id.isNotEmpty && seenIds.add(id);
      }).toList();

      if (liveAlbums.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveAlbums));
      }
    } catch (e, stackTrace) {
      logger.log(
        'Dynamic albums fetch for $prefLang fallback to cache/local',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // 4. Return live albums
  if (liveAlbums.isNotEmpty) {
    return liveAlbums.take(limit).toList();
  }

  return const [];
}



Future<String?> fetchDynamicNewReleasesPlaylistId(String languageName) async {
  try {
    final yt = YoutubeHttpClient();
    final remixContext = {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': '1.20240101.01.00',
        'hl': 'en',
        'gl': 'IN',
      },
    };

    // 1. Discover language category dynamically from YouTube Music
    final moodsRes = await yt.sendPost('browse', {
      'context': remixContext,
      'browseId': 'FEmusic_moods_and_genres',
    }, validate: true).timeout(const Duration(seconds: 8));

    String? categoryParams;
    void findCategory(dynamic node) {
      if (categoryParams != null) return;
      if (node is Map && node.containsKey('musicNavigationButtonRenderer')) {
        final btn = node['musicNavigationButtonRenderer'];
        final text =
            btn['buttonText']?['runs']?[0]?['text']?.toString().toLowerCase() ?? '';
        if (text == languageName.toLowerCase()) {
          categoryParams = btn['clickCommand']?['browseEndpoint']?['params'];
        }
      }
      if (node is Map) {
        for (final v in node.values) findCategory(v);
      } else if (node is List) {
        for (final v in node) findCategory(v);
      }
    }
    findCategory(moodsRes);

    if (categoryParams != null) {
      final genreRes = await yt.sendPost('browse', {
        'context': remixContext,
        'browseId': 'FEmusic_moods_and_genres_category',
        'params': categoryParams,
      }, validate: true).timeout(const Duration(seconds: 8));

      String? newMusicBrowseId;
      void findNewMusic(dynamic node) {
        if (newMusicBrowseId != null) return;
        if (node is Map && node.containsKey('musicTwoRowItemRenderer')) {
          final item = node['musicTwoRowItemRenderer'];
          final title = (item['title']?['runs'] as List?)
                  ?.map((r) => r['text'])
                  .join()
                  .toLowerCase() ??
              '';
          if (title.contains('new music') || title.contains('hitlist')) {
            newMusicBrowseId =
                item['navigationEndpoint']?['browseEndpoint']?['browseId'];
          }
        }
        if (node is Map) {
          for (final v in node.values) findNewMusic(v);
        } else if (node is List) {
          for (final v in node) findNewMusic(v);
        }
      }
      findNewMusic(genreRes);

      final musicId = newMusicBrowseId;
      if (musicId != null) {
        return musicId.startsWith('VL') ? musicId.substring(2) : musicId;
      }
    }

    // 2. Fallback dynamically from YouTube Music FEmusic_new_releases
    final releasesRes = await yt.sendPost('browse', {
      'context': remixContext,
      'browseId': 'FEmusic_new_releases',
    }, validate: true).timeout(const Duration(seconds: 8));

    String? fallbackPlaylistId;
    void findFallback(dynamic node) {
      if (fallbackPlaylistId != null) return;
      if (node is Map && node.containsKey('musicTwoRowItemRenderer')) {
        final item = node['musicTwoRowItemRenderer'];
        final browseId =
            item['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString();
        if (browseId != null &&
            (browseId.startsWith('VLRDCL') || browseId.startsWith('RDCL'))) {
          fallbackPlaylistId = browseId;
        }
      }
      if (node is Map) {
        for (final v in node.values) findFallback(v);
      } else if (node is List) {
        for (final v in node) findFallback(v);
      }
    }
    findFallback(releasesRes);

    final fbId = fallbackPlaylistId;
    if (fbId != null) {
      return fbId.startsWith('VL') ? fbId.substring(2) : fbId;
    }
  } catch (_) {}
  return null;
}

Future<List<Map<String, dynamic>>> getSuggestedNewReleases({
  int limit = 20,
  bool forceRefresh = false,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'ta';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;

  final cacheKey = 'ytm_home_new_releases_v4_$prefLang';
  var liveSongs = <Map<String, dynamic>>[];

  // 1. Try cache if not forcing refresh and cache box is open
  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveSongs = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  // 2. Fetch fresh official new releases dynamically from YouTube Music Songs shelf
  if (liveSongs.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Prioritize official "New Music <Language>" from YouTube Music category page
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final featured = catShelves['featuredPlaylists'] ?? const [];
        final newMusicPl = featured.firstWhere(
          (pl) {
            final t = pl['title']?.toString().toLowerCase() ?? '';
            return t.contains('new music') || t.contains('latest');
          },
          orElse: () => <String, dynamic>{},
        );

        if (newMusicPl['ytid'] != null) {
          try {
            final plData = await ytMusicClient.music
                .getPlaylist(newMusicPl['ytid'].toString())
                .timeout(const Duration(seconds: 8));
            for (final (index, track) in plData.tracks.indexed) {
              liveSongs.add(returnSongLayout(index, track));
              if (liveSongs.length >= limit) break;
            }
          } catch (_) {}
        }

        // 2. Supplement with latest language audio songs from YouTube Music Songs shelf
        if (liveSongs.length < limit) {
          final latestSongs = await ytMusicClient.music
              .searchSongs('Latest $prefLang songs', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Video>[]);
          for (final (index, song) in latestSongs.indexed) {
            if (!liveSongs.any((s) => s['ytid'] == song.id.value)) {
              liveSongs.add(returnSongLayout(liveSongs.length + index, song));
            }
          }
        }

        // 3. Supplement with language new release audio tracks
        if (liveSongs.length < limit) {
          final releaseSongs = await ytMusicClient.music
              .searchSongs('$prefLang new releases', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Video>[]);
          for (final (index, song) in releaseSongs.indexed) {
            if (!liveSongs.any((s) => s['ytid'] == song.id.value)) {
              liveSongs.add(returnSongLayout(liveSongs.length + index, song));
            }
          }
        }
      }

      // 3. Supplement with global latest songs if needed
      if (liveSongs.length < limit) {
        final globalLatest = await ytMusicClient.music
            .searchSongs('Latest songs', limit: limit)
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Video>[]);
        for (final (index, song) in globalLatest.indexed) {
          if (!liveSongs.any((s) => s['ytid'] == song.id.value)) {
            liveSongs.add(returnSongLayout(liveSongs.length + index, song));
          }
        }
      }

      // Deduplicate
      final seenIds = <String>{};
      liveSongs = liveSongs.where((s) {
        final id = s['ytid']?.toString() ?? '';
        return id.isNotEmpty && seenIds.add(id);
      }).toList();

      if (liveSongs.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveSongs));
      }
    } catch (e, stackTrace) {
      logger.log(
        'Dynamic new releases fetch for $prefLang failed:',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // 3. Return fresh new releases
  if (liveSongs.isNotEmpty) {
    return liveSongs.take(limit).toList();
  }

  return const [];
}

const _moodKeywords = <String, List<String>>{
  'romance': ['romance', 'love', 'romantic', 'heartbreak'],
  'party': ['party', 'dance', 'kuthu', 'club', 'dj'],
  'workout': ['workout', 'energy', 'gym', 'motivat'],
  'chill': ['chill', 'dream', 'lounge', 'relax', 'peace', 'traffic'],
  'feel good': ['feel good', 'happy', 'road trip', 'sing-along'],
  'energy': ['energy', 'workout', 'kuthu', 'dance', 'hip hop', 'booster'],
  'focus': ['chill', 'lounge', 'dream', 'peace', 'instrumental'],
};

Future<List<Map<String, dynamic>>> getFeaturedMoodPlaylists({
  String mood = 'All',
  bool forceRefresh = false,
  int limit = 20,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'ta';

  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;
  final cleanMood = mood.trim().toLowerCase();
  final cacheKey = 'ytm_mood_playlists_v4_${cleanMood}_$prefLang';
  var livePlaylists = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        livePlaylists = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (livePlaylists.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Fetch the official category page shelves for the user's chosen language!
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final featuredPlaylists = catShelves['featuredPlaylists'] ?? const [];

        if (cleanMood == 'all' ||
            cleanMood == 'featured' ||
            cleanMood == prefLang.toLowerCase()) {
          // Show all official featured playlists of the language (e.g. Kollywood Hitlist, New Music Tamil, etc.)
          for (final pl in featuredPlaylists) {
            final title = pl['title']?.toString() ?? '';
            if (_isForbiddenVideoPlaylist(title)) continue;
            final rawThumb = pl['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            livePlaylists.add({
              ...pl,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
            });
          }
        } else {
          // Filter the language's official featured playlists matching this mood
          final keywords = _moodKeywords[cleanMood] ?? [cleanMood];
          for (final pl in featuredPlaylists) {
            final title = (pl['title']?.toString() ?? '').toLowerCase();
            if (keywords.any(title.contains)) {
              if (_isForbiddenVideoPlaylist(pl['title']?.toString() ?? '')) continue;
              final rawThumb = pl['image']?.toString();
              final highResThumb = rawThumb != null
                  ? formatArtworkResolution(rawThumb, 1080)
                  : rawThumb;
              livePlaylists.add({
                ...pl,
                if (highResThumb != null) 'image': highResThumb,
                if (highResThumb != null) 'highResImage': highResThumb,
              });
            }
          }

          // Supplement with language-specific mood playlist search
          if (livePlaylists.length < limit) {
            final langMoodPlaylists = await ytMusicClient.music
                .searchPlaylists('$prefLang $mood playlist', limit: limit)
                .timeout(const Duration(seconds: 6))
                .catchError((_) => <Map<String, dynamic>>[]);

            for (final pl in langMoodPlaylists) {
              final title = pl['title']?.toString() ?? '';
              if (_isForbiddenVideoPlaylist(title)) continue;
              if (livePlaylists.any((p) => p['ytid'] == pl['ytid'])) continue;
              final rawThumb = pl['image']?.toString();
              final highResThumb = rawThumb != null
                  ? formatArtworkResolution(rawThumb, 1080)
                  : rawThumb;
              livePlaylists.add({
                ...pl,
                if (highResThumb != null) 'image': highResThumb,
                if (highResThumb != null) 'highResImage': highResThumb,
              });
            }
          }
        }
      }

      // 2. Global mood category fallback (for English users or when language results empty)
      if (livePlaylists.isEmpty) {
        final moodShelves = await getLanguageCategoryShelves(
          cleanMood,
          forceRefresh: forceRefresh,
        );
        final officialMoodPlaylists =
            moodShelves['featuredPlaylists'] ?? const [];
        for (final pl in officialMoodPlaylists) {
          final title = pl['title']?.toString() ?? '';
          if (_isForbiddenVideoPlaylist(title)) continue;
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          livePlaylists.add({
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
          });
        }
      }

      if (livePlaylists.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, livePlaylists));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching YTM mood playlists for $mood in $prefLang:',
        error: e,
        stackTrace: st,
      );
    }
  }

  if (livePlaylists.isNotEmpty) {
    for (final p in livePlaylists) {
      if (!playlists.any((item) => item['ytid'] == p['ytid'])) {
        playlists.add(p);
      }
    }
    return livePlaylists.take(limit).toList();
  }

  return const [];
}

Future<List<Map<String, dynamic>>> getTrendingSongsForYou({
  bool forceRefresh = false,
  int limit = 20,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'ta';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;

  final cacheKey = 'ytm_pure_audio_trending_v5_$prefLang';
  var liveSongs = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveSongs = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (liveSongs.isEmpty) {
    try {
      // 1. Primary: YouTube Music Official Trending Songs (dedicated Songs search filter)
      final ytmTrending = await ytMusicClient.music
          .searchSongs('Trending $prefLang', limit: limit)
          .timeout(const Duration(seconds: 8))
          .catchError((_) => <Video>[]);

      for (final (index, song) in ytmTrending.indexed) {
        final songMap = returnSongLayout(index, song);
        songMap['chartRank'] = index + 1;
        liveSongs.add(songMap);
      }

      // 2. Supplement if needed with $prefLang Trending songs from YouTube Music
      if (liveSongs.length < limit) {
        final moreTrending = await ytMusicClient.music
            .searchSongs('$prefLang Trending', limit: limit)
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Video>[]);

        for (final song in moreTrending) {
          if (!liveSongs.any((s) => s['ytid'] == song.id.value)) {
            final songMap = returnSongLayout(liveSongs.length, song);
            songMap['chartRank'] = liveSongs.length + 1;
            liveSongs.add(songMap);
            if (liveSongs.length >= limit) break;
          }
        }
      }

      // 3. Fallback to YouTube Music category songs shelf if needed
      if (liveSongs.isEmpty && prefLang.toLowerCase() != 'english') {
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final catSongs = catShelves['songs'] ?? const [];
        for (final (index, s) in catSongs.indexed) {
          final ytid = s['ytid']?.toString() ?? '';
          if (ytid.isEmpty) continue;
          final rawThumb = s['image']?.toString();
          final highRes = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : null;
          final lowRes = rawThumb != null
              ? formatArtworkResolution(rawThumb, 544)
              : null;
          liveSongs.add({
            'id': index,
            'ytid': ytid,
            'title': formatSongTitle(s['title']?.toString() ?? ''),
            'artist': s['artist']?.toString() ?? '',
            'artistId': s['artistId']?.toString() ?? '',
            'videoAuthor': s['artist']?.toString() ?? '',
            'image': highRes ?? 'https://i.ytimg.com/vi/$ytid/maxresdefault.jpg',
            'lowResImage': lowRes ?? 'https://i.ytimg.com/vi/$ytid/mqdefault.jpg',
            'highResImage': highRes ?? 'https://i.ytimg.com/vi/$ytid/maxresdefault.jpg',
            'duration': s['duration'],
            'chartRank': index + 1,
            'isLive': false,
            'source': 'youtube-music',
          });
        }
      }

      // 4. Global YouTube Music Trending fallback
      if (liveSongs.isEmpty) {
        final globalTrending = await ytMusicClient.music
            .searchSongs('Trending songs', limit: limit)
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Video>[]);

        for (final (index, song) in globalTrending.indexed) {
          final songMap = returnSongLayout(index, song);
          songMap['chartRank'] = index + 1;
          liveSongs.add(songMap);
        }
      }

      // Deduplicate
      final seenIds = <String>{};
      liveSongs = liveSongs.where((s) {
        final id = s['ytid']?.toString() ?? '';
        return id.isNotEmpty && seenIds.add(id);
      }).toList();

      if (liveSongs.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveSongs));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching trending songs for $prefLang:',
        error: e,
        stackTrace: st,
      );
    }
  }

  return liveSongs.take(limit).toList();
}

Future<List<Map<String, dynamic>>> getQuickPicksSongs({
  bool forceRefresh = false,
  int limit = 16,
}) async {
  const cacheKey = 'ytm_quick_picks_songs_v1';
  var liveSongs = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveSongs = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (liveSongs.isEmpty) {
    try {
      // Find seed song from recent songs or user liked songs
      String? seedId;
      if (Hive.isBoxOpen('user')) {
        try {
          final box = Hive.box('user');
          final recents = box.get('recentSongs', defaultValue: <dynamic>[]);
          if (recents is List && recents.isNotEmpty) {
            for (final item in recents.reversed) {
              if (item is Map &&
                  item['ytid'] != null &&
                  item['ytid'].toString().length == 11) {
                seedId = item['ytid'].toString();
                break;
              }
            }
          }

          if (seedId == null || seedId.isEmpty) {
            final liked = box.get('likedSongs', defaultValue: <dynamic>[]);
            if (liked is List && liked.isNotEmpty) {
              final lastLiked = liked.last;
              if (lastLiked is Map &&
                  lastLiked['ytid'] != null &&
                  lastLiked['ytid'].toString().length == 11) {
                seedId = lastLiked['ytid'].toString();
              }
            }
          }
        } catch (_) {}
      }

      // If still null, fetch top trending song as seed
      if (seedId == null || seedId.isEmpty) {
        final trending = await getTrendingSongsForYou(limit: 5);
        if (trending.isNotEmpty && trending.first['ytid'] != null) {
          seedId = trending.first['ytid'].toString();
        }
      }

      if (seedId != null && seedId.isNotEmpty) {
        final radioTracks = await ytMusicClient.music
            .getRadioSongs(seedId, limit: limit)
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Video>[]);

        for (var i = 0; i < radioTracks.length; i++) {
          final track = radioTracks[i];
          final layout = returnSongLayout(i, track);
          liveSongs.add(layout);
        }
      }

      // Fallback: if radio returned fewer, supplement with trending songs
      if (liveSongs.length < 8) {
        final trending = await getTrendingSongsForYou(
          forceRefresh: forceRefresh,
          limit: limit,
        );
        for (final s in trending) {
          if (!liveSongs.any((x) => x['ytid'] == s['ytid'])) {
            liveSongs.add(Map<String, dynamic>.from(s));
          }
          if (liveSongs.length >= limit) break;
        }
      }

      if (liveSongs.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveSongs));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching quick picks songs:',
        error: e,
        stackTrace: st,
      );
    }
  }

  return liveSongs.take(limit).toList();
}

Future<List<Map<String, dynamic>>> getTrendingCommunityPlaylists({
  bool forceRefresh = false,
  int limit = 20,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'ta';

  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;
  final cacheKey = 'ytm_trending_community_playlists_v3_$prefLang';
  var livePlaylists = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        livePlaylists = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (livePlaylists.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Prioritize exact community playlists directly from YouTube Music category page
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final catCommunity = catShelves['communityPlaylists'] ?? const [];
        for (final pl in catCommunity) {
          final title = pl['title']?.toString() ?? '';
          if (_isForbiddenVideoPlaylist(title)) continue;
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          livePlaylists.add({
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
            'source': 'youtube-music-playlist',
          });
        }

        // 2. Supplement with official curated category playlists (e.g. Kollywood Hitlist) if space
        if (livePlaylists.length < limit) {
          final featured = catShelves['featuredPlaylists'] ?? const [];
          for (final pl in featured) {
            final title = pl['title']?.toString() ?? '';
            if (_isForbiddenVideoPlaylist(title)) continue;
            final rawThumb = pl['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            livePlaylists.add({
              ...pl,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
              'source': 'youtube-music-playlist',
            });
          }
        }

        // 3. Supplement with language trending playlists directly from YouTube Music if needed
        if (livePlaylists.length < limit) {
          final langPlaylists = await ytMusicClient.music
              .searchPlaylists('$prefLang trending playlist', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Map<String, dynamic>>[]);

          for (final pl in langPlaylists) {
            final title = pl['title']?.toString() ?? '';
            if (_isForbiddenVideoPlaylist(title)) continue;
            final rawThumb = pl['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            livePlaylists.add({
              ...pl,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
              'source': 'youtube-music-playlist',
            });
          }
        }
      }

      // 3. Supplement with home feed playlists if needed
      if (livePlaylists.length < limit) {
        final homePlaylists = await ytMusicClient.music
            .getHomePlaylists(hl: rawLang, limit: limit)
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Map<String, dynamic>>[]);

        for (final pl in homePlaylists) {
          final title = pl['title']?.toString() ?? '';
          if (_isForbiddenVideoPlaylist(title)) continue;
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          livePlaylists.add({
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
            'source': 'youtube-music-playlist',
          });
        }
      }

      if (livePlaylists.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, livePlaylists));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching trending community playlists:',
        error: e,
        stackTrace: st,
      );
    }
  }

  if (livePlaylists.isNotEmpty) {
    for (final p in livePlaylists) {
      if (!playlists.any((item) => item['ytid'] == p['ytid'])) {
        playlists.add(p);
      }
    }
    return livePlaylists.take(limit).toList();
  }

  return const [];
}

Future<List<dynamic>> getUserPlaylistsNotInFolders() async {
  final playlistsInFolders = <String>{};
  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    for (final playlist in folderPlaylists) {
      if (playlist['ytid'] != null && playlist['source'] == 'user-youtube') {
        playlistsInFolders.add(playlist['ytid']);
      }
    }
  }

  final allUserPlaylists = await getUserPlaylists();
  return allUserPlaylists.where((playlist) {
    return !playlistsInFolders.contains(playlist['ytid']);
  }).toList();
}

bool playlistExistsAnywhere(String playlistId) {
  final normalizedId = playlistId.trim();
  if (normalizedId.isEmpty) return false;

  if (userPlaylists.value.any((id) => id == normalizedId)) {
    return true;
  }

  if (userCustomPlaylists.value.any(
    (p) => p['ytid']?.toString() == normalizedId,
  )) {
    return true;
  }

  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    if (folderPlaylists.any((p) => p['ytid']?.toString() == normalizedId)) {
      return true;
    }
  }

  return false;
}

int findPlaylistIndexByYtId(String ytid) {
  for (var i = 0; i < playlists.length; i++) {
    if (playlists[i]['ytid'] == ytid) {
      return i;
    }
  }
  return -1;
}

Future<Map?> getPlaylistInfoForWidget(
  dynamic id, {
  bool isArtist = false,
  String? artistName,
  String? artistImage,
  String? sourceSongId,
  String? sourceVideoAuthor,
  bool preferredVerified = false,
  bool forceRefresh = false,
}) async {
  if (id == null) return null;
  final normalizedId = id.toString().trim();
  if (normalizedId.isEmpty || normalizedId == 'null') return null;
  if (isArtist) {
    final offlineArtist = _findOfflinePlaylist(normalizedId);
    if (offlineArtist != null && (!forceRefresh || offlineMode.value)) {
      return offlineArtist;
    }
    if (offlineMode.value) return null;

    return getArtistCatalog(
      normalizedId,
      preferredName: artistName,
      preferredImage: artistImage,
      sourceSongId: sourceSongId,
      sourceVideoAuthor: sourceVideoAuthor,
      forceRefresh: forceRefresh,
      preferredVerified: preferredVerified,
    );
  }
  if (normalizedId.startsWith('customId-')) {
    return _findCustomPlaylist(normalizedId)?.playlist;
  }

  final offlinePlaylist = _findOfflinePlaylist(normalizedId);
  if (offlinePlaylist != null) return offlinePlaylist;

  return _fetchYouTubePlaylist(normalizedId);
}

Future<Map<String, dynamic>?> resolveArtistInfoForWidget(
  dynamic id, {
  String? artistName,
  String? artistImage,
  String? sourceSongId,
  String? sourceVideoAuthor,
  bool preferredVerified = false,
}) async {
  if (id == null) return null;
  final normalizedId = id.toString().trim();
  if (normalizedId.isEmpty || normalizedId == 'null') return null;

  final offlineArtist = _findOfflinePlaylist(normalizedId);
  if (offlineArtist != null) {
    return Map<String, dynamic>.from(offlineArtist);
  }
  if (offlineMode.value) return null;

  final artist = await resolveArtist(
    normalizedId,
    preferredName: artistName,
    preferredImage: artistImage,
    sourceSongId: sourceSongId,
    sourceVideoAuthor: sourceVideoAuthor,
    preferredVerified: preferredVerified,
  );

  if (artist == null) {
    logger.log(
      'No official artist channel found for "$normalizedId"'
      '${artistName == null ? '' : ' ($artistName)'}',
    );
    return null;
  }

  return {...artist, 'source': 'youtube-artist', 'isArtist': true, 'list': []};
}

({Map playlist, bool isFromFolder})? _findCustomPlaylist(String playlistId) {
  for (final playlist in userCustomPlaylists.value) {
    if (playlist['ytid'] == playlistId) {
      return (playlist: playlist, isFromFolder: false);
    }
  }
  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    for (final playlist in folderPlaylists) {
      if (playlist['ytid'] == playlistId) {
        return (playlist: playlist as Map, isFromFolder: true);
      }
    }
  }
  return null;
}

Map? _findOfflinePlaylist(String id) {
  return _findPlaylistById(offlinePlaylistService.offlinePlaylists.value, id);
}

Map? _findPlaylistById(Iterable<dynamic> playlists, String id) {
  for (final playlist in playlists) {
    if (playlist is Map && playlist['ytid']?.toString() == id) {
      return playlist;
    }
  }

  return null;
}

Future<Map?> _fetchYouTubePlaylist(String id) async {
  // 1. Local DB / in-memory caches (no network).
  var playlist = _findPlaylistById(playlists, id);

  // 2. User-added YouTube playlists.
  if (playlist == null) {
    final userPlaylists = await getUserPlaylists();
    playlist = _findPlaylistById(userPlaylists, id);
  }

  // 3. Previously fetched online playlists.
  playlist ??= _findPlaylistById(onlinePlaylists.value, id);

  // 4. Fetch from YouTube as a last resort.
  if (playlist == null) {
    try {
      final strId = id.trim();
      if (strId.startsWith('MPREb_')) {
        final album = await ytMusicClient.music.getAlbum(strId);
        final albumThumb = album.thumbnailUrl != null
            ? formatArtworkResolution(album.thumbnailUrl!, 1080)
            : null;
        playlist = {
          'ytid': album.id,
          'title': album.title,
          'artist': album.artist,
          'year': album.year,
          'image': albumThumb,
          'lowResImage': album.thumbnailUrl,
          'highResImage': albumThumb,
          'isAlbum': true,
          'source': 'youtube-music-album',
          'list': album.tracks
              .map((t) => returnSongLayout(0, t, playlistImage: albumThumb))
              .toList(),
        };
      } else if (id.length == 11) {
        var officialTrack = await ytMusicClient.music.getSong(id);
        officialTrack ??= await ytMusicClient.music.searchSong(id);
        if (officialTrack != null) {
          final layout = returnSongLayout(0, officialTrack);
          final thumb = layout['highResImage']?.toString() ??
              layout['image']?.toString();

          playlist = {
            'ytid': officialTrack.id.value,
            'title': layout['title'],
            'artist': layout['artist'],
            'image': thumb,
            'lowResImage': layout['lowResImage'],
            'highResImage': thumb,
            'isSingle': true,
            'isAlbum': true,
            'list': [layout],
          };
        }
      } else {
        final cleanId = strId.startsWith('VL') ? strId.substring(2) : strId;
        try {
          final musicPlaylist = await ytMusicClient.music
              .getPlaylist(cleanId)
              .timeout(const Duration(seconds: 10));
          final plThumb = musicPlaylist.thumbnailUrl != null
              ? formatArtworkResolution(musicPlaylist.thumbnailUrl!, 1080)
              : null;
          playlist = {
            'ytid': musicPlaylist.id,
            'title': musicPlaylist.title,
            'artist': musicPlaylist.author,
            'image': plThumb,
            'lowResImage': musicPlaylist.thumbnailUrl,
            'highResImage': plThumb,
            'source': 'youtube-music-playlist',
            'list': musicPlaylist.tracks
                .map(
                  (t) => returnSongLayout(
                    0,
                    t,
                  ),
                )
                .toList(),
          };
        } catch (_) {
          playlist = {
            'ytid': cleanId,
            'title': 'Playlist',
            'image': null,
            'source': 'youtube-music-playlist',
            'list': [],
          };
        }
      }
      _updateOnlineCache(playlist);
    } catch (e, stackTrace) {
      logger.log(
        'Failed to fetch playlist info for id $id',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  if (playlist == null) return null;

  // 6. Populate the song list if it is absent or empty.
  final list = playlist['list'];
  if (list == null || (list is List && list.isEmpty)) {
    playlist['list'] = await _loadSongsForPlaylist(playlist);
  }

  return playlist;
}

Future<List> _loadSongsForPlaylist(Map playlist) async {
  try {
    final ytid = playlist['ytid']?.toString() ?? '';
    if (ytid.startsWith('MPREb_')) {
      if (playlist['list'] is List && (playlist['list'] as List).isNotEmpty) {
        return playlist['list'] as List;
      }
      final album = await ytMusicClient.music.getAlbum(ytid);
      return album.tracks
          .map((t) => returnSongLayout(0, t, playlistImage: album.thumbnailUrl))
          .toList();
    }
    if (playlist['isSingle'] == true || ytid.length == 11) {
      if (playlist['list'] is List && (playlist['list'] as List).isNotEmpty) {
        return playlist['list'] as List;
      }
      var officialTrack = await ytMusicClient.music.getSong(ytid);
      officialTrack ??= await ytMusicClient.music.searchSong(ytid);
      if (officialTrack != null) {
        final thumb = playlist['image']?.toString() ??
            (officialTrack.musicData.isNotEmpty
                ? officialTrack.musicData.first.image?.toString()
                : null);
        return [returnSongLayout(0, officialTrack, playlistImage: thumb)];
      }
      return [];
    }

    final cleanYtid = ytid.startsWith('VL') ? ytid.substring(2) : ytid;
    final playlistImage = playlist['isAlbum'] == true
        ? playlist['image'] as String?
        : null;
    final songs = await getSongsFromPlaylist(
      cleanYtid,
      playlistImage: playlistImage,
    );
    if (!playlists.contains(playlist)) {
      playlists.add(playlist);
    }
    return songs;
  } catch (e, stackTrace) {
    logger.log(
      'Error fetching songs for playlist ${playlist['ytid']}',
      error: e,
      stackTrace: stackTrace,
    );
    return [];
  }
}

Future<List> getSongsFromPlaylist(
  dynamic playlistId, {
  String? playlistImage,
}) async {
  final cleanId = playlistId.toString().trim().startsWith('VL')
      ? playlistId.toString().trim().substring(2)
      : playlistId.toString().trim();
  final cacheKey = 'ytm_playlistSongs_v2_$cleanId';
  final cached = await getData('cache', cacheKey);
  if (cached is List && cached.isNotEmpty) {
    return cached;
  }

  final songList = <Map<String, dynamic>>[];

  // 1. YouTube Music first (official releases, high-res audio, clean album covers)
  try {
    final musicPlaylist = await ytMusicClient.music
        .getPlaylist(cleanId)
        .timeout(const Duration(seconds: 10));
    if (musicPlaylist.tracks.isNotEmpty) {
      for (final track in musicPlaylist.tracks) {
        songList.add(
          returnSongLayout(
            songList.length,
            track,
            playlistImage: playlistImage,
          ),
        );
      }
      unawaited(
        addOrUpdateData<List>('cache', cacheKey, songList),
      );
      return songList;
    }
  } catch (e, st) {
    logger.log(
      'Error fetching YTM songs for playlist $cleanId:',
      error: e,
      stackTrace: st,
    );
  }

  // 2. Legacy cache fallback if available
  final legacyCache = await getData('cache', 'playlistSongs$cleanId');
  if (legacyCache is List && legacyCache.isNotEmpty) {
    return legacyCache;
  }

  return songList;
}

Future updatePlaylistList(BuildContext context, String playlistId) async {
  final index = findPlaylistIndexByYtId(playlistId);
  if (index == -1) {
    logger.log('Playlist with id $playlistId not found for update');
    return null;
  }

  try {
    final cleanId = playlistId.startsWith('VL')
        ? playlistId.substring(2)
        : playlistId;
    final songList = <Map<String, dynamic>>[];

    try {
      final musicPlaylist = await ytMusicClient.music
          .getPlaylist(cleanId)
          .timeout(const Duration(seconds: 10));
      if (musicPlaylist.tracks.isNotEmpty) {
        for (final track in musicPlaylist.tracks) {
          songList.add(
            returnSongLayout(
              songList.length,
              track,
            ),
          );
        }
      }
    } catch (_) {}

    playlists[index]['list'] = songList;
    unawaited(
      addOrUpdateData<List>('cache', 'ytm_playlistSongs_v2_$cleanId', songList),
    );
    showToast(context, context.l10n!.playlistUpdated);
    return playlists[index];
  } catch (e, stackTrace) {
    logger.log(
      'Error updating playlist list for $playlistId',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<void> renameSongInPlaylist(
  dynamic playlistId,
  dynamic songId,
  String newTitle,
  String newArtist,
) async {
  try {
    final found = _findCustomPlaylist(playlistId.toString());
    final playlist = found?.playlist;
    final isFromFolder = found?.isFromFolder ?? false;

    if (playlist != null && playlist['list'] != null) {
      final songIndex = (playlist['list'] as List).indexWhere(
        (song) => song['ytid'] == songId,
      );

      if (songIndex != -1) {
        final updatedSongs = List<dynamic>.from(playlist['list'] as List);
        updatedSongs[songIndex] =
            Map<String, dynamic>.from(updatedSongs[songIndex] as Map)
              ..['title'] = newTitle
              ..['artist'] = newArtist;

        playlist['list'] = updatedSongs;

        if (isFromFolder) {
          userPlaylistFolders.value = List<Map>.from(userPlaylistFolders.value);
          unawaited(
            addOrUpdateData<List>(
              'user',
              'playlistFolders',
              userPlaylistFolders.value,
            ),
          );
        } else {
          final updatedPlaylists = userCustomPlaylists.value
              .map((p) => p['ytid'] == playlistId ? playlist : p)
              .toList();
          userCustomPlaylists.value = updatedPlaylists;
          unawaited(
            addOrUpdateData<List>('user', 'customPlaylists', updatedPlaylists),
          );
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error renaming song in playlist',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<void> updatePlaylistLikeStatus(
  String playlistId,
  bool add, {
  Map? playlistData,
}) async {
  try {
    final normalizedPlaylistId = playlistId.trim();
    if (normalizedPlaylistId.isEmpty || normalizedPlaylistId == 'null') return;

    final updateToken = ++_playlistLikeUpdateToken;
    _latestPlaylistLikeUpdateTokens[normalizedPlaylistId] = updateToken;

    final playlistToAdd = add
        ? await _resolvePlaylistForLikedStatus(
            normalizedPlaylistId,
            playlistData,
          )
        : null;

    if (_latestPlaylistLikeUpdateTokens[normalizedPlaylistId] != updateToken) {
      return;
    }

    final updatedLikedPlaylists = _deduplicateLikedPlaylists(
      userLikedPlaylists.value,
    );

    if (add) {
      if (playlistToAdd != null &&
          !updatedLikedPlaylists.any((playlist) {
            final id =
                playlist['ytid']?.toString() ?? playlist['id']?.toString();
            return id == normalizedPlaylistId;
          })) {
        updatedLikedPlaylists.add(playlistToAdd);
      }
    } else {
      updatedLikedPlaylists.removeWhere((playlist) {
        final id =
            playlist['ytid']?.toString() ?? playlist['id']?.toString();
        return id == normalizedPlaylistId;
      });
    }

    if (_likedPlaylistIdsAreEqual(
      userLikedPlaylists.value,
      updatedLikedPlaylists,
    )) {
      return;
    }

    userLikedPlaylists.value = List<Map>.from(updatedLikedPlaylists);
    unawaited(
      addOrUpdateData<List>('user', 'likedPlaylists', userLikedPlaylists.value),
    );
  } catch (e, stackTrace) {
    logger.log(
      'Error updating playlist like status: ',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

List<Map> _deduplicateLikedPlaylists(Iterable<Map> likedPlaylists) {
  final seenPlaylistIds = <String>{};
  final deduplicatedPlaylists = <Map>[];

  for (final playlist in likedPlaylists) {
    final playlistId =
        playlist['ytid']?.toString() ?? playlist['id']?.toString();
    if (playlistId == null || playlistId.isEmpty) {
      deduplicatedPlaylists.add(playlist);
      continue;
    }

    if (seenPlaylistIds.add(playlistId)) {
      deduplicatedPlaylists.add(playlist);
    }
  }

  return deduplicatedPlaylists;
}

bool _likedPlaylistIdsAreEqual(List<Map> previous, List<Map> updated) {
  if (previous.length != updated.length) return false;

  for (var i = 0; i < previous.length; i++) {
    final prevId =
        previous[i]['ytid']?.toString() ?? previous[i]['id']?.toString();
    final updatedId =
        updated[i]['ytid']?.toString() ?? updated[i]['id']?.toString();
    if (prevId != updatedId) {
      return false;
    }
  }

  return true;
}

Future<Map?> _resolvePlaylistForLikedStatus(
  String playlistId,
  Map? playlistData,
) async {
  if (playlistData != null) {
    final pYtid = playlistData['ytid']?.toString();
    final pId = playlistData['id']?.toString();
    if (pYtid == playlistId || pId == playlistId) {
      final map = Map<String, dynamic>.from(playlistData);
      map['ytid'] ??= playlistId;
      return map;
    }
  }

  final cachedPlaylist = _searchAppPlaylistsById(playlistId);
  if (cachedPlaylist != null) {
    return Map<String, dynamic>.from(cachedPlaylist);
  }

  for (final p in userCustomPlaylists.value) {
    final id = p['ytid']?.toString() ?? p['id']?.toString();
    if (id == playlistId) {
      final map = Map<String, dynamic>.from(p);
      map['ytid'] ??= playlistId;
      return map;
    }
  }

  try {
    final playlistInfo = await getPlaylistInfoForWidget(playlistId);
    if (playlistInfo != null) {
      return Map<String, dynamic>.from(playlistInfo);
    }
  } catch (_) {}

  if (playlistData != null) {
    final map = Map<String, dynamic>.from(playlistData);
    map['ytid'] ??= playlistId;
    return map;
  }

  return null;
}

bool isPlaylistPinned(String playlistId) =>
    pinnedPlaylistIds.value.contains(playlistId);

bool togglePinnedPlaylist(String playlistId, BuildContext context) {
  final current = List<String>.from(pinnedPlaylistIds.value);
  if (current.contains(playlistId)) {
    current.remove(playlistId);
    pinnedPlaylistIds.value = current;
    unawaited(addOrUpdateData<List>('user', 'pinnedPlaylistIds', current));
    return false;
  }
  if (current.length >= pinnedPlaylistsLimit) {
    return false;
  }
  current.add(playlistId);
  pinnedPlaylistIds.value = current;
  unawaited(addOrUpdateData<List>('user', 'pinnedPlaylistIds', current));
  return true;
}

void _unpinPlaylist(String playlistId) {
  if (!pinnedPlaylistIds.value.contains(playlistId)) return;
  final updated = List<String>.from(pinnedPlaylistIds.value)
    ..remove(playlistId);
  pinnedPlaylistIds.value = updated;
  unawaited(addOrUpdateData<List>('user', 'pinnedPlaylistIds', updated));
}

/// Updates the offline playlist metadata (title, image, source) when a custom
/// playlist is renamed or modified. This ensures the offline playlist section
/// in the library displays the updated information.
Future<void> syncOfflinePlaylistMetadata(Map updatedPlaylist) async {
  final playlistId = updatedPlaylist['ytid']?.toString();
  if (playlistId == null ||
      !offlinePlaylistService.isPlaylistDownloaded(playlistId)) {
    return;
  }

  final offlinePlaylists = List<dynamic>.from(
    offlinePlaylistService.offlinePlaylists.value,
  );
  final offlineIndex = offlinePlaylists.indexWhere(
    (p) => p['ytid']?.toString() == playlistId,
  );

  if (offlineIndex == -1) return;

  // Update the offline playlist with the new metadata
  offlinePlaylists[offlineIndex] = {
    ...offlinePlaylists[offlineIndex],
    'title': updatedPlaylist['title'],
    'image': updatedPlaylist['image'],
    'source': updatedPlaylist['source'],
  };

  // Create a new list to trigger ValueNotifier listeners
  offlinePlaylistService.offlinePlaylists.value = List<dynamic>.from(
    offlinePlaylists,
  );
  unawaited(
    addOrUpdateData<List>('userNoBackup', 'offlinePlaylists', offlinePlaylists),
  );
}

/// Generates a language-aware, region-aware, and mood-aware cache key for Home Feed.
/// Ensures different music content languages never share or collide with each other's cache entries.
String getHomeFeedCacheKey({
  String? contentLanguage,
  String? region,
  String? mood,
}) {
  final lang = contentLanguage ?? contentLanguagePreference ?? 'ta';
  final reg = region ?? 'IN';
  final m = (mood == null || mood.trim().isEmpty) ? 'All' : mood.trim();
  return 'ytm_home_feed_v7_${lang}_${reg}_$m';
}

/// Fetches the unified dynamic Home Feed.
///
/// Integrates YouTube Music InnerTube `FEmusic_home` shelves (similar to ytmusicapi `get_home()`),
/// caches results in Hive (`ytm_home_feed_v7`), and includes fallback mechanisms to guarantee a rich
/// feed even during network degradation.
Future<List<HomeSection>> getUnifiedHomeFeed({
  bool forceRefresh = false,
  String? mood,
}) async {
  final cacheKey = getHomeFeedCacheKey(mood: mood);
  HomeSection? moodSection;

  final cacheStopwatch = Stopwatch()..start();
  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey, cachingDuration: homeFeedCacheDuration);
      if (homeCacheMs == null && appStartupStopwatch.isRunning) {
        homeCacheMs = cacheStopwatch.elapsedMilliseconds;
        checkAndLogColdStartPerf();
      }
      if (cached is List && cached.isNotEmpty) {
        final cachedSections = <HomeSection>[];
        for (final item in cached) {
          if (item is Map) {
            cachedSections.add(HomeSection.fromJson(item));
          }
        }
        if (cachedSections.isNotEmpty) {
          logger.log('[HOME_FEED] cache hit key=$cacheKey sections=${cachedSections.length}');

          // Blend cached remote sections with fresh local personalization
          final personalizedSections = PersonalizationService.instance
              .buildPersonalizedSections(mood: mood);

          final composedSections = HomeFeedComposer.compose(
            remoteSections: cachedSections,
            moodSection: moodSection,
            personalizedSections: personalizedSections,
          );

          logger.log(HomeFeedComposer.formatHomeOrder(composedSections));
          return composedSections;
        }
      }
    } catch (_) {}
  }

  // 1. If a specific mood is selected (other than 'All'), fetch featured playlists for that mood
  if (mood != null && mood.isNotEmpty && mood != 'All' && !offlineMode.value) {
    try {
      final moodPlaylists = await getFeaturedMoodPlaylists(
        mood: mood,
        forceRefresh: forceRefresh,
      );
      if (moodPlaylists.isNotEmpty) {
        moodSection = HomeSection(
          title: '$mood playlists',
          subtitle: 'Featured for your mood',
          type: HomeContentType.playlists,
          contents: moodPlaylists,
        );
      }
    } catch (_) {}
  }

  final sections = <HomeSection>[];

  // 2. Fetch dynamic shelves from YouTube Music (FEmusic_home)
  // Always use hl: 'en' so that shelf topics/headers are always in clean English
  // rather than being translated/transliterated into Tamil script by YouTube.
  if (!offlineMode.value) {
    try {
      final remoteShelves = await ytMusicClient.music
          .getHomeFeed(hl: 'en', gl: 'IN')
          .timeout(const Duration(seconds: 8));

      logger.log('[HOME_FEED] shelves=${remoteShelves.length}');

      for (final shelf in remoteShelves) {
        if (shelf.isNotEmpty) {
          logger.log(
            '[HOME_SECTION] source=remote title="${shelf.title}" type=${shelf.type.name} items=${shelf.contents.length}',
          );
          sections.add(shelf);
        }
      }
    } catch (e, st) {
      logger.log('Error fetching dynamic home feed from InnerTube:', error: e, stackTrace: st);
    }
  }

  // 3. Fallback / Resilience: Only trigger when network/API fails or zero valid shelves returned.
  // If remote feed is valid but small (1 or 2 shelves), render it without forcing fallback.
  if (sections.isEmpty && !offlineMode.value) {
    logger.log('[HOME_FEED] using fallback recommendation sections');
    try {
      // Add Quick Picks if not present
      if (!sections.any((s) => s.title.toLowerCase().contains('quick picks'))) {
        final quickPicks = await getQuickPicksSongs(forceRefresh: forceRefresh);
        if (quickPicks.isNotEmpty) {
          sections.insert(
            0,
            HomeSection(
              title: 'Quick picks',
              subtitle: 'START RADIO FROM A SONG',
              type: HomeContentType.songs,
              contents: quickPicks,
              isChunkedSongs: true,
            ),
          );
        }
      }

      // Add Trending songs if not present
      if (!sections.any((s) => s.title.toLowerCase().contains('trending'))) {
        final trending = await getTrendingSongsForYou(forceRefresh: forceRefresh);
        if (trending.isNotEmpty) {
          sections.add(
            HomeSection(
              title: 'Trending songs for you',
              subtitle: 'POPULAR NOW',
              type: HomeContentType.songs,
              contents: trending,
            ),
          );
        }
      }

      // Add New releases if not present
      if (!sections.any((s) => s.title.toLowerCase().contains('new release'))) {
        final newReleases = await getSuggestedNewReleases(forceRefresh: forceRefresh);
        if (newReleases.isNotEmpty) {
          sections.add(
            HomeSection(
              title: 'New releases',
              subtitle: 'FRESH TRACKS & VIDEOS',
              type: HomeContentType.songs,
              contents: newReleases,
            ),
          );
        }
      }

      // Add Albums if not present
      if (!sections.any((s) => s.title.toLowerCase().contains('album'))) {
        final albums = await getSuggestedAlbumsAndSingles(forceRefresh: forceRefresh);
        if (albums.isNotEmpty) {
          sections.add(
            HomeSection(
              title: 'Albums for you',
              subtitle: 'RECOMMENDED ALBUMS',
              type: HomeContentType.albums,
              contents: albums,
            ),
          );
        }
      }

      // Add Artists if not present
      if (!sections.any((s) => s.title.toLowerCase().contains('artist'))) {
        final artists = await getSuggestedArtists(forceRefresh: forceRefresh);
        if (artists.isNotEmpty) {
          sections.add(
            HomeSection(
              title: 'Artists for you',
              subtitle: 'TOP VERIFIED ARTISTS',
              type: HomeContentType.artists,
              contents: artists,
            ),
          );
        }
      }

      // Add Community playlists
      if (!sections.any((s) => s.title.toLowerCase().contains('community'))) {
        final community = await getTrendingCommunityPlaylists(forceRefresh: forceRefresh);
        if (community.isNotEmpty) {
          sections.add(
            HomeSection(
              title: 'Trending community playlists',
              subtitle: 'DISCOVERED PLAYLISTS',
              type: HomeContentType.playlists,
              contents: community,
            ),
          );
        }
      }
    } catch (_) {}
  }

  // 4. Generate fresh local personalization
  final personalizedSections = PersonalizationService.instance
      .buildPersonalizedSections(mood: mood);

  // 5. Compose final ordered feed through HomeFeedComposer
  final composedSections = HomeFeedComposer.compose(
    remoteSections: sections,
    moodSection: moodSection,
    personalizedSections: personalizedSections,
  );

  logger.log(HomeFeedComposer.formatHomeOrder(composedSections));

  // 6. Cache valid remote sections in Hive (NOT the personalized composition)
  if (sections.isNotEmpty && Hive.isBoxOpen('cache')) {
    final serialized = sections.map((s) => s.toJson()).toList();
    unawaited(addOrUpdateData('cache', cacheKey, serialized));
  }

  return composedSections;
}

/// Backwards compatibility alias for [getUnifiedHomeFeed].
Future<List<HomeSection>> getDynamicHomeFeed({
  bool forceRefresh = false,
  String? mood,
}) =>
    getUnifiedHomeFeed(forceRefresh: forceRefresh, mood: mood);


