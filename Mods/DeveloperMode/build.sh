#!/usr/bin/env bash
# Build ScumDevGate UE4SS C++ mod -> dlls/main.dll
# Needs llvm-mingw (x86_64-w64-mingw32-clang++) on PATH or at /c/llvm-mingw/bin.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
CXX="${CXX:-/c/llvm-mingw/bin/x86_64-w64-mingw32-clang++}"
mkdir -p "$here/dlls"
"$CXX" -O2 -s -shared -static -static-libgcc -static-libstdc++ \
    -fno-exceptions -fno-rtti \
    -o "$here/dlls/main.dll" "$here/src/main.cpp" \
    -lkernel32
echo "built: $here/dlls/main.dll"
