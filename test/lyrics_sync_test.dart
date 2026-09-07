import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/models/lyric_line.dart';
import 'package:catchify/services/lrclib_service.dart';
import 'package:catchify/widgets/lyrics_display_widget.dart';

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

    test('LrcParser.parse handles 1, 2, 3, and >3 decimal digits correctly', () {
      const lrcVariousDecimals = '''
[00:10.5]1 digit decimal (500ms)
[00:20.25]2 digits decimal (250ms)
[00:30.125]3 digits decimal (125ms)
[00:40.1234]4 digits decimal (123ms truncated)
''';
      final lines = LrcParser.parse(lrcVariousDecimals);
      expect(lines.length, 4);
      expect(lines[0].timeInMs, 10500);
      expect(lines[1].timeInMs, 20250);
      expect(lines[2].timeInMs, 30125);
      expect(lines[3].timeInMs, 40123);
    });
  });

  group('LrcLibService tests', () {
    test('isChannelLabel identifies record labels and channels correctly', () {
      expect(LrcLibService.isChannelLabel('Sony Music South'), true);
      expect(LrcLibService.isChannelLabel('Think Music India'), true);
      expect(LrcLibService.isChannelLabel('T-Series'), true);
      expect(LrcLibService.isChannelLabel('Saregama Tamil'), true);
      expect(LrcLibService.isChannelLabel('Zee Music South'), true);
      expect(LrcLibService.isChannelLabel('Tips Official'), true);
      expect(LrcLibService.isChannelLabel('Sun TV'), true);
      expect(LrcLibService.isChannelLabel('Star Vijay'), true);

      // Real music artists should not be flagged as channel labels
      expect(LrcLibService.isChannelLabel('Anirudh Ravichander'), false);
      expect(LrcLibService.isChannelLabel('A.R. Rahman'), false);
      expect(LrcLibService.isChannelLabel('Hiphop Tamizha'), false);
      expect(LrcLibService.isChannelLabel('Yuvan Shankar Raja'), false);
      expect(LrcLibService.isChannelLabel('Santhosh Narayanan'), false);
      expect(LrcLibService.isChannelLabel('Sid Sriram'), false);
    });
  });

  group('LyricsDisplayWidget attribution tests', () {
    testWidgets('PlainLyricsWidget displays "Lyrics powered by LRCLIB"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlainLyricsWidget(lyrics: 'First line of lyrics\nSecond line of lyrics'),
          ),
        ),
      );

      expect(find.text('Lyrics powered by LRCLIB'), findsOneWidget);
      expect(find.text('First line of lyrics\nSecond line of lyrics'), findsOneWidget);
    });

    testWidgets('SyncedLyricsWidget renders lyrics and "Lyrics powered by LRCLIB"', (tester) async {
      const lrc = '''
[00:05.00]Line 1
[00:10.00]Line 2
''';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncedLyricsWidget(
              lyrics: lrc,
              positionDataStream: const Stream.empty(),
            ),
          ),
        ),
      );

      expect(find.text('Line 1'), findsOneWidget);
      expect(find.text('Line 2'), findsOneWidget);
      expect(find.text('Lyrics powered by LRCLIB'), findsOneWidget);
    });
  });
}
