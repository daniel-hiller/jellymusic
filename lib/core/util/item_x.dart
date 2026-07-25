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
