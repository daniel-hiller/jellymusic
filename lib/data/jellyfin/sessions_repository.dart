import 'package:audio_service/audio_service.dart';
import 'package:dart_jellyfin/dart_jellyfin.dart';

import 'jellyfin_service.dart';

/// Jellyfin's `/Sessions` surface: which other clients are reachable, the
/// remote-control commands we send them, and registering this app as a target
/// other clients can cast *to*.
///
/// Jellyfin counts time in ticks (10,000 per millisecond); conversions happen
/// here so callers stay in [Duration].
class SessionsRepository {
  SessionsRepository(this._service);

  final JellyfinService _service;

  JellyfinSessionsApi get _api => _service.client.sessions;

  /// Only sessions seen in the last few minutes are worth showing — Jellyfin
  /// keeps stale entries around long after a client is gone.
  static const _activeWithin = Duration(minutes: 5);

  // ─── Discovery ─────────────────────────────────────────────────────

  /// Clients this device can hand playback to: willing to take remote control,
  /// able to play audio — and not this device itself.
  Future<List<JellyfinSession>> castTargets() async {
    final sessions = await _sessions();
    return [
      for (final s in sessions)
        if (s.supportsRemoteControl &&
            s.deviceId != _service.deviceId &&
            _playsAudio(s))
          s,
    ];
  }

  /// Re-reads one session, for polling what a cast target is doing.
  Future<JellyfinSession?> byId(String sessionId) async {
    for (final s in await _sessions()) {
      if (s.id == sessionId) return s;
    }
    return null;
  }

  /// Every session we're allowed to see.
  ///
  /// `controllableByUserId` comes back empty on setups where the account lacks
  /// the remote-control permission for other users, so fall back to the
  /// unfiltered list — it still contains this user's own sessions, which is
  /// what casting mostly targets. Both the picker and the status poll go
  /// through here; when only one of them had the fallback, devices showed up
  /// but their playback state never did.
  Future<List<JellyfinSession>> _sessions() async {
    if (!_service.isAuthenticated) return const [];
    final byUser = await _api.list(
      controllableByUserId: _service.userId,
      activeWithinSeconds: _activeWithin.inSeconds,
    );
    if (byUser.isNotEmpty) return byUser;
    return _api.list(activeWithinSeconds: _activeWithin.inSeconds);
  }

  /// An empty `playableMediaTypes` means the client didn't declare any — we
  /// give it the benefit of the doubt rather than hiding a usable target.
  static bool _playsAudio(JellyfinSession s) =>
      s.playableMediaTypes.isEmpty ||
      s.playableMediaTypes.any((t) => t.toLowerCase() == 'audio');

  // ─── Commands sent to a target ─────────────────────────────────────

  /// Replace the target's queue and start playing at [startIndex].
  Future<void> play(
    String sessionId,
    List<String> itemIds, {
    int startIndex = 0,
    Duration position = Duration.zero,
  }) {
    return _api.play(
      sessionId: sessionId,
      itemIds: itemIds,
      playCommand: 'PlayNow',
      startIndex: startIndex,
      startPositionTicks: position == Duration.zero ? null : _ticks(position),
    );
  }

  /// Insert after the currently playing item on the target.
  Future<void> playNext(String sessionId, List<String> itemIds) => _api.play(
        sessionId: sessionId,
        itemIds: itemIds,
        playCommand: 'PlayNext',
      );

  /// Append to the end of the target's queue.
  Future<void> addToQueue(String sessionId, List<String> itemIds) => _api.play(
        sessionId: sessionId,
        itemIds: itemIds,
        playCommand: 'PlayLast',
      );

  Future<void> playPause(String sessionId) => _api.sendPlaystateCommand(
        sessionId: sessionId,
        command: JellyfinPlaystateCommand.playPause,
      );

  Future<void> pause(String sessionId) => _api.sendPlaystateCommand(
        sessionId: sessionId,
        command: JellyfinPlaystateCommand.pause,
      );

  Future<void> next(String sessionId) => _api.sendPlaystateCommand(
        sessionId: sessionId,
        command: JellyfinPlaystateCommand.nextTrack,
      );

  Future<void> previous(String sessionId) => _api.sendPlaystateCommand(
        sessionId: sessionId,
        command: JellyfinPlaystateCommand.previousTrack,
      );

