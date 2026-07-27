import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_player_handler.dart';
import '../data/jellyfin/sessions_repository.dart';
import 'cast_providers.dart';
import 'providers.dart';

/// Player state for the UI.
///
/// Every provider here has two sources: the local [AudioPlayerHandler], and —
/// while a cast target is selected — the polled remote session. Widgets don't
/// know the difference; they watch the same providers either way.

// Local sources. The public providers below pick between these and the cast
// target's polled state, so widgets can stay unaware of which one is live.
final _localPlaybackState =
    StreamProvider<PlaybackState>((ref) => ref.watch(audioHandlerProvider).playbackState);
final _localMediaItem =
    StreamProvider<MediaItem?>((ref) => ref.watch(audioHandlerProvider).mediaItem);
final _localQueue =
    StreamProvider<List<MediaItem>>((ref) => ref.watch(audioHandlerProvider).queue);
final _localVolume =
    StreamProvider<double>((ref) => ref.watch(audioHandlerProvider).volumeStream);

/// Live playback state (playing/paused, processing, queue index).
final playbackStateProvider = Provider<AsyncValue<PlaybackState>>((ref) {
  if (ref.watch(castTargetProvider) == null) {
    return ref.watch(_localPlaybackState);
  }
  return ref.watch(remoteSessionProvider).whenData((session) {
    final remote = session == null
        ? RemotePlayback.idle
        : RemotePlayback.fromSession(session);
    return PlaybackState(
      playing: remote.playing,
      processingState: session?.nowPlayingItem == null
          ? AudioProcessingState.idle
          : AudioProcessingState.ready,
      updatePosition: remote.position,
      repeatMode: remote.repeatMode,
      shuffleMode: remote.shuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      controls: const [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
    );
  });
});

/// The currently playing track as a [MediaItem].
final currentMediaItemProvider = Provider<AsyncValue<MediaItem?>>((ref) {
  if (ref.watch(castTargetProvider) == null) {
    return ref.watch(_localMediaItem);
  }
  return ref
      .watch(remoteSessionProvider)
      .whenData((session) => remoteMediaItem(ref, session));
});

/// The active queue.
///
/// Jellyfin doesn't expose a remote session's queue, only its current item, so
/// while casting this is the single now-playing entry (or empty).
final queueProvider = Provider<AsyncValue<List<MediaItem>>>((ref) {
  if (ref.watch(castTargetProvider) == null) {
    return ref.watch(_localQueue);
  }
  return ref.watch(remoteSessionProvider).whenData((session) {
    final item = remoteMediaItem(ref, session);
    return item == null ? const <MediaItem>[] : [item];
  });
});

/// High-resolution playback position for the seek bar.
///
/// The remote is only polled every couple of seconds, so between polls the
/// position is advanced locally — otherwise the seek bar would jump.
final positionProvider = StreamProvider<Duration>((ref) {
  final target = ref.watch(castTargetProvider);
  if (target == null) {
    return ref.watch(audioHandlerProvider).player.positionStream;
  }

  final controller = StreamController<Duration>();
  var anchor = Duration.zero;
  var anchoredAt = DateTime.now();
  var playing = false;

  ref.listen<AsyncValue<JellyfinSession?>>(remoteSessionProvider, (_, next) {
    final session = next.value;
    final remote = session == null
        ? RemotePlayback.idle
        : RemotePlayback.fromSession(session);
    anchor = remote.position;
    anchoredAt = DateTime.now();
    playing = remote.playing;
    if (!controller.isClosed) controller.add(anchor);
  }, fireImmediately: true);

  final ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
    if (controller.isClosed) return;
    controller.add(
      playing ? anchor + DateTime.now().difference(anchoredAt) : anchor,
    );
  });

  ref.onDispose(() {
    ticker.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Output volume in 0..1 (also drives the mute icon state).
final volumeProvider = Provider<AsyncValue<double>>((ref) {
  if (ref.watch(castTargetProvider) == null) {
    return ref.watch(_localVolume);
  }
  final muted = ref.watch(remotePlaybackProvider).muted;
  return AsyncData(muted ? 0.0 : ref.watch(remoteVolumeProvider));
});

final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(playbackStateProvider).value?.playing ?? false;
});

/// Imperative façade the UI calls to control playback. Routes to the cast
/// target when one is selected, to the local player otherwise.
final playerControllerProvider = Provider<PlayerController>((ref) {
  final target = ref.watch(castTargetProvider);
  return PlayerController(
    ref.watch(audioHandlerProvider),
    remote: target == null
        ? null
        : RemotePlayer(ref.watch(sessionsRepositoryProvider), target.sessionId),
    remoteState: () => ref.read(remotePlaybackProvider),
    onRemoteVolume: (v) => ref.read(remoteVolumeProvider.notifier).applyLocal(v),
  );
});

/// Sends the controller's calls to a remote session.
class RemotePlayer {
  RemotePlayer(this._repo, this._sessionId);

  final SessionsRepository _repo;
  final String _sessionId;

  Future<void> play(List<String> itemIds, {int index = 0}) =>
      _repo.play(_sessionId, itemIds, startIndex: index);
  Future<void> playNext(List<String> itemIds) =>
      _repo.playNext(_sessionId, itemIds);
  Future<void> addToQueue(List<String> itemIds) =>
      _repo.addToQueue(_sessionId, itemIds);

  Future<void> togglePlay() => _repo.playPause(_sessionId);
  Future<void> pause() => _repo.pause(_sessionId);
  Future<void> next() => _repo.next(_sessionId);
  Future<void> previous() => _repo.previous(_sessionId);
  Future<void> seek(Duration position) => _repo.seek(_sessionId, position);
  Future<void> setVolume(double value) => _repo.setVolume(_sessionId, value);
  Future<void> toggleMute() => _repo.toggleMute(_sessionId);
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) =>
      _repo.setRepeatMode(_sessionId, mode);
  Future<void> setShuffle(bool enabled) =>
      _repo.setShuffle(_sessionId, enabled);
}

