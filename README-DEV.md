# JellyMusic — Development

Setup, build and release notes for working on JellyMusic. For the user-facing
overview see [README.md](README.md).

## Requirements

- **Flutter 3.44.x** (CI pins `3.44.7`), Dart ≥ 3.5 (`pubspec` requires
  `sdk: >=3.5.0`).
- A reachable Jellyfin server (a recent 10.x).
- Linux desktop deps:
  ```bash
  sudo apt install libmpv-dev mpv libsecret-1-dev libayatana-appindicator3-dev
  ```
  — libmpv for audio, libsecret for secure token storage, appindicator for the
  system-tray icon. External links open via `xdg-open` (`xdg-utils`).

## Run

All platform folders (`android/`, `ios/`, `linux/`, `macos/`, `windows/`,
`web/`) are committed and pre-configured — bundle id `com.jellymusic.app`,
display name **JellyMusic**, and the native `audio_service` wiring. Just:

```bash
flutter pub get
flutter run -d linux      # or -d chrome, or a connected phone / desktop
```

Localization sources live in `lib/l10n/*.arb` and are code-generated
(`flutter: generate: true`). `flutter run` / `flutter pub get` regenerate them;
by hand it's `flutter gen-l10n`.

## Web container (local build)

The published image is runtime-only (nginx copies `build/web`), so build the
bundle first:

```bash
flutter build web --release
docker build -t jellymusic-web .
docker run -p 8080:80 jellymusic-web   # → http://localhost:8080
```

nginx serves the bundle with an SPA fallback for `go_router`, hard-cached hashed
assets and a no-cache bootstrap (`docker/nginx.conf`). The app connects to
whichever Jellyfin server the user logs into — there's no build-time server URL.

## Releases, versioning & updates

`pubspec.yaml` stays at a fixed `1.0.0`; the real version comes from the git
tag. Publishing a GitHub release runs `.github/workflows/release.yml`, which:

- builds **Linux, Android, Windows and macOS** binaries — including a Windows
  installer (`.exe`, Inno Setup) and a Linux **Flatpak** — and attaches them to
  the release (iOS is handled separately via App Store Connect),
- pushes a **container image** to `ghcr.io/daniel-hiller/jellymusic`
  (`:<version>` and `:latest`),
- injects the tag into every build
  (`--dart-define=APP_VERSION=<tag>`, read in `lib/core/app_info.dart`).

Only the automatic `GITHUB_TOKEN` is used. Android ships debug-signed and
macOS/Windows unsigned unless you add signing secrets. The published container
image starts private (make it public or pull with a token).

**Web demo (GitHub Pages):** deployed by `.github/workflows/pages.yml` on every
push to `main` — a live preview at
`https://daniel-hiller.github.io/jellymusic/`. It's separate from releases on
purpose: the `github-pages` environment only allows deploys from branches, not
release tags. Needs a public repo and (one-time) **Settings → Pages → Source =
"GitHub Actions"**.

**CI:** `.github/workflows/ci.yml` runs `flutter analyze` on every push and PR.

Non-store builds check the GitHub releases API on launch
(`lib/data/update_service.dart`) and show a dismissible in-app banner when a
newer tag exists.

> Cut a release: tag `vX.Y.Z`, publish it on GitHub, and the workflow fills in
> the binaries and the container image. (The Pages demo updates from `main`.)

## Flatpak notes

The Flatpak ships its own **audio-only** `libmpv` (media_kit needs libmpv as a
system library, and it isn't in the freedesktop runtime). It's built from
source — mpv 0.38 + a minimal libplacebo (no Vulkan/GL) + libass/fribidi —
against the runtime's ffmpeg. `--libdir=lib` is forced so pkg-config resolves
the modules consistently. The CI job uses the `org.flatpak.Builder` flatpak.

## Native platform config (already applied)

Reference for what the committed platform folders contain — no need to redo it:

- **Android** — `MainActivity` extends `AudioServiceActivity`; the manifest
  declares the `AudioService` foreground service (`mediaPlayback`), the
  `MediaButtonReceiver`, and `INTERNET` / `FOREGROUND_SERVICE*` / `WAKE_LOCK` /
  `POST_NOTIFICATIONS` permissions. `minSdk` is 23.
- **iOS** — `Info.plist` enables the `audio` background mode.
- **macOS** — `com.apple.security.network.client` in **both**
  `DebugProfile.entitlements` and `Release.entitlements` (the sandbox blocks
  server access otherwise).
- **Linux / Windows** — desktop audio runs through `just_audio_media_kit`
  (libmpv), initialised in `main.dart`. On Linux the window/dock icon is set in
  the GTK runner.

## Project structure

```
lib/
├── main.dart      # init: storage, deviceId, cache, audio_service, DI overrides
├── app.dart       # MaterialApp.router + theme + localization
├── l10n/          # .arb sources + generated AppLocalizations
├── core/          # app_info, theme (JellyColors), router, audio handler, utils
├── data/          # Jellyfin service + repositories, HTTP cache, update check
├── providers/     # Riverpod: DI, auth, library, player & cast
├── features/      # UI per feature: auth, home, library, search, player, settings, shell
└── widgets/       # reusable: CoverArt, AlbumCard, AlbumShelf, SongTile, BrandMark, …
```
