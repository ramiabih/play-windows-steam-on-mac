#!/usr/bin/env bash
#
# install.sh — Wine + DXMT + Steam + steamwebhelper wrapper.
# Idempotent: safe to re-run.

set -euo pipefail
cd "$(dirname "$0")"
source "lib/common.sh"

log_step "macos-wine-steam installer"
log_info "WINEPREFIX : $WINEPREFIX"
log_info "WINE_APP   : $WINE_APP"
log_info ""

require_macos_arm64
ensure_rosetta

INSTALL_GAMES=0
for arg in "$@"; do
    case "$arg" in
        --games) INSTALL_GAMES=1 ;;
    esac
done

steps=(
    scripts/install-prereqs.sh
    scripts/install-wine.sh
    scripts/setup-prefix.sh
    scripts/install-steam.sh
    scripts/install-dxmt.sh
    scripts/fix-ssl.sh
    scripts/install-wrapper.sh
    scripts/configure-game-launch.sh
)

if (( INSTALL_GAMES )); then
    steps+=(scripts/build-dxmt-fork.sh)
fi

for step in "${steps[@]}"; do
    log_step "$(basename "$step")"
    bash "$step"
done

log_step "Done"
log_info ""
log_info "Launch Steam:"
log_info "  ./run.sh"
log_info "  or double-click run.command"
log_info ""
log_info "Log: \${TMPDIR}/macos-wine-steam.log"
