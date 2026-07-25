import 'package:dart_jellyfin/dart_jellyfin.dart';

import 'jellyfin_service.dart';

/// All music browsing/search/favourite reads flow through here so the UI
/// stays decoupled from the raw SDK. Every method scopes to `Audio` /
/// `MusicAlbum` / `MusicArtist` item kinds.
class MusicRepository {
  MusicRepository(this._service);

  final JellyfinService _service;
  JellyfinClient get _c => _service.client;

  /// The user's music libraries (usually one).
  Future<List<JellyfinView>> musicViews() async {
    final res = await _c.userViews.list();
    return res.items.where((v) => v.isMusic).toList();
  }

  /// Recently added albums — the home screen's hero row.
  Future<List<JellyfinItem>> recentlyAdded({int limit = 20}) {
    return _c.items.latest(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      limit: limit,
    );
  }

  /// "Jump back in" — albums/tracks with a saved playback position.
  Future<List<JellyfinItem>> continueListening({int limit = 20}) async {
    final res = await _c.items.resume(
      mediaTypes: const ['Audio'],
      limit: limit,
    );
    return res.items;
  }

  /// Recently played albums (most recent first).
  Future<List<JellyfinItem>> recentlyPlayedAlbums({int limit = 20}) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      sortBy: const ['DatePlayed'],
      descending: true,
      filters: const ['IsPlayed'],
      limit: limit,
    );
    return res.items;
  }

  /// Recently played individual tracks (not grouped into albums).
  Future<List<JellyfinItem>> recentlyPlayedTracks({int limit = 20}) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.audio],
      sortBy: const ['DatePlayed'],
      descending: true,
      filters: const ['IsPlayed'],
      limit: limit,
    );
    return res.items;
  }

  /// Most-played albums.
  Future<List<JellyfinItem>> mostPlayedAlbums({int limit = 20}) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      sortBy: const ['PlayCount'],
      descending: true,
      filters: const ['IsPlayed'],
      limit: limit,
    );
    return res.items;
  }

  /// Favourite albums.
  Future<List<JellyfinItem>> favoriteAlbums({int limit = 20}) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      sortBy: const ['SortName'],
      filters: const ['IsFavorite'],
      limit: limit,
    );
    return res.items;
  }

  /// Favourite artists.
  Future<List<JellyfinItem>> favoriteArtists({int limit = 20}) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicArtist],
      sortBy: const ['SortName'],
      filters: const ['IsFavorite'],
      limit: limit,
    );
    return res.items;
  }

  /// A random album selection — always has something to show.
  Future<List<JellyfinItem>> randomAlbums({int limit = 20}) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      sortBy: const ['Random'],
      limit: limit,
    );
    return res.items;
  }

  /// All albums, paged and sorted. Set [favoritesOnly] to filter to favourites;
  /// [startLetter] filters to that letter via the server.
  Future<JellyfinQueryResult<JellyfinItem>> albums({
    int startIndex = 0,
    int limit = 100,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
    String? startLetter,
    String searchTerm = '',
  }) {
    if (searchTerm.isNotEmpty) {
      // Match on the album name *and* the artist, so typing an artist finds
      // their albums (plain searchTerm on MusicAlbum only hits the album name).
      return _albumsMatching(searchTerm,
          sortBy: sortBy, descending: descending, favoritesOnly: favoritesOnly);
    }
    if (startLetter != null) {
      return _letterPage(JellyfinItemKind.musicAlbum, startLetter,
          startIndex: startIndex,
          limit: limit,
          sortBy: sortBy,
          descending: descending,
          favoritesOnly: favoritesOnly);
    }
    return _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      sortBy: sortBy,
      descending: descending,
      filters: favoritesOnly ? const ['IsFavorite'] : const [],
      startIndex: startIndex,
      limit: limit,
    );
  }

  /// Album search that matches the album name *and* the artist: runs the plain
  /// name search, resolves artists whose name matches, and unions in their
  /// albums. Returned as one un-paged result (search hits are already narrow),
  /// deduped by id, name matches first.
  Future<JellyfinQueryResult<JellyfinItem>> _albumsMatching(
    String term, {
    required List<String> sortBy,
    required bool descending,
    required bool favoritesOnly,
  }) async {
    final filters = favoritesOnly ? const ['IsFavorite'] : const <String>[];
    final byName = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      sortBy: sortBy,
      descending: descending,
      filters: filters,
      searchTerm: term,
      limit: 100,
    );
    final matchedArtists = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicArtist],
      searchTerm: term,
      limit: 20,
    );
    final artistIds = [for (final a in matchedArtists.items) a.id];
    var byArtist = const <JellyfinItem>[];
    if (artistIds.isNotEmpty) {
      final res = await _c.items.list(
        includeItemTypes: const [JellyfinItemKind.musicAlbum],
        artistIds: artistIds.join(','),
        sortBy: sortBy,
        descending: descending,
        filters: filters,
        limit: 100,
      );
      byArtist = res.items;
    }
    final seen = <String>{};
    final merged = [
      for (final a in [...byName.items, ...byArtist])
        if (seen.add(a.id)) a,
    ];
    return JellyfinQueryResult(
        items: merged, totalRecordCount: merged.length);
  }

  /// All artists, paged and sorted.
  Future<JellyfinQueryResult<JellyfinItem>> artists({
    int startIndex = 0,
    int limit = 100,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
    String? startLetter,
    String searchTerm = '',
  }) {
    if (searchTerm.isNotEmpty) {
      return _c.items.list(
        includeItemTypes: const [JellyfinItemKind.musicArtist],
        sortBy: sortBy,
        descending: descending,
        filters: favoritesOnly ? const ['IsFavorite'] : const [],
        searchTerm: searchTerm,
        startIndex: startIndex,
        limit: limit,
      );
    }
    if (startLetter != null) {
      return _letterPage(JellyfinItemKind.musicArtist, startLetter,
          startIndex: startIndex,
          limit: limit,
          sortBy: sortBy,
          descending: descending,
          favoritesOnly: favoritesOnly);
    }
    return _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicArtist],
      sortBy: sortBy,
      descending: descending,
      filters: favoritesOnly ? const ['IsFavorite'] : const [],
      startIndex: startIndex,
      limit: limit,
    );
  }

  /// All tracks, paged and sorted — backs the library's "Titel" tab.
  Future<JellyfinQueryResult<JellyfinItem>> songs({
    int startIndex = 0,
    int limit = 200,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
    String? startLetter,
    String searchTerm = '',
  }) {
    if (searchTerm.isNotEmpty) {
      return _c.items.list(
        includeItemTypes: const [JellyfinItemKind.audio],
        sortBy: sortBy,
        descending: descending,
        filters: favoritesOnly ? const ['IsFavorite'] : const [],
        searchTerm: searchTerm,
        startIndex: startIndex,
        limit: limit,
      );
    }
    if (startLetter != null) {
      return _letterPage(JellyfinItemKind.audio, startLetter,
          startIndex: startIndex,
          limit: limit,
          sortBy: sortBy,
          descending: descending,
          favoritesOnly: favoritesOnly);
    }
    return _c.items.list(
      includeItemTypes: const [JellyfinItemKind.audio],
      sortBy: sortBy,
      descending: descending,
      filters: favoritesOnly ? const ['IsFavorite'] : const [],
      startIndex: startIndex,
      limit: limit,
    );
  }

  /// A page of one item type whose name **starts with** [letter] — the A–Z
  /// filter. Uses `nameStartsWith` (not `…OrGreater`) so scrolling stays within
  /// the letter instead of bleeding into the rest of the alphabet. The typed
  /// `items.list` doesn't expose it, so this goes through the client's
  /// raw-request escape hatch, mirroring the params `list` sends.
  Future<JellyfinQueryResult<JellyfinItem>> _letterPage(
    String includeItemType,
    String letter, {
    required int startIndex,
    required int limit,
    required List<String> sortBy,
    required bool descending,
    required bool favoritesOnly,
  }) async {
    final res = await _c.request<Map<String, dynamic>>(
      '/Items',
      queryParameters: {
        'userId': _c.userId,
        'recursive': true,
        'enableImages': true,
        'enableUserData': true,
        'includeItemTypes': includeItemType,
        if (sortBy.isNotEmpty) 'sortBy': sortBy.join(','),
        'sortOrder': descending ? 'Descending' : 'Ascending',
        if (favoritesOnly) 'filters': 'IsFavorite',
        'startIndex': startIndex,
        'limit': limit,
        'nameStartsWith': letter,
        'fields': JellyfinItemsApi.musicFields.join(','),
      },
    );
    return JellyfinQueryResult.fromJson(
        res.data ?? const {}, JellyfinItem.fromJson);
  }

  // ─── Playlists ─────────────────────────────────────────────────────

  /// All playlists, sorted.
  Future<JellyfinQueryResult<JellyfinItem>> playlists({
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
    int limit = 200,
  }) {
    return _c.items.list(
      includeItemTypes: const [JellyfinItemKind.playlist],
      sortBy: sortBy,
      descending: descending,
      filters: favoritesOnly ? const ['IsFavorite'] : const [],
      limit: limit,
    );
  }

  /// A playlist's tracks, in playlist order. Each track's
  /// `raw['PlaylistItemId']` is the entry id needed to remove it.
  Future<List<JellyfinItem>> playlistTracks(String playlistId) async {
    final res = await _c.playlists.items(playlistId: playlistId);
    return res.items;
  }

  /// Create a playlist, optionally seeded with [itemIds]. Returns its id.
  Future<String> createPlaylist(String name, {List<String> itemIds = const []}) async {
    final item = await _c.playlists.create(name: name, itemIds: itemIds);
    await _service.clearCache();
    return item.id;
  }

  Future<void> addToPlaylist(String playlistId, List<String> itemIds) async {
    await _c.playlists.addItems(playlistId: playlistId, itemIds: itemIds);
    await _service.clearCache();
  }

  Future<void> removeFromPlaylist(String playlistId, List<String> entryIds) async {
    await _c.playlists.removeItems(playlistId: playlistId, entryIds: entryIds);
    await _service.clearCache();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _c.playlists.delete(playlistId);
    await _service.clearCache();
  }

  Future<void> renamePlaylist(String playlistId, String name) async {
    await _c.playlists.rename(playlistId: playlistId, name: name);
    await _service.clearCache();
  }

  /// The tracks of an album, in disc/track order.
  Future<List<JellyfinItem>> albumTracks(String albumId) async {
    final res = await _c.items.list(
      parentId: albumId,
      includeItemTypes: const [JellyfinItemKind.audio],
      sortBy: const ['ParentIndexNumber', 'IndexNumber', 'SortName'],
      limit: 500,
    );
    return res.items;
  }

  /// An artist's most-played tracks ("Popular").
  Future<List<JellyfinItem>> artistTopTracks(String artistId,
      {int limit = 5}) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.audio],
      artistIds: artistId,
      sortBy: const ['PlayCount', 'SortName'],
      descending: true,
      limit: limit,
    );
    return res.items;
  }

  /// The artist's own albums (where they're the album artist).
  Future<List<JellyfinItem>> artistAlbums(String artistId) =>
      _artistAlbumsBy('albumArtistIds', artistId);

  /// Albums the artist only *appears on* (guest spots, compilations) — i.e.
  /// they contributed tracks but aren't the album artist.
  Future<List<JellyfinItem>> artistAppearsOn(String artistId) =>
      _artistAlbumsBy('contributingArtistIds', artistId);

  /// Shared album query keyed by a Jellyfin artist filter param. The SDK's
  /// `list()` only exposes `artistIds`, so the album-artist / contributing
  /// split goes through the raw endpoint.
  Future<List<JellyfinItem>> _artistAlbumsBy(
      String artistParam, String artistId) async {
    final res = await _c.request<Map<String, dynamic>>(
      '/Items',
      queryParameters: {
        'userId': _c.userId,
        'recursive': true,
        'enableImages': true,
        'enableUserData': true,
        'includeItemTypes': JellyfinItemKind.musicAlbum,
        artistParam: artistId,
        'sortBy': 'PremiereDate,SortName',
        'sortOrder': 'Descending',
        'limit': 200,
        'fields': JellyfinItemsApi.musicFields.join(','),
      },
    );
    return JellyfinQueryResult.fromJson(
            res.data ?? const {}, JellyfinItem.fromJson)
        .items;
  }

  /// Favourite tracks.
  Future<List<JellyfinItem>> favoriteSongs({int limit = 200}) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.audio],
      filters: const ['IsFavorite'],
      sortBy: const ['SortName'],
      limit: limit,
    );
    return res.items;
  }

  /// A single item (album/artist/track) by id.
  Future<JellyfinItem?> itemById(String id) => _c.items.byId(id);

  /// Several items by id, in the order the ids were given.
  ///
  /// Used when another client casts to us: the `Play` command carries item ids
  /// only, and `/Items?ids=` answers in the server's sort order, not ours.
  Future<List<JellyfinItem>> itemsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final res = await _c.items.list(ids: ids, limit: ids.length);
    final byId = {for (final item in res.items) item.id: item};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// An "Instant Mix" (radio) seeded from any item — album, artist, song,
  /// playlist or genre. Returns the generated track list.
  Future<List<JellyfinItem>> instantMix(String itemId, {int limit = 200}) async {
    final res = await _c.instantMix.fromItem(itemId: itemId, limit: limit);
    return res.items;
  }

  // ─── Genres ────────────────────────────────────────────────────────

  /// All music genres, sorted by name.
  Future<List<JellyfinItem>> genres({int limit = 500}) async {
    final res = await _c.musicGenres.list(
      sortBy: const ['SortName'],
      limit: limit,
    );
    return res.items;
  }

  /// Albums tagged with a genre.
  Future<List<JellyfinItem>> genreAlbums(String genreId) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      genreIds: genreId,
      sortBy: const ['SortName'],
      limit: 300,
    );
    return res.items;
  }

  /// Search across the music library. Returns albums, artists and tracks
  /// mixed; the UI groups them by [JellyfinItem.type].
  Future<List<JellyfinItem>> search(String term, {int limit = 40}) async {
    if (term.trim().isEmpty) return const [];
    final res = await _c.items.list(
      searchTerm: term,
      includeItemTypes: const [
        JellyfinItemKind.audio,
        JellyfinItemKind.musicAlbum,
        JellyfinItemKind.musicArtist,
      ],
      limit: limit,
    );
    return res.items;
  }

  /// Lyrics for a track, or `null` when the server has none.
  Future<JellyfinLyrics?> lyrics(String itemId) => _c.lyrics.forItem(itemId);

  // ─── Favourites ────────────────────────────────────────────────────

  Future<bool> toggleFavorite(JellyfinItem item) async {
    final next = !item.isFavorite;
    await _c.userData.setFavorite(item.id, next);
    await _service.clearCache();
    return next;
  }

  /// Set the favourite flag for an item by id (used by the player, which
  /// only has the current track's id).
  Future<void> setFavorite(String itemId, bool isFavorite) async {
    await _c.userData.setFavorite(itemId, isFavorite);
    await _service.clearCache();
  }
}
