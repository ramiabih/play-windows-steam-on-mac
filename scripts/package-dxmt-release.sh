#!/usr/bin/env bash
# Package the DXMT fork build into a prebuilt release tarball and (optionally)
# publish it as a GitHub release, so users can download instead of compiling.
#
# Run this after a successful `./install.sh --games` build.
#
# Usage:
#   ./scripts/package-dxmt-release.sh            # just build the tarball
#   ./scripts/package-dxmt-release.sh --publish  # build + create/upload GH release

set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

DXMT_SRC="${DXMT_SRC:-$HOME/dev/dxmt}"
STAGE_DIR="$DXMT_SRC/staging"
TAG="${DXMT_PREBUILT_TAG:-dxmt-fork-v1}"
ASSET="dxmt-fork-macos-arm64.tar.gz"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/dist}"
OUT="$OUT_DIR/$ASSET"
REPO="${RELEASE_REPO:-ramiabih/play-windows-steam-on-mac}"

log_step "Package DXMT prebuilt"

[[ -f "$STAGE_DIR/x86_64-unix/winemetal.so" ]] \
    || die "No staged build at $STAGE_DIR. Run ./install.sh --games first."

# Record provenance so we know exactly what this tarball contains.
fork_commit=$(git -C "$DXMT_SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)
cat > "$STAGE_DIR/MANIFEST.txt" <<EOF
DXMT fork prebuilt for macos-wine-steam
built:        $(date -u +"%Y-%m-%dT%H:%M:%SZ")
dxmt commit:  $fork_commit
wine target:  ${WINE_VERSION}
host macOS:   $(sw_vers -productVersion 2>/dev/null || echo unknown)
EOF

mkdir -p "$OUT_DIR"
tar -czf "$OUT" -C "$STAGE_DIR" \
    x86_64-unix x86_64-windows i386-windows MANIFEST.txt
log_ok "Wrote $OUT ($(du -h "$OUT" | cut -f1))"

if [[ "${1:-}" == "--publish" ]]; then
    require_cmd gh
    log_step "Publishing release $TAG to $REPO"
    if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
        gh release upload "$TAG" "$OUT" --repo "$REPO" --clobber
        log_ok "Updated asset on existing release $TAG"
    else
        gh release create "$TAG" "$OUT" \
            --repo "$REPO" \
            --title "DXMT fork (prebuilt, Apple Silicon)" \
            --notes "Prebuilt DXMT fork for Wine 11 game rendering on Apple Silicon.

Built from notpop/dxmt ($fork_commit). Installed automatically by \`./install.sh --games\` — no compile needed.

To build from source instead: \`DXMT_BUILD_FROM_SOURCE=1 ./install.sh --games\`."
        log_ok "Created release $TAG"
    fi
fi

log_ok "Done"
