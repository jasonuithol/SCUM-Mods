# DeveloperMode

A server-side mod for **SCUM dedicated servers** that unlocks the game's built-in
**developer-tier admin commands** — the ones GamePires gated above the normal
admin/elevated tiers, which return *"Player must be developer."* for everyone on
a retail server. The headline command:

```
#UpgradeBaseBuildingElementsWithinRadius <radius>
```

upgrades every base-building element within `<radius>` (cm) of you to its max tier
— **online, no restart, persistent** — using SCUM's own native code.

> **Server operators only.** This patches your dedicated-server process in memory,
> which requires file-system access to the server and UE4SS injection — i.e. a
> server you run/administer. It does nothing on a client and cannot affect a
> server you don't control. Use it on your own / authorised servers.

## Requirements

- A **SCUM dedicated server** you administer (SteamCMD app `3792580`).
- **UE4SS injected server-side** (the same setup used by other SCUM server mods,
  e.g. the "scum-allow-mods" bundle). UE4SS must be able to load into
  `SCUMServer.exe`.
- The server launched so injection is allowed (self-hosted: BattlEye is
  client-side and not involved server-side; on a rented host, server-side mod/DLL
  injection must be permitted).
- The account you use must already have admin/elevated rights to issue `#`
  commands.

## Install

1. Copy the **`DeveloperMode`** folder into your server's UE4SS mods directory:
   ```
   <server>\SCUM\Binaries\Win64\ue4ss\Mods\DeveloperMode\dlls\main.dll
   ```
2. Enable it in `…\ue4ss\Mods\mods.txt` by adding:
   ```
   DeveloperMode : 1
   ```
3. Start the server. Confirm it worked in
   `…\ue4ss\Mods\DeveloperMode\dlls\DeveloperMode.log`:
   ```
   PATCHED predicate 0x... -> B0 01 C3. Tier-4 developer commands unlocked.
   ```
4. In-game, an admin stands in the base and runs e.g.
   `#UpgradeBaseBuildingElementsWithinRadius 5000`.

## How it works

SCUM admin commands carry a required-privilege tier; the top tier ("developer")
is checked against an in-memory developer-ID set that is empty on retail servers,
so nobody qualifies. A single shared predicate decides it. DeveloperMode finds
that predicate at boot and patches its first 3 bytes to `mov al,1 ; ret` so it
always returns true — opening the developer tier. The game's own dispatcher then
runs the command with correct context (no save-file edits, no reconstructed game
state).

It does **not** modify `SCUMServer.exe` on disk — the patch is applied to memory
each boot, so the file's integrity is unchanged and the patch vanishes when the
process exits.

The predicate's address moves with every SCUM build, so DeveloperMode doesn't
hardcode it: it AOB-scans for the gate logic, follows the call, and cross-checks
the result against the *"Player must be developer."* string before writing. If the
pattern ever stops matching (a future SCUM patch changed the gate), it logs
*"dev gate not located"* and patches nothing — it never blind-writes.

## When SCUM updates

Usually nothing to do — the AOB re-locates the gate on the next boot. If
`DeveloperMode.log` says *"dev gate not located"*, the gate changed and the mod
needs an updated signature; check the mod page for a new version.

## Notes

- This opens the **entire developer tier**, not only the upgrade command.
- Exactly what it touches: it writes 3 bytes (`B0 01 C3` = `mov al,1 ; ret`) over
  the developer-check predicate in the running `SCUMServer.exe` process — in
  memory only, every boot. Nothing on disk is modified, and no game/save data is
  altered.

## License

All rights reserved — see `LICENSE`. Personal use on servers you administer; no
redistribution or reuse without permission.

