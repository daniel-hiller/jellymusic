import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import '../../widgets/cover_art.dart';
import 'cast_sheet.dart';
import 'player_widgets.dart';

/// What fills the centre of the phone player. The queue and lyrics live inline
/// where the cover is — the queue replaces it, the lyrics sit over a blurred
/// copy of it — rather than in bottom sheets.
enum _CentrePane { cover, queue, lyrics }

/// Portrait/phone player: large art with the transport controls below. The
/// artwork accepts gestures — swipe left/right to change track, drag the whole
/// screen down to dismiss — and the queue/lyrics buttons swap the centre pane
/// in place.
class NowPlayingMobile extends ConsumerStatefulWidget {
  const NowPlayingMobile({super.key, required this.item});

  final MediaItem item;

  @override
  ConsumerState<NowPlayingMobile> createState() => _NowPlayingMobileState();
}

class _NowPlayingMobileState extends ConsumerState<NowPlayingMobile> {
  _CentrePane _pane = _CentrePane.cover;

  // Drag-to-dismiss: fraction of screen height the content is offset by.
  double _dismiss = 0;
  bool _dragging = false;

  MediaItem get item => widget.item;

  void _toggle(_CentrePane pane) => setState(
        () => _pane = _pane == pane ? _CentrePane.cover : pane,
      );

  // ─── Drag-to-dismiss ───────────────────────────────────────────────

  void _onDragUpdate(DragUpdateDetails d, double height) {
    // Downward only; a small upward drag just resists.
    setState(
        () => _dismiss = (_dismiss + d.primaryDelta! / height).clamp(0, 1));
  }

  void _onDragEnd(DragEndDetails d) {
    final fling = d.primaryVelocity != null && d.primaryVelocity! > 700;
    if (_dismiss > 0.18 || fling) {
      Navigator.of(context).maybePop();
    } else {
      setState(() {
        _dragging = false;
        _dismiss = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height;
    final art = item.artUri?.toString();

    return Scaffold(
      backgroundColor: context.colors.background,
      // The drag moves the tinted background along with everything on it.
      // Sliding only the contents leaves the backdrop hanging in place until
      // the route is popped, which it then catches up with in one jump.
      body: AnimatedSlide(
        // Follow the finger 1:1 while dragging, snap back smoothly on release.
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        offset: Offset(0, _dismiss),
        child: Opacity(
          opacity: (1 - _dismiss * 0.6).clamp(0.0, 1.0),
          child: PlayerBackground(
            artUrl: art,
            child: SafeArea(
              child: Column(
                children: [
                  // The top bar is a reliable drag-to-dismiss grip that never
                  // fights an inner scroll view.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) =>
                        setState(() => _dragging = true),
                    onVerticalDragUpdate: (d) => _onDragUpdate(d, height),
                    onVerticalDragEnd: _onDragEnd,
                    child: PlayerTopBar(
                      actions: const [
                        CastButton(),
                        SleepTimerButton(),
                        FavoriteButton(size: 24),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: _CentreArea(
                        pane: _pane,
                        art: art,
                        itemId: item.id,
                        onDragUpdate: (d) => _onDragUpdate(d, height),
                        onDragStart: () => setState(() => _dragging = true),
                        onDragEnd: _onDragEnd,
                        onNext: () => ref.read(playerControllerProvider).next(),
                        onPrevious: () =>
                            ref.read(playerControllerProvider).previous(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: context.colors.accentBright, fontSize: 16),
                        ),
                        if ((item.album ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.album!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const PlayerSeekBar(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: PlayerTransportControls(playSize: 56),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: l.queueTab,
                          icon: const Icon(Icons.queue_music_rounded),
                          isSelected: _pane == _CentrePane.queue,
                          color: _pane == _CentrePane.queue
                              ? context.colors.accent
                              : context.colors.textSecondary,
                          onPressed: () => _toggle(_CentrePane.queue),
                        ),
                        const Expanded(child: VolumeControl()),
                        IconButton(
                          tooltip: l.lyricsTab,
                          icon: const Icon(Icons.lyrics_rounded),
                          isSelected: _pane == _CentrePane.lyrics,
                          color: _pane == _CentrePane.lyrics
                              ? context.colors.accent
                              : context.colors.textSecondary,
                          onPressed: () => _toggle(_CentrePane.lyrics),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The swappable centre: cover (with track-change swipes), queue, or lyrics
/// over a blurred cover. A cross-fade keeps the switch calm.
class _CentreArea extends StatelessWidget {
  const _CentreArea({
    required this.pane,
    required this.art,
    required this.itemId,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onNext,
    required this.onPrevious,
  });

  final _CentrePane pane;
  final String? art;
  final String itemId;
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (pane) {
      _CentrePane.queue =>
        _CoverBackdrop(art: art, child: const QueueList()),
      _CentrePane.lyrics =>
        _CoverBackdrop(art: art, child: LyricsView(itemId: itemId)),
      _CentrePane.cover => _SwipeableCover(
          art: art,
          onDragStart: onDragStart,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          onNext: onNext,
          onPrevious: onPrevious,
        ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(pane), child: child),
    );
  }
}

/// Cover art that changes track on a horizontal fling and forwards vertical
/// drags to the dismiss handler.
class _SwipeableCover extends StatelessWidget {
  const _SwipeableCover({
    required this.art,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onNext,
    required this.onPrevious,
  });

  final String? art;
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Horizontal + vertical recognisers on one detector never fight each
      // other — the arena picks the axis of the drag.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v <= -250) {
          onNext(); // swipe left → next
        } else if (v >= 250) {
          onPrevious(); // swipe right → previous
        }
      },
      onVerticalDragStart: (_) => onDragStart(),
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Center(child: GlowCover(artUrl: art)),
    );
  }
}

/// [child] (queue or lyrics) over a blurred, dimmed copy of the current cover,
/// filling the cover area so the pane change never reveals an empty void.
class _CoverBackdrop extends StatelessWidget {
  const _CoverBackdrop({required this.art, required this.child});

  final String? art;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (art != null)
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: CoverArt(url: art, borderRadius: 16),
            ),
          // Scrim so the content stays legible over any artwork.
          Container(color: context.colors.background.withValues(alpha: 0.6)),
          child,
        ],
      ),
    );
  }
}
