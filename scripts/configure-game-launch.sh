#!/usr/bin/env bash
# Persist DXMT DLL overrides in the prefix and set UE5 launch options.

set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"
require_prefix_initialised

log_step "Game launch configuration"

wine_run reg add "HKCU\\Software\\Wine\\DllOverrides" /v dxgi /t REG_SZ /d native,builtin /f >/dev/null
wine_run reg add "HKCU\\Software\\Wine\\DllOverrides" /v d3d11 /t REG_SZ /d native,builtin /f >/dev/null
wine_run reg add "HKCU\\Software\\Wine\\DllOverrides" /v d3d10core /t REG_SZ /d native,builtin /f >/dev/null
wine_run reg add "HKCU\\Software\\Wine\\DllOverrides" /v bcrypt /t REG_SZ /d builtin /f >/dev/null
wine_run reg add "HKCU\\Software\\Wine\\DllOverrides" /v ncrypt /t REG_SZ /d builtin /f >/dev/null
wine_run reg add "HKCU\\Software\\Wine\\DllOverrides" /v gameoverlayrenderer /t REG_SZ /d disabled /f >/dev/null
wine_run reg add "HKCU\\Software\\Wine\\DllOverrides" /v gameoverlayrenderer64 /t REG_SZ /d disabled /f >/dev/null
log_ok "DLL overrides in prefix registry"

if [[ -f "$REPO_ROOT/scripts/set-launch-options.sh" ]]; then
    bash "$REPO_ROOT/scripts/set-launch-options.sh" 4704690 "-d3d11 -windowed" 2>/dev/null \
        || log_warn "Could not set LaunchOptions for 4704690 (launch Steam once, then re-run)"
fi

log_ok "Game launch configuration complete"
