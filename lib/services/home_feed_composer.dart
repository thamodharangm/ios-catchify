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

import 'package:catchify/models/home_section.dart';

/// Pure composition layer for the Catchify Home Feed.
///
/// Responsible for:
/// 1. Composing remote shelves, mood sections, and local Catchify sections.
/// 2. Applying high-intent listening hierarchy (Quick picks -> Discovery -> Long tail).
/// 3. In-section item deduplication without cross-shelf contamination.
/// 4. Preserving unknown/future YouTube Music shelves in their relative remote order.
/// 5. Dropping empty sections.
class HomeFeedComposer {
  const HomeFeedComposer._();

  /// Composes a unified, ordered list of [HomeSection]s.
  ///
  /// This method is pure and does NOT perform any network or disk operations.
  static List<HomeSection> compose({
    required List<HomeSection> remoteSections,
    HomeSection? moodSection,
    HomeSection? favoritesSection,
    HomeSection? recapSection,
  }) {
    // 1. Collect all candidates
    final candidates = <_OrderedSection>[];

    // Mood section (if present, takes top priority for mood-focused listening)
    if (moodSection != null && moodSection.isNotEmpty) {
      final deduped = _deduplicateSection(moodSection);
      if (deduped.isNotEmpty) {
        candidates.add(_OrderedSection(
          section: deduped,
          priority: 0,
          originalIndex: 0,
        ));
      }
    }

    // Remote sections
    for (var i = 0; i < remoteSections.length; i++) {
      final section = remoteSections[i];
      if (section.isEmpty) continue;

      final deduped = _deduplicateSection(section);
      if (deduped.isEmpty) continue;

      final priority = _resolveSemanticPriority(deduped, i);
      candidates.add(_OrderedSection(
        section: deduped,
        priority: priority,
        originalIndex: i,
      ));
    }

    // Local sections (Back to favorites, Recap)
    if (favoritesSection != null && favoritesSection.isNotEmpty) {
      final deduped = _deduplicateSection(favoritesSection);
      if (deduped.isNotEmpty) {
        candidates.add(_OrderedSection(
          section: deduped,
          priority: 100,
          originalIndex: 1000,
        ));
      }
    }

    if (recapSection != null && recapSection.isNotEmpty) {
      final deduped = _deduplicateSection(recapSection);
      if (deduped.isNotEmpty) {
        candidates.add(_OrderedSection(
          section: deduped,
          priority: 105,
          originalIndex: 1001,
        ));
      }
    }

    // 2. Stable sort by priority, preserving original order for equal priorities
    candidates.sort((a, b) {
      final priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) return priorityComparison;
      return a.originalIndex.compareTo(b.originalIndex);
    });

