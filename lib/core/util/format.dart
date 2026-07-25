/// Formatting helpers shared across the UI.
abstract final class Format {
  /// `Duration` -> `m:ss` or `h:mm:ss`.
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:$s';
    }
    return '$m:$s';
  }

  /// Milliseconds -> `m:ss`. Returns `--:--` when null.
  static String durationMs(int? ms) {
    if (ms == null) return '--:--';
    return duration(Duration(milliseconds: ms));
  }

  /// "3 Titel • 2023" style subtitle for albums.
  static String albumSubtitle({int? trackCount, int? year}) {
    final parts = <String>[
      if (trackCount != null) '$trackCount ${trackCount == 1 ? 'Titel' : 'Titel'}',
      if (year != null) '$year',
    ];
    return parts.join(' • ');
  }
}
