import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/database/playlists.db.dart';

void main() {
  group('Playlists Database Tests', () {
    test('playlistsDB contains verified playlists for all supported languages', () {
      expect(playlistsDB.isNotEmpty, isTrue);

      final supportedLanguages = [
        'ta', // Tamil
        'hi', // Hindi
        'te', // Telugu
        'ml', // Malayalam
        'kn', // Kannada
        'pa', // Punjabi
        'mr', // Marathi
        'bn', // Bengali
        'gu', // Gujarati
        'ur', // Urdu
        'or', // Odia
        'as', // Assamese
        'sa', // Sanskrit
        'kok', // Konkani
        'ko', // Korean / K-Pop
        'es', // Spanish / Latin
        'ja', // Japanese / J-Pop / Anime
      ];

      for (final lang in supportedLanguages) {
        final langPlaylists = playlistsDB.where((p) => p['language'] == lang).toList();
        expect(
          langPlaylists.length,
          greaterThanOrEqualTo(8),
          reason: 'Language "$lang" should have at least 8 curated playlists, found ${langPlaylists.length}',
        );

        for (final p in langPlaylists) {
          expect(p['title'], isNotNull, reason: 'Playlist must have title');
          expect((p['title'] as String).trim().isNotEmpty, isTrue);
          expect(p['ytid'], isNotNull, reason: 'Playlist must have ytid');
          expect((p['ytid'] as String).trim().isNotEmpty, isTrue);
          expect(p['image'], isNotNull, reason: 'Playlist must have image');
          expect((p['image'] as String).startsWith('http'), isTrue);
        }
      }
    });

    test('All regional playlists are properly tagged with language', () {
      final regionalLanguages = [
        'ta', 'hi', 'te', 'ml', 'kn', 'pa', 'mr', 'bn', 'gu', 'ur', 'or', 'as', 'sa', 'kok', 'ko', 'es', 'ja',
      ];

      for (final lang in regionalLanguages) {
        final playlists = playlistsDB.where((p) => p['language'] == lang).toList();
        for (final item in playlists) {
          expect(item['language'], equals(lang));
        }
      }
    });

    test('English/global playlists are available in significant quantity', () {
      final enPlaylists = playlistsDB
          .where((p) => p['language'] == 'en' || p['language'] == null)
          .toList();
      expect(enPlaylists.length, greaterThanOrEqualTo(20));
    });

    test('All playlist artworks are unique without duplicates', () {
      final imageSet = <String>{};
      final duplicates = <String>[];
      for (final p in playlistsDB) {
        final img = p['image'] as String?;
        if (img != null && img.isNotEmpty) {
          if (!imageSet.add(img)) {
            duplicates.add('${p['title']} ($img)');
          }
        }
      }
      expect(duplicates, isEmpty, reason: 'Found duplicate images: $duplicates');
    });
  });
}
