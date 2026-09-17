import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/language_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('catchify_lang_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    final box = Hive.box('settings');
    await box.clear();
  });

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

  group('InnerTube Transport Language Strategy (resolveHomeFeedTransportLanguage)', () {
    test('verified languages use direct hl transport', () {
      const verified = [
        'en',
        'ta',
        'hi',
        'te',
        'ml',
        'kn',
        'pa',
        'mr',
        'bn',
        'gu',
        'ur',
        'or',
        'as',
      ];

      for (final code in verified) {
        expect(
          resolveHomeFeedTransportLanguage(code),
          equals(code),
          reason: 'Verified language $code must map to direct transport hl',
        );
      }
    });

    test('unindexed InnerTube languages safely fall back to en transport hl', () {
      // Sanskrit and Konkani returned 0 shelves on InnerTube runtime probe
      expect(resolveHomeFeedTransportLanguage('sa'), equals('en'));
      expect(resolveHomeFeedTransportLanguage('kok'), equals('en'));
    });

    test('UI-only languages fall back to en transport hl', () {
      expect(resolveHomeFeedTransportLanguage('de'), equals('en'));
      expect(resolveHomeFeedTransportLanguage('fr'), equals('en'));
      expect(resolveHomeFeedTransportLanguage('es'), equals('en'));
      expect(resolveHomeFeedTransportLanguage('ja'), equals('en'));
    });

    test('handles null, empty, whitespace, and corrupt values safely', () {
      expect(resolveHomeFeedTransportLanguage(null), equals('en'));
      expect(resolveHomeFeedTransportLanguage(''), equals('en'));
      expect(resolveHomeFeedTransportLanguage('   '), equals('en'));
      expect(resolveHomeFeedTransportLanguage('corrupt_lang'), equals('en'));
    });
  });

  group('Home Feed Cache Key Generation (v8)', () {
    test('generates versioned language-aware, transport-aware, and mood-aware cache keys', () {
      final keyTa = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        transportHl: 'ta',
        region: 'IN',
        mood: 'All',
      );
      final keyHi = getHomeFeedCacheKey(
        contentLanguage: 'hi',
        transportHl: 'hi',
        region: 'IN',
        mood: 'All',
      );
      final keyEn = getHomeFeedCacheKey(
        contentLanguage: 'en',
        transportHl: 'en',
        region: 'IN',
        mood: 'All',
      );
      final keySa = getHomeFeedCacheKey(
        contentLanguage: 'sa',
        transportHl: 'en',
        region: 'IN',
        mood: 'All',
      );

      expect(keyTa, equals('ytm_home_feed_v8_ta_ta_IN_All'));
      expect(keyHi, equals('ytm_home_feed_v8_hi_hi_IN_All'));
      expect(keyEn, equals('ytm_home_feed_v8_en_en_IN_All'));
      expect(keySa, equals('ytm_home_feed_v8_sa_en_IN_All'));

      // Verify no cross-language collision
      expect(keyTa, isNot(equals(keyHi)));
      expect(keyTa, isNot(equals(keyEn)));
      expect(keyHi, isNot(equals(keyEn)));
      expect(keySa, isNot(equals(keyEn)));
    });

    test('isolates cache when transport language differs for same content language', () {
      final keyTaDirect = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        transportHl: 'ta',
        region: 'IN',
        mood: 'All',
      );
      final keyTaFallback = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        transportHl: 'en',
        region: 'IN',
        mood: 'All',
      );

      expect(keyTaDirect, equals('ytm_home_feed_v8_ta_ta_IN_All'));
      expect(keyTaFallback, equals('ytm_home_feed_v8_ta_en_IN_All'));
      expect(keyTaDirect, isNot(equals(keyTaFallback)));
    });

    test('generates distinct cache keys for different moods', () {
      final keyAll = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        transportHl: 'ta',
        region: 'IN',
        mood: 'All',
      );
      final keyWorkout = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        transportHl: 'ta',
        region: 'IN',
        mood: 'Workout',
      );
      final keyChill = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        transportHl: 'ta',
        region: 'IN',
        mood: 'Chill',
      );

      expect(keyAll, equals('ytm_home_feed_v8_ta_ta_IN_All'));
      expect(keyWorkout, equals('ytm_home_feed_v8_ta_ta_IN_Workout'));
      expect(keyChill, equals('ytm_home_feed_v8_ta_ta_IN_Chill'));

      expect(keyAll, isNot(equals(keyWorkout)));
      expect(keyWorkout, isNot(equals(keyChill)));
    });

    test('defaults safely when parameters are omitted or empty', () {
      final keyDefault = getHomeFeedCacheKey(mood: '');
      expect(keyDefault, startsWith('ytm_home_feed_v8_'));
      expect(keyDefault, endsWith('_IN_All'));
    });
  });

  group('First-Launch Onboarding & Decoupled State Management', () {
    test('completeContentLanguageOnboarding updates content language without altering UI language', () async {
      final box = Hive.box('settings');
      await box.put('languageCode', 'en');
      languageSetting = const Locale('en');

      // User selects Tamil on onboarding
      await completeContentLanguageOnboarding('ta');

      // 1. Content language is updated
      expect(contentLanguagePreference, equals('ta'));
      expect(contentLanguagePreferenceNotifier.value, equals('ta'));
      expect(box.get('contentLanguageCode'), equals('ta'));
      expect(box.get('hasSeenLanguageOnboarding'), isTrue);

      // 2. UI language MUST REMAIN ENGLISH
      expect(box.get('languageCode'), equals('en'));
      expect(languageSetting.languageCode, equals('en'));
    });

    test('completeContentLanguageOnboarding with Hindi preserves English UI', () async {
      final box = Hive.box('settings');
      await box.put('languageCode', 'en');
      languageSetting = const Locale('en');

      await completeContentLanguageOnboarding('hi');

      expect(contentLanguagePreference, equals('hi'));
      expect(box.get('contentLanguageCode'), equals('hi'));
      expect(box.get('hasSeenLanguageOnboarding'), isTrue);
      expect(box.get('languageCode'), equals('en'));
      expect(languageSetting.languageCode, equals('en'));
    });

    test('Changing App UI Language does NOT alter Music Content Language', () async {
      final box = Hive.box('settings');
      await completeContentLanguageOnboarding('ta');
      expect(contentLanguagePreference, equals('ta'));

      // Simulate user later going to Settings -> App Language -> German ('de')
      await box.put('languageCode', 'de');
      languageSetting = const Locale('de');

      // App UI is German, but Music preference remains Tamil
      expect(languageSetting.languageCode, equals('de'));
      expect(box.get('languageCode'), equals('de'));
      expect(contentLanguagePreference, equals('ta'));
      expect(box.get('contentLanguageCode'), equals('ta'));

      // Home cache key continues to be Tamil-oriented
      final key = getHomeFeedCacheKey(mood: 'All');
      expect(key, startsWith('ytm_home_feed_v8_ta_'));
    });

    test('Changing Music Language does NOT alter App UI Language', () async {
      final box = Hive.box('settings');
      await box.put('languageCode', 'de');
      languageSetting = const Locale('de');
      await completeContentLanguageOnboarding('ta');

      // User changes Music Language to Hindi
      setContentLanguagePreference('hi');

      expect(contentLanguagePreference, equals('hi'));
      expect(box.get('contentLanguageCode'), equals('hi'));
      // UI language remains German
      expect(languageSetting.languageCode, equals('de'));
      expect(box.get('languageCode'), equals('de'));
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
