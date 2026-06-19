#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"
require_wine_installed
require_prefix_initialised

DXMT_URL="https://github.com/3Shain/dxmt/releases/download/v${DXMT_VERSION}/dxmt-v${DXMT_VERSION}-builtin.tar.gz"
VENDOR_DIR="$REPO_ROOT/vendor/dxmt-v${DXMT_VERSION}"
TARBALL="$VENDOR_DIR/dxmt-v${DXMT_VERSION}-builtin.tar.gz"

log_step "DXMT v${DXMT_VERSION}"

mkdir -p "$VENDOR_DIR"
if [[ ! -f "$TARBALL" ]]; then
    log_info "Downloading DXMT"
    curl -fL --retry 3 --retry-delay 2 -o "$TARBALL" "$DXMT_URL"
fi

EXTRACT_DIR="$VENDOR_DIR/extracted"
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$TARBALL" -C "$EXTRACT_DIR"

src_unix=$(find "$EXTRACT_DIR" -type d -name "x86_64-unix" | head -n1)
src_win64=$(find "$EXTRACT_DIR" -type d -name "x86_64-windows" | head -n1)
src_win32=$(find "$EXTRACT_DIR" -type d -name "i386-windows" | head -n1)
[[ -d "$src_unix" && -d "$src_win64" && -d "$src_win32" ]] || die "DXMT tarball layout unexpected"

install_file() {
    local src=$1 dst=$2
    [[ -f "$src" ]] || die "Missing: $src"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
}

WINE_UNIX="$(wine_lib_dir x86_64-unix)"
WINE_WIN64="$(wine_lib_dir x86_64-windows)"
WINE_WIN32="$(wine_lib_dir i386-windows)"
PREFIX_SYS32="$WINEPREFIX/drive_c/windows/system32"
PREFIX_SYSWOW64="$WINEPREFIX/drive_c/windows/syswow64"

install_file "$src_unix/winemetal.so" "$WINE_UNIX/winemetal.so"
for dll in winemetal.dll d3d11.dll dxgi.dll d3d10core.dll; do
    install_file "$src_win64/$dll" "$WINE_WIN64/$dll"
    install_file "$src_win32/$dll" "$WINE_WIN32/$dll"
done
install_file "$src_win64/winemetal.dll" "$PREFIX_SYS32/winemetal.dll"
install_file "$src_win32/winemetal.dll" "$PREFIX_SYSWOW64/winemetal.dll"

mkdir -p "$DXMT_ROOT"
rm -rf "$DXMT_ROOT"/{i386-windows,x86_64-windows,x86_64-unix}
cp -R "$src_win32" "$DXMT_ROOT/i386-windows"
cp -R "$src_win64" "$DXMT_ROOT/x86_64-windows"
cp -R "$src_unix" "$DXMT_ROOT/x86_64-unix"

log_ok "DXMT installed into Wine and $DXMT_ROOT"
