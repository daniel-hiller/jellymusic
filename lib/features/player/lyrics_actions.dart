import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jelly_colors.dart';
import '../../core/util/format.dart';
import '../../data/models/lyrics_candidate.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';

/// Ask the server's lyric providers what they have for a track and let the
/// listener pick one. Saving attaches it to the track for every client, so the
/// list shows enough of each match — provider, artist, album, length, whether
/// it is timed — to tell a right answer from a plausible wrong one.
Future<void> showLyricsSearchSheet(
  BuildContext context, {
  required String itemId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _LyricsSearchSheet(itemId: itemId),
  );
}

class _LyricsSearchSheet extends ConsumerWidget {
  const _LyricsSearchSheet({required this.itemId});

  final String itemId;

  Future<void> _save(
      BuildContext context, WidgetRef ref, LyricsCandidate candidate) async {
    // Captured before the sheet pops — its own context is gone by then.
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await ref.read(musicRepositoryProvider).saveLyrics(itemId, candidate.id);
      ref.invalidate(lyricsProvider(itemId));
      messenger.showSnackBar(SnackBar(content: Text(l.lyricsSaved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.lyricsSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final results = ref.watch(lyricsSearchProvider(itemId));

    return SafeArea(
      child: ConstrainedBox(
        // Tall enough to be worth scrolling, short enough to stay a sheet.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(l.lyricsPickTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Flexible(
              child: results.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                // A server with no lyric plugin answers with an empty list
                // rather than an error, so both endings say the same thing.
                error: (_, __) => _Message(l.lyricsSearchFailed),
                data: (items) => items.isEmpty
                    ? _Message(l.lyricsNoResults)
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => _CandidateTile(
                          candidate: items[i],
                          onTap: () => _save(context, ref, items[i]),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate, required this.onTap});

  final LyricsCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final subtitle = [
      if (candidate.artist != null) candidate.artist!,
      if (candidate.album != null) candidate.album!,
      if (candidate.duration != null) Format.duration(candidate.duration!),
    ].join(' • ');

    return ListTile(
      leading: Icon(
        candidate.isSynced
            ? Icons.graphic_eq_rounded
            : Icons.notes_rounded,
        color: candidate.isSynced
            ? context.colors.accent
            : context.colors.textTertiary,
      ),
      title: Text(
        candidate.title ?? candidate.provider,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.colors.textSecondary),
            ),
      trailing: Text(
        candidate.isSynced ? l.lyricsSynced : l.lyricsPlain,
        style: TextStyle(
          fontSize: 12,
          color: context.colors.textTertiary,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colors.textSecondary),
      ),
    );
  }
}

/// Detach the track's current lyrics. Returns true when the server accepted it.
Future<bool> removeLyrics(
  BuildContext context,
  WidgetRef ref, {
  required String itemId,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(musicRepositoryProvider).deleteLyrics(itemId);
    ref.invalidate(lyricsProvider(itemId));
    messenger.showSnackBar(SnackBar(content: Text(l.lyricsRemoved)));
    return true;
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.lyricsRemoveFailed)));
    return false;
  }
}
