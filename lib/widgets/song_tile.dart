import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/jelly_colors.dart';
import '../core/util/format.dart';
import '../core/util/item_x.dart';
import '../features/library/playlist_actions.dart';
import '../l10n/app_localizations.dart';
import '../providers/player_providers.dart';
import '../providers/providers.dart';
import 'cover_art.dart';

/// A single track row: title + artist, duration, and — depending on context —
/// either a track number (album view) or the album cover art (flat song
/// lists) as the leading widget. A trailing overflow menu exposes the
/// favourite toggle and "add to playlist"; [onRemoveFromPlaylist], when set,
/// adds a "remove" entry (used inside playlist detail). Highlights when it's
/// the current track.
class SongTile extends ConsumerStatefulWidget {
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
  ConsumerState<SongTile> createState() => _SongTileState();
}

class _SongTileState extends ConsumerState<SongTile> {
  /// Local favourite state so toggling doesn't require a per-tile network
  /// read; seeded from the item and updated optimistically.
  bool? _favOverride;

  bool get _isFavorite => _favOverride ?? widget.song.isFavorite;

  Future<void> _toggleFavorite() async {
    final next = !_isFavorite;
    setState(() => _favOverride = next);
    try {
      await ref
          .read(musicRepositoryProvider)
          .setFavorite(widget.song.id, next);
    } catch (_) {
      if (mounted) setState(() => _favOverride = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final song = widget.song;
    final current = ref.watch(currentMediaItemProvider).value;
    final isCurrent = current?.id == song.id;
    final playing = ref.watch(isPlayingProvider);

    final nowPlayingIcon = Icon(
      playing ? Icons.equalizer_rounded : Icons.pause_rounded,
      color: context.colors.accent,
      size: 20,
    );

    final Widget leading;
    if (widget.showCoverArt) {
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
                  '${widget.trailingIndex ?? song.indexNumber ?? ''}',
                  style: TextStyle(color: context.colors.textTertiary),
                ),
        ),
      );
    }

    return ListTile(
      onTap: widget.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: leading,
      title: Text(
        song.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isCurrent ? context.colors.accent : context.colors.textPrimary,
        ),
      ),
      subtitle: widget.showArtist
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
          if (_isFavorite)
            Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.favorite, size: 15, color: context.colors.accent),
            ),
          Text(
            Format.durationMs(song.durationMs),
            style: TextStyle(color: context.colors.textTertiary),
          ),
          _SongMenu(
            l: l,
            isFavorite: _isFavorite,
            onToggleFavorite: _toggleFavorite,
            onPlayNext: () {
              ref.read(playerControllerProvider).playNext([song]);
              _toast(context, l.toastPlayNext);
            },
            onAddToQueue: () {
              ref.read(playerControllerProvider).addToQueue([song]);
              _toast(context, l.toastAddedToQueue);
            },
            onAddToPlaylist: () =>
                showAddToPlaylistSheet(context, ref, itemIds: [song.id]),
            onRemoveFromPlaylist: widget.onRemoveFromPlaylist,
          ),
        ],
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _SongMenu extends StatelessWidget {
  const _SongMenu({
    required this.l,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onPlayNext,
    required this.onAddToQueue,
    required this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
  });

  final AppLocalizations l;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onPlayNext;
  final VoidCallback onAddToQueue;
  final VoidCallback onAddToPlaylist;
  final VoidCallback? onRemoveFromPlaylist;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded,
          size: 20, color: context.colors.textSecondary),
      onSelected: (value) {
        switch (value) {
          case 'fav':
            onToggleFavorite();
          case 'next':
            onPlayNext();
          case 'queue':
            onAddToQueue();
          case 'add':
            onAddToPlaylist();
          case 'remove':
            onRemoveFromPlaylist?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'fav',
          child: _row(
            isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            isFavorite ? l.songUnfavorite : l.songFavorite,
          ),
        ),
        PopupMenuItem(
          value: 'next',
          child: _row(Icons.playlist_play_rounded, l.songPlayNext),
        ),
        PopupMenuItem(
          value: 'queue',
          child: _row(Icons.queue_music_rounded, l.songAddToQueue),
        ),
        PopupMenuItem(
          value: 'add',
          child: _row(Icons.playlist_add_rounded, l.songAddToPlaylist),
        ),
        if (onRemoveFromPlaylist != null)
          PopupMenuItem(
            value: 'remove',
            child: _row(
                Icons.playlist_remove_rounded, l.songRemoveFromPlaylist),
          ),
      ],
    );
  }

  Widget _row(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      );
}
