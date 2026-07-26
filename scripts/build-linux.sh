#!/usr/bin/env bash
# =============================================================================
#  JellyMusic — Linux release build
#
#  Produces (into dist/linux/):
#    jellymusic-linux-x64-<version>.tar.gz    (always — portable, install.sh)
#    jellymusic_<version>_amd64.deb           (if dpkg-deb is available)
#    jellymusic-<version>.x86_64.rpm          (if fpm is available)
#
#  All bundle the Flutter Linux release output (build/linux/x64/release/bundle)
#  under /opt/jellymusic, with a /usr/bin/jellymusic symlink, a .desktop entry
#  and a hicolor icon so the app shows up in the menu after install.
#
#  Usage:
#    scripts/build-linux.sh                 # build + package
#    scripts/build-linux.sh --skip-build    # repackage an existing build
#    VERSION=1.1.0 scripts/build-linux.sh   # override version (CI passes the tag)
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    -h|--help)    sed -n '2,17p' "$0"; exit 0 ;;
    *)            echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[33m!!! %s\033[0m\n' "$1" >&2; }
die()  { printf '\033[31mxxx %s\033[0m\n' "$1" >&2; exit 1; }

APP=jellymusic
VERSION="${VERSION:-0.0.0-dev}"
step "Version: $VERSION"

command -v flutter >/dev/null || die "flutter not found on PATH."

if (( !SKIP_BUILD )); then
  step "flutter pub get";               flutter pub get
  step "flutter build linux --release"; flutter build linux --release \
    --dart-define=APP_VERSION="$VERSION"
fi

BUNDLE_DIR="$ROOT/build/linux/x64/release/bundle"
[[ -x "$BUNDLE_DIR/$APP" ]] || die "Build output not found: $BUNDLE_DIR/$APP"

ICON_SRC="$ROOT/packaging/jellymusic.png"
[[ -f "$ICON_SRC" ]] || die "Icon not found: $ICON_SRC"

OUT_DIR="$ROOT/dist/linux"
mkdir -p "$OUT_DIR"

DESKTOP_CONTENT=$(cat <<'EOF'
[Desktop Entry]
Name=JellyMusic
GenericName=Music Player
Comment=A modern, music-first Jellyfin client
Exec=jellymusic
Icon=jellymusic
Type=Application
Categories=AudioVideo;Audio;Player;
Keywords=music;jellyfin;audio;player;stream;
StartupWMClass=jellymusic
Terminal=false
EOF
)

# --- Staging tree shared by .deb and .rpm (files land under these paths) ----
STAGE="$(mktemp -d /tmp/jellymusic-pkg.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/opt/jellymusic" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/512x512/apps"
cp -a "$BUNDLE_DIR/." "$STAGE/opt/jellymusic/"
ln -sf "/opt/jellymusic/jellymusic" "$STAGE/usr/bin/jellymusic"
cp "$ICON_SRC" "$STAGE/usr/share/icons/hicolor/512x512/apps/jellymusic.png"
printf '%s\n' "$DESKTOP_CONTENT" \
  > "$STAGE/usr/share/applications/jellymusic.desktop"

# --- tar.gz (portable, with a per-user install.sh) --------------------------
step "Assembling tar.gz"
TGZ_STAGE="$(mktemp -d /tmp/jellymusic-tgz.XXXXXX)"
trap 'rm -rf "$STAGE" "$TGZ_STAGE"' EXIT
mkdir -p "$TGZ_STAGE/jellymusic-$VERSION"
cp -a "$BUNDLE_DIR/." "$TGZ_STAGE/jellymusic-$VERSION/"
cp "$ICON_SRC" "$TGZ_STAGE/jellymusic-$VERSION/jellymusic.png"
printf '%s\n' "$DESKTOP_CONTENT" > "$TGZ_STAGE/jellymusic-$VERSION/jellymusic.desktop"
cat > "$TGZ_STAGE/jellymusic-$VERSION/install.sh" <<'INSTALL_EOF'
#!/usr/bin/env bash
# Per-user install for the portable tarball.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.local/share/jellymusic"
mkdir -p "$TARGET" "$HOME/.local/bin" \
         "$HOME/.local/share/applications" \
         "$HOME/.local/share/icons/hicolor/512x512/apps"
cp -a "$HERE/." "$TARGET/"
ln -sf "$TARGET/jellymusic" "$HOME/.local/bin/jellymusic"
cp "$HERE/jellymusic.png" \
   "$HOME/.local/share/icons/hicolor/512x512/apps/jellymusic.png"
sed "s|^Exec=jellymusic$|Exec=$TARGET/jellymusic|" "$HERE/jellymusic.desktop" \
   > "$HOME/.local/share/applications/jellymusic.desktop"
gtk-update-icon-cache -q -t -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
update-desktop-database -q "$HOME/.local/share/applications" 2>/dev/null || true
echo "Installed JellyMusic to $TARGET (ensure ~/.local/bin is on PATH)."
INSTALL_EOF
chmod +x "$TGZ_STAGE/jellymusic-$VERSION/install.sh"
TGZ_PATH="$OUT_DIR/jellymusic-linux-x64-$VERSION.tar.gz"
rm -f "$TGZ_PATH"
tar -C "$TGZ_STAGE" -czf "$TGZ_PATH" "jellymusic-$VERSION"

# --- .deb (dpkg-deb) --------------------------------------------------------
if command -v dpkg-deb >/dev/null; then
  step "Assembling .deb"
  DEB_ROOT="$STAGE-deb"
  cp -a "$STAGE" "$DEB_ROOT"
  mkdir -p "$DEB_ROOT/DEBIAN"
  INSTALLED_SIZE="$(du -sk "$DEB_ROOT/opt" | awk '{print $1}')"
  cat > "$DEB_ROOT/DEBIAN/control" <<EOF
Package: jellymusic
Version: $VERSION
Section: sound
Priority: optional
Architecture: amd64
Maintainer: Daniel Hiller <daniel-hiller@users.noreply.github.com>
Installed-Size: $INSTALLED_SIZE
Depends: libgtk-3-0, libglib2.0-0, libstdc++6, libsecret-1-0, libayatana-appindicator3-1, libmpv2 | libmpv1
Recommends: xdg-utils
Description: A modern, music-first Jellyfin client
 Browse your Jellyfin music library, build a queue, cast to and from other
 clients, and enjoy gapless playback — desktop-native, built with Flutter.
Homepage: https://github.com/daniel-hiller/jellymusic
EOF
  cat > "$DEB_ROOT/DEBIAN/postinst" <<'POST_EOF'
#!/bin/sh
set -e
gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database -q /usr/share/applications 2>/dev/null || true
POST_EOF
  cp "$DEB_ROOT/DEBIAN/postinst" "$DEB_ROOT/DEBIAN/postrm"
  chmod 0755 "$DEB_ROOT/DEBIAN/postinst" "$DEB_ROOT/DEBIAN/postrm"
  DEB_PATH="$OUT_DIR/jellymusic_${VERSION}_amd64.deb"
  rm -f "$DEB_PATH"
  dpkg-deb --root-owner-group --build "$DEB_ROOT" "$DEB_PATH" >/dev/null
  rm -rf "$DEB_ROOT"
else
  warn "dpkg-deb not available — skipping .deb."
fi

# --- .rpm (fpm) -------------------------------------------------------------
# fpm builds the rpm straight from the staging tree; rpm's own dependency
# generator auto-adds the shared-library Requires (libmpv, libsecret, gtk, …).
if command -v fpm >/dev/null; then
  step "Assembling .rpm"
  RPM_PATH="$OUT_DIR/jellymusic-${VERSION}.x86_64.rpm"
  rm -f "$RPM_PATH"
  fpm -s dir -t rpm -n jellymusic -v "$VERSION" -a x86_64 \
    --license MIT \
    --maintainer "Daniel Hiller" \
    --url "https://github.com/daniel-hiller/jellymusic" \
    --description "A modern, music-first Jellyfin client" \
    --rpm-summary "A modern, music-first Jellyfin client" \
    -p "$RPM_PATH" \
    -C "$STAGE" .
else
  warn "fpm not available — skipping .rpm (install: gem install fpm)."
fi

# --- SHA-256 + summary ------------------------------------------------------
step "Hashing artifacts"
for f in "$OUT_DIR"/jellymusic*"$VERSION"*.{tar.gz,deb,rpm}; do
  [[ -f "$f" ]] || continue
  sha256sum "$f" | tee "$f.sha256" >/dev/null
  printf '  %s (%s MB)\n' "$(basename "$f")" "$(du -m "$f" | awk '{print $1}')"
done
printf '\033[32mDone: %s\033[0m\n' "$OUT_DIR"
