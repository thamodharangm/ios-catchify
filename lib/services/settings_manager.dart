/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Catchify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Catchify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/thamodharangm/catchify
 */

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:catchify/screens/playlist_page.dart';
import 'package:catchify/screens/user_songs_page.dart';
import 'package:catchify/utilities/language_utils.dart';

// Preferences

final shouldWeCheckUpdates = ValueNotifier<bool?>(
  Hive.box('settings').get('shouldWeCheckUpdates', defaultValue: null),
);

final playNextSongAutomatically = ValueNotifier<bool>(
  Hive.box('settings').get('playNextSongAutomatically', defaultValue: false),
);

final useSystemColor = ValueNotifier<bool>(
  Hive.box('settings').get('useSystemColor', defaultValue: false),
);

final usePureBlackColor = ValueNotifier<bool>(
  Hive.box('settings').get('usePureBlackColor', defaultValue: false),
);

final offlineMode = ValueNotifier<bool>(
  Hive.box('settings').get('offlineMode', defaultValue: false),
);

final wrappedEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('wrappedEnabled', defaultValue: true),
);

final predictiveBack = ValueNotifier<bool>(
  Hive.box('settings').get('predictiveBack', defaultValue: true),
);

final sponsorBlockSupport = ValueNotifier<bool>(
  Hive.box('settings').get('sponsorBlockSupport', defaultValue: false),
);

final externalRecommendations = ValueNotifier<bool>(
  Hive.box('settings').get('externalRecommendations', defaultValue: false),
);

final useProxy = ValueNotifier<bool>(
  Hive.box('settings').get('useProxy', defaultValue: false),
);

final audioQualitySetting = ValueNotifier<String>(
  Hive.box('settings').get('audioQuality', defaultValue: 'high'),
);

final lyricsOffsetNotifier = ValueNotifier<int>(
  Hive.box('settings').get('lyricsOffsetMs', defaultValue: 0) as int,
);

List<double> _readEqualizerGains() {
  final raw = Hive.box(
    'settings',
  ).get('equalizerBandGains', defaultValue: const <dynamic>[]);

  if (raw is List) {
    return raw.map((value) => value is num ? value.toDouble() : 0.0).toList();
  }

  return <double>[];
}

final equalizerEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('equalizerEnabled', defaultValue: false),
);

final equalizerBandGains = ValueNotifier<List<double>>(_readEqualizerGains());

Locale languageSetting = getLocaleFromLanguageCode(
  Hive.box('settings').get('languageCode', defaultValue: 'en') as String,
);

final hasSeenLanguageOnboarding =
    Hive.box('settings').get('hasSeenLanguageOnboarding', defaultValue: false)
        as bool;

/// Content-language preference picked on first launch, used only to steer
/// which playlists/songs are suggested. Distinct from [languageSetting],
/// which controls the app's displayed UI language and is unaffected by this.
String? contentLanguagePreference =
    Hive.box('settings').get('contentLanguageCode') as String?;

final themeModeSetting =
    Hive.box('settings').get('themeIndex', defaultValue: 0) as int;

String playlistSortSetting = Hive.box(
  'settings',
).get('playlistSortType', defaultValue: PlaylistSortType.default_.name);

String offlineSortSetting = Hive.box(
  'settings',
).get('offlineSortType', defaultValue: OfflineSortType.default_.name);

Color primaryColorSetting = Color(
  Hive.box('settings').get('accentColor', defaultValue: 0xFF9948EF),
);

final shuffleNotifier = ValueNotifier<bool>(
  Hive.box('settings').get('shuffleEnabled', defaultValue: false),
);

final repeatNotifier = ValueNotifier<AudioServiceRepeatMode>(
  AudioServiceRepeatMode.values[Hive.box(
    'settings',
  ).get('repeatMode', defaultValue: 0)],
);

// Non-storage notifiers

var sleepTimerNotifier = ValueNotifier<Duration?>(null);

// Server-Notifiers

final announcementURL = ValueNotifier<String?>(null);

/// Re-syncs every persisted setting's in-memory value from the `settings`
/// Hive box. Every setting above is only read once, at process start, into
/// either a [ValueNotifier] or a plain top-level variable — data_manager's
/// restoreData overwrites the box on disk but never touches these. Without
/// calling this afterward, a restored backup (e.g. from another device)
/// silently keeps behaving like the pre-restore settings — proxy, equalizer,
/// audio quality, theme colors, etc. — until the app is fully force-quit and
/// relaunched.
///
/// `themeModeSetting` and `hasSeenLanguageOnboarding` are intentionally not
/// reloaded here: both are declared `final` and only ever consulted once at
/// cold start (live theme-mode changes flow through `_CatchifyState.themeMode`
/// instead), so there is nothing a mid-session reload could affect.
void reloadSettingsFromStorage() {
  final settingsBox = Hive.box('settings');

  shouldWeCheckUpdates.value = settingsBox.get(
    'shouldWeCheckUpdates',
    defaultValue: null,
  );
  playNextSongAutomatically.value = settingsBox.get(
    'playNextSongAutomatically',
    defaultValue: false,
  );
  useSystemColor.value = settingsBox.get(
    'useSystemColor',
    defaultValue: false,
  );
  usePureBlackColor.value = settingsBox.get(
    'usePureBlackColor',
    defaultValue: false,
  );
  offlineMode.value = settingsBox.get('offlineMode', defaultValue: false);
  wrappedEnabled.value = settingsBox.get('wrappedEnabled', defaultValue: true);
  predictiveBack.value = settingsBox.get('predictiveBack', defaultValue: true);
  sponsorBlockSupport.value = settingsBox.get(
    'sponsorBlockSupport',
    defaultValue: false,
  );
  externalRecommendations.value = settingsBox.get(
    'externalRecommendations',
    defaultValue: false,
  );
  useProxy.value = settingsBox.get('useProxy', defaultValue: false);
  audioQualitySetting.value = settingsBox.get(
    'audioQuality',
    defaultValue: 'high',
  );
  lyricsOffsetNotifier.value = settingsBox.get(
    'lyricsOffsetMs',
    defaultValue: 0,
  ) as int;
  equalizerEnabled.value = settingsBox.get(
    'equalizerEnabled',
    defaultValue: false,
  );
  equalizerBandGains.value = _readEqualizerGains();
  shuffleNotifier.value = settingsBox.get('shuffleEnabled', defaultValue: false);
  repeatNotifier.value =
      AudioServiceRepeatMode.values[settingsBox.get('repeatMode', defaultValue: 0)];

  languageSetting = getLocaleFromLanguageCode(
    settingsBox.get('languageCode', defaultValue: 'en') as String,
  );
  contentLanguagePreference =
      settingsBox.get('contentLanguageCode') as String?;
  playlistSortSetting = settingsBox.get(
    'playlistSortType',
    defaultValue: PlaylistSortType.default_.name,
  );
  offlineSortSetting = settingsBox.get(
    'offlineSortType',
    defaultValue: OfflineSortType.default_.name,
  );
  primaryColorSetting = Color(
    settingsBox.get('accentColor', defaultValue: 0xFF9948EF),
  );
}
