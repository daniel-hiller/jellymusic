import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';

/// HTTP response caching for the Jellyfin SDK.
///
/// Jellyfin's API sends no cache directives, so browsing the same lists
/// re-hits the server every time — which feels sluggish. We inject a short
/// `Cache-Control` on GET responses and let [DioCacheInterceptor] persist them
/// (Hive on device, IndexedDB on web). Reads within the TTL come straight from
/// disk; mutations call [CacheStore.clean] to stay correct.
class HttpCache {
  HttpCache(this.store, this.dio);

  final CacheStore store;
  final Dio dio;

  /// Drop everything (called after writes / on logout / on manual refresh).
  Future<void> clear() => store.clean();
}

/// Build the persistent cache store, falling back to in-memory if the
/// platform store can't be opened.
Future<CacheStore> buildCacheStore() async {
  try {
    if (kIsWeb) return HiveCacheStore(null);
    final dir = await getApplicationSupportDirectory();
    return HiveCacheStore('${dir.path}/jellymusic_http_cache');
  } catch (_) {
    return MemCacheStore();
  }
}

/// A [Dio] wired with the cache interceptor. [ttl] bounds how long a cached
/// GET is served before revalidating against the server.
Dio buildCachingDio(
  CacheStore store, {
  Duration ttl = const Duration(seconds: 90),
}) {
  final dio = Dio();

  final cacheOptions = CacheOptions(
    store: store,
    policy: CachePolicy.forceCache,
    maxStale: const Duration(days: 7),
    // Serve stale cache on network failures and server errors — but never on
    // auth failures (401/403), which must reach the app. (dio_cache_interceptor
    // 4 replaced `hitCacheOnErrorExcept` with these two explicit knobs.)
    hitCacheOnNetworkFailure: true,
    hitCacheOnErrorCodes: const [500, 502, 503, 504],
  );

  // Volatile endpoints must never be cached — e.g. Quick Connect polling,
  // where a cached "not authenticated yet" response would hide the approval,
  // or `/Sessions`, where a cached device list would keep showing devices that
  // are long gone (and, worse, keep hiding ones that just appeared).
  bool isVolatile(Uri uri) =>
      uri.path.contains('/QuickConnect/') || uri.path.contains('/Sessions');

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (isVolatile(options.uri)) {
          options.extra
              .addAll(cacheOptions.copyWith(policy: CachePolicy.noCache)
                  .toExtra());
        }
        handler.next(options);
      },
      // Inject a freshness window on cacheable GET responses *before* the
      // cache interceptor stores them, so the cache has a bounded TTL.
      onResponse: (response, handler) {
        final req = response.requestOptions;
        if (req.method.toUpperCase() == 'GET' && !isVolatile(req.uri)) {
          response.headers.set('cache-control', 'max-age=${ttl.inSeconds}');
        }
        handler.next(response);
      },
    ),
  );

  dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));

  return dio;
}
