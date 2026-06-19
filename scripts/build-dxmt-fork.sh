#!/usr/bin/env bash
# Build notpop's DXMT fork (Wine 11 Metal view fix) and stage into Wine + prefix.
# First run builds LLVM 15 from source (~30 min). Re-runs are incremental.

set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"
require_wine_installed
require_prefix_initialised

DXMT_SRC="${DXMT_SRC:-$HOME/dev/dxmt}"
LLVM_PREFIX="${LLVM_PREFIX:-$DXMT_SRC/toolchains/llvm}"
WINE_TOOLCHAIN="${WINE_TOOLCHAIN:-$DXMT_SRC/toolchains/wine}"

WINE_UNIX="$(wine_lib_dir x86_64-unix)"
WINE_WIN64="$(wine_lib_dir x86_64-windows)"
WINE_WIN32="$(wine_lib_dir i386-windows)"
PREFIX_SYS32="$WINEPREFIX/drive_c/windows/system32"
PREFIX_SYSWOW64="$WINEPREFIX/drive_c/windows/syswow64"

DXMT_FORK_URL="https://github.com/notpop/dxmt.git"
DXMT_FORK_BRANCH="debug/present-path-tracing"
LLVM_SRC_DIR="$DXMT_SRC/toolchains/llvm-src"
LLVM_VERSION_TAG="llvmorg-15.0.7"
WINE_TARBALL_URL="https://github.com/3Shain/wine/releases/download/v8.16-3shain/wine.tar.gz"

log_step "DXMT fork (Wine 11 game rendering)"

# DXMT compiles Metal shaders, which needs the `metal` compiler. That ships
# only with full Xcode (App Store), not the Command Line Tools. Check early so
# we don't fail 5 minutes into a compile.
if ! xcrun -f metal >/dev/null 2>&1; then
    if [[ -d /Applications/Xcode.app ]]; then
        log_warn "Switching active developer dir to Xcode and fetching Metal toolchain"
        sudo xcode-select -s /Applications/Xcode.app/Contents/Developer || true
        xcodebuild -downloadComponent MetalToolchain 2>/dev/null || true
    fi
fi
if ! xcrun -f metal >/dev/null 2>&1; then
    die "The Metal shader compiler (metal) is missing.

Building game support requires full Xcode, not just the Command Line Tools.

  1. Install Xcode from the App Store (free, large download):
       https://apps.apple.com/app/xcode/id497799835
  2. Open it once so it finishes setup, then run:
       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
       xcodebuild -downloadComponent MetalToolchain
  3. Re-run: ./install.sh --games

The plain Steam client (./install.sh, no --games) does NOT need Xcode."
fi
log_ok "Metal shader compiler available"

_brew_ensure() {
    local pkg=$1
    if brew_arm64 list --formula "$pkg" >/dev/null 2>&1; then
        log_ok "brew: $pkg"
    else
        log_info "Installing $pkg"
        brew_arm64 install "$pkg"
    fi
}

for pkg in meson ninja bison flex cmake gettext mingw-w64 wget; do
    _brew_ensure "$pkg"
done

# DXMT needs meson >=1.3.0, but meson 1.10/1.11 crash on this cross-build
# (cpp_importstd KeyError) and the system meson can get shadowed by whatever
# is in the user site-packages. Use an isolated venv pinned to a known-good
# version so nothing leaks in.
MESON_PIN="${MESON_PIN:-1.7.2}"
MESON_VENV="$DXMT_SRC/toolchains/meson-venv"
if [[ ! -x "$MESON_VENV/bin/meson" ]] \
    || [[ "$("$MESON_VENV/bin/meson" --version 2>/dev/null)" != "$MESON_PIN" ]]; then
    log_info "Setting up isolated meson $MESON_PIN"
    python3 -m venv --clear "$MESON_VENV"
    "$MESON_VENV/bin/pip" install --quiet --disable-pip-version-check "meson==$MESON_PIN" ninja
fi
MESON="$MESON_VENV/bin/meson"
[[ -x "$MESON" ]] || die "meson venv setup failed"
export MESON

if [[ ! -d "$DXMT_SRC/.git" ]]; then
    log_info "Cloning $DXMT_FORK_URL ($DXMT_FORK_BRANCH)"
    git clone --branch "$DXMT_FORK_BRANCH" "$DXMT_FORK_URL" "$DXMT_SRC"
else
    log_info "Updating DXMT fork"
    git -C "$DXMT_SRC" fetch origin "$DXMT_FORK_BRANCH" || true
    if git -C "$DXMT_SRC" diff --quiet && git -C "$DXMT_SRC" diff --cached --quiet; then
        git -C "$DXMT_SRC" checkout "$DXMT_FORK_BRANCH"
        git -C "$DXMT_SRC" merge --ff-only "origin/$DXMT_FORK_BRANCH" 2>/dev/null || true
    fi
fi
git -C "$DXMT_SRC" submodule update --init --recursive

