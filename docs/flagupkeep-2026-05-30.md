# FlagUpkeep — build write-up & handoff (2026-05-30)

Server-side UE4SS mod that auto-repairs a flag's base elements to full, paid for
with **repair points** banked from toolboxes. Built in one session on top of
GarbageGoober's gating lineage. This doc captures the design, the reverse
engineering it took, the current state, and exactly where to resume.

---

## 1. What it does

- Players build a chest/wardrobe in their flag named exactly **`FlagUpkeep`** and
  put toolboxes in it.
- **`upkeep deposit`** (chest **open**) converts each toolbox's charges into
  **repair points** for that flag and removes the box. Values: `Tool_Box`=100,
  `Tool_Box_Small`=50, `Improvised_Tool_Box`=20.
- Every cycle (default **1 h**) the mod repairs elements below the flag's
  **trigger** health, spending **1 repair point per element** (restores to full
  from any level). Uses the banked balance only → works unattended.
- Access is gated per-player / per-flag / default, exactly like GarbageGoober
  (same `SCUM.db` owner lookup). Per-flag `upkeep trigger <percent>`.

Commands (normal chat): `upkeep` (help), `deposit`, `check`, `now`, `trigger`,
`pause`/`resume`; admin: `pause-all`/`resume-all`, `reload`, `list`, `status`,
`add`/`remove`, `flag`, `default`, `get`/`set-access-msg`, `damage` (test tool,
gated by `allowTestDamage`).

---

## 2. The reverse engineering (what made it possible)

The hard parts, in the order they fell. Full detail is in memory
(`reference-scum-base-building-architecture`, `reference-scum-item-inventory-model`,
`reference-scum-save-db`); recon was driven through the `#lsr` harness
(`Mods/LootSorterRecon`, PASS 33–41).

1. **Base-element repair is drivable server-side.** The per-element `BaseElementId`
   that blocked FlagUpgrade is in `SCUM.db` as `base_element.element_id` (with
   `base_id`, `location_*`, `element_health`). The game's own repair fires
   `ConZBaseManager:NetMulticast_InteractWithElement(dataVersion, 170
   RepairBaseElement, baseData{BaseId,BaseLocation}, elemData{BaseElementId,
   BaseElementLocation, RepairValue, …}, User:APrisoner)`. Driven from Lua with a
   large `RepairValue` it **clamps the element to full HP**, no crash, and persists
   (verified: a repaired element read 0.9997 in the DB after a save). This partly
   overturns the old "interaction-RPC no-ops" conclusion — that was specific to
   *upgrade* (which is destroy+respawn); *repair* genuinely uses this multicast.
   `ApplyDamageToBaseElement(…,+amt)` also works (used by the test-damage tool);
   negative amt heals but is UNCLAMPED (overshoots), so repair uses the 170 path.

2. **Item charges** live on `UDiscreteUsageItemComponent._repQuantity`, read off a
   live item via `item:GetComponentByClass(StaticFindObject(
   "/Script/SCUM.DiscreteUsageItemComponent"))`.

3. **Virtualization is the villain.** Items in a *placed* chest virtualize out of
   `FindAllOf("Item")` when the chest isn't being accessed; standing next to a
   closed chest surfaces the item *shells* but their data reads 0; **opening the
   chest fully de-virtualizes them** (real charges populate). There is no
   reflectable item list on the inventory, and *tracing a virtualized item's
   internals natively crashes the server* (pcall can't catch it). → we can't read
   chest contents reliably at arbitrary times.

4. **Hence the repair-points model.** Read the toolboxes once, while the player has
   the chest open (`upkeep deposit`), bank their charges as a persistent per-flag
   point balance, and consume the boxes. Repair spends the balance — no live item
   reads at repair time → reliable and unattended.

---

## 3. Architecture

```
Mods/shared/Scripts/gating.lua      shared library (NOT a mod; UE4SS ignores it)
Mods/FlagUpkeep/Scripts/main.lua    loads Config + gating + upkeep; arms timer; chat hook
Mods/FlagUpkeep/Scripts/upkeep.lua  mod-specific engine (repair, points, deposit, trigger, dispatch)
Mods/FlagUpkeep/Scripts/Config.lua  operator settings
Mods/FlagUpkeep/{README, install-libraries.*}
```

**Shared lib** (`Gating.attach(M, opts)`): installs onto the mod's namespace the
reflection helpers, world enumeration, the read-only `SCUM.db` reader, the
entitlement store + resolution, the common access commands, and `reply`/
`onChatMessage`. The mod supplies (via opts): `storeExtra` (extra per-flag store
maps the lib (de)serialises — FlagUpkeep passes `triggerOverrides` floatmap +
`repairPoints` intmap), `defaultNotEnabled`, `statusExtra`. The mod keeps its
action, help text, `handleCommand` dispatch, and mod-specific commands.

**Gotcha:** changing `main.lua` requires a **server restart** (`upkeep reload`
re-runs the *old* in-memory main, which wouldn't attach the lib). `Scripts`-only
changes (Config/upkeep) can use `upkeep reload`.

**GarbageGoober is NOT migrated** to the lib: its eval/demo build bakes
`sorter.lua` into the encrypted `goober-core.exe`, so depending on an external lib
complicates/weakens that protection. Decide later whether to migrate it (and how
to handle the eval build) or keep its copy.

### Two lag effects (inherent, documented)
- **DB health lag:** `element_health` is read from `SCUM.db`, which updates only on
  the server's periodic save (~min). So damage/repair take a save to show in
  `upkeep check`/DB. A per-element cooldown (`repairCooldownSec`, default 300)
  stops a quick re-run from spending a second point before the DB catches up.
- **Client visual lag:** connected clients don't redraw repaired integrity until
  they re-sync (relog / move away+back) — the `dataVersion` replication tag. The
  repair is applied + persisted server-side regardless.

---

## 4. Status & resume

**Working/verified:** deposit → points → repair → elements restored to full,
persists across save + relog. Points economy correct. Per-flag trigger, the gate,
the admin test-damage tool all functional.

**Done but needs a fresh smoke test:** the shared-lib extraction + FlagUpkeep
migration (deployed; verify the access commands — `status`/`list`/`add`/`flag`/
`default`/`pause` — still behave after the refactor).

**Deployed, AWAITING verification:** the deposit-persistence fix. `upkeep deposit`
now removes boxes via `Server_InventoryComponent_RemoveEntry` (persists) instead of
`K2_DestroyActor` (in-memory only — boxes returned on relog = a dupe). **To
verify:** deposit → relog → boxes stay gone, points unchanged; and confirm the
removed box isn't merely dropped to the floor (if it is, chain a destroy).

**Git:** commit `fd1e24a` = the PRE-lib points version. The **lib extraction +
FlagUpkeep refactor + deposit fix are UNCOMMITTED** (working tree). The recon
scratch `Mods/LootSorterRecon/Scripts/live.lua` stays uncommitted by convention.

**Next steps (in order):**
1. Verify deposit persistence (relog) + floor check.
2. Smoke-test the post-refactor access commands.
3. Commit the lib + FlagUpkeep refactor + deposit fix.
4. (Optional) push; migrate GarbageGoober onto the lib (mind its eval build);
   build a FlagUpkeep eval/demo build if it's to be distributed.

**Deployed config note:** the server's `FlagUpkeep/Config.lua` has
`allowTestDamage=true` for testing; the repo default is `false` (keep it false on
real servers).
