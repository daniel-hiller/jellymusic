import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

import '../../core/app_info.dart';
import '../../core/util/item_x.dart';
import '../cache/http_cache.dart';
import 'device_profile.dart';

/// What the server decided about one track: where to stream it from, how it
/// is being delivered, and the session the delivery belongs to.
class PlaybackNegotiation {
  const PlaybackNegotiation({
    required this.url,
    required this.playMethod,
    this.playSessionId,
    this.mediaSourceId,
  });

  /// `PlayMethod` values as `/Sessions/Playing` expects them.
  static const directPlay = 'DirectPlay';
  static const directStream = 'DirectStream';
  static const transcode = 'Transcode';

  /// Signed URL to hand to the audio engine.
  final String url;

  /// One of [directPlay], [directStream] or [transcode] — reported back so the
  /// server dashboard shows what a session is really costing it.
  final String playMethod;

  /// Session the server opened for this decision; threaded through playback
  /// reporting so it can match the two up (and clean up a transcode job).
  final String? playSessionId;

  /// Which of the item's sources is playing.
  final String? mediaSourceId;
}

/// Thin wrapper around [JellyfinClient] that owns the connection identity
/// and centralises URL building (artwork + audio streams).
///
/// One instance lives for the whole app (see `providers/providers.dart`).
/// Screens never touch [JellyfinClient] directly — they go through the
/// repositories, which read [client] from here.
class JellyfinService {
  JellyfinService._({
    required String deviceId,
    required this.client,
    CacheStore? cacheStore,
  })  : _deviceId = deviceId,
        _cacheStore = cacheStore;

  /// Creates the service and its SDK client. Pass a [cacheStore] to route
  /// all SDK requests through the caching [Dio]; omit it (e.g. in tests) for
  /// a plain, uncached client.
  factory JellyfinService({
    required String deviceId,
    CacheStore? cacheStore,
  }) {
    final client = JellyfinClient(
      credentials: JellyfinCredentials(
        client: appName,
        device: _defaultDeviceName(),
        deviceId: deviceId,
        version: appVersion,
      ),
      dio: cacheStore != null ? buildCachingDio(cacheStore) : null,
    );
    return JellyfinService._(
      deviceId: deviceId,
      client: client,
      cacheStore: cacheStore,
    );
  }

  static const String appName = 'JellyMusic';
  static const String appVersion = AppInfo.version;

  final String _deviceId;
  final JellyfinClient client;
  final CacheStore? _cacheStore;

  int? _maxStreamingBitrate;

  /// Album-level normalisation gains keyed by album id, including the misses:
  /// a null value means "asked, the server has none", so an unscanned album
  /// isn't re-fetched once per track.
  final Map<String, double?> _albumGains = {};

  /// Direct-play decisions keyed by item id. Only these are kept: their URL is
  /// a plain static file link that stays valid, whereas a transcode decision
  /// carries a play session the server would tear down on reuse.
  final Map<String, PlaybackNegotiation> _directDecisions = {};

  /// Cap for streaming bitrate (bits/s); null lets the server decide / direct
  /// play. Set from user settings; applied to newly started tracks.
  int? get maxStreamingBitrate => _maxStreamingBitrate;

  set maxStreamingBitrate(int? value) {
    if (value == _maxStreamingBitrate) return;
    _maxStreamingBitrate = value;
    // Every stored decision was made under the previous cap.
    _directDecisions.clear();
  }

  /// Drop all cached HTTP responses (after writes, on logout, on refresh).
  Future<void> clearCache() async {
    _albumGains.clear();
    _directDecisions.clear();
    await _cacheStore?.clean();
  }

  String get deviceId => _deviceId;
  bool get isConnected => client.baseUrl != null;
  bool get isAuthenticated => client.isAuthenticated;
  String? get userId => client.userId;

  /// Point the client at a server + restore an existing session.
  void restore({
    required String baseUrl,
    required String token,
    required String userId,
  }) {
    client.connect(_normalizeUrl(baseUrl));
    client.setSession(token: token, userId: userId);
  }

  /// Connect to a server without a session (pre-login).
  void connect(String baseUrl) => client.connect(_normalizeUrl(baseUrl));

  void setSession({required String token, required String userId}) =>
      client.setSession(token: token, userId: userId);

  void logout() {
    _albumGains.clear();
    _directDecisions.clear();
    client.disconnect();
  }

  // ─── Loudness ──────────────────────────────────────────────────────

  /// Album-wide normalisation gain in dB, or null when the server has none.
  ///
  /// Only newer servers copy the album gain onto every track, so it generally
  /// has to be read off the album item itself. The result is memoised because
  /// a queue is usually a handful of albums played track by track — otherwise
  /// this would be one request per track change.
  Future<double?> albumNormalizationGain(String albumId) async {
    if (_albumGains.containsKey(albumId)) return _albumGains[albumId];
    double? gain;
    try {
      gain = (await client.items.byId(albumId))?.normalizationGainDb;
    } catch (_) {
      // Offline or a server hiccup — don't cache the miss, so the next track
      // from this album can try again.
      return null;
    }
    _albumGains[albumId] = gain;
    return gain;
  }

  // ─── Artwork URLs ──────────────────────────────────────────────────

