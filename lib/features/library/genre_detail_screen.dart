import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/album_card.dart';
import '../../widgets/album_shelf.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/song_tile.dart';
import '../player/radio_actions.dart';
import 'detail_hero.dart';

/// A genre: its albums in a grid, the artists and tracks tagged with it, plus
/// a "start radio" action seeded from the genre. Sections the server has
/// nothing for hide themselves.
class GenreDetailScreen extends ConsumerWidget {
  const GenreDetailScreen({super.key, required this.genreId});

  final String genreId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final genre = ref.watch(artistByIdProvider(genreId)).value;
    final albums = ref.watch(genreAlbumsProvider(genreId));
    final artists = ref.watch(genreArtistsProvider(genreId));
    final tracks = ref.watch(genreTracksProvider(genreId));
    final controller = ref.watch(playerControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(genre?.name ?? 'Genre'),
        actions: [
          IconButton(
            tooltip: l.radioAction,
            icon: const Icon(Icons.radio_rounded),
            onPressed: () => startRadio(context, ref, genreId),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (albums.isLoading)
            // The grid sizes itself to its parent, so it needs the viewport's
            // remaining height rather than a sliver's unbounded one.
            const SliverFillRemaining(child: AlbumGridSkeleton())
          else
            ...albums.maybeWhen(
              data: (items) => items.isEmpty
                  ? const <Widget>[]
                  : [
                      DetailSectionHeader(l.tabAlbums),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 0.70,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, i) => AlbumCard(
                            album: items[i],
                            onTap: () => _openAlbum(context, items[i]),
                          ),
                        ),
                      ),
                    ],
              orElse: () => const <Widget>[],
            ),
          ...artists.maybeWhen(
            data: (items) => items.isEmpty
                ? const <Widget>[]
                : [
                    DetailSectionHeader(l.genreArtists),
                    SliverToBoxAdapter(
                      child: AlbumShelf(
                        items: items,
                        horizontalPadding: 14,
                        onOpen: (item) => _openArtist(context, item),
                      ),
                    ),
                  ],
            orElse: () => const <Widget>[],
          ),
          ...tracks.maybeWhen(
            data: (items) => items.isEmpty
                ? const <Widget>[]
                : [
                    DetailSectionHeader(l.genreTracks),
                    SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => SongTile(
                        song: items[i],
                        showCoverArt: true,
                        onTap: () => controller.playItems(items, index: i),
                      ),
                    ),
                  ],
            orElse: () => const <Widget>[],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _openAlbum(BuildContext context, JellyfinItem album) =>
      context.go('/library/genre/$genreId/album/${album.id}');

  void _openArtist(BuildContext context, JellyfinItem artist) =>
      context.go('/library/genre/$genreId/artist/${artist.id}');
}
