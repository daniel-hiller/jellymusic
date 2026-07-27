import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/jelly_colors.dart';
import '../core/util/format.dart';
import '../core/util/item_x.dart';
import '../providers/player_providers.dart';
import '../providers/providers.dart';
import 'cover_art.dart';
import 'item_menu.dart';

/// A single track row: title + artist, duration, and — depending on context —
/// either a track number (album view) or the album cover art (flat song
/// lists) as the leading widget. A trailing overflow menu exposes playback,
/// playlist and flag actions; [onRemoveFromPlaylist], when set, adds a
/// "remove" entry (used inside playlist detail). Highlights when it's the
/// current track.
class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.trailingIndex,
    this.showArtist = true,
    this.showCoverArt = false,
    this.onRemoveFromPlaylist,
  });

  final JellyfinItem song;
  final VoidCallback onTap;
  final int? trailingIndex;
  final bool showArtist;

  /// Show the album cover as the leading widget instead of a track number.
  /// Use in flat lists (all songs, search, favourites) where a per-album
  /// track number would be meaningless.
  final bool showCoverArt;

  /// When provided, the overflow menu gains a "remove from playlist" entry.
  final VoidCallback? onRemoveFromPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentMediaItemProvider).value;
    final isCurrent = current?.id == song.id;
    final playing = ref.watch(isPlayingProvider);

    final nowPlayingIcon = Icon(
      playing ? Icons.equalizer_rounded : Icons.pause_rounded,
      color: context.colors.accent,
      size: 20,
    );

    final Widget leading;
    if (showCoverArt) {
      final url =
          ref.watch(jellyfinServiceProvider).primaryImageUrl(song, size: 96);
      leading = SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverArt(url: url, size: 44, borderRadius: 6),
            if (isCurrent)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: nowPlayingIcon),
              ),
          ],
        ),
      );
    } else {
      leading = SizedBox(
        width: 28,
        child: Center(
          child: isCurrent
              ? nowPlayingIcon
              : Text(
                  '${trailingIndex ?? song.indexNumber ?? ''}',
                  style: TextStyle(color: context.colors.textTertiary),
                ),
        ),
      );
    }

    return ItemMenu(
      item: song,
      onRemoveFromPlaylist: onRemoveFromPlaylist,
      builder: (context, menu) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: leading,
        title: Text(
          song.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color:
                isCurrent ? context.colors.accent : context.colors.textPrimary,
          ),
        ),
        subtitle: showArtist
            ? Text(
                song.trackArtistLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.colors.textSecondary),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (menu.isFavorite)
              Padding(
                padding: EdgeInsets.only(right: 6),
                child:
                    Icon(Icons.favorite, size: 15, color: context.colors.accent),
              ),
            Text(
              Format.durationMs(song.durationMs),
              style: TextStyle(color: context.colors.textTertiary),
            ),
            menu.button,
          ],
        ),
      ),
    );
  }
}
