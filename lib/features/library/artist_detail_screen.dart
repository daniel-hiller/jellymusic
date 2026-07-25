import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/album_shelf.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/song_tile.dart';
import '../player/radio_actions.dart';
import 'detail_hero.dart';

/// Artist view (Nocturne): circular hero + actions, a "Popular" track list and
/// a horizontal row of the artist's albums.
class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artistId});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final artist = ref.watch(artistByIdProvider(artistId)).value;
    final albums = ref.watch(artistAlbumsProvider(artistId));
    final appearsOn = ref.watch(artistAppearsOnProvider(artistId));
    final top = ref.watch(artistTopTracksProvider(artistId));
    final controller = ref.watch(playerControllerProvider);
    final service = ref.watch(jellyfinServiceProvider);
    final isFav =
        ref.watch(favoriteProvider(artistId)).value ?? false;

    final coverUrl =
        artist != null ? service.primaryImageUrl(artist, size: 480) : null;
    final meta = artist?.genres.take(3).join(' · ') ?? '';
    final topTracks = top.value ?? const [];
    final overview = artist?.overview ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(pinned: true, expandedHeight: 0),
          SliverToBoxAdapter(
            child: DetailHero(
              coverUrl: coverUrl,
              circle: true,
              kicker: l.labelArtist,
              title: artist?.name ?? '—',
              meta: meta,
              trailing: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: MediaQuery.sizeOf(context).width < 560
                    ? WrapAlignment.center
                    : WrapAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: topTracks.isEmpty
                        ? null
                        : () => controller.playItems(topTracks),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(l.playAction),
                  ),
                  OutlinedButton.icon(
                    onPressed: topTracks.isEmpty
                        ? null
                        : () async {
                            await controller.playItems(topTracks);
                            await controller.toggleShuffle();
                          },
                    icon: const Icon(Icons.shuffle_rounded, size: 18),
                    label: Text(l.shuffleAction),
                  ),
                  HeroRoundAction(
                    icon: Icons.radio_rounded,
                    tooltip: l.radioAction,
                    onTap: () => startRadio(context, ref, artistId),
                  ),
                  HeroRoundAction(
                    icon: isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav ? context.colors.accent : null,
                    tooltip: isFav ? l.songUnfavorite : l.songFavorite,
                    onTap: () =>
                        ref.read(favoriteProvider(artistId).notifier).toggle(),
                  ),
                ],
              ),
            ),
          ),
          if (top.isLoading) ...[
            _SectionHeader(l.artistPopular),
            const SliverToBoxAdapter(
              child: SongRowsSkeleton(rows: 5, shrinkWrap: true),
            ),
          ] else if (topTracks.isNotEmpty) ...[
            _SectionHeader(l.artistPopular),
            SliverList.builder(
              itemCount: topTracks.length,
              itemBuilder: (context, i) => SongTile(
                song: topTracks[i],
                showCoverArt: true,
                onTap: () => controller.playItems(topTracks, index: i),
              ),
            ),
          ],
          _SectionHeader(l.artistAlbums),
          SliverToBoxAdapter(
            child: albums.when(
              loading: () => const AlbumShelfSkeleton(horizontalPadding: 14),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.errorWithMessage('$e')),
              ),
              data: (items) => AlbumShelf(
                items: items,
                horizontalPadding: 14,
                onOpen: (item) => context.go('/library/album/${item.id}'),
              ),
            ),
          ),
          // Albums the artist only appears on (guest spots, compilations).
          ...appearsOn.maybeWhen(
            data: (items) => items.isEmpty
                ? const <Widget>[]
                : [
                    _SectionHeader(l.artistAppearsOn),
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
          if (overview.isNotEmpty) ...[
            _SectionHeader(l.artistAbout),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
                child: _ExpandableText(overview),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Artist biography, clamped to a few lines with a Show more / less toggle.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              height: 1.45,
              color: context.colors.textSecondary,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? l.commonShowLess : l.commonShowMore),
          ),
        ),
      ],
    );
  }
}
