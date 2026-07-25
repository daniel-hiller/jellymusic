# Changelog

All notable changes to JellyMusic, newest first. This project follows
[Semantic Versioning](https://semver.org).

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
