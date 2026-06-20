#!/usr/bin/env bash
# Build a double-clickable "Steam on Wine.app" launcher and drop it in
# /Applications so it shows up in Spotlight, Launchpad, and the Dock.
#
# The app just runs this repo's run.sh, with the repo path baked in so it keeps
# working from anywhere (Dock, Launchpad, wherever).

set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

APP_NAME="${APP_NAME:-Steam on Wine}"
APP_DIR="${APP_DIR:-/Applications/${APP_NAME}.app}"
ICON_SRC="$REPO_ROOT/assets/steam-on-wine-icon.png"

log_step "Installing ${APP_NAME}.app"

CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RES"

# -- Icon: crop to square, build .icns ----------------------------------------
if [[ -f "$ICON_SRC" ]] && command -v sips >/dev/null && command -v iconutil >/dev/null; then
    log_info "Building app icon"
    tmp_icon="$(mktemp -d)"
    side=$(sips -g pixelHeight "$ICON_SRC" | awk '/pixelHeight/{print $2}')
    sips -c "$side" "$side" "$ICON_SRC" --out "$tmp_icon/square.png" >/dev/null
    iconset="$tmp_icon/icon.iconset"
    mkdir -p "$iconset"
    for sz in 16 32 64 128 256 512; do
        sips -z "$sz" "$sz"           "$tmp_icon/square.png" --out "$iconset/icon_${sz}x${sz}.png"    >/dev/null
        sips -z $((sz*2)) $((sz*2))   "$tmp_icon/square.png" --out "$iconset/icon_${sz}x${sz}@2x.png" >/dev/null
    done
    iconutil -c icns "$iconset" -o "$RES/AppIcon.icns"
    rm -rf "$tmp_icon"
    ICON_PLIST="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"
else
    log_warn "Icon source or tools missing — app will use the default icon"
    ICON_PLIST=""
fi

# -- Launcher executable ------------------------------------------------------
cat > "$MACOS/launcher" <<EOF
#!/bin/bash
cd "$REPO_ROOT" || exit 1
exec ./run.sh --detach
EOF
chmod +x "$MACOS/launcher"

# -- Info.plist ---------------------------------------------------------------
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.ramiabih.steam-on-wine</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
${ICON_PLIST}
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Refresh Launch Services / icon cache so the new icon shows immediately.
touch "$APP_DIR"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$APP_DIR" >/dev/null 2>&1 || true

log_ok "Installed: $APP_DIR"
log_info "Find it in Launchpad/Spotlight, or drag it to your Dock."
