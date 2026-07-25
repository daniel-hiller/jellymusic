import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jelly_colors.dart';
import '../../core/util/dominant_color.dart';
import '../../core/util/format.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/skeleton.dart';

/// Dominant colour extracted from the current cover art, used to tint the
/// player background. Returns null when extraction fails (e.g. cross-origin
/// images on web can't be read) so callers fall back to the static gradient.
///
/// Kept alive per artwork URL: the result is a single [Color] and recomputing
/// it while the full-screen player is being pushed would jank the transition.
/// [MiniPlayer] warms it on track change so it's ready before that.
final coverColorProvider =
    FutureProvider.autoDispose.family<Color?, String>((ref, url) async {
  ref.keepAlive();
  try {
    return await dominantColorOf(CachedNetworkImageProvider(url));
  } catch (_) {
    return null;
  }
});

/// Shared building blocks for the mobile and desktop Now-Playing screens and
/// the mini player. Keeping them here means both layouts stay in lock-step.

// ─── Chrome (background gradient + top bar) ──────────────────────────

/// Fades the cover's dominant colour into the background, animating on track
/// change. Falls back to a neutral gradient when no colour is available.
class PlayerBackground extends ConsumerWidget {
  const PlayerBackground({super.key, required this.child, this.artUrl});

  final Widget child;
  final String? artUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fallback tint when no cover colour is available; per-theme so light
    // themes get a light header instead of a dark slab.
    final neutral = context.colors.headerGradientTop;
    final color = artUrl == null
        ? null
        : ref.watch(coverColorProvider(artUrl!)).value;
    final top = color == null
        ? neutral
        : Color.alphaBlend(color.withValues(alpha: 0.5), neutral);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, context.colors.background],
          stops: const [0.0, 0.6],
        ),
      ),
      child: child,
    );
  }
}

/// Square cover art with a soft radial glow behind it, tinted from the cover's
/// dominant colour (falls back to the accent). A Nocturne signature used on the
/// Now Playing screens.
class GlowCover extends ConsumerWidget {
  const GlowCover({super.key, required this.artUrl, this.borderRadius = 16});

  final String? artUrl;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color =
        artUrl == null ? null : ref.watch(coverColorProvider(artUrl!)).value;
    final glow = color ?? context.colors.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.45),
            blurRadius: 90,
            spreadRadius: -18,
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: CoverArt(url: artUrl, borderRadius: borderRadius),
      ),
    );
  }
}

/// Down-chevron + centred album title, with optional trailing [actions].
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({super.key, this.album, this.actions = const []});

  final String? album;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            album ?? AppLocalizations.of(context).nowPlaying,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (actions.isEmpty)
          const SizedBox(width: 48)
        else
          ...actions,
      ],
    );
  }
}

// ─── Seek bar ────────────────────────────────────────────────────────

class PlayerSeekBar extends ConsumerWidget {
  const PlayerSeekBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final controller = ref.watch(playerControllerProvider);
    final total = item?.duration ?? Duration.zero;

    final max = total.inMilliseconds.toDouble();
    final value =
        position.inMilliseconds.clamp(0, total.inMilliseconds).toDouble();

    return Column(
      children: [
        Slider(
          value: max == 0 ? 0 : value,
          max: max == 0 ? 1 : max,
          onChanged: (v) =>
              controller.seek(Duration(milliseconds: v.round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(Format.duration(position),
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 12)),
              Text(Format.duration(total),
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Transport controls (shuffle / prev / play / next / repeat) ──────

class PlayerTransportControls extends ConsumerWidget {
  const PlayerTransportControls({super.key, this.playSize = 44});

  /// Diameter of the central play/pause button.
  final double playSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackStateProvider).value;
    final controller = ref.watch(playerControllerProvider);
    final playing = state?.playing ?? false;
    final shuffleOn = state?.shuffleMode == AudioServiceShuffleMode.all;
    final repeat = state?.repeatMode ?? AudioServiceRepeatMode.none;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle_rounded,
              color: shuffleOn ? context.colors.accent : context.colors.textSecondary),
          onPressed: controller.toggleShuffle,
        ),
        IconButton(
          iconSize: playSize * 0.9,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: controller.previous,
        ),
        Container(
          decoration: BoxDecoration(
            color: context.colors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: context.colors.accent.withValues(alpha: 0.55),
                blurRadius: 28,
                spreadRadius: -4,
              ),
            ],
          ),
          child: IconButton(
            iconSize: playSize,
            color: context.colors.onAccent,
            icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            onPressed: controller.togglePlay,
          ),
        ),
        IconButton(
          iconSize: playSize * 0.9,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: controller.next,
        ),
        IconButton(
          icon: Icon(
            repeat == AudioServiceRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: repeat == AudioServiceRepeatMode.none
                ? context.colors.textSecondary
                : context.colors.accent,
          ),
          onPressed: controller.cycleRepeat,
        ),
      ],
    );
  }
}

// ─── Favourite toggle for the current track ──────────────────────────

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;
    if (item == null) return const SizedBox.shrink();

    final isFav = ref.watch(favoriteProvider(item.id)).value ?? false;
    return IconButton(
      iconSize: size,
      tooltip: isFav ? 'Aus Favoriten entfernen' : 'Zu Favoriten',
      icon: Icon(
        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isFav ? context.colors.accent : context.colors.textSecondary,
      ),
      onPressed: () => ref.read(favoriteProvider(item.id).notifier).toggle(),
    );
  }
}

// ─── Sleep timer ─────────────────────────────────────────────────────

class SleepTimerButton extends ConsumerWidget {
  const SleepTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(sleepTimerProvider);
    final active = remaining != null;

