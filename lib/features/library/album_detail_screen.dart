import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jelly_colors.dart';
import '../../core/util/item_x.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/song_tile.dart';
import '../player/radio_actions.dart';
import 'detail_hero.dart';

/// Album view (Nocturne): a horizontal hero (cover + title + meta over a glow),
/// an action row, and the track list.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final detail = ref.watch(albumDetailProvider(albumId));
    final service = ref.watch(jellyfinServiceProvider);
    final controller = ref.watch(playerControllerProvider);

    return Scaffold(
      body: detail.when(
        loading: () => const DetailScreenSkeleton(),
        error: (e, _) => Center(child: Text(l.errorWithMessage('$e'))),
        data: (data) {
          final album = data.album;
          final tracks = data.tracks;
          final coverUrl =
              album != null ? service.primaryImageUrl(album, size: 640) : null;

          final meta = [
            if (album != null && album.albumArtistLabel.isNotEmpty)
              album.albumArtistLabel,
            if (album?.productionYear != null) '${album!.productionYear}',
            l.trackCount('${tracks.length}'),
            _runtime(tracks),
          ].where((s) => s.isNotEmpty).join(' · ');

          return CustomScrollView(
            slivers: [
              const SliverAppBar(pinned: true, expandedHeight: 0),
              SliverToBoxAdapter(
                child: DetailHero(
                  coverUrl: coverUrl,
                  kicker: l.labelAlbum,
                  title: album?.name ?? l.labelAlbum,
                  meta: meta,
                  trailing: _HeroActions(
                    onPlay: tracks.isEmpty
                        ? null
                        : () => controller.playItems(tracks),
                    onShuffle: tracks.isEmpty
                        ? null
                        : () async {
                            await controller.playItems(tracks);
                            await controller.toggleShuffle();
                          },
                    onRadio: () => startRadio(context, ref, albumId),
                    favItemId: albumId,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverList.builder(
                itemCount: tracks.length,
                itemBuilder: (context, i) => SongTile(
                  song: tracks[i],
                  showArtist: false,
                  onTap: () => controller.playItems(tracks, index: i),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  static String _runtime(List<JellyfinItem> tracks) {
    final ms = tracks.fold<int>(0, (a, t) => a + (t.durationMs ?? 0));
    if (ms == 0) return '';
    final min = (ms / 60000).round();
    return '$min min';
  }
}

/// Play / Shuffle / Radio / Favourite action row under the hero title.
class _HeroActions extends ConsumerWidget {
  const _HeroActions({
    required this.onPlay,
    required this.onShuffle,
    required this.onRadio,
    required this.favItemId,
  });

  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;
  final VoidCallback onRadio;
  final String favItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isFav = ref.watch(favoriteProvider(favItemId)).value ?? false;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      // Centre the actions under the centred header on phones; keep them
      // left-aligned beside the cover on the wide desktop layout.
      alignment: MediaQuery.sizeOf(context).width < 560
          ? WrapAlignment.center
          : WrapAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text(l.playAction),
        ),
        OutlinedButton.icon(
          onPressed: onShuffle,
          icon: const Icon(Icons.shuffle_rounded, size: 18),
          label: Text(l.shuffleAction),
        ),
        HeroRoundAction(
          icon: Icons.radio_rounded,
          tooltip: l.radioAction,
          onTap: onRadio,
        ),
        HeroRoundAction(
          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFav ? context.colors.accent : null,
          tooltip: isFav ? l.songUnfavorite : l.songFavorite,
          onTap: () => ref.read(favoriteProvider(favItemId).notifier).toggle(),
        ),
      ],
    );
  }
}
