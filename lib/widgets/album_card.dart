import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/jelly_colors.dart';
import '../core/util/item_x.dart';
import '../providers/providers.dart';
import 'cover_art.dart';
import 'item_menu.dart';

/// A tappable album tile (cover + title + artist) for grids and rows. Also
/// carries artists, whose cards look the same; the context menu adapts to
/// whichever kind it was given.
///
/// The cover sizes itself to the available width via [AspectRatio], so the
/// card fits its grid cell instead of overflowing. Pass [width] to pin the
/// card's width (used in the home shelves' horizontal lists); leave it null
/// to let the card fill its grid cell.
class AlbumCard extends ConsumerWidget {
  const AlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.width,
  });

  final JellyfinItem album;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(jellyfinServiceProvider);
    final url = service.primaryImageUrl(album, size: 320);

    final card = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CoverArt(url: url, borderRadius: 8),
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              album.albumArtistLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );

    final menu = ItemMenu(item: album, builder: (context, _) => card);
    return width == null ? menu : SizedBox(width: width, child: menu);
  }
}
