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

    // Add empty first line so nothing is highlighted until first line is sung
    lines.add(LyricLine(timeInMs: 0, text: ''));

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
            if (msStr.length == 2) {
              ms = int.parse(msStr) * 10;
            } else if (msStr.length == 3) {
              ms = int.parse(msStr);
            }
          }

          final timeInMs = (minutes * 60 + seconds) * 1000 + ms;
          lines.add(LyricLine(timeInMs: timeInMs, text: text));
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

  /// Finds the current line index based on position.
  /// Returns the last line whose timestamp is <= positionMs.
  static int findCurrentLineIndex(List<LyricLine> lines, int positionMs) {
    if (lines.isEmpty) return 0;

    const delayMs = 300;
    final adjustedMs = positionMs - delayMs;

    for (var i = lines.length - 1; i >= 0; i--) {
      if (lines[i].timeInMs <= adjustedMs) {
        return i;
      }
    }

    return 0;
  }
}
