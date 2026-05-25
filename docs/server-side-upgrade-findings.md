# Server-side / online bulk-upgrade — investigation & findings (2026-05-25)

Goal: let a server admin **bulk-upgrade a chosen player's base on a live, online
server** (no restart), instead of god-mode-filling each element by hand.

This documents what was tried and the definitive conclusion, so the dead ends
don't get re-walked. The working method today remains the offline DB edit
(`tools/db_tier.py`); everything below is about whether an *online* route exists.

## TL;DR

- SCUM's native **`#UpgradeBaseBuildingElementsWithinRadius <r>`** is exactly the
  feature — upgrades every element in radius to max — but it's **gated** as an
  internal/developer command.
- "Developer" access is grantable on a real server via the **`elevated_users`**
  table in `SCUM.db` (see `tools/elevate.py`). That genuinely unlocks dev
  commands (`#SetStamina`, `#SpawnItem2`, …) — **but NOT this command.** It sits
  in a higher "internal" tier.
- **Server-side UE4SS works** (injected into `SCUMServer.exe`) and we can hook
  the admin-command RPC with full player context — but invoking the command
  **server-side is rejected too**: the gate checks the *player's* privilege, not
  the call origin.
- There is **no callable `ProcessCommand`/upgrade UFunction**, **no settable
  developer flag**, and **no reflectable per-element registry** (element IDs/HP
  live in native C++ with no UProperty exposure) — so we can't drive the upgrade
  ourselves either.
- **Only remaining route:** an AOB memory-patch of the native gate (a C++ UE4SS
  mod or a static exe patch), as `scum_allow_mods` does for the signature check.
  Version-fragile, and its live viability depends on the host allowing
  server-side injection under BattlEye. **Parked.**

## Granting developer access — `tools/elevate.py`

On a dedicated server, add a player's Steam64 to the `elevated_users` table in
`<server>/SCUM/Saved/SaveFiles/SCUM.db` (server stopped → insert → restart).
`tools/elevate.py` does this safely (dry-run default, refuses while the server
holds the DB, backs up first, WAL-checkpoints). Verified: the elevated user gains
real developer commands. The `#UpgradeBaseBuildingElementsWithinRadius` command,
however, still returns **"player must be a developer."**

## Server-side UE4SS (the reusable platform we built)

UE4SS injects into `SCUMServer.exe` via the standard `dwmapi.dll` proxy (the
server exe statically imports `dwmapi`). On a self-hosted test server with
BattlEye off, this is safe and works. Config notes:

- Reuse the AllowMods bundle layout (`dwmapi.dll` + `ue4ss/`), headless-friendly
  (`ConsoleEnabled`/`GuiConsoleEnabled = 0`).
- For Lua `RegisterHook` to work, enable `HookProcessInternal = 1` and
  `HookProcessLocalScriptFunction = 1` in `UE4SS-settings.ini` (the AllowMods
  bundle ships them off).

`Mods/BulkUpgrade/Scripts/main.lua` is a **server-side hot-reload harness**:
there's no F11 on a headless server, so it hooks
`/Script/SCUM.PlayerRpcChannel:Chat_Server_ProcessAdminCommand` and, when the
admin types **`#bu`** in chat, re-reads and executes an external `live.lua`. This
gives a no-restart iteration loop *and* hands `live.lua` the calling player's
context (`BU.channel` = the `PlayerRpcChannel`, `BU.controller` = their
`BP_ConZPlayerController_C`) — which would also auto-scope an upgrade to where
the admin stands.

## What the reflection sweep proved (all server-side)

| Probe | Result |
| :--- | :--- |
| Call `Chat_Server_ProcessAdminCommand("UpgradeBaseBuildingElementsWithinRadius 5000")` server-side | **"player must be a developer"** — gate is player-privilege based, not call-origin. |
| Functions on `PlayerRpcChannel` (132), `ConZGameMode` (14), `ConZBaseManager` (14) | No `ProcessCommand`/`Upgrade*`; manager has only `NetMulticast_Destroy*`. |
| `UpgradeBaseBuildingElementsWithinRadius` as a UFunction (probed many classes) | Not found — native-only dispatch inside the command processor. |
| Developer/privilege **property** on controller / player-state / channel | None (privilege is an in-memory Steam-ID set from `elevated_users`). |
| Element registry: `ConZBaseManager` (only `_bases` map), `ConZBase` (only `_baseElementActor`), `ConZBaseElement` (only the cosmetic HISM `_elementClassMap`) | **No per-element IDs/data** — can't drive destroy+respawn or the `UpgradeBaseElement` (180) interaction ourselves. |

## Conclusion & options

- **Native patch** (only path to the online/native ideal): RE the gate in the
  server binary and flip it, delivered as a C++ UE4SS mod or static exe patch.
  Real reverse-engineering, breaks on each SCUM update, and needs the host to
  allow server-side injection under BattlEye (unconfirmed). Parked.
- **DB edit + restart** (works today): `tools/db_tier.py --playerid <id>` on the
  live server's `SCUM.db`, applied in a restart/maintenance window. No RE, no
  fragility — just not restart-free.
