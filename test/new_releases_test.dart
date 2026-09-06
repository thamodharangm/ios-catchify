import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/database/new_releases.db.dart';
import 'package:catchify/services/playlists_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('New Releases Tests', () {
    test('newReleasesDB contains valid entries with required fields', () {
      expect(newReleasesDB, isNotEmpty);
      for (final song in newReleasesDB) {
        expect(song['ytid'], isNotNull);
        expect(song['ytid'].toString(), isNotEmpty);
        expect(song['title'], isNotNull);
        expect(song['title'].toString(), isNotEmpty);
        expect(song['artist'], isNotNull);
        expect(song['artist'].toString(), isNotEmpty);
        expect(song['image'], isNotNull);
        expect(song['image'].toString(), startsWith('http'));
        expect(song['language'], isNotNull);
      }
    });

    test('newReleasesDB contains no duplicate IDs', () {
      final seenIds = <String>{};
      for (final song in newReleasesDB) {
        final ytid = song['ytid'].toString();
        expect(
          seenIds.contains(ytid),
          isFalse,
          reason: 'Duplicate ytid found: $ytid in "${song['title']}"',
        );
        seenIds.add(ytid);
      }
    });

    test('newReleasesDB covers regional languages including Tamil, Hindi, Telugu, Malayalam, and English', () {
      final languages = newReleasesDB
          .map((s) => s['language']?.toString())
          .whereType<String>()
          .toSet();

      expect(languages.contains('Tamil'), isTrue);
      expect(languages.contains('Hindi'), isTrue);
      expect(languages.contains('Telugu'), isTrue);
      expect(languages.contains('Malayalam'), isTrue);
      expect(languages.contains('English'), isTrue);
    });

    test('getSuggestedNewReleases returns unique songs without duplicates', () async {
      final songs = await getSuggestedNewReleases(limit: 20);
      expect(songs, isNotEmpty);
      expect(songs.length, lessThanOrEqualTo(20));

      final seen = <String>{};
      for (final s in songs) {
        final ytid = s['ytid'].toString();
        expect(seen.contains(ytid), isFalse, reason: 'Duplicate in suggestions: $ytid');
        seen.add(ytid);
      }
    });

    test('getSuggestedNewReleases prioritizes preferred language (Tamil)', () async {
      final songs = await getSuggestedNewReleases(limit: 8);
      expect(songs, isNotEmpty);

      // Since raw default is 'ta' (Tamil), top results should contain Tamil songs
      final tamilCount = songs.where((s) => s['language'] == 'Tamil').length;
      expect(tamilCount, greaterThan(0));
    });
  });
}
