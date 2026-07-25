import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../widgets/cover_art.dart';

/// Spotify-style "mini player": shrinks the (single) desktop window into a
/// small, always-on-top compact bar. Flutter desktop is single-window, so the
/// main window *becomes* the mini player; expanding restores the previous size
/// and position.
class MiniWindowController extends Notifier<bool> {
  Size? _savedSize;
  Offset? _savedPosition;

  static const _miniSize = Size(400, 132);

  @override
  bool build() => false;

  Future<void> enter() async {
    if (state) return;
    _savedSize = await windowManager.getSize();
    _savedPosition = await windowManager.getPosition();
    // Order matters on GTK/Linux: lower the minimum first, THEN resize. Locking
    // resizable before setSize would pin the window at its current size, so we
    // don't lock it at all here.
    await windowManager.setMinimumSize(const Size(300, 110));
    await windowManager.setSize(_miniSize);
    await windowManager.setAlwaysOnTop(true);
    state = true;
  }

  Future<void> exit() async {
    if (!state) return;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setMinimumSize(const Size(480, 600));
    if (_savedSize != null) await windowManager.setSize(_savedSize!);
    if (_savedPosition != null) {
      await windowManager.setPosition(_savedPosition!);
    }
    state = false;
  }
}

final miniWindowProvider =
    NotifierProvider<MiniWindowController, bool>(MiniWindowController.new);

/// The compact UI shown while the window is in mini mode. Fills the small
/// window: cover, title/artist, transport, a thin progress line, and a button
/// to expand back to the full app.
class MiniPlayerWindow extends ConsumerWidget {
  const MiniPlayerWindow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final item = ref.watch(currentMediaItemProvider).value;
    final playing = ref.watch(isPlayingProvider);
    final controller = ref.watch(playerControllerProvider);
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final total = item?.duration ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    Future<void> expand() async {
      await ref.read(miniWindowProvider.notifier).exit();
      if (context.mounted) context.pop();
    }

    return Scaffold(
      backgroundColor: context.colors.surfaceHigh,
      body: Column(
        children: [
          // Drag the whole bar to move the window (frameless-friendly).
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                child: Row(
                  children: [
                    CoverArt(
                      url: item?.artUri?.toString(),
                      size: 64,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item?.title ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item?.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: controller.previous,
                    ),
                    IconButton(
                      iconSize: 34,
                      icon: Icon(playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded),
                      onPressed: controller.togglePlay,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: controller.next,
                    ),
                    IconButton(
                      tooltip: l.miniPlayerExpand,
                      icon: const Icon(Icons.open_in_full_rounded, size: 18),
                      onPressed: expand,
                    ),
                  ],
                ),
              ),
            ),
          ),
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: context.colors.surfaceHigher,
            valueColor: AlwaysStoppedAnimation<Color>(context.colors.accent),
          ),
        ],
      ),
    );
  }
}
