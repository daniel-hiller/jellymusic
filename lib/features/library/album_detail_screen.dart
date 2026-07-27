import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/jelly_colors.dart';
import '../../core/util/item_x.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/album_shelf.dart';
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
    final similar = ref.watch(similarAlbumsProvider(albumId));
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

          final albumArtist = album?.albumArtistLabel ?? '';
          final discs = _discs(tracks);

          // [i] is always the position in the flat track list, so playback
          // starts on the tapped track no matter which disc it sits on.
          SongTile tile(int i) {
            final track = tracks[i];
            final trackArtist = track.trackArtistLabel;
            // Only show the per-track artist when it differs from the
            // album artist — i.e. compilations ("Various Artists") and
            // guest features. Hides the redundant repeat on normal albums.
            final showArtist = trackArtist.isNotEmpty &&
                trackArtist.toLowerCase() != albumArtist.toLowerCase();
            return SongTile(
              song: track,
              showArtist: showArtist,
              onTap: () => controller.playItems(tracks, index: i),
            );
          }

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
                        : () => controller.playItemsShuffled(tracks),
                    onRadio: () => startRadio(context, ref, albumId),
                    favItemId: albumId,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (discs.length < 2)
                SliverList.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, i) => tile(i),
                )
              else
                for (final disc in discs) ...[
                  _DiscHeader(l.discNumber('${disc.number}')),
                  SliverList.builder(
                    itemCount: disc.length,
                    itemBuilder: (context, i) => tile(disc.start + i),
                  ),
                ],
              // Related albums need server-side metadata; without it the answer
              // is empty and the shelf, heading included, stays away.
              ...similar.maybeWhen(
                data: (items) => items.isEmpty
                    ? const <Widget>[]
                    : [
                        DetailSectionHeader(l.similarAlbums),
                        SliverToBoxAdapter(
                          child: AlbumShelf(
                            items: items,
                            horizontalPadding: 14,
                            onOpen: (item) =>
                                context.go('/library/album/${item.id}'),
                          ),
                        ),
                      ],
                orElse: () => const <Widget>[],
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

  /// The runs of consecutive tracks that share a disc number. `albumTracks`
  /// sorts by `ParentIndexNumber` first, so one run per disc is enough; a
  /// single run means a single-disc album and no headings.
  static List<_Disc> _discs(List<JellyfinItem> tracks) {
    final discs = <_Disc>[];
    for (final track in tracks) {
      final number = track.parentIndexNumber ?? 1;
      if (discs.isEmpty || discs.last.number != number) {
        discs.add(_Disc(number, discs.isEmpty ? 0 : discs.last.end));
      }
      discs.last.length++;
    }
    return discs;
  }
}

/// One disc of a multi-disc album: its number plus where its tracks begin in
/// the flat track list.
class _Disc {
  _Disc(this.number, this.start);

  final int number;
  final int start;
  int length = 0;

  int get end => start + length;
}

/// Divider between the discs of a multi-disc album. Quieter than a section
/// heading — it labels a continuation of the same list, not a new one.
class _DiscHeader extends StatelessWidget {
  const _DiscHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: context.colors.textTertiary,
          ),
        ),
      ),
    );
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
