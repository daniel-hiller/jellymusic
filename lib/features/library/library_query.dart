import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';

/// One selectable sort criterion: a human [label] and the Jellyfin
/// `sortBy` [field] it maps to.
@immutable
class SortOption {
  const SortOption(this.label, this.field);
  final String label;
  final String field;
}

/// The browsing state for a library list: which field to sort by, direction,
/// and whether to show favourites only. Held per tab in a `StateProvider`.
@immutable
class LibraryQuery {
  const LibraryQuery({
    required this.sortField,
    this.descending = false,
    this.favoritesOnly = false,
    this.startLetter,
    this.searchTerm = '',
  });

  final String sortField;
  final bool descending;
  final bool favoritesOnly;

  /// In-tab text search (server `searchTerm`). Empty = no search. A search and
  /// an A–Z letter are mutually exclusive — setting one clears the other.
  final String searchTerm;

  /// A–Z filter: when set, the list shows only items whose name starts with
  /// this letter (server `nameStartsWith`). Null shows the whole list. Pass
  /// `clearLetter: true` to reset it (e.g. on a sort change).
  final String? startLetter;

  LibraryQuery copyWith({
    String? sortField,
    bool? descending,
    bool? favoritesOnly,
    String? startLetter,
    bool clearLetter = false,
    String? searchTerm,
  }) {
    return LibraryQuery(
      sortField: sortField ?? this.sortField,
      descending: descending ?? this.descending,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      startLetter: clearLetter ? null : (startLetter ?? this.startLetter),
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      other.sortField == sortField &&
      other.descending == descending &&
      other.favoritesOnly == favoritesOnly &&
      other.startLetter == startLetter &&
      other.searchTerm == searchTerm;

  @override
  int get hashCode => Object.hash(
      sortField, descending, favoritesOnly, startLetter, searchTerm);
}

/// Sort menus per browsable type. Built with [AppLocalizations] so the labels
/// follow the app language (the `field` values are the fixed Jellyfin keys).
abstract final class SortOptions {
  static List<SortOption> albums(AppLocalizations l) => [
        SortOption(l.sortName, 'SortName'),
        SortOption(l.sortArtist, 'AlbumArtist'),
        SortOption(l.sortYear, 'ProductionYear'),
        SortOption(l.sortDateAdded, 'DateCreated'),
        SortOption(l.sortRandom, 'Random'),
      ];

  static List<SortOption> artists(AppLocalizations l) => [
        SortOption(l.sortName, 'SortName'),
        SortOption(l.sortRandom, 'Random'),
      ];

  static List<SortOption> songs(AppLocalizations l) => [
        SortOption(l.sortTitle, 'SortName'),
        SortOption(l.sortAlbum, 'Album'),
        SortOption(l.sortArtist, 'Artist'),
        SortOption(l.sortDateAdded, 'DateCreated'),
        SortOption(l.sortRandom, 'Random'),
      ];

  static List<SortOption> playlists(AppLocalizations l) => [
        SortOption(l.sortName, 'SortName'),
        SortOption(l.sortDateAdded, 'DateCreated'),
      ];
}
