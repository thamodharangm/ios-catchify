/*
 *     Copyright (C) 2026 Thamodharan Ganesan
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
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/theme/app_themes.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/widgets/custom_bar.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _toggleOfflineMode(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'offlineMode', value);
    offlineMode.value = value;
    NavigationManager.refreshRouter();
    showToast(context, context.l10n!.settingChangedMsg);
    setState(() {});
  }

  Widget _sectionTitle(String title, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 16, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: primaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;

    var themeLabel = 'System';
    if (themeMode == ThemeMode.dark) {
      themeLabel = 'Dark';
    } else if (themeMode == ThemeMode.light) {
      themeLabel = 'Light';
    }

    var playerStyleLabel = 'Dynamic';
    if (playerGradientStyle.value == 'pure_black') {
      playerStyleLabel = 'Pure Black';
    } else if (playerGradientStyle.value == 'blurred') {
      playerStyleLabel = 'Frosted';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n!.settings),
      ),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            // ── QUICK TOGGLES ──
            ValueListenableBuilder<bool>(
              valueListenable: offlineMode,
              builder: (_, value, __) {
                return CustomBar(
                  context.l10n!.offlineMode,
                  FluentIcons.cloud_off_24_regular,
                  description: context.l10n!.offlineModeDescription,
                  borderRadius: commonCustomBarRadius,
                  trailing: Switch(
                    value: value,
                    onChanged: (v) => _toggleOfflineMode(context, v),
                  ),
                );
              },
            ),

            // ── SECTION 1: CUSTOMIZATION & PLAYBACK ──
            _sectionTitle('PREFERENCES & EXPERIENCE', primaryColor),
            CustomBar(
              context.l10n?.themeAndAppUI ?? 'Theme & Appearance',
              FluentIcons.paint_brush_24_filled,
              description: 'Accent colors, dark/AMOLED mode & languages',
              borderRadius: commonCustomBarRadiusFirst,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: primaryColorSetting,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    themeLabel,
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    FluentIcons.chevron_right_24_regular,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              onTap: () async {
                await context.push('/settings/theme');
                if (mounted) setState(() {});
              },
            ),
            CustomBar(
              context.l10n?.musicAndPlayback ?? 'Music & Playback',
              FluentIcons.music_note_2_24_filled,
              description: 'Streaming bitrates, equalizer & playback options',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${streamingQualityWifi.value.toUpperCase()} / ${streamingQualityMobile.value.toUpperCase()}',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    FluentIcons.chevron_right_24_regular,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              onTap: () async {
                await context.push('/settings/playback');
                if (mounted) setState(() {});
              },
            ),
            CustomBar(
              'Now Playing & Visuals',
              FluentIcons.color_line_24_filled,
              description: 'Player background gradient & lyrics sync offset',
              borderRadius: commonCustomBarRadiusLast,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playerStyleLabel,
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    FluentIcons.chevron_right_24_regular,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              onTap: () async {
                await context.push('/settings/player');
                if (mounted) setState(() {});
              },
            ),

            // ── SECTION 2: DATA & STORAGE ──
            _sectionTitle('DATA & STORAGE', primaryColor),
            CustomBar(
              'Storage & Cache',
              FluentIcons.storage_24_filled,
              description: 'Manage disk cache, auto-caching & data cleanup',
              borderRadius: commonCustomBarRadiusFirst,
              trailing: Icon(
                FluentIcons.chevron_right_24_regular,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () => context.push('/settings/storage'),
            ),
            CustomBar(
              context.l10n?.backupAndRestore ?? 'Backup & Restore',
              FluentIcons.cloud_sync_24_filled,
              description: 'Export/import data, Spotify playlists & local folders',
              borderRadius: commonCustomBarRadiusLast,
              trailing: Icon(
                FluentIcons.chevron_right_24_regular,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () => context.push('/settings/backup'),
            ),

            // ── SECTION 3: ABOUT & INFO ──
            _sectionTitle('ABOUT & SYSTEM', primaryColor),
            CustomBar(
              context.l10n!.about,
              FluentIcons.info_24_filled,
              description: 'App version, open source license & updates',
              borderRadius: commonCustomBarRadiusFirst,
              trailing: Icon(
                FluentIcons.chevron_right_24_regular,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () => context.push('/settings/about'),
            ),
            CustomBar(
              '${context.l10n!.copyLogs} (${logger.getLogCount()})',
              FluentIcons.error_circle_24_regular,
              description: 'Copy debug logs to clipboard for troubleshooting',
              onTap: () async {
                final message = await logger.copyLogs(context);
                if (context.mounted) showToast(context, message);
              },
            ),
            CustomBar(
              context.l10n!.licenses,
              FluentIcons.document_24_regular,
              borderRadius: commonCustomBarRadiusLast,
              trailing: Icon(
                FluentIcons.chevron_right_24_regular,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () => context.push('/settings/license'),
            ),

            const SizedBox(height: 24),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }
}
