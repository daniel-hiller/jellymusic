import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/util/item_x.dart';
import '../data/jellyfin/cast_receiver.dart';
import '../data/jellyfin/sessions_repository.dart';
import 'providers.dart';

/// Casting: hand playback to another Jellyfin client and drive it from here.
///
/// While a target is selected, [playerControllerProvider] sends commands to
/// that session instead of the local player, and the player UI reads its state
/// from [remoteSessionProvider] — see `player_providers.dart`, which switches
/// the shared streams over.

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return SessionsRepository(ref.watch(jellyfinServiceProvider));
});

// ─── This device as a cast target ────────────────────────────────────

const _kReceiverEnabled = 'settings.castReceiver';

/// Whether other clients may cast *to* this device. Persisted; turning it off
/// closes the WebSocket and drops us from other clients' device lists.
final castReceiverEnabledProvider =
    AsyncNotifierProvider<CastReceiverSetting, bool>(CastReceiverSetting.new);

class CastReceiverSetting extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kReceiverEnabled) ?? true;
  }

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReceiverEnabled, enabled);
  }
}

/// Keeps the receiver's socket in step with login state and the setting above.
///
/// Watched once from the app root; nothing else needs to know it exists.
final castReceiverProvider = Provider<CastReceiver>((ref) {
  final receiver = CastReceiver(
    service: ref.watch(jellyfinServiceProvider),
    music: ref.watch(musicRepositoryProvider),
    sessions: ref.watch(sessionsRepositoryProvider),
    handler: ref.watch(audioHandlerProvider),
  );

  void sync() {
    final loggedIn = ref.read(authControllerProvider).value != null;
    final enabled = ref.read(castReceiverEnabledProvider).value ?? true;
    if (loggedIn && enabled) {
      receiver.start();
    } else {
      receiver.stop();
    }
  }

  ref.listen(authControllerProvider, (_, __) => sync());
  ref.listen(castReceiverEnabledProvider, (_, __) => sync());
  ref.onDispose(receiver.stop);
  sync();
  return receiver;
});

/// The device playback is being sent to. Null means "this device".
class CastTarget {
  const CastTarget({
    required this.sessionId,
    required this.name,
    this.client,
  });

  final String sessionId;

  /// Device name as reported by the target ("Wohnzimmer TV").
  final String name;

  /// Client application name ("Jellyfin Web", "Finamp").
  final String? client;

  factory CastTarget.of(JellyfinSession session) => CastTarget(
        sessionId: session.id,
        name: session.deviceName?.isNotEmpty == true
            ? session.deviceName!
            : (session.client ?? session.id),
        client: session.client,
      );
}

/// Selectable targets, refreshed while the picker is open.
final castTargetsProvider =
    StreamProvider.autoDispose<List<JellyfinSession>>((ref) async* {
  // Errors are deliberately not swallowed: "no devices found" and "the server
  // refused the request" look identical in the picker otherwise.
  final repo = ref.watch(sessionsRepositoryProvider);
  yield await repo.castTargets();
  yield* Stream.periodic(const Duration(seconds: 5))
      .asyncMap((_) => repo.castTargets());
});

/// Current cast target, or null while playing locally.
final castTargetProvider =
    NotifierProvider<CastController, CastTarget?>(CastController.new);

class CastController extends Notifier<CastTarget?> {
  @override
  CastTarget? build() => null;

