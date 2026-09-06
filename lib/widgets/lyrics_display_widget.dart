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
import 'package:catchify/services/settings_manager.dart'
    show lyricsOffsetNotifier;

/// Displays synced lyrics with real-time highlighting and auto-scrolling.
///
/// Uses a direct stream subscription (not StreamBuilder inside build) to avoid
/// the Flutter anti-pattern of rebuilding the whole widget tree on every position
/// tick. Line changes trigger targeted setState calls only when the active line
/// index actually changes.
class SyncedLyricsWidget extends StatefulWidget {
  const SyncedLyricsWidget({
    super.key,
    required this.lyrics,
    required this.positionDataStream,
  });

  /// Raw LRC format lyrics string
  final String lyrics;

  /// Stream providing current playback position
  final Stream<PositionData> positionDataStream;

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> {
  late List<LyricLine> _lines;
  final ScrollController _scrollController = ScrollController();
  int _currentLineIndex = -1;
  StreamSubscription<PositionData>? _positionSub;

  // Each lyric row: a generous fixed height so Tamil/Hindi multi-byte lines
  // don't overflow. Using a key-per-index for precise scroll targeting.
  static const double _rowHeight = 56;

  @override
  void initState() {
    super.initState();
    _lines = LrcParser.parse(widget.lyrics);
    _subscribe();
  }

  @override
  void didUpdateWidget(SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _lines = LrcParser.parse(widget.lyrics);
      _currentLineIndex = -1;
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

  void _onPositionUpdate(PositionData data) {
    if (!mounted) return;
    final posMs = data.position.inMilliseconds;
    // Apply the user-configured offset from Settings (lyricsOffsetNotifier).
    // Positive offset → lyrics appear earlier (increase posMs so we jump ahead in the line list).
    final newIndex = LrcParser.findCurrentLineIndex(
      _lines,
      posMs,
      userOffsetMs: lyricsOffsetNotifier.value,
    );

    if (newIndex != _currentLineIndex) {
      // Capture old index BEFORE setState so _scrollToLine gets the new index
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

    // Use jumpTo for the first two lines — avoids animating before the scroll
    // extent is fully computed (which causes incorrect final positions).
    // For all other lines, animate smoothly.
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
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      physics: const BouncingScrollPhysics(),
      child: Text(
        lyrics,
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
  });

  final String lyrics;
  final Stream<PositionData> positionDataStream;

  @override
  Widget build(BuildContext context) {
    if (LrcParser.isSynced(lyrics)) {
      return SyncedLyricsWidget(
        lyrics: lyrics,
        positionDataStream: positionDataStream,
      );
    }
    return PlainLyricsWidget(lyrics: lyrics);
  }
}