    final l = AppLocalizations.of(context);
    return PopupMenuButton<int>(
      tooltip: l.sleepTimer,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bedtime_rounded,
              size: 22,
              color: active ? context.colors.accent : context.colors.textSecondary),
          if (active)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${remaining.inMinutes + 1}',
                style: TextStyle(
                    color: context.colors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      onSelected: (minutes) {
        final notifier = ref.read(sleepTimerProvider.notifier);
        if (minutes == 0) {
          notifier.cancel();
        } else {
          notifier.start(Duration(minutes: minutes));
        }
      },
      itemBuilder: (context) => [
        for (final m in const [15, 30, 45, 60])
          PopupMenuItem(value: m, child: Text(l.sleepMinutes('$m'))),
        if (active) PopupMenuItem(value: 0, child: Text(l.sleepOff)),
      ],
    );
  }
}

// ─── Volume (slider + mute-on-click icon) ────────────────────────────

class VolumeControl extends ConsumerWidget {
  const VolumeControl({super.key, this.width});

  /// Fixed slider width. Pass null to let the slider fill the parent's width
  /// (the parent must impose a bounded width, e.g. via [Expanded]).
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(volumeProvider).value ?? 1.0;
    final controller = ref.watch(playerControllerProvider);

    final icon = volume <= 0
        ? Icons.volume_off_rounded
        : volume < 0.5
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded;

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      ),
      child: Slider(
        value: volume.clamp(0.0, 1.0),
        onChanged: controller.setVolume,
      ),
    );

    return Listener(
      // Mouse wheel over the control nudges the volume (up = louder).
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) {
          const step = 0.05;
          final delta = signal.scrollDelta.dy < 0 ? step : -step;
          controller.setVolume((volume + delta).clamp(0.0, 1.0));
        }
      },
      child: Row(
        mainAxisSize: width == null ? MainAxisSize.max : MainAxisSize.min,
        children: [
          IconButton(
            tooltip: volume <= 0 ? 'Ton an' : 'Stumm',
            icon: Icon(icon, color: context.colors.textSecondary),
            onPressed: controller.toggleMute,
          ),
          width == null
              ? Expanded(child: slider)
              : SizedBox(width: width, child: slider),
        ],
      ),
    );
  }
}

// ─── Play queue ──────────────────────────────────────────────────────

class QueueList extends ConsumerWidget {
  const QueueList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider).value ?? const [];
    final currentIndex =
        ref.watch(playbackStateProvider).value?.queueIndex;
    final controller = ref.watch(playerControllerProvider);

    if (queue.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).queueEmpty));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queue.length,
      buildDefaultDragHandles: false,
      // onReorderItem already delivers the final target index (adjusted for
      // the removed item), so no manual off-by-one correction is needed.
      onReorderItem: (oldIndex, newIndex) =>
          controller.moveQueueItem(oldIndex, newIndex),
      itemBuilder: (context, i) {
        final m = queue[i];
        final isCurrent = i == currentIndex;
        return ListTile(
          key: ValueKey('queue_$i'),
          dense: true,
          onTap: () => controller.skipToQueueItem(i),
          leading: isCurrent
              ? SizedBox(
                  width: 40,
                  child: Icon(Icons.equalizer_rounded,
                      color: context.colors.accent, size: 20),
                )
              : CoverArt(url: m.artUri?.toString(), size: 40, borderRadius: 4),
          title: Text(
            m.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent ? context.colors.accent : context.colors.textPrimary,
            ),
          ),
          subtitle: Text(
            m.artist ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.colors.textSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: AppLocalizations.of(context).commonRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: context.colors.textTertiary,
                onPressed: () => controller.removeQueueItem(i),
              ),
              ReorderableDragStartListener(
                index: i,
                child: Icon(Icons.drag_handle_rounded,
                    color: context.colors.textTertiary),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Lyrics (synced highlight + auto-scroll) ─────────────────────────

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  static const double _lineExtent = 48;
  final _scrollController = ScrollController();
  int _lastActive = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeScroll(int active, int count, double viewportHeight) {
    if (!mounted || active < 0 || active == _lastActive) return;
    _lastActive = active;
    if (!_scrollController.hasClients) return;
    final target = (active * _lineExtent) -
        (viewportHeight / 2) +
        (_lineExtent / 2);
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target.clamp(0.0, max),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider(widget.itemId));
    final position =
        ref.watch(positionProvider).value ?? Duration.zero;

    final l = AppLocalizations.of(context);
    return lyricsAsync.when(
      loading: () => const LyricsSkeleton(),
      error: (e, _) => Center(child: Text(l.lyricsUnavailable)),
      data: (lyrics) {
        if (lyrics == null || lyrics.lines.isEmpty) {
          return Center(child: Text(l.lyricsNone));
        }
        final lines = lyrics.lines;
        final synced = lyrics.isSynced;
        final positionTicks = position.inMilliseconds * 10000;

        // Active line = last timed line whose start is in the past.
        var active = -1;
        if (synced) {
          for (var i = 0; i < lines.length; i++) {
            final t = lines[i].startTicks;
            if (t != null && t <= positionTicks) {
              active = i;
            } else if (t != null && t > positionTicks) {
              break;
            }
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            if (synced) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _maybeScroll(active, lines.length, constraints.maxHeight),
              );
            }
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemExtent: synced ? _lineExtent : null,
              itemCount: lines.length,
              itemBuilder: (context, i) {
                final isActive = synced && i == active;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Text(
                    lines[i].text.isEmpty ? '♪' : lines[i].text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isActive ? 18 : 16,
                      height: 1.3,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive
                          ? context.colors.textPrimary
                          : (synced
                              ? context.colors.textTertiary
                              : context.colors.textSecondary),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
