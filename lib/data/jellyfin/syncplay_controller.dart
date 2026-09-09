import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/audio/audio_player_handler.dart';
import 'music_repository.dart';
import 'syncplay_repository.dart';

/// What the UI needs to know about the group this device is in.
class SyncPlayState {
  const SyncPlayState({
    this.groupId,
    this.groupName = '',
    this.members = const [],
    this.waiting = false,
    this.clock = ClockOffset.zero,
  });

  /// Null while this device is in no group — the ordinary case.
  final String? groupId;
  final String groupName;
  final List<String> members;

  /// True while the server holds the group because a member is still
  /// buffering. Worth surfacing: from inside, a deliberate group-wide wait
  /// is indistinguishable from the app having hung.
  final bool waiting;

  final ClockOffset clock;

  bool get active => groupId != null;

  static const idle = SyncPlayState();

  SyncPlayState copyWith({
    String? groupId,
    String? groupName,
    List<String>? members,
    bool? waiting,
    ClockOffset? clock,
  }) {
    return SyncPlayState(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      members: members ?? this.members,
      waiting: waiting ?? this.waiting,
      clock: clock ?? this.clock,
    );
  }
}

/// Keeps this device in step with a SyncPlay group.
///
/// The server is the clock and the queue: it pushes what to play and names the
/// **instant** — on its own clock — at which every member is to act. This
/// class turns those instants into local ones, schedules the action, and tells
/// the server when this device falls behind so the group can wait for it.
///
/// Frames arrive on the same `/socket` the cast receiver already holds open,
/// so [handleFrame] is fed from there rather than opening a second socket.
class SyncPlayController {
  SyncPlayController({
    required SyncPlayRepository syncPlay,
    required MusicRepository music,
    required AudioPlayerHandler handler,
  })  : _syncPlay = syncPlay,
        _music = music,
        _handler = handler;

  final SyncPlayRepository _syncPlay;
  final MusicRepository _music;
  final AudioPlayerHandler _handler;

  final _states = StreamController<SyncPlayState>.broadcast();
  Stream<SyncPlayState> get states => _states.stream;

  SyncPlayState _state = SyncPlayState.idle;
  SyncPlayState get state => _state;

  /// The group's queue, as playlist-entry id per position. The server
  /// addresses tracks by these rather than by item id, because the same track
  /// may sit in the queue twice.
  ///
  /// Note what this does *not* cover: reaching the end of a track advances the
  /// local player on its own rather than through the group, so members drift
  /// apart at track boundaries instead of being re-cued together.
  List<String> _playlistItemIds = const [];
  int _playingIndex = 0;

  Timer? _scheduled;
  Timer? _clockTimer;
  StreamSubscription<ProcessingState>? _bufferingSub;
  bool _reportedBuffering = false;

  /// How often the clock is re-measured. Drift between two machines is slow,
  /// but a laptop waking from sleep can jump, so this is not a one-off.
  static const _clockInterval = Duration(minutes: 2);

  /// A command whose moment is further out than this is treated as a mistake
  /// rather than obeyed — a wildly wrong clock would otherwise park playback
  /// for hours.
  static const _maxSchedule = Duration(seconds: 30);

  // ─── Membership ────────────────────────────────────────────────────

  Future<void> create(String name) async {
    await _syncPlay.create(name);
    // The server answers the creation with a GroupJoined frame; nothing to
    // do here but wait for it.
  }

  Future<void> join(String groupId) => _syncPlay.join(groupId);

  Future<void> leave() async {
    try {
      await _syncPlay.leave();
    } finally {
      _teardown();
    }
  }

  /// Forget the group without telling the server — for logout, where the
  /// session that held the membership is gone anyway.
  void reset() => _teardown();

  /// Drop group state without talking to the server — on logout, or when the
  /// server tells us we are no longer a member.
  void _teardown() {
    _scheduled?.cancel();
    _scheduled = null;
    _clockTimer?.cancel();
    _clockTimer = null;
    unawaited(_bufferingSub?.cancel());
    _bufferingSub = null;
    _reportedBuffering = false;
    _playlistItemIds = const [];
    _playingIndex = 0;
    _emit(SyncPlayState.idle);
  }

  Future<void> dispose() async {
    _teardown();
    await _states.close();
  }

