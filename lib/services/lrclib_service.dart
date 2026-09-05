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

  // Channel and label patterns that shouldn't be used as the artist name
  static final List<RegExp> _channelLabelPatterns = [
    RegExp(r'\bthink\s*(?:music|indie)\b', caseSensitive: false),
    RegExp(r'\bsony\s*music\b', caseSensitive: false),
    RegExp(r'\bt-series\b', caseSensitive: false),
    RegExp(r'\bsaregama\b', caseSensitive: false),
    RegExp(r'\bzee\s*music\b', caseSensitive: false),
    RegExp(r'\baditya\s*music\b', caseSensitive: false),
    RegExp(r'\btips\b', caseSensitive: false),
    RegExp(r'\blahari\b', caseSensitive: false),
    RegExp(r'\bdivo\b', caseSensitive: false),
    RegExp(r'\bmuzik247\b', caseSensitive: false),
    RegExp(r'\bspeed\s*audio\b', caseSensitive: false),
    RegExp(r'\btimes\s*music\b', caseSensitive: false),
    RegExp(r'\beros\s*now\b', caseSensitive: false),
    RegExp(r'\byrf\b|\byash\s*raj\b', caseSensitive: false),
    RegExp(r'\bjunglee\b', caseSensitive: false),
    RegExp(r'\bsun\s*tv\b|\bstar\s*vijay\b', caseSensitive: false),
    RegExp(r'\bvevo\b', caseSensitive: false),
    RegExp(r'\brecords\b|\bofficial\b|\btopic\b|\bmusic\s*india\b', caseSensitive: false),
  ];

  static bool isChannelLabel(String artist) {
    if (artist.trim().isEmpty) return true;
    for (final pattern in _channelLabelPatterns) {
      if (pattern.hasMatch(artist)) return true;
    }
    return false;
  }

  // Common title cleanup patterns
  static final List<RegExp> _titleCleanupPatterns = [
    RegExp(r'\s*\(.*?(?:official|audio|video|lyrics|lyric|feat|ft|remix|hd|4k|from|full song).*?\)', caseSensitive: false),
    RegExp(r'\s*\[.*?(?:official|audio|video|lyrics|lyric|feat|ft|remix|hd|4k|from|full song).*?\]', caseSensitive: false),
    RegExp(r'\s*-\s*(?:official|audio|video|lyrics|lyric|hd|4k|music video|lyric video|video song).*$', caseSensitive: false),
    RegExp(r'\s*(?:official video|music video|lyric video|video song|audio song|full video|lyrical video)', caseSensitive: false),
  ];

  // Common artist separation patterns
  static final List<String> _artistSeparators = [' feat.', ' ft.', ' feat', ' ft', ' & ', ', ', ' x '];

  /// Clean the title for better search results
  static String _cleanTitle(String title) {
    var cleaned = title.trim();
    // Strip leading @handles (e.g. @SaiAbhyankkar - )
    cleaned = cleaned.replaceAll(RegExp(r'^@\w+\s*[-–—:]\s*'), '');
    for (final pattern in _titleCleanupPatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    cleaned = cleaned.replaceAll(RegExp(r'[\(\)\[\]\|]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Extract primary artist from the given string
  static String _cleanArtist(String artist) {
    var cleaned = artist.trim();
    cleaned = cleaned.replaceAll(RegExp('^@'), '');
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

  static List<String> _buildSearchQueries(String artist, String title) {
    final cleanT = _cleanTitle(title);
    final cleanA = _cleanArtist(artist);
    final isLabel = isChannelLabel(cleanA);
    final effectiveArtist = isLabel ? '' : cleanA;

    final words = cleanT.split(' ').where((w) => w.trim().isNotEmpty).toList();
    final first1Word = words.isNotEmpty ? words.first : '';
    final first2Words = words.length >= 2 ? '${words[0]} ${words[1]}' : cleanT;
    final first3Words = words.length >= 3 ? '${words[0]} ${words[1]} ${words[2]}' : cleanT;

    final queries = <String>[];

    // 1. Artist + Title if artist is real
    if (effectiveArtist.isNotEmpty && cleanT.isNotEmpty) {
      queries
        ..add('$effectiveArtist $first2Words')
        ..add('$effectiveArtist $cleanT');
    }

    // 2. First 2-3 words of title (e.g. "Vaama Vaama Idhayam", "Vaan Vaan Idhayam")
    if (first2Words.isNotEmpty) queries.add(first2Words);
    if (first3Words.isNotEmpty && first3Words != first2Words) queries.add(first3Words);

    // 3. First word if single word title (e.g. "Radhimaa", "Chaleya", "Manike")
    if (first1Word.length >= 4 && !queries.contains(first1Word)) {
      queries.add(first1Word);
    }

    // 4. What if artist was actually the song title? (e.g. "Vaama Vaama" + "Idhayam")
    if (!isLabel && cleanA.isNotEmpty && cleanA.length >= 3) {
      if (first2Words.isNotEmpty) queries.add('$cleanA $first2Words');
      queries.add(cleanA);
    }

    // 5. Full cleaned title fallback
    if (cleanT.isNotEmpty && !queries.contains(cleanT)) {
      queries.add(cleanT);
    }

    // Deduplicate preserving order
    final seen = <String>{};
    final dedup = <String>[];
    for (final q in queries) {
      final norm = q.toLowerCase().trim();
      if (norm.length > 1 && seen.add(norm)) {
        dedup.add(q.trim());
      }
    }
    return dedup;
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
    final queries = _buildSearchQueries(artist, title);

    for (final q in queries) {
      final results = await _queryLyricsWithParams(query: q);
      final valid = results
          .where((track) => track.syncedLyrics != null || track.plainLyrics != null)
          .toList();
      if (valid.isNotEmpty) return valid;
    }

    // Direct track_name / artist_name search as final fallback
    final cleanT = _cleanTitle(title);
    final cleanA = _cleanArtist(artist);
    final isLabel = isChannelLabel(cleanA);
    if (cleanT.isNotEmpty) {
      final results = await _queryLyricsWithParams(
        trackName: cleanT,
        artistName: isLabel ? null : cleanA,
        albumName: album,
      );
      final valid = results
          .where((track) => track.syncedLyrics != null || track.plainLyrics != null)
          .toList();
      if (valid.isNotEmpty) return valid;
    }

    return [];
  }

  /// Fetch lyrics for a song - returns synced lyrics if available, otherwise plain lyrics
  static Future<String?> getLyrics({
    required String title,
    required String artist,
    int? duration,
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
      final syncedTracks = tracks
          .where((t) => t.syncedLyrics != null && t.syncedLyrics!.isNotEmpty)
          .toList();
      final pool = syncedTracks.isNotEmpty ? syncedTracks : tracks;

      final Track bestMatch;
      if (duration != null && duration > 0) {
        // Find match with duration closest to the requested one
        bestMatch = pool.reduce((best, current) {
          final bestDiff = (best.duration - duration).abs();
          final currentDiff = (current.duration - duration).abs();
          return bestDiff <= currentDiff ? best : current;
        });
      } else {
        bestMatch = pool.first;
      }

      // Prefer synced lyrics over plain lyrics
      return bestMatch.syncedLyrics ?? bestMatch.plainLyrics;
    } catch (_) {
      return null;
    }
  }
}
