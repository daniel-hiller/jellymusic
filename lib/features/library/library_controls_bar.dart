import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import 'library_query.dart';

/// Sort + direction + favourites-filter controls, shared by every library
/// list. Reads and writes the tab's [LibraryQuery] state provider.
class LibraryControlsBar extends ConsumerWidget {
  const LibraryControlsBar({
    super.key,
    required this.queryProvider,
    required this.sortOptions,
    this.searchable = true,
  });

  final StateProvider<LibraryQuery> queryProvider;

  /// Builds the sort menu for the current language. A builder (not a plain
  /// list) so the labels re-localise when the app language changes.
  final List<SortOption> Function(AppLocalizations) sortOptions;

  /// Whether to show the in-tab search field (the paged album/artist/song
  /// lists support it; the playlist tab doesn't).
  final bool searchable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final query = ref.watch(queryProvider);
    final notifier = ref.read(queryProvider.notifier);
    final options = sortOptions(l);
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
          if (searchable) ...[
            const SizedBox(width: 8),
            Expanded(child: _LibrarySearch(queryProvider: queryProvider)),
            const SizedBox(width: 4),
          ] else
            const Spacer(),
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
