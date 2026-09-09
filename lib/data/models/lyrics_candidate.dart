/// One lyric result offered by a server-side lyric provider plugin.
///
/// The search endpoint answers with the provider's own metadata rather than
/// the track's, so the title and artist here are what the *provider* matched —
/// which is exactly what makes the list worth showing: a wrong match is
/// usually obvious from the name before it is ever saved.
class LyricsCandidate {
  const LyricsCandidate({
    required this.id,
    required this.provider,
    this.title,
    this.artist,
    this.album,
    this.isSynced = false,
    this.duration,
  });

  /// Opaque id to hand back when saving this result.
  final String id;

  /// Which plugin produced it, shown so a server with several configured
  /// providers stays legible.
  final String provider;

  final String? title;
  final String? artist;
  final String? album;

  /// Whether the result carries timestamps. Synced lyrics scroll along with
  /// playback; plain ones only sit there, so the distinction is worth showing.
  final bool isSynced;

  /// Track length the provider matched against, when it reports one. Handy
  /// for spotting a match against a different edit of the same song.
  final Duration? duration;

  factory LyricsCandidate.fromJson(Map<String, dynamic> json) {
    final metadata = json['Metadata'];
    final meta = metadata is Map<String, dynamic> ? metadata : const {};
    // Jellyfin reports the length in ticks, like everything else it times.
    final ticks = meta['Length'];
    return LyricsCandidate(
      id: '${json['Id'] ?? ''}',
      provider: '${json['ProviderName'] ?? ''}',
      title: _text(meta['Title']),
      artist: _text(meta['Artist']),
      album: _text(meta['Album']),
      isSynced: meta['IsSynced'] == true,
      duration: ticks is num && ticks > 0
          ? Duration(milliseconds: ticks ~/ 10000)
          : null,
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
