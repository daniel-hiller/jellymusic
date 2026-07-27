# Changelog

All notable changes to JellyMusic, newest first. This project follows
[Semantic Versioning](https://semver.org).

## v1.2.0 — 2026-07-27

**Added**
- Filter any library list by **played state, genre and decade**, next to the
  existing favourites filter. Each tab offers only what the server can answer
  for it — genres, for instance, take neither.
- **Library switcher** for servers with more than one music library; everything
  from the home shelves to search scopes to the one you pick. Servers with a
  single music library see no change.
- Playlists and genres are now **paged like the other tabs**, with sort, in-tab
  search and the A–Z rail.
- Sort albums and songs by **play count**.
- Albums with several discs are **grouped per disc**.
- **Similar artists** on the artist page and **similar albums** on the album
  page. Both stay hidden when the server has nothing to offer — this needs
  metadata a plugin provides.
- A genre now lists its **artists and tracks**, not only its albums.
- **Reorder playlist tracks** by dragging.
- A **"For you"** shelf on the home screen, from the server's own suggestions.
- **Save the queue as a playlist**, and clear it.
- **Mark tracks played or unplayed** from the song menu.
- Optional **volume levelling** from Jellyfin's ReplayGain values, per track or
  per album (Settings → Playback → Audio). Off by default.

**Changed**
- **Crossfade now really overlaps.** The setting used to fade one track out and
  the next one in with a gap of silence between them; a second decoder now
  carries the outgoing tail while the next track is already playing. Gapless
  playback at a crossfade of zero is untouched and remains the default.
- **Playback negotiates with the server through a device profile.** A quality
  cap used to force a transcode on every track, even one already below the cap —
  and files were transcoded even with no cap set at all. The server now decides
  per track, so anything your client can play directly is streamed untouched.
  What actually happened is reported back, so the Jellyfin dashboard shows
  direct play and transcoding correctly.

**Fixed**
- The **Shuffle** button on albums, artists and playlists toggled shuffle
  instead of switching it on — pressing it while shuffle was already active
  turned it off and played in order.
- Skipping to the next track could **hang indefinitely** while a fade was
  running, because a ramp cancelled by a competing one never completed.
- A transport button pressed during a track change no longer answers with a
  multi-second ramp.

## v1.1.2 — 2026-07-26

**Changed**
- Licensed under **AGPL-3.0** — anyone hosting a modified version over a network
  must offer its source. A license link was added to the About screen.

**Fixed**
- Desktop (Linux / Windows / macOS): JellyMusic now runs as a **single
  instance** — launching it again focuses the already-open window instead of
  starting a second copy. (macOS was already single-instance via Launch
  Services; Linux and Windows now match.)

## v1.1.1 — 2026-07-26

**Added**
- Linux **`.deb` and `.rpm`** packages (built by CI, attached to each release).

**Fixed**
- Linux: no longer crashes at launch when the OS keyring is locked or missing —
  secure storage falls back to `shared_preferences` (this affects desktops that
  don't auto-unlock the login keyring on sign-in, e.g. COSMIC).
- Linux: the packaged desktop entry and icon now use the application id
  (`com.jellymusic.app`), so the running window maps to the right icon and no
  duplicate menu entry appears.

**Removed**
- The Flatpak build — bundling every system library the plugins hard-link
  (libmpv, libsecret, the whole Ayatana tray stack) proved too fragile to
  maintain; the `.deb`/`.rpm` link the host's libraries instead.

## v1.1.0 — 2026-07-26

**Added**
- Desktop: a Spotify-style mini player — shrinks the window into a small,
  always-on-top compact bar (cover, title, transport), with a button to expand
  back to the full app. Available on X11, Windows and macOS (Wayland doesn't
  let a client control its own window geometry).
- Desktop: optional *close to tray* and *minimise to tray* (two independent
  settings under Settings → Appearance → Desktop).
- CI now also builds a Windows installer (`.exe`, Inno Setup), alongside the
  existing portable archives.
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
