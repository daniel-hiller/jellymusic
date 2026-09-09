import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/jellyfin/syncplay_controller.dart';
import '../data/jellyfin/syncplay_repository.dart';
import 'providers.dart';

final syncPlayRepositoryProvider = Provider<SyncPlayRepository>((ref) {
  return SyncPlayRepository(ref.watch(jellyfinServiceProvider));
});

/// The single controller that follows a group for this app.
///
/// It lives as long as the app does: the socket that feeds it is owned by the
/// cast receiver, which also outlives any one screen.
final syncPlayControllerProvider = Provider<SyncPlayController>((ref) {
  final controller = SyncPlayController(
    syncPlay: ref.watch(syncPlayRepositoryProvider),
    music: ref.watch(musicRepositoryProvider),
    handler: ref.watch(audioHandlerProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Group membership as the UI sees it. Seeded with the controller's current
/// state so a screen opened mid-session doesn't start out blank.
final syncPlayStateProvider = StreamProvider<SyncPlayState>((ref) {
  final controller = ref.watch(syncPlayControllerProvider);
  // The controller's stream is a broadcast one and replays nothing, so a
  // screen opened while a group is already joined would start out blank.
  return () async* {
    yield controller.state;
    yield* controller.states;
  }();
});

/// Whether this device is currently in a group — the flag the transport
/// consults before deciding whether a button acts locally or on the group.
final inSyncPlayGroupProvider = Provider<bool>((ref) {
  return ref.watch(syncPlayStateProvider).value?.active ?? false;
});

/// Groups available to join. Re-read whenever the picker opens rather than
/// held: membership changes on other people's devices, not this one.
final syncPlayGroupsProvider =
    FutureProvider.autoDispose<List<SyncPlayGroup>>((ref) {
  return ref.watch(syncPlayRepositoryProvider).groups();
});
