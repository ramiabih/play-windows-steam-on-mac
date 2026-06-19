#!/usr/bin/env bash
#
# run.sh — Launch Steam with DXMT + wrapper settings that work on Apple Silicon.

set -euo pipefail
cd "$(dirname "$0")"
source "lib/common.sh"

require_wine_installed
require_prefix_initialised

STEAM_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
[[ -f "$STEAM_EXE" ]] || die "Steam not installed. Run ./install.sh first."

HTMLCACHE="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Steam/htmlcache"
LOG_FILE="${STEAM_LOG:-${TMPDIR:-/tmp}/macos-wine-steam.log}"
WRAPPER_BIN="$REPO_ROOT/wrapper/steamwebhelper.exe"

log_step "Preparing launch"

patterns='steam\.exe|steamwebhelper|wineserver|wine64-preloader'
to_kill=$(pgrep -f "$patterns" 2>/dev/null || true)
if [[ -n "$to_kill" ]]; then
    # shellcheck disable=SC2086
    kill -9 $to_kill 2>/dev/null || true
    sleep 2
fi
"$WINESERVER_BIN" -k 2>/dev/null || true
sleep 1

if [[ -d "$HTMLCACHE" ]]; then
    find "$HTMLCACHE" -maxdepth 2 \( -name "Singleton*" -o -name "*.lock" \) -delete 2>/dev/null || true
fi

if [[ -f "$WRAPPER_BIN" ]]; then
    wrapper_md5=$(md5 -q "$WRAPPER_BIN")
    needs_redeploy=0
    while IFS= read -r -d '' cef_dir; do
        target_md5=$(md5 -q "$cef_dir/steamwebhelper.exe" 2>/dev/null || echo "")
        if [[ "$target_md5" != "$wrapper_md5" ]]; then
            needs_redeploy=1
        fi
    done < <(find "$WINEPREFIX/drive_c/Program Files (x86)/Steam/bin/cef" \
        -maxdepth 1 -type d -name "cef.win*" -print0 2>/dev/null)

    if (( needs_redeploy )); then
        log_warn "Wrapper missing or overwritten — redeploying"
        bash "$REPO_ROOT/scripts/install-wrapper.sh"
    fi
fi

export WINEPREFIX
export WINEDEBUG
export WINEDLLPATH_PREPEND="${DXMT_ROOT}${WINEDLLPATH_PREPEND:+:${WINEDLLPATH_PREPEND}}"
export DXMT_LOG_LEVEL="${DXMT_LOG_LEVEL:-error}"
export WINEDLLOVERRIDES="dxgi,d3d11,d3d10core=n,b;bcrypt=b;ncrypt=b;gameoverlayrenderer,gameoverlayrenderer64=d"

STEAM_ARGS=(
    -no-cef-sandbox
    -cef-single-process
    -noverifyfiles
)

detect_display_size() {
    local bounds width height
    bounds=$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null || true)
    if [[ "$bounds" =~ ,[[:space:]]*([0-9]+),[[:space:]]*([0-9]+)$ ]]; then
        width="${BASH_REMATCH[1]}"
        height="${BASH_REMATCH[2]}"
        if [[ "$width" -gt 0 && "$height" -gt 0 ]]; then
            echo "${width}x${height}"
            return
        fi
    fi
    echo "1920x1080"
}

WINE_VIRTUAL_DESKTOP_NAME="${WINE_VIRTUAL_DESKTOP_NAME:-macos-wine-steam}"
if [[ -z "${WINE_VIRTUAL_DESKTOP+x}" || "${WINE_VIRTUAL_DESKTOP:-}" == "auto" ]]; then
    WINE_VIRTUAL_DESKTOP="$(detect_display_size)"
fi

: > "$LOG_FILE"

log_step "Launching Steam"
log_info "Prefix          : $WINEPREFIX"
log_info "Virtual desktop : ${WINE_VIRTUAL_DESKTOP_NAME} @ ${WINE_VIRTUAL_DESKTOP}"
log_info "Log             : $LOG_FILE"

cd "$WINEPREFIX/drive_c/Program Files (x86)/Steam"

if [[ -n "${WINE_VIRTUAL_DESKTOP:-}" ]]; then
    nohup arch -x86_64 "$WINE_BIN" \
        explorer.exe "/desktop=${WINE_VIRTUAL_DESKTOP_NAME},${WINE_VIRTUAL_DESKTOP}" \
        "C:\\Program Files (x86)\\Steam\\Steam.exe" \
        "${STEAM_ARGS[@]}" \
        >>"$LOG_FILE" 2>&1 &
else
    nohup arch -x86_64 "$WINE_BIN" \
        "C:\\Program Files (x86)\\Steam\\Steam.exe" \
        "${STEAM_ARGS[@]}" \
        >>"$LOG_FILE" 2>&1 &
fi
disown

log_ok "Steam started (safe to close this terminal)"
log_info "Tail log: tail -f $LOG_FILE"

if [[ "${1:-}" != "--detach" ]]; then
    sleep 2
    log_info "Tailing log — Ctrl-C detaches (Steam keeps running)"
    tail -f "$LOG_FILE"
fi
