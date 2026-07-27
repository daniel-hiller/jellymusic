import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/skeleton.dart';
import 'paged_library.dart';

/// Reusable playlist actions: create a playlist and add tracks to one. Kept
/// as top-level helpers so any screen (library, album, song tile) can call
/// them.

/// Prompt for a name and create a playlist (optionally seeded with
/// [seedItemIds]). Returns the new playlist id, or null if cancelled/failed.
///
/// [confirmation] replaces the text of the success snackbar for callers whose
/// wording differs from "playlist created" — saving the play queue, say.
Future<String?> showCreatePlaylistDialog(
  BuildContext context,
  WidgetRef ref, {
  List<String> seedItemIds = const [],
  String Function(String name)? confirmation,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.playlistNew),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: l.playlistNameHint),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(controller.text.trim()),
          child: Text(l.commonCreate),
        ),
      ],
    ),
  );

  if (name == null || name.isEmpty) return null;

  try {
    final id = await ref
        .read(musicRepositoryProvider)
        .createPlaylist(name, itemIds: seedItemIds);
    invalidatePlaylists(ref);
    messenger.showSnackBar(SnackBar(
        content: Text(confirmation?.call(name) ?? l.playlistCreated(name))));
    return id;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l.errorWithMessage('$e'))));
    return null;
  }
}

/// Bottom sheet to add [itemIds] to an existing playlist or a new one.
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<String> itemIds,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _AddToPlaylistSheet(itemIds: itemIds),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.itemIds});

  final List<String> itemIds;

  Future<void> _addTo(
      BuildContext context, WidgetRef ref, String playlistId, String name) async {
    // Capture the app-level messenger + strings before popping the sheet, so
    // the snackbar still shows once the sheet's own context is gone.
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await ref
          .read(musicRepositoryProvider)
          .addToPlaylist(playlistId, itemIds);
      ref.invalidate(playlistDetailProvider(playlistId));
      invalidatePlaylists(ref);
      messenger.showSnackBar(
        SnackBar(
            content: Text(itemIds.length == 1
                ? l.addedToPlaylistOne(name)
                : l.addedToPlaylistMany('${itemIds.length}', name))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorWithMessage('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final playlists = ref.watch(playlistsProvider);
    final service = ref.watch(jellyfinServiceProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(l.addToPlaylistTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: context.colors.surfaceHigher,
              child: Icon(Icons.add_rounded, color: context.colors.accent),
            ),
            title: Text(l.playlistNew),
            // Show the create dialog over the sheet (root navigator), then
            // close the sheet — keeps a valid context throughout.
            onTap: () async {
              await showCreatePlaylistDialog(context, ref,
                  seedItemIds: itemIds);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const Divider(height: 1),
          Flexible(
            child: playlists.when(
              loading: () => const TileRowsSkeleton(
                rows: 4,
                leadingSize: 40,
                shrinkWrap: true,
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.errorWithMessage('$e')),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.playlistsNone),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return ListTile(
                      leading: CoverArt(
                        url: service.primaryImageUrl(p, size: 96),
                        size: 40,
                        borderRadius: 4,
                      ),
                      title: Text(p.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _addTo(context, ref, p.id, p.name),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
