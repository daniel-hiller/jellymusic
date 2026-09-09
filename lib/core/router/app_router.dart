import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/library/album_detail_screen.dart';
import '../../features/library/artist_detail_screen.dart';
import '../../features/library/genre_detail_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/library/playlist_add_songs_screen.dart';
import '../../features/library/playlist_detail_screen.dart';
import '../../features/player/mini_window.dart';
import '../../features/player/now_playing_screen.dart';
import '../../features/player/queue_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/splash_screen.dart';
import '../../providers/providers.dart';
import '../../widgets/swipe_back.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// The app's router. Redirects on auth state and hosts the three-tab
/// stateful shell. Album/artist detail routes live *inside* each branch so
/// the back stack and bottom nav stay correct.
final routerProvider = Provider<GoRouter>((ref) {
  // Bump a listenable whenever auth changes so redirect re-evaluates.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading) return loc == '/splash' ? null : '/splash';

      final loggedIn = auth.value != null;

      if (!loggedIn) {
        // /add-account doubles as the first-login form when logged out.
        return (loc == '/login' || loc == '/add-account') ? null : '/login';
      }
      // Logged in: keep users off the auth gate, but allow /add-account so a
      // second server can be added without logging the first one out.
      if (loc == '/login' || loc == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/add-account',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SwipeBack(child: LoginScreen(addMode: true)),
      ),
      GoRoute(
        path: '/now-playing',
        parentNavigatorKey: _rootKey, // full-screen, above the shell
        pageBuilder: (_, __) => const MaterialPage(
          fullscreenDialog: true,
          child: NowPlayingScreen(),
        ),
      ),
      GoRoute(
        path: '/queue',
        parentNavigatorKey: _rootKey, // above the shell, reachable everywhere
        builder: (_, __) => const SwipeBack(child: QueueScreen()),
      ),
      GoRoute(
        path: '/mini',
        parentNavigatorKey: _rootKey, // compact window, above everything
        builder: (_, __) => const MiniPlayerWindow(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'album/:id',
                    builder: (_, s) => SwipeBack(
                        child: AlbumDetailScreen(
                            albumId: s.pathParameters['id']!)),
                  ),
                  GoRoute(
                    path: 'artist/:id',
                    builder: (_, s) => SwipeBack(
                        child: ArtistDetailScreen(
                            artistId: s.pathParameters['id']!)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, __) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'album/:id',
                    builder: (_, s) => SwipeBack(
                        child: AlbumDetailScreen(
                            albumId: s.pathParameters['id']!)),
                  ),
                  GoRoute(
                    path: 'artist/:id',
                    builder: (_, s) => SwipeBack(
                        child: ArtistDetailScreen(
                            artistId: s.pathParameters['id']!)),
                  ),
                  GoRoute(
                    path: 'playlist/:id',
                    builder: (_, s) => SwipeBack(
                        child: PlaylistDetailScreen(
                            playlistId: s.pathParameters['id']!)),
                    routes: [
                      GoRoute(
                        path: 'add',
                        builder: (_, s) => SwipeBack(
                            child: PlaylistAddSongsScreen(
                                playlistId: s.pathParameters['id']!)),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'genre/:id',
                    builder: (_, s) => SwipeBack(
                        child: GenreDetailScreen(
                            genreId: s.pathParameters['id']!)),
                    routes: [
                      GoRoute(
                        path: 'album/:albumId',
                        builder: (_, s) => SwipeBack(
                            child: AlbumDetailScreen(
                                albumId: s.pathParameters['albumId']!)),
                      ),
                      GoRoute(
                        path: 'artist/:artistId',
                        builder: (_, s) => SwipeBack(
                            child: ArtistDetailScreen(
                                artistId: s.pathParameters['artistId']!)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (_, __) => const SearchScreen(),
                routes: [
                  GoRoute(
                    path: 'album/:id',
                    builder: (_, s) => SwipeBack(
                        child: AlbumDetailScreen(
                            albumId: s.pathParameters['id']!)),
                  ),
                  GoRoute(
                    path: 'artist/:id',
                    builder: (_, s) => SwipeBack(
                        child: ArtistDetailScreen(
                            artistId: s.pathParameters['id']!)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
