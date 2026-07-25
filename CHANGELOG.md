# Changelog

All notable changes to JellyMusic, newest first. This project follows
[Semantic Versioning](https://semver.org).

## Unreleased

**Added**
- Desktop: a Spotify-style mini player — shrinks the window into a small,
  always-on-top compact bar (cover, title, transport), with a button to expand
  back to the full app. Available on X11, Windows and macOS (Wayland doesn't
  let a client control its own window geometry).
- Desktop: optional *close to tray* and *minimise to tray* (two independent
  settings under Settings → Playback → Desktop).
- CI now also builds a Windows installer (`.exe`, Inno Setup) and a Linux
  Flatpak bundle, alongside the existing portable archives.
- Collapsible desktop sidebar (icon-only mode), remembered across launches.
- Your favourite playlists are listed directly in the desktop sidebar.
- Favourite toggle on playlists, so the favourites filter applies to them too.
- Richer artist page: an "Appears on" section (guest spots / compilations,
  separate from the artist's own albums) and the artist biography.
- Recently played *tracks* shelf on the home screen.
- Standalone queue screen, reachable from the mini player (no longer buried in
  Now Playing) — reorder, remove and tap-to-jump.
- Desktop system tray with transport controls (play/pause, previous/next, show
  window, quit) and the current track shown in the menu.
- Native splash screen (Android/iOS) on the Nocturne background.
- In-tab search for albums, artists and songs; album search also matches by
  artist, not just the album name.
- Mouse-wheel volume control on the volume sliders.

**Changed**
- Desktop: the library categories (albums / artists / songs / playlists /
  genres / favourites) now live directly in the sidebar instead of in-page tabs.
- The A–Z rail now filters server-side by letter — scrolling stays within the
  chosen letter — with proper hover and active states.
- Redesigned the About screen (hero panel, version pill, grouped links).
- Localised the library sort menu, the sort/favourites filter tooltips and the
  fullscreen tooltip.

**Fixed**
- Album track lists now show the per-track artist on compilations and guest
  features; more robust artist fallback in the player, OS notification and
  search results.

**Removed**
- The separate library "Favourites" view — every list already carries a
  favourites filter, which covers it.

## v1.0.0 — 2026-07-25

Initial public release. Available on **Linux, Windows, macOS, Android and web**
from a single codebase; iOS ships separately via the App Store.

**Added**
- Multi-server login (password + Quick Connect) with multiple accounts.
- Library: albums / artists / songs / playlists / genres / favourites, with
  sort options, a favourites filter, infinite scroll and an A–Z jump rail on
  desktop.
- Home shelves: continue listening, recently played/added, most played,
  favourite albums/artists, a random pick.
- Responsive player: editable queue, synced/plain lyrics, volume + mute,
  favourite toggle, sleep timer. On mobile the queue shows inline and lyrics
  sit over a blurred cover; swipe the artwork to change track and swipe down
  to dismiss.
- Gapless playback (libmpv prefetch on desktop) and an optional crossfade.
- Casting to and from other Jellyfin clients with full state sync (track,
  position, play/pause, volume, shuffle/repeat).
- 12 light/dark themes in a tabbed picker, switchable at runtime and from the
  login screen.
- Playlist create/rename/delete/add/remove; Instant Mix radio.
- Background playback + OS media controls, Jellyfin scrobbling, HTTP response
  caching, German/English localization.
- Edge-swipe-back on pushed screens; settings grouped into Account / Playback /
  Appearance / About tabs; in-app update check via GitHub releases.
- Release automation: GitHub Actions builds every platform (except iOS),
  publishes the web app to GitHub Pages and a container image to ghcr, and a
  Docker Compose file runs that image.
