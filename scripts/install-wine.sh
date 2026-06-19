#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"
require_macos_arm64

WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/wine-devel-${WINE_VERSION}-osx64.tar.xz"

log_step "Wine ${WINE_VERSION}"

if [[ -x "$WINE_BIN" ]]; then
    log_ok "Already installed at $WINE_APP"
    exit 0
fi

require_cmd curl
mkdir -p "$WINE_ROOT"
log_info "Downloading Wine ${WINE_VERSION}"
curl -fL --retry 3 --retry-delay 2 "$WINE_URL" | tar xJf - -C "$WINE_ROOT"
[[ -x "$WINE_BIN" ]] || die "Wine binary missing after extract: $WINE_BIN"

version=$(run_x86_64 "$WINE_BIN" --version 2>&1 || true)
log_ok "Installed: $version"
