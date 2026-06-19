#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"
require_prefix_initialised

log_step "TLS trust roots"

CA_SRC="/etc/ssl/cert.pem"
CA_DST="$WINEPREFIX/drive_c/windows/cacert.pem"

if [[ -r "$CA_SRC" ]]; then
    cp "$CA_SRC" "$CA_DST"
    log_ok "Copied macOS CA bundle to prefix"
else
    log_warn "No CA bundle at $CA_SRC"
fi

log_ok "SSL step complete"
