# SCUM Server-Side Mods

Server-side mods and reverse-engineering notes for **SCUM** dedicated servers
(UE 4.27.2, build 1.3.x).

Everything here is **server-side**: the mods run inside `SCUMServer.exe` via UE4SS
and require nothing on players' machines, so **client BattlEye can stay on**. They
only affect a server you run/administer.

> **Scope / ethics:** these patch or script a dedicated-server process you own.
> They do nothing on a client and cannot affect a server you don't control. Use
> them only on your own / authorised servers.

---

## Headline mods

### DeveloperMode — unlock the developer-tier admin commands

`Mods/DeveloperMode/` (native C++ UE4SS mod, `dlls/main.dll`)

Unlocks SCUM's built-in **developer-tier** admin commands — the ones GamePires
gated above the normal admin/elevated tiers, which return *"Player must be
developer."* on a retail server. The headline command:

```
#UpgradeBaseBuildingElementsWithinRadius <radius>
```

upgrades every base-building element within `<radius>` cm of you to its max tier —
**online, no restart, persistent** — via SCUM's own native code.

It AOB-scans for the developer-check predicate at boot and patches its first 3
bytes to `mov al,1 ; ret` so it always returns true, opening the whole developer
tier. The patch is applied **in memory each boot** — nothing on disk is modified,
no save/game state is reconstructed. If a future SCUM patch moves the gate, it
logs *"dev gate not located"* and writes nothing (never a blind write).

See `Mods/DeveloperMode/README.md` for install/usage.

### GarbageGoober — auto-sort loose loot into category chests

`Mods/GarbageGoober/` (UE4SS Lua mod)

On a timer it sweeps loose, on-the-floor loot inside a flag's influence and moves
each item into a chest **in that same flag** whose custom name matches the item's
category (built from SCUM's real vendor categories). Flag-scoped and
**entitlement-gated** (per-player primary, per-flag fallback, global default), so
sorting can be sold or granted as a perk. Owner→base links and entitlements are
read from `SCUM.db` read-only via a bundled public-domain `sqlite3.exe`.
Configured and driven entirely from in-game **normal chat** (`goober …`).

See `Mods/GarbageGoober/README.md` for install/usage and the full command list.

### FlagUpkeep — auto-repair a base from banked "repair points"

`Mods/FlagUpkeep/` (UE4SS Lua mod)

On a timer it repairs the base elements in an enabled flag back to full health,
spending **repair points** that owners bank by depositing **toolboxes** into a
chest in that flag. Repair drives the game's own
`NetMulticast_InteractWithElement(170 RepairBaseElement)` per element (ids read
from `SCUM.db`), which clamps to full HP. Reuses GarbageGoober's gating layer:
flag-scoped, entitlement-gated, driven from normal chat (`upkeep …`).

The repair-points economy exists because a placed chest's contents virtualize out
of view, so the mod banks a persistent per-flag balance on **deposit** (chest
open) instead of reading live toolboxes at repair time — letting upkeep run
unattended.

See `Mods/FlagUpkeep/README.md`.

The shared entitlement / chat-command / DB-reader layer that GarbageGoober and
FlagUpkeep both build on lives at `Mods/shared/Scripts/gating.lua` (a library, not
a mod — each mod's `main.lua` loads and runs it).

---

## Tools

Offline helpers for the developer-command workflow (edit a stopped server's
`SCUM.db`; dry-run by default, `--apply` required, backs up first, refuses to run
while the server holds the DB):

- **`tools/elevate.py`** — grant/revoke SCUM **Elevated User** status by editing
  the `elevated_users` table. `python tools/elevate.py --list` /
  `… <steam64> --apply`.
- **`tools/devgate_patch.py`** — the standalone runtime version of the dev-gate
  unlock that **DeveloperMode** now ships as a DLL; kept as the reference
  implementation of the AOB scan + patch.

---

## Research harnesses

These reverse-engineered the base-building / inventory systems the mods rely on.
Not needed to run the mods:

- `Mods/FlagUpgrade/Scripts/main.lua` — client-side UE4SS hot-reload harness (F11
  re-runs a `live.lua`); how the base-building system, interaction RPCs, and
  struct layouts were RE'd.
- `Mods/BulkUpgrade/Scripts/main.lua` — server-side hot-reload harness (`#bu` in
  chat re-runs an external `live.lua` with the caller's player context).
- `Mods/LootSorterRecon/` — inventory/item-model recon scratch for GarbageGoober.
- `Mods/HelloScum/Scripts/main.lua` — minimal UE4SS sanity mod.

---

## Repo layout

```
Mods/
  DeveloperMode/      # native dev-tier unlock (main.dll) — HEADLINE
  GarbageGoober/      # loot auto-sorter (Lua)            — HEADLINE
  FlagUpkeep/         # auto-repair from repair points    — HEADLINE
  shared/Scripts/gating.lua   # shared entitlement/chat/DB lib used by the Lua mods
  FlagUpgrade/        # client-side RE harness
  BulkUpgrade/        # server-side RE harness (#bu -> live.lua)
  LootSorterRecon/    # inventory recon scratch
  HelloScum/          # sanity mod
tools/
  elevate.py          # grant/revoke elevated-user (dev cmds) via SCUM.db
  devgate_patch.py    # standalone runtime dev-gate patch (DeveloperMode = the DLL)
docs/
  *.md                # investigation write-ups + solved findings
  recon/              # research archive (lab notebook + probe scripts)
```

Build outputs, the SCUM-AllowMods bundle, DB backups, downloaded `sqlite3.exe`,
the `live.lua` hot-reload buffer, and per-mod runtime state (`entitlements.lua`,
logs) are git-ignored.

---

## Setup notes

- UE4SS must be injected **server-side** (the "scum-allow-mods" bundle), able to
  load into `SCUMServer.exe`.
- Enable a mod in `…\ue4ss\Mods\mods.txt` (`ModName : 1`). **Never** create an
  `enabled.txt` — it silently overrides `mods.txt`.
- The Lua mods' chat triggers need `HookProcessInternal = 1` and
  `HookProcessLocalScriptFunction = 1` in `ue4ss\UE4SS-settings.ini`.
- Self-hosted servers: BattlEye is client-side and not involved server-side. On a
  rented host, server-side mod/DLL injection must be permitted.
