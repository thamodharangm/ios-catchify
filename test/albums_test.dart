import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/services/playlists_manager.dart';

void main() {
  group('Albums & Singles Dynamic Tests', () {
    test('artistLanguageCodeToName maps major languages correctly', () {
      expect(artistLanguageCodeToName['ta'], 'Tamil');
      expect(artistLanguageCodeToName['hi'], 'Hindi');
      expect(artistLanguageCodeToName['te'], 'Telugu');
      expect(artistLanguageCodeToName['en'], 'English');
    });
  });
}
