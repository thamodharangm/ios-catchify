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
 *
 *
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/thamodharangm/catchify
 */

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart' show audioHandler;
import 'package:catchify/models/lyric_line.dart';
import 'package:catchify/models/position_data.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/widgets/song_artwork.dart';

/// Full-screen synced lyrics page matching the Youtify / Apple Music aesthetic.
class LyricsPage extends StatefulWidget {
  const LyricsPage({super.key, required this.initialMetadata});

  final MediaItem initialMetadata;

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  late MediaItem _currentMetadata;
  StreamSubscription<MediaItem?>? _mediaItemSub;
  Future<String?>? _lyricsFuture;
  String? _loadedSongKey;

  @override
  void initState() {
    super.initState();
    _currentMetadata = widget.initialMetadata;
    _fetchLyricsForTrack(_currentMetadata);

    _mediaItemSub = audioHandler.mediaItem.listen((item) {
      if (item != null && item.id.isNotEmpty && item.id != _currentMetadata.id) {
        if (mounted) {
          setState(() {
            _currentMetadata = item;
            _fetchLyricsForTrack(item);
          });
        }
      }
    });
  }

  void _fetchLyricsForTrack(MediaItem metadata) {
    final songKey = '${metadata.id}_${metadata.artist}_${metadata.title}';
    if (_loadedSongKey == songKey) return;
    _loadedSongKey = songKey;
    _lyricsFuture = getSongLyrics(
      metadata.artist,
      metadata.title,
      duration: metadata.duration?.inSeconds,
    );
  }

