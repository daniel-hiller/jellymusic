#!/usr/bin/env bash
# Installs the JellyMusic icon into the user's icon theme and a launcher entry,
# so Wayland/COSMIC/GNOME show it in the dash and app grid.
#
# The window's app id is APPLICATION_ID (com.jellymusic.app); the compositor
# resolves the icon *by that name* from the theme, so the icon file must be
# named <app-id>.png in an hicolor apps directory. Run once after building:
#   ./scripts/install-linux-icon.sh
set -euo pipefail

APP_ID="com.jellymusic.app"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Transparent bars — sits in the dock like the other icons, not a dark tile.
# (iOS/Android/macOS/Windows use the opaque assets/icon/icon.png instead.)
ICON_SRC="$REPO/assets/icon/brand-1024.png"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
APP_DIR="$HOME/.local/share/applications"

[ -f "$ICON_SRC" ] || { echo "Missing $ICON_SRC — run: dart run tool/gen_icons.dart"; exit 1; }

mkdir -p "$ICON_DIR" "$APP_DIR"
install -m644 "$ICON_SRC" "$ICON_DIR/$APP_ID.png"
install -m644 "$REPO/linux/jellymusic.desktop" "$APP_DIR/$APP_ID.desktop"

# Refresh caches (best-effort; name resolution scans dirs even without them).
command -v gtk-update-icon-cache >/dev/null && \
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
command -v update-desktop-database >/dev/null && \
  update-desktop-database "$APP_DIR" 2>/dev/null || true

echo "Installed $APP_ID icon and launcher entry."
echo "If the dash still shows the old icon, log out and back in to clear the shell cache."
