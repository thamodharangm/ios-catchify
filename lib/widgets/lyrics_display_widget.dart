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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/main.dart' show audioHandler;
import 'package:catchify/models/lyric_line.dart';
import 'package:catchify/models/position_data.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/settings_manager.dart';

/// Displays synced lyrics with real-time highlighting and auto-scrolling
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
  late final ScrollController _scrollController;
  int _currentLineIndex = -1;
  bool _showSyncControl = false;

  @override
  void initState() {
    super.initState();
    _lines = LrcParser.parse(widget.lyrics);
    _scrollController = ScrollController();
    lyricsOffsetNotifier.addListener(_onOffsetChanged);
  }

  void _onOffsetChanged() {
    if (mounted) {
      setState(() {
        _currentLineIndex = -1;
      });
    }
  }

  @override
  void didUpdateWidget(SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _lines = LrcParser.parse(widget.lyrics);
      _currentLineIndex = -1;
    }
  }

  @override
  void dispose() {
    lyricsOffsetNotifier.removeListener(_onOffsetChanged);
    _scrollController.dispose();
    super.dispose();
  }

  static const double _itemExtent = 52;

  void _scrollToCurrentLine(int lineIndex) {
    if (lineIndex < 0 || _lines.isEmpty || !_scrollController.hasClients) return;

    // Center the current line in the viewport
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset =
        lineIndex * _itemExtent - (viewportHeight / 2) + (_itemExtent / 2);
    final maxScroll = _scrollController.position.maxScrollExtent;
    final safeOffset = targetOffset.clamp(0.0, maxScroll);

    if ((safeOffset - _scrollController.offset).abs() > 1) {
      _scrollController.animateTo(
        safeOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _updateOffset(int deltaMs, {bool reset = false}) {
    final newOffset =
        reset ? 0 : (lyricsOffsetNotifier.value + deltaMs).clamp(-5000, 5000);
    lyricsOffsetNotifier.value = newOffset;
    addOrUpdateData<int>('settings', 'lyricsOffsetMs', newOffset);
    setState(() {
      _currentLineIndex = -1;
    });
  }

  Widget _buildSyncControls(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final offset = lyricsOffsetNotifier.value;

    if (!_showSyncControl) {
      return Material(
        color: offset == 0
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.6)
            : colorScheme.primaryContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _showSyncControl = true),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.timer_24_regular,
                  size: 15,
                  color: offset == 0
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onPrimaryContainer,
                ),
                if (offset != 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${offset > 0 ? '+' : ''}${(offset / 1000).toStringAsFixed(1)}s',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final sign = offset > 0 ? '+' : '';
    final displaySec = (offset / 1000).toStringAsFixed(1);

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Delay button (-0.1s: lyrics later)
            IconButton(
              icon: const Icon(Icons.remove, size: 16),
              tooltip: 'Delay lyrics (-0.1s)',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _updateOffset(-100),
            ),
            // Offset label (tap to reset to 0.0s)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _updateOffset(0, reset: true),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  offset == 0 ? 'Sync: 0.0s' : '$sign${displaySec}s',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: offset == 0
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                  ),
                ),
              ),
            ),
            // Advance button (+0.1s: lyrics earlier)
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              tooltip: 'Advance lyrics (+0.1s)',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _updateOffset(100),
            ),
            // Close button
            IconButton(
              icon: const Icon(Icons.close, size: 14),
              tooltip: 'Close sync',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 28),
              onPressed: () => setState(() => _showSyncControl = false),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return _buildEmptyState(context);
    }

    return Stack(
      children: [
        StreamBuilder<PositionData>(
          stream: widget.positionDataStream,
          builder: (context, snapshot) {
            final positionMs = snapshot.data?.position.inMilliseconds ?? 0;
            final currentLineIndex = LrcParser.findCurrentLineIndex(
              _lines,
              positionMs,
              userOffsetMs: lyricsOffsetNotifier.value,
            );

            // Only update if line actually changed
            if (currentLineIndex != _currentLineIndex) {
              _currentLineIndex = currentLineIndex;
              Future.microtask(() => _scrollToCurrentLine(currentLineIndex));
            }

            return _buildLyricsList(context);
          },
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _buildSyncControls(context),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note,
            size: 48,
            color: colorScheme.onSecondaryContainer.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No lyrics available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _lines.length,
      itemExtent: _itemExtent,
      itemBuilder: (context, index) {
        final isCurrentLine = index == _currentLineIndex;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (_lines[index].timeInMs > 0) {
              audioHandler.seek(Duration(milliseconds: _lines[index].timeInMs));
            }
          },
          child: Align(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: _getLyricTextStyle(isCurrentLine, colorScheme),
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

  TextStyle _getLyricTextStyle(bool isCurrentLine, ColorScheme colorScheme) {
    if (isCurrentLine) {
      return TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colorScheme.primary,
        height: 1.3,
        letterSpacing: 0.3,
      );
    }

    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: colorScheme.onSecondaryContainer.withValues(alpha: 0.5),
      height: 1.3,
    );
  }
}

/// Displays plain text lyrics (non-synced)
class PlainLyricsWidget extends StatelessWidget {
  const PlainLyricsWidget({super.key, required this.lyrics});

  /// Plain text lyrics
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

/// Smart lyrics widget that automatically chooses between synced and plain display
class LyricsDisplayWidget extends StatelessWidget {
  const LyricsDisplayWidget({
    super.key,
    required this.lyrics,
    required this.positionDataStream,
  });

  /// Lyrics text (can be LRC format or plain text)
  final String lyrics;

  /// Stream providing current playback position
  final Stream<PositionData> positionDataStream;

  @override
  Widget build(BuildContext context) {
    // Check if lyrics are in LRC (synced) format
    if (LrcParser.isSynced(lyrics)) {
      return SyncedLyricsWidget(
        lyrics: lyrics,
        positionDataStream: positionDataStream,
      );
    }

    // Fallback to plain text display
    return PlainLyricsWidget(lyrics: lyrics);
  }
}
