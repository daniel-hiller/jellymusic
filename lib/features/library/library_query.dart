import 'package:flutter/foundation.dart';

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
  });

  final String sortField;
  final bool descending;
  final bool favoritesOnly;

  LibraryQuery copyWith({
    String? sortField,
    bool? descending,
    bool? favoritesOnly,
  }) {
    return LibraryQuery(
      sortField: sortField ?? this.sortField,
      descending: descending ?? this.descending,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      other.sortField == sortField &&
      other.descending == descending &&
      other.favoritesOnly == favoritesOnly;

  @override
  int get hashCode => Object.hash(sortField, descending, favoritesOnly);
}

/// Sort menus per browsable type.
abstract final class SortOptions {
  static const albums = [
    SortOption('Name', 'SortName'),
    SortOption('Künstler', 'AlbumArtist'),
    SortOption('Jahr', 'ProductionYear'),
    SortOption('Zuletzt hinzugefügt', 'DateCreated'),
    SortOption('Zufällig', 'Random'),
  ];

  static const artists = [
    SortOption('Name', 'SortName'),
    SortOption('Zufällig', 'Random'),
  ];

  static const songs = [
    SortOption('Titel', 'SortName'),
    SortOption('Album', 'Album'),
    SortOption('Künstler', 'Artist'),
    SortOption('Zuletzt hinzugefügt', 'DateCreated'),
    SortOption('Zufällig', 'Random'),
  ];

  static const playlists = [
    SortOption('Name', 'SortName'),
    SortOption('Zuletzt hinzugefügt', 'DateCreated'),
  ];
}
