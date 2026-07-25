import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

import '../../core/app_info.dart';
import '../cache/http_cache.dart';

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

  /// Cap for streaming bitrate (bits/s); null lets the server decide / direct
  /// play. Set from user settings; applied to newly started tracks.
  int? maxStreamingBitrate;

  /// Drop all cached HTTP responses (after writes, on logout, on refresh).
  Future<void> clearCache() async => _cacheStore?.clean();

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

  void logout() => client.disconnect();

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

  // ─── Stream URLs ───────────────────────────────────────────────────

  /// Signed streaming URL for a track. Uses the "universal" endpoint so
  /// the server transparently transcodes when the client can't direct-play
  /// the source container.
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
