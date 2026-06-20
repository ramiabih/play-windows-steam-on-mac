#!/usr/bin/env bash
#
# uninstall.sh — Remove files created by this project (with confirmation).

set -euo pipefail
cd "$(dirname "$0")"
source "lib/common.sh"

confirm_remove() {
    local path=$1 label=$2
    [[ -e "$path" ]] || return 0
    printf 'Remove %s (%s)? [y/N] ' "$label" "$path"
    read -r ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || return 0
    rm -rf "$path"
    log_ok "Removed $path"
}

log_step "Uninstall macos-wine-steam"

confirm_remove "/Applications/Steam on Wine.app" "Launcher app"
confirm_remove "$WINEPREFIX" "Wine prefix"
confirm_remove "$WINE_ROOT" "Wine install"
confirm_remove "$DXMT_ROOT" "DXMT"
confirm_remove "${DXMT_SRC:-$HOME/dev/dxmt}" "DXMT build tree (LLVM + source, several GB)"
confirm_remove "$REPO_ROOT/vendor" "Downloaded vendor files"
confirm_remove "${TMPDIR:-/tmp}/SteamSetup.exe" "Steam installer cache"
confirm_remove "${TMPDIR:-/tmp}/macos-wine-steam.log" "Launch log"

log_ok "Done (Rosetta is not removed)"
