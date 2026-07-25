import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/song_tile.dart';
import '../player/radio_actions.dart';
import 'detail_hero.dart';

/// A playlist: header (cover + play/shuffle) over its tracks, plus edit
/// actions (add songs, rename, delete) in the app bar.
class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  Future<void> _removeTrack(
      BuildContext context, WidgetRef ref, JellyfinItem track) async {
    final entryId = track.raw['PlaylistItemId'] as String?;
    if (entryId == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(musicRepositoryProvider)
          .removeFromPlaylist(playlistId, [entryId]);
      ref.invalidate(playlistDetailProvider(playlistId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorWithMessage('$e'))));
    }
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, String currentName) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.playlistRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == currentName) return;
    try {
      await ref.read(musicRepositoryProvider).renamePlaylist(playlistId, name);
      ref.invalidate(playlistDetailProvider(playlistId));
      ref.invalidate(playlistsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorWithMessage('$e'))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.playlistDeleteTitle),
        content: Text(l.playlistDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(musicRepositoryProvider).deletePlaylist(playlistId);
      ref.invalidate(playlistsProvider);
      router.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorWithMessage('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final detail = ref.watch(playlistDetailProvider(playlistId));
    final service = ref.watch(jellyfinServiceProvider);
    final controller = ref.watch(playerControllerProvider);

    return Scaffold(
      body: detail.when(
        loading: () => const DetailScreenSkeleton(),
        error: (e, _) => Center(child: Text(l.errorWithMessage('$e'))),
        data: (data) {
          final playlist = data.playlist;
          final tracks = data.tracks;
          final name = playlist?.name ?? '—';
          final coverUrl = playlist != null
              ? service.primaryImageUrl(playlist, size: 640)
              : null;
          final isFav = ref.watch(favoriteProvider(playlistId)).value ?? false;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                actions: [
                  IconButton(
                    tooltip: l.radioAction,
                    icon: const Icon(Icons.radio_rounded),
                    onPressed: () => startRadio(context, ref, playlistId),
                  ),
                  IconButton(
                    tooltip: l.addSongsTitle,
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () =>
                        context.push('/library/playlist/$playlistId/add'),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') _rename(context, ref, name);
                      if (v == 'delete') _delete(context, ref);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                          value: 'rename', child: Text(l.playlistRenameTitle)),
                      PopupMenuItem(
                          value: 'delete', child: Text(l.commonDelete)),
                    ],
                  ),
                ],
                expandedHeight: 0,
              ),
              SliverToBoxAdapter(
                child: DetailHero(
                  coverUrl: coverUrl,
                  kicker: l.labelPlaylist,
                  title: name,
                  meta: l.trackCount('${tracks.length}'),
                  trailing: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: MediaQuery.sizeOf(context).width < 560
                        ? WrapAlignment.center
                        : WrapAlignment.start,
                    children: [
                      FilledButton.icon(
                        onPressed: tracks.isEmpty
                            ? null
                            : () => controller.playItems(tracks),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(l.playAction),
                      ),
                      OutlinedButton.icon(
                        onPressed: tracks.isEmpty
                            ? null
                            : () async {
                                await controller.playItems(tracks);
                                await controller.toggleShuffle();
                              },
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: Text(l.shuffleAction),
                      ),
                      HeroRoundAction(
                        icon: isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav ? context.colors.accent : null,
                        tooltip: isFav ? l.songUnfavorite : l.songFavorite,
                        onTap: () {
                          ref
                              .read(favoriteProvider(playlistId).notifier)
                              .toggle();
                          // Refresh the playlist lists so the favourites filter
                          // and the sidebar reflect the change immediately.
                          ref.invalidate(playlistsProvider);
                          ref.invalidate(favoritePlaylistsProvider);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (tracks.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(l.playlistEmpty)),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, i) => SongTile(
                    song: tracks[i],
                    showCoverArt: true,
                    onTap: () => controller.playItems(tracks, index: i),
                    onRemoveFromPlaylist: () =>
                        _removeTrack(context, ref, tracks[i]),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}
