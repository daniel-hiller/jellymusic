import 'package:flutter/foundation.dart';

/// Static facts about this build — the app version and the project's home.
///
/// The version is injected by CI from the git tag (`--dart-define=APP_VERSION`)
/// so `pubspec.yaml` can stay at a fixed `1.0.0`; App Store / Play versioning is
/// driven by the tag instead. Local dev builds show the `-dev` fallback.
abstract final class AppInfo {
  static const String version =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0-dev');

  static const String author = 'Daniel Hiller';
  static const String repoUrl = 'https://github.com/daniel-hiller/jellymusic';
  static const String releasesUrl = '$repoUrl/releases';
  static const String latestReleaseApi =
      'https://api.github.com/repos/daniel-hiller/jellymusic/releases/latest';

  /// True for a real tagged release (not a local `-dev` build). Used to gate
  /// the update check so dev builds don't nag.
  static bool get isTaggedRelease => !version.contains('-dev');

  /// Update checks run everywhere except iOS (the App Store handles updates)
  /// and web (always served fresh from the container).
  static bool get supportsUpdateCheck {
    if (kIsWeb) return false;
    return defaultTargetPlatform != TargetPlatform.iOS;
  }
}