  /// Move the current queue to [session] and keep controlling it from here.
  ///
  /// The local player is paused rather than stopped, so coming back with
  /// [playHere] resumes where this device left off.
  Future<void> castTo(JellyfinSession session) async {
    final handler = ref.read(audioHandlerProvider);
    final local = handler.playbackState.value;
    final queue = handler.queue.value;
    final index = local.queueIndex ?? 0;
    final position = handler.player.position;
    final wasPlaying = local.playing;

    // Release the local output entirely rather than just pausing: a paused
    // libmpv keeps its stream (and the server's transcode) open, so the same
    // track would be transcoded twice once the target starts.
    await handler.releaseForCast();
    state = CastTarget.of(session);

    if (queue.isEmpty) return;
    final repo = ref.read(sessionsRepositoryProvider);
    await repo.play(
      session.id,
      [for (final item in queue) item.id],
      startIndex: index.clamp(0, queue.length - 1),
      position: position,
    );
    await repo.setRepeatMode(session.id, local.repeatMode);
    await repo.setShuffle(
      session.id,
      local.shuffleMode == AudioServiceShuffleMode.all,
    );
    // `PlayNow` always starts playback, so a paused hand-off needs a pause
    // after the fact — with a beat for the target to actually get going,
    // otherwise it pauses before it started and then plays anyway.
    if (!wasPlaying) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await repo.pause(session.id);
    }
  }

  /// Take playback back: stop the remote and continue here at the track and
  /// position it had reached.
  ///
  /// Stopping (rather than pausing) matters on a busy server: a paused client
  /// keeps its stream — and its transcode — open, so the same track would be
  /// transcoded twice while we start it locally.
  Future<void> playHere() async {
    final target = state;
    if (target == null) return;
    final repo = ref.read(sessionsRepositoryProvider);

    // Read the remote's position *before* stopping it — stopping is what ends
    // the clock, and the last poll may be up to two seconds stale.
    JellyfinSession? session;
    try {
      session = await repo.byId(target.sessionId);
      await repo.stop(target.sessionId);
    } catch (_) {/* target may already be gone */}

    state = null; // from here on the local player is the source of truth
    await _resumeLocally(session);
  }

  /// Continue what [session] was playing on this device.
  Future<void> _resumeLocally(JellyfinSession? session) async {
    final item = session?.nowPlayingItem;
    if (item == null) return;
    final remote = RemotePlayback.fromSession(session!);
    final handler = ref.read(audioHandlerProvider);

    await handler.setRepeatMode(remote.repeatMode);
    await handler.setShuffleMode(remote.shuffle
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none);

    // Usually the track is still in our queue (we handed that queue over), so
    // resuming keeps the whole queue rather than collapsing it to one track.
    final index = handler.queue.value.indexWhere((m) => m.id == item.id);
    if (index >= 0) {
      await handler.resumeAt(index, remote.position, play: remote.playing);
      return;
    }

    // Otherwise the target moved on to something we don't have — pull that one
    // track in and continue with it.
    final fresh = await ref.read(musicRepositoryProvider).itemById(item.id);
    if (fresh == null) return;
    await handler.loadQueue([fresh], startPosition: remote.position);
    if (!remote.playing) await handler.pause();
  }
}

/// Polls the cast target so the player UI can show what it's doing.
/// Emits null while playing locally.
final remoteSessionProvider =
    StreamProvider<JellyfinSession?>((ref) async* {
  final target = ref.watch(castTargetProvider);
  if (target == null) {
    yield null;
    return;
  }
  final repo = ref.watch(sessionsRepositoryProvider);
  Future<JellyfinSession?> load() async {
    try {
      return await repo.byId(target.sessionId);
    } catch (_) {
      return null;
    }
  }

  yield await load();
  yield* Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => load());
});

/// Volume of the cast target, kept usable despite the polling lag.
///
/// The poll is two seconds behind, so a slider bound straight to it snaps back
/// under the user's finger. A manual change wins for a moment, after which the
/// target's own reports take over again — and a target that reports no level
/// at all simply keeps the last value instead of jumping to 100%.
final remoteVolumeProvider =
    NotifierProvider<RemoteVolume, double>(RemoteVolume.new);

class RemoteVolume extends Notifier<double> {
  DateTime? _changedAt;

  static const _grace = Duration(seconds: 3);

  @override
  double build() {
    ref.listen(remoteSessionProvider, (_, next) {
      final session = next.value;
      if (session == null) return;
      final reported = RemotePlayback.fromSession(session).volume;
      if (reported == null) return;
      final changedAt = _changedAt;
      if (changedAt != null && DateTime.now().difference(changedAt) < _grace) {
        return; // our own change hasn't come back around yet
      }
      state = reported;
    });
    return 1.0;
  }

  /// Reflect a level the user just set, before the target confirms it.
  void applyLocal(double value) {
    _changedAt = DateTime.now();
    state = value.clamp(0.0, 1.0);
  }
}

/// The remote's play state in the shape the transport controls expect.
final remotePlaybackProvider = Provider<RemotePlayback>((ref) {
  final session = ref.watch(remoteSessionProvider).value;
  return session == null
      ? RemotePlayback.idle
      : RemotePlayback.fromSession(session);
});

/// What the target is playing, as a [MediaItem] so the existing player widgets
/// can render it unchanged.
MediaItem? remoteMediaItem(Ref ref, JellyfinSession? session) {
  final item = session?.nowPlayingItem;
  if (item == null) return null;
  final service = ref.read(jellyfinServiceProvider);
  final art = service.primaryImageUrl(item, size: 512);
  return MediaItem(
    id: item.id,
    title: item.name,
    album: item.album,
    artist: item.trackArtistLabel,
    duration:
        item.durationMs != null ? Duration(milliseconds: item.durationMs!) : null,
    artUri: art != null ? Uri.parse(art) : null,
  );
}
