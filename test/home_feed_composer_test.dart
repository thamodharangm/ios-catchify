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
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/thamodharangm/catchify
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/models/home_section.dart';
import 'package:catchify/services/home_feed_composer.dart';

void main() {
  group('HomeFeedComposer Tests', () {
    test('Strictly preserves original remote shelf order 1:1 without semantic sorting', () {
      final inputShelves = [
        const HomeSection(
          title: 'Dancing on your own',
          subtitle: 'DANCE YOUR STRESS AWAY',
          type: HomeContentType.playlists,
          contents: [{'id': 'pl_1', 'title': 'Dance Playlist'}],
        ),
        const HomeSection(
          title: 'Trending community playlists',
          subtitle: 'DISCOVERED PLAYLISTS',
          type: HomeContentType.playlists,
          contents: [{'id': 'pl_comm_1', 'title': 'Comm Playlist'}],
        ),
        const HomeSection(
          title: 'Hindi Hits',
          subtitle: 'POPULAR HINDI',
          type: HomeContentType.playlists,
          contents: [{'id': 'pl_hindi', 'title': 'Hindi Playlist'}],
        ),
        const HomeSection(
          title: 'New releases',
          subtitle: 'FRESH TRACKS',
          type: HomeContentType.albums,
          contents: [{'id': 'alb_1', 'title': 'New Album'}],
        ),
        const HomeSection(
          title: 'Quick picks',
          subtitle: 'START RADIO FROM A SONG',
          type: HomeContentType.songs,
          contents: [{'id': 'song_1', 'title': 'Quick Song'}],
          isChunkedSongs: true,
        ),
        const HomeSection(
          title: 'Trending songs for you',
          subtitle: 'POPULAR NOW',
          type: HomeContentType.songs,
          contents: [{'id': 'song_2', 'title': 'Trending Track'}],
        ),
      ];

      final composed = HomeFeedComposer.compose(
        remoteSections: inputShelves,
      );

      // The server produced order must be preserved in exact order:
      expect(composed.length, equals(6));
      expect(composed[0].title, equals('Dancing on your own'));
      expect(composed[1].title, equals('Trending community playlists'));
      expect(composed[2].title, equals('Hindi Hits'));
      expect(composed[3].title, equals('New releases'));
      expect(composed[4].title, equals('Quick picks'));
      expect(composed[5].title, equals('Trending songs for you'));
    });

    test('Injects local personalized sections cleanly without disturbing remote order', () {
      final inputShelves = [
        const HomeSection(
          title: 'Dancing on your own',
          type: HomeContentType.playlists,
          contents: [{'id': 'pl_1', 'title': 'Dance Playlist'}],
        ),
        const HomeSection(
          title: 'Quick picks',
          type: HomeContentType.songs,
          contents: [{'id': 'song_1', 'title': 'Quick Song'}],
        ),
        const HomeSection(
          title: 'Trending songs for you',
          type: HomeContentType.songs,
          contents: [{'id': 'song_2', 'title': 'Trending Track'}],
        ),
      ];

      final personalizedShelves = [
        const HomeSection(
          title: 'Made for you',
          type: HomeContentType.songs,
          contents: [{'id': 'mfy_1', 'title': 'Personalized Song'}],
        ),
      ];

      final composed = HomeFeedComposer.compose(
        remoteSections: inputShelves,
        personalizedSections: personalizedShelves,
      );

      expect(composed.length, equals(4));
      // First shelf: server hero shelf
      expect(composed[0].title, equals('Dancing on your own'));
      // Second shelf: local personalization inserted
      expect(composed[1].title, equals('Made for you'));
      // Remaining shelves: server order intact
      expect(composed[2].title, equals('Quick picks'));
      expect(composed[3].title, equals('Trending songs for you'));
    });

    test('Deduplicates items within the same shelf by ytid/id', () {
      const shelfWithDuplicates = HomeSection(
        title: 'Quick picks',
        type: HomeContentType.songs,
        contents: [
          {'ytid': 'song_A', 'title': 'Song A'},
          {'ytid': 'song_B', 'title': 'Song B'},
          {'ytid': 'song_A', 'title': 'Song A Duplicate'},
          {'ytid': 'song_C', 'title': 'Song C'},
        ],
      );

      final composed = HomeFeedComposer.compose(
        remoteSections: [shelfWithDuplicates],
      );

      expect(composed.length, equals(1));
      expect(composed.first.contents.length, equals(3));
      expect(composed.first.contents.map((c) => c['ytid']).toList(),
          equals(['song_A', 'song_B', 'song_C']));
    });

    test('Allows same item across different meaningful shelves', () {
      const shelf1 = HomeSection(
        title: 'Quick picks',
        type: HomeContentType.songs,
        contents: [
          {'ytid': 'song_shared', 'title': 'Shared Song'},
        ],
      );

      const shelf2 = HomeSection(
        title: 'Trending songs for you',
        type: HomeContentType.songs,
        contents: [
          {'ytid': 'song_shared', 'title': 'Shared Song'},
        ],
      );

      final composed = HomeFeedComposer.compose(
        remoteSections: [shelf1, shelf2],
      );

      expect(composed.length, equals(2));
      expect(composed[0].contents.first['ytid'], equals('song_shared'));
      expect(composed[1].contents.first['ytid'], equals('song_shared'));
    });

    test('Prunes empty sections', () {
      const emptyShelf = HomeSection(
        title: 'Empty Shelf',
        type: HomeContentType.songs,
        contents: [],
      );
      const validShelf = HomeSection(
        title: 'Quick picks',
        type: HomeContentType.songs,
        contents: [{'ytid': 'valid_1', 'title': 'Valid'}],
      );

      final composed = HomeFeedComposer.compose(
        remoteSections: [emptyShelf, validShelf],
      );

      expect(composed.length, equals(1));
      expect(composed.first.title, equals('Quick picks'));
    });

    test('Places mood section at the top when provided', () {
      const moodSection = HomeSection(
        title: 'Party playlists',
        type: HomeContentType.playlists,
        contents: [{'id': 'pl_party', 'title': 'Party Hits'}],
      );
      const remoteShelf = HomeSection(
        title: 'Quick picks',
        type: HomeContentType.songs,
        contents: [{'ytid': 's1', 'title': 'Song 1'}],
      );

      final composed = HomeFeedComposer.compose(
        remoteSections: [remoteShelf],
        moodSection: moodSection,
      );

      expect(composed.length, equals(2));
      expect(composed[0].title, equals('Party playlists'));
      expect(composed[1].title, equals('Quick picks'));
    });

    test('Formats diagnostic home order string correctly', () {
      final sections = [
        const HomeSection(
          title: 'Quick picks',
          type: HomeContentType.songs,
          contents: [{'id': '1'}],
        ),
        const HomeSection(
          title: 'Trending',
          type: HomeContentType.songs,
          contents: [{'id': '2'}, {'id': '3'}],
        ),
      ];

      final log = HomeFeedComposer.formatHomeOrder(sections);
      expect(log, contains('[HOME_ORDER]'));
      expect(log, contains('01. title="Quick picks"'));
      expect(log, contains('type=songs'));
      expect(log, contains('items=1'));
      expect(log, contains('02. title="Trending"'));
      expect(log, contains('items=2'));
    });
  });
}
