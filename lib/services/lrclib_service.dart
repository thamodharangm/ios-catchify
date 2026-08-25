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

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model class for LrcLib API track response
class Track {
  Track({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.instrumental,
    this.plainLyrics,
    this.syncedLyrics,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as int? ?? 0,
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      albumName: json['albumName'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      instrumental: json['instrumental'] as bool? ?? false,
      plainLyrics: json['plainLyrics'] as String?,
      syncedLyrics: json['syncedLyrics'] as String?,
    );
  }

  final int id;
  final String trackName;
  final String artistName;
  final String albumName;
  final int duration;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;
}

/// Service to interact with LrcLib API (https://lrclib.net)
class LrcLibService {
  static const String _baseUrl = 'https://lrclib.net/api/search';

  // Common title cleanup patterns
  static final List<RegExp> _titleCleanupPatterns = [
    RegExp(r'\s*\(.*?(?:official|audio|video|lyrics|lyric|feat|ft|remix|hd|4k|from).*?\)', caseSensitive: false),
    RegExp(r'\s*\[.*?(?:official|audio|video|lyrics|lyric|feat|ft|remix|hd|4k|from).*?\]', caseSensitive: false),
    RegExp(r'\s*-\s*(?:official|audio|video|lyrics|lyric|hd|4k|music video|lyric video|video song).*$', caseSensitive: false),
    RegExp(r'\s*(?:official video|music video|lyric video|video song|audio song|full video|lyrical video)', caseSensitive: false),
  ];

  // Common artist separation patterns
  static final List<String> _artistSeparators = [' feat.', ' ft.', ' feat', ' ft', ' & ', ', ', ' x '];

  /// Clean the title for better search results
  static String _cleanTitle(String title) {
    var cleaned = title.trim();
    if (cleaned.contains('|')) {
      cleaned = cleaned.split('|').first.trim();
    }
    for (final pattern in _titleCleanupPatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    return cleaned.trim();
  }

  /// Extract primary artist from the given string
  static String _cleanArtist(String artist) {
    var cleaned = artist.trim();
    for (final separator in _artistSeparators) {
      final idx = cleaned.toLowerCase().indexOf(separator.toLowerCase());
      if (idx != -1) {
        cleaned = cleaned.substring(0, idx);
        break;
      }
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*topic$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'vevo$', caseSensitive: false), '');
    return cleaned.trim();
  }

  /// Query LrcLib API with specific parameters
  static Future<List<Track>> _queryLyricsWithParams({
    String? trackName,
    String? artistName,
    String? albumName,
    String? query,
  }) async {
    try {
      final uri = Uri.parse(_baseUrl);
      final queryParams = <String, String>{};

      if (query != null && query.trim().isNotEmpty) queryParams['q'] = query.trim();
      if (trackName != null && trackName.trim().isNotEmpty) queryParams['track_name'] = trackName.trim();
      if (artistName != null && artistName.trim().isNotEmpty) queryParams['artist_name'] = artistName.trim();
      if (albumName != null && albumName.trim().isNotEmpty) queryParams['album_name'] = albumName.trim();

      final uriWithQuery = uri.replace(queryParameters: queryParams);
      final response = await http
          .get(uriWithQuery)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);

        late List<dynamic> jsonList;
        if (jsonData is List) {
          jsonList = jsonData;
        } else if (jsonData is Map && jsonData['tracks'] != null) {
          jsonList = jsonData['tracks'];
        } else if (jsonData is Map) {
          jsonList = [jsonData];
        } else {
          jsonList = [];
        }

        return jsonList
            .whereType<Map<String, dynamic>>()
            .map(Track.fromJson)
            .toList();
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  /// Query LrcLib for lyrics using multiple fallback strategies
  static Future<List<Track>> _queryLyrics({
    required String artist,
    required String title,
    String? album,
  }) async {
    final cleanedTitle = _cleanTitle(title);
    final cleanedArtist = _cleanArtist(artist);

    // Strategy 1: Combined search query (most flexible for search index)
    if (cleanedTitle.isNotEmpty && cleanedArtist.isNotEmpty) {
      final results = (await _queryLyricsWithParams(query: '$cleanedTitle $cleanedArtist'))
          .where((track) => track.syncedLyrics != null || track.plainLyrics != null)
          .toList();
      if (results.isNotEmpty) return results;
    }

    // Strategy 2: Exact track and artist params
    if (cleanedTitle.isNotEmpty && cleanedArtist.isNotEmpty) {
      final results = (await _queryLyricsWithParams(
        trackName: cleanedTitle,
        artistName: cleanedArtist,
        albumName: album,
      )).where((track) => track.syncedLyrics != null || track.plainLyrics != null).toList();
      if (results.isNotEmpty) return results;
    }

    // Strategy 3: Cleaned title search
    if (cleanedTitle.isNotEmpty) {
      final results = (await _queryLyricsWithParams(query: cleanedTitle))
          .where((track) => track.syncedLyrics != null || track.plainLyrics != null)
          .toList();
      if (results.isNotEmpty) return results;
    }

    // Strategy 4: If title has "Movie - Song" (e.g. "Leo - Naa Ready"), extract song part
    if (cleanedTitle.contains(' - ')) {
      final parts = cleanedTitle.split(' - ');
      if (parts.length >= 2) {
        final songName = parts[1].trim();
        if (songName.isNotEmpty) {
          final results = (await _queryLyricsWithParams(query: songName))
              .where((track) => track.syncedLyrics != null || track.plainLyrics != null)
              .toList();
          if (results.isNotEmpty) return results;
        }
      }
    }

    // Strategy 5: Raw title search fallback
    if (cleanedTitle != title.trim()) {
      final results = (await _queryLyricsWithParams(query: title.trim()))
          .where((track) => track.syncedLyrics != null || track.plainLyrics != null)
          .toList();
      if (results.isNotEmpty) return results;
    }

    return [];
  }

  /// Fetch lyrics for a song - returns synced lyrics if available, otherwise plain lyrics
  static Future<String?> getLyrics({
    required String title,
    required String artist,
    int duration = -1,
    String? album,
  }) async {
    try {
      final tracks = await _queryLyrics(
        artist: artist,
        title: title,
        album: album,
      );

      if (tracks.isEmpty) {
        return null;
      }

      // Prioritize tracks with synced lyrics
      final syncedTracks = tracks.where((t) => t.syncedLyrics != null && t.syncedLyrics!.isNotEmpty).toList();
      if (syncedTracks.isNotEmpty) {
        return syncedTracks.first.syncedLyrics;
      }

      final plainTracks = tracks.where((t) => t.plainLyrics != null && t.plainLyrics!.isNotEmpty).toList();
      if (plainTracks.isNotEmpty) {
        return plainTracks.first.plainLyrics;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
