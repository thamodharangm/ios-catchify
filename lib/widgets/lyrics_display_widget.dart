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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:catchify/main.dart' show audioHandler;
import 'package:catchify/models/lyric_line.dart';
import 'package:catchify/models/position_data.dart';
import 'package:catchify/services/settings_manager.dart'
    show
        lyricsOffsetNotifier,
        activeSongLyricsOffsetNotifier,
        getLyricsOffsetForSong,
        setLyricsOffsetForSong,
        resetLyricsOffsetForSong,
        hasCustomLyricsOffsetForSong;

/// Displays synced lyrics with real-time highlighting, auto-scrolling, and
/// per-song interactive timing adjustment.
class SyncedLyricsWidget extends StatefulWidget {
  const SyncedLyricsWidget({
    super.key,
    required this.lyrics,
    required this.positionDataStream,
    this.songId,
  });

  /// Raw LRC format lyrics string
  final String lyrics;

  /// Stream providing current playback position
  final Stream<PositionData> positionDataStream;

  /// Optional song identifier (e.g. ytid) to store and load per-song offset
  final String? songId;

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> {
  late List<LyricLine> _lines;
  final ScrollController _scrollController = ScrollController();
  int _currentLineIndex = -1;
  StreamSubscription<PositionData>? _positionSub;

  // Tracks the most recently seen position so we can re-snap when the user
  // changes the lyrics offset without waiting for a new position tick.
  int _lastPositionMs = 0;

  // Toggle for interactive on-screen sync adjustment controls
  bool _expandedSyncControls = false;

  // Each lyric row: a generous fixed height so multi-line text doesn't overflow.
  static const double _rowHeight = 56;

  @override
  void initState() {
    super.initState();
    _lines = LrcParser.parse(widget.lyrics);
    _subscribe();

    activeSongLyricsOffsetNotifier.value = getLyricsOffsetForSong(widget.songId);

    // Snap to the correct line immediately when lyrics first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final currentPos = audioHandler.playbackState.value.position;
        _onPositionMs(currentPos.inMilliseconds);
      } catch (_) {
        // audioHandler may not be available in unit tests; ignore silently.
      }
    });

    // Listen to both global and per-song offset changes
    lyricsOffsetNotifier.addListener(_onOffsetChanged);
    activeSongLyricsOffsetNotifier.addListener(_onOffsetChanged);
  }

  @override
  void didUpdateWidget(SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      activeSongLyricsOffsetNotifier.value = getLyricsOffsetForSong(widget.songId);
    }
    if (oldWidget.lyrics != widget.lyrics) {
      _lines = LrcParser.parse(widget.lyrics);
      _currentLineIndex = -1;
      _lastPositionMs = 0;
      // Re-snap to correct position for the new lyrics set.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          final currentPos = audioHandler.playbackState.value.position;
          _onPositionMs(currentPos.inMilliseconds);
        } catch (_) {}
      });
    }
    if (oldWidget.positionDataStream != widget.positionDataStream) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    _positionSub = widget.positionDataStream.listen(_onPositionUpdate);
  }

  void _unsubscribe() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// Called on every position-stream tick.
  void _onPositionUpdate(PositionData data) {
    _onPositionMs(data.position.inMilliseconds);
  }

  /// Core highlight logic — works with raw milliseconds so it can be called
  /// both from the position stream and directly (initial snap / offset change).
  void _onPositionMs(int posMs) {
    if (!mounted) return;
    _lastPositionMs = posMs;
    final effectiveOffset = getLyricsOffsetForSong(widget.songId);
    final newIndex = LrcParser.findCurrentLineIndex(
      _lines,
      posMs,
      userOffsetMs: effectiveOffset,
    );

    if (newIndex != _currentLineIndex) {
      setState(() {
        _currentLineIndex = newIndex;
      });
      _scrollToLine(newIndex);
    }
  }

  /// Called when the user adjusts the lyrics offset.
  void _onOffsetChanged() {
    if (!mounted) return;
    setState(() {});
    _onPositionMs(_lastPositionMs);
  }

  void _adjustOffset(int deltaMs) {
    HapticFeedback.selectionClick();
    final current = getLyricsOffsetForSong(widget.songId);
    final next = (current + deltaMs).clamp(-15000, 15000);
    setLyricsOffsetForSong(widget.songId, next);
  }

  void _resetOffset() {
    HapticFeedback.mediumImpact();
    resetLyricsOffsetForSong(widget.songId);
  }

  void _scrollToLine(int index) {
    if (index < 0 || !_scrollController.hasClients) return;
    final position = _scrollController.position;

    // Target: center the active line in the visible area
    final viewportHeight = position.viewportDimension;
    final target =
        (index * _rowHeight) - (viewportHeight / 2) + (_rowHeight / 2);
    final safeTarget = target.clamp(0.0, position.maxScrollExtent);

    if (index <= 1) {
      _scrollController.jumpTo(safeTarget);
    } else if ((safeTarget - position.pixels).abs() > 2) {
      _scrollController.animateTo(
        safeTarget,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    lyricsOffsetNotifier.removeListener(_onOffsetChanged);
    activeSongLyricsOffsetNotifier.removeListener(_onOffsetChanged);
    _unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) return _buildEmpty(context);
    return _buildList(context);
  }

  Widget _buildEmpty(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSecondaryContainer;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 48, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No lyrics available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 24, bottom: 52, left: 16, right: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _lines.length,
            itemExtent: _rowHeight,
            itemBuilder: (context, index) {
              final isCurrent = index == _currentLineIndex;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final ms = _lines[index].timeInMs;
                  audioHandler.seek(Duration(milliseconds: ms));
                },
                child: Align(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: isCurrent
                        ? TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                            height: 1.3,
                            letterSpacing: 0.3,
                          )
                        : TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: colorScheme.onSecondaryContainer.withValues(alpha: 0.45),
                            height: 1.3,
                          ),
                    child: Text(
                      _lines[index].text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(
            child: _buildSyncControls(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncControls(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final offsetMs = getLyricsOffsetForSong(widget.songId);
    final hasCustom = hasCustomLyricsOffsetForSong(widget.songId);
    final sign = offsetMs > 0 ? '+' : '';
    final secStr = (offsetMs / 1000).toStringAsFixed(1);

    if (!_expandedSyncControls) {
      // Collapsed compact capsule
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _expandedSyncControls = true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasCustom
                  ? colorScheme.primary.withValues(alpha: 0.6)
                  : colorScheme.outline.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 13,
                color: hasCustom ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 5),
              Text(
                offsetMs == 0 ? 'Sync' : 'Sync: $sign${secStr}s',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: hasCustom ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Expanded interactive quick-sync adjustment bar
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasCustom
              ? colorScheme.primary.withValues(alpha: 0.7)
              : colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepButton(
            label: '-0.5s',
            onTap: () => _adjustOffset(-500),
            colorScheme: colorScheme,
          ),
          _buildStepButton(
            label: '-0.1s',
            onTap: () => _adjustOffset(-100),
            colorScheme: colorScheme,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$sign${secStr}s',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: hasCustom ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
                if (hasCustom) ...[
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: _resetOffset,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: colorScheme.error.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildStepButton(
            label: '+0.1s',
            onTap: () => _adjustOffset(100),
            colorScheme: colorScheme,
          ),
          _buildStepButton(
            label: '+0.5s',
            onTap: () => _adjustOffset(500),
            colorScheme: colorScheme,
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _expandedSyncControls = false);
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorScheme.surface.withValues(alpha: 0.7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

/// Displays plain (non-synced) lyrics as scrollable text
class PlainLyricsWidget extends StatelessWidget {
  const PlainLyricsWidget({super.key, required this.lyrics});

  final String lyrics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cleanLyricsText = LrcParser.cleanLyrics(lyrics);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      physics: const BouncingScrollPhysics(),
      child: Text(
        cleanLyricsText.isNotEmpty ? cleanLyricsText : lyrics,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSecondaryContainer,
          height: 1.7,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Automatically selects between synced and plain lyrics display
class LyricsDisplayWidget extends StatelessWidget {
  const LyricsDisplayWidget({
    super.key,
    required this.lyrics,
    required this.positionDataStream,
    this.songId,
  });

  final String lyrics;
  final Stream<PositionData> positionDataStream;
  final String? songId;

  @override
  Widget build(BuildContext context) {
    if (LrcParser.isSynced(lyrics)) {
      return SyncedLyricsWidget(
        lyrics: lyrics,
        positionDataStream: positionDataStream,
        songId: songId,
      );
    }
    return PlainLyricsWidget(lyrics: lyrics);
  }
}

