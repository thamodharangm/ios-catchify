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
/// Responsibilities:
/// 1. Strictly preserves raw YouTube Music server shelf order 1:1 without artificial priority sorting.
/// 2. In-section item deduplication without cross-shelf contamination.
/// 3. Injects local personalization (mood, personalized sections, favorites, recap) at clean, dedicated slots:
///    - [moodSection] (if present) placed at the top (index 0) for active mood listening.
///    - [personalizedSections] (e.g. "Made for you") placed after the primary shelf (or at slot 0 if no remote shelves),
///      preserving the remaining remote feed in its exact server order.
///    - [favoritesSection] and [recapSection] placed at designated positions.
/// 4. Dropping empty sections.
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
    List<HomeSection>? personalizedSections,
  }) {
    final result = <HomeSection>[];

    // 1. Mood section: if present, takes top priority for mood-focused listening
    if (moodSection != null && moodSection.isNotEmpty) {
      final deduped = _deduplicateSection(moodSection);
      if (deduped.isNotEmpty) {
        result.add(deduped);
      }
    }

    // 2. Prepare local personalized sections (e.g. "Made for you", "Because you listened to...")
    final validPersonalized = <HomeSection>[];
    if (personalizedSections != null && personalizedSections.isNotEmpty) {
      for (final sec in personalizedSections) {
        if (sec.isEmpty) continue;
        final deduped = _deduplicateSection(sec);
        if (deduped.isNotEmpty) {
          validPersonalized.add(deduped);
        }
      }
    }

    // 3. Prepare remote sections, strictly preserving server order
    final validRemote = <HomeSection>[];
    for (final sec in remoteSections) {
      if (sec.isEmpty) continue;
      final deduped = _deduplicateSection(sec);
      if (deduped.isNotEmpty) {
        validRemote.add(deduped);
      }
    }

    // 4. Assemble feed:
    // If we have remote sections:
    // - Insert first remote section (the server's top hero / primary carousel)
    // - Insert local personalized sections (e.g. "Made for you") right after the hero carousel
    // - Insert local favorites / recap if present
    // - Append remaining remote sections in their exact native server order
    if (validRemote.isNotEmpty) {
      result.add(validRemote.first);

      // Insert local personalization right after the primary shelf
      result.addAll(validPersonalized);

      if (favoritesSection != null && favoritesSection.isNotEmpty) {
        final deduped = _deduplicateSection(favoritesSection);
        if (deduped.isNotEmpty) result.add(deduped);
      }
      if (recapSection != null && recapSection.isNotEmpty) {
        final deduped = _deduplicateSection(recapSection);
        if (deduped.isNotEmpty) result.add(deduped);
      }

      // Append remaining remote sections in their exact native server order
      if (validRemote.length > 1) {
        result.addAll(validRemote.sublist(1));
      }
    } else {
      // Remote feed empty or offline mode: show personalized & local sections
      result.addAll(validPersonalized);
      if (favoritesSection != null && favoritesSection.isNotEmpty) {
        final deduped = _deduplicateSection(favoritesSection);
        if (deduped.isNotEmpty) result.add(deduped);
      }
      if (recapSection != null && recapSection.isNotEmpty) {
        final deduped = _deduplicateSection(recapSection);
        if (deduped.isNotEmpty) result.add(deduped);
      }
    }

    return result;
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
