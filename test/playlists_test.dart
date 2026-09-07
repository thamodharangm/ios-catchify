import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/services/playlists_manager.dart';

void main() {
  group('Playlists Database & Dynamic Tests', () {
    test('playlists global list starts empty', () {
      expect(playlists, isEmpty);
    });
  });
}
