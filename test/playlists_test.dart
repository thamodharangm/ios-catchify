import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/database/playlists.db.dart';
import 'package:catchify/services/playlists_manager.dart';

void main() {
  group('Playlists Database & Dynamic Tests', () {
    test('playlistsDB is deprecated and empty (100% dynamic live YTM)', () {
      expect(playlistsDB, isEmpty);
    });

    test('playlists global list starts empty', () {
      expect(playlists, isEmpty);
    });
  });
}
