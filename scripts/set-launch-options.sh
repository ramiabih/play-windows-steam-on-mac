#!/usr/bin/env bash
# Set Steam per-game launch options in localconfig.vdf.
# Usage: ./scripts/set-launch-options.sh <appid> "<options>"
# Example: ./scripts/set-launch-options.sh 4704690 "-d3d11 -windowed"

set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"
require_prefix_initialised

APPID="${1:-}"
OPTIONS="${2:-}"
[[ -n "$APPID" && -n "$OPTIONS" ]] || die "Usage: $0 <appid> \"<launch options>\""

STEAM_USERDATA="$WINEPREFIX/drive_c/Program Files (x86)/Steam/userdata"
CONFIG=$(find "$STEAM_USERDATA" -path '*/config/localconfig.vdf' 2>/dev/null | head -n1)
[[ -f "$CONFIG" ]] || die "localconfig.vdf not found under $STEAM_USERDATA"

python3 - "$CONFIG" "$APPID" "$OPTIONS" <<'PY'
import re, sys
path, appid, options = sys.argv[1:4]
with open(path, 'r', encoding='utf-8', errors='surrogateescape') as f:
    data = f.read()

apps_m = re.search(r'"apps"\s*\{', data)
if not apps_m:
    sys.stderr.write(f'"apps" section not found in {path}\n')
    sys.exit(1)

apps_start = apps_m.end()
apps_tail = data[apps_start:]
block_re = re.compile(
    rf'^(\s*)"{re.escape(appid)}"\s*\n\1\{{',
    re.MULTILINE,
)
m = block_re.search(apps_tail)
if not m:
    sys.stderr.write(f'AppID {appid} not found under apps in {path}\n')
    sys.exit(1)

block_start = apps_start + m.start()
indent = m.group(1)
open_brace = apps_start + m.end() - 1
depth = 0
close_idx = None
for i in range(open_brace, len(data)):
    if data[i] == '{':
        depth += 1
    elif data[i] == '}':
        depth -= 1
        if depth == 0:
            close_idx = i
            break
if close_idx is None:
    sys.stderr.write(f'AppID {appid} block not closed in {path}\n')
    sys.exit(1)

inner_start = open_brace + 1
inner = data[inner_start:close_idx]
inner = re.sub(r'\n\s*"LaunchOptions"\s+"[^"]*"', '', inner)
if not inner.endswith('\n'):
    inner += '\n'
inner += f'{indent}\t"LaunchOptions"\t\t"{options}"'
data = data[:inner_start] + inner + data[close_idx:]

with open(path, 'w', encoding='utf-8', errors='surrogateescape') as f:
    f.write(data)
print(f'Set LaunchOptions for {appid}: {options}')
PY

log_ok "Restart Steam for launch options to take effect"