    // 3. Return final ordered sections
    return candidates.map((c) => c.section).toList();
  }

  /// Deduplicates items within the same shelf by item ID.
  ///
  /// Items across different shelves are intentionally preserved.
  static HomeSection _deduplicateSection(HomeSection section) {
    if (section.contents.length <= 1) return section;

    final seenIds = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final item in section.contents) {
      final id = _extractItemId(item);
      if (id.isNotEmpty) {
        if (seenIds.add(id)) {
          deduped.add(item);
        }
      } else {
        // If no stable ID exists, keep the item
        deduped.add(item);
      }
    }

    if (deduped.length == section.contents.length) {
      return section;
    }

    return HomeSection(
      title: section.title,
      subtitle: section.subtitle,
      type: section.type,
      contents: deduped,
      isChunkedSongs: section.isChunkedSongs,
      browseId: section.browseId,
      params: section.params,
    );
  }

  /// Extracts a stable identification key for deduplication.
  static String _extractItemId(Map<String, dynamic> item) {
    final ytid = item['ytid']?.toString()?.trim();
    if (ytid != null && ytid.isNotEmpty && ytid != 'null') return ytid;

    final id = item['id']?.toString()?.trim();
    if (id != null && id.isNotEmpty && id != 'null') return id;

    final browseId = item['browseId']?.toString()?.trim();
    if (browseId != null && browseId.isNotEmpty && browseId != 'null') {
      return browseId;
    }

    final title = item['title']?.toString()?.trim() ?? '';
    final artist = item['artist']?.toString()?.trim() ?? '';
    if (title.isNotEmpty) return '$title::$artist';

    return '';
  }

  /// Resolves the semantic priority for ordering shelves.
  ///
  /// Hierarchy:
  /// - 10: Quick picks / Immediate listening / Start radio / Listen again
  /// - 20: Personalized songs / Mixed for you / For you
  /// - 30: Continue listening / Recently played
  /// - 40: Trending songs / Top charts / Popular now
  /// - 50: New releases / Fresh tracks
  /// - 60: Albums / Recommended albums
  /// - 70: Artists / Top artists
  /// - 80: Featured playlists / Curated playlists
  /// - 90: Community playlists / Discovered playlists
  /// - 1000 + originalIndex: Unknown/new future YouTube Music shelves (retains remote order)
  static int _resolveSemanticPriority(HomeSection section, int originalIndex) {
    final title = section.title.toLowerCase();
    final subtitle = (section.subtitle ?? '').toLowerCase();
    final combined = '$title $subtitle';

    // 1. Immediate / High-intent listening
    if (combined.contains('quick pick') ||
        combined.contains('start radio') ||
        combined.contains('listen again') ||
        combined.contains('forgotten favorite') ||
        combined.contains('similar to')) {
      return 10;
    }

    // 2. Personalized music
    if (combined.contains('mixed for you') ||
        combined.contains('for you') ||
        combined.contains('recommended') ||
        combined.contains('more like')) {
      // If it's specifically an album shelf for you, route to albums priority
      if (section.type == HomeContentType.albums || combined.contains('album')) {
        return 60;
      }
      // If it's specifically an artist shelf for you, route to artists priority
      if (section.type == HomeContentType.artists || combined.contains('artist')) {
        return 70;
      }
      return 20;
    }

    // 3. Continue listening / recently played
    if (combined.contains('continue listening') ||
        combined.contains('recently played') ||
        combined.contains('play it again')) {
      return 30;
    }

    // 4. Trending & Charts
    if (combined.contains('trending') ||
        combined.contains('top track') ||
        combined.contains('chart') ||
        combined.contains('popular') ||
        combined.contains('hits')) {
      return 40;
    }

    // 5. New releases
    if (combined.contains('new release') ||
        combined.contains('fresh track') ||
        combined.contains('latest')) {
      return 50;
    }

    // 6. Albums
    if (section.type == HomeContentType.albums ||
        combined.contains('album') ||
        combined.contains('singles and eps')) {
      return 60;
    }

    // 7. Artists
    if (section.type == HomeContentType.artists ||
        combined.contains('artist') ||
        combined.contains('singers')) {
      return 70;
    }

    // 8. Featured Playlists
    if (section.type == HomeContentType.playlists &&
        (combined.contains('playlist') || combined.contains('featured'))) {
      return 80;
    }

    // 9. Community & Discovered Playlists
    if (combined.contains('community') ||
        combined.contains('public playlist') ||
        combined.contains('discovered')) {
      return 90;
    }

    // If type is known songs and didn't match specific titles, treat as high-priority discovery
    if (section.type == HomeContentType.songs) {
      return 45;
    }

    // Unknown or new future shelves: preserve their original remote relative order!
    return 1000 + originalIndex;
  }

  /// Formats the section order into a clean diagnostic log.
  static String formatHomeOrder(List<HomeSection> sections) {
    final sb = StringBuffer('\n[HOME_ORDER]\n');
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i];
      final num = (i + 1).toString().padLeft(2, '0');
      sb.writeln('$num. title="${s.title}"');
      sb.writeln('    type=${s.type.name}');
      sb.writeln('    items=${s.contents.length}\n');
    }
    return sb.toString();
  }
}

class _OrderedSection {
  final HomeSection section;
  final int priority;
  final int originalIndex;

  const _OrderedSection({
    required this.section,
    required this.priority,
    required this.originalIndex,
  });
}
