import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/cast_providers.dart';

/// Device picker: this device plus every Jellyfin client that accepts remote
/// control. Picking one hands the current queue over and keeps controlling it
/// from here; picking "this device" pauses the remote and comes back.
Future<void> showCastSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    showDragHandle: true,
    builder: (_) => const _CastSheet(),
  );
}

class _CastSheet extends ConsumerWidget {
  const _CastSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final targets = ref.watch(castTargetsProvider);
    final current = ref.watch(castTargetProvider);

    // Close first, then switch. Handing playback over takes seconds, and
    // popping *after* the await ran the pop inside the frame that the resumed
    // player triggered — Navigator asserts on that (`!_debugLocked`) and the
    // app ends up on a blank page.
    void pick(Future<void> Function() action) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      action().catchError((Object e) {
        messenger.showSnackBar(SnackBar(content: Text(l.castFailed('$e'))));
      });
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.castTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.computer_rounded,
              color: current == null ? context.colors.accent : null,
            ),
            title: Text(l.castThisDevice),
            trailing: current == null
                ? Icon(Icons.check_rounded, color: context.colors.accent)
                : null,
            onTap: current == null
                ? null
                : () => pick(ref.read(castTargetProvider.notifier).playHere),
          ),
          const Divider(height: 1),
          targets.when(
            loading: () => ListTile(
              leading: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text(l.castSearching),
            ),
            error: (e, _) => ListTile(title: Text(l.castFailed('$e'))),
            data: (sessions) {
              if (sessions.isEmpty) {
                return ListTile(
                  leading: Icon(Icons.devices_other_rounded,
                      color: context.colors.textTertiary),
                  title: Text(
                    l.castNoDevices,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                );
              }
              return Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    final selected = current?.sessionId == s.id;
                    return ListTile(
                      leading: Icon(
                        Icons.speaker_rounded,
                        color: selected ? context.colors.accent : null,
                      ),
                      title: Text(s.deviceName ?? s.client ?? s.id),
                      subtitle: Text(
                        [s.client, s.userName]
                            .whereType<String>()
                            .where((v) => v.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                      trailing: selected
                          ? Icon(Icons.check_rounded,
                              color: context.colors.accent)
                          : null,
                      onTap: selected
                          ? null
                          : () => pick(() => ref
                              .read(castTargetProvider.notifier)
                              .castTo(s)),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Cast button for the player chrome. Tints itself and shows the target's name
/// while casting, so it's obvious playback left this device.
class CastButton extends ConsumerWidget {
  const CastButton({super.key, this.showLabel = false});

  /// Append the target device name next to the icon (desktop mini player).
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final target = ref.watch(castTargetProvider);
    final casting = target != null;

    final icon = Icon(
      casting ? Icons.cast_connected_rounded : Icons.cast_rounded,
      color: casting ? context.colors.accent : context.colors.textSecondary,
      size: 22,
    );

    if (!showLabel || !casting) {
      return IconButton(
        tooltip: casting ? l.castPlayingOn(target.name) : l.castTooltip,
        icon: icon,
        onPressed: () => showCastSheet(context),
      );
    }

    return Tooltip(
      message: l.castPlayingOn(target.name),
      child: TextButton.icon(
        onPressed: () => showCastSheet(context),
        icon: icon,
        label: Text(
          target.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.colors.accent, fontSize: 12),
        ),
      ),
    );
  }
}
