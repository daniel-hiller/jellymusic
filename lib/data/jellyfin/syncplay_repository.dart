import 'package:dart_jellyfin/dart_jellyfin.dart';

import 'jellyfin_service.dart';

/// One SyncPlay group as the server advertises it.
class SyncPlayGroup {
  const SyncPlayGroup({
    required this.id,
    required this.name,
    this.participants = const [],
  });

  final String id;
  final String name;

  /// Display names of the members, as the server reports them.
  final List<String> participants;

  factory SyncPlayGroup.fromJson(Map<String, dynamic> json) {
    final raw = json['Participants'];
    return SyncPlayGroup(
      id: '${json['GroupId'] ?? ''}',
      name: '${json['GroupName'] ?? ''}',
      participants: raw is List
          ? [for (final p in raw) '$p']
          : const [],
    );
  }
}

/// How far this device's clock sits from the server's, and how good that
/// measurement is.
///
/// SyncPlay commands carry the wall-clock instant they are meant to take
/// effect, so every client needs the server's clock rather than its own —
/// two devices whose clocks differ by half a second would otherwise start
/// half a second apart, which is exactly what the feature exists to prevent.
class ClockOffset {
  const ClockOffset({required this.offset, required this.roundTrip});

  /// `serverClock - localClock`. Add it to a local instant to get the
  /// server's, subtract it to go the other way.
  final Duration offset;

  /// Round-trip time of the measurement it came from. Smaller is better:
  /// the offset's error is bounded by half of this.
  final Duration roundTrip;

  static const zero =
      ClockOffset(offset: Duration.zero, roundTrip: Duration.zero);

  /// A server instant expressed on this device's clock.
  DateTime toLocal(DateTime serverTime) => serverTime.subtract(offset);
}

/// Jellyfin's `/SyncPlay` surface: finding groups, joining them, driving the
/// group's playback, and the clock measurement the timing depends on.
class SyncPlayRepository {
  SyncPlayRepository(this._service);

  final JellyfinService _service;

  JellyfinSyncPlayApi get _api => _service.client.syncPlay;

  // ─── Groups ────────────────────────────────────────────────────────

  /// Groups the current user is allowed to join.
  Future<List<SyncPlayGroup>> groups() async {
    if (!_service.isAuthenticated) return const [];
    final raw = await _api.list();
    return [for (final g in raw) SyncPlayGroup.fromJson(g)];
  }

  Future<void> create(String name) => _api.createGroup(groupName: name);

  Future<void> join(String groupId) => _api.joinGroup(groupId: groupId);

  Future<void> leave() => _api.leaveGroup();

  // ─── Driving the group ─────────────────────────────────────────────
  //
  // These replace the local transport while a group is joined: the server
  // decides when everyone acts, and this client hears its own command back
  // over the socket like every other member.

  Future<void> play() => _api.unpause();

  Future<void> pause() => _api.pause();

  Future<void> stop() => _api.stop();

  Future<void> seek(Duration position) =>
      _api.seek(positionTicks: _ticks(position));

  Future<void> next(String playlistItemId) =>
      _api.nextItem(playlistItemId: playlistItemId);

  Future<void> previous(String playlistItemId) =>
      _api.previousItem(playlistItemId: playlistItemId);

  Future<void> setPlaylistItem(String playlistItemId) =>
      _api.setPlaylistItem(playlistItemId: playlistItemId);

  /// Replace what the group is playing, starting at [startIndex].
  Future<void> setQueue(
    List<String> itemIds, {
    int startIndex = 0,
    Duration position = Duration.zero,
  }) =>
      _api.setNewQueue(
        playingQueue: itemIds,
        playingItemPosition: startIndex,
        startPositionTicks: _ticks(position),
      );

  Future<void> queue(List<String> itemIds, {bool next = false}) =>
      _api.queue(itemIds: itemIds, mode: next ? 'QueueNext' : 'Queue');

  /// `RepeatNone | RepeatAll | RepeatOne`, applied to the whole group.
  Future<void> setRepeatMode(String mode) => _api.setRepeatMode(mode: mode);

  /// `Sorted | Shuffle`, applied to the whole group.
  Future<void> setShuffleMode(String mode) => _api.setShuffleMode(mode: mode);

  // ─── Sync handshake ────────────────────────────────────────────────

  /// Tell the server this client is stalled, so the group waits for it.
  Future<void> reportBuffering({
    required String playlistItemId,
    required Duration position,
    required bool isPlaying,
  }) =>
      _api.buffering(
        playlistItemId: playlistItemId,
        positionTicks: _ticks(position),
        isPlaying: isPlaying,
      );

  /// Tell the server this client has caught up and can resume.
  Future<void> reportReady({
    required String playlistItemId,
    required Duration position,
    required bool isPlaying,
  }) =>
      _api.ready(
        playlistItemId: playlistItemId,
        positionTicks: _ticks(position),
        isPlaying: isPlaying,
      );

  /// Measure the offset between this device's clock and the server's.
  ///
  /// The exchange is the usual NTP one: note when the request left, read the
  /// two server-side stamps out of the reply, note when it came back. The
  /// round trip cancels out of the offset as long as it is roughly
  /// symmetric, which over a LAN it is.
  ///
  /// [samples] measurements are taken and the one with the shortest round
  /// trip wins rather than an average — a single delayed packet skews a mean,
  /// while the fastest exchange is the one least distorted by queueing.
  Future<ClockOffset> measureClock({int samples = 3}) async {
    ClockOffset? best;
    for (var i = 0; i < samples; i++) {
      final sample = await _measureOnce();
      if (sample == null) continue;
      if (best == null || sample.roundTrip < best.roundTrip) best = sample;
    }
    if (best != null) {
      // The server records the round trip against this session so it can
      // decide how long to give each member before starting without them.
      try {
        await _api.ping(ping: best.roundTrip.inMilliseconds);
      } catch (_) {/* advisory only */}
    }
    return best ?? ClockOffset.zero;
  }

  Future<ClockOffset?> _measureOnce() async {
    try {
      final sent = DateTime.now().toUtc();
      final body = await _service.client.system.utcTime();
      final received = DateTime.now().toUtc();

      final reception = DateTime.tryParse('${body['RequestReceptionTime']}');
      final transmission =
          DateTime.tryParse('${body['ResponseTransmissionTime']}');
      if (reception == null || transmission == null) return null;

      final roundTrip = received.difference(sent) -
          transmission.difference(reception);
      final offset = (reception.difference(sent) +
              transmission.difference(received)) ~/
          2;
      return ClockOffset(
        offset: offset,
        // A clock that ran backwards between the two reads would give a
        // negative trip; treat it as unusably noisy rather than best.
        roundTrip: roundTrip.isNegative ? const Duration(days: 1) : roundTrip,
      );
    } catch (_) {
      return null;
    }
  }

  static int _ticks(Duration d) => d.inMilliseconds * 10000;
}
