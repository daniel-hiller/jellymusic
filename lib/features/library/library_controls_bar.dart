import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/theme/jelly_colors.dart';
import 'library_query.dart';

/// Sort + direction + favourites-filter controls, shared by every library
/// list. Reads and writes the tab's [LibraryQuery] state provider.
class LibraryControlsBar extends ConsumerWidget {
  const LibraryControlsBar({
    super.key,
    required this.queryProvider,
    required this.sortOptions,
  });

  final StateProvider<LibraryQuery> queryProvider;
  final List<SortOption> sortOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(queryProvider);
    final notifier = ref.read(queryProvider.notifier);
    final current = sortOptions.firstWhere(
      (o) => o.field == query.sortField,
      orElse: () => sortOptions.first,
    );
    final isRandom = current.field == 'Random';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          PopupMenuButton<String>(
            initialValue: current.field,
            onSelected: (field) => notifier.state =
                query.copyWith(sortField: field),
            itemBuilder: (context) => [
              for (final o in sortOptions)
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
              tooltip: query.descending ? 'Absteigend' : 'Aufsteigend',
              icon: Icon(
                query.descending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 20,
              ),
              onPressed: () => notifier.state =
                  query.copyWith(descending: !query.descending),
            ),
          const Spacer(),
          IconButton(
            tooltip: query.favoritesOnly
                ? 'Alle anzeigen'
                : 'Nur Favoriten',
            icon: Icon(
              query.favoritesOnly
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: query.favoritesOnly
                  ? context.colors.accent
                  : context.colors.textSecondary,
            ),
            onPressed: () => notifier.state =
                query.copyWith(favoritesOnly: !query.favoritesOnly),
          ),
        ],
      ),
    );
  }
}
