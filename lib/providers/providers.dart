import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../core/audio/audio_player_handler.dart';
import '../data/jellyfin/auth_repository.dart';
import '../data/jellyfin/resilient_secure_storage.dart';
import '../data/jellyfin/jellyfin_service.dart';
import '../data/jellyfin/music_repository.dart';
import '../data/models/server_session.dart';
import '../features/library/library_query.dart';

// ─── Infrastructure (overridden in main.dart with real instances) ────

final secureStorageProvider = Provider<ResilientSecureStorage>(
  (_) => throw UnimplementedError('override in main()'),
);

final jellyfinServiceProvider = Provider<JellyfinService>(
  (_) => throw UnimplementedError('override in main()'),
);

final audioHandlerProvider = Provider<AudioPlayerHandler>(
  (_) => throw UnimplementedError('override in main()'),
);

// ─── Repositories ────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(jellyfinServiceProvider),
    ref.watch(secureStorageProvider),
  );
});

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return MusicRepository(ref.watch(jellyfinServiceProvider));
});

// ─── Auth state ──────────────────────────────────────────────────────

final authControllerProvider =
    AsyncNotifierProvider<AuthController, ServerSession?>(AuthController.new);

class AuthController extends AsyncNotifier<ServerSession?> {
  @override
  Future<ServerSession?> build() {
    return ref.read(authRepositoryProvider).restoreSession();
  }

  Future<void> login({
    required String server,
    required String username,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(
            baseUrl: server,
            username: username,
            password: password,
          ),
    );
    ref.invalidate(savedAccountsProvider);
  }

  /// Log out the active account; if another remains it becomes active.
  Future<void> logout() async {
    final next = await ref.read(authRepositoryProvider).logout();
    state = AsyncData(next);
    ref.invalidate(savedAccountsProvider);
  }

  /// Finalise a Quick Connect login once the attempt has been approved.
  Future<void> completeQuickConnect(String secret) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).quickConnectComplete(secret),
    );
    ref.invalidate(savedAccountsProvider);
  }

  /// Switch the active account to a different saved server/user.
  Future<void> switchServer(ServerSession session) async {
    if (session.key == state.value?.key) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).switchTo(session),
    );
    ref.invalidate(savedAccountsProvider);
  }
}

/// All saved accounts (users across servers) for the switcher UI.
///
/// Deliberately does NOT watch [authControllerProvider] — the controller
/// invalidates this provider on login/logout/switch, and watching it back
/// would form a dependency cycle.
final savedAccountsProvider = FutureProvider<List<ServerSession>>((ref) {
  return ref.watch(authRepositoryProvider).sessions();
});

/// `true` once a session is present — the router redirects on this.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).value != null;
});

// ─── Library data ────────────────────────────────────────────────────

/// Re-fetches whenever the logged-in user changes.
final _sessionUserId = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).value?.userId;
});

final musicViewsProvider = FutureProvider<List<JellyfinView>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).musicViews();
});

final recentlyAddedProvider = FutureProvider<List<JellyfinItem>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).recentlyAdded();
});

final continueListeningProvider = FutureProvider<List<JellyfinItem>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).continueListening();
});

final recentlyPlayedProvider = FutureProvider<List<JellyfinItem>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).recentlyPlayedAlbums();
});

final recentlyPlayedTracksProvider =
    FutureProvider<List<JellyfinItem>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).recentlyPlayedTracks();
});

final mostPlayedProvider = FutureProvider<List<JellyfinItem>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).mostPlayedAlbums();
});

final favoriteAlbumsProvider = FutureProvider<List<JellyfinItem>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).favoriteAlbums();
});

final favoriteArtistsProvider = FutureProvider<List<JellyfinItem>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).favoriteArtists();
});

final randomAlbumsProvider = FutureProvider<List<JellyfinItem>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).randomAlbums();
});

// ─── Per-tab browsing state (sort field, direction, favourites filter) ─

final albumsQueryProvider = StateProvider<LibraryQuery>(
    (_) => const LibraryQuery(sortField: 'SortName'));
final artistsQueryProvider = StateProvider<LibraryQuery>(
    (_) => const LibraryQuery(sortField: 'SortName'));
final songsQueryProvider = StateProvider<LibraryQuery>(
    (_) => const LibraryQuery(sortField: 'SortName'));
final playlistsQueryProvider = StateProvider<LibraryQuery>(
    (_) => const LibraryQuery(sortField: 'SortName'));

final albumsProvider = FutureProvider<List<JellyfinItem>>((ref) async {
  ref.watch(_sessionUserId);
  final q = ref.watch(albumsQueryProvider);
  final res = await ref.watch(musicRepositoryProvider).albums(
        sortBy: [q.sortField],
        descending: q.descending,
        favoritesOnly: q.favoritesOnly,
      );
  return res.items;
});

final artistsProvider = FutureProvider<List<JellyfinItem>>((ref) async {
  ref.watch(_sessionUserId);
  final q = ref.watch(artistsQueryProvider);
  final res = await ref.watch(musicRepositoryProvider).artists(
        sortBy: [q.sortField],
        descending: q.descending,
        favoritesOnly: q.favoritesOnly,
      );
  return res.items;
});

final favoriteSongsProvider = FutureProvider<List<JellyfinItem>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).favoriteSongs();
});

final songsProvider = FutureProvider<List<JellyfinItem>>((ref) async {
  ref.watch(_sessionUserId);
  final q = ref.watch(songsQueryProvider);
  final res = await ref.watch(musicRepositoryProvider).songs(
        sortBy: [q.sortField],
        descending: q.descending,
        favoritesOnly: q.favoritesOnly,
      );
  return res.items;
});

