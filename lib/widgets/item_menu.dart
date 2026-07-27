import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/jelly_colors.dart';
import '../features/library/paged_library.dart';
import '../features/library/playlist_actions.dart';
import '../features/player/radio_actions.dart';
import '../l10n/app_localizations.dart';
import '../providers/player_providers.dart';
import '../providers/providers.dart';

/// One entry of an item's context menu.
class ItemAction {
  const ItemAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.startsGroup = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  /// Draws a divider above the entry, so the menu stays readable as it grows:
  /// what to play, which collections the item belongs to, and the flags the
  /// server keeps for it.
  final bool startsGroup;
}

/// Attaches [item]'s context menu to a tile: a long press on touch, a right
/// click with a pointer, and — where the layout has room for it — the
/// three-dot [ItemMenuState.button] the [builder] can place inside its row.
///
/// The builder receives the state so a tile can also mirror the favourite flag
/// the menu keeps (the song rows show a heart next to the duration).
class ItemMenu extends ConsumerStatefulWidget {
  const ItemMenu({
    super.key,
    required this.item,
    required this.builder,
    this.onRemoveFromPlaylist,
  });

  final JellyfinItem item;
  final Widget Function(BuildContext context, ItemMenuState menu) builder;

  /// When set, the menu gains a "remove from playlist" entry.
  final VoidCallback? onRemoveFromPlaylist;

  @override
  ItemMenuState createState() => ItemMenuState();
}

class ItemMenuState extends ConsumerState<ItemMenu> {
  /// Local favourite state so toggling doesn't require a per-tile network
  /// read; seeded from the item and updated optimistically.
  bool? _favOverride;

  /// Same for the played flag, which the item carries in its user data.
  bool? _playedOverride;

  bool get isFavorite => _favOverride ?? widget.item.isFavorite;

  bool get isPlayed =>
      _playedOverride ?? widget.item.userData?.played ?? false;

  /// The overflow button — the same menu the long press opens.
  Widget get button => PopupMenuButton<ItemAction>(
        icon: Icon(Icons.more_vert_rounded,
            size: 20, color: context.colors.textSecondary),
        onSelected: (action) => action.onSelected(),
        itemBuilder: (_) => _entries(),
      );

  /// Opens the menu where the long press or right click landed.
  Future<void> openAt(Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<ItemAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      items: _entries(),
    );
    if (!mounted) return;
    action?.onSelected();
  }

  /// Flip the favourite flag, showing the new state immediately and reverting
  /// it when the server refuses.
  Future<void> _setFavorite(bool next) async {
    setState(() => _favOverride = next);
    try {
      await ref.read(musicRepositoryProvider).setFavorite(widget.item.id, next);
      // The playlist lists carry the flag too — the favourites filter and the
      // sidebar shortcut both read it.
      if (mounted && widget.item.type == JellyfinItemKind.playlist) {
        invalidatePlaylists(ref);
      }
    } catch (_) {
      if (mounted) setState(() => _favOverride = !next);
    }
  }

  Future<void> _setPlayed(bool next) async {
    setState(() => _playedOverride = next);
    try {
      await ref.read(musicRepositoryProvider).setPlayed(widget.item.id, next);
    } catch (_) {
      if (mounted) setState(() => _playedOverride = !next);
    }
  }

  List<PopupMenuEntry<ItemAction>> _entries() {
    final entries = <PopupMenuEntry<ItemAction>>[];
    for (final action in _actionsFor(
      context,
      ref,
      widget.item,
      isFavorite: isFavorite,
      isPlayed: isPlayed,
      setFavorite: _setFavorite,
      setPlayed: _setPlayed,
      onRemoveFromPlaylist: widget.onRemoveFromPlaylist,
    )) {
      if (action.startsGroup && entries.isNotEmpty) {
        entries.add(const PopupMenuDivider());
      }
      entries.add(PopupMenuItem(
        value: action,
        child: Row(
          children: [
            Icon(action.icon, size: 20),
            const SizedBox(width: 12),
            Text(action.label),
          ],
        ),
      ));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Translucent so the press registers over the gaps between a card's
      // cover and its labels, not just on the painted parts.
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (d) => openAt(d.globalPosition),
      onSecondaryTapDown: (d) => openAt(d.globalPosition),
      child: widget.builder(context, this),
    );
  }
}

