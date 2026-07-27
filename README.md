<p align="center">
  <img src="packaging/jellymusic.png" alt="JellyMusic" width="128" />
</p>

<h1 align="center">JellyMusic</h1>

<p align="center">
  A modern, music-first Jellyfin client built with Flutter — sleek, theme-able,
  responsive across <b>desktop (Linux/Windows/macOS)</b> and <b>mobile
  (Android/iOS)</b>, plus web, from a single codebase.
</p>

<p align="center">
  <a href="https://daniel-hiller.github.io/jellymusic/"><b>▶&nbsp; Try the live demo</b></a>
</p>

---

Login → browse your library → open an album → play works end to end: a full
player (queue editing, synced lyrics, sleep timer, gapless or crossfaded
playback), playlists, genres, radio (Instant Mix), casting to and from other
Jellyfin clients, runtime themes, multi-server accounts, on-device response
caching, and German/English localization.

## Features

- **Library** — Albums, Artists, Songs, Playlists and Genres, all paged, with
  sort, in-tab search, a favourites filter and a server-side A–Z rail on
  desktop. Narrow a list further by played state, genre and decade — each tab
  offers what the server can actually answer for it. If your server has more
  than one music library, a switcher scopes everything to one of them.
- **Home** — shelves mirroring what Jellyfin tracks: continue listening, recently
  played (albums *and* tracks), recently added, most played, favourites, the
  server's own suggestions, a random pick. Each hides itself when empty.
- **Browsing** — albums with several discs are grouped per disc; artist pages
  carry their own albums, an *appears-on* section, the biography and similar
  artists; albums link on to similar albums; a genre lists its albums, artists
  and tracks; playlist tracks reorder by dragging.
- **Player** — responsive Now Playing: cover + Queue/Lyrics on desktop, a single
  column on mobile (queue inline, lyrics over a blurred cover; swipe the artwork
  to change track, swipe down to close). Synced/plain lyrics, editable queue,
  volume + mute, favourite toggle, sleep timer; the background tints from the
  cover colour. The queue is also its own screen, reachable from the mini
  player, and can be saved as a playlist or cleared.
- **Casting** — drive another Jellyfin client from here, or act as a target for
  others (over `/Sessions`), with full state sync.
- **Desktop** — a collapsible sidebar with your library and favourite playlists,
  a system tray with transport controls, optional close/minimise-to-tray, and a
  Spotify-style mini-player window (X11/Windows/macOS).
- **Playback** — gapless by default (libmpv prefetch on desktop), or a real
  crossfade that overlaps the two tracks. The server decides between direct play
  and transcoding from a per-platform device profile, so a file that already
  fits your quality setting is streamed untouched. Optional volume levelling
  from Jellyfin's ReplayGain values, background playback + OS media controls,
  and scrobbling back to Jellyfin.
- **Themes** — 12 palettes (6 dark / 6 light), switchable at runtime.
- **Accounts** — multiple servers/users, password or **Quick Connect** login.
- **More** — Instant Mix radio, playlist CRUD, marking tracks played or
  unplayed, on-device response caching, German/English localization, and an
  in-app update check.

## Get it

- **Desktop & mobile** — download from the
  [latest release](https://github.com/daniel-hiller/jellymusic/releases): a
  Windows installer, Linux `.deb` / `.rpm` / tarball, a macOS app, and an
  Android APK. iOS ships via the App Store.
- **Web** — try the hosted [live demo](https://daniel-hiller.github.io/jellymusic/),
  or self-host it (below).

## Self-host the web app

The web build ships as a container image — no build needed, just point it at
your Jellyfin server (you do that at login, so there's no config):

```bash
# grab the compose file, then:
docker compose up -d      # → http://localhost:8080
```

`docker-compose.yml` pulls `ghcr.io/daniel-hiller/jellymusic:latest` and serves
the app with nginx.

## Development

Setup, building and release details live in **[README-DEV.md](README-DEV.md)**.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
