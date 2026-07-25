import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/cast_providers.dart';
import '../../providers/player_providers.dart';
import '../../widgets/cover_art.dart';
import 'cast_sheet.dart';
import 'player_widgets.dart';

/// The persistent bar above the nav showing the current track. Compact on
/// phones (cover + title + play/next); on desktop it uses the extra width for
/// prev/next, a favourite toggle and a volume slider. Tapping the track info
/// opens the full Now Playing screen.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;
    final castTarget = ref.watch(castTargetProvider);
    // Stay visible while casting even with nothing playing yet: the cast
    // button lives in here, and hiding the bar would strand the user on the
    // remote device with no way back.
    if (item == null && castTarget == null) return const SizedBox.shrink();

    // Warm the cover colour while the mini player is on screen: computing it
    // lazily inside the full-screen player would stall its opening animation.
    final art = item?.artUri?.toString();
    if (art != null) ref.watch(coverColorProvider(art));

    final l = AppLocalizations.of(context);
    final playing = ref.watch(isPlayingProvider);
    final controller = ref.watch(playerControllerProvider);
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final total = item?.duration ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    final trackInfo = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            CoverArt(
              url: art,
              size: 44,
              borderRadius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item?.title ?? l.nothingPlaying,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    // With nothing playing on the target, name the target
                    // instead of leaving an empty line.
                    item?.artist ??
                        (castTarget == null
                            ? ''
                            : l.castPlayingOn(castTarget.name)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: context.colors.surfaceHigh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: isWide
                ? Row(
                    children: [
                      Expanded(flex: 4, child: trackInfo),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                        ],
                      ),
                      Expanded(
                        flex: 4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const FavoriteButton(size: 22),
                            IconButton(
                              tooltip: l.queueTab,
                              icon: const Icon(
                                  Icons.queue_music_rounded, size: 22),
                              onPressed: () => context.push('/queue'),
                            ),
                            const CastButton(showLabel: true),
                            const VolumeControl(width: 110),
                            IconButton(
                              tooltip: l.fullscreenTooltip,
                              icon: const Icon(
                                  Icons.open_in_full_rounded, size: 20),
                              onPressed: onTap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: trackInfo),
                      IconButton(
                        tooltip: l.queueTab,
                        icon: const Icon(Icons.queue_music_rounded, size: 24),
                        onPressed: () => context.push('/queue'),
                      ),
                      const CastButton(),
                      IconButton(
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 30,
                        ),
                        onPressed: controller.togglePlay,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 28),
                        onPressed: controller.next,
                      ),
                    ],
                  ),
          ),
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: context.colors.surfaceHigher,
            valueColor:
                AlwaysStoppedAnimation<Color>(context.colors.accent),
          ),
        ],
      ),
    );
  }
}
