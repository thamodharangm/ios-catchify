import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/database/albums.db.dart';

void main() {
  group('Albums & Singles Tests', () {
    test('albumsDB is deprecated and empty (100% dynamic live YTM)', () {
      expect(albumsDB, isEmpty);
    });
  });
}
