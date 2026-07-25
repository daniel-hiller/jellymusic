# JellyMusic

A modern, music-first Jellyfin client built with Flutter. Sleek, theme-able
UI, responsive across **desktop (Linux/Windows/macOS)** and **mobile
(Android/iOS)** — plus web — from a single codebase.

Login → browse your library → open an album → play works end to end: a full
player (queue editing, synced lyrics, sleep timer, gapless/fade), playlists,
genres, radio (Instant Mix), casting to and from other Jellyfin clients,
runtime themes, multi-server accounts, on-device response caching, and
German/English localization.

---

## Features

- **Library** — Albums, Artists, Songs, Playlists, Genres, Favourites. Sort
  (name / artist / year / date added / play count / random) plus a
  "favourites only" filter, with infinite scroll and an A–Z jump rail on
  desktop.
- **Home** — shelves that mirror what Jellyfin tracks: continue listening,
  recently played, recently added, most played, favourite albums/artists, a
  random pick. Each hides itself when empty. Rows scroll horizontally with a
  visible scrollbar on desktop.
- **Player** — responsive Now Playing:
  - Desktop: two panes — cover art beside a Queue / Lyrics tab strip.
  - Mobile: single column where the queue shows **inline** (replacing the
    cover) and the lyrics sit over a **blurred** copy of the cover. **Swipe**
    the artwork left/right to change track, **swipe the screen down** to close.
  - Synced/plain lyrics, editable queue (reorder, remove, play next, add to
    queue), volume + mute, favourite toggle, sleep timer. The background tints
    itself from the cover's dominant colour.
- **Casting** — hand playback to another Jellyfin client and drive it from
  here, or let other clients cast **to** this device (both over `/Sessions`),
  with full state sync (track, position, play/pause, volume, shuffle/repeat).
- **Playback tuning** — gapless (libmpv prefetch on desktop) and an optional
  fade at track boundaries.
- **Themes** — 12 palettes (6 dark / 6 light) in a Dark/Light tabbed picker,
  switchable at runtime and from the login screen.
