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

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/screens/search_page.dart';
import 'package:catchify/services/audio_permission_service.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/listening_stats_service.dart';
import 'package:catchify/services/playlist_download_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/services/update_manager.dart';
import 'package:catchify/theme/app_colors.dart';
import 'package:catchify/theme/app_themes.dart';
import 'package:catchify/utilities/flutter_bottom_sheet.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/language_utils.dart';
import 'package:catchify/widgets/bottom_sheet_bar.dart';
import 'package:catchify/widgets/confirmation_dialog.dart';
import 'package:catchify/widgets/custom_bar.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Track which sections are expanded
  final Map<int, bool> _expanded = {
    0: true,  // Theme & App UI — open by default
    1: false,
    2: false,
    3: false,
    4: false,
  };

  void _toggle(int index) {
    setState(() {
      _expanded[index] = !(_expanded[index] ?? false);
    });
  }

  // ─── Collapsible section wrapper ─────────────────────────────────────────
  Widget _section({
    required int index,
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    final isOpen = _expanded[index] ?? false;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surfaceContainerHigh;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          // ── Header (tappable) ──
          GestureDetector(
            onTap: () => _toggle(index),
            child: Container(
              decoration: BoxDecoration(
                color: isOpen
                    ? primaryColor.withValues(alpha: 0.12)
                    : surfaceColor,
                borderRadius: isOpen
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: primaryColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isOpen
                            ? primaryColor
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isOpen
                          ? primaryColor
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Animated body ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: items),
            ),
            crossFadeState: isOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final activatedColor = Theme.of(context).colorScheme.secondaryContainer;
    final inactivatedColor =
        Theme.of(context).colorScheme.surfaceContainerHigh;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.settings)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),

            // ── 1. Theme & App UI ──
            _section(
              index: 0,
              title: context.l10n!.themeAndAppUI,
              icon: FluentIcons.paint_brush_24_filled,
              items: _themeItems(context, primaryColor, activatedColor,
                  inactivatedColor),
            ),

            // ── 2. Music & Playback ──
            _section(
              index: 1,
              title: context.l10n!.musicAndPlayback,
              icon: FluentIcons.music_note_2_24_filled,
              items: _musicPlaybackItems(context),
            ),

            // ── 3. Others ──
            _section(
              index: 2,
              title: context.l10n!.others,
              icon: FluentIcons.more_circle_24_filled,
              items: _othersItems(context),
            ),

            // ── 4. Backup & Restore ──
            _section(
              index: 3,
              title: context.l10n!.backupAndRestore,
              icon: FluentIcons.cloud_sync_24_filled,
              items: _backupRestoreItems(context),
            ),

            // ── 5. About ──
            _section(
              index: 4,
              title: context.l10n!.about,
              icon: FluentIcons.info_24_filled,
              items: _aboutItems(context),
            ),

            const SizedBox(height: 20),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Item builders (return List<Widget> — no SectionHeader needed)
  // ─────────────────────────────────────────────────────────────────────────

  List<Widget> _themeItems(
    BuildContext context,
    Color primaryColor,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);
    final showPredictiveBack = Platform.isAndroid;
    final showDynamicColor = Platform.isAndroid;

    return [
      CustomBar(
        context.l10n!.accentColor,
        FluentIcons.color_24_regular,
        borderRadius: commonCustomBarRadiusFirst,
        onTap: () => _showAccentColorPicker(context),
      ),
      CustomBar(
        context.l10n!.themeMode,
        FluentIcons.weather_sunny_28_regular,
        onTap: () => _showThemeModePicker(context),
      ),
      CustomBar(
        context.l10n!.language,
        FluentIcons.translate_24_regular,
        borderRadius: (!showDynamicColor && !isDark && !showPredictiveBack)
            ? commonCustomBarRadiusLast
            : BorderRadius.zero,
        onTap: () => _showLanguagePicker(context),
      ),
      if (showDynamicColor)
        CustomBar(
          context.l10n!.dynamicColor,
          FluentIcons.toggle_left_24_regular,
          borderRadius: (!isDark && !showPredictiveBack)
              ? commonCustomBarRadiusLast
              : BorderRadius.zero,
          trailing: Switch(
            value: useSystemColor.value,
            onChanged: (value) => _toggleSystemColor(context, value),
          ),
        ),
      if (isDark)
        CustomBar(
          context.l10n!.pureBlackTheme,
          FluentIcons.color_background_24_regular,
          borderRadius: !showPredictiveBack
              ? commonCustomBarRadiusLast
              : BorderRadius.zero,
          trailing: Switch(
            value: usePureBlackColor.value,
            onChanged: (value) => _togglePureBlack(context, value),
          ),
        ),
      if (showPredictiveBack)
        ValueListenableBuilder<bool>(
          valueListenable: predictiveBack,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.predictiveBack,
              FluentIcons.position_backward_24_regular,
              borderRadius: commonCustomBarRadiusLast,
              trailing: Switch(
                value: value,
                onChanged: (value) => _togglePredictiveBack(context, value),
              ),
            );
          },
        ),
    ];
  }

  List<Widget> _musicPlaybackItems(BuildContext context) {
    final showUpdates = Platform.isAndroid && !isFdroidBuild;
    final showEqualizer = Platform.isAndroid;

    return [
      CustomBar(
        context.l10n!.audioQuality,
        FluentIcons.music_note_1_24_regular,
        borderRadius: commonCustomBarRadiusFirst,
        onTap: () => _showAudioQualityPicker(context),
      ),
      if (showEqualizer)
        CustomBar(
          context.l10n!.equalizer,
          FluentIcons.data_histogram_24_regular,
          onTap: () => context.push('/settings/equalizer'),
        ),
      if (!offlineMode.value) ...[
        ValueListenableBuilder<bool>(
          valueListenable: sponsorBlockSupport,
          builder: (_, value, __) {
            return CustomBar(
              'SponsorBlock',
              FluentIcons.cut_24_regular,
              description: context.l10n!.sponsorBlockDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleSponsorBlock(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: playNextSongAutomatically,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.automaticSongPicker,
              FluentIcons.music_note_2_play_20_regular,
              description: context.l10n!.automaticSongPickerDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) {
                  _toggleAutoPlayNext(context, value);
                  showToast(context, context.l10n!.settingChangedMsg);
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: externalRecommendations,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.externalRecommendations,
              FluentIcons.channel_share_24_regular,
              description: context.l10n!.externalRecommendationsDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) =>
                    _toggleExternalRecommendations(context, value),
              ),
            );
          },
        ),
      ],
      ValueListenableBuilder<bool>(
        valueListenable: useProxy,
        builder: (_, value, __) {
          return CustomBar(
            context.l10n!.useProxy,
            FluentIcons.shield_24_regular,
            description: context.l10n!.useProxyDescription,
            trailing: Switch(
              value: value,
              onChanged: (value) {
                useProxy.value = value;
                addOrUpdateData<bool>('settings', 'useProxy', value);
                showToast(context, context.l10n!.settingChangedMsg);
              },
            ),
          );
        },
      ),
      ValueListenableBuilder<bool>(
        valueListenable: wrappedEnabled,
        builder: (_, value, __) {
          return CustomBar(
            context.l10n!.listeningStats,
            FluentIcons.clock_24_regular,
            description: context.l10n!.listeningStatsDescription,
            trailing: Switch(
              value: value,
              onChanged: (value) => _toggleWrapped(context, value),
            ),
          );
        },
      ),
      ValueListenableBuilder<bool>(
        valueListenable: offlineMode,
        builder: (_, value, __) {
          return CustomBar(
            context.l10n!.offlineMode,
            FluentIcons.cloud_off_24_regular,
            description: context.l10n!.offlineModeDescription,
            borderRadius: !showUpdates
                ? commonCustomBarRadiusLast
                : BorderRadius.zero,
            trailing: Switch(
              value: value,
              onChanged: (value) => _toggleOfflineMode(context, value),
            ),
          );
        },
      ),
      if (showUpdates)
        ValueListenableBuilder<bool?>(
          valueListenable: shouldWeCheckUpdates,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.automaticUpdateChecks,
              FluentIcons.arrow_sync_24_regular,
              description: context.l10n!.automaticUpdateChecksDescription,
              borderRadius: commonCustomBarRadiusLast,
              trailing: Switch(
                value: value ?? false,
                onChanged: (value) =>
                    _toggleAutomaticUpdateChecks(context, value),
              ),
            );
          },
        ),
    ];
  }

  List<Widget> _othersItems(BuildContext context) {
    return [
      CustomBar(
        context.l10n!.clearCache,
        FluentIcons.broom_24_regular,
        borderRadius: commonCustomBarRadiusFirst,
        onTap: () async {
          final cleared = await clearCache();
          if (mounted) {
            showToast(
              context,
              cleared
                  ? '${context.l10n!.cacheMsg}!'
                  : context.l10n!.error,
            );
          }
        },
      ),
      CustomBar(
        context.l10n!.clearSearchHistory,
        FluentIcons.history_24_regular,
        onTap: () => _showConfirmationDialog(
          context: context,
          confirmationMessage: context.l10n!.clearSearchHistoryQuestion,
          onSubmit: () {
            searchHistoryNotifier.value = [];
            deleteData('user', 'searchHistory');
            showToast(context, '${context.l10n!.searchHistoryMsg}!');
          },
        ),
      ),
      CustomBar(
        context.l10n!.clearRecentlyPlayed,
        FluentIcons.receipt_play_24_regular,
        onTap: () => _showConfirmationDialog(
          context: context,
          confirmationMessage: context.l10n!.clearRecentlyPlayedQuestion,
          onSubmit: () {
            userRecentlyPlayed.value = [];
            deleteData('user', 'recentlyPlayedSongs');
            showToast(context, '${context.l10n!.recentlyPlayedMsg}!');
          },
        ),
      ),
      CustomBar(
        context.l10n!.clearListeningStats,
        FluentIcons.clock_24_regular,
        onTap: () => _showConfirmationDialog(
          context: context,
          confirmationMessage: context.l10n!.clearListeningStatsQuestion,
          submitMessage: context.l10n!.delete,
          isDangerous: true,
          onSubmit: () async {
            audioHandler.resetListeningStatsSession(flushStats: false);
            await listeningStatsService.clearStats();
            audioHandler.startListeningStatsSessionIfNeeded();
            if (mounted) {
              showToast(
                context,
                '${context.l10n!.listeningStatsCleared}!',
              );
            }
          },
        ),
      ),
      CustomBar(
        context.l10n!.deleteDownloads,
        FluentIcons.delete_24_regular,
        onTap: () => _showConfirmationDialog(
          context: context,
          confirmationMessage: context.l10n!.deleteDownloadsQuestion,
          submitMessage: context.l10n!.delete,
          isDangerous: true,
          onSubmit: () async {
            try {
              await offlinePlaylistService.deleteAllDownloads();
              if (mounted) {
                showToast(context, context.l10n!.downloadsDeleted);
              }
            } catch (e) {
              if (mounted) {
                showToast(context, context.l10n!.error);
              }
            }
          },
        ),
      ),
      CustomBar(
        '${context.l10n!.copyLogs} (${logger.getLogCount()})',
        FluentIcons.error_circle_24_regular,
        onTap: () async {
          final message = await logger.copyLogs(context);
          if (mounted) showToast(context, message);
        },
      ),
      CustomBar(
        context.l10n!.licenses,
        FluentIcons.document_24_regular,
        borderRadius: commonCustomBarRadiusLast,
        onTap: () => context.push('/settings/license'),
      ),
    ];
  }

  List<Widget> _backupRestoreItems(BuildContext context) {
    return [
      CustomBar(
        context.l10n!.backupUserData,
        FluentIcons.cloud_sync_24_regular,
        borderRadius: commonCustomBarRadiusFirst,
        onTap: () => _backupUserData(context),
      ),
      CustomBar(
        context.l10n!.restoreUserData,
        FluentIcons.cloud_add_24_regular,
        onTap: () async {
          try {
            final result = await restoreData(context);
            if (result.success) {
              reloadSongLibraryStateFromStorage();
              reloadPlaylistLibraryStateFromStorage();
              reloadSearchHistoryFromStorage();
              // The restored settings box may carry different values than
              // what's already loaded in memory (proxy, equalizer, audio
              // quality, wrappedEnabled, etc.); without resyncing them here,
              // the app silently keeps following pre-restore settings until
              // the next cold start, when they'd suddenly flip without
              // explanation.
              reloadSettingsFromStorage();
              listeningStatsService.reload();
            }
            if (mounted) {
              showToast(
                context,
                result.message,
                icon: result.success
                    ? null
                    : FluentIcons.error_circle_24_regular,
              );
            }
          } catch (e, str) {
            logger.log(
                'Error restoring data', error: e, stackTrace: str);
            if (mounted) {
              showToast(
                context,
                context.l10n!.error,
                icon: FluentIcons.error_circle_24_regular,
              );
            }
          }
        },
      ),
      CustomBar(
        context.l10n!.importSpotifyPlaylist,
        FluentIcons.arrow_import_24_regular,
        onTap: () => context.push('/settings/importSpotifyPlaylist'),
      ),
      CustomBar(
        'Local music folders',
        FluentIcons.folder_24_filled,
        borderRadius: (!Platform.isAndroid || isFdroidBuild)
            ? commonCustomBarRadiusLast
            : BorderRadius.zero,
        onTap: () => _showLocalMusicFoldersDialog(context),
      ),
      if (Platform.isAndroid && !isFdroidBuild)
        CustomBar(
          context.l10n!.downloadAppUpdate,
          FluentIcons.arrow_download_24_regular,
          borderRadius: commonCustomBarRadiusLast,
          onTap: () => checkAppUpdates(manual: true),
        ),
    ];
  }

  void _showLocalMusicFoldersDialog(BuildContext context) {
    final folders = List<String>.from(localMusicFolders);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Local music folders'),
              content: SizedBox(
                width: double.maxFinite,
                child: folders.isEmpty
                    ? const Text(
                        'No folders selected yet. Add a folder to scan.',
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: folders.length,
                        itemBuilder: (context, index) {
                          final path = folders[index];
                          return ListTile(
                            dense: true,
                            title: Text(_folderName(path)),
                            subtitle: Text(path),
                            trailing: IconButton(
                              icon: const Icon(FluentIcons.delete_24_regular),
                              onPressed: () async {
                                setState(() {
                                  folders.removeAt(index);
                                });
                                await _saveLocalMusicFolders(folders);
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final hasPermission = await _ensureAudioPermission(context);
                    if (!hasPermission) {
                      return;
                    }
                    final path = await FilePicker.getDirectoryPath();
                    if (path == null || path.isEmpty) {
                      return;
                    }
                    if (path.startsWith('content://')) {
                      if (context.mounted) {
                        showToast(
                          context,
                          'Folder access is restricted on Android. Choose a local storage folder.',
                        );
                      }
                      return;
                    }
                    if (!folders.contains(path)) {
                      setState(() {
                        folders.add(path);
                      });
                      await _saveLocalMusicFolders(folders);
                    }
                  },
                  child: const Text('Add folder'),
                ),
                TextButton(
                  onPressed: folders.isEmpty
                      ? null
                      : () async {
                          final hasPermission = await _ensureAudioPermission(
                            context,
                          );
                          if (!hasPermission) {
                            return;
                          }
                          await _rescanLocalMusicFolders(context, folders);
                        },
                  child: const Text('Rescan'),
                ),
                TextButton(
                  onPressed: folders.isEmpty
                      ? null
                      : () async {
                          await _clearLocalMusicFolders(context);
                          setState(folders.clear);
                        },
                  child: const Text('Clear'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n!.cancel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveLocalMusicFolders(List<String> folders) async {
    localMusicFolders = List<String>.from(folders);
    await addOrUpdateData(
      'userNoBackup',
      'localMusicFolders',
      localMusicFolders,
    );
  }

  Future<void> _rescanLocalMusicFolders(
    BuildContext context,
    List<String> folders,
  ) async {
    final report = await refreshLocalSongsFromFolders(folders);
    if (context.mounted) {
      showToast(context, _localScanMessage(report, context));
    }
  }

  Future<bool> _ensureAudioPermission(BuildContext context) async {
    final hasPermission = await AudioPermissionService.hasAudioPermission();
    if (hasPermission) {
      return true;
    }

    final granted = await AudioPermissionService.requestAudioPermission();
    if (!granted && context.mounted) {
      showToast(context, 'Audio permission is required to scan local music.');
    }
    return granted;
  }

  Future<void> _clearLocalMusicFolders(BuildContext context) async {
    localMusicFolders = [];
    userLocalSongs.value = [];
    await addOrUpdateData('userNoBackup', 'localMusicFolders', []);
    await addOrUpdateData('userNoBackup', 'localSongs', userLocalSongs.value);
    if (context.mounted) {
      showToast(context, context.l10n!.settingChangedMsg);
    }
  }

  String _folderName(String path) {
    final clean = path.replaceAll(RegExp(r'[/\\]+$'), '');
    final parts = clean.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty ? parts.last : path;
  }

  String _localScanMessage(LocalScanReport report, BuildContext context) {
    if (report.found > 0) {
      return context.l10n!.playlistUpdated;
    }
    if (report.contentUriFolders > 0) {
      return Platform.isAndroid
          ? 'Folder access is restricted on Android. Choose a local storage folder.'
          : 'Folder access is restricted. Choose an accessible folder.';
    }
    if (report.missingFolders > 0) {
      return 'Selected folder is not available. Please choose another.';
    }
    if (report.errorFolders > 0) {
      return 'Unable to scan folders. Check storage permissions.';
    }
    return 'No supported audio files found in the selected folders.';
  }

  List<Widget> _aboutItems(BuildContext context) {
    return [
      CustomBar(
        context.l10n!.about,
        FluentIcons.book_information_24_regular,
        borderRadius: commonCustomBarRadius,
        onTap: () => context.push('/settings/about'),
      ),
    ];
  }

  // ─── Bottom-sheet pickers ─────────────────────────────────────────────────
  void _showAccentColorPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showCustomBottomSheet(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: availableColors.length,
          itemBuilder: (context, index) {
            final color = availableColors[index];
            final isSelected = color == primaryColorSetting;

            return GestureDetector(
              onTap: () {
                addOrUpdateData<int>(
                  'settings',
                  'accentColor',
                  color.toARGB32(),
                );
                Catchify.updateAppState(
                  context,
                  newAccentColor: color,
                  useSystemColor: false,
                );
                showToast(context, context.l10n!.accentChangeMsg);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: colorScheme.onSurface, width: 3)
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        FluentIcons.checkmark_20_filled,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  void _showThemeModePicker(BuildContext context) {
    final availableModes = [
      ThemeMode.system,
      ThemeMode.light,
      ThemeMode.dark,
    ];
    const modeIcons = [
      FluentIcons.phone_24_regular,
      FluentIcons.weather_sunny_24_regular,
      FluentIcons.weather_moon_24_regular,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableModes.length,
        itemBuilder: (context, index) {
          final mode = availableModes[index];
          final modeNames = [
            context.l10n!.themeModeSystem,
            context.l10n!.themeModeLight,
            context.l10n!.themeModeDark,
          ];

          return BottomSheetBar(
            modeNames[mode.index],
            () {
              addOrUpdateData<int>(
                  'settings', 'themeIndex', mode.index);
              Catchify.updateAppState(context, newThemeMode: mode);
              Navigator.pop(context);
            },
            themeMode == mode,
            icon: modeIcons[mode.index],
          );
        },
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final availableLanguages = appLanguages.toList();
    final activeLanguageCode =
        Localizations.localeOf(context).languageCode;
    final activeScriptCode =
        Localizations.localeOf(context).scriptCode;
    final activeLanguageFullCode = activeScriptCode != null
        ? '$activeLanguageCode-$activeScriptCode'
        : activeLanguageCode;

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableLanguages.length,
        itemBuilder: (context, index) {
          final language = availableLanguages[index];
          final newLocale = getLocaleFromLanguageCode(language);
          final newLocaleFullCode = newLocale.scriptCode != null
              ? '${newLocale.languageCode}-${newLocale.scriptCode}'
              : newLocale.languageCode;

          return BottomSheetBar(
            getLanguageDisplayName(context, language),
            () {
              addOrUpdateData<String>(
                'settings',
                'languageCode',
                newLocaleFullCode,
              );
              Catchify.updateAppState(context, newLocale: newLocale);
              showToast(context, context.l10n!.languageMsg);
              Navigator.pop(context);
            },
            activeLanguageFullCode == newLocaleFullCode,
          );
        },
      ),
    );
  }

  void _showAudioQualityPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentQuality = audioQualitySetting.value;

    final String activeLabel;
    final String activeSubLabel;
    switch (currentQuality) {
      case 'high':
        activeLabel = 'Lossless / High Quality';
        activeSubLabel = '24-bit/48 kHz • AAC 256 kbps';
        break;
      case 'medium':
        activeLabel = 'Medium Quality';
        activeSubLabel = 'AAC 128 kbps';
        break;
      default:
        activeLabel = 'Data Saver';
        activeSubLabel = 'AAC 64 kbps';
    }

    final qualityTiers = [
      (
        id: 'high',
        title: 'Lossless / High Quality',
        subtitle: 'AAC 256 kbps • Studio Fidelity (CD Quality)',
        icon: FluentIcons.speaker_2_24_filled,
      ),
      (
        id: 'medium',
        title: 'Medium Quality',
        subtitle: 'AAC 128 kbps • Balanced Performance',
        icon: FluentIcons.speaker_2_24_regular,
      ),
      (
        id: 'low',
        title: 'Data Saver',
        subtitle: 'AAC 64 kbps • Low Data Usage',
        icon: FluentIcons.speaker_1_24_regular,
      ),
    ];

    showCustomBottomSheet(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FluentIcons.headphones_sound_wave_24_regular,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n!.audioQuality,
                        style: TextStyle(
                          fontFamily: 'Unbounded',
                          fontFamilyFallback: const ['AnekTamil'],
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$activeLabel • $activeSubLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Apple Music Hardware & Codec Info Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        FluentIcons.info_16_regular,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Playback Hardware & Audio Notes:',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• High Quality & Lossless audio streams at up to 256 kbps AAC (matching Apple Music CD/Lossy fidelity).\n'
                    '• AirPods & Bluetooth headphones compress audio to AAC ~256 kbps due to Bluetooth limitations.\n'
                    '• For pure uncompressed listening above 24-bit/48 kHz, use wired headphones with an external USB DAC.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Streaming Quality:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...qualityTiers.map((item) {
              final isSelected = currentQuality == item.id;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  addOrUpdateData<String>('settings', 'audioQuality', item.id);
                  audioQualitySetting.value = item.id;
                  showToast(context, context.l10n!.audioQualityMsg);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? FluentIcons.checkmark_circle_24_filled
                            : FluentIcons.circle_24_regular,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        item.icon,
                        size: 18,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Toggle helpers ───────────────────────────────────────────────────────
  void _toggleSystemColor(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'useSystemColor', value);
    useSystemColor.value = value;
    Catchify.updateAppState(
      context,
      newAccentColor: primaryColorSetting,
      useSystemColor: value,
    );
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _togglePureBlack(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'usePureBlackColor', value);
    usePureBlackColor.value = value;
    Catchify.updateAppState(context);
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _togglePredictiveBack(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'predictiveBack', value);
    predictiveBack.value = value;
    transitionsBuilder = value
        ? const PredictiveBackPageTransitionsBuilder()
        : const CupertinoPageTransitionsBuilder();
    Catchify.updateAppState(context);
    showToast(context, context.l10n!.settingChangedMsg);
  }

  Future<void> _toggleWrapped(BuildContext context, bool value) async {
    if (!value) {
      audioHandler.resetListeningStatsSession(
        countCurrentTick: true,
        flushStats: false,
      );
      await listeningStatsService.flush();
    }

    await addOrUpdateData<bool>('settings', 'wrappedEnabled', value);
    wrappedEnabled.value = value;
    listeningStatsService.reload();
    if (value) {
      audioHandler.startListeningStatsSessionIfNeeded();
    }
    if (mounted) {
      showToast(context, context.l10n!.settingChangedMsg);
    }
  }

  void _toggleOfflineMode(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'offlineMode', value);
    offlineMode.value = value;

    // Trigger router refresh and notify about the change
    NavigationManager.refreshRouter();

    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleSponsorBlock(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'sponsorBlockSupport', value);
    sponsorBlockSupport.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAutoPlayNext(BuildContext context, bool value) {
    addOrUpdateData<bool>(
        'settings', 'playNextSongAutomatically', value);
    playNextSongAutomatically.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAutomaticUpdateChecks(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', value);
    shouldWeCheckUpdates.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleExternalRecommendations(
      BuildContext context, bool value) {
    addOrUpdateData<bool>(
        'settings', 'externalRecommendations', value);
    externalRecommendations.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String confirmationMessage,
    required VoidCallback onSubmit,
    String? submitMessage,
    bool isDangerous = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          submitMessage: submitMessage ?? context.l10n!.clear,
          confirmationMessage: confirmationMessage,
          isDangerous: isDangerous,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: () {
            Navigator.of(context).pop();
            onSubmit();
          },
        );
      },
    );
  }

  Future<void> _backupUserData(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    try {
      if (Platform.isAndroid) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              icon: Icon(
                FluentIcons.info_24_regular,
                color: colorScheme.primary,
                size: 32,
              ),
              content: Text(
                context.l10n!.folderRestrictions,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: <Widget>[
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n!.understand),
                ),
              ],
            );
          },
        );
      }
      final result = await backupData(context);
      if (mounted) {
        showToast(
          context,
          result.message,
          icon: result.success
              ? null
              : FluentIcons.error_circle_24_regular,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error backing up data',
          error: e, stackTrace: stackTrace);
      if (mounted) {
        showToast(
          context,
          context.l10n!.error,
          icon: FluentIcons.error_circle_24_regular,
        );
      }
    }
  }
}
