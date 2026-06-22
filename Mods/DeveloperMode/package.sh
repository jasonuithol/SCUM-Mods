#!/usr/bin/env bash
# Package DeveloperMode for distribution (binary-only zip).
# Produces  <repo>/dist/DeveloperMode-<VERSION>.zip  with this layout:
#   README.md
#   LICENSE
#   UE4SS-settings-SCUM.ini           (SCUM-safe UE4SS baseline; see README step 2)
#   DeveloperMode/dlls/main.dll
#   DeveloperMode/DeveloperMode.ini   (per-executor-tier access config)
# Users extract and copy the DeveloperMode/ folder into their server's
#   ...\SCUM\Binaries\Win64\ue4ss\Mods\  (and apply the settings ini per README).
set -euo pipefail
VERSION="${1:-1.1.0}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

bash "$here/build.sh"                                   # -> dlls/main.dll

stage="$repo/dist/DeveloperMode-$VERSION"
rm -rf "$stage"
mkdir -p "$stage/DeveloperMode/dlls"
cp "$here/dlls/main.dll"            "$stage/DeveloperMode/dlls/main.dll"
cp "$here/DeveloperMode.ini"        "$stage/DeveloperMode/DeveloperMode.ini"
cp "$here/UE4SS-settings-SCUM.ini"  "$stage/UE4SS-settings-SCUM.ini"
cp "$here/README.md"                "$stage/README.md"
cp "$here/LICENSE"                  "$stage/LICENSE"

# Vortex manifest (ue4ss.mod.json) — makes this zip installable by the SCUM
# Vortex extension. Placed INSIDE the mod folder so the same zip serves both
# manual install and Vortex (the extension treats this folder as the payload).
cat > "$stage/DeveloperMode/ue4ss.mod.json" <<JSON
{
  "id": "developer-mode",
  "name": "DeveloperMode",
  "version": "$VERSION",
  "folderId": "DeveloperMode",
  "side": "server",
  "loadOrder": 100,
  "ue4ssMinVersion": "3.0.1",
  "author": "Jason Uithol",
  "homepage": "https://github.com/jasonuithol/SCUM-Mods",
  "nexus": { "domain": "scum", "modId": 45 }
}
JSON

# zip via python (portable; no `zip` dependency on Windows git-bash)
python - "$stage" "$repo/dist/DeveloperMode-$VERSION.zip" <<'PY'
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