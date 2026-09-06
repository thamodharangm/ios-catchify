import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:catchify/database/albums.db.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_albums_test');
    Hive.init(tempDir.path);
    await Hive.openBox('cache');
    await Hive.openBox('settings');
    await Hive.openBox('user');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Albums & Singles Tests', () {
    test('albumsDB contains valid entries with required fields', () {
      expect(albumsDB.isNotEmpty, isTrue);
      expect(albumsDB.length, greaterThanOrEqualTo(100));

      for (final item in albumsDB) {
        final album = item as Map;
        final ytid = album['ytid'] as String?;
        final title = album['title'] as String?;
        final image = album['image'] as String?;

        expect(ytid, isNotNull, reason: 'ytid should not be null');
        expect(ytid!.isNotEmpty, isTrue, reason: 'ytid should not be empty');

        expect(title, isNotNull, reason: 'title should not be null');
        expect(title!.isNotEmpty, isTrue, reason: 'title should not be empty');

        expect(image, isNotNull, reason: 'image should not be null for $title');
        expect(image!.startsWith('http'), isTrue,
            reason: 'image URL must be HTTP/HTTPS for $title');
      }
    });

    test('albumsDB contains viral Tamil independent singles requested by user', () {
      final titles = albumsDB.map((a) => (a as Map)['title'].toString()).toList();

      expect(titles.any((t) => t.contains('Radhimaa')), isTrue,
          reason: 'albumsDB must contain Radhimaa single');
      expect(titles.any((t) => t.contains('Pavazha Malli')), isTrue,
          reason: 'albumsDB must contain Pavazha Malli single');
      expect(titles.any((t) => t.contains('Katchi Sera')), isTrue,
          reason: 'albumsDB must contain Katchi Sera single');
      expect(titles.any((t) => t.contains('Aasa Kooda')), isTrue,
          reason: 'albumsDB must contain Aasa Kooda single');
      expect(titles.any((t) => t.contains('Bodhai Kodhai')), isTrue,
          reason: 'albumsDB must contain Bodhai Kodhai single');
      expect(titles.any((t) => t.contains('Orasaadha')), isTrue,
          reason: 'albumsDB must contain Orasaadha single');
      expect(titles.any((t) => t.contains('Enjoy Enjaami')), isTrue,
          reason: 'albumsDB must contain Enjoy Enjaami single');
      expect(titles.any((t) => t.contains('Kutty Pattas')), isTrue,
          reason: 'albumsDB must contain Kutty Pattas single');
      expect(titles.any((t) => t.contains('Hey Minnale')), isTrue,
          reason: 'albumsDB must contain Hey Minnale single');
      expect(titles.any((t) => t.contains('Manasilaayo')), isTrue,
          reason: 'albumsDB must contain Manasilaayo single');
      expect(titles.any((t) => t.contains('Matta')), isTrue,
          reason: 'albumsDB must contain Matta single');
    });

    test('albumsDB covers regional languages including Tamil, Hindi, Telugu, Malayalam', () {
      final languages = albumsDB
          .where((a) => (a as Map)['language'] != null)
          .map((a) => (a as Map)['language'] as String)
          .toSet();

      expect(languages.contains('Tamil'), isTrue,
          reason: 'albumsDB must contain Tamil blockbuster albums');
      expect(languages.contains('Hindi'), isTrue,
          reason: 'albumsDB must contain Hindi blockbuster albums');
      expect(languages.contains('Telugu'), isTrue,
          reason: 'albumsDB must contain Telugu blockbuster albums');
      expect(languages.contains('Malayalam'), isTrue,
          reason: 'albumsDB must contain Malayalam blockbuster albums');
    });

    test('getSuggestedAlbumsAndSingles returns unique albums without duplicates', () async {
      final albums = await getSuggestedAlbumsAndSingles(limit: 20);
      expect(albums.isNotEmpty, isTrue);
      expect(albums.length, lessThanOrEqualTo(20));

      final ids = albums.map((a) => a['ytid']).toSet();
      expect(ids.length, equals(albums.length),
          reason: 'All suggested albums must have unique IDs');
    });

    test('STRICT LANGUAGE ISOLATION: Tamil preferred returns ONLY Tamil and NO English albums', () async {
      contentLanguagePreference = 'Tamil';
      final albums = await getSuggestedAlbumsAndSingles(limit: 20);
      expect(albums.isNotEmpty, isTrue);

      for (final a in albums) {
        expect(a['language'], equals('Tamil'),
            reason: 'Albums for Tamil user must strictly be Tamil, found ${a['title']} (${a['language']})');
      }

      final englishCount = albums.where((a) => a['language'] == 'English' || a['language'] == null).length;
      expect(englishCount, equals(0),
          reason: 'English albums must be completely removed when regional language is active');
    });

    test('English preference returns English/global albums', () async {
      contentLanguagePreference = 'English';
      final albums = await getSuggestedAlbumsAndSingles(limit: 15);
      expect(albums.isNotEmpty, isTrue);

      final hasEnglishOrGlobal = albums.any((a) => a['language'] == 'English' || a['language'] == null);
      expect(hasEnglishOrGlobal, isTrue,
          reason: 'English/global albums should appear when English is preferred');
    });
  });
}
