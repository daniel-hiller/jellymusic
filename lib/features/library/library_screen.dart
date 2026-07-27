import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/album_card.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/song_tile.dart';
import 'library_controls_bar.dart';
import 'library_picker.dart';
import 'library_section.dart';
import 'paged_library.dart';
import 'playlist_actions.dart';

/// The library browser: Albums / Artists / Songs / Playlists / Genres. Every
/// tab pages through the same [LibraryKind] machinery and carries a
/// [LibraryControlsBar] (sort + direction + search + filters). Grids use a
/// max-extent delegate so column count adapts from phone to desktop.
///
/// - Desktop (≥ 800 px): the sidebar drives which category shows, so this
///   renders just the active section (via [librarySectionProvider]).
/// - Phones: the categories stay as a tab bar here.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  /// The body widget for a single category.
  static Widget bodyFor(LibrarySection section) => switch (section) {
        LibrarySection.albums => const _AlbumsGrid(),
        LibrarySection.artists => const _ArtistsGrid(),
        LibrarySection.songs => const _SongsList(),
        LibrarySection.playlists => const _PlaylistsList(),
        LibrarySection.genres => const _GenresList(),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    if (isWide) {
      final section = ref.watch(librarySectionProvider);
      // The library switcher sits in the sidebar on desktop, so the app bar
      // stays plain here.
      return Scaffold(
        appBar: AppBar(title: Text(section.label(l))),
        body: bodyFor(section),
      );
    }

    return DefaultTabController(
      length: LibrarySection.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.libraryTitle),
          actions: const [LibraryPicker(style: LibraryPickerStyle.appBar)],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final s in LibrarySection.values) Tab(text: s.label(l)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final s in LibrarySection.values) bodyFor(s),
          ],
        ),
      ),
    );
  }
}

class _AlbumsGrid extends ConsumerWidget {
  const _AlbumsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const LibraryControlsBar(kind: LibraryKind.albums),
        Expanded(
          child: _PagedItemGrid(
            kind: LibraryKind.albums,
            onTap: (a) => context.go('/library/album/${a.id}'),
          ),
        ),
      ],
    );
  }
}

class _ArtistsGrid extends ConsumerWidget {
  const _ArtistsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const LibraryControlsBar(kind: LibraryKind.artists),
        Expanded(
          child: _PagedItemGrid(
            kind: LibraryKind.artists,
            onTap: (a) => context.go('/library/artist/${a.id}'),
          ),
        ),
      ],
    );
  }
}

class _SongsList extends ConsumerWidget {
  const _SongsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final paged = ref.watch(pagedLibraryProvider(LibraryKind.songs));
    final controller = ref.watch(playerControllerProvider);
    return Column(
      children: [
        const LibraryControlsBar(kind: LibraryKind.songs),
        Expanded(
          child: _PagedBody(
            kind: LibraryKind.songs,
            state: paged,
            emptyLabel: l.songsEmpty,
            skeleton: const SongRowsSkeleton(),
            builder: (items, scrollController) => ListView.builder(
              controller: scrollController,
              itemCount: items.length,
              itemBuilder: (context, i) => SongTile(
                song: items[i],
                showCoverArt: true,
                onTap: () => controller.playItems(items, index: i),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A library grid (albums / artists) with infinite scroll + an A–Z jump rail.
class _PagedItemGrid extends ConsumerWidget {
  const _PagedItemGrid({required this.kind, required this.onTap});

  final LibraryKind kind;
  final void Function(JellyfinItem) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final paged = ref.watch(pagedLibraryProvider(kind));
    return _PagedBody(
      kind: kind,
      state: paged,
      emptyLabel: l.nothingFound,
      skeleton: const AlbumGridSkeleton(),
      builder: (items, scrollController) => GridView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.70,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) =>
            AlbumCard(album: items[i], onTap: () => onTap(items[i])),
      ),
    );
  }
}

/// Handles the four paged states (loading / error / empty / data), wires
/// scroll-to-load-more, and — on desktop — the A–Z jump rail. The [builder]
/// receives the loaded items and the [ScrollController] to attach.
class _PagedBody extends ConsumerWidget {
  const _PagedBody({
    required this.kind,
    required this.state,
    required this.emptyLabel,
    required this.skeleton,
    required this.builder,
  });

  final LibraryKind kind;
  final PagedState state;
  final String emptyLabel;

  /// Placeholder for the first page; shaped like the list this body builds.
  final Widget skeleton;
  final Widget Function(List<JellyfinItem> items, ScrollController controller)
      builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    if (state.items.isEmpty) {
      if (state.error != null) {
        return Center(child: Text(l.errorWithMessage('${state.error}')));
      }
      if (state.loadingMore) {
        return skeleton;
      }
      return Center(child: Text(emptyLabel));
    }

    return _AlphabetScroll(
      activeLetter: ref.watch(queryProviderFor(kind)).startLetter,
      // A letter filters the list to that letter via the server; '#' clears
      // the filter and shows the whole list.
      onLetter: (letter) {
        final notifier = ref.read(queryProviderFor(kind).notifier);
        notifier.state = letter == '#'
            ? notifier.state.copyWith(clearLetter: true)
            : notifier.state.copyWith(startLetter: letter);
      },
      builder: (controller) => NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 700) {
            ref.read(pagedLibraryProvider(kind).notifier).loadMore();
          }
          return false;
        },
        child: builder(state.items, controller),
      ),
    );
  }
}

