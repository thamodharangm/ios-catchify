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
 *
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/thamodharangm/catchify
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/utilities/artwork_provider.dart';

class ArtistCard extends StatefulWidget {
  const ArtistCard({
    super.key,
    required this.artist,
    this.avatarSize = 88.0,
    this.cardWidth = 104.0,
  });

  final Map<String, dynamic> artist;
  final double avatarSize;
  final double cardWidth;

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = widget.artist['title']?.toString() ?? context.l10n!.artist;
    final image = widget.artist['image']?.toString();
    final artistId =
        widget.artist['ytid']?.toString() ?? widget.artist['title']?.toString() ?? '';

    return SizedBox(
      width: widget.cardWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          if (artistId.isEmpty) return;
          context.push(
            '/home/artist/${Uri.encodeComponent(artistId)}',
            extra: widget.artist,
          );
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: _pressed ? 0.94 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: widget.avatarSize,
                  height: widget.avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: image != null && image.isNotEmpty
                        ? Image(
                            image: ArtworkProvider.get(image),
                            width: widget.avatarSize,
                            height: widget.avatarSize,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildFallback(colorScheme),
                          )
                        : _buildFallback(colorScheme),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n!.artist,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.80),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(ColorScheme colorScheme) {
    return Container(
      width: widget.avatarSize,
      height: widget.avatarSize,
      color: colorScheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          FluentIcons.person_24_filled,
          size: widget.avatarSize * 0.45,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
