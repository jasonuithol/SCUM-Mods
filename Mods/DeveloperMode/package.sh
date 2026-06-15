#!/usr/bin/env bash
# Package DeveloperMode for distribution (binary-only zip).
# Produces  <repo>/dist/DeveloperMode-<VERSION>.zip  with this layout:
#   README.md
#   LICENSE
#   DeveloperMode/dlls/main.dll
#   DeveloperMode/DeveloperMode.ini   (per-executor-tier access config)
# Users extract and copy the DeveloperMode/ folder into their server's
#   ...\SCUM\Binaries\Win64\ue4ss\Mods\
set -euo pipefail
VERSION="${1:-1.0.0}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

bash "$here/build.sh"                                   # -> dlls/main.dll

stage="$repo/dist/DeveloperMode-$VERSION"
rm -rf "$stage"
mkdir -p "$stage/DeveloperMode/dlls"
cp "$here/dlls/main.dll"       "$stage/DeveloperMode/dlls/main.dll"
cp "$here/DeveloperMode.ini"   "$stage/DeveloperMode/DeveloperMode.ini"
cp "$here/README.md"           "$stage/README.md"
cp "$here/LICENSE"             "$stage/LICENSE"

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