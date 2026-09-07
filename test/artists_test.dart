import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/database/artists.db.dart';

void main() {
  group('Artists Database & Dynamic Tests', () {
    test('artistsDB is deprecated and empty (100% dynamic live YTM)', () {
      expect(artistsDB, isEmpty);
    });
  });
}
