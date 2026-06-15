#!/usr/bin/env bash
# Package ClothesDryer for Nexus distribution (full working build).
# Produces  <repo>/dist/ClothesDryer-<VERSION>.zip  with this layout:
#   README.md
#   LICENSE
#   UE4SS-settings-SCUM.ini            (SCUM-safe UE4SS config; replaces theirs)
#   ClothesDryer/Scripts/...          (the mod, incl. a VENDORED copy of
#                                       gating.lua — the mod is self-contained,
#                                       no external shared/ folder dependency)
# Users extract and copy the single ClothesDryer/ folder into their
#   ...\SCUM\Binaries\Win64\ue4ss\Mods\
# (and drop UE4SS-settings-SCUM.ini in as their ...\ue4ss\UE4SS-settings.ini)
#
#   ./package.sh            # version 1.0.0
#   ./package.sh 1.2.0      # custom version
set -euo pipefail
MOD="ClothesDryer"
VERSION="${1:-1.0.0}"
here="$(cd "$(dirname "$0")" && pwd)"      # Mods/<MOD>
repo="$(cd "$here/../.." && pwd)"
shared="$repo/Mods/shared/Scripts/gating.lua"

[ -f "$shared" ] || { echo "missing shared gating lib: $shared" >&2; exit 1; }
ue4ss_ini="$here/UE4SS-settings-SCUM.ini"
[ -f "$ue4ss_ini" ] || { echo "missing UE4SS settings: $ue4ss_ini" >&2; exit 1; }

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
cp "$ue4ss_ini"      "$stage/UE4SS-settings-SCUM.ini"
# VENDOR the shared gating lib INTO the mod's own Scripts folder so the shipped
# mod is self-contained (no ...\Mods\shared\ dependency). main.lua loads it from
# its own Scripts\gating.lua first.
cp "$shared"         "$stage/$MOD/Scripts/gating.lua"

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
