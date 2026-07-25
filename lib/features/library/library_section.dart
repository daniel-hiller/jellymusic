import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../l10n/app_localizations.dart';

/// The browsable library categories. On desktop each is a direct sidebar entry;
/// on phones they stay as tabs inside the library screen.
///
/// There's deliberately no "favourites" entry — every list carries a favourites
/// filter in its controls bar, which covers it without a separate view.
enum LibrarySection { albums, artists, songs, playlists, genres }

/// Which library category the desktop content area shows. Driven by the
/// sidebar; ignored on phones (they use the tab bar instead).
final librarySectionProvider =
    StateProvider<LibrarySection>((_) => LibrarySection.albums);

extension LibrarySectionMeta on LibrarySection {
  /// Localised label, reusing the existing tab strings.
  String label(AppLocalizations l) => switch (this) {
        LibrarySection.albums => l.tabAlbums,
        LibrarySection.artists => l.tabArtists,
        LibrarySection.songs => l.tabSongs,
        LibrarySection.playlists => l.tabPlaylists,
        LibrarySection.genres => l.tabGenres,
      };

  IconData get icon => switch (this) {
        LibrarySection.albums => Icons.album_rounded,
        LibrarySection.artists => Icons.person_rounded,
        LibrarySection.songs => Icons.music_note_rounded,
        LibrarySection.playlists => Icons.queue_music_rounded,
        LibrarySection.genres => Icons.category_rounded,
      };

  IconData get outlinedIcon => switch (this) {
        LibrarySection.albums => Icons.album_outlined,
        LibrarySection.artists => Icons.person_outline_rounded,
        LibrarySection.songs => Icons.music_note_outlined,
        LibrarySection.playlists => Icons.queue_music_outlined,
        LibrarySection.genres => Icons.category_outlined,
      };
}