/// The entries [item] supports. Every kind offers what it can actually do: an
/// album can be shuffled and queued, an artist leads to a radio, a genre stops
/// at playing it — it has neither a favourite flag nor a finite track list to
/// slot in after the current song.
List<ItemAction> _actionsFor(
  BuildContext context,
  WidgetRef ref,
  JellyfinItem item, {
  required bool isFavorite,
  required bool isPlayed,
  required Future<void> Function(bool next) setFavorite,
  required Future<void> Function(bool next) setPlayed,
  VoidCallback? onRemoveFromPlaylist,
}) {
  final l = AppLocalizations.of(context);
  final player = ref.read(playerControllerProvider);

  ItemAction play() => ItemAction(
        icon: Icons.play_arrow_rounded,
        label: l.playAction,
        onSelected: () => _withTracks(context, ref, item, play: player.playItems),
      );

  ItemAction shuffle() => ItemAction(
        icon: Icons.shuffle_rounded,
        label: l.shuffleAction,
        onSelected: () =>
            _withTracks(context, ref, item, play: player.playItemsShuffled),
      );

  ItemAction playNext() => ItemAction(
        icon: Icons.playlist_play_rounded,
        label: l.songPlayNext,
        onSelected: () => _withTracks(context, ref, item,
            play: player.playNext, confirmation: l.toastPlayNext),
      );

  ItemAction addToQueue() => ItemAction(
        icon: Icons.queue_music_rounded,
        label: l.songAddToQueue,
        onSelected: () => _withTracks(context, ref, item,
            play: player.addToQueue, confirmation: l.toastAddedToQueue),
      );

  ItemAction radio() => ItemAction(
        icon: Icons.radio_rounded,
        label: l.radioAction,
        onSelected: () => startRadio(context, ref, item.id),
      );

  ItemAction favorite() => ItemAction(
        icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        label: isFavorite ? l.songUnfavorite : l.songFavorite,
        startsGroup: true,
        onSelected: () => setFavorite(!isFavorite),
      );

  return switch (item.type) {
    JellyfinItemKind.musicAlbum => [
        play(),
        shuffle(),
        playNext(),
        addToQueue(),
        radio(),
        favorite(),
      ],
    JellyfinItemKind.musicArtist => [play(), radio(), favorite()],
    JellyfinItemKind.playlist => [
        play(),
        shuffle(),
        playNext(),
        addToQueue(),
        favorite(),
        ItemAction(
          icon: Icons.drive_file_rename_outline_rounded,
          label: l.playlistRenameTitle,
          startsGroup: true,
          onSelected: () => showRenamePlaylistDialog(context, ref,
              playlistId: item.id, currentName: item.name),
        ),
        ItemAction(
          icon: Icons.delete_outline_rounded,
          label: l.commonDelete,
          onSelected: () =>
              showDeletePlaylistDialog(context, ref, playlistId: item.id),
        ),
      ],
    JellyfinItemKind.musicGenre => [play(), radio()],
    // Tracks, and anything else a tile hands us that plays as audio.
    _ => [
        playNext(),
        addToQueue(),
        ItemAction(
          icon: Icons.playlist_add_rounded,
          label: l.songAddToPlaylist,
          startsGroup: true,
          onSelected: () =>
              showAddToPlaylistSheet(context, ref, itemIds: [item.id]),
        ),
        if (onRemoveFromPlaylist != null)
          ItemAction(
            icon: Icons.playlist_remove_rounded,
            label: l.songRemoveFromPlaylist,
            onSelected: onRemoveFromPlaylist,
          ),
        favorite(),
        ItemAction(
          icon: isPlayed
              ? Icons.remove_done_rounded
              : Icons.check_circle_outline_rounded,
          label: isPlayed ? l.songMarkUnplayed : l.songMarkPlayed,
          onSelected: () => setPlayed(!isPlayed),
        ),
      ],
  };
}

/// The tracks an item stands for — an album's, a playlist's, a genre's, or the
/// artist's most played. A track stands for itself.
Future<List<JellyfinItem>> _tracksOf(WidgetRef ref, JellyfinItem item) {
  final repo = ref.read(musicRepositoryProvider);
  return switch (item.type) {
    JellyfinItemKind.musicAlbum => repo.albumTracks(item.id),
    JellyfinItemKind.playlist => repo.playlistTracks(item.id),
    JellyfinItemKind.musicGenre => repo.genreTracks(item.id),
    JellyfinItemKind.musicArtist => repo.artistTopTracks(item.id, limit: 200),
    _ => Future.value([item]),
  };
}

/// Resolve the item's tracks and hand them to [play], confirming with a
/// snackbar when [confirmation] is set.
///
/// Everything but a track has to be fetched first, so the menu closes on the
/// tap and the work finishes behind it; a failed fetch ends in a snackbar
/// rather than an exception on the screen the menu came from.
Future<void> _withTracks(
  BuildContext context,
  WidgetRef ref,
  JellyfinItem item, {
  required Future<void> Function(List<JellyfinItem> tracks) play,
  String? confirmation,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final tracks = await _tracksOf(ref, item);
    if (tracks.isEmpty) return;
    await play(tracks);
    if (confirmation != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(confirmation)));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l.errorWithMessage('$e'))));
  }
}
