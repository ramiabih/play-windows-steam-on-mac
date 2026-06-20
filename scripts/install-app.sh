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
# IMPORTANT: macOS TCC blocks apps launched from Finder/Dock from executing
# files inside ~/Documents, ~/Desktop, ~/Downloads ("Operation not permitted").
# Since this repo usually lives in ~/Documents, the app can't just call run.sh.
# So we bake a fully self-contained launcher (paths hardcoded at install time)
# that only touches the Wine install, the prefix, and /tmp — none of which are
# TCC-protected. It launches Steam in a new session so it survives this app
# exiting, keeping a single Dock icon.
STEAM_EXE_REL="drive_c/Program Files (x86)/Steam"
{
    echo '#!/bin/bash'
    echo "WINEPREFIX=$(printf %q "$WINEPREFIX")"
    echo "WINE_BIN=$(printf %q "$WINE_BIN")"
    echo "DXMT_ROOT=$(printf %q "$DXMT_ROOT")"
    echo "STEAM_DIR=$(printf %q "$WINEPREFIX/$STEAM_EXE_REL")"
    cat <<'BODY'
LOG="${TMPDIR:-/tmp}/macos-wine-steam.log"
STEAM_EXE="$STEAM_DIR/steam.exe"
[ -f "$STEAM_EXE" ] || { osascript -e 'display alert "Steam on Wine" message "Steam is not installed yet. Run ./install.sh in the project folder first."' >/dev/null 2>&1; exit 1; }

# Kill any existing instance (including orphans). Patterns are .exe-suffixed and
# case-insensitive so they match Wine titles but never this launcher itself.
titles='Steam\.exe|steamwebhelper|explorer\.exe|winedevice\.exe|steamservice\.exe|services\.exe|plugplay\.exe|svchost\.exe|rpcss\.exe|wineboot\.exe|winewrapper|conhost\.exe|start\.exe|PenguinHotel'
pkill -9 -fi "$titles" 2>/dev/null
sleep 1
pkill -9 -fi "$titles" 2>/dev/null

HTMLCACHE="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Steam/htmlcache"
[ -d "$HTMLCACHE" ] && find "$HTMLCACHE" -maxdepth 2 \( -name "Singleton*" -o -name "*.lock" \) -delete 2>/dev/null

export WINEPREFIX
export WINEDEBUG=-all
export WINEDLLPATH_PREPEND="$DXMT_ROOT"
export DXMT_LOG_LEVEL=error
export WINEDLLOVERRIDES="dxgi,d3d11,d3d10core=n,b;bcrypt=b;ncrypt=b;gameoverlayrenderer,gameoverlayrenderer64=d"
export DXMT_METALFX_SPATIAL_SWAPCHAIN=1
export DXMT_CONFIG="d3d11.metalSpatialUpscaleFactor = 1.5"
export MTL_HUD_ENABLED=0

SIZE=$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null | awk -F', ' '{w=$3+0; h=$4+0; if (w>0 && h>0) print w"x"h}')
[ -z "$SIZE" ] && SIZE="1920x1080"

cd "$STEAM_DIR" || exit 1
: > "$LOG"

# Launch in a new session so Steam survives after this app process exits.
/usr/bin/python3 - "$WINE_BIN" "$SIZE" "$LOG" <<'PY'
import os, sys, subprocess
wine, size, log = sys.argv[1], sys.argv[2], sys.argv[3]
with open(log, "ab") as f:
    subprocess.Popen(
        ["arch", "-x86_64", wine, "explorer.exe",
         "/desktop=macos-wine-steam," + size,
         r"C:\Program Files (x86)\Steam\Steam.exe",
         "-no-cef-sandbox", "-cef-single-process", "-noverifyfiles"],
        stdout=f, stderr=f, stdin=subprocess.DEVNULL,
        start_new_session=True,
    )
PY
BODY
} > "$MACOS/launcher"
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
