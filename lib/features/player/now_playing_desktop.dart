import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import 'cast_sheet.dart';
import 'player_widgets.dart';

/// Wide-screen player: album art on the left, a Queue / Lyrics tab pane on
/// the right, and the transport + volume + favourite controls in a clean bar
/// spanning the bottom.
class NowPlayingDesktop extends ConsumerWidget {
  const NowPlayingDesktop({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: PlayerBackground(
        artUrl: item.artUri?.toString(),
        child: SafeArea(
          child: Column(
            children: [
              PlayerTopBar(
                album: item.album,
                actions: const [CastButton(), SleepTimerButton()],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _CoverPane(item: item)),
                      const SizedBox(width: 32),
                      Expanded(child: _TabsPane(itemId: item.id)),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: context.colors.surfaceHigh),
              _ControlBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPane extends StatelessWidget {
  const _CoverPane({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: GlowCover(artUrl: item.artUri?.toString()),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          item.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          item.artist ?? '',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.colors.accentBright, fontSize: 16),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TabsPane extends StatelessWidget {
  const _TabsPane({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l.queueTab),
              Tab(text: l.lyricsTab),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const QueueList(),
                LyricsView(itemId: itemId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PlayerSeekBar(),
          Row(
            children: [
              // Left: favourite. Fixed-width so the transport stays centred.
              const SizedBox(
                width: 200,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FavoriteButton(size: 26),
                ),
              ),
              const Expanded(
                child: Center(
                  child: SizedBox(
                    width: 340,
                    child: PlayerTransportControls(playSize: 56),
                  ),
                ),
              ),
              // Right: volume, mirroring the left width.
              const SizedBox(
                width: 200,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: VolumeControl(width: 120),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
