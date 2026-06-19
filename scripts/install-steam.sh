#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"
require_wine_installed
require_prefix_initialised

STEAM_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
SETUP_URL="https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe"
SETUP_DEST="${TMPDIR:-/tmp}/SteamSetup.exe"

log_step "Steam client"

if [[ -f "$STEAM_EXE" ]]; then
    log_ok "Already installed at $STEAM_EXE"
    exit 0
fi

log_info "Downloading Steam installer"
curl -fL --retry 3 --retry-delay 2 -o "$SETUP_DEST" "$SETUP_URL"
head -c 2 "$SETUP_DEST" | grep -q '^MZ' || die "Invalid SteamSetup.exe download"

log_info "Running installer (complete the wizard if a window appears)"
wine_run "$SETUP_DEST"
[[ -f "$STEAM_EXE" ]] || die "steam.exe not found after install"
rm -f "$SETUP_DEST"
log_ok "Steam installed"
