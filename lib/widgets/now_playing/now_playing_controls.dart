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

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/flutter_bottom_sheet.dart';
import 'package:catchify/widgets/now_playing/marquee_text_widget.dart';
import 'package:catchify/widgets/playback_icon_button.dart';
import 'package:catchify/widgets/position_slider.dart';

class NowPlayingControls extends StatelessWidget {
  const NowPlayingControls({
    super.key,
    required this.size,
    required this.audioId,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.metadata,
  });

  final Size size;
  final dynamic audioId;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = size.width > 800;

    final titleFontSize = getResponsiveTitleFontSize(size);
    final artistFontSize = getResponsiveArtistFontSize(size);
    final canOpenArtist = _canOpenArtist(metadata);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 280;
        final isVeryCompact = availableHeight < 200;

        final spacing = isVeryCompact
            ? 2.0
            : isCompact
            ? 4.0
            : 8.0;
        final iconScale = isVeryCompact
            ? 0.65
            : isCompact
            ? 0.75
            : 1.0;
        final fontScale = isCompact ? 0.9 : 1.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCompact) const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 24,
                vertical: spacing,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MarqueeTextWidget(
                    text: metadata.title,
                    fontColor: colorScheme.secondary,
                    fontSize: titleFontSize * fontScale,
                    fontWeight: FontWeight.bold,
                  ),
                  SizedBox(height: spacing),
                  if (metadata.artist != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canOpenArtist
                          ? () => _openArtistPage(context, metadata)
                          : null,
                      child: MarqueeTextWidget(
                        text: metadata.artist!,
                        fontColor: colorScheme.onSurfaceVariant,
                        fontSize: artistFontSize * fontScale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (!isVeryCompact) ...[
                    const SizedBox(height: 6),
                    const AudioQualityBadge(),
                  ],
                ],
              ),
            ),
            if (!isCompact) const Spacer(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 400 : constraints.maxWidth,
              ),
              child: const PositionSlider(),
            ),
            SizedBox(height: spacing),
            PlayerControlButtons(
              metadata: metadata,
              iconSize: adjustedIconSize * iconScale,
              miniIconSize: adjustedMiniIconSize * iconScale,
            ),
            if (!isCompact) const Spacer(),
          ],
        );
      },
    );
  }

  bool _canOpenArtist(MediaItem metadata) {
    final artist = metadata.artist?.trim() ?? '';
    final artistId = metadata.extras?['artistId']?.toString().trim() ?? '';
    final sourceSongId = metadata.extras?['ytid']?.toString().trim() ?? '';

    return !offlineMode.value &&
        (artist.isNotEmpty || artistId.isNotEmpty || sourceSongId.isNotEmpty);
  }

  void _openArtistPage(BuildContext context, MediaItem metadata) {
    final artist = metadata.artist?.trim() ?? '';
    final artistId = metadata.extras?['artistId']?.toString().trim() ?? '';
    final sourceSongId = metadata.extras?['ytid']?.toString().trim() ?? '';
    final videoAuthor =
        metadata.extras?['videoAuthor']?.toString().trim() ?? '';
    final lookup = artistId.isNotEmpty
        ? artistId
        : artist.isNotEmpty
        ? artist
        : sourceSongId;

    if (lookup.isEmpty) return;

    final router = GoRouter.of(context);
    final basePath = _artistRouteBasePath(context);
    final artistData = {
      'ytid': artistId.isNotEmpty ? artistId : lookup,
      if (artist.isNotEmpty) 'title': artist,
      if (sourceSongId.isNotEmpty) 'sourceSongId': sourceSongId,
      if (videoAuthor.isNotEmpty) 'videoAuthor': videoAuthor,
      'source': 'youtube-artist',
      'isArtist': true,
      'list': [],
    };

    Navigator.of(context).pop();
    unawaited(
      router.push(
        '$basePath/artist/${Uri.encodeComponent(lookup)}',
        extra: artistData,
      ),
    );
  }

  String _artistRouteBasePath(BuildContext context) {
    try {
      final currentPath = GoRouterState.of(context).uri.path;
      if (currentPath.startsWith(NavigationManager.searchPath)) {
        return NavigationManager.searchPath;
      }
      if (currentPath.startsWith(NavigationManager.libraryPath)) {
        return NavigationManager.libraryPath;
      }
    } catch (_) {}

    return NavigationManager.homePath;
  }
}

