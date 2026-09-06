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
import 'package:catchify/main.dart' show audioHandler;
import 'package:catchify/models/lyric_line.dart';
import 'package:catchify/models/position_data.dart';

/// Displays synced lyrics with real-time highlighting and auto-scrolling.
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

  /// Optional song identifier (e.g. ytid) — reserved for future use
  final String? songId;

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> {
  late List<LyricLine> _lines;
  final ScrollController _scrollController = ScrollController();
  int _currentLineIndex = -1;
  StreamSubscription<PositionData>? _positionSub;

  // Each lyric row: a generous fixed height so multi-line text doesn't overflow.
  static const double _rowHeight = 56;

  @override
  void initState() {
    super.initState();
    _lines = LrcParser.parse(widget.lyrics);
    _subscribe();

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
  }

  @override
  void didUpdateWidget(SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _lines = LrcParser.parse(widget.lyrics);
      _currentLineIndex = -1;
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

  /// Core highlight logic — works with raw milliseconds.
  void _onPositionMs(int posMs) {
    if (!mounted) return;
    final newIndex = LrcParser.findCurrentLineIndex(_lines, posMs);

    if (newIndex != _currentLineIndex) {
      setState(() {
        _currentLineIndex = newIndex;
      });
      _scrollToLine(newIndex);
    }
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                      color: colorScheme.onSecondaryContainer
                          .withValues(alpha: 0.45),
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