// ─── Playlists ───────────────────────────────────────────────────────

final playlistsProvider = FutureProvider<List<JellyfinItem>>((ref) async {
  ref.watch(_sessionUserId);
  final q = ref.watch(playlistsQueryProvider);
  final res = await ref.watch(musicRepositoryProvider).playlists(
        sortBy: [q.sortField],
        descending: q.descending,
        favoritesOnly: q.favoritesOnly,
      );
  return res.items;
});

/// Favourite playlists only — used for the quick list in the desktop sidebar.
final favoritePlaylistsProvider = FutureProvider<List<JellyfinItem>>((ref) async {
  ref.watch(_sessionUserId);
  final res = await ref
      .watch(musicRepositoryProvider)
      .playlists(favoritesOnly: true);
  return res.items;
});

/// A playlist's item + its tracks.
final playlistDetailProvider =
    FutureProvider.family<PlaylistDetail, String>((ref, playlistId) async {
  ref.watch(_sessionUserId);
  final repo = ref.watch(musicRepositoryProvider);
  final results = await Future.wait([
    repo.itemById(playlistId),
    repo.playlistTracks(playlistId),
  ]);
  return PlaylistDetail(
    playlist: results[0] as JellyfinItem?,
    tracks: results[1] as List<JellyfinItem>,
  );
});

class PlaylistDetail {
  final JellyfinItem? playlist;
  final List<JellyfinItem> tracks;
  const PlaylistDetail({required this.playlist, required this.tracks});
}

/// Album detail (the album item + its tracks).
final albumDetailProvider =
    FutureProvider.family<AlbumDetail, String>((ref, albumId) async {
  final repo = ref.watch(musicRepositoryProvider);
  final results = await Future.wait([
    repo.itemById(albumId),
    repo.albumTracks(albumId),
  ]);
  return AlbumDetail(
    album: results[0] as JellyfinItem?,
    tracks: results[1] as List<JellyfinItem>,
  );
});

final artistAlbumsProvider =
    FutureProvider.family<List<JellyfinItem>, String>((ref, artistId) {
  return ref.watch(musicRepositoryProvider).artistAlbums(artistId);
});

/// Albums the artist only appears on, with their own albums removed so the two
/// sections never repeat the same record.
final artistAppearsOnProvider =
    FutureProvider.family<List<JellyfinItem>, String>((ref, artistId) async {
  final repo = ref.watch(musicRepositoryProvider);
  final own = await ref.watch(artistAlbumsProvider(artistId).future);
  final appears = await repo.artistAppearsOn(artistId);
  final ownIds = {for (final a in own) a.id};
  return [
    for (final a in appears)
      if (!ownIds.contains(a.id)) a,
  ];
});

final artistTopTracksProvider =
    FutureProvider.family<List<JellyfinItem>, String>((ref, artistId) {
  return ref.watch(musicRepositoryProvider).artistTopTracks(artistId);
});

/// An artist (or any item) by id — replaces the old hack of pulling the
/// artist name out of the album-detail provider.
final artistByIdProvider =
    FutureProvider.family<JellyfinItem?, String>((ref, id) {
  return ref.watch(musicRepositoryProvider).itemById(id);
});

// ─── Genres ──────────────────────────────────────────────────────────

final genresProvider = FutureProvider<List<JellyfinItem>>((ref) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).genres();
});

final genreAlbumsProvider =
    FutureProvider.family<List<JellyfinItem>, String>((ref, genreId) {
  ref.watch(_sessionUserId);
  return ref.watch(musicRepositoryProvider).genreAlbums(genreId);
});

/// Debounced-ish search: the UI sets the term, this fetches for it.
final searchTermProvider = StateProvider<String>((_) => '');

final searchResultsProvider = FutureProvider<List<JellyfinItem>>((ref) {
  final term = ref.watch(searchTermProvider);
  return ref.watch(musicRepositoryProvider).search(term);
});

class AlbumDetail {
  final JellyfinItem? album;
  final List<JellyfinItem> tracks;
  const AlbumDetail({required this.album, required this.tracks});
}

// ─── Lyrics ──────────────────────────────────────────────────────────

/// Timed (or plain) lyrics for a track; `null` when the server has none.
final lyricsProvider =
    FutureProvider.autoDispose.family<JellyfinLyrics?, String>((ref, itemId) {
  return ref.watch(musicRepositoryProvider).lyrics(itemId);
});

// ─── Favourite (per item, reactive) ──────────────────────────────────

/// The favourite flag for a single item, seeded from the server and
/// flipped optimistically by [FavoriteNotifier.toggle]. Keyed by item id so
/// the player, tiles and detail screens all stay in sync.
final favoriteProvider = AsyncNotifierProvider.autoDispose
    .family<FavoriteNotifier, bool, String>(FavoriteNotifier.new);

class FavoriteNotifier extends AsyncNotifier<bool> {
  // Riverpod 3 passes the family argument to the constructor.
  FavoriteNotifier(this.itemId);

  final String itemId;

  @override
  Future<bool> build() async {
    final item = await ref.watch(musicRepositoryProvider).itemById(itemId);
    return item?.isFavorite ?? false;
  }

  /// Flip the flag, updating the UI immediately and reverting on failure.
  Future<void> toggle() async {
    final current = state.value ?? false;
    final next = !current;
    state = AsyncData(next);
    try {
      await ref.read(musicRepositoryProvider).setFavorite(itemId, next);
    } catch (_) {
      state = AsyncData(current);
    }
  }
}
