import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/database/artists.db.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';

void main() {
  group('Artists Database & Suggested Artists Tests', () {
    test('artistsDB contains valid entries with required fields', () {
      expect(artistsDB.isNotEmpty, isTrue);
      expect(artistsDB.length, greaterThanOrEqualTo(30));

      for (final artist in artistsDB) {
        final ytid = artist['ytid'] as String?;
        final title = artist['title'] as String?;
        final image = artist['image'] as String?;
        final language = artist['language'] as String?;
        final isArtist = artist['isArtist'] as bool?;

        expect(ytid, isNotNull, reason: 'ytid should not be null');
        expect(ytid!.isNotEmpty, isTrue, reason: 'ytid should not be empty');

        expect(title, isNotNull, reason: 'title should not be null');
        expect(title!.isNotEmpty, isTrue, reason: 'title should not be empty');

        expect(image, isNotNull, reason: 'image should not be null for $title');
        expect(image!.startsWith('https://'), isTrue,
            reason: 'image URL must be HTTPS for $title');

        expect(language, isNotNull, reason: 'language should not be null for $title');
        expect(isArtist, isTrue, reason: 'isArtist must be true for $title');
      }
    });

    test('artistsDB contains no duplicate IDs or titles', () {
      final seenIds = <String>{};
      final seenTitles = <String>{};

      for (final artist in artistsDB) {
        final ytid = artist['ytid'] as String;
        final title = (artist['title'] as String).toLowerCase().trim();

        expect(seenIds.contains(ytid), isFalse,
            reason: 'Duplicate ytid found: $ytid ($title)');
        seenIds.add(ytid);

        expect(seenTitles.contains(title), isFalse,
            reason: 'Duplicate title found: $title');
        seenTitles.add(title);
      }
    });

    test('artistsDB covers Tamil, Hindi, English and regional languages', () {
      final languages = artistsDB.map((a) => a['language'] as String).toSet();
      expect(languages.contains('Tamil'), isTrue);
      expect(languages.contains('English'), isTrue);
      expect(languages.contains('Hindi'), isTrue);
      expect(languages.contains('Telugu'), isTrue);
      expect(languages.contains('Malayalam'), isTrue);
    });

    test('getSuggestedArtists returns unique artists', () async {
      final artists = await getSuggestedArtists(limit: 20);
      expect(artists.isNotEmpty, isTrue);
      expect(artists.length, lessThanOrEqualTo(20));

      final ids = artists.map((a) => a['ytid']).toSet();
      expect(ids.length, equals(artists.length),
          reason: 'All suggested artists must be unique');
    });

    test('getSuggestedArtists prioritizes preferred language (Tamil)', () async {
      contentLanguagePreference = 'Tamil';
      final artists = await getSuggestedArtists(limit: 15);
      expect(artists.isNotEmpty, isTrue);

      final topArtists = artists.take(5).toList();
      final hasTamilArtist = topArtists.any((a) => a['language'] == 'Tamil');
      expect(hasTamilArtist, isTrue,
          reason: 'Top artists should include Tamil artists when Tamil is preferred');
    });
  });
}
