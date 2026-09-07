import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/services/playlists_manager.dart';

void main() {
  group('New Releases Dynamic Tests', () {
    test('supported content languages have valid codes', () {
      expect(artistLanguageCodeToName.containsKey('ta'), true);
      expect(artistLanguageCodeToName.containsKey('en'), true);
      expect(artistLanguageCodeToName.containsKey('hi'), true);
    });
  });
}
