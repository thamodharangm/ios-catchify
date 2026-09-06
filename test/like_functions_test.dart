import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/playlists_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_like_test');
    Hive.init(tempDir.path);
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

  group('isSongAlreadyLiked tests', () {
    setUp(() {
      userLikedSongsList.value = [
        {'ytid': 'song_1', 'title': 'First Song'},
        {'id': 'song_2', 'title': 'Second Song'},
      ];
    });

    test('returns false for null, empty, or "null" string', () {
      expect(isSongAlreadyLiked(null), isFalse);
      expect(isSongAlreadyLiked(''), isFalse);
      expect(isSongAlreadyLiked('   '), isFalse);
      expect(isSongAlreadyLiked('null'), isFalse);
    });

    test('finds song by ytid', () {
      expect(isSongAlreadyLiked('song_1'), isTrue);
    });

    test('finds song by id fallback', () {
      expect(isSongAlreadyLiked('song_2'), isTrue);
    });

    test('returns false for non-matching song id', () {
      expect(isSongAlreadyLiked('non_existent'), isFalse);
    });
  });

  group('isPlaylistAlreadyLiked tests', () {
    setUp(() {
      userLikedPlaylists.value = [
        {'ytid': 'playlist_1', 'title': 'First Playlist'},
        {'id': 'playlist_2', 'title': 'Second Playlist'},
      ];
    });

    test('returns false for null, empty, or "null" string', () {
      expect(isPlaylistAlreadyLiked(null), isFalse);
      expect(isPlaylistAlreadyLiked(''), isFalse);
      expect(isPlaylistAlreadyLiked('   '), isFalse);
      expect(isPlaylistAlreadyLiked('null'), isFalse);
    });

    test('finds playlist by ytid', () {
      expect(isPlaylistAlreadyLiked('playlist_1'), isTrue);
    });

    test('finds playlist by id fallback', () {
      expect(isPlaylistAlreadyLiked('playlist_2'), isTrue);
    });

    test('returns false for non-matching playlist id', () {
      expect(isPlaylistAlreadyLiked('non_existent'), isFalse);
    });
  });
}
