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
import '../../widgets/cover_art.dart';
import '../../widgets/skeleton.dart';

/// Landing screen: a greeting plus horizontally-scrolling shelves that mirror
/// what Jellyfin tracks — continue listening, recently played, recently
/// added, most played, favourites and a random pick. Each shelf carries a
/// heading and hides itself when the server has nothing for it.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static final _shelves = <_ShelfSpec>[
    _ShelfSpec((l) => l.shelfContinue, continueListeningProvider),
    _ShelfSpec((l) => l.shelfRecentlyPlayed, recentlyPlayedProvider),
    _ShelfSpec((l) => l.shelfRecentlyAdded, recentlyAddedProvider),
    _ShelfSpec((l) => l.shelfMostPlayed, mostPlayedProvider),
    _ShelfSpec((l) => l.shelfFavoriteAlbums, favoriteAlbumsProvider),
    _ShelfSpec((l) => l.shelfFavoriteArtists, favoriteArtistsProvider),
    _ShelfSpec((l) => l.shelfRandom, randomAlbumsProvider),
  ];

  Future<void> _refresh(WidgetRef ref) async {
    // Clear the HTTP cache so a manual refresh really re-hits the server.
    await ref.read(jellyfinServiceProvider).clearCache();
    for (final s in _shelves) {
      ref.invalidate(s.provider);
    }
    ref.invalidate(recentlyPlayedTracksProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final userName =
        ref.watch(authControllerProvider).value?.userName ?? '';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Text(userName.isEmpty ? l.homeWelcome : l.homeHi(userName)),
              actions: [
                IconButton(
                  tooltip: l.actionRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => _refresh(ref),
                ),
                // Keep the action clear of the desktop scrollbar.
                const SizedBox(width: 8),
              ],
            ),
            for (final s in _shelves)
              SliverToBoxAdapter(
                child: _Shelf(title: s.title(l), provider: s.provider),
              ),
            const SliverToBoxAdapter(child: _RecentTracksShelf()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _ShelfSpec {
  const _ShelfSpec(this.title, this.provider);
  final String Function(AppLocalizations) title;
  final FutureProvider<List<JellyfinItem>> provider;
}

class _Shelf extends ConsumerWidget {
  const _Shelf({required this.title, required this.provider});

  final String title;
  final FutureProvider<List<JellyfinItem>> provider;

  void _open(BuildContext context, JellyfinItem item) {
    final target = switch (item.type) {
      JellyfinItemKind.musicArtist => 'artist/${item.id}',
      JellyfinItemKind.audio => 'album/${item.albumId ?? item.id}',
      _ => 'album/${item.id}',
    };
    context.go('/home/$target');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      // The heading is known before the data is, so it stays put and only the
      // cards below it are stand-ins — no jump when the shelf fills in.
      loading: () => _titled(context, const AlbumShelfSkeleton()),
      // Failing shelves stay quiet rather than littering the home screen.
      error: (e, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return _titled(
          context,
          AlbumShelf(items: items, onOpen: (item) => _open(context, item)),
        );
      },
    );
  }

  Widget _titled(BuildContext context, Widget shelf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        shelf,
      ],
    );
  }
}

/// A horizontal shelf of recently played *tracks* (unlike the album shelves).
/// Tapping a card plays from that point through the rest of the row.
class _RecentTracksShelf extends ConsumerWidget {
  const _RecentTracksShelf();

  static const _cardWidth = 128.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(recentlyPlayedTracksProvider);
    return async.maybeWhen(
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        final controller = ref.watch(playerControllerProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(l.shelfRecentlyPlayedTracks,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            SizedBox(
              height: _cardWidth + 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _TrackCard(
                  track: tracks[i],
                  width: _cardWidth,
                  onTap: () => controller.playItems(tracks, index: i),
                ),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _TrackCard extends ConsumerWidget {
  const _TrackCard(
      {required this.track, required this.width, required this.onTap});

  final JellyfinItem track;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url =
        ref.watch(jellyfinServiceProvider).primaryImageUrl(track, size: 256);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(url: url, size: width, borderRadius: 8),
            const SizedBox(height: 6),
            Text(
              track.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              track.trackArtistLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
