#!/usr/bin/env bash
# Package MapPing for distribution. Produces  <repo>/dist/MapPing-<VERSION>.zip
# with this layout:
#   README.md
#   LICENSE
#   UE4SS-settings-SCUM.ini      (SCUM-safe UE4SS config; replaces theirs)
#   MapPing/Scripts/...          (the mod — fully self-contained, no shared/ dep)
# Users extract and copy the single MapPing/ folder into their
#   ...\SCUM\Binaries\Win64\ue4ss\Mods\
# (and drop UE4SS-settings-SCUM.ini in as their ...\ue4ss\UE4SS-settings.ini)
#
#   ./package.sh            # version 1.0.0
#   ./package.sh 1.2.0      # custom version
set -euo pipefail
MOD="MapPing"
VERSION="${1:-1.0.0}"
here="$(cd "$(dirname "$0")" && pwd)"      # Mods/<MOD>
repo="$(cd "$here/../.." && pwd)"

ue4ss_ini="$here/UE4SS-settings-SCUM.ini"
[ -f "$ue4ss_ini" ] || { echo "missing UE4SS settings: $ue4ss_ini" >&2; exit 1; }

stage="$repo/dist/$MOD-$VERSION"
rm -rf "$stage"
mkdir -p "$stage/$MOD/Scripts"

# the mod: Lua scripts only (Scripts/ holds no runtime state)
cp "$here"/Scripts/*.lua "$stage/$MOD/Scripts/"
cp "$here/README.md" "$stage/README.md"
cp "$here/LICENSE"   "$stage/LICENSE"
cp "$ue4ss_ini"      "$stage/UE4SS-settings-SCUM.ini"

# zip via python (portable; no `zip` dependency on Windows git-bash)
PY_BIN="$(command -v python || command -v python3)"
[ -n "$PY_BIN" ] || { echo "python not found" >&2; exit 1; }
"$PY_BIN" - "$stage" "$repo/dist/$MOD-$VERSION.zip" <<'PY'
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