class PlayerControlButtons extends StatelessWidget {
  const PlayerControlButtons({
    super.key,
    required this.metadata,
    required this.iconSize,
    required this.miniIconSize,
  });
  final MediaItem metadata;
  final double iconSize;
  final double miniIconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveIconSize = screenWidth < 360 ? iconSize * 0.85 : iconSize;
    final responsiveMiniIconSize = screenWidth < 360
        ? miniIconSize * 0.85
        : miniIconSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isTight = maxWidth < 360;
        final isUltraTight = maxWidth < 320;

        final horizontalPadding = isUltraTight
            ? 10.0
            : isTight
            ? 14.0
            : 20.0;
        final buttonSpacing = isUltraTight
            ? 6.0
            : isTight
            ? 10.0
            : screenWidth < 360
            ? 8.0
            : 16.0;
        final minButtonSize = isUltraTight
            ? 38.0
            : isTight
            ? 42.0
            : 46.0;
        final buttonPadding = EdgeInsets.all(
          isUltraTight
              ? 6.0
              : isTight
              ? 8.0
              : 10.0,
        );

        final buttonConstraints = BoxConstraints(
          minWidth: minButtonSize,
          minHeight: minButtonSize,
        );

        final controlIconSize =
            responsiveIconSize *
            (isUltraTight
                ? 0.75
                : isTight
                ? 0.85
                : 0.92);
        final miniControlSize =
            responsiveMiniIconSize *
            (isUltraTight
                ? 0.8
                : isTight
                ? 0.9
                : 1.0);
        final playPadding = EdgeInsets.all(
          responsiveIconSize *
              (isUltraTight
                  ? 0.30
                  : isTight
                  ? 0.36
                  : 0.45),
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: <Widget>[
              _buildShuffleButton(
                context,
                colorScheme,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
              SizedBox(width: buttonSpacing),
              Expanded(
                child: Center(
                  child: StreamBuilder<List<MediaItem>>(
                    stream: audioHandler.queue,
                    builder: (context, snapshot) {
                      return ValueListenableBuilder<AudioServiceRepeatMode>(
                        valueListenable: repeatNotifier,
                        builder: (_, repeatMode, __) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    FluentIcons.previous_24_regular,
                                    color: colorScheme.onSurface,
                                  ),
                                  tooltip: context.l10n!.skipToPrevious,
                                  constraints: buttonConstraints,
                                  iconSize: controlIconSize * 0.65,
                                  onPressed: () =>
                                      audioHandler.skipToPrevious(),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: buttonPadding,
                                    minimumSize: Size(
                                      minButtonSize,
                                      minButtonSize,
                                    ),
                                  ),
                                ),
                                SizedBox(width: buttonSpacing),
                                PlaybackIconButton(
                                  iconColor: colorScheme.onPrimary,
                                  backgroundColor: colorScheme.primary,
                                  iconSize: controlIconSize,
                                  padding: playPadding,
                                ),
                                SizedBox(width: buttonSpacing),
                                ValueListenableBuilder<bool>(
                                  valueListenable: playNextSongAutomatically,
                                  builder: (_, autoPlay, __) {
                                    final canGoNext = audioHandler.hasNext ||
                                        repeatMode != AudioServiceRepeatMode.none ||
                                        autoPlay;
                                    return IconButton(
                                      icon: Icon(
                                        FluentIcons.next_24_regular,
                                        color: canGoNext
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurface.withValues(
                                                alpha: 0.3,
                                              ),
                                      ),
                                      tooltip: context.l10n!.skipToNext,
                                      constraints: buttonConstraints,
                                      iconSize: controlIconSize * 0.65,
                                      onPressed: canGoNext
                                          ? () => repeatMode ==
                                                  AudioServiceRepeatMode.one
                                              ? audioHandler.playAgain()
                                              : audioHandler.skipToNext()
                                          : null,
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        disabledBackgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        padding: buttonPadding,
                                        minimumSize: Size(
                                          minButtonSize,
                                          minButtonSize,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              SizedBox(width: buttonSpacing),
              _buildRepeatButton(
                context,
                colorScheme,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShuffleButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: shuffleNotifier,
      builder: (_, value, __) {
        return IconButton(
          icon: Icon(
            value
                ? FluentIcons.arrow_shuffle_24_filled
                : FluentIcons.arrow_shuffle_24_regular,
            color: value ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
          tooltip: context.l10n!.shuffle,
          iconSize: size,
          constraints: buttonConstraints,
          padding: buttonPadding,
          style: IconButton.styleFrom(
            backgroundColor: value
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            audioHandler.setShuffleMode(
              value
                  ? AudioServiceShuffleMode.none
                  : AudioServiceShuffleMode.all,
            );
          },
        );
      },
    );
  }

  Widget _buildRepeatButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return StreamBuilder<List<MediaItem>>(
      stream: audioHandler.queue,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? [];
        return ValueListenableBuilder<AudioServiceRepeatMode>(
          valueListenable: repeatNotifier,
          builder: (_, repeatMode, __) {
            final isActive = repeatMode != AudioServiceRepeatMode.none;

            return IconButton(
              icon: Icon(
                repeatMode == AudioServiceRepeatMode.one
                    ? FluentIcons.arrow_repeat_1_24_filled
                    : isActive
                    ? FluentIcons.arrow_repeat_all_24_filled
                    : FluentIcons.arrow_repeat_all_24_regular,
                color: isActive
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              tooltip: context.l10n!.repeat,
              iconSize: size,
              constraints: buttonConstraints,
              padding: buttonPadding,
              style: IconButton.styleFrom(
                backgroundColor: isActive
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final AudioServiceRepeatMode newMode;
                if (repeatMode == AudioServiceRepeatMode.none) {
                  newMode = queue.length <= 1
                      ? AudioServiceRepeatMode.one
                      : AudioServiceRepeatMode.all;
                } else if (repeatMode == AudioServiceRepeatMode.all) {
                  newMode = AudioServiceRepeatMode.one;
                } else {
                  newMode = AudioServiceRepeatMode.none;
                }
                repeatNotifier.value = newMode;
                audioHandler.setRepeatMode(newMode);
              },
            );
          },
        );
      },
    );
  }
}

/// Apple Music style Audio Quality badge displayed under artist name
class AudioQualityBadge extends StatelessWidget {
  const AudioQualityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<String>(
      valueListenable: audioQualitySetting,
      builder: (context, quality, _) {
        final String label;
        final String subLabel;
        switch (quality) {
          case 'high':
            label = 'Lossless';
            subLabel = '24-bit/48 kHz • AAC 256 kbps';
            break;
          case 'medium':
            label = 'High Quality';
            subLabel = 'AAC 128 kbps';
            break;
          default:
            label = 'Standard';
            subLabel = 'AAC 64 kbps';
        }

        return GestureDetector(
          onTap: () => _showAudioQualityInfoSheet(
            context,
            quality,
            label,
            subLabel,
          ),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.16),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.speaker_2_16_filled,
                  size: 11,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4.5),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    fontFamilyFallback: const ['AnekTamil'],
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _showAudioQualityInfoSheet(
  BuildContext context,
  String currentQuality,
  String label,
  String subLabel,
) {
  final colorScheme = Theme.of(context).colorScheme;

  showCustomBottomSheet(
    context,
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio Quality',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$label • $subLabel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info Card explaining Lossless / AAC / Hardware / AirPods
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
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
                        'Playback Hardware & Quality Notes:',
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
          const SizedBox(height: 18),
          Text(
            'Select Streaming Quality:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...[
            ('high', 'Lossless / High Quality', 'AAC 256 kbps (Best Fidelity)'),
            ('medium', 'Medium Quality', 'AAC 128 kbps (Balanced)'),
            ('low', 'Data Saver', 'AAC 64 kbps (Saves Data)'),
          ].map((item) {
            final isSelected = currentQuality == item.$1;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                addOrUpdateData<String>('settings', 'audioQuality', item.$1);
                audioQualitySetting.value = item.$1;
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? FluentIcons.checkmark_circle_24_filled
                          : FluentIcons.circle_24_regular,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
