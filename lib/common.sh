#!/usr/bin/env bash
# Shared helpers for macos-wine-steam.

set -euo pipefail

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_BLUE=$'\033[34m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
else
    C_RESET="" C_BOLD="" C_BLUE="" C_GREEN="" C_YELLOW="" C_RED=""
fi

_log() {
    local level=$1 color=$2
    shift 2
    printf '%s%s [%s]%s %s\n' "$color" "$(date +%H:%M:%S)" "$level" "$C_RESET" "$*" >&2
}

log_info()  { _log "INFO"  "$C_BLUE"   "$*"; }
log_ok()    { _log "OK"    "$C_GREEN"  "$*"; }
log_warn()  { _log "WARN"  "$C_YELLOW" "$*"; }
log_error() { _log "ERROR" "$C_RED"    "$*"; }

log_step() {
    printf '\n%s%s== %s ==%s\n' "$C_BOLD" "$C_BLUE" "$*" "$C_RESET" >&2
}

die() {
    log_error "$@"
    exit 1
}

: "${HOMEBREW_PREFIX:=/opt/homebrew}"
export HOMEBREW_PREFIX
export PATH="$HOMEBREW_PREFIX/bin:$PATH"

: "${WINE_VERSION:=11.8}"
: "${WINE_ROOT:=$HOME/wine-${WINE_VERSION}}"
: "${WINE_APP:=$WINE_ROOT/Wine Devel.app}"
: "${WINE_BIN:=$WINE_APP/Contents/Resources/wine/bin/wine}"
: "${WINESERVER_BIN:=$WINE_APP/Contents/Resources/wine/bin/wineserver}"
: "${WINEPREFIX:=$HOME/.wine-steam-${WINE_VERSION%%.*}}"
: "${DXMT_VERSION:=0.80}"
: "${DXMT_ROOT:=$HOME/DXMT}"

export WINE_VERSION WINE_ROOT WINE_APP WINE_BIN WINESERVER_BIN WINEPREFIX DXMT_VERSION DXMT_ROOT
: "${WINEDEBUG:=-all}"
export WINEDEBUG

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export REPO_ROOT

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_macos_arm64() {
    [[ "$(uname -s)" == "Darwin" ]] || die "macOS only."
    [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" == "1" ]] \
        || die "Apple Silicon (arm64) required."
}

ensure_rosetta() {
    if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
        log_ok "Rosetta 2 available"
        return
    fi
    log_info "Installing Rosetta 2 (sudo required)"
    sudo softwareupdate --install-rosetta --agree-to-license
    /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1 || die "Rosetta installation failed"
    log_ok "Rosetta 2 installed"
}

require_wine_installed() {
    [[ -x "$WINE_BIN" ]] || die "Wine not found at $WINE_BIN. Run ./install.sh first."
}

require_prefix_initialised() {
    [[ -d "$WINEPREFIX/drive_c/windows" ]] \
        || die "Wine prefix missing at $WINEPREFIX. Run ./install.sh first."
}

run_x86_64() {
    arch -x86_64 "$@"
}

brew_arm64() {
    arch -arm64 "$HOMEBREW_PREFIX/bin/brew" "$@"
}

wine_run() {
    WINEPREFIX="$WINEPREFIX" WINEDEBUG="$WINEDEBUG" run_x86_64 "$WINE_BIN" "$@"
}

# Kill every Wine/Steam process from this project, including orphans whose
# wineserver has already exited (wineserver -k can't reach those, and it hangs
# when no server is live). We match Wine's window titles case-insensitively.
# Every pattern carries an ".exe"/explicit suffix so it can never match this
# repo's own paths, which contain the word "steam" (avoids self-killing).
stop_wine_steam() {
    local titles='Steam\.exe|steamwebhelper|explorer\.exe|winedevice\.exe|steamservice\.exe|services\.exe|plugplay\.exe|svchost\.exe|rpcss\.exe|wineboot\.exe|winewrapper|conhost\.exe|start\.exe|PenguinHotel'
    pkill -9 -fi "$titles" 2>/dev/null || true
    sleep 1
    pkill -9 -fi "$titles" 2>/dev/null || true
}

wine_lib_dir() {
    local arch=$1
    echo "$WINE_APP/Contents/Resources/wine/lib/wine/${arch}"
}
