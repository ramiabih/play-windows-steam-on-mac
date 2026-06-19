#!/usr/bin/env bash
# Compile and install the steamwebhelper wrapper into every cef.win* directory.
# The wrapper prepends --disable-gpu --single-process to the real helper,
# which fixes Steam's black login window on Wine/macOS.

set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"
require_wine_installed
require_prefix_initialised

MINGW_BIN="$HOMEBREW_PREFIX/bin/x86_64-w64-mingw32-gcc"
if [[ ! -x "$MINGW_BIN" ]]; then
    if [[ -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
        log_info "Installing mingw-w64 (needed to build the wrapper)"
        arch -arm64 "$HOMEBREW_PREFIX/bin/brew" install mingw-w64
    else
        die "mingw-w64 required. Install Homebrew from https://brew.sh then re-run install.sh"
    fi
fi
[[ -x "$MINGW_BIN" ]] || die "x86_64-w64-mingw32-gcc not found"

WRAPPER_DIR="$REPO_ROOT/wrapper"
WRAPPER_BIN="$WRAPPER_DIR/steamwebhelper.exe"

log_step "steamwebhelper wrapper"

make -C "$WRAPPER_DIR" clean >/dev/null 2>&1 || true
make -C "$WRAPPER_DIR" CC="$MINGW_BIN" || die "Wrapper build failed"
[[ -f "$WRAPPER_BIN" ]] || die "Wrapper binary missing"

STEAM_CEF_ROOT="$WINEPREFIX/drive_c/Program Files (x86)/Steam/bin/cef"
[[ -d "$STEAM_CEF_ROOT" ]] || die "Steam CEF dir missing — install Steam first"

wrapper_md5=$(md5 -q "$WRAPPER_BIN")
wrapper_size=$(stat -f%z "$WRAPPER_BIN")
WRAPPER_SIZE_CEILING=500000

is_wrapper_like() {
    [[ -f "$1" ]] && (( $(stat -f%z "$1") < WRAPPER_SIZE_CEILING ))
}

installed=0
while IFS= read -r -d '' cef_dir; do
    target="$cef_dir/steamwebhelper.exe"
    real="$cef_dir/steamwebhelper_real.exe"

    [[ -f "$target" ]] || continue

    if is_wrapper_like "$target"; then
        if [[ ! -f "$real" ]] || is_wrapper_like "$real"; then
            die "$(basename "$cef_dir"): Valve binary missing. Re-run scripts/install-steam.sh"
        fi
    else
        if [[ ! -f "$real" ]] || is_wrapper_like "$real"; then
            cp "$target" "$real" || die "Failed to stash Valve binary"
        fi
    fi

    cp "$WRAPPER_BIN" "$target" || die "Failed to install wrapper"
    log_ok "Installed in $(basename "$cef_dir") (md5 ${wrapper_md5:0:12})"
    installed=$((installed + 1))
done < <(find "$STEAM_CEF_ROOT" -maxdepth 1 -type d -name "cef.win*" -print0)

(( installed > 0 )) || die "No cef.win* directories found"
log_ok "Wrapper active in $installed director(y/ies)"
