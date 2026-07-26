import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../providers/providers.dart';
import 'library_query.dart';

/// The three infinitely-scrolling library lists.
enum LibraryKind { albums, artists, songs }

/// One page-window of a library list.
class PagedState {
  const PagedState({
    this.items = const [],
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<JellyfinItem> items;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;

  PagedState copyWith({
    List<JellyfinItem>? items,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
  }) =>
      PagedState(
        items: items ?? this.items,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
      );
}

/// Lazily loads a library list in pages, appending as the user scrolls.
/// Resets and reloads the first page whenever the tab's [LibraryQuery] (sort /
/// direction / favourites filter) or the active account changes.
final pagedLibraryProvider = NotifierProvider.autoDispose
    .family<PagedLibrary, PagedState, LibraryKind>(PagedLibrary.new);

/// The per-tab sort/filter/letter state provider for [kind]. Exposed so the
/// A–Z rail can set `startLetter` on the right tab.
StateProvider<LibraryQuery> queryProviderFor(LibraryKind kind) => switch (kind) {
      LibraryKind.albums => albumsQueryProvider,
      LibraryKind.artists => artistsQueryProvider,
      LibraryKind.songs => songsQueryProvider,
    };

class PagedLibrary extends Notifier<PagedState> {
  // Riverpod 3 passes the family argument to the notifier's constructor
  // instead of to `build`.
  PagedLibrary(this.arg);

  final LibraryKind arg;

  static const _pageSize = 60;
  bool _busy = false;

  StateProvider<LibraryQuery> get _queryProvider => queryProviderFor(arg);

  @override
  PagedState build() {
    // Depend on the query, the chosen library and the account so a change
    // rebuilds and reloads page 0.
    ref.watch(_queryProvider);
    ref.watch(activeMusicViewProvider);
    ref.watch(authControllerProvider);
    _busy = false;
    Future.microtask(_loadFirst);
    return const PagedState(loadingMore: true);
  }

  Future<JellyfinQueryResult<JellyfinItem>> _fetch(int start) {
    final repo = ref.read(musicRepositoryProvider);
    final q = ref.read(_queryProvider);
    final sortBy = [q.sortField];
    final parentId = ref.read(activeMusicViewProvider).value;
    return switch (arg) {
      LibraryKind.albums => repo.albums(
          startIndex: start,
          limit: _pageSize,
          sortBy: sortBy,
          descending: q.descending,
          favoritesOnly: q.favoritesOnly,
          startLetter: q.startLetter,
          searchTerm: q.searchTerm,
          parentId: parentId),
      LibraryKind.artists => repo.artists(
          startIndex: start,
          limit: _pageSize,
          sortBy: sortBy,
          descending: q.descending,
          favoritesOnly: q.favoritesOnly,
          startLetter: q.startLetter,
          searchTerm: q.searchTerm,
          parentId: parentId),
      LibraryKind.songs => repo.songs(
          startIndex: start,
          limit: _pageSize,
          sortBy: sortBy,
          descending: q.descending,
          favoritesOnly: q.favoritesOnly,
          startLetter: q.startLetter,
          searchTerm: q.searchTerm,
          parentId: parentId),
    };
  }

  Future<void> _loadFirst() async {
    if (_busy) return;
    _busy = true;
    try {
      final res = await _fetch(0);
      state = PagedState(
        items: res.items,
        hasMore: res.items.length < res.totalRecordCount,
        loadingMore: false,
      );
    } catch (e) {
      state = PagedState(loadingMore: false, hasMore: false, error: e);
    } finally {
      _busy = false;
    }
  }

  /// Fetch the next page and append it. Safe to call repeatedly while scrolling.
  Future<void> loadMore() async {
    if (_busy || !state.hasMore) return;
    _busy = true;
    state = state.copyWith(loadingMore: true);
    try {
      final res = await _fetch(state.items.length);
      final all = [...state.items, ...res.items];
      state = PagedState(
        items: all,
        hasMore: res.items.isNotEmpty && all.length < res.totalRecordCount,
        loadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    } finally {
      _busy = false;
    }
  }
}
