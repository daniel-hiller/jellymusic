import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../providers/providers.dart';

/// Start an Instant Mix ("radio") seeded from [itemId] (album, artist, song,
/// playlist or genre) and begin playback. Shows a snackbar on success/error.
Future<void> startRadio(
  BuildContext context,
  WidgetRef ref,
  String itemId,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final tracks = await ref.read(musicRepositoryProvider).instantMix(itemId);
    if (tracks.isEmpty) return;
    await ref.read(playerControllerProvider).playItems(tracks);
    messenger.showSnackBar(SnackBar(content: Text(l.radioStarted)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}
