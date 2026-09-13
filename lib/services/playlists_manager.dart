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

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart' show logger;
import 'package:catchify/services/artist_service.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/playlist_download_service.dart';
import 'package:catchify/services/proxy_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/formatter.dart';
import 'package:catchify/utilities/playlist_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
      final plist = await ytClient.playlists.get(playlistID);
      return {
        'ytid': plist.id.toString(),
        'title': plist.title,
        'image': null,
        'source': 'user-youtube',
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
        'source': 'user-youtube',
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
      return '${context.l10n?.notYTlist ?? 'Not a YouTube playlist'}!';
    }
  }

  try {
    if (playlistExistsAnywhere(playlistId)) {
      return '${context.l10n?.playlistAlreadyExists ?? 'Playlist already exists'}!';
    }

    final playlist = await ytClient.playlists.get(playlistId);
    if (playlist.title.isEmpty) {
      return '${context.l10n?.invalidYouTubePlaylist ?? 'Invalid YouTube playlist'}!';
    }

    userPlaylists.value = [...userPlaylists.value, playlistId];
    unawaited(addOrUpdateData<List>('user', 'playlists', userPlaylists.value));
    return '${context.l10n?.addedSuccess ?? 'Successfully added'}!';
  } catch (e, stackTrace) {
    logger.log('Error adding user playlist', error: e, stackTrace: stackTrace);
    return '${context.l10n?.error ?? 'Error'}: $e';
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
  return ('${context.l10n?.addedSuccess ?? 'Successfully added'}!', newPlaylistId);
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
      return context.l10n?.songAlreadyInPlaylist ?? 'Song already in playlist';
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

    return context.l10n?.songAdded ?? 'Song added';
  } else {
    logger.log('Custom playlist not found for ytid: $playlistId');
    return context.l10n?.error ?? 'Error';
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
      return context.l10n?.addedSuccess ?? 'Successfully added';
    } else {
      return context.l10n?.songAlreadyInPlaylist ?? 'Song already in playlist';
    }
  } else {
    logger.log('Custom playlist not found for ytid: $playlistId');
    return context.l10n?.error ?? 'Error';
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
        return context.l10n?.error ?? 'Error';
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

    return '${context.l10n?.addedSuccess ?? 'Successfully added'}!';
  } catch (e, stackTrace) {
    logger.log(
      'Error moving playlist to folder',
      error: e,
      stackTrace: stackTrace,
    );
    return context.l10n?.error ?? 'Error';
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
    }

    final searchTerm = type == 'album' ? '$query album' : query;

    late final Iterable searchResultsIterable;
    try {
      searchResultsIterable = await ytClient.search.searchContent(
        searchTerm,
        filter: TypeFilters.playlist,
      );
    } catch (e, st) {
      logger.log(
        'Error while searching online songs:',
        error: e,
        stackTrace: st,
      );
      if (useProxy.value) {
        final proxyYt = await ProxyManager().getYoutubeExplodeClient();
        if (proxyYt != null) {
          try {
            searchResultsIterable = await proxyYt.search.searchContent(
              searchTerm,
              filter: TypeFilters.playlist,
            );
          } catch (e2, st2) {
            logger.log('Proxy search failed:', error: e2, stackTrace: st2);
            searchResultsIterable = <dynamic>[];
          } finally {
            try {
              proxyYt.close();
            } catch (_) {}
          }
        } else {
          searchResultsIterable = <dynamic>[];
        }
      } else {
        searchResultsIterable = <dynamic>[];
      }
    }

    final newPlaylists = searchResultsIterable
        .whereType<SearchPlaylist>()
        .map((playlist) {
          final playlistMap = {
            'ytid': playlist.id.toString(),
            'title': playlist.title,
            'image': playlist.thumbnails.first.url.toString(),
            'source': 'youtube',
            'list': [],
            'isAlbum': type == 'album',
          };
          return playlistMap;
        })
        .toList();

    return newPlaylists;
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

  final cacheKey = 'ytm_home_from_the_community_$prefLang';
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
      final searchQuery = prefLang.toLowerCase() == 'english'
          ? 'community playlists'
          : '$prefLang playlist';
      final ytmPlaylists = await ytMusicClient.music
          .searchPlaylists(searchQuery, limit: limit)
          .timeout(const Duration(seconds: 8));
      if (ytmPlaylists.isNotEmpty) {
        livePlaylists = ytmPlaylists.map((pl) {
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          return {
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
          };
        }).toList();
        if (Hive.isBoxOpen('cache')) {
          unawaited(addOrUpdateData('cache', cacheKey, livePlaylists));
        }
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
    if (Hive.isBoxOpen('cache')) {
      unawaited(addOrUpdateData('cache', cacheKey, livePlaylists));
    }
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

  final cacheKey = 'dynamic_home_artists_$prefLang';
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
      final ytmArtists = await ytMusicClient.music
          .searchArtists(prefLang)
          .timeout(const Duration(seconds: 8));
      if (ytmArtists.isNotEmpty) {
        liveArtists = ytmArtists.map((artist) {
          return {
            'ytid': artist.id,
            'title': artist.name,
            'image': artist.thumbnailUrl,
            'source': 'youtube-artist',
            'isArtist': true,
            'isVerifiedArtist': true,
          };
        }).toList();

        if (Hive.isBoxOpen('cache')) {
          unawaited(addOrUpdateData('cache', cacheKey, liveArtists));
        }
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

  final cacheKey = 'dynamic_home_albums_$prefLang';
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

  // 2. If no cache or forceRefresh requested, fetch dynamically from YouTube Music
  if (liveAlbums.isEmpty) {
    try {
      final searchQuery = prefLang.toLowerCase() == 'english'
          ? 'new albums'
          : '$prefLang new albums';
      final ytmAlbums = await ytMusicClient.music
          .searchAlbums(searchQuery, limit: limit)
          .timeout(const Duration(seconds: 8));

      if (ytmAlbums.isNotEmpty) {
        final currentYear = DateTime.now().year;
        final recentAlbums = ytmAlbums.where((album) {
          final year = int.tryParse(album['year']?.toString() ?? '');
          return year == null || year >= currentYear - 1;
        }).toList();

        final rawAlbums = (recentAlbums.isNotEmpty ? recentAlbums : ytmAlbums)
            .take(limit)
            .toList();
        liveAlbums = rawAlbums.map((album) {
          final rawThumb = album['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          return {
            ...album,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
          };
        }).toList();
        if (Hive.isBoxOpen('cache')) {
          unawaited(addOrUpdateData('cache', cacheKey, liveAlbums));
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Dynamic albums fetch for $prefLang fallback to cache/local',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // 3. Fallback: fetch official singles / new releases dynamically from YouTube Music songs search
  if (liveAlbums.isEmpty) {
    try {
      final query = prefLang.toLowerCase() == 'english'
          ? 'latest hits'
          : '$prefLang latest songs';
      final songs = await ytMusicClient.music
          .searchSongs(query, limit: limit)
          .timeout(const Duration(seconds: 8));
      if (songs.isNotEmpty) {
        liveAlbums = [
          for (final (index, song) in songs.indexed)
            () {
              final layout = returnSongLayout(0, song);
              final thumb = layout['highResImage']?.toString() ??
                  layout['image']?.toString();
              return {
                'id': index,
                'ytid': song.id.value,
                'title': layout['title'],
                'artist': layout['artist'],
                'image': thumb,
                'lowResImage': layout['lowResImage'],
                'highResImage': thumb,
                'language': prefLang,
                'isSingle': true,
                'isAlbum': true,
                'list': [layout],
              };
            }(),
        ];
        if (Hive.isBoxOpen('cache')) {
          unawaited(addOrUpdateData('cache', cacheKey, liveAlbums));
        }
      }
    } catch (_) {}
  }

  // 4. Return live albums (strictly no static database mixing)
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

  final cacheKey = 'ytm_home_new_releases_v2_$prefLang';
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

  // 2. Fetch fresh official new releases dynamically from YouTube Music
  if (liveSongs.isEmpty) {
    try {
      final dynamicPlaylistId =
          await fetchDynamicNewReleasesPlaylistId(prefLang);
      if (dynamicPlaylistId != null && dynamicPlaylistId.isNotEmpty) {
        final officialPlaylist = await ytMusicClient.music
            .getPlaylist(dynamicPlaylistId)
            .timeout(const Duration(seconds: 8));

        if (officialPlaylist.tracks.isNotEmpty) {
          liveSongs = [
            for (final (index, song)
                in officialPlaylist.tracks.take(limit).indexed)
              returnSongLayout(
                index,
                song,
              ),
          ];

          if (Hive.isBoxOpen('cache')) {
            unawaited(addOrUpdateData('cache', cacheKey, liveSongs));
          }
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Dynamic new releases fetch from official YTM playlist for $prefLang failed:',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // 3. Fallback dynamically to global new releases from YouTube Music browse
  if (liveSongs.isEmpty) {
    try {
      final globalId = await fetchDynamicNewReleasesPlaylistId('English');
      if (globalId != null && globalId.isNotEmpty) {
        final globalPlaylist = await ytMusicClient.music
            .getPlaylist(globalId)
            .timeout(const Duration(seconds: 8));
        if (globalPlaylist.tracks.isNotEmpty) {
          liveSongs = [
            for (final (index, song)
                in globalPlaylist.tracks.take(limit).indexed)
              returnSongLayout(
                index,
                song,
              ),
          ];
          if (Hive.isBoxOpen('cache')) {
            unawaited(addOrUpdateData('cache', cacheKey, liveSongs));
          }
        }
      }
    } catch (_) {}
  }

  // 4. Return ONLY fresh new releases (strictly no mixing with old database tracks)
  if (liveSongs.isNotEmpty) {
    return liveSongs.take(limit).toList();
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
        final video = await ytClient.videos.get(id);
        var officialTrack = video;
        if (video.musicData.isEmpty) {
          try {
            final cleanTitle = formatSongTitle(video.title);
            final officialList = await ytMusicClient.music
                .searchSongs('$cleanTitle ${video.author}', limit: 3)
                .timeout(const Duration(seconds: 5));
            if (officialList.isNotEmpty) {
              officialTrack = officialList.first;
            }
          } catch (_) {}
        }
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
          final ytPlaylist = await ytClient.playlists.get(cleanId);
          playlist = {
            'ytid': ytPlaylist.id.toString(),
            'title': ytPlaylist.title,
            'image': ytPlaylist.thumbnails.mediumResUrl,
            'source': 'user-youtube',
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
      final video = await ytClient.videos.get(ytid);
      var officialTrack = video;
      if (video.musicData.isEmpty) {
        try {
          final cleanTitle = formatSongTitle(video.title);
          final officialList = await ytMusicClient.music
              .searchSongs('$cleanTitle ${video.author}', limit: 3)
              .timeout(const Duration(seconds: 5));
          if (officialList.isNotEmpty) {
            officialTrack = officialList.first;
          }
        } catch (_) {}
      }
      final thumb = playlist['image']?.toString() ??
          (officialTrack.musicData.isNotEmpty
              ? officialTrack.musicData.first.image?.toString()
              : null);
      return [returnSongLayout(0, officialTrack, playlistImage: thumb)];
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

  // 3. Fallback to standard YouTube Explode
  try {
    await for (final song in ytClient.playlists.getVideos(cleanId)) {
      songList.add(
        returnSongLayout(songList.length, song, playlistImage: playlistImage),
      );
    }
    if (songList.isNotEmpty) {
      unawaited(
        addOrUpdateData<List>('cache', cacheKey, songList),
      );
    }
  } catch (e, st) {
    logger.log(
      'Error fetching standard YouTube songs for playlist $cleanId:',
      error: e,
      stackTrace: st,
    );
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

    if (songList.isEmpty) {
      await for (final song in ytClient.playlists.getVideos(cleanId)) {
        songList.add(returnSongLayout(songList.length, song));
      }
    }

    playlists[index]['list'] = songList;
    unawaited(
      addOrUpdateData<List>('cache', 'ytm_playlistSongs_v2_$cleanId', songList),
    );
    showToast(context, context.l10n?.playlistUpdated ?? 'Playlist updated');
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
