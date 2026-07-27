import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_player_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

/// Streaming quality presets. `bitrate` is the cap in bits/s passed to the
/// Jellyfin universal stream endpoint; `null` means no cap (direct play /
/// server decides).
enum AudioQuality {
  auto('Automatisch', null),
  low('Datensparend · 96 kbps', 96000),
  medium('Standard · 192 kbps', 192000),
  high('Hoch · 320 kbps', 320000),
  max('Maximal · verlustfrei', null);

  const AudioQuality(this.label, this.bitrate);
  final String label;
  final int? bitrate;

  static AudioQuality fromIndex(int? i) =>
      (i == null || i < 0 || i >= values.length) ? auto : values[i];
}

const _kAudioQuality = 'settings.audioQuality';

/// Load the saved streaming quality at startup and apply its bitrate to the
/// service, so the very first track already honours the preference.
Future<AudioQuality> loadSavedAudioQuality() async {
  final prefs = await SharedPreferences.getInstance();
  return AudioQuality.fromIndex(prefs.getInt(_kAudioQuality));
}

/// Current streaming quality; setting it persists the choice and updates the
/// service used to build stream URLs.
final audioQualityProvider =
    AsyncNotifierProvider<AudioQualityController, AudioQuality>(
        AudioQualityController.new);

class AudioQualityController extends AsyncNotifier<AudioQuality> {
  @override
  Future<AudioQuality> build() async {
    final prefs = await SharedPreferences.getInstance();
    final quality = AudioQuality.fromIndex(prefs.getInt(_kAudioQuality));
    ref.read(jellyfinServiceProvider).maxStreamingBitrate = quality.bitrate;
    return quality;
  }

  Future<void> setQuality(AudioQuality quality) async {
    ref.read(jellyfinServiceProvider).maxStreamingBitrate = quality.bitrate;
    state = AsyncData(quality);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAudioQuality, quality.index);
  }
}

// ─── Playback: gapless + fade ────────────────────────────────────────

const _kGapless = 'settings.gapless';
const _kFadeSeconds = 'settings.fadeSeconds';

/// Whether libmpv prefetches the next queue entry (desktop gapless).
///
/// Read in `main()` because `JustAudioMediaKit.prefetchPlaylist` has to be set
/// before the player exists — changing it takes effect on the next launch.
Future<bool> loadSavedGapless() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kGapless) ?? true;
}

/// Fade length in seconds at track boundaries; 0 keeps playback gapless.
Future<int> loadSavedFadeSeconds() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_kFadeSeconds) ?? 0;
}

/// Gapless toggle. Persisted immediately, applied on the next start.
final gaplessProvider =
    AsyncNotifierProvider<GaplessController, bool>(GaplessController.new);

class GaplessController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => loadSavedGapless();

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGapless, enabled);
  }
}

/// Whether the desktop sidebar is collapsed to icons only. Persisted.
const _kSidebarCollapsed = 'settings.sidebarCollapsed';

final sidebarCollapsedProvider =
    AsyncNotifierProvider<SidebarCollapsedController, bool>(
        SidebarCollapsedController.new);

class SidebarCollapsedController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSidebarCollapsed) ?? false;
  }

  Future<void> toggle() async {
    final next = !(state.value ?? false);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSidebarCollapsed, next);
  }
}

/// Desktop tray behaviour: hide to tray instead of quitting on window close,
/// and/or hide to tray on minimise. Two independent, persisted toggles.
const _kCloseToTray = 'settings.closeToTray';
const _kMinimizeToTray = 'settings.minimizeToTray';

final closeToTrayProvider =
    AsyncNotifierProvider<CloseToTrayController, bool>(
        CloseToTrayController.new);

class CloseToTrayController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCloseToTray) ?? false;
  }

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCloseToTray, enabled);
  }
}

final minimizeToTrayProvider =
    AsyncNotifierProvider<MinimizeToTrayController, bool>(
        MinimizeToTrayController.new);

class MinimizeToTrayController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMinimizeToTray) ?? false;
  }

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMinimizeToTray, enabled);
  }
}

// ─── Playback: loudness normalisation ────────────────────────────────

const _kNormalization = 'settings.normalization';

/// Saved levelling mode; off unless the user turned it on.
Future<AudioNormalization> loadSavedNormalization() async {
  final prefs = await SharedPreferences.getInstance();
  final index = prefs.getInt(_kNormalization);
  final values = AudioNormalization.values;
  return (index == null || index < 0 || index >= values.length)
      ? AudioNormalization.off
      : values[index];
}

/// Which ReplayGain value playback levels itself to. Applies to the running
/// track at once.
final normalizationProvider =
    AsyncNotifierProvider<NormalizationController, AudioNormalization>(
        NormalizationController.new);

class NormalizationController extends AsyncNotifier<AudioNormalization> {
  @override
  Future<AudioNormalization> build() async {
    final mode = await loadSavedNormalization();
    ref.read(audioHandlerProvider).normalization = mode;
    return mode;
  }

  Future<void> set(AudioNormalization mode) async {
    ref.read(audioHandlerProvider).normalization = mode;
    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNormalization, mode.index);
  }
}

/// Fade length in seconds (0 = off). Applies to the running player at once.
final fadeSecondsProvider =
    AsyncNotifierProvider<FadeController, int>(FadeController.new);

class FadeController extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final seconds = await loadSavedFadeSeconds();
    ref.read(audioHandlerProvider).fadeDuration = Duration(seconds: seconds);
    return seconds;
  }

  Future<void> set(int seconds) async {
    ref.read(audioHandlerProvider).fadeDuration = Duration(seconds: seconds);
    state = AsyncData(seconds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFadeSeconds, seconds);
  }
}

// ─── Theme ───────────────────────────────────────────────────────────

const _kTheme = 'settings.theme';

/// The selected [JellyTheme]. Persisted; defaults to Nocturne. Same shape as
/// [localeProvider] so the settings and login pickers wire up identically.
final themeProvider =
    AsyncNotifierProvider<ThemeController, JellyTheme>(ThemeController.new);

class ThemeController extends AsyncNotifier<JellyTheme> {
  @override
  Future<JellyTheme> build() async {
    final prefs = await SharedPreferences.getInstance();
    return JellyTheme.byName(prefs.getString(_kTheme));
  }

  Future<void> setTheme(JellyTheme theme) async {
    state = AsyncData(theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, theme.name);
  }
}

// ─── Language / locale ───────────────────────────────────────────────

const _kLocale = 'settings.localeCode';

/// App language: null means "follow the system". Persisted across launches.
final localeProvider =
    AsyncNotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_kLocale));
  }

  /// [code] is a language code ('de', 'en') or 'system'.
  Future<void> setLanguage(String code) async {
    state = AsyncData(_decode(code));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, code);
  }

  static Locale? _decode(String? code) =>
      (code == null || code == 'system') ? null : Locale(code);
}
