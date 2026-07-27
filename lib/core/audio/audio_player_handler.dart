import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/jellyfin/jellyfin_service.dart';
import '../util/item_x.dart';

/// Bridges [just_audio] (actual playback) and [audio_service] (background
/// playback + OS media controls: notification, lockscreen, media keys).
///
/// It also reports playback to Jellyfin (start / progress / stopped) so
/// "Continue listening", play counts and multi-device state stay in sync.
class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  AudioPlayerHandler(this._jellyfin) {
    _init();
  }

  final JellyfinService _jellyfin;
  final AudioPlayer _player = AudioPlayer();

  Timer? _progressTimer;
  String? _reportedItemId;

  /// True while [loadQueue] swaps the sources out from under the player, so the
  /// transient `completed` this can emit isn't mistaken for "queue finished".
  bool _swappingQueue = false;

  /// Bumped on every [loadQueue] so late async callbacks can tell whether the
  /// queue they were reacting to is still the current one.
  int _loadGeneration = 0;

  /// Volume to restore when unmuting (see [toggleMute]).
  double _preMuteVolume = 1.0;

  /// The level the user picked. The fader scales this rather than overwriting
  /// it, so ramps never move the volume slider.
  double _userVolume = 1.0;
  final _volumeSubject = StreamController<double>.broadcast();

  /// Fade envelope in 0..1, multiplied onto [_userVolume].
  double _fadeGain = 1.0;
  Timer? _fadeTimer;

  /// How long to fade when a track ends or begins. Zero — the default — means
  /// no fading at all, which is what makes gapless playback actually gapless.
  /// Set from the saved preference (see `settings_providers.dart`).
  Duration fadeDuration = Duration.zero;

  /// Transport actions (play/pause/skip) use a short fade of their own: a
  /// multi-second ramp on a button press feels broken, not smooth.
  static const _transportFade = Duration(milliseconds: 320);

  AudioPlayer get player => _player;

  // ─── Volume ────────────────────────────────────────────────────────

  /// The user-facing level — deliberately not `_player.volumeStream`, which
  /// would report every intermediate step of a fade.
  Stream<double> get volumeStream async* {
    yield _userVolume;
    yield* _volumeSubject.stream;
  }

  double get volume => _userVolume;

  Future<void> setVolume(double value) async {
    _userVolume = value.clamp(0.0, 1.0);
    _volumeSubject.add(_userVolume);
    await _applyVolume();
  }

  /// Toggle mute, remembering the level to restore on unmute.
  Future<void> toggleMute() {
    if (_userVolume > 0) {
      _preMuteVolume = _userVolume;
      return setVolume(0);
    }
    return setVolume(_preMuteVolume == 0 ? 1.0 : _preMuteVolume);
  }

  // ─── Fading ────────────────────────────────────────────────────────

  Future<void> _applyVolume() => _player.setVolume(_userVolume * _fadeGain);

  /// Ramp the fade envelope to [target] over [over]. Returns when the ramp is
  /// done, so callers can pause/skip on a silent player.
  Future<void> _fadeTo(double target, Duration over) async {
    _fadeTimer?.cancel();
    if (over <= Duration.zero || _fadeGain == target) {
      _fadeGain = target;
      await _applyVolume();
      return;
    }

    const tick = Duration(milliseconds: 40);
    final steps = (over.inMilliseconds / tick.inMilliseconds).ceil();
    final from = _fadeGain;
    final done = Completer<void>();
    var step = 0;

    _fadeTimer = Timer.periodic(tick, (timer) async {
      step++;
      _fadeGain = step >= steps
          ? target
          : from + (target - from) * (step / steps);
      await _applyVolume();
      if (step >= steps) {
        timer.cancel();
        if (!done.isCompleted) done.complete();
      }
    });
    await done.future;
  }

  /// Watches the position so the tail of a track can fade out. Only armed
  /// while [fadeDuration] is non-zero.
  void _maybeFadeOutTail(Duration position) {
    final total = _player.duration;
    if (fadeDuration <= Duration.zero || total == null || !_player.playing) {
      return;
    }
    // Nothing to fade into after the last track — let it end at full level.
    if (!_player.hasNext) return;
    final remaining = total - position;
    if (remaining <= fadeDuration && remaining > Duration.zero) {
      if (_fadeTimer?.isActive ?? false) return; // already ramping
      if (_fadeGain < 1.0) return; // already faded
      _fadeTo(0.0, remaining);
    }
  }

  Future<void> _init() async {
    // Sources are set on the first loadQueue via setAudioSources; nothing to
    // preload up front.

    // Pipe just_audio events -> audio_service PlaybackState.
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        playbackState.add(playbackState.value
            .copyWith(processingState: AudioProcessingState.error));
      },
    );

    // When the track changes, surface the new MediaItem + scrobble.
    _player.currentIndexStream.listen(_setCurrentIndex);

    _player.playingStream.listen((_) => _broadcastState(null));

    // Drives the end-of-track fade; a no-op while fadeDuration is zero.
    _player.positionStream.listen(_maybeFadeOutTail);

    // End of queue: just_audio leaves `playing == true` at the completed
    // position, so the UI stays stuck on "pause". Reset to a paused, ready
    // state instead.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _onQueueCompleted();
    });

    // Best-effort progress heartbeat every 10s.
    _progressTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _reportProgress());
  }

  // ─── Queue loading ─────────────────────────────────────────────────

  /// Replace the queue with [items] and start at [startIndex], optionally
  /// resuming at [startPosition] (used when playback is handed back from a
  /// cast target).
  Future<void> loadQueue(
    List<JellyfinItem> items, {
    int startIndex = 0,
    Duration startPosition = Duration.zero,
  }) async {
    final gen = ++_loadGeneration;
    final mediaItems = items.map(_toMediaItem).toList();
    queue.add(mediaItems);

    _swappingQueue = true;
    try {
      // Pause before swapping the sources out. just_audio's `play()` returns
      // immediately while `playing` is already true, so starting a new queue
      // mid-playback could leave the platform silent with the UI still
      // claiming it plays — the reported "tap a song, nothing happens" bug.
      await _player.pause();
      if (gen != _loadGeneration) return; // a newer tap took over
      // setAudioSources replaces the queue and positions the player at
      // [startIndex]/[startPosition] atomically — no fragile clear()+seek
      // dance (which threw a RangeError on the media_kit backend).
      await _player.setAudioSources(
        mediaItems.map(_toSource).toList(),
        initialIndex: startIndex,
        initialPosition: startPosition,
      );
    } finally {
      _swappingQueue = false;
    }
    if (gen != _loadGeneration) return;
    // Emit the starting track explicitly: currentIndexStream doesn't fire
    // when the index is unchanged (e.g. first play at index 0), which would
    // otherwise leave the UI without a MediaItem while audio plays.
    _setCurrentIndex(startIndex);
    unawaited(play());
  }

  /// Seek to the start of queue entry [index].
  ///
  /// [AudioPlayer.seek] silently does nothing while the player is loading, so
  /// a seek issued right after a queue swap can be dropped and leave playback
  /// stranded on the wrong track. Wait for the load to settle first.
  Future<void> _seekToIndex(int index, [Duration position = Duration.zero]) async {
    if (_player.processingState == ProcessingState.loading) {
      await _player.processingStateStream
          .firstWhere((s) => s != ProcessingState.loading)
          .timeout(const Duration(seconds: 5),
              onTimeout: () => ProcessingState.idle);
    }
    await _player.seek(position, index: index);
  }

  /// Release the audio output while playback lives on a cast target.
  ///
  /// [AudioPlayer.stop] tears down the decoder — and, on the libmpv backend,
  /// closes the network stream — so the server isn't transcoding for us at the
  /// same time as for the cast device. The queue and audio source are kept, so
  /// [resumeAt] can bring playback straight back.
  Future<void> releaseForCast() async {
    _fadeTimer?.cancel();
    _fadeGain = 1.0;
    await _player.stop();
  }

  /// Continue the already-loaded queue at [index] / [position] — the local half
  /// of taking playback back from a cast target.
  ///
  /// After [releaseForCast] the platform is idle; `seek(index:)` re-arms the
  /// source and the following `play()` reactivates it, restoring this position.
  Future<void> resumeAt(int index, Duration position,
      {bool play = true}) async {
    await _seekToIndex(index, position);
    if (play) {
      await this.play();
    } else {
      _setCurrentIndex(index);
    }
  }

  /// Surface the track at [index] as the current [mediaItem] and scrobble it,
  /// skipping when it's already current so double-firing sources (this call
  /// plus [AudioPlayer.currentIndexStream]) don't double-report.
  void _setCurrentIndex(int? index) {
    final q = queue.value;
    if (index == null || index < 0 || index >= q.length) return;
    final next = q[index];
    if (mediaItem.value?.id == next.id) return;
    mediaItem.add(next);
    // The outgoing track faded itself out; bring the new one up.
    if (fadeDuration > Duration.zero && _player.playing) {
      _fadeTo(1.0, fadeDuration);
    }
    _onTrackStarted(next);
  }

  /// The queue played to its end. just_audio keeps `playing == true` at the
  /// completed position, so the UI would stay stuck on "pause". Close out the
  /// scrobble, pause, and rewind to the start so the player is reset and ready
  /// to replay. (Seeking without an index keeps the same track, so no spurious
  /// "track started" is reported.)
  Future<void> _onQueueCompleted() async {
    if (_swappingQueue) return;
    final gen = _loadGeneration;
    await _reportStopped();
    // A new queue may have started while the report was in flight — pausing
    // then would silently kill the track the user just tapped.
    if (gen != _loadGeneration ||
        _player.processingState != ProcessingState.completed) {
      return;
    }
    await _player.pause();
    await _player.seek(Duration.zero);
  }

  AudioSource _toSource(MediaItem m) =>
      AudioSource.uri(Uri.parse(m.extras!['url'] as String), tag: m);

  // ─── Queue editing ─────────────────────────────────────────────────

  /// Append tracks to the end of the queue.
  Future<void> addToQueue(List<JellyfinItem> items) async {
    if (items.isEmpty) return;
    final mediaItems = items.map(_toMediaItem).toList();
    queue.add([...queue.value, ...mediaItems]);
    await _player.addAudioSources(mediaItems.map(_toSource).toList());
  }

  /// Insert tracks right after the current one ("play next").
  Future<void> playNext(List<JellyfinItem> items) async {
    if (items.isEmpty) return;
    final mediaItems = items.map(_toMediaItem).toList();
    final at = ((_player.currentIndex ?? -1) + 1).clamp(0, queue.value.length);
    final q = [...queue.value]..insertAll(at, mediaItems);
    queue.add(q);
    await _player.insertAudioSources(at, mediaItems.map(_toSource).toList());
  }

  /// Reorder the queue (drag-and-drop in the queue view).
  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    final q = [...queue.value];
    if (oldIndex < 0 || oldIndex >= q.length) return;
    final item = q.removeAt(oldIndex);
    q.insert(newIndex.clamp(0, q.length), item);
    queue.add(q);
    await _player.moveAudioSource(oldIndex, newIndex);
  }

  /// Remove one entry from the queue by position. This is the canonical
  /// `audio_service` API (its sibling [BaseAudioHandler.removeQueueItem] takes
  /// a [MediaItem] instead).
  @override
  Future<void> removeQueueItemAt(int index) async {
    final q = [...queue.value];
    if (index < 0 || index >= q.length) return;
    q.removeAt(index);
    queue.add(q);
    await _player.removeAudioSourceAt(index);
  }

  /// Drop the whole queue and stop playback.
  ///
  /// Tearing the sources down is guarded the same way [loadQueue] guards its
  /// swap: [_swappingQueue] keeps the transient `completed` the backend can
  /// emit from being read as "queue finished", and a fresh generation retires
  /// any load still in flight. The player is stopped before the sources go, so
  /// the libmpv backend closes the stream instead of indexing into a list that
  /// is about to be empty.
  Future<void> clearQueue() async {
    if (queue.value.isEmpty) return;
    ++_loadGeneration;
    _swappingQueue = true;
    try {
      await _reportStopped();
      _fadeTimer?.cancel();
      _fadeGain = 1.0;
      await _player.stop();
      await _player.clearAudioSources();
    } finally {
      _swappingQueue = false;
    }
    queue.add(const []);
    mediaItem.add(null);
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      queueIndex: null,
    ));
  }

  MediaItem _toMediaItem(JellyfinItem item) {
    final art = _jellyfin.primaryImageUrl(item, size: 512);
    return MediaItem(
      id: item.id,
      title: item.name,
      album: item.album,
      artist: item.trackArtistLabel,
      duration: item.durationMs != null
          ? Duration(milliseconds: item.durationMs!)
          : null,
      artUri: art != null ? Uri.parse(art) : null,
      extras: {
        'url': _jellyfin.streamUrl(
          item.id,
          maxStreamingBitrate: _jellyfin.maxStreamingBitrate,
        ),
      },
    );
  }

  // ─── Transport controls (called by OS + our UI) ────────────────────

  @override
  Future<void> play() async {
    if (fadeDuration > Duration.zero) {
      _fadeTimer?.cancel();
      _fadeGain = 0;
      await _applyVolume();
      await _player.play();
      await _fadeTo(1.0, _transportFade);
      return;
    }
    // Clear any leftover envelope from a previous fade before playing.
    await _fadeTo(1.0, Duration.zero);
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (fadeDuration > Duration.zero) await _fadeTo(0.0, _transportFade);
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _withTransportFade(_player.seekToNext);

  @override
  Future<void> skipToPrevious() => _withTransportFade(_player.seekToPrevious);

  /// Duck out, run [action], come back up — so manual skips don't click.
  Future<void> _withTransportFade(Future<void> Function() action) async {
    if (fadeDuration <= Duration.zero) return action();
    await _fadeTo(0.0, _transportFade);
    await action();
    await _fadeTo(1.0, _transportFade);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _seekToIndex(index);
    // Tapping a queue entry means "play this": seeking alone stays silent when
    // the player is paused or parked at the end of the queue.
    await play();
  }

  @override
  Future<void> stop() async {
    await _reportStopped();
    await _player.stop();
    _progressTimer?.cancel();
    await super.stop();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    if (enabled) await _player.shuffle();
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _player.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      _ => LoopMode.off,
    });
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  // ─── State broadcasting ────────────────────────────────────────────

  void _broadcastState(PlaybackEvent? event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    ));
  }

  // ─── Jellyfin scrobbling (best-effort) ─────────────────────────────

  Future<void> _onTrackStarted(MediaItem item) async {
    await _reportStopped(); // close out the previous track
    _reportedItemId = item.id;
    try {
      await _jellyfin.client.playback.start(itemId: item.id);
    } catch (_) {/* offline / server hiccup — ignore */}
  }

  Future<void> _reportProgress() async {
    final id = _reportedItemId;
    if (id == null) return;
    try {
      await _jellyfin.client.playback.progress(
        itemId: id,
        position: _player.position,
        isPaused: !_player.playing,
      );
    } catch (_) {}
  }

  Future<void> _reportStopped() async {
    final id = _reportedItemId;
    if (id == null) return;
    _reportedItemId = null;
    try {
      await _jellyfin.client.playback.stopped(
        itemId: id,
        position: _player.position,
      );
    } catch (_) {}
  }

  Future<void> dispose() async {
    _progressTimer?.cancel();
    _fadeTimer?.cancel();
    await _volumeSubject.close();
    await _player.dispose();
  }
}
