# DeveloperMode

A server-side mod for **SCUM dedicated servers** that unlocks the game's built-in
**developer-tier admin commands** — the ones GamePires gated above the normal
admin/elevated tiers, which return *"Player must be developer."* for everyone on
a retail server — and lets you choose **which executor tiers** are allowed to use
them. The headline command:

```
#UpgradeBaseBuildingElementsWithinRadius <radius>
```

upgrades every base-building element within `<radius>` (cm) of you to its max tier
— **online, no restart, persistent** — using SCUM's own native code.

> **Admins only — by design.** Access is controlled per executor tier in
> `DeveloperMode.ini`. By default **Regular players are denied** and Admin /
> SuperAdmin / Elevated / Developer are allowed. (Earlier builds of this mod
> opened the developer tier to *everyone* — that is fixed; see below.)

> **Server operators only.** This patches your dedicated-server process in memory,
> which requires file-system access to the server and UE4SS injection — i.e. a
> server you run/administer. It does nothing on a client and cannot affect a
> server you don't control. Use it on your own / authorised servers.

## Requirements

- A **SCUM dedicated server** you administer (SteamCMD app `3792580`).
- **UE4SS injected server-side** (the same setup used by other SCUM server mods).
  UE4SS must be able to load into `SCUMServer.exe`.
- The server launched so injection is allowed (self-hosted: BattlEye is
  client-side and not involved server-side; on a rented host, server-side mod/DLL
  injection must be permitted).
- An account with the relevant tier (Admin via `AdminUser.ini`, or Elevated via
  the `elevated_users` table) to actually issue `#` commands.

## Install

1. Copy the **`DeveloperMode`** folder into your server's UE4SS mods directory so
   you have:
   ```
   <server>\SCUM\Binaries\Win64\ue4ss\Mods\DeveloperMode\dlls\main.dll
   <server>\SCUM\Binaries\Win64\ue4ss\Mods\DeveloperMode\DeveloperMode.ini
   ```
2. *(Optional)* Edit **`DeveloperMode.ini`** to choose which tiers may run
   developer commands (see below). The default already denies Regular players.
3. Enable it in `…\ue4ss\Mods\mods.txt` by adding:
   ```
   DeveloperMode : 1
   ```
4. Start the server. Confirm it worked in
   `…\ue4ss\Mods\DeveloperMode\dlls\DeveloperMode.log`:
   ```
   config loaded: Regular=OFF Admin=ON SuperAdmin=ON Elevated=ON Developer=ON
   located: validator=0x... gate=0x... canExec=0x... | tierOff=0x52 ...
   INSTALLED: developer-tier commands are now gated by DeveloperMode.ini (per-executor-tier).
   ```
5. In-game, an allowed admin stands in the base and runs e.g.
   `#UpgradeBaseBuildingElementsWithinRadius 5000`. A Regular player who tries it
   still gets *"Player must be developer."*

## Configuration (`DeveloperMode.ini`)

The file lives in the mod folder and is read **once at server start** (edit, then
restart). Each SCUM executor tier is `ON` (may run developer commands) or `OFF`:

```
Regular    = OFF      # normal connected players
Admin      = ON       # AdminUser.ini admins
SuperAdmin = ON
Elevated   = ON       # users in elevated_users (e.g. via tools/elevate.py)
Developer  = ON       # GamePires developer tier (empty on retail)
```

If the file is missing, the same defaults apply (Regular **OFF**, all others
**ON**). Values accept `ON`/`OFF` (also `true`/`false`, `1`/`0`).

## How it works

Every SCUM admin command carries a required-tier byte
(`EExecutorStatus`: Regular 0, Admin 1, SuperAdmin 2, Elevated 3, Developer 4).
For a developer-tier command the per-command validator asks a global
`IsDeveloper()` predicate — empty on retail, so nobody passes.

DeveloperMode installs a tiny in-memory hook on that validator. When a
**developer-tier** command is run, the hook asks the game's **own** authorization
function what the caller's actual tier is, then allows the command only if that
tier is `ON` in `DeveloperMode.ini`. Regular players are denied and still get the
normal *"Player must be developer."* reply; the game's own dispatcher runs the
command for allowed tiers (no save-file edits, no reconstructed game state).

It does **not** modify `SCUMServer.exe` on disk — the hook is applied to memory
each boot and vanishes when the process exits.

All addresses move with every SCUM build, so nothing is hardcoded: the mod
AOB-scans for the gate logic and cross-checks it against the *"Player must be
developer."* / *"Not authorized to execute command."* strings before touching
anything. If the pattern ever stops matching, it logs the failure and installs
**no** hook — it never blind-writes, and it fails **safe** (the developer tier
simply stays locked for everyone, exactly like vanilla).

> **Note — the all-access bug (fixed).** Previous versions patched `IsDeveloper`
> to always return `true`, which unlocked developer commands for **every**
> connected player. This version replaces that with the per-tier hook above, so
> Regular players are denied by default.

## When SCUM updates

Usually nothing to do — the AOB re-locates everything on the next boot. If
`DeveloperMode.log` says it could not locate the gate/validator, the binary
changed and the mod needs an updated signature; check the mod page for a new
version. Until then the developer tier stays locked (safe).

## License

All rights reserved — see `LICENSE`. Personal use on servers you administer; no
redistribution or reuse without permission.