class _PlaylistsList extends ConsumerWidget {
  const _PlaylistsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final paged = ref.watch(pagedLibraryProvider(LibraryKind.playlists));
    final service = ref.watch(jellyfinServiceProvider);
    return Column(
      children: [
        const LibraryControlsBar(kind: LibraryKind.playlists),
        // Creating a playlist sits above the list instead of inside it, so it
        // stays put while the list pages and stays reachable when a search or
        // filter leaves nothing behind.
        ListTile(
          leading: CircleAvatar(
            backgroundColor: context.colors.surfaceHigher,
            child: Icon(Icons.add_rounded, color: context.colors.accent),
          ),
          title: Text(l.playlistNew),
          onTap: () => showCreatePlaylistDialog(context, ref),
        ),
        Expanded(
          child: _PagedBody(
            kind: LibraryKind.playlists,
            state: paged,
            emptyLabel: l.nothingFound,
            skeleton: const TileRowsSkeleton(),
            builder: (items, scrollController) => ListView.builder(
              controller: scrollController,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final p = items[i];
                final count = p.childCount;
                return ListTile(
                  leading: CoverArt(
                    url: service.primaryImageUrl(p, size: 96),
                    size: 48,
                    borderRadius: 6,
                  ),
                  title: Text(p.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: count != null
                      ? Text(l.trackCount('$count'),
                          style: TextStyle(
                              color: context.colors.textSecondary))
                      : null,
                  onTap: () => context.go('/library/playlist/${p.id}'),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _GenresList extends ConsumerWidget {
  const _GenresList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final paged = ref.watch(pagedLibraryProvider(LibraryKind.genres));
    return Column(
      children: [
        const LibraryControlsBar(kind: LibraryKind.genres),
        Expanded(
          child: _PagedBody(
            kind: LibraryKind.genres,
            state: paged,
            emptyLabel: l.genresEmpty,
            skeleton: const GenreGridSkeleton(),
            builder: (items, scrollController) => GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisExtent: 104,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => _GenreTile(
                genre: items[i],
                onTap: () => context.go('/library/genre/${items[i].id}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A colourful gradient genre tile with a rotated corner mark (Nocturne).
class _GenreTile extends StatelessWidget {
  const _GenreTile({required this.genre, required this.onTap});

  final JellyfinItem genre;
  final VoidCallback onTap;

  /// Deterministic hue from the genre name, kept in a muted violet-leaning
  /// spread so tiles feel like one family.
  HSLColor _base() {
    final hash = genre.name.codeUnits.fold<int>(0, (a, c) => a * 31 + c);
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.42, 0.42);
  }

  @override
  Widget build(BuildContext context) {
    final base = _base();
    final top = base.toColor();
    final bottom = base.withLightness(0.24).toColor();
    final mark = base.withLightness(0.60).withSaturation(0.55).toColor();

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, bottom],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -16,
                top: -10,
                child: Transform.rotate(
                  angle: 0.44, // ~25°
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: mark,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 20,
                            offset: Offset(0, 10)),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    genre.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.16,
                      shadows: [
                        Shadow(color: Color(0x59000000), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a scrollable with an A–Z filter rail on the right (desktop only).
/// Tapping a letter loads only items starting with it via the server, like the
/// official client. [onLetter] receives the tapped letter; [activeLetter] is
/// the currently applied one (null = no filter, shown as `#`).
class _AlphabetScroll extends StatefulWidget {
  const _AlphabetScroll({
    required this.onLetter,
    required this.builder,
    this.activeLetter,
  });

  final void Function(String letter) onLetter;
  final Widget Function(ScrollController controller) builder;
  final String? activeLetter;

  @override
  State<_AlphabetScroll> createState() => _AlphabetScrollState();
}

class _AlphabetScrollState extends State<_AlphabetScroll> {
  static const _letters = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = widget.builder(_controller);
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    if (!isWide) return scrollable;

    // No letter filter → '#' is the active ("all") entry.
    final active = widget.activeLetter ?? '#';

    return Row(
      children: [
        Expanded(child: scrollable),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final letter in _letters)
                Expanded(
                  child: _LetterTile(
                    letter: letter,
                    selected: letter == active,
                    onTap: () => widget.onLetter(letter),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single rail letter: larger tap target, hover highlight, and an accent
/// pill when it's the active filter.
class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: accent.withValues(alpha: 0.14),
        child: Container(
          width: 22,
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  color: accent.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? accent : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
