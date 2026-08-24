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
    RegExp(r'\s*\(.*?(?:official|audio|video|lyrics|feat|ft|remix|hd|4k).*?\)', caseSensitive: false),
    RegExp(r'\s*\[.*?(?:official|audio|video|lyrics|feat|ft|remix|hd|4k).*?\]', caseSensitive: false),
    RegExp(r'\s*-\s*(?:official|audio|video|lyrics|hd|4k).*$', caseSensitive: false),
    RegExp(r'\s*\|\s*.*$', caseSensitive: false),
  ];

  // Common artist separation patterns
  static final List<String> _artistSeparators = [' feat.', ' ft.', ' feat', ' ft', ' & ', ', ', ' x '];

  /// Clean the title for better search results
  static String _cleanTitle(String title) {
    var cleaned = title.trim();
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

      if (query != null) queryParams['q'] = query;
      if (trackName != null) queryParams['track_name'] = trackName;
      if (artistName != null) queryParams['artist_name'] = artistName;
      if (albumName != null) queryParams['album_name'] = albumName;

      final uriWithQuery = uri.replace(queryParameters: queryParams);
      final response = await http
          .get(uriWithQuery)
          .timeout(const Duration(seconds: 10));

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

  /// Query LrcLib for lyrics using multiple strategies
  static Future<List<Track>> _queryLyrics({
    required String artist,
    required String title,
    String? album,
  }) async {
    final cleanedTitle = _cleanTitle(title);
    final cleanedArtist = _cleanArtist(artist);

    var results = (await _queryLyricsWithParams(
      trackName: cleanedTitle,
      artistName: cleanedArtist,
      albumName: album,
    )).where((track) => track.syncedLyrics != null || track.plainLyrics != null).toList();

    if (results.isNotEmpty) return results;

    results = (await _queryLyricsWithParams(trackName: cleanedTitle))
        .where((track) => track.syncedLyrics != null || track.plainLyrics != null)
        .toList();

    if (results.isNotEmpty) return results;

    results = (await _queryLyricsWithParams(query: '$cleanedArtist $cleanedTitle'))
        .where((track) => track.syncedLyrics != null || track.plainLyrics != null)
        .toList();

    if (results.isNotEmpty) return results;

    results = (await _queryLyricsWithParams(query: cleanedTitle))
        .where((track) => track.syncedLyrics != null || track.plainLyrics != null)
        .toList();

    if (results.isNotEmpty) return results;

    if (cleanedTitle != title.trim()) {
      results = (await _queryLyricsWithParams(
        trackName: title.trim(),
        artistName: artist.trim(),
      )).where((track) => track.syncedLyrics != null || track.plainLyrics != null).toList();

      if (results.isNotEmpty) return results;
    }

    return results;
  }

  static double _calculateStringSimilarity(String str1, String str2) {
    final s1 = str1.trim().toLowerCase();
    final s2 = str2.trim().toLowerCase();

    if (s1 == s2) return 1;
    if (s1.isEmpty || s2.isEmpty) return 0;
    if (s1.contains(s2) || s2.contains(s1)) return 0.8;

    final maxLength = s1.length > s2.length ? s1.length : s2.length;
    final distance = _levenshteinDistance(s1, s2);
    return 1.0 - (distance / maxLength);
  }

  static int _levenshteinDistance(String s1, String s2) {
    final matrix = List<List<int>>.generate(
      s1.length + 1,
      (i) => List<int>.filled(s2.length + 1, 0),
    );

    for (var i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= s1.length; i++) {
      for (var j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        final deletion = matrix[i - 1][j] + 1;
        final insertion = matrix[i][j - 1] + 1;
        final substitution = matrix[i - 1][j - 1] + cost;
        matrix[i][j] = [
          deletion,
          insertion,
          substitution,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
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

      final cleanedTitle = _cleanTitle(title);
      final cleanedArtist = _cleanArtist(artist);

      Track? bestMatch;

      if (duration == -1) {
        bestMatch = tracks.isEmpty
            ? null
            : tracks.reduce((best, current) {
                var bestScore = 0.0;
                if (best.syncedLyrics != null) bestScore += 1.0;
                bestScore += (_calculateStringSimilarity(cleanedTitle, best.trackName) +
                        _calculateStringSimilarity(cleanedArtist, best.artistName)) /
                    2.0;

                var currentScore = 0.0;
                if (current.syncedLyrics != null) currentScore += 1.0;
                currentScore += (_calculateStringSimilarity(cleanedTitle, current.trackName) +
                        _calculateStringSimilarity(cleanedArtist, current.artistName)) /
                    2.0;

                return bestScore >= currentScore ? best : current;
              });
      } else {
        bestMatch = tracks.isEmpty
            ? null
            : tracks.reduce((best, current) {
                final bestDiff = (best.duration - duration).abs();
                final currentDiff = (current.duration - duration).abs();
                return bestDiff <= currentDiff ? best : current;
              });

        if (bestMatch != null && (bestMatch.duration - duration).abs() > 5) {
          bestMatch = null;
        }
      }

      if (bestMatch != null) {
        return bestMatch.syncedLyrics ?? bestMatch.plainLyrics;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