if [[ ! -f "$LLVM_PREFIX/lib/libLLVMCore.a" ]]; then
    log_warn "Building LLVM 15 x86_64 (~30 min, one-time)"
    if [[ ! -d "$LLVM_SRC_DIR" ]]; then
        git clone --branch "$LLVM_VERSION_TAG" --depth 1 \
            https://github.com/llvm/llvm-project.git "$LLVM_SRC_DIR"
    fi
    _llvm_build_dir="$LLVM_SRC_DIR/build"
    mkdir -p "$_llvm_build_dir"
    cmake -S "$LLVM_SRC_DIR/llvm" -B "$_llvm_build_dir" \
        -DLLVM_ENABLE_PROJECTS="" \
        -DLLVM_TARGETS_TO_BUILD="X86;AArch64" \
        -DLLVM_BUILD_TOOLS=OFF \
        -DLLVM_BUILD_EXAMPLES=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_ENABLE_RTTI=ON \
        -DCMAKE_BUILD_TYPE=Release \
        "-DCMAKE_OSX_ARCHITECTURES=x86_64" \
        "-DCMAKE_INSTALL_PREFIX=$LLVM_PREFIX"
    cmake --build "$_llvm_build_dir"
    cmake --install "$_llvm_build_dir"
fi
[[ -f "$LLVM_PREFIX/lib/libLLVMCore.a" ]] || die "LLVM build failed"

if [[ ! -x "$WINE_TOOLCHAIN/bin/winebuild" ]]; then
    _wine_tarball="$DXMT_SRC/toolchains/wine.tar.gz"
    mkdir -p "$DXMT_SRC/toolchains"
    if [[ ! -f "$_wine_tarball" ]]; then
        curl -fL -o "$_wine_tarball" "$WINE_TARBALL_URL"
    fi
    mkdir -p "$WINE_TOOLCHAIN"
    tar -xzf "$_wine_tarball" -C "$WINE_TOOLCHAIN"
    # Some tarballs nest everything under a single top dir (wine-*/), others
    # extract flat (./bin, ./lib). Normalise so bin/winebuild is at the root.
    if [[ ! -x "$WINE_TOOLCHAIN/bin/winebuild" ]]; then
        _nested=$(find "$WINE_TOOLCHAIN" -mindepth 2 -maxdepth 2 -type f -name winebuild -path '*/bin/winebuild' | head -n1)
        if [[ -n "$_nested" ]]; then
            _nested_root=$(dirname "$(dirname "$_nested")")
            shopt -s dotglob
            mv "$_nested_root"/* "$WINE_TOOLCHAIN"/
            shopt -u dotglob
        fi
    fi
fi
[[ -x "$WINE_TOOLCHAIN/bin/winebuild" ]] || die "Wine toolchain missing"

xcodebuild -downloadComponent MetalToolchain 2>/dev/null || true

cd "$DXMT_SRC"
llvm_rel=$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$LLVM_PREFIX" "$DXMT_SRC")
wine_rel=$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$WINE_TOOLCHAIN" "$DXMT_SRC")

if [[ ! -d build ]]; then
    arch -arm64 "$MESON" setup --cross-file build-win64.txt \
        -Dnative_llvm_path="$llvm_rel" \
        -Dwine_install_path="$wine_rel" \
        build --buildtype release
fi
arch -arm64 "$MESON" compile -C build

if [[ ! -d build32 ]]; then
    arch -arm64 "$MESON" setup --cross-file build-win32.txt \
        -Dwine_install_path="$wine_rel" \
        build32 --buildtype release
fi
arch -arm64 "$MESON" compile -C build32

install_file() {
    local src=$1 dst=$2
    [[ -f "$src" ]] || die "Missing: $src"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
}

install_file "$DXMT_SRC/build/src/winemetal/unix/winemetal.so" "$WINE_UNIX/winemetal.so"

while IFS= read -r -d '' f; do
    name=$(basename "$f")
    case "$name" in
        d3d11.dll|d3d10core.dll|dxgi.dll|winemetal.dll)
            install_file "$f" "$WINE_WIN64/$name"
            ;;
    esac
done < <(find "$DXMT_SRC/build" -name "*.dll" -print0)

while IFS= read -r -d '' f; do
    name=$(basename "$f")
    case "$name" in
        d3d11.dll|d3d10core.dll|dxgi.dll|winemetal.dll)
            install_file "$f" "$WINE_WIN32/$name"
            ;;
    esac
done < <(find "$DXMT_SRC/build32" -name "*.dll" -print0 2>/dev/null)

cp "$WINE_WIN64/winemetal.dll" "$PREFIX_SYS32/winemetal.dll"
cp "$WINE_WIN32/winemetal.dll" "$PREFIX_SYSWOW64/winemetal.dll"

mkdir -p "$DXMT_ROOT"
rm -rf "$DXMT_ROOT"/{i386-windows,x86_64-windows,x86_64-unix}
cp -R "$WINE_WIN32" "$DXMT_ROOT/i386-windows"
cp -R "$WINE_WIN64" "$DXMT_ROOT/x86_64-windows"
mkdir -p "$DXMT_ROOT/x86_64-unix"
cp "$WINE_UNIX/winemetal.so" "$DXMT_ROOT/x86_64-unix/winemetal.so"

log_ok "DXMT fork installed (game rendering)"
