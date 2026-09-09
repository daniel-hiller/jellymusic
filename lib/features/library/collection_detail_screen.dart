import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/album_card.dart';
import '../../widgets/skeleton.dart';

/// What a collection gathers, as a grid of its albums.
///
/// Collections are curated on the server — a box set, a label's back
/// catalogue — so this only shows what is in one; nothing here edits it.
class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final collection = ref.watch(artistByIdProvider(collectionId)).value;
    final items = ref.watch(collectionItemsProvider(collectionId));

    return Scaffold(
      appBar: AppBar(title: Text(collection?.name ?? '')),
      body: items.when(
        loading: () => const AlbumGridSkeleton(),
        error: (e, _) => Center(child: Text(l.errorWithMessage('$e'))),
        data: (albums) {
          if (albums.isEmpty) {
            return Center(
              child: Text(
                l.collectionEmpty,
                style: TextStyle(color: context.colors.textSecondary),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisExtent: 220,
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
            ),
            itemCount: albums.length,
            itemBuilder: (context, i) => AlbumCard(
              album: albums[i],
              onTap: () => context.go('/library/album/${albums[i].id}'),
            ),
          );
        },
      ),
    );
  }
}
