#!/usr/bin/env bash
# Make sure the machine has the basics: Xcode Command Line Tools + Homebrew.
# Everything else (Wine, Steam, DXMT, mingw, build tools) is handled by the
# later steps. This is the "you just bought this Mac" safety net.

set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"
require_macos_arm64

log_step "Prerequisites"

# -- Xcode Command Line Tools (gives us git, make, cc, etc.) -------------------
if xcode-select -p >/dev/null 2>&1; then
    log_ok "Xcode Command Line Tools present"
else
    log_info "Installing Xcode Command Line Tools (a dialog will pop up — click Install)"
    xcode-select --install || true
    log_warn "Waiting for you to finish the Command Line Tools install..."
    until xcode-select -p >/dev/null 2>&1; do
        sleep 5
    done
    log_ok "Xcode Command Line Tools installed"
fi

# -- Homebrew -----------------------------------------------------------------
if [[ -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
    log_ok "Homebrew present"
else
    log_info "Installing Homebrew (it'll ask for your password)"
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || die "Homebrew install failed. Install it manually from https://brew.sh then re-run."
    [[ -x "$HOMEBREW_PREFIX/bin/brew" ]] \
        || die "Homebrew installed but not at $HOMEBREW_PREFIX/bin/brew. Set HOMEBREW_PREFIX and re-run."
    log_ok "Homebrew installed"
fi

log_ok "Prerequisites ready"
