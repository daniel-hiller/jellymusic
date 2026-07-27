import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/jelly_colors.dart';
import '../../core/util/item_x.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/skeleton.dart';
import 'paged_library.dart';

/// Multi-select picker to add tracks to a playlist. Lists the library's
/// songs with a client-side text filter; tap to (de)select, then confirm.
class PlaylistAddSongsScreen extends ConsumerStatefulWidget {
  const PlaylistAddSongsScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<PlaylistAddSongsScreen> createState() =>
      _PlaylistAddSongsScreenState();
}

class _PlaylistAddSongsScreenState
    extends ConsumerState<PlaylistAddSongsScreen> {
  final _selected = <String>{};
  String _filter = '';
  bool _saving = false;

  Future<void> _confirm() async {
    if (_selected.isEmpty) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(musicRepositoryProvider)
          .addToPlaylist(widget.playlistId, _selected.toList());
      ref.invalidate(playlistDetailProvider(widget.playlistId));
      invalidatePlaylists(ref);
      messenger.showSnackBar(
        SnackBar(content: Text(l.addedCount('${_selected.length}'))),
      );
      router.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(
            SnackBar(content: Text(l.errorWithMessage('$e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final songs = ref.watch(songsProvider);
    final service = ref.watch(jellyfinServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.isEmpty
            ? l.addSongsTitle
            : l.selectedCount('${_selected.length}')),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty || _saving ? null : _confirm,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.commonAdd),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l.filterSongsHint,
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: songs.when(
        loading: () => const TileRowsSkeleton(leadingSize: 40),
        error: (e, _) => Center(child: Text(l.errorWithMessage('$e'))),
        data: (items) {
          final filtered = _filter.isEmpty
              ? items
              : items
                  .where((s) =>
                      s.name.toLowerCase().contains(_filter) ||
                      s.trackArtistLabel.toLowerCase().contains(_filter))
                  .toList();
          if (filtered.isEmpty) {
            return Center(child: Text(l.noSongs));
          }
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final s = filtered[i];
              final checked = _selected.contains(s.id);
              return CheckboxListTile(
                value: checked,
                onChanged: (_) => setState(() {
                  checked ? _selected.remove(s.id) : _selected.add(s.id);
                }),
                controlAffinity: ListTileControlAffinity.trailing,
                activeColor: context.colors.accent,
                secondary: CoverArt(
                  url: service.primaryImageUrl(s, size: 96),
                  size: 40,
                  borderRadius: 4,
                ),
                title: Text(s.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(s.trackArtistLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            },
          );
        },
      ),
    );
  }
}
