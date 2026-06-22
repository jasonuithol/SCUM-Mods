#!/usr/bin/env bash
# Package the extension bundle into a distributable zip for Nexus Mods.
# Usage: ./package.sh
# Produces dist/scum-vortex-extension-<version>.zip with info.json + index.js at
# the archive ROOT (Vortex requires the manifest/entry at top level).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ext="$here/extension"
repo="$(cd "$here/.." && pwd)"
dist="$repo/dist"

version="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$ext/info.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
out="$dist/scum-vortex-extension-$version.zip"

mkdir -p "$dist"

# zip via python (portable; no `zip` dependency on Windows git-bash) — same
# approach the mod package.sh scripts use.
python - "$ext" "$out" <<'PY'
import sys, os, zipfile
ext, out = sys.argv[1], sys.argv[2]
if os.path.exists(out): os.remove(out)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(ext):
        for f in files:
            full = os.path.join(root, f)
            z.write(full, os.path.relpath(full, ext))   # arcname relative to extension/ root
print("packaged:", out, os.path.getsize(out), "bytes")
PY