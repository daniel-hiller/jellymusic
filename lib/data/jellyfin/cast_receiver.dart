import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dart_jellyfin/dart_jellyfin.dart';

import '../../core/audio/audio_player_handler.dart';
import 'jellyfin_service.dart';
import 'music_repository.dart';
import 'sessions_repository.dart';

/// Makes this app a cast *target*: other Jellyfin clients can send it playback
/// commands, the way this app drives them via [SessionsRepository].
///
/// Two halves: [SessionsRepository.registerAsCastTarget] announces what we can
/// do (that's what puts us in other clients' device lists), and the `/socket`
/// WebSocket delivers the commands. The socket drops out with the network, so
/// [start] keeps reconnecting with a backoff until [stop].
class CastReceiver {
  CastReceiver({
    required JellyfinService service,
    required MusicRepository music,
    required SessionsRepository sessions,
    required AudioPlayerHandler handler,
  })  : _service = service,
        _music = music,
        _sessions = sessions,
        _handler = handler;

  final JellyfinService _service;
  final MusicRepository _music;
  final SessionsRepository _sessions;
  final AudioPlayerHandler _handler;

  StreamSubscription<JellyfinNotification>? _sub;
  Timer? _retry;
  bool _running = false;
  Duration _backoff = _minBackoff;

  static const _minBackoff = Duration(seconds: 5);
  static const _maxBackoff = Duration(minutes: 2);

  /// Announce our capabilities and listen for commands. Safe to call again
  /// after a login; a running receiver is restarted against the new session.
  Future<void> start() async {
    await stop();
    if (!_service.isAuthenticated) return;
    _running = true;
    _backoff = _minBackoff;
    await _connect();
  }

  Future<void> stop() async {
    _running = false;
    _retry?.cancel();
    _retry = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _service.client.notifications.close();
    } catch (_) {/* not connected */}
  }

  Future<void> _connect() async {
    if (!_running) return;
    try {
      // Capabilities live on the session, so they have to be re-posted for
      // every new token — cheap enough to do on each (re)connect.
      await _sessions.registerAsCastTarget();

      final stream = await _service.client.notifications.connect();
      _sub = stream.listen(
        _onFrame,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
      );
      // No channel subscription needed: remote-control frames are pushed to
      // our own session regardless, and `SessionsStart` would add a 2-second
      // firehose of session lists we already poll for the device picker.
      _backoff = _minBackoff;
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_running || (_retry?.isActive ?? false)) return;
    unawaited(_sub?.cancel());
    _sub = null;
    unawaited(_service.client.notifications.close().catchError((_) {}));
    _retry = Timer(_backoff, () {
      _backoff = _backoff * 2 > _maxBackoff ? _maxBackoff : _backoff * 2;
      _connect();
    });
  }

  // ─── Incoming commands ─────────────────────────────────────────────

  Future<void> _onFrame(JellyfinNotification frame) async {
    final data = frame.data;
    switch (frame.messageType) {
      case 'Play':
        if (data is Map) await _play(Map<String, dynamic>.from(data));
      case 'Playstate':
        if (data is Map) await _playstate(Map<String, dynamic>.from(data));
      case 'GeneralCommand':
        if (data is Map) await _general(Map<String, dynamic>.from(data));
    }
  }

  Future<void> _play(Map<String, dynamic> data) async {
    final ids = [
      for (final id in (data['ItemIds'] as List<dynamic>? ?? const []))
        id.toString(),
    ];
    if (ids.isEmpty) return;

    final items = await _music.itemsByIds(ids);
    if (items.isEmpty) return;

    final startIndex = (data['StartIndex'] as num?)?.toInt() ?? 0;
    switch (data['PlayCommand']?.toString() ?? 'PlayNow') {
      case 'PlayNext':
        await _handler.playNext(items);
      case 'PlayLast':
        await _handler.addToQueue(items);
      default:
        await _handler.loadQueue(
          items,
          startIndex: startIndex.clamp(0, items.length - 1),
        );
        final ticks = (data['StartPositionTicks'] as num?)?.toInt() ?? 0;
        if (ticks > 0) {
          await _handler.seek(Duration(milliseconds: ticks ~/ 10000));
        }
    }
  }

  Future<void> _playstate(Map<String, dynamic> data) async {
    switch (data['Command']?.toString()) {
      case 'Play':
      case 'Unpause':
        await _handler.play();
      case 'Pause':
        await _handler.pause();
      case 'PlayPause':
        _handler.playbackState.value.playing
            ? await _handler.pause()
            : await _handler.play();
      case 'Stop':
        await _handler.stop();
      case 'NextTrack':
        await _handler.skipToNext();
      case 'PreviousTrack':
        await _handler.skipToPrevious();
      case 'Seek':
        final ticks = (data['SeekPositionTicks'] as num?)?.toInt() ?? 0;
        await _handler.seek(Duration(milliseconds: ticks ~/ 10000));
    }
  }

  Future<void> _general(Map<String, dynamic> data) async {
    final args = Map<String, dynamic>.from(
      (data['Arguments'] as Map<dynamic, dynamic>?) ?? const {},
    );
    switch (data['Name']?.toString()) {
      case 'SetVolume':
        final volume = double.tryParse('${args['Volume']}');
        if (volume != null) await _handler.setVolume(volume / 100);
      case 'VolumeUp':
        await _handler.setVolume(_handler.volume + 0.05);
      case 'VolumeDown':
        await _handler.setVolume(_handler.volume - 0.05);
      case 'Mute':
        if (_handler.volume > 0) await _handler.toggleMute();
      case 'Unmute':
        if (_handler.volume == 0) await _handler.toggleMute();
      case 'ToggleMute':
        await _handler.toggleMute();
      case 'SetRepeatMode':
        await _handler.setRepeatMode(switch ('${args['RepeatMode']}') {
          'RepeatAll' => AudioServiceRepeatMode.all,
          'RepeatOne' => AudioServiceRepeatMode.one,
          _ => AudioServiceRepeatMode.none,
        });
      case 'SetShuffleQueue':
        await _handler.setShuffleMode('${args['ShuffleMode']}' == 'Shuffle'
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none);
    }
  }
}
