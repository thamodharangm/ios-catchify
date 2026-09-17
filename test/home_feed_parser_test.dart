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

import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/models/home_section.dart';

void main() {
  group('HomeSection Model & Parsing Tests', () {
    test('HomeSection constructor and properties', () {
      const section = HomeSection(
        title: 'Quick picks',
        subtitle: 'START RADIO FROM A SONG',
        type: HomeContentType.songs,
        contents: [
          {
            'id': 'video123456',
            'ytid': 'video123456',
            'title': 'Test Song',
            'artist': 'Test Artist',
            'artistId': 'UC1234567890',
            'artists': [
              {'name': 'Test Artist', 'id': 'UC1234567890'}
            ],
            'album': 'Test Album',
            'albumId': 'MPREb_987654321',
            'views': '14M plays',
            'isExplicit': false,
            'image': 'https://example.com/std.jpg',
            'lowResImage': 'https://example.com/low.jpg',
            'highResImage': 'https://example.com/high.jpg',
            'contentType': 'song',
          }
        ],
        isChunkedSongs: true,
      );

      expect(section.title, equals('Quick picks'));
      expect(section.subtitle, equals('START RADIO FROM A SONG'));
      expect(section.type, equals(HomeContentType.songs));
      expect(section.contents.length, equals(1));
      expect(section.isChunkedSongs, isTrue);
      expect(section.isNotEmpty, isTrue);
      expect(section.isEmpty, isFalse);

      final song = section.contents.first;
      expect(song['artistId'], equals('UC1234567890'));
      expect(song['album'], equals('Test Album'));
      expect(song['albumId'], equals('MPREb_987654321'));
      expect(song['views'], equals('14M plays'));
      expect(song['contentType'], equals('song'));
    });

    test('HomeSection JSON serialization and deserialization preserves rich fields', () {
      const original = HomeSection(
        title: 'New releases',
        subtitle: 'RECOMMENDED',
        type: HomeContentType.albums,
        contents: [
          {
            'ytid': 'MPREb_12345',
            'browseId': 'MPREb_12345',
            'title': 'Test Album',
            'artist': 'Test Band',
            'artistId': 'UC_band_123',
            'artists': [
              {'name': 'Test Band', 'id': 'UC_band_123'}
            ],
            'year': '2026',
            'type': 'album',
            'audioPlaylistId': 'OLAK5uy_album_playlist',
            'isAlbum': true,
            'isSingle': false,
            'isExplicit': true,
            'image': 'https://example.com/std.jpg',
            'lowResImage': 'https://example.com/low.jpg',
            'highResImage': 'https://example.com/high.jpg',
            'source': 'youtube-music-album',
            'contentType': 'album',
          }
        ],
        browseId: 'FEmusic_new_releases',
        params: 'params_test',
      );

      final json = original.toJson();
      expect(json['title'], equals('New releases'));
      expect(json['type'], equals('albums'));
      expect(json['browseId'], equals('FEmusic_new_releases'));
      expect(json['params'], equals('params_test'));
      expect(json['contents'], isA<List>());

      final restored = HomeSection.fromJson(json);
      expect(restored.title, equals(original.title));
      expect(restored.subtitle, equals(original.subtitle));
      expect(restored.type, equals(HomeContentType.albums));
      expect(restored.browseId, equals('FEmusic_new_releases'));
      expect(restored.params, equals('params_test'));
      expect(restored.contents.length, equals(1));

      final restoredAlbum = restored.contents.first;
      expect(restoredAlbum['ytid'], equals('MPREb_12345'));
      expect(restoredAlbum['browseId'], equals('MPREb_12345'));
      expect(restoredAlbum['artistId'], equals('UC_band_123'));
      expect(restoredAlbum['year'], equals('2026'));
      expect(restoredAlbum['audioPlaylistId'], equals('OLAK5uy_album_playlist'));
      expect(restoredAlbum['isExplicit'], isTrue);
      expect(restoredAlbum['lowResImage'], equals('https://example.com/low.jpg'));
    });

    test('Mixed content shelf preserves distinct contentTypes', () {
      const mixedSection = HomeSection(
        title: 'Mixed Discovery',
        type: HomeContentType.mixed,
        contents: [
          {
            'ytid': 'song_1',
            'title': 'Song 1',
            'contentType': 'song',
          },
          {
            'ytid': 'vid_1',
            'title': 'Music Video 1',
            'contentType': 'video',
            'videoType': 'MUSIC_VIDEO_TYPE_OMV',
          },
          {
            'ytid': 'MPREb_album',
            'title': 'Album 1',
            'contentType': 'album',
          },
          {
            'ytid': 'UC_artist',
            'title': 'Artist 1',
            'contentType': 'artist',
          },
          {
            'ytid': 'RDCLAK_playlist',
            'title': 'Playlist 1',
            'contentType': 'playlist',
          },
        ],
      );

      expect(mixedSection.type, equals(HomeContentType.mixed));
      expect(mixedSection.contents.length, equals(5));
      expect(mixedSection.contents[0]['contentType'], equals('song'));
      expect(mixedSection.contents[1]['contentType'], equals('video'));
      expect(mixedSection.contents[2]['contentType'], equals('album'));
      expect(mixedSection.contents[3]['contentType'], equals('artist'));
      expect(mixedSection.contents[4]['contentType'], equals('playlist'));
    });

    test('Playlist parsing preserves count and description', () {
      const playlistSection = HomeSection(
        title: 'Trending community playlists',
        type: HomeContentType.playlists,
        contents: [
          {
            'ytid': 'PL_test_123',
            'playlistId': 'PL_test_123',
            'title': 'Awesome Mix Vol. 1',
            'description': 'Curated playlist • 50 tracks',
            'count': '50',
            'artist': 'Curator Name',
            'author': [
              {'name': 'Curator Name', 'id': 'UC_curator_123'}
            ],
            'contentType': 'playlist',
          }
        ],
      );

      expect(playlistSection.type, equals(HomeContentType.playlists));
      final pl = playlistSection.contents.first;
      expect(pl['playlistId'], equals('PL_test_123'));
      expect(pl['count'], equals('50'));
      expect(pl['description'], contains('50 tracks'));
    });

    test('HomeSection deserialization handles malformed JSON safely', () {
      final malformedJson = <String, dynamic>{
        'title': null,
        'type': 'unrecognized_type_xyz',
        'contents': 'not_a_list',
      };

      final section = HomeSection.fromJson(malformedJson);
      expect(section.title, equals(''));
      expect(section.type, equals(HomeContentType.unknown));
      expect(section.contents, isEmpty);
      expect(section.isEmpty, isTrue);
    });

    test('HomeContentType handles all enum variants', () {
      expect(HomeContentType.values, contains(HomeContentType.songs));
      expect(HomeContentType.values, contains(HomeContentType.albums));
      expect(HomeContentType.values, contains(HomeContentType.artists));
      expect(HomeContentType.values, contains(HomeContentType.playlists));
      expect(HomeContentType.values, contains(HomeContentType.mixed));
      expect(HomeContentType.values, contains(HomeContentType.unknown));
    });

    test('Empty section drops correctly without crash', () {
      const emptySection = HomeSection(
        title: 'Empty Shelf',
        type: HomeContentType.songs,
        contents: [],
      );

      expect(emptySection.isEmpty, isTrue);
      expect(emptySection.isNotEmpty, isFalse);
    });
  });
}