  /// Primary cover art for an item. Pass the item's `imageTags['Primary']`
  /// as [tag] for proper cache-busting, or fall back to the album's
  /// primary tag for a track.
  String? primaryImageUrl(
    JellyfinItem item, {
    int size = 512,
  }) {
    if (!isConnected) return null;
    final tag = item.imageTags[JellyfinImagesApi.typePrimary];
    if (tag != null) {
      return client.images.url(
        itemId: item.id,
        type: JellyfinImagesApi.typePrimary,
        tag: tag,
        fillWidth: size,
        fillHeight: size,
      );
    }
    // Track without its own art -> use the parent album's primary image.
    if (item.albumId != null && item.albumPrimaryImageTag != null) {
      return client.images.url(
        itemId: item.albumId!,
        type: JellyfinImagesApi.typePrimary,
        tag: item.albumPrimaryImageTag,
        fillWidth: size,
        fillHeight: size,
      );
    }
    return null;
  }

  /// Raw primary-image URL by id + tag (for views/artists where we only
  /// have the id).
  String imageUrlById(String itemId, {String? tag, int size = 512}) =>
      client.images.url(
        itemId: itemId,
        type: JellyfinImagesApi.typePrimary,
        tag: tag,
        fillWidth: size,
        fillHeight: size,
      );

  /// Backdrop (wide) art for headers, if the item has one.
  String? backdropUrl(JellyfinItem item, {int width = 1280}) {
    if (!isConnected || item.backdropImageTags.isEmpty) return null;
    return client.images.url(
      itemId: item.id,
      type: JellyfinImagesApi.typeBackdrop,
      tag: item.backdropImageTags.first,
      fillWidth: width,
    );
  }

  // ─── Playback negotiation ──────────────────────────────────────────

  /// How long to wait for a playback decision before giving up on it. Short
  /// on purpose: this sits between tapping a song and hearing it, and the
  /// fallback plays just as well.
  static const _negotiationTimeout = Duration(seconds: 6);

  /// Ask the server how to play [itemId], given what this platform can decode
  /// and the bitrate the user allowed.
  ///
  /// The server answers with a media source that says whether the file can be
  /// streamed as it is or has to be re-encoded, plus the URL for whichever it
  /// picked. This replaces guessing at the universal endpoint, which had to
  /// force a transcode whenever a cap was set because it couldn't know the
  /// source was already below it.
  ///
  /// Never throws and never returns null: an old server, an error or a timeout
  /// all fall back to [streamUrl], so a track never fails to play because the
  /// negotiation did.
  Future<PlaybackNegotiation> negotiatePlayback(String itemId) async {
    final cached = _directDecisions[itemId];
    if (cached != null) return cached;
    try {
      final info = await client.mediaInfo
          .postedInfo(
            itemId: itemId,
            deviceProfile:
                audioDeviceProfile(maxStreamingBitrate: _maxStreamingBitrate),
            maxStreamingBitrate: _maxStreamingBitrate,
          )
          .timeout(_negotiationTimeout);
      if (info.errorCode != null || info.mediaSources.isEmpty) {
        return _fallbackPlayback(itemId);
      }
      final source = info.mediaSources.first;

      if (source.supportsDirectPlay || source.supportsDirectStream) {
        // No container in the path: ffprobe reports some files with a whole
        // list of them ("mov,mp4,m4a,…"), which makes no sense as a file
        // extension. The server types the response either way.
        final decision = PlaybackNegotiation(
          url: client.audio.directStreamUrl(itemId: itemId).$1,
          playMethod: source.supportsDirectPlay
              ? PlaybackNegotiation.directPlay
              : PlaybackNegotiation.directStream,
          playSessionId: info.playSessionId,
          mediaSourceId: source.id,
        );
        _directDecisions[itemId] = decision;
        return decision;
      }

      final transcodingUrl = source.transcodingUrl;
      if (transcodingUrl != null) {
        return PlaybackNegotiation(
          // Relative to the server root, and already signed.
          url: '${client.baseUrl}$transcodingUrl',
          playMethod: PlaybackNegotiation.transcode,
          playSessionId: info.playSessionId,
          mediaSourceId: source.id,
        );
      }
    } catch (_) {/* pre-negotiation server, offline, or too slow */}
    return _fallbackPlayback(itemId);
  }

  PlaybackNegotiation _fallbackPlayback(String itemId) => PlaybackNegotiation(
        url: streamUrl(itemId, maxStreamingBitrate: _maxStreamingBitrate),
        // Without a decision from the server, all we know is what we asked the
        // universal endpoint for: with a cap it re-encodes to MP3, without one
        // it serves the containers we listed as they are.
        playMethod: _maxStreamingBitrate == null
            ? PlaybackNegotiation.directPlay
            : PlaybackNegotiation.transcode,
      );

  // ─── Stream URLs ───────────────────────────────────────────────────

  /// Signed streaming URL for a track. Uses the "universal" endpoint so
  /// the server transparently transcodes when the client can't direct-play
  /// the source container.
  ///
  /// This is the fallback behind [negotiatePlayback]: it needs no round trip
  /// and plays on every server version, at the price of transcoding whenever
  /// a bitrate cap is set.
  ///
  /// [maxStreamingBitrate] lets you cap bandwidth on mobile networks.
  String streamUrl(
    String itemId, {
    int? maxStreamingBitrate,
    String? playSessionId,
  }) =>
      client.audio.universalStreamUrl(
        itemId: itemId,
        maxStreamingBitrate: maxStreamingBitrate,
        playSessionId: playSessionId,
        // When a bitrate cap forces transcoding, request a *progressive* MP3
        // stream instead of the default HLS/ts — plain HTML5 audio (web) and
        // libmpv (desktop) both play it, whereas HLS fails in the browser.
        transcodingProtocol: 'http',
        transcodingContainer: 'mp3',
        audioCodec: 'mp3',
      );

  static String _defaultDeviceName() {
    // Kept simple; a fuller impl would read platform/device model.
    return 'Flutter';
  }

  static String _normalizeUrl(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    // Strip a trailing slash so path joins stay clean.
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }
}