  void _emit(SyncPlayState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  // ─── Socket frames ─────────────────────────────────────────────────

  /// Feed one `/socket` frame in. Non-SyncPlay frames are ignored, so the
  /// caller can hand over everything it receives.
  Future<void> handleFrame(JellyfinNotification frame) async {
    final data = frame.data;
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    switch (frame.messageType) {
      case 'SyncPlayGroupUpdate':
        await _onGroupUpdate(map);
      case 'SyncPlayCommand':
        await _onCommand(map);
    }
  }

  Future<void> _onGroupUpdate(Map<String, dynamic> update) async {
    final type = '${update['Type']}';
    final payload = update['Data'];

    switch (type) {
      case 'GroupJoined':
        if (payload is Map) {
          await _onJoined(Map<String, dynamic>.from(payload));
        }
      case 'GroupLeft':
      case 'NotInGroup':
        _teardown();
      case 'UserJoined':
        _emit(_state.copyWith(members: [..._state.members, '$payload']));
      case 'UserLeft':
        _emit(_state.copyWith(
          members: [
            for (final m in _state.members)
              if (m != '$payload') m,
          ],
        ));
      case 'PlayQueue':
        if (payload is Map) {
          await _onPlayQueue(Map<String, dynamic>.from(payload));
        }
      case 'StateUpdate':
        if (payload is Map) {
          final groupState = '${payload['State']}';
          _emit(_state.copyWith(waiting: groupState == 'Waiting'));
        }
      // GroupDoesNotExist / LibraryAccessDenied land here too; both mean the
      // join did not happen, and the state is already idle.
    }
  }

  Future<void> _onJoined(Map<String, dynamic> info) async {
    final participants = info['Participants'];
    _emit(SyncPlayState(
      groupId: '${info['GroupId'] ?? ''}',
      groupName: '${info['GroupName'] ?? ''}',
      members: participants is List ? [for (final p in participants) '$p'] : const [],
      clock: _state.clock,
    ));
    await _syncClock();
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(_clockInterval, (_) => _syncClock());
    _watchBuffering();
  }

  Future<void> _syncClock() async {
    final clock = await _syncPlay.measureClock();
    if (_state.active) _emit(_state.copyWith(clock: clock));
  }

  // ─── The group's queue ─────────────────────────────────────────────

  Future<void> _onPlayQueue(Map<String, dynamic> queue) async {
    final playlist = queue['Playlist'];
    if (playlist is! List) return;

    final itemIds = <String>[];
    final entryIds = <String>[];
    for (final entry in playlist) {
      if (entry is! Map) continue;
      itemIds.add('${entry['ItemId']}');
      entryIds.add('${entry['PlaylistItemId']}');
    }
    _playlistItemIds = entryIds;
    _playingIndex = (queue['PlayingItemIndex'] as num?)?.toInt() ?? 0;

    if (itemIds.isEmpty) {
      await _handler.stop();
      return;
    }

    final startTicks = (queue['StartPositionTicks'] as num?)?.toInt() ?? 0;
    final position = Duration(milliseconds: startTicks ~/ 10000);
    final items = await _music.itemsByIds(itemIds);
    if (items.isEmpty) return;

    // Loaded paused on purpose: the server sends the moment to start as its
    // own command, and starting here would put this device ahead of the group.
    await _handler.loadQueue(
      items,
      startIndex: _playingIndex.clamp(0, items.length - 1),
      startPosition: position,
      autoPlay: false,
    );
    await _reportReady(position: position, isPlaying: false);
  }

  // ─── Commands ──────────────────────────────────────────────────────

  Future<void> _onCommand(Map<String, dynamic> command) async {
    final when = DateTime.tryParse('${command['When']}');
    final ticks = (command['PositionTicks'] as num?)?.toInt() ?? 0;
    final target = Duration(milliseconds: ticks ~/ 10000);
    final what = '${command['Command']}';
    if (when == null) return;

    _scheduled?.cancel();

    final localWhen = _state.clock.toLocal(when.toUtc());
    final delay = localWhen.difference(DateTime.now().toUtc());

    if (delay > _maxSchedule) {
      // Further out than any real cue: act now rather than sit idle for what
      // is almost certainly a clock that is badly wrong.
      await _apply(what, target, lateBy: Duration.zero);
      return;
    }
    if (delay <= Duration.zero) {
      await _apply(what, target, lateBy: -delay);
      return;
    }
    _scheduled = Timer(delay, () {
      unawaited(_apply(what, target, lateBy: Duration.zero));
    });
  }

  /// [lateBy] is how long after the appointed moment this ran. For anything
  /// that resumes playback it is added to the target position — the group has
  /// been playing for that long already, and starting from the old position
  /// would leave this device permanently behind.
  Future<void> _apply(
    String command,
    Duration target, {
    required Duration lateBy,
  }) async {
    switch (command) {
      case 'Unpause':
        await _handler.seek(target + lateBy);
        await _handler.play();
      case 'Pause':
        await _handler.pause();
        await _handler.seek(target);
      case 'Seek':
        await _handler.seek(target);
      case 'Stop':
        await _handler.stop();
    }
  }

  // ─── Falling behind ────────────────────────────────────────────────

  /// Tell the server when this device stalls, and again when it recovers.
  ///
  /// Without this the group either drifts apart or waits forever, depending on
  /// the server's policy — the whole point of the handshake is that a member
  /// whose network hiccups holds everyone rather than silently lagging.
  void _watchBuffering() {
    _bufferingSub?.cancel();
    _bufferingSub = _handler.player.processingStateStream.listen((state) {
      if (!_state.active) return;
      final stalled =
          state == ProcessingState.buffering || state == ProcessingState.loading;
      if (stalled == _reportedBuffering) return;
      _reportedBuffering = stalled;
      final position = _handler.player.position;
      final playing = _handler.player.playing;
      unawaited(stalled
          ? _reportBuffering(position: position, isPlaying: playing)
          : _reportReady(position: position, isPlaying: playing));
    });
  }

  String? get _currentEntryId =>
      _playingIndex >= 0 && _playingIndex < _playlistItemIds.length
          ? _playlistItemIds[_playingIndex]
          : null;

  Future<void> _reportBuffering({
    required Duration position,
    required bool isPlaying,
  }) async {
    final entry = _currentEntryId;
    if (entry == null) return;
    try {
      await _syncPlay.reportBuffering(
        playlistItemId: entry,
        position: position,
        isPlaying: isPlaying,
      );
    } catch (_) {/* the group carries on without us */}
  }

  Future<void> _reportReady({
    required Duration position,
    required bool isPlaying,
  }) async {
    final entry = _currentEntryId;
    if (entry == null) return;
    try {
      await _syncPlay.reportReady(
        playlistItemId: entry,
        position: position,
        isPlaying: isPlaying,
      );
    } catch (_) {/* the group carries on without us */}
  }

  // ─── Transport, routed through the group ───────────────────────────
  //
  // While a group is joined every transport action belongs to the server: it
  // decides when, and this device hears its own command back over the socket
  // like every other member. Acting locally as well would put this one ahead.

  Future<void> play() => _syncPlay.play();

  Future<void> pause() => _syncPlay.pause();

  Future<void> seek(Duration position) => _syncPlay.seek(position);

  Future<void> skipToNext() async {
    final entry = _currentEntryId;
    if (entry != null) await _syncPlay.next(entry);
  }

  Future<void> skipToPrevious() async {
    final entry = _currentEntryId;
    if (entry != null) await _syncPlay.previous(entry);
  }

  Future<void> setQueue(List<JellyfinItem> items, {int startIndex = 0}) =>
      _syncPlay.setQueue(
        [for (final i in items) i.id],
        startIndex: startIndex,
      );

  Future<void> addToQueue(List<JellyfinItem> items, {bool next = false}) =>
      _syncPlay.queue([for (final i in items) i.id], next: next);

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) =>
      _syncPlay.setRepeatMode(switch (mode) {
        AudioServiceRepeatMode.one => 'RepeatOne',
        AudioServiceRepeatMode.all ||
        AudioServiceRepeatMode.group =>
          'RepeatAll',
        AudioServiceRepeatMode.none => 'RepeatNone',
      });

  Future<void> setShuffle(bool enabled) =>
      _syncPlay.setShuffleMode(enabled ? 'Shuffle' : 'Sorted');
}
