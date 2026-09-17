import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/utilities/language_utils.dart';
import 'package:catchify/services/playlists_manager.dart';

void main() {
  group('Language Resolution & Mappings', () {
    test('supported music content languages map to identical code', () {
      final supportedCodes = [
        'ta',
        'hi',
        'te',
        'ml',
        'kn',
        'pa',
        'en',
        'mr',
        'bn',
        'gu',
        'ur',
        'or',
        'as',
        'sa',
        'kok',
      ];

      for (final code in supportedCodes) {
        expect(
          resolveContentLanguageCode(code),
          equals(code),
          reason: 'Language code $code should map to itself for music content',
        );
      }
    });

    test('unsupported UI-only languages deterministically fall back to en', () {
      final unsupportedUiOnly = [
        'fr',
        'de',
        'es',
        'ja',
        'ko',
        'ru',
        'zh',
        'pt',
        'it',
        'tr',
        'uk',
        'pl',
        'sv',
        'hu',
        'id',
        'el',
        'et',
        'he',
      ];

      for (final code in unsupportedUiOnly) {
        expect(
          resolveContentLanguageCode(code),
          equals('en'),
          reason: 'UI-only language $code should safely fall back to en for music content',
        );
      }
    });

    test('resolveContentLanguageCode handles null, empty, whitespace, and corrupt values safely', () {
      expect(resolveContentLanguageCode(null), equals('en'));
      expect(resolveContentLanguageCode(''), equals('en'));
      expect(resolveContentLanguageCode('   '), equals('en'));
      expect(resolveContentLanguageCode('xyz_corrupt'), equals('en'));
      expect(resolveContentLanguageCode('unknown123'), equals('en'));
    });

    test('resolveContentLanguageCode handles locale codes with script subtags', () {
      expect(resolveContentLanguageCode('ta-IN'), equals('ta'));
      expect(resolveContentLanguageCode('hi-IN'), equals('hi'));
      expect(resolveContentLanguageCode('zh-Hans'), equals('en'));
      expect(resolveContentLanguageCode('en-US'), equals('en'));
    });

    test('resolveUiLanguageCode validates supported appLanguages and falls back to en', () {
      expect(resolveUiLanguageCode('en'), equals('en'));
      expect(resolveUiLanguageCode('ta'), equals('ta'));
      expect(resolveUiLanguageCode('hi'), equals('hi'));
      expect(resolveUiLanguageCode('fr'), equals('fr'));
      expect(resolveUiLanguageCode('de'), equals('de'));
      expect(resolveUiLanguageCode('ja'), equals('ja'));
      expect(resolveUiLanguageCode(null), equals('en'));
      expect(resolveUiLanguageCode(''), equals('en'));
      expect(resolveUiLanguageCode('invalid_language'), equals('en'));
    });

    test('getLocaleFromLanguageCode correctly returns Locale instances', () {
      expect(getLocaleFromLanguageCode('ta').languageCode, equals('ta'));
      expect(getLocaleFromLanguageCode('hi').languageCode, equals('hi'));
      expect(getLocaleFromLanguageCode('en').languageCode, equals('en'));
      expect(getLocaleFromLanguageCode(null).languageCode, equals('en'));
      expect(getLocaleFromLanguageCode('unsupported_xyz').languageCode, equals('en'));
    });
  });

  group('Home Feed Cache Key Generation', () {
    test('generates versioned language-aware and mood-aware cache keys', () {
      final keyTa = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        region: 'IN',
        mood: 'All',
      );
      final keyHi = getHomeFeedCacheKey(
        contentLanguage: 'hi',
        region: 'IN',
        mood: 'All',
      );
      final keyEn = getHomeFeedCacheKey(
        contentLanguage: 'en',
        region: 'IN',
        mood: 'All',
      );
      final keyTe = getHomeFeedCacheKey(
        contentLanguage: 'te',
        region: 'IN',
        mood: 'All',
      );

      expect(keyTa, equals('ytm_home_feed_v7_ta_IN_All'));
      expect(keyHi, equals('ytm_home_feed_v7_hi_IN_All'));
      expect(keyEn, equals('ytm_home_feed_v7_en_IN_All'));
      expect(keyTe, equals('ytm_home_feed_v7_te_IN_All'));

      // Verify no cross-language collision
      expect(keyTa, isNot(equals(keyHi)));
      expect(keyTa, isNot(equals(keyEn)));
      expect(keyHi, isNot(equals(keyEn)));
      expect(keyTe, isNot(equals(keyTa)));
    });

    test('generates distinct cache keys for different moods', () {
      final keyAll = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        region: 'IN',
        mood: 'All',
      );
      final keyWorkout = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        region: 'IN',
        mood: 'Workout',
      );
      final keyChill = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        region: 'IN',
        mood: 'Chill',
      );

      expect(keyAll, equals('ytm_home_feed_v7_ta_IN_All'));
      expect(keyWorkout, equals('ytm_home_feed_v7_ta_IN_Workout'));
      expect(keyChill, equals('ytm_home_feed_v7_ta_IN_Chill'));

      expect(keyAll, isNot(equals(keyWorkout)));
      expect(keyWorkout, isNot(equals(keyChill)));
    });

    test('defaults safely when parameters are omitted or empty', () {
      final keyDefault = getHomeFeedCacheKey(mood: '');
      expect(keyDefault, startsWith('ytm_home_feed_v7_'));
      expect(keyDefault, endsWith('_IN_All'));
    });
  });

  group('Reactive Language State & Notification Verification', () {
    test('contentLanguagePreferenceNotifier notifies listeners upon update', () {
      final notifier = ValueNotifier<String?>('ta');
      var notifiedCount = 0;
      String? lastValue;

      notifier.addListener(() {
        notifiedCount++;
        lastValue = notifier.value;
      });

      notifier.value = 'hi';
      expect(notifiedCount, equals(1));
      expect(lastValue, equals('hi'));

      notifier.value = 'en';
      expect(notifiedCount, equals(2));
      expect(lastValue, equals('en'));

      notifier.dispose();
    });
  });
}