- **Playlists** — create, rename, delete, add songs (multi-select picker or
  from any track's menu), remove.
- **Radio** — Instant Mix seeded from an album, artist, playlist or genre.
- **Accounts** — multiple servers/users; switch between them, or add another
  without signing the first out. Password or **Quick Connect** login.
- **Navigation** — a bottom nav (Home / Library / Search / Settings) on phones,
  a nav rail on desktop, and edge-swipe-back on pushed screens.
- **Settings** — grouped into Account, Playback (quality, fade, gapless, cast
  target, clear cache), Appearance (theme, language) and About.
- **Playback plumbing** — background playback + OS media controls
  (notification / lockscreen / media keys) via `audio_service`, and scrobbling
  back to Jellyfin (start / progress / stopped) so play counts and
  "continue listening" stay in sync.
- **Updates** — non-store builds check the GitHub releases API on launch and
  show a dismissible in-app banner when a newer version exists.

## Requirements

- Flutter **3.44.x** (the CI pins `3.44.7`), Dart ≥ 3.5 (`pubspec` requires
  `sdk: >=3.5.0`).
- A reachable Jellyfin server (a recent 10.x).
- Linux desktop deps:
  `sudo apt install libmpv-dev mpv libsecret-1-dev libayatana-appindicator3-dev`
  — libmpv for audio, libsecret for secure token storage, appindicator for the
  system-tray icon. External links open via `xdg-open`
  (`xdg-utils`).

## First run

All platform folders (`android/`, `ios/`, `linux/`, `macos/`, `windows/`,
`web/`) are committed and pre-configured — bundle id `com.jellymusic.app`,
display name **JellyMusic**, and the native `audio_service` wiring described
below. Just fetch dependencies and run:

```bash
cd jellymusic
flutter pub get

flutter run -d linux
flutter run -d chrome     # web: audio works; HLS-transcoded streams don't
flutter run                # a connected phone / emulator / desktop
```

> Localization sources live in `lib/l10n/*.arb` and are code-generated
> (`flutter: generate: true`). `flutter run` / `flutter pub get` regenerate
> them; to do it by hand run `flutter gen-l10n`.

## Web in production

Releases publish the web app two ways automatically (see below), or build the
container locally. The image is runtime-only (nginx), so build the web bundle
first:

```bash
flutter build web --release
docker build -t jellymusic-web .
docker run -p 8080:80 jellymusic-web   # → http://localhost:8080
```

The container serves the bundle with nginx (SPA fallback for `go_router`,
hard-cached hashed assets, no-cache bootstrap; config in `docker/nginx.conf`).
The app connects to whichever Jellyfin server the user logs into, so there is
no build-time server URL.

To run the **published** image instead of building, use `docker-compose.yml`
(it pulls `ghcr.io/daniel-hiller/jellymusic:latest`, no build step):

```bash
docker compose pull && docker compose up -d   # → http://localhost:8080
```

## Releases, versioning & updates

`pubspec.yaml` stays at a fixed `1.0.0`; the real version comes from the git
tag. Publishing a GitHub release runs `.github/workflows/release.yml`, which:

- builds **Linux, Android, Windows and macOS** binaries and attaches them to
  the release (iOS is handled separately via App Store Connect),
- publishes the **web app to GitHub Pages** and a **container image to
  `ghcr.io/daniel-hiller/jellymusic`** (`:<version>` and `:latest`),
- injects the tag into every build
  (`--dart-define=APP_VERSION=<tag>`, read in `lib/core/app_info.dart`).

Only the automatic `GITHUB_TOKEN` is used. Android ships debug-signed and
macOS/Windows unsigned unless you add signing secrets. One-time repo setup:
**Settings → Pages → Source = "GitHub Actions"** so the Pages deploy can run;
the published container image starts private (make it public or pull with a
token).

Every platform except iOS and web checks the GitHub releases API on launch
(`lib/data/update_service.dart`) and shows a dismissible in-app banner when a
newer tag exists, linking to the release. Dev builds (`-dev` version) skip the
check.

> Cut a release: tag `vX.Y.Z`, publish it on GitHub, and the workflow fills in
> the binaries, the container image and the Pages site.

## Native platform config (already applied)

Reference for what the committed platform folders already contain — you don't
need to redo any of this:

- **Android** — `MainActivity` extends `AudioServiceActivity`; the manifest
  declares the `AudioService` foreground service (`mediaPlayback`), the
  `MediaButtonReceiver`, and `INTERNET` / `FOREGROUND_SERVICE*` / `WAKE_LOCK` /
  `POST_NOTIFICATIONS` permissions. `minSdk` is 23.
- **iOS** — `Info.plist` enables the `audio` background mode.
- **macOS** — `com.apple.security.network.client` is set in **both**
  `DebugProfile.entitlements` and `Release.entitlements` (the sandbox blocks
  server access otherwise).
- **Linux / Windows** — desktop audio runs through `just_audio_media_kit`
  (libmpv), initialised in `main.dart`. On Linux the window/dock icon is set in
  the GTK runner; `scripts/install-linux-icon.sh` installs it into the icon
  theme for the dash.

## Project structure (overview)

```
lib/
├── main.dart                 # init: storage, deviceId, cache, audio_service, DI overrides
├── app.dart                  # MaterialApp.router + selected theme + localization
├── l10n/                     # .arb sources + generated AppLocalizations
├── core/
│   ├── app_info.dart         # version (injected from the tag) + repo URLs
│   ├── theme/                # runtime themes: JellyColors extension + light/dark palettes
│   ├── router/               # go_router (auth redirect + stateful shell)
│   ├── audio/                # audio_service handler over just_audio (+ fade, scrobbling)
│   └── util/                 # formatting, cover-colour extraction, item helpers
├── data/
│   ├── cache/                # dio HTTP response cache
│   ├── jellyfin/             # service, auth/music/sessions repositories, cast receiver
│   ├── update_service.dart   # GitHub releases update check
│   └── models/               # persisted session
├── providers/                # Riverpod: DI, auth, library, player & cast providers
├── features/                 # UI per feature: auth, home, library, search, player, settings, shell
└── widgets/                  # reusable: CoverArt, AlbumCard, AlbumShelf, SongTile, BrandMark, SwipeBack, skeletons
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
