import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/models/lyric_line.dart';

void main() {
  group('LrcParser tests', () {
    test('parses standard LRC lyrics accurately without fake empty line', () {
      const lrc = '''
[00:12.50]First line of the song
[00:15.00]Second line of the song
[01:02.30]Third line of the song
''';

      final lines = LrcParser.parse(lrc);
      expect(lines.length, 3);
      expect(lines[0].text, 'First line of the song');
      expect(lines[0].timeInMs, 12500);
      expect(lines[1].text, 'Second line of the song');
      expect(lines[1].timeInMs, 15000);
      expect(lines[2].text, 'Third line of the song');
      expect(lines[2].timeInMs, 62300);
    });

    test('parses [offset:+/-xxx] tag and shifts timestamps appropriately', () {
      // Positive offset means lyrics should appear earlier (timeInMs decreases)
      const lrcWithPositiveOffset = '''
[offset:+500]
[00:10.00]Line with +500ms offset
''';
      final linesPos = LrcParser.parse(lrcWithPositiveOffset);
      expect(linesPos.length, 1);
      expect(linesPos[0].timeInMs, 9500); // 10000 - 500

      // Negative offset means lyrics should appear later (timeInMs increases)
      const lrcWithNegativeOffset = '''
[offset:-300]
[00:10.00]Line with -300ms offset
''';
      final linesNeg = LrcParser.parse(lrcWithNegativeOffset);
      expect(linesNeg.length, 1);
      expect(linesNeg[0].timeInMs, 10300); // 10000 - (-300)
    });

    test('findCurrentLineIndex returns -1 before first line begins', () {
      final lines = [
        LyricLine(timeInMs: 10000, text: 'First line'),
        LyricLine(timeInMs: 15000, text: 'Second line'),
      ];

      // At 5000ms (before first line at 10000ms)
      final index = LrcParser.findCurrentLineIndex(lines, 5000);
      expect(index, -1);
    });

    test('findCurrentLineIndex accurately identifies active line on exact time', () {
      final lines = [
        LyricLine(timeInMs: 10000, text: 'First line'),
        LyricLine(timeInMs: 15000, text: 'Second line'),
      ];

      // At exactly 10000ms
      expect(LrcParser.findCurrentLineIndex(lines, 10000), 0);
      // At 12000ms (between line 0 and line 1)
      expect(LrcParser.findCurrentLineIndex(lines, 12000), 0);
      // At 15000ms (line 1 begins)
      expect(LrcParser.findCurrentLineIndex(lines, 15000), 1);
      // At 20000ms (after line 1)
      expect(LrcParser.findCurrentLineIndex(lines, 20000), 1);
    });

    test('findCurrentLineIndex with userOffsetMs shifts timing in real time', () {
      final lines = [
        LyricLine(timeInMs: 10000, text: 'First line'),
        LyricLine(timeInMs: 15000, text: 'Second line'),
      ];

      // At 9800ms, line 0 hasn't started yet with 0 offset
      expect(LrcParser.findCurrentLineIndex(lines, 9800), -1);

      // With userOffsetMs = +300ms (lyrics advance / appear earlier)
      // adjustedMs becomes 9800 + 300 = 10100ms >= 10000ms
      expect(
        LrcParser.findCurrentLineIndex(lines, 9800, userOffsetMs: 300),
        0,
      );

      // At 10100ms, line 0 is active with 0 offset
      expect(LrcParser.findCurrentLineIndex(lines, 10100), 0);

      // With userOffsetMs = -300ms (lyrics delay / appear later)
      // adjustedMs becomes 10100 - 300 = 9800ms < 10000ms
      expect(
        LrcParser.findCurrentLineIndex(lines, 10100, userOffsetMs: -300),
        -1,
      );
    });

    test('LrcParser.parse strips timestamps like [02:40:03] and word-sync tags from line text', () {
      const lrcWithDuplicateAndWordTags = '''
[02:40:03] [02:40:03] Kanmani Anbodu Kadhalan
 [02:45:10] Naan Naanaga <02:45:20> Illai
[02:50:00]Unnai Kaanum Varai [02:50:00]
''';
      final lines = LrcParser.parse(lrcWithDuplicateAndWordTags);
      expect(lines.length, 3);
      expect(lines[0].text, 'Kanmani Anbodu Kadhalan');
      expect(lines[0].text.contains('['), false);
      expect(lines[1].text, 'Naan Naanaga  Illai');
      expect(lines[1].text.contains('<'), false);
      expect(lines[2].text, 'Unnai Kaanum Varai');
      expect(lines[2].text.contains('['), false);
    });

    test('LrcParser.cleanLyrics strips all timestamps and metadata tags for plain display', () {
      const raw = '''
[ti:Song Title]
[ar:Artist Name]
[offset:+300]
[00:12.50]First line
[02:40:03] Second line with timestamp
[02:45:00] [02:45:00] Third line with double timestamp
Fourth line with <02:45:10> word-sync
''';
      final cleaned = LrcParser.cleanLyrics(raw);
      expect(cleaned.contains('['), false);
      expect(cleaned.contains(']'), false);
      expect(cleaned.contains('<'), false);
      expect(cleaned.contains('>'), false);
      expect(cleaned.contains('First line'), true);
      expect(cleaned.contains('Second line with timestamp'), true);
      expect(cleaned.contains('Third line with double timestamp'), true);
      expect(cleaned.contains('Fourth line with  word-sync'), true);
    });
  });
}
