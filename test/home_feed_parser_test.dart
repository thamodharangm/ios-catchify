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
            'image': 'https://example.com/image.jpg',
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
    });

    test('HomeSection JSON serialization and deserialization', () {
      const original = HomeSection(
        title: 'Albums for you',
        subtitle: 'RECOMMENDED',
        type: HomeContentType.albums,
        contents: [
          {
            'ytid': 'MPREb_12345',
            'title': 'Test Album',
            'artist': 'Test Band',
            'isAlbum': true,
            'source': 'youtube-music-album',
          }
        ],
      );

      final json = original.toJson();
      expect(json['title'], equals('Albums for you'));
      expect(json['type'], equals('albums'));
      expect(json['contents'], isA<List>());

      final restored = HomeSection.fromJson(json);
      expect(restored.title, equals(original.title));
      expect(restored.subtitle, equals(original.subtitle));
      expect(restored.type, equals(HomeContentType.albums));
      expect(restored.contents.length, equals(1));
      expect(restored.contents.first['ytid'], equals('MPREb_12345'));
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
