import 'package:dart_jellyfin/dart_jellyfin.dart';

import 'jellyfin_service.dart';

/// Narrows a list read to items the user has (not) listened to.
enum PlayedState { any, played, unplayed }

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
  Future<List<JellyfinItem>> recentlyAdded({
    int limit = 20,
    String? parentId,
  }) {
    return _c.items.latest(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      parentId: parentId,
      limit: limit,
    );
  }

  /// "Jump back in" — albums/tracks with a saved playback position.
  Future<List<JellyfinItem>> continueListening({
    int limit = 20,
    String? parentId,
  }) async {
    final res = await _c.items.resume(
      mediaTypes: const ['Audio'],
      parentId: parentId,
      limit: limit,
    );
    return res.items;
  }

  /// Recently played albums (most recent first).
  Future<List<JellyfinItem>> recentlyPlayedAlbums({
    int limit = 20,
    String? parentId,
  }) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      parentId: parentId,
      sortBy: const ['DatePlayed'],
      descending: true,
      filters: const ['IsPlayed'],
      limit: limit,
    );
    return res.items;
  }

  /// Recently played individual tracks (not grouped into albums).
  Future<List<JellyfinItem>> recentlyPlayedTracks({
    int limit = 20,
    String? parentId,
  }) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.audio],
      parentId: parentId,
      sortBy: const ['DatePlayed'],
      descending: true,
      filters: const ['IsPlayed'],
      limit: limit,
    );
    return res.items;
  }

  /// Most-played albums.
  Future<List<JellyfinItem>> mostPlayedAlbums({
    int limit = 20,
    String? parentId,
  }) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      parentId: parentId,
      sortBy: const ['PlayCount'],
      descending: true,
      filters: const ['IsPlayed'],
      limit: limit,
    );
    return res.items;
  }

  /// Favourite albums.
  Future<List<JellyfinItem>> favoriteAlbums({
    int limit = 20,
    String? parentId,
  }) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      parentId: parentId,
      sortBy: const ['SortName'],
      filters: const ['IsFavorite'],
      limit: limit,
    );
    return res.items;
  }

  /// Favourite artists.
  Future<List<JellyfinItem>> favoriteArtists({
    int limit = 20,
    String? parentId,
  }) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicArtist],
      parentId: parentId,
      sortBy: const ['SortName'],
      filters: const ['IsFavorite'],
      limit: limit,
    );
    return res.items;
  }

  /// A random album selection — always has something to show.
  Future<List<JellyfinItem>> randomAlbums({
    int limit = 20,
    String? parentId,
  }) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
      parentId: parentId,
      sortBy: const ['Random'],
      limit: limit,
    );
    return res.items;
  }

  /// Server-curated picks for the current user ("For you").
  Future<List<JellyfinItem>> suggestions({int limit = 20}) async {
    final res = await _c.suggestions.list(
      mediaType: const ['Audio'],
      limit: limit,
    );
    return res.items;
  }

  /// Artists the server considers related to [artistId]. Empty on servers
  /// without the metadata to back it.
  Future<List<JellyfinItem>> similarArtists(String artistId,
      {int limit = 12}) async {
    final res = await _c.library.similarArtists(itemId: artistId, limit: limit);
    return res.items;
  }

  /// Albums the server considers related to [albumId].
  Future<List<JellyfinItem>> similarAlbums(String albumId,
      {int limit = 12}) async {
    final res = await _c.library.similarAlbums(itemId: albumId, limit: limit);
    return res.items;
  }

  // ─── Browsable lists ───────────────────────────────────────────────

  /// All albums, paged, sorted and filtered.
  Future<JellyfinQueryResult<JellyfinItem>> albums({
    int startIndex = 0,
    int limit = 100,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
    String? startLetter,
    String searchTerm = '',
    String? parentId,
    PlayedState playedState = PlayedState.any,
    List<String> genreIds = const [],
    List<int> years = const [],
  }) {
    if (searchTerm.isNotEmpty) {
      // Match on the album name *and* the artist, so typing an artist finds
      // their albums (plain searchTerm on MusicAlbum only hits the album name).
      return _albumsMatching(
        searchTerm,
        sortBy: sortBy,
        descending: descending,
        favoritesOnly: favoritesOnly,
        parentId: parentId,
        playedState: playedState,
        genreIds: genreIds,
        years: years,
      );
    }
    return _items(
      JellyfinItemKind.musicAlbum,
      startIndex: startIndex,
      limit: limit,
      sortBy: sortBy,
      descending: descending,
      favoritesOnly: favoritesOnly,
      startLetter: startLetter,
      parentId: parentId,
      playedState: playedState,
      genreIds: genreIds,
      years: years,
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
    required String? parentId,
    required PlayedState playedState,
    required List<String> genreIds,
    required List<int> years,
  }) async {
    final byName = await _items(
      JellyfinItemKind.musicAlbum,
      sortBy: sortBy,
      descending: descending,
      favoritesOnly: favoritesOnly,
      parentId: parentId,
      playedState: playedState,
      genreIds: genreIds,
      years: years,
      searchTerm: term,
      limit: 100,
    );
    final matchedArtists = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicArtist],
      parentId: parentId,
      searchTerm: term,
      limit: 20,
    );
    final artistIds = [for (final a in matchedArtists.items) a.id];
    var byArtist = const <JellyfinItem>[];
    if (artistIds.isNotEmpty) {
      final res = await _items(
        JellyfinItemKind.musicAlbum,
        sortBy: sortBy,
        descending: descending,
        favoritesOnly: favoritesOnly,
        parentId: parentId,
        playedState: playedState,
        genreIds: genreIds,
        years: years,
        artistIds: artistIds.join(','),
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

  /// All artists, paged, sorted and filtered.
  Future<JellyfinQueryResult<JellyfinItem>> artists({
    int startIndex = 0,
    int limit = 100,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
    String? startLetter,
    String searchTerm = '',
    String? parentId,
    PlayedState playedState = PlayedState.any,
    List<String> genreIds = const [],
    List<int> years = const [],
  }) {
    return _items(
      JellyfinItemKind.musicArtist,
      startIndex: startIndex,
      limit: limit,
      sortBy: sortBy,
      descending: descending,
      favoritesOnly: favoritesOnly,
      startLetter: startLetter,
      searchTerm: searchTerm,
      parentId: parentId,
      playedState: playedState,
      genreIds: genreIds,
      years: years,
    );
  }

  /// All tracks, paged, sorted and filtered — backs the library's "Titel" tab.
  Future<JellyfinQueryResult<JellyfinItem>> songs({
    int startIndex = 0,
    int limit = 200,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
    String? startLetter,
    String searchTerm = '',
    String? parentId,
    PlayedState playedState = PlayedState.any,
    List<String> genreIds = const [],
    List<int> years = const [],
  }) {
    return _items(
      JellyfinItemKind.audio,
      startIndex: startIndex,
      limit: limit,
      sortBy: sortBy,
      descending: descending,
      favoritesOnly: favoritesOnly,
      startLetter: startLetter,
      searchTerm: searchTerm,
      parentId: parentId,
      playedState: playedState,
      genreIds: genreIds,
      years: years,
    );
  }

  /// One page of a single item kind with the library filters applied.
  ///
  /// The typed `items.list` covers most of the query, but `nameStartsWith`
  /// (the A–Z rail) and `years` (the decade filter) only exist on the raw
  /// `/Items` endpoint — either of them routes the same parameters through
  /// [_rawItems] instead.
  Future<JellyfinQueryResult<JellyfinItem>> _items(
    String includeItemType, {
    int startIndex = 0,
    int? limit,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
    PlayedState playedState = PlayedState.any,
    String? startLetter,
    String searchTerm = '',
    String? parentId,
    List<String> genreIds = const [],
    List<int> years = const [],
    String? artistIds,
  }) {
    // A text search and an A–Z letter are mutually exclusive; search wins.
    final letter = searchTerm.isEmpty ? startLetter : null;
    final filters = _filters(favoritesOnly, playedState);
    if (letter != null || years.isNotEmpty) {
      return _rawItems(
        includeItemType,
        startIndex: startIndex,
        limit: limit,
        sortBy: sortBy,
        descending: descending,
        filters: filters,
        startLetter: letter,
        searchTerm: searchTerm,
        parentId: parentId,
        genreIds: genreIds,
        years: years,
        artistIds: artistIds,
      );
    }
    return _c.items.list(
      includeItemTypes: [includeItemType],
      parentId: parentId,
      sortBy: sortBy,
      descending: descending,
      filters: filters,
      genreIds: genreIds.isEmpty ? null : genreIds.join(','),
      artistIds: artistIds,
      searchTerm: searchTerm.isEmpty ? null : searchTerm,
      startIndex: startIndex,
      limit: limit,
    );
  }

  /// The raw-`/Items` twin of [_items]. `nameStartsWith` is used (not
  /// `…OrGreater`) so scrolling stays within the letter instead of bleeding
  /// into the rest of the alphabet.
  Future<JellyfinQueryResult<JellyfinItem>> _rawItems(
    String includeItemType, {
    required int startIndex,
    required int? limit,
    required List<String> sortBy,
    required bool descending,
    required List<String> filters,
    required String? startLetter,
    required String searchTerm,
    required String? parentId,
    required List<String> genreIds,
    required List<int> years,
    required String? artistIds,
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
        if (filters.isNotEmpty) 'filters': filters.join(','),
        'startIndex': startIndex,
        if (limit != null) 'limit': limit,
        if (startLetter != null) 'nameStartsWith': startLetter,
        if (searchTerm.isNotEmpty) 'searchTerm': searchTerm,
        if (parentId != null) 'parentId': parentId,
        if (genreIds.isNotEmpty) 'genreIds': genreIds.join(','),
        if (years.isNotEmpty) 'years': years.join(','),
        if (artistIds != null) 'artistIds': artistIds,
        'fields': JellyfinItemsApi.musicFields.join(','),
      },
    );
    return JellyfinQueryResult.fromJson(
        res.data ?? const {}, JellyfinItem.fromJson);
  }

  /// The Jellyfin `filters` values for the favourite and played toggles.
  static List<String> _filters(bool favoritesOnly, PlayedState playedState) => [
        if (favoritesOnly) 'IsFavorite',
        if (playedState == PlayedState.played) 'IsPlayed',
        if (playedState == PlayedState.unplayed) 'IsUnplayed',
      ];

  /// The album production years present in the library, newest first — the
  /// source for the decade filter. `/Items/Filters` answers this as a facet,
  /// so it costs one small request instead of a sweep over every album.
  Future<List<int>> years({String? parentId}) async {
    final facets = await _c.filter.legacy(
      parentId: parentId,
      includeItemTypes: const [JellyfinItemKind.musicAlbum],
    );
    return facets.years.toSet().toList()..sort((a, b) => b.compareTo(a));
  }

  // ─── Playlists ─────────────────────────────────────────────────────

  /// All playlists, paged and sorted.
  ///
  /// Playlists live in their own library, so [parentId] is only honoured when
  /// a caller genuinely wants to scope to a folder — the music-view selection
  /// does not apply here.
  Future<JellyfinQueryResult<JellyfinItem>> playlists({
    int startIndex = 0,
    int limit = 200,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
    String? startLetter,
    String searchTerm = '',
    String? parentId,
    PlayedState playedState = PlayedState.any,
    List<String> genreIds = const [],
    List<int> years = const [],
  }) {
    return _items(
      JellyfinItemKind.playlist,
      startIndex: startIndex,
      limit: limit,
      sortBy: sortBy,
      descending: descending,
      favoritesOnly: favoritesOnly,
      startLetter: startLetter,
      searchTerm: searchTerm,
      parentId: parentId,
      playedState: playedState,
      genreIds: genreIds,
      years: years,
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

  /// Move the entry [entryId] (a `PlaylistItemId`) to [newIndex].
  Future<void> movePlaylistItem(
      String playlistId, String entryId, int newIndex) async {
    await _c.playlists.moveItem(
      playlistId: playlistId,
      playlistItemId: entryId,
      newIndex: newIndex,
    );
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
  Future<List<JellyfinItem>> favoriteSongs({
    int limit = 200,
    String? parentId,
  }) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.audio],
      parentId: parentId,
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

  /// Music genres, paged and sorted. `/MusicGenres` narrows by name, parent
  /// and favourite only, so the track-level filters do not apply here; the
  /// typed genre list has no sort-order parameter, hence the raw request.
  Future<JellyfinQueryResult<JellyfinItem>> genres({
    int startIndex = 0,
    int limit = 500,
    List<String> sortBy = const ['SortName'],
    bool descending = false,
    bool favoritesOnly = false,
    String? startLetter,
    String searchTerm = '',
    String? parentId,
    PlayedState playedState = PlayedState.any,
    List<String> genreIds = const [],
    List<int> years = const [],
  }) async {
    final letter = searchTerm.isEmpty ? startLetter : null;
    final res = await _c.request<Map<String, dynamic>>(
      '/MusicGenres',
      queryParameters: {
        'userId': _c.userId,
        'enableImages': true,
        'enableUserData': true,
        'enableTotalRecordCount': true,
        if (sortBy.isNotEmpty) 'sortBy': sortBy.join(','),
        'sortOrder': descending ? 'Descending' : 'Ascending',
        if (favoritesOnly) 'isFavorite': true,
        'startIndex': startIndex,
        'limit': limit,
        if (letter != null) 'nameStartsWith': letter,
        if (searchTerm.isNotEmpty) 'searchTerm': searchTerm,
        if (parentId != null) 'parentId': parentId,
        'fields': JellyfinItemsApi.musicFields.join(','),
      },
    );
    return JellyfinQueryResult.fromJson(
        res.data ?? const {}, JellyfinItem.fromJson);
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

  /// Artists that have music in a genre.
  Future<List<JellyfinItem>> genreArtists(String genreId,
      {int limit = 200}) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.musicArtist],
      genreIds: genreId,
      sortBy: const ['SortName'],
      limit: limit,
    );
    return res.items;
  }

  /// Tracks tagged with a genre.
  Future<List<JellyfinItem>> genreTracks(String genreId,
      {int limit = 200}) async {
    final res = await _c.items.list(
      includeItemTypes: const [JellyfinItemKind.audio],
      genreIds: genreId,
      sortBy: const ['SortName'],
      limit: limit,
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

  // ─── Favourites & played state ─────────────────────────────────────

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

  /// Mark an item played or unplayed.
  Future<void> setPlayed(String itemId, bool played) async {
    if (played) {
      await _c.userData.markPlayed(itemId);
    } else {
      await _c.userData.markUnplayed(itemId);
    }
    await _service.clearCache();
  }
}
