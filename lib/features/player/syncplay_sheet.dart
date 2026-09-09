import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/syncplay_providers.dart';

/// Group picker for listening together: the groups this user may join, a way
/// to start one, and a way out of the one they are in.
Future<void> showSyncPlaySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    showDragHandle: true,
    builder: (_) => const _SyncPlaySheet(),
  );
}

class _SyncPlaySheet extends ConsumerWidget {
  const _SyncPlaySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(syncPlayStateProvider).value;
    final groups = ref.watch(syncPlayGroupsProvider);
    final controller = ref.watch(syncPlayControllerProvider);

    // Close first, then act: joining is a round trip, and popping afterwards
    // runs the pop inside a frame the group update already triggered.
    void run(Future<void> Function() action) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      action().catchError((Object e) {
        messenger.showSnackBar(
            SnackBar(content: Text(l.syncPlayFailed('$e'))));
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
              child: Text(l.syncPlayTitle,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          if (state != null && state.active) ...[
            ListTile(
              leading: Icon(Icons.groups_rounded, color: context.colors.accent),
              title: Text(l.syncPlayJoined(state.groupName)),
              subtitle: Text(
                state.waiting
                    ? l.syncPlayWaiting
                    : l.syncPlayMembers('${state.members.length}'),
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: Text(l.syncPlayLeave),
              onTap: () => run(controller.leave),
            ),
          ] else ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: context.colors.surfaceHigher,
                child: Icon(Icons.add_rounded, color: context.colors.accent),
              ),
              title: Text(l.syncPlayNewGroup),
              onTap: () async {
                final name = await _askForName(context);
                if (name == null || !context.mounted) return;
                run(() => controller.create(name));
              },
            ),
            const Divider(height: 1),
            Flexible(
              child: groups.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                // SyncPlay is a per-user permission and can be off for the
                // server entirely; either way the list call fails rather than
                // coming back empty, so one message covers both.
                error: (_, __) => _Message(l.syncPlayUnsupported),
                data: (items) => items.isEmpty
                    ? _Message(l.syncPlayNone)
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final group = items[i];
                          return ListTile(
                            leading: const Icon(Icons.groups_outlined),
                            title: Text(group.name),
                            subtitle: group.participants.isEmpty
                                ? null
                                : Text(
                                    group.participants.join(', '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: context.colors.textSecondary),
                                  ),
                            onTap: () => run(() => controller.join(group.id)),
                          );
                        },
                      ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

Future<String?> _askForName(BuildContext context) {
  final l = AppLocalizations.of(context);
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.syncPlayNewGroup),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l.syncPlayNameHint),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(controller.text.trim()),
          child: Text(l.commonCreate),
        ),
      ],
    ),
  ).then((value) => (value == null || value.isEmpty) ? null : value);
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colors.textSecondary),
      ),
    );
  }
}

/// Opens the group picker, and shows at a glance whether this device is in a
/// group — the transport behaves differently while it is, so that has to be
/// visible rather than inferred from playback that will not obey.
class SyncPlayButton extends ConsumerWidget {
  const SyncPlayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(syncPlayStateProvider).value;
    final active = state?.active ?? false;

    return IconButton(
      tooltip: active ? l.syncPlayJoined(state!.groupName) : l.syncPlayTitle,
      icon: Icon(
        active ? Icons.groups_rounded : Icons.groups_outlined,
        color: active ? context.colors.accent : context.colors.textSecondary,
        size: 22,
      ),
      onPressed: () => showSyncPlaySheet(context),
    );
  }
}