  @override
  void dispose() {
    _mediaItemSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPureBlack = playerGradientStyle.value == 'pure_black';

    final bgColorTop = isPureBlack
        ? const Color(0xFF0F0F0F)
        : Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.28), const Color(0xFF142420));
    final bgColorBottom = isPureBlack
        ? Colors.black
        : Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.16), const Color(0xFF0F1A17));

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgColorTop, bgColorBottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: FutureBuilder<String?>(
                    future: _lyricsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading lyrics...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final rawLyrics = snapshot.data;
                      if (rawLyrics == null || rawLyrics.trim().isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FluentIcons.music_note_2_24_regular,
                                size: 52,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n!.lyricsNotAvailable,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (LrcParser.isSynced(rawLyrics)) {
                        return _SyncedLyricsBody(
                          key: ValueKey(_loadedSongKey),
                          rawLyrics: rawLyrics,
                          metadata: _currentMetadata,
                        );
                      } else {
                        return _PlainLyricsBody(
                          lyrics: rawLyrics,
                          metadata: _currentMetadata,
                        );
                      }
                    },
                  ),
                ),
                _buildBottomControls(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SongArtworkWidget(
              metadata: _currentMetadata,
              size: 44,
              borderRadius: 8,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentMetadata.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentMetadata.artist ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Powered by Lrclib',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 19,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Copy lyrics',
                    onPressed: () async {
                      final lyrics = await _lyricsFuture;
                      if (lyrics != null && lyrics.isNotEmpty) {
                        final clean = LrcParser.cleanLyrics(lyrics);
                        final toCopy = clean.isNotEmpty ? clean : lyrics;
                        await Clipboard.setData(ClipboardData(text: toCopy));
                        if (context.mounted) {
                          showToast(context, 'Lyrics copied to clipboard');
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.share_rounded,
                      size: 19,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Share lyrics',
                    onPressed: () async {
                      final lyrics = await _lyricsFuture;
                      if (lyrics != null && lyrics.isNotEmpty) {
                        final clean = LrcParser.cleanLyrics(lyrics);
                        final textToShare =
                            '${_currentMetadata.title} - ${_currentMetadata.artist}\n\n${clean.isNotEmpty ? clean : lyrics}';
                        await SharePlus.instance.share(
                          ShareParams(
                            text: textToShare,
                            subject: '${_currentMetadata.title} Lyrics',
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        StreamBuilder<PositionData>(
          stream: audioHandler.positionDataStream,
          builder: (context, snapshot) {
            final posData = snapshot.data;
            final currentMs = posData?.position.inMilliseconds.toDouble() ?? 0.0;
            final totalMs = posData?.duration.inMilliseconds.toDouble() ?? 1.0;
            final maxMs = totalMs > currentMs ? totalMs : currentMs + 1.0;

            return SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: currentMs.clamp(0.0, maxMs),
                max: maxMs,
                onChanged: (val) {
                  audioHandler.seek(Duration(milliseconds: val.toInt()));
                },
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 20),
          child: StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data?.playing ?? false;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      FluentIcons.previous_24_filled,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => audioHandler.skipToPrevious(),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () {
                      if (isPlaying) {
                        audioHandler.pause();
                      } else {
                        audioHandler.play();
                      }
                    },
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? FluentIcons.pause_24_filled : FluentIcons.play_24_filled,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(
                      FluentIcons.next_24_filled,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => audioHandler.skipToNext(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SyncedLyricsBody extends StatefulWidget {
  const _SyncedLyricsBody({
    super.key,
    required this.rawLyrics,
    required this.metadata,
  });

  final String rawLyrics;
  final MediaItem metadata;

  @override
  State<_SyncedLyricsBody> createState() => _SyncedLyricsBodyState();
}

class _SyncedLyricsBodyState extends State<_SyncedLyricsBody> {
  late List<LyricLine> _lines;
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _lineKeys = [];
  int _currentLineIndex = -1;
  StreamSubscription<PositionData>? _positionSub;
  bool _isUserScrolling = false;
  Timer? _userScrollResumeTimer;

  @override
  void initState() {
    super.initState();
    _lines = LrcParser.parse(widget.rawLyrics);
    _lineKeys.addAll(List.generate(_lines.length, (_) => GlobalKey()));

    _positionSub = audioHandler.positionDataStream.listen(_onPositionTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final pos = audioHandler.playbackState.value.position.inMilliseconds;
        _evaluatePosition(pos, forceScroll: true);
      } catch (_) {}
    });
  }

  void _onPositionTick(PositionData data) {
    _evaluatePosition(data.position.inMilliseconds);
  }

  void _evaluatePosition(int posMs, {bool forceScroll = false}) {
    if (!mounted || _lines.isEmpty) return;
    final songOffset = getLyricsOffsetForSong(widget.metadata.id);
    final idx = LrcParser.findCurrentLineIndex(
      _lines,
      posMs,
      userOffsetMs: songOffset,
    );

    if (idx != _currentLineIndex || forceScroll) {
      setState(() {
        _currentLineIndex = idx;
      });

      if (!_isUserScrolling && idx >= 0 && idx < _lineKeys.length) {
        _scrollToKey(_lineKeys[idx]);
      }
    }
  }

  void _scrollToKey(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentCtx = key.currentContext;
      if (currentCtx != null) {
        Scrollable.ensureVisible(
          currentCtx,
          alignment: 0.42,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _userScrollResumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return Center(
        child: Text(
          context.l10n!.lyricsNotAvailable,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          _isUserScrolling = true;
          _userScrollResumeTimer?.cancel();
          _userScrollResumeTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              _isUserScrolling = false;
              if (_currentLineIndex >= 0 && _currentLineIndex < _lineKeys.length) {
                _scrollToKey(_lineKeys[_currentLineIndex]);
              }
            }
          });
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        itemCount: _lines.length,
        itemBuilder: (context, index) {
          final isCurrent = index == _currentLineIndex;
          final line = _lines[index];

          return Container(
            key: _lineKeys[index],
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _isUserScrolling = false;
                setState(() => _currentLineIndex = index);
                audioHandler.seek(Duration(milliseconds: line.timeInMs));
                _scrollToKey(_lineKeys[index]);
              },
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                style: isCurrent
                    ? const TextStyle(
                        fontFamilyFallback: ['AnekTamil', 'Roboto'],
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.35,
                        letterSpacing: 0.2,
                      )
                    : TextStyle(
                        fontFamilyFallback: const ['AnekTamil', 'Roboto'],
                        fontSize: 18.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.38),
                        height: 1.35,
                      ),
                child: Text(
                  line.text,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlainLyricsBody extends StatelessWidget {
  const _PlainLyricsBody({
    required this.lyrics,
    required this.metadata,
  });

  final String lyrics;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final clean = LrcParser.cleanLyrics(lyrics);
    final display = clean.isNotEmpty ? clean : lyrics;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Text(
        display,
        style: TextStyle(
          fontFamilyFallback: const ['AnekTamil', 'Roboto'],
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.88),
          height: 1.8,
        ),
      ),
    );
  }
}
