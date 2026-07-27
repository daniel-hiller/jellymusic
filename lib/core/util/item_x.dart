import 'package:dart_jellyfin/dart_jellyfin.dart';

/// Display helpers on [JellyfinItem] that resolve the artist name(s) robustly.
///
/// Jellyfin scatters the artist across several fields depending on item kind
/// (`AlbumArtist`, `AlbumArtists`, `Artists`, `ArtistItems`). These getters
/// walk a sensible fallback chain so the UI never ends up with an empty label
/// just because one particular field wasn't populated.
extension JellyfinItemArtistX on JellyfinItem {
  /// Primary artist for an **album** — prefers the album artist.
  String get albumArtistLabel {
    final a = albumArtist;
    if (a != null && a.isNotEmpty) return a;
    if (albumArtists.isNotEmpty) return albumArtists.join(', ');
    if (artists.isNotEmpty) return artists.join(', ');
    if (artistItems.isNotEmpty) {
      return artistItems.map((r) => r.name).join(', ');
    }
    return '';
  }

  /// Primary artist for a **track** — prefers the track-level artists.
  String get trackArtistLabel {
    if (artists.isNotEmpty) return artists.join(', ');
    final a = albumArtist;
    if (a != null && a.isNotEmpty) return a;
    if (albumArtists.isNotEmpty) return albumArtists.join(', ');
    if (artistItems.isNotEmpty) {
      return artistItems.map((r) => r.name).join(', ');
    }
    return '';
  }
}

/// Loudness (ReplayGain) values Jellyfin computes during a library scan.
///
/// The SDK doesn't type them, so they're read out of the untouched
/// [JellyfinItem.raw] body. `NormalizationGain` is a dB offset — negative for
/// a loud master, positive for a quiet one — and the server puts it on the
/// track *and* on the album item, where it carries the album-wide gain.
/// `AlbumNormalizationGain` is the same album value copied onto the track;
/// it only exists on newer servers, which is why the album gain still has to
/// be resolvable from the album item.
extension JellyfinItemLoudnessX on JellyfinItem {
  /// Track-level gain in dB, or null when the server has none for this item.
  double? get normalizationGainDb => _gainDb('NormalizationGain');

  /// Album-level gain in dB as inherited onto a track. Null on servers that
  /// don't copy it down — resolve it from the album item instead.
  double? get albumNormalizationGainDb => _gainDb('AlbumNormalizationGain');

  double? _gainDb(String field) {
    final value = raw[field];
    // The field is a float on the wire, but a whole-number gain can arrive as
    // an int, and it is absent (rather than null) for unscanned items.
    return value is num && value.isFinite ? value.toDouble() : null;
  }
}
