# Server-side bulk-upgrade — pivot to native gameplay path (2026-05-26)

Follow-up / correction to `findings 2026-05-25`. Same goal: bulk-upgrade a
chosen player's base on a live, online server. Documents a strategic reframe
that supersedes the "Parked: native patch" conclusion.

## TL;DR

- The 2026-05-25 conclusion that we'd need to AOB-patch the developer gate was
  premature. The dev gate only guards the **chat command surface**. The
  underlying mutation is reachable through the same UFunction path that
  **normal clients use every day** when a player walks up to a wall and
  upgrades it in-game.
- The previous sweep concluded "can't drive the (180) interaction" because no
  per-element ID registry exists. **IDs are not the addressing mechanism** —
  actor references are. UE4SS hands us those via `FindAllOf` / `UObjectArray`.
- New plan: server-side UE4SS Lua mod enumerates `ConZBaseElement` actors,
  filters by distance to flag, and invokes the mutation leaf UFunction directly.
  No binary patching. No BattlEye risk. No AOB fragility. Reuses the existing
  `BulkUpgrade/main.lua` hot-reload harness.

## Why the previous conclusion was wrong

The reflection sweep table read:

> Element registry: `ConZBaseManager` (only `_bases` map), `ConZBase` (only
> `_baseElementActor`), `ConZBaseElement` (only the cosmetic HISM
> `_elementClassMap`) | **No per-element IDs/data** — can't drive
> destroy+respawn or the `UpgradeBaseElement` (180) interaction ourselves.

That second clause is a non-sequitur. Real clients drive interaction (180)
constantly — they don't have IDs either. The client-side flow is:

1. Local interaction trace (raycast from camera) returns an actor pointer.
2. Client RPCs the actor pointer to the server via the interaction RPC.
3. Server-side handler reads the actor off the RPC, runs proximity / squad /
   material checks, and calls a mutation leaf on the element.

We can short-circuit step 1 (we enumerate actors instead of tracing), call
straight into a deeper layer than step 2, and choose how much of step 3 we want
to run.

## The new path

### Architecture

Extension of existing `Mods/BulkUpgrade/Scripts/main.lua`. On `#bu` (or a new
`#upgradeall <r>`):

1. Read the admin's location from `BU.controller` (already exposed by the
   harness).
2. Resolve the flag (nearest `ConZBase`, or accept a flag actor passed in).
3. Enumerate `BP_ConZBaseElement_C` (verify exact leaf class name from SDK
   dump) via `UEHelpers.GetWorld()` traversal or `FindAllOf`.
4. Filter by 3D distance from flag center against the radius arg.
5. For each filtered element, invoke the mutation leaf UFunction with target
   tier = Cement.

### Three candidate call sites

In order of how much checking they skip:

| Layer | Call target (working names — confirm from SDK dump) | Skips |
| :--- | :--- | :--- |
| RPC entry | One of `PlayerRpcChannel`'s 132 functions, likely `Server_*` with `BaseElement` / `Upgrade` in the name | Network layer only |
| Interaction handler | `ConZBaseElement::OnInteract(180, ...)` or `HandleInteraction(180, ...)` | Network + interaction routing |
| **Mutation leaf** | `ConZBaseElement::SetMaterialTier(...)` / `UpgradeToTier(...)` / `ApplyMaterialUpgrade(...)` | All gameplay checks (materials, proximity, squad ownership). **This is the same leaf `#UpgradeBaseBuildingElementsWithinRadius` calls internally** |

The chat admin command is a foreach-in-radius wrapper around the mutation
leaf. We want the leaf directly — no materials cost, no squad ownership
requirement, no proximity. The dev gate doesn't live here; it lives on the
chat dispatch layer that we're not using.

### SDK dump search strategy

If the existing dump from the 2025-05-25 sweep is still around, grep it. If
not, regenerate via UE4SS UHT dumper. Targets:

- All UFunctions on `ConZBaseElement` (and any parent classes). Filter for:
  `Material`, `Tier`, `Upgrade`, `SetMesh`, `Apply`, `Switch`.
- All 132 UFunctions on `PlayerRpcChannel`. Filter for: `BaseElement`,
  `Upgrade`, `Server_`, `Interact`.
- The `EBaseElementMaterial` enum (or whatever it's actually named). Values
  expected: Twig (0), Wood (1), Stone (2), Brick (3), Cement (4). Confirm the
  Cement integer value before hardcoding.

### `live.lua` sketch

```lua
local FLAG_RADIUS_CM = 5000  -- 50m, matches in-game flag radius default
local TARGET_TIER    = 4     -- Cement; CONFIRM from EBaseElementMaterial dump

local admin_loc = BU.controller:K2_GetActorLocation()

local elements = FindAllOf("BP_ConZBaseElement_C")  -- verify exact class name
local upgraded, skipped = 0, 0

for i, elem in ipairs(elements) do
    local elem_loc = elem:K2_GetActorLocation()
    local dx = elem_loc.X - admin_loc.X
    local dy = elem_loc.Y - admin_loc.Y
    local dz = elem_loc.Z - admin_loc.Z
    if (dx*dx + dy*dy + dz*dz) <= (FLAG_RADIUS_CM * FLAG_RADIUS_CM) then
        -- TODO: replace with the confirmed mutation-leaf UFunction call
        elem:SetMaterialTier(TARGET_TIER)
        upgraded = upgraded + 1
    else
        skipped = skipped + 1
    end
end

print(string.format("[BU] upgraded=%d skipped=%d", upgraded, skipped))
```

The function name and signature here are placeholders. The first task is the
SDK dump to confirm them.

## Why this beats the patch route

- No AOB scan, no `VirtualProtect`, no static binary modification.
- No "does the host allow server-side injection under BattlEye" question — the
  UE4SS harness is already in-process and we're staying inside UFunction calls.
- Survives game updates as long as UFunction names stay stable. Function names
  are dramatically more durable than byte-pattern matches against a leaf
  function's prologue.
- Reuses the existing `BulkUpgrade/main.lua` hot-reload harness verbatim. Only
  `live.lua` evolves.
- The mutation we call is the same one the gated chat command calls, so
  replication, save state, and visual updates happen through the normal code
  paths.

## Action items

1. **SDK dump** of `ConZBaseElement` and `PlayerRpcChannel` UFunctions. Either
   regenerate via UE4SS UHT dumper or live-introspect from Lua.
2. **Identify the mutation leaf** — the UFunction that actually flips material
   tier without running gameplay checks.
3. **Identify `EBaseElementMaterial`** (or whatever the enum is called) and
   confirm Cement's integer value.
4. **Wire `live.lua`** per the sketch above with confirmed names.
5. **Sandbox test** on a throwaway base — single element first, then radius.
6. **Verify replication** — clients connected at the time should see the
   upgrade without a reconnect.

## What does NOT change from 2026-05-25

- `tools/db_tier.py` remains the offline fallback (restart required).
- `tools/elevate.py` still grants tier-2 dev commands; `#bu` itself still needs
  to be issued by an elevated user since it goes through
  `Chat_Server_ProcessAdminCommand`. Confirm whether plain admin works or
  whether elevated is required for the `#bu` shim specifically.
- The `BulkUpgrade/main.lua` harness pattern is unchanged.
- The native-gate AOB patch is still on the shelf as the fallback for **other**
  tier-3 commands (anything we'd want to call where there's no underlying
  UFunction reachable from server-side UE4SS). Not the primary route for this
  feature.
