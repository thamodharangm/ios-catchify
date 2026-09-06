import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/database/albums.db.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';

void main() {
  group('Albums & Singles Tests', () {
    test('albumsDB contains valid entries with required fields', () {
      expect(albumsDB.isNotEmpty, isTrue);
      expect(albumsDB.length, greaterThanOrEqualTo(100));

      for (final item in albumsDB) {
        final album = item as Map;
        final ytid = album['ytid'] as String?;
        final title = album['title'] as String?;
        final image = album['image'] as String?;

        expect(ytid, isNotNull, reason: 'ytid should not be null');
        expect(ytid!.isNotEmpty, isTrue, reason: 'ytid should not be empty');

        expect(title, isNotNull, reason: 'title should not be null');
        expect(title!.isNotEmpty, isTrue, reason: 'title should not be empty');

        expect(image, isNotNull, reason: 'image should not be null for $title');
        expect(image!.startsWith('http'), isTrue,
            reason: 'image URL must be HTTP/HTTPS for $title');
      }
    });

    test('albumsDB covers regional languages including Tamil and Hindi', () {
      final languages = albumsDB
          .where((a) => (a as Map)['language'] != null)
          .map((a) => (a as Map)['language'] as String)
          .toSet();

      expect(languages.contains('Tamil'), isTrue,
          reason: 'albumsDB must contain Tamil blockbuster albums');
      expect(languages.contains('Hindi'), isTrue,
          reason: 'albumsDB must contain Hindi blockbuster albums');
      expect(languages.contains('Telugu'), isTrue,
          reason: 'albumsDB must contain Telugu blockbuster albums');
      expect(languages.contains('Malayalam'), isTrue,
          reason: 'albumsDB must contain Malayalam blockbuster albums');
    });

    test('getSuggestedAlbumsAndSingles returns unique albums without duplicates', () async {
      final albums = await getSuggestedAlbumsAndSingles(limit: 20);
      expect(albums.isNotEmpty, isTrue);
      expect(albums.length, lessThanOrEqualTo(20));

      final ids = albums.map((a) => a['ytid']).toSet();
      expect(ids.length, equals(albums.length),
          reason: 'All suggested albums must have unique IDs');
    });

    test('getSuggestedAlbumsAndSingles prioritizes preferred language (Tamil)', () async {
      contentLanguagePreference = 'Tamil';
      final albums = await getSuggestedAlbumsAndSingles(limit: 15);
      expect(albums.isNotEmpty, isTrue);

      final topAlbums = albums.take(5).toList();
      final hasTamilAlbum = topAlbums.any((a) => a['language'] == 'Tamil');
      expect(hasTamilAlbum, isTrue,
          reason: 'Top albums should include Tamil albums when Tamil is preferred');
    });
  });
}
