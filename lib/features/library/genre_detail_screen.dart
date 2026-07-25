import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/album_card.dart';
import '../../widgets/skeleton.dart';
import '../player/radio_actions.dart';

/// A genre: its albums in a grid, plus a "start radio" action seeded from the
/// genre.
class GenreDetailScreen extends ConsumerWidget {
  const GenreDetailScreen({super.key, required this.genreId});

  final String genreId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final genre = ref.watch(artistByIdProvider(genreId)).value;
    final albums = ref.watch(genreAlbumsProvider(genreId));

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
      body: albums.when(
        loading: () => const AlbumGridSkeleton(),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('—'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
          );
        },
      ),
    );
  }

  void _openAlbum(BuildContext context, JellyfinItem album) =>
      context.go('/library/genre/$genreId/album/${album.id}');
}