  Future<void> stop(String sessionId) => _api.sendPlaystateCommand(
        sessionId: sessionId,
        command: JellyfinPlaystateCommand.stop,
      );

  Future<void> seek(String sessionId, Duration position) =>
      _api.sendPlaystateCommand(
        sessionId: sessionId,
        command: JellyfinPlaystateCommand.seek,
        seekPositionTicks: _ticks(position),
      );

  /// [volume] is 0..1 here; Jellyfin's `SetVolume` argument is 0..100.
  Future<void> setVolume(String sessionId, double volume) => _api.sendFullCommand(
        sessionId: sessionId,
        name: JellyfinGeneralCommand.setVolume,
        arguments: {'Volume': '${(volume.clamp(0.0, 1.0) * 100).round()}'},
      );

  Future<void> toggleMute(String sessionId) => _api.sendCommand(
        sessionId: sessionId,
        command: JellyfinGeneralCommand.toggleMute,
      );

  Future<void> setRepeatMode(String sessionId, AudioServiceRepeatMode mode) =>
      _api.sendFullCommand(
        sessionId: sessionId,
        name: 'SetRepeatMode',
        arguments: {
          'RepeatMode': switch (mode) {
            AudioServiceRepeatMode.one => 'RepeatOne',
            AudioServiceRepeatMode.all ||
            AudioServiceRepeatMode.group =>
              'RepeatAll',
            AudioServiceRepeatMode.none => 'RepeatNone',
          },
        },
      );

  Future<void> setShuffle(String sessionId, bool enabled) =>
      _api.sendFullCommand(
        sessionId: sessionId,
        name: 'SetShuffleQueue',
        arguments: {'ShuffleMode': enabled ? 'Shuffle' : 'Sorted'},
      );

  // ─── Being a target ────────────────────────────────────────────────

  /// Advertise this client so other Jellyfin apps list it as a cast target.
  /// Repeat after every login — capabilities are attached to the session, and
  /// a new session is created whenever the token changes.
  Future<void> registerAsCastTarget() => _api.postCapabilities(
        playableMediaTypes: const ['Audio'],
        supportsMediaControl: true,
        supportedCommands: const [
          'Play',
          'Pause',
          'PlayPause',
          'Stop',
          'NextTrack',
          'PreviousTrack',
          'Seek',
          'SetVolume',
          'VolumeUp',
          'VolumeDown',
          'Mute',
          'Unmute',
          'ToggleMute',
          'SetRepeatMode',
          'SetShuffleQueue',
          'DisplayMessage',
        ],
      );

  static int _ticks(Duration d) => d.inMilliseconds * 10000;
}

/// The parts of a session's `PlayState` the player UI needs.
class RemotePlayback {
  const RemotePlayback({
    required this.playing,
    required this.position,
    required this.volume,
    required this.muted,
    required this.repeatMode,
    required this.shuffle,
  });

  final bool playing;
  final Duration position;

  /// 0..1, mirroring the local player's scale. Null when the target doesn't
  /// report a level — not every client does, and defaulting to full volume
  /// would yank the slider to 100% on every poll.
  final double? volume;
  final bool muted;
  final AudioServiceRepeatMode repeatMode;
  final bool shuffle;

  static const idle = RemotePlayback(
    playing: false,
    position: Duration.zero,
    volume: null,
    muted: false,
    repeatMode: AudioServiceRepeatMode.none,
    shuffle: false,
  );

  factory RemotePlayback.fromSession(JellyfinSession session) {
    final state = session.playState ?? const {};
    final ticks = (state['PositionTicks'] as num?)?.toInt() ?? 0;
    final level = (state['VolumeLevel'] as num?)?.toDouble();
    return RemotePlayback(
      // A session with nothing loaded reports neither playing nor paused.
      playing: session.nowPlayingItem != null &&
          (state['IsPaused'] as bool? ?? false) == false,
      position: Duration(milliseconds: ticks ~/ 10000),
      volume: level == null ? null : (level / 100).clamp(0.0, 1.0),
      muted: state['IsMuted'] as bool? ?? false,
      repeatMode: switch ('${state['RepeatMode']}') {
        'RepeatOne' => AudioServiceRepeatMode.one,
        'RepeatAll' => AudioServiceRepeatMode.all,
        _ => AudioServiceRepeatMode.none,
      },
      shuffle: '${state['PlaybackOrder']}' == 'Shuffle',
    );
  }
}
