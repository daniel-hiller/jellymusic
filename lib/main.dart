import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/desktop/desktop_tray.dart';
import 'core/audio/audio_player_handler.dart';
import 'core/theme/app_theme.dart';
import 'data/cache/http_cache.dart';
import 'data/jellyfin/auth_repository.dart';
import 'data/jellyfin/resilient_secure_storage.dart';
import 'data/jellyfin/jellyfin_service.dart';
import 'features/settings/settings_providers.dart';
import 'features/shell/splash_screen.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop windowing (needed by the system tray to show/focus the window).
  if (isDesktop) {
    await windowManager.ensureInitialized();
  }

  // A right click opens an item's context menu; on the web the browser would
  // otherwise put its own menu on top of it.
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }

  // Everything else start-up needs — the keyring, the on-disk caches, the
  // media session — is platform I/O that no first frame depends on, so it runs
  // behind the splash rather than in front of it. See [_Boot].
  runApp(const _Boot());
}

/// The long-lived services the app is built on; nothing can be read before
/// they exist.
class _Services {
  const _Services(this.storage, this.jellyfin, this.audio);

  final ResilientSecureStorage storage;
  final JellyfinService jellyfin;
  final AudioPlayerHandler audio;
}

/// Draws the splash while start-up runs, then swaps in the real app with the
/// finished services in its provider scope.
///
/// This is what keeps the launch short. Awaiting the same work *before*
/// [runApp] leaves the OS launch image on screen for all of it, with no Flutter
/// UI behind it — the app looks frozen and doesn't answer a touch. On iOS the
/// keyring, the HTTP cache and the media session together take long enough
/// that this is plainly visible.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  _Services? _services;

  @override
  void initState() {
    super.initState();
    _boot().then((services) {
      if (mounted) setState(() => _services = services);
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    if (services == null) {
      // No provider scope yet, so no saved theme either. Nocturne is the
      // default and the colour the native launch image is drawn in, so the
      // handover from it has nothing to give away.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: JellyTheme.nocturne.themeData,
        home: const SplashScreen(),
      );
    }
    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(services.storage),
        jellyfinServiceProvider.overrideWithValue(services.jellyfin),
        audioHandlerProvider.overrideWithValue(services.audio),
      ],
      child: const JellyMusicApp(),
    );
  }
}

Future<_Services> _boot() async {
  // On Linux/Windows (and optionally macOS) just_audio has no native
  // backend — this routes playback through libmpv so desktop works too.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    // libmpv only decodes the next queue entry ahead of time when asked to,
    // and that prefetch is what makes desktop playback gapless. Both knobs
    // have to be set before the first player is created, hence the read here
    // rather than in a provider.
    JustAudioMediaKit.prefetchPlaylist =
        await _step('gapless setting', loadSavedGapless);
    // Names the process in the system volume mixer (defaults to the package
    // name otherwise).
    JustAudioMediaKit.title = 'JellyMusic';
    JustAudioMediaKit.ensureInitialized();
  }

  // flutter_secure_storage 10 encrypts on Android by default; the old
  // `encryptedSharedPreferences` option was removed. Wrapped so a locked/absent
  // OS keyring (common on Linux desktops that don't auto-unlock it) falls back
  // to shared_preferences instead of crashing at launch.
  final storage = ResilientSecureStorage(const FlutterSecureStorage());

  // Each of these is a round trip to a different corner of the platform and
  // none of them needs the others, so they go at once rather than in turn.
  final (deviceId, cacheStore, quality, fadeSeconds, normalization) = await (
    // Stable per-install device id (Jellyfin tracks sessions by it).
    _step('device id', () => AuthRepository.ensureDeviceId(storage)),
    // Persistent HTTP cache so browsing doesn't re-hit the server every time.
    _step('http cache', buildCacheStore),
    _step('audio quality', loadSavedAudioQuality),
    _step('fade setting', loadSavedFadeSeconds),
    _step('normalisation', loadSavedNormalization),
  ).wait;

  final service = JellyfinService(deviceId: deviceId, cacheStore: cacheStore);
  // Apply the saved streaming quality before the first track plays.
  service.maxStreamingBitrate = quality.bitrate;

  // Start audio_service — this hosts our handler in a background isolate
  // on mobile and wires OS media controls.
  final audioHandler = await _step(
    'media session',
    () => AudioService.init(
      builder: () => AudioPlayerHandler(service),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.jellymusic.app.audio',
        androidNotificationChannelName: 'JellyMusic',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    ),
  );
  audioHandler.fadeDuration = Duration(seconds: fadeSeconds);
  audioHandler.normalization = normalization;

  return _Services(storage, service, audioHandler);
}

/// Times one start-up step and reports it in debug builds.
///
/// Launch cost is easy to regress and hard to pin down afterwards: a keyring
/// that has to be unlocked, an HTTP cache that has grown, a media session the
/// OS is slow to hand out — from the outside they are one and the same wait.
Future<T> _step<T>(String name, Future<T> Function() run) async {
  if (!kDebugMode) return run();
  final watch = Stopwatch()..start();
  try {
    return await run();
  } finally {
    debugPrint('boot: $name — ${watch.elapsedMilliseconds} ms');
  }
}
