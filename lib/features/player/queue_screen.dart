import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import 'player_widgets.dart';

/// The play queue as its own surface, reachable from the mini player (so it's
/// no longer buried inside Now Playing). Reuses [QueueList] — same reorder /
/// remove / tap-to-jump behaviour — under a plain app bar.
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final count = ref.watch(queueProvider).value?.length ?? 0;
    final controller = ref.watch(playerControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.queueTab),
        actions: [
          if (count > 0)
            IconButton(
              tooltip: l.shuffleAction,
              icon: const Icon(Icons.shuffle_rounded),
              onPressed: controller.toggleShuffle,
            ),
        ],
      ),
      body: const SafeArea(child: QueueList()),
    );
  }
}
