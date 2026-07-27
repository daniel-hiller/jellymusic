import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/theme/jelly_colors.dart';
import '../../data/jellyfin/music_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import 'library_query.dart';
import 'paged_library.dart';

/// Sort + direction + search + filters, shared by every library list. Reads and
/// writes the tab's [LibraryQuery] state provider.
class LibraryControlsBar extends ConsumerWidget {
  const LibraryControlsBar({super.key, required this.kind});

  final LibraryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final queryProvider = queryProviderFor(kind);
    final query = ref.watch(queryProvider);
    final notifier = ref.read(queryProvider.notifier);
    final options = kind.sortOptions(l);
    final current = options.firstWhere(
      (o) => o.field == query.sortField,
      orElse: () => options.first,
    );
    final isRandom = current.field == 'Random';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          PopupMenuButton<String>(
            initialValue: current.field,
            onSelected: (field) => notifier.state =
                query.copyWith(sortField: field, clearLetter: true),
            itemBuilder: (context) => [
              for (final o in options)
                PopupMenuItem(value: o.field, child: Text(o.label)),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded, size: 20),
                const SizedBox(width: 6),
                Text(current.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
          if (!isRandom)
            IconButton(
              tooltip: query.descending ? l.sortDescending : l.sortAscending,
              icon: Icon(
                query.descending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 20,
              ),
              onPressed: () => notifier.state =
                  query.copyWith(descending: !query.descending, clearLetter: true),
            ),
          const SizedBox(width: 8),
          Expanded(child: _LibrarySearch(queryProvider: queryProvider)),
          const SizedBox(width: 4),
          if (kind.hasFilterSheet)
            IconButton(
              tooltip: l.filterTitle,
              icon: Icon(
                Icons.tune_rounded,
                color: query.hasFilters
                    ? context.colors.accent
                    : context.colors.textSecondary,
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _FilterSheet(kind: kind),
              ),
            ),
          IconButton(
            tooltip: query.favoritesOnly
                ? l.filterShowAll
                : l.filterFavoritesOnly,
            icon: Icon(
              query.favoritesOnly
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: query.favoritesOnly
                  ? context.colors.accent
                  : context.colors.textSecondary,
            ),
            onPressed: () => notifier.state =
                query.copyWith(favoritesOnly: !query.favoritesOnly, clearLetter: true),
          ),
        ],
      ),
    );
  }
}

/// The filter sheet behind the controls bar's tune icon: played state, genres
/// and decades. Only the filters the list's endpoint honours are shown, so a
/// tab never offers a control that can't move anything.
///
/// Every change lands in the tab's [LibraryQuery] right away — the list behind
/// the sheet updates as the chips are tapped.
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.kind});

  final LibraryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final queryProvider = queryProviderFor(kind);
    final query = ref.watch(queryProvider);
    // A narrowed list has nothing to do with the letter the rail was on.
    void apply(LibraryQuery next) =>
        ref.read(queryProvider.notifier).state = next.copyWith(clearLetter: true);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.filterTitle,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: query.hasFilters
                        ? () => apply(query.copyWith(
                              playedState: PlayedState.any,
                              genreIds: const [],
                              years: const [],
                            ))
                        : null,
                    child: Text(l.filterReset),
                  ),
                ],
              ),
              if (kind.supportsPlayedFilter)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final state in PlayedState.values)
                        ChoiceChip(
                          label: Text(switch (state) {
                            PlayedState.any => l.filterShowAll,
                            PlayedState.played => l.filterPlayed,
                            PlayedState.unplayed => l.filterUnplayed,
                          }),
                          selected: query.playedState == state,
                          onSelected: (_) =>
                              apply(query.copyWith(playedState: state)),
                        ),
                    ],
                  ),
                ),
              if (kind.supportsGenreFilter)
                _GenreFilter(query: query, apply: apply),
              if (kind.supportsDecadeFilter)
                _DecadeFilter(query: query, apply: apply),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multi-select genre chips, fed by the library's full genre list. Hides
/// itself while that list is still loading or when the library has no genres.
class _GenreFilter extends ConsumerWidget {
  const _GenreFilter({required this.query, required this.apply});

  final LibraryQuery query;
  final void Function(LibraryQuery) apply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final genres = ref.watch(genresProvider).value ?? const [];
    if (genres.isEmpty) return const SizedBox.shrink();

    return _FilterGroup(
      title: l.filterGenre,
      children: [
        for (final genre in genres)
          FilterChip(
            label: Text(genre.name),
            selected: query.genreIds.contains(genre.id),
            onSelected: (selected) {
              final ids = [...query.genreIds];
              if (selected) {
                ids.add(genre.id);
              } else {
                ids.remove(genre.id);
              }
              apply(query.copyWith(genreIds: ids));
            },
          ),
      ],
    );
  }
}

/// Multi-select decade chips, grouped from the production years the library
/// actually holds. A picked decade narrows to the ten years it spans.
class _DecadeFilter extends ConsumerWidget {
  const _DecadeFilter({required this.query, required this.apply});

  final LibraryQuery query;
  final void Function(LibraryQuery) apply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final years = ref.watch(libraryYearsProvider).value ?? const [];
    if (years.isEmpty) return const SizedBox.shrink();

    final decades = {for (final year in years) year - year % 10}.toList()
      ..sort((a, b) => b.compareTo(a));

    return _FilterGroup(
      title: l.filterDecade,
      children: [
        for (final decade in decades)
          FilterChip(
            label: Text(l.filterDecadeLabel('$decade')),
            selected: query.years.contains(decade),
            onSelected: (selected) {
              final picked = [
                for (final year in query.years)
                  if (year < decade || year >= decade + 10) year,
                if (selected)
                  for (var year = decade; year < decade + 10; year++) year,
              ]..sort();
              apply(query.copyWith(years: picked));
            },
          ),
      ],
    );
  }
}

/// A titled group of chips inside the filter sheet.
class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: context.colors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

/// Debounced in-tab search. Writes [LibraryQuery.searchTerm] (clearing any A–Z
/// letter) and syncs itself back to empty when the term is cleared elsewhere.
class _LibrarySearch extends ConsumerStatefulWidget {
  const _LibrarySearch({required this.queryProvider});

  final StateProvider<LibraryQuery> queryProvider;

  @override
  ConsumerState<_LibrarySearch> createState() => _LibrarySearchState();
}

class _LibrarySearchState extends ConsumerState<_LibrarySearch> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: ref.read(widget.queryProvider).searchTerm);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _apply(String value) {
    final notifier = ref.read(widget.queryProvider.notifier);
    notifier.state =
        notifier.state.copyWith(searchTerm: value.trim(), clearLetter: true);
  }

  void _onChanged(String value) {
    setState(() {}); // refresh the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _apply(value));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Keep the field in sync when the term is cleared elsewhere (e.g. a letter).
    ref.listen(widget.queryProvider, (_, next) {
      if (next.searchTerm.isEmpty && _controller.text.isNotEmpty) {
        _controller.clear();
        setState(() {});
      }
    });

    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: l.searchHint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _debounce?.cancel();
                  _controller.clear();
                  _apply('');
                  setState(() {});
                },
              ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
