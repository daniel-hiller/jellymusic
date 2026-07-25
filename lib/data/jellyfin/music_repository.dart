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

  /// All albums, paged and sorted. Set [favoritesOnly] to filter to favourites.
  Future<JellyfinQueryResult<JellyfinItem>> albums({
    int startIndex = 0,
    int limit = 100,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
  }) {
    return _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      sortBy: sortBy,
      descending: descending,
      filters: favoritesOnly ? const ['IsFavorite'] : const [],
      startIndex: startIndex,
      limit: limit,
    );
  }

  /// All artists, paged and sorted.
  Future<JellyfinQueryResult<JellyfinItem>> artists({
    int startIndex = 0,
    int limit = 100,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
  }) {
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
  }) {
    return _c.items.list(
      includeItemTypes: const [JellyfinItemKind.audio],
      sortBy: sortBy,
      descending: descending,
      filters: favoritesOnly ? const ['IsFavorite'] : const [],
      startIndex: startIndex,
      limit: limit,
    );
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

  /// The albums belonging to an artist.
  Future<List<JellyfinItem>> artistAlbums(String artistId) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      artistIds: artistId,
      sortBy: const ['PremiereDate', 'SortName'],
      descending: true,
      limit: 200,
    );
    return res.items;
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
