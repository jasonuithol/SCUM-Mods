# ScumDevGate

UE4SS C++ mod that unlocks SCUM's **tier-4 "developer" admin commands** on a
dedicated server — chiefly:

```
#UpgradeBaseBuildingElementsWithinRadius <radius>
```

which upgrades every base element in radius to max tier, **online, no restart**,
using SCUM's own native code path. It patches the in-memory `IsDeveloper`
predicate at boot; it does **not** modify `SCUMServer.exe` on disk.

> Self-hosted / authorised servers only. This widens what any admin-tier account
> can do (it opens *all* tier-4 commands, not just the upgrade).

## How it works

SCUM admin commands are `UAdminCommand_*` objects with a required-tier byte at
`+0x52`; tier 4 = developer, checked against an in-memory developer-ID set that
is empty on retail. One shared predicate returns that bool in `AL`. The mod
overwrites its first 3 bytes with `B0 01 C3` (`mov al,1 ; ret`) → always "is
developer" → tier-4 commands open.

The predicate address shifts every SCUM build, so the mod doesn't hardcode it.
It AOB-scans `.text` for the gate logic and follows the call:

```
E8 ?? ?? ?? ??  80 7F 52 04  75 ??  84 C0  75 ??  48 8D 05
└ call IsDev ┘  └cmp [rdi+52],4┘ jne  test  jne     lea -> "Player must be developer."
```

then cross-checks the trailing `LEA` resolves to the `"Player must be developer."`
string before patching. No match → patches nothing (fail safe). Full RE writeup:
`docs/devgate-online-upgrade-SOLVED-2026-05-26.md`.

## Build

Needs [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) (`x86_64-w64-mingw32-clang++`):

```bash
bash build.sh        # -> dlls/main.dll
```

Pure Win32 + UCRT; depends only on `KERNEL32.dll` + the OS Universal CRT.

## Install

1. Copy this folder's `dlls/main.dll` to
   `<server>\SCUM\Binaries\Win64\ue4ss\Mods\ScumDevGate\dlls\main.dll`.
2. Add to `…\ue4ss\Mods\mods.txt`:  `ScumDevGate            : 1`
3. (Re)start the server. Confirm via `dlls\devgate.log`:
   `PATCHED predicate 0x... -> B0 01 C3. Tier-4 developer commands unlocked.`
4. An elevated/admin user runs `#UpgradeBaseBuildingElementsWithinRadius <radius>`
   while standing in the base.

Requires server-side UE4SS injection (same as any UE4SS server mod) and the
account already having admin/elevated rights to issue `#` commands at all.

## When SCUM updates

The AOB is anchored on the gate logic + the reject string, so it normally keeps
working across patches. If `devgate.log` says **"dev gate not located"**, the gate
changed — re-derive it with the procedure in the docs (or run
`tools/devgate_patch.py`, which uses the same locator, to confirm). The mod never
blind-writes, so a stale signature is harmless: it just does nothing.

## Related

- `tools/devgate_patch.py` — static on-disk variant (same locator) for hosts that
  don't allow injection but let you patch/upload the server binary.
