#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"
require_wine_installed

log_step "Wine prefix at $WINEPREFIX"

"$WINESERVER_BIN" -k 2>/dev/null || true
sleep 1

if [[ -d "$WINEPREFIX/drive_c/windows" ]]; then
    log_info "Existing prefix — running wineboot -u"
    wine_run wineboot -u >/dev/null 2>&1 || true
else
    log_info "Creating new prefix"
    wine_run wineboot -i >/dev/null 2>&1 || die "wineboot failed"
fi

fonts_dir="$WINEPREFIX/drive_c/windows/Fonts"
mkdir -p "$fonts_dir"

declare -a font_sources=(
    "/System/Library/Fonts/Hiragino Sans GB.ttc"
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
)

copied=0
for src in "${font_sources[@]}"; do
    [[ -r "$src" ]] || continue
    dst="$fonts_dir/$(basename "$src")"
    cp "$src" "$dst"
    copied=$((copied + 1))
done
log_ok "Fonts copied: $copied"

FONT_REG="$REPO_ROOT/assets/japanese-fonts.reg"
if [[ -f "$FONT_REG" ]]; then
    wine_run regedit /S "Z:${FONT_REG}" >/dev/null 2>&1 \
        || log_warn "Font registry import had warnings (non-fatal)"
fi

wine_run reg add "HKCU\\Software\\Wine\\Mac Driver" /v RetinaMode /t REG_SZ /d n /f >/dev/null
wine_run reg add "HKCU\\Control Panel\\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f >/dev/null
wine_run reg add "HKCU\\Control Panel\\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f >/dev/null
wine_run reg add "HKCU\\Control Panel\\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f >/dev/null

log_ok "Prefix ready"
