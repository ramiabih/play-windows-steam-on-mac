#!/usr/bin/env bash
# Open Steam Store checkout in your Mac browser (reliable fallback for Wine CEF payments).
set -euo pipefail
url="${1:-https://store.steampowered.com/cart/}"
open "$url"
