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
import 'data/cache/http_cache.dart';
import 'data/jellyfin/auth_repository.dart';
import 'data/jellyfin/resilient_secure_storage.dart';
import 'data/jellyfin/jellyfin_service.dart';
import 'features/settings/settings_providers.dart';
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

  // On Linux/Windows (and optionally macOS) just_audio has no native
  // backend — this routes playback through libmpv so desktop works too.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    // libmpv only decodes the next queue entry ahead of time when asked to,
    // and that prefetch is what makes desktop playback gapless. Both knobs
    // have to be set before the first player is created, hence the read here
    // rather than in a provider.
    JustAudioMediaKit.prefetchPlaylist = await loadSavedGapless();
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

  // Stable per-install device id (Jellyfin tracks sessions by it).
  final deviceId = await AuthRepository.ensureDeviceId(storage);

  // Persistent HTTP cache so browsing doesn't re-hit the server every time.
  final cacheStore = await buildCacheStore();
  final service = JellyfinService(deviceId: deviceId, cacheStore: cacheStore);

  // Apply the saved streaming quality before the first track plays.
  service.maxStreamingBitrate = (await loadSavedAudioQuality()).bitrate;
  final fadeSeconds = await loadSavedFadeSeconds();
  final normalization = await loadSavedNormalization();

  // Start audio_service — this hosts our handler in a background isolate
  // on mobile and wires OS media controls.
  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(service),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.jellymusic.app.audio',
      androidNotificationChannelName: 'JellyMusic',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  audioHandler.fadeDuration = Duration(seconds: fadeSeconds);
  audioHandler.normalization = normalization;

  runApp(
    ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        jellyfinServiceProvider.overrideWithValue(service),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const JellyMusicApp(),
    ),
  );
}