class PlayerController {
  PlayerController(
    this._handler, {
    RemotePlayer? remote,
    RemotePlayback Function()? remoteState,
    void Function(double volume)? onRemoteVolume,
  })  : _remote = remote,
        _remoteState = remoteState ?? (() => RemotePlayback.idle),
        _onRemoteVolume = onRemoteVolume;

  final AudioPlayerHandler _handler;
  final RemotePlayer? _remote;

  /// Last polled state of the cast target; only read while casting.
  final RemotePlayback Function() _remoteState;

  /// Lets the UI show a volume change before the target confirms it.
  final void Function(double volume)? _onRemoteVolume;

  /// True while playback is running on another device.
  bool get isCasting => _remote != null;

  /// Play a list of tracks starting at [index] (e.g. tap a song in an album).
  Future<void> playItems(List<JellyfinItem> items, {int index = 0}) {
    final remote = _remote;
    if (remote != null) {
      return remote.play([for (final i in items) i.id], index: index);
    }
    return _handler.loadQueue(items, startIndex: index);
  }

  Future<void> togglePlay() {
    final remote = _remote;
    if (remote != null) return remote.togglePlay();
    return _handler.playbackState.value.playing
        ? _handler.pause()
        : _handler.play();
  }

  Future<void> next() => _remote?.next() ?? _handler.skipToNext();
  Future<void> previous() => _remote?.previous() ?? _handler.skipToPrevious();
  Future<void> seek(Duration position) =>
      _remote?.seek(position) ?? _handler.seek(position);
  Future<void> pause() => _remote?.pause() ?? _handler.pause();

  /// Queue editing stays local: Jellyfin exposes a remote session's current
  /// item but not its queue, so these would act on the wrong list — and worse,
  /// would start the local player while another device is playing.
  Future<void> skipToQueueItem(int index) =>
      _remote != null ? Future.value() : _handler.skipToQueueItem(index);

  Future<void> setVolume(double value) {
    final remote = _remote;
    if (remote == null) return _handler.setVolume(value);
    _onRemoteVolume?.call(value);
    return remote.setVolume(value);
  }
  Future<void> toggleMute() => _remote?.toggleMute() ?? _handler.toggleMute();

  Future<void> addToQueue(List<JellyfinItem> items) {
    final remote = _remote;
    if (remote != null) return remote.addToQueue([for (final i in items) i.id]);
    return _handler.addToQueue(items);
  }

  Future<void> playNext(List<JellyfinItem> items) {
    final remote = _remote;
    if (remote != null) return remote.playNext([for (final i in items) i.id]);
    return _handler.playNext(items);
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) => _remote != null
      ? Future.value()
      : _handler.moveQueueItem(oldIndex, newIndex);
  Future<void> removeQueueItem(int index) =>
      _remote != null ? Future.value() : _handler.removeQueueItemAt(index);
  Future<void> clearQueue() =>
      _remote != null ? Future.value() : _handler.clearQueue();

  /// Play [items] shuffled — what a "Shuffle" button means. The mode is *set*
  /// rather than toggled, so an already-shuffled player doesn't fall back to
  /// straight order. The queue is loaded shuffled in one go, so the track it
  /// starts on isn't cut off by a reshuffle a moment later.
  Future<void> playItemsShuffled(List<JellyfinItem> items) async {
    final remote = _remote;
    if (remote != null) {
      await remote.play([for (final i in items) i.id]);
      return remote.setShuffle(true);
    }
    return _handler.loadQueue(items, shuffled: true);
  }

  /// Shuffle and repeat read their current value from whichever side is live —
  /// the remote reports both in its `PlayState`, so toggling stays in step.
  Future<void> setShuffle(bool enabled) {
    final remote = _remote;
    if (remote != null) return remote.setShuffle(enabled);
    return _handler.setShuffleMode(
      enabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
  }

  Future<void> toggleShuffle() {
    final remote = _remote;
    final current = remote != null
        ? _remoteState().shuffle
        : _handler.playbackState.value.shuffleMode ==
            AudioServiceShuffleMode.all;
    return setShuffle(!current);
  }

  Future<void> cycleRepeat() {
    final remote = _remote;
    final current = remote != null
        ? _remoteState().repeatMode
        : _handler.playbackState.value.repeatMode;
    final next = switch (current) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.none,
    };
    return remote != null
        ? remote.setRepeatMode(next)
        : _handler.setRepeatMode(next);
  }
}

/// Sleep timer: the remaining time until playback auto-pauses, or null when
/// no timer is running. Ticks down once per second.
final sleepTimerProvider =
    NotifierProvider<SleepTimerController, Duration?>(SleepTimerController.new);

class SleepTimerController extends Notifier<Duration?> {
  Timer? _ticker;

  @override
  Duration? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  /// Start (or restart) the timer; playback pauses when it elapses.
  void start(Duration duration) {
    _ticker?.cancel();
    final end = DateTime.now().add(duration);
    state = duration;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = end.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _ticker?.cancel();
        ref.read(playerControllerProvider).pause();
        state = null;
      } else {
        state = remaining;
      }
    });
  }

  void cancel() {
    _ticker?.cancel();
    state = null;
  }
}
