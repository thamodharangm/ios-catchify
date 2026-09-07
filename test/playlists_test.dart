import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/services/playlists_manager.dart';

void main() {
  group('Playlists Database & Dynamic Tests', () {
    test('playlists global list starts empty', () {
      expect(playlists, isEmpty);
    });

    test('artistLanguageCodeToName maps community playlist languages', () {
      expect(artistLanguageCodeToName['ta'], equals('Tamil'));
      expect(artistLanguageCodeToName['en'], equals('English'));
      expect(artistLanguageCodeToName['hi'], equals('Hindi'));
    });

    test('getCommunityPlaylists returns a Future List', () async {
      final res = await getCommunityPlaylists(limit: 5);
      expect(res, isA<List>());
    });
  });
}
