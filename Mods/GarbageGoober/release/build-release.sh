#!/usr/bin/env bash
# Build a GarbageGoober EVAL package: the engine is encrypted and BAKED INTO
# goober-core.exe, decrypted in memory at runtime; the exe also carries the
# native time-bomb. No payload.bin, and no clean Config.lua/sorter.lua, are shipped.
#
#   ./build-release.sh                    # default 30-day expiry
#   DAYS=14 ./build-release.sh            # custom window (days from now)
#   EXPIRY_EPOCH=1750000000 ./build-release.sh   # exact unix epoch
#   DAYS=0 ./build-release.sh             # no time-bomb (testing only)
#
# Needs llvm-mingw (x86_64-w64-mingw32-clang++) on PATH or at /c/llvm-mingw/bin,
# same as Mods/DeveloperMode/build.sh.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
mod="$(cd "$here/.." && pwd)"          # Mods/GarbageGoober
scripts="$mod/Scripts"
out="$mod/dist/GarbageGoober"          # under dist/ -> gitignored
CXX="${CXX:-/c/llvm-mingw/bin/x86_64-w64-mingw32-clang++}"
DAYS="${DAYS:-30}"

if [ -n "${EXPIRY_EPOCH:-}" ]; then
    expiry="$EXPIRY_EPOCH"
elif [ "$DAYS" = "0" ]; then
    expiry=0
else
    expiry="$(date -d "+${DAYS} days" +%s)"
fi

rm -rf "$out"; mkdir -p "$out/Scripts"
build="$mod/dist/.build"; rm -rf "$build"; mkdir -p "$build"   # temp, under dist/ (gitignored)

# 1. temp "packer" build (no embed/expiry) — gives us packh + wrap
"$CXX" -O2 -s -static -static-libgcc -static-libstdc++ -fno-exceptions -fno-rtti \
    -o "$build/packer.exe" "$here/goober-core.cpp" -lkernel32

# 2. pack the clean engine into an embeddable C header (cygpath -> real Windows
#    paths so the exe's CRT can open them regardless of MSYS path mangling)
"$build/packer.exe" packh "$(cygpath -w "$scripts")" "$(cygpath -w "$build/payload_data.h")"

# 3. obfuscate the bootstrap into the stub main.lua (modDir = the editable line)
moddir='C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\GarbageGoober'
"$build/packer.exe" wrap "$(cygpath -w "$here/bootstrap.lua")" "$(cygpath -w "$out/Scripts/main.lua")" "$moddir"

# 4. compile the FINAL goober-core.exe with the engine BAKED IN + the time-bomb
#    (so the shipped package needs no payload.bin)
"$CXX" -O2 -s -static -static-libgcc -static-libstdc++ -fno-exceptions -fno-rtti \
    -DGG_EMBEDDED -I"$(cygpath -m "$build")" -DGG_EXPIRY="$expiry" \
    -o "$out/goober-core.exe" "$here/goober-core.cpp" -lkernel32

# 5. support files + tester README (+ expiry date)
[ -f "$mod/install-libraries.ps1" ] && cp "$mod/install-libraries.ps1" "$out/"
[ -f "$mod/install-libraries.cmd" ] && cp "$mod/install-libraries.cmd" "$out/"
cp "$here/README-eval.md" "$out/README.md"
if [ "$expiry" != "0" ]; then
    printf '\n## Expiry\n\nThis evaluation build stops working after **%s**.\n' \
        "$(date -d "@$expiry" '+%Y-%m-%d %H:%M %z')" >> "$out/README.md"
fi

# 6. zip for shipping (one file to hand over), then drop the temp build dir
zipout="$mod/dist/GarbageGoober-eval.zip"
rm -f "$zipout"
powershell.exe -NoProfile -Command "Compress-Archive -Path '$(cygpath -w "$out")' -DestinationPath '$(cygpath -w "$zipout")' -Force" >/dev/null
rm -rf "$build"

echo "----------------------------------------------------------"
echo "eval package: $out"
echo "shipping zip: $zipout"
if [ "$expiry" = "0" ]; then
    echo "  expiry: NONE (time-bomb disabled)"
else
    echo "  expires: $(date -d "@$expiry" '+%Y-%m-%d %H:%M:%S %z')  (epoch $expiry)"
fi
echo "  package: Scripts/main.lua (obfuscated) + goober-core.exe (engine embedded)"
echo "           + install-libraries.* + README.md   (NO payload.bin)"
