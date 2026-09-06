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

/// Represents a single line of lyrics with its timestamp
class LyricLine {
  LyricLine({required this.timeInMs, required this.text});

  /// Timestamp in milliseconds
  final int timeInMs;

  /// Lyric text for this line
  final String text;

  @override
  String toString() => 'LyricLine($timeInMs, $text)';
}

/// Parser for LRC format lyrics
class LrcParser {
  /// Parses LRC format lyrics into a list of [LyricLine]
  ///
  /// LRC format example:
  /// ```
  /// [00:12.34]First line
  /// [00:15.67]Second line
  /// [01:23.45]Third line
  /// ```
  static List<LyricLine> parse(String lyrics) {
    final lines = <LyricLine>[];

    if (lyrics.isEmpty) return lines;

    // Check for standard LRC metadata [offset:+/-xxx] in milliseconds
    final offsetPattern = RegExp(
      r'\[offset:\s*([+-]?\d+)\s*\]',
      caseSensitive: false,
    );
    final offsetMatch = offsetPattern.firstMatch(lyrics);
    final lrcOffset = offsetMatch != null
        ? (int.tryParse(offsetMatch.group(1) ?? '0') ?? 0)
        : 0;

    final linePattern = RegExp(
      r'^((?:\[\d{1,3}:\d{2}(?:[.:]\d{2,3})?\])+)\s*(.*)$',
      multiLine: true,
    );
    final tagPattern = RegExp(
      r'\[(\d{1,3}):(\d{2})(?:[.:](\d{2,3}))?\]',
    );

    for (final lineMatch in linePattern.allMatches(lyrics)) {
      final tags = lineMatch.group(1)!;
      final text = lineMatch.group(2)!.trim();

      if (text.isEmpty) continue;

      for (final tagMatch in tagPattern.allMatches(tags)) {
        try {
          final minutes = int.parse(tagMatch.group(1)!);
          final seconds = int.parse(tagMatch.group(2)!);
          final msStr = tagMatch.group(3);

          var ms = 0;
          if (msStr != null) {
            if (msStr.length == 1) {
              ms = int.parse(msStr) * 100;
            } else if (msStr.length == 2) {
              ms = int.parse(msStr) * 10;
            } else if (msStr.length == 3) {
              ms = int.parse(msStr);
            }
          }

          final rawTimeInMs = (minutes * 60 + seconds) * 1000 + ms;
          // In standard LRC, positive offset causes lyrics to appear earlier
          final timeInMs = rawTimeInMs - lrcOffset;
          lines.add(
            LyricLine(timeInMs: timeInMs >= 0 ? timeInMs : 0, text: text),
          );
        } catch (_) {
          continue;
        }
      }
    }

    // Sort lines by timestamp
    lines.sort((a, b) => a.timeInMs.compareTo(b.timeInMs));

    return lines;
  }

  /// Checks if the lyrics are in LRC format (synced)
  static bool isSynced(String lyrics) {
    return RegExp(
      r'\[\d{1,3}:\d{2}(?:[.:]\d{2,3})?\]',
    ).hasMatch(lyrics);
  }

  /// Finds the current line index based on playback position and optional user offset.
  /// Returns the matching index, or -1 if the playback position is before the first line.
  static int findCurrentLineIndex(
    List<LyricLine> lines,
    int positionMs, {
    int userOffsetMs = 0,
  }) {
    if (lines.isEmpty) return -1;

    final adjustedMs = positionMs + userOffsetMs;

    for (var i = lines.length - 1; i >= 0; i--) {
      if (lines[i].timeInMs <= adjustedMs) {
        return i;
      }
    }

    return -1;
  }
}
