#!/usr/bin/env bash
# Build a TIME-LIMITED demo of DeveloperMode. Same DLL as build.sh, but with a
# compile-time expiry baked in (DM_EXPIRY): after it, start_mod logs "expired"
# and does NOT patch the dev gate. The normal build.sh produces a permanent
# build (DM_EXPIRY=0). Output: dist/DeveloperMode-demo/ + dist/DeveloperMode-demo.zip
#
#   ./build-demo.sh                      # 30-day expiry
#   DAYS=14 ./build-demo.sh              # custom window (days from now)
#   EXPIRY_EPOCH=1750000000 ./build-demo.sh   # exact unix epoch
#
# Needs llvm-mingw (x86_64-w64-mingw32-clang++), same as build.sh.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
CXX="${CXX:-/c/llvm-mingw/bin/x86_64-w64-mingw32-clang++}"
DAYS="${DAYS:-30}"

if [ -n "${EXPIRY_EPOCH:-}" ]; then
    expiry="$EXPIRY_EPOCH"
else
    expiry="$(date -d "+${DAYS} days" +%s)"
fi

stage="$repo/dist/DeveloperMode-demo"          # under dist/ -> gitignored
rm -rf "$stage"; mkdir -p "$stage/DeveloperMode/dlls"

# compile the DLL with the expiry baked in (native time-bomb)
"$CXX" -O2 -s -shared -static -static-libgcc -static-libstdc++ \
    -fno-exceptions -fno-rtti \
    -DDM_EXPIRY="$expiry" \
    -o "$stage/DeveloperMode/dlls/main.dll" "$here/src/main.cpp" \
    -lkernel32

cp "$here/README.md" "$stage/README.md"
cp "$here/LICENSE"   "$stage/LICENSE"
printf '\n## Evaluation build\n\nThis is a **time-limited demo**: after **%s** it stops patching the dev gate (it logs "evaluation build EXPIRED" and does nothing). Contact the author for a full build.\n' \
    "$(date -d "@$expiry" '+%Y-%m-%d %H:%M %z')" >> "$stage/README.md"

# zip for shipping (contents at archive root: README.md, LICENSE, DeveloperMode/)
zipout="$repo/dist/DeveloperMode-demo.zip"
rm -f "$zipout"
powershell.exe -NoProfile -Command "Compress-Archive -Path '$(cygpath -w "$stage")\*' -DestinationPath '$(cygpath -w "$zipout")' -Force" >/dev/null

echo "----------------------------------------------------------"
echo "demo package: $stage"
echo "shipping zip: $zipout"
echo "expires:      $(date -d "@$expiry" '+%Y-%m-%d %H:%M:%S %z')  (epoch $expiry)"