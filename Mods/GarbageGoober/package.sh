#!/usr/bin/env bash
# Package GarbageGoober for Nexus distribution (full working build).
# Produces  <repo>/dist/GarbageGoober-<VERSION>.zip  with this layout:
#   README.md
#   LICENSE
#   GarbageGoober/Scripts/...          (the mod — self-contained, no shared lib)
# Users extract and copy the GarbageGoober/ folder into their
#   ...\SCUM\Binaries\Win64\ue4ss\Mods\
#
#   ./package.sh            # version 1.0.0
#   ./package.sh 1.2.0      # custom version
set -euo pipefail
MOD="GarbageGoober"
VERSION="${1:-1.0.0}"
here="$(cd "$(dirname "$0")" && pwd)"      # Mods/<MOD>
repo="$(cd "$here/../.." && pwd)"

stage="$repo/dist/$MOD-$VERSION"
rm -rf "$stage"
mkdir -p "$stage/$MOD/Scripts"

# the mod: Lua scripts (+ any data files) — Scripts/ holds no runtime state
cp "$here"/Scripts/*.lua "$stage/$MOD/Scripts/"
for extra in "$here"/Scripts/*.yaml "$here"/Scripts/*.yml "$here"/Scripts/*.json; do
    [ -f "$extra" ] && cp "$extra" "$stage/$MOD/Scripts/"
done
cp "$here/README.md" "$stage/README.md"
cp "$here/LICENSE"   "$stage/LICENSE"

# zip via python (portable; no `zip` dependency on Windows git-bash)
python - "$stage" "$repo/dist/$MOD-$VERSION.zip" <<'PY'
import sys, os, zipfile
stage, out = sys.argv[1], sys.argv[2]
if os.path.exists(out): os.remove(out)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(stage):
        for f in files:
            full = os.path.join(root, f)
            z.write(full, os.path.relpath(full, stage))
print("packaged:", out, os.path.getsize(out), "bytes")
PY
echo "staging dir: $stage"
