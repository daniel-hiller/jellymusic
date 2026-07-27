import 'dart:async';

import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/util/item_x.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/item_menu.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/song_tile.dart';

/// Search across tracks, albums and artists. Types are grouped in the
/// results; tapping a track plays it, an album/artist navigates to detail.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(searchTermProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final term = ref.watch(searchTermProvider);
    final results = ref.watch(searchResultsProvider);
    final player = ref.watch(playerControllerProvider);
    final service = ref.watch(jellyfinServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
      ),
      body: term.isEmpty
          ? Center(child: Text(l.searchPrompt))
          : results.when(
              loading: () => const TileRowsSkeleton(leadingSize: 44),
              error: (e, _) => Center(child: Text(l.errorWithMessage('$e'))),
              data: (items) {
                if (items.isEmpty) {
                  return Center(child: Text(l.searchNoResults));
                }
                final songs = items.where((i) => i.isAudio).toList();
                final albums = items
                    .where((i) => i.type == JellyfinItemKind.musicAlbum)
                    .toList();
                final artists = items
                    .where((i) => i.type == JellyfinItemKind.musicArtist)
                    .toList();

                return ListView(
                  children: [
                    if (artists.isNotEmpty)
                      ..._section(l.tabArtists, artists, (a) {
                        return _EntityTile(
                          item: a,
                          title: a.name,
                          subtitle: l.tabArtists,
                          imageUrl: service.primaryImageUrl(a, size: 128),
                          circle: true,
                          onTap: () =>
                              context.go('/search/artist/${a.id}'),
                        );
                      }),
                    if (albums.isNotEmpty)
                      ..._section(l.tabAlbums, albums, (a) {
                        return _EntityTile(
                          item: a,
                          title: a.name,
                          subtitle: a.albumArtistLabel.isNotEmpty
                              ? a.albumArtistLabel
                              : l.labelAlbum,
                          imageUrl: service.primaryImageUrl(a, size: 128),
                          onTap: () =>
                              context.go('/search/album/${a.id}'),
                        );
                      }),
                    if (songs.isNotEmpty) ...[
                      _header(l.tabSongs),
                      ...List.generate(
                        songs.length,
                        (i) => SongTile(
                          song: songs[i],
                          showCoverArt: true,
                          onTap: () => player.playItems(songs, index: i),
                        ),
                      ),
                    ],
                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
    );
  }

  List<Widget> _section(
    String title,
    List<JellyfinItem> items,
    Widget Function(JellyfinItem) builder,
  ) {
    return [
      _header(title),
      ...items.map(builder),
    ];
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// An album or artist hit, with the same context menu its card carries in the
/// library.
class _EntityTile extends StatelessWidget {
  const _EntityTile({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
    this.circle = false,
  });

  final JellyfinItem item;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final art = CoverArt(
      url: imageUrl,
      size: 48,
      borderRadius: circle ? 24 : 6,
    );
    return ItemMenu(
      item: item,
      builder: (context, menu) => ListTile(
        onTap: onTap,
        leading: circle ? ClipOval(child: art) : art,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: menu.button,
      ),
    );
  }
}
