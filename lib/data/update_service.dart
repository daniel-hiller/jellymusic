import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/app_info.dart';

/// A newer release than the running build, discovered on GitHub.
class UpdateInfo {
  const UpdateInfo({required this.version, required this.url, this.notes});

  /// Release version, e.g. `1.2.0` (the tag with any leading `v` stripped).
  final String version;

  /// The release page to send the user to.
  final String url;

  /// Release notes body, if any.
  final String? notes;
}

/// Session-only flag: set once the user dismisses the update banner so it
/// doesn't reappear until the next launch.
final updateBannerDismissedProvider = StateProvider<bool>((_) => false);

/// Checks the GitHub releases API for a version newer than [AppInfo.version].
///
/// Returns null when up to date, unsupported (iOS/web), a dev build, or on any
/// network/parse error — the update hint is best-effort and never blocks.
final updateProvider = FutureProvider<UpdateInfo?>((ref) async {
  if (!AppInfo.supportsUpdateCheck || !AppInfo.isTaggedRelease) return null;

  try {
    final res = await Dio().get<Map<String, dynamic>>(
      AppInfo.latestReleaseApi,
      options: Options(
        headers: {'Accept': 'application/vnd.github+json'},
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    final data = res.data;
    if (data == null) return null;

    final tag = (data['tag_name'] as String?)?.trim();
    if (tag == null || tag.isEmpty) return null;
    final latest = _stripV(tag);

    if (_compare(latest, AppInfo.version) <= 0) return null; // up to date
    return UpdateInfo(
      version: latest,
      url: (data['html_url'] as String?) ?? AppInfo.releasesUrl,
      notes: data['body'] as String?,
    );
  } catch (_) {
    return null;
  }
});

String _stripV(String tag) =>
    tag.startsWith('v') || tag.startsWith('V') ? tag.substring(1) : tag;

/// Compares two dotted versions numerically. Pre-release suffixes (`-dev`,
/// `-rc1`) are ignored for the numeric compare, then a bare version outranks a
/// pre-release of the same numbers. Returns >0 if [a] is newer than [b].
int _compare(String a, String b) {
  final (aNums, aPre) = _split(a);
  final (bNums, bPre) = _split(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < aNums.length ? aNums[i] : 0) -
        (i < bNums.length ? bNums[i] : 0);
    if (d != 0) return d;
  }
  // Equal numbers: a release (no pre) beats a pre-release.
  if (aPre == bPre) return 0;
  if (aPre.isEmpty) return 1;
  if (bPre.isEmpty) return -1;
  return aPre.compareTo(bPre);
}

(List<int>, String) _split(String v) {
  final dash = v.indexOf('-');
  final core = dash == -1 ? v : v.substring(0, dash);
  final pre = dash == -1 ? '' : v.substring(dash + 1);
  final nums = [
    for (final part in core.split('.')) int.tryParse(part) ?? 0,
  ];
  return (nums, pre);
}
