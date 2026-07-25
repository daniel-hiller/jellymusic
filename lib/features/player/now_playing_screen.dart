import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';
import 'now_playing_desktop.dart';
import 'now_playing_mobile.dart';

/// Full-screen player. Picks a layout by width: a two-pane desktop layout
/// (art + Queue/Lyrics tabs) on wide screens, the single-column phone layout
/// otherwise. Both share the widgets in `player_widgets.dart`.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;

    if (item == null) {
      return Scaffold(
        body: Center(child: Text(AppLocalizations.of(context).nothingPlaying)),
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return isWide
        ? NowPlayingDesktop(item: item)
        : NowPlayingMobile(item: item);
  }
}
