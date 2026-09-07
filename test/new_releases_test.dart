import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/database/new_releases.db.dart';

void main() {
  group('New Releases Tests', () {
    test('newReleasesDB is deprecated and empty (100% dynamic live YTM)', () {
      expect(newReleasesDB, isEmpty);
    });
  });
}
