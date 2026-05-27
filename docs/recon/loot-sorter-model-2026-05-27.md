# SCUM loot/item/container/inventory model — recon for the loot-sorter mod

Reverse-engineered live on the test server (SCUM 1.3.0, UE 4.27.2) on 2026-05-27 with
`Mods/LootSorterRecon` (a read-only UE4SS Lua dumper driven by the `#lsr` admin-chat
command, 9 passes). Module is `/Script/SCUM`. Full generated type defs are archived at
`docs/recon/sdk/SCUM-types-1.3.0.lua` (+ `SCUM_enums-1.3.0.lua`, `*.usmap`) — produced
by UE4SS `GenerateLuaTypes()` / `DumpUSMAP()`.

> Method note: in this UE4SS build you cannot super-walk (`GetSuperStruct()` crashes,
> gotcha #12) and `ForEachProperty`/`ForEachFunction` only list a class's OWN members.
> The reliable route was `GenerateLuaTypes()` → read full hierarchies offline, plus
> `FindAllOf(nativeName)` + reading inherited props/structs by name.

## Items are NOT world actors you can census normally

Items are `AItem` actors but most are **virtualized** (managed by `ItemVirtualizationManager`)
and not present as live UObjects — a full `FindAllOf("Actor")` census (223 589 actors,
2 758 classes) contained **zero** item classes. Only non-virtualized items (near players /
freshly dropped) show up via `FindAllOf("Item")` (21 in the test). **Open question for an
autonomous cleanup loop: items in an unattended base may be virtualized.** See "Open
questions".

## Item (`/Script/SCUM.Item`, leaf = per-item BP e.g. `12_Gauge_Slug_C`)

- **Type** = the item's leaf class FName (e.g. `12_Gauge_Slug_C`, `Rags_C`, `CannedPear_C`).
- **Stable ID** = `item._repServerEntitySetupAndId._value` — a `uint64` (struct
  `FPackedEntitySetupAndId{ _value:uint64 }`). Use for dwell-time tracking across sweeps.
- **Where it is** = `item._serverPresence` (a `UItemPresence` subclass):
  - `UItemPresence_OnTheFloor` → **dropped on the ground**. `presence.Data` is
    `FItemPresence_OnTheFloor_RepData { Location:FVector_NetQuantize10, Rotation:FRotator,
    dropper:APawn, IsValid:bool }` → **world location = `presence.Data.Location`**.
  - `UItemPresence_InTheInventory` → in a container. `presence._inventory` (the
    `UInventoryComponent`) + `presence._location` (`FInventoryEntryLocation{ Value:uint32 }`, a
    packed slot).
  - also `UItemPresence_Attachment`, `UItemPresence_PrisonerCorpse`.
- `_itemTags` / `_ownedItemTags` (GameplayTag arrays), `_itemSpawnTypes`/`_itemSpawnGroup`,
  `_rarity` — candidate category signals (TBD vs vendor taxonomy).
- `_itemLocation` is a RED HERRING: it's spawn-region eligibility flags
  (Coastal/Urban/Police/Military…), not current position.
- `Item.DropAround(Actor, dropper, zOffset)` → drops an item near an actor.

## Chests (`AChestItem : AItem`, e.g. `Improvised_Metal_Chest_C`)

A placed storage chest is an `AChestItem` (deployed item), NOT an `AItemContainer` (those
are the lockable WORLD containers — weapon lockers, depositories — keyed in
`ItemContainerManager._itemContainers`; player chests are NOT in that map).

`AChestItem` fields:
- **`_inventory : UChestInventoryComponent`** — the chest's storage component.
- **`_nameableItemComponent : UNameableItemComponent`** → **`._name : FString`** = the
  player-given custom name (e.g. `"Ammo"`). (Rename UFunc:
  `UNameableItemComponent:OnEditTextWidgetTextAccepted(User, Text)`.)
- `_canContainChestItem`, `_lockpickableEnabled`, `_overrideCanBeNamed`, `_buriableChestItemComponent`.

Enumerate chests via `FindAllOf("ChestInventoryComponent")` (subclass-inclusive: also
`UDepotInventoryComponent`, `UVehicleInventoryComponent`). For each component:
`owner = comp:GetOwner()` → the `AChestItem`; `owner:K2_GetActorLocation()`,
`owner._nameableItemComponent._name`.

### Inventory hierarchy
`UInventoryComponent : UActorComponent` → `UGridInventoryComponent` →
`UChestInventoryComponent` → {`UDepotInventoryComponent`, `UVehicleInventoryComponent`}.
Contents are tracked **from the item side** (each item's presence points at its inventory),
not as a list field on the component (`UInventoryComponent` own-props are nearly empty:
`_repHasEntries:bool`).

## The WRITE / transfer API (`UInventoryUserComponent`, server RPCs)

- **`Server_InventoryComponent_AddOrMoveEntry(Inventory:UInventoryComponent,
  entryActor:AActor, entryLocation:FInventoryEntryLocation)`** — **move/add an item
  (`entryActor`, an `AItem`) into `Inventory` at a slot.** This is the core move call.
  **CONFIRMED WORKING server-side 2026-05-27**: `iuc:Server_InventoryComponent_AddOrMoveEntry(
  chestInv, groundItem, {Value=0x40000000})` moved a ground item into the chest and it stuck.
  `FInventoryEntryLocation.Value`: **`0x40000000` (1073741824) = auto-place first free slot**;
  explicit slots pack `x | (y<<10)`. `Value=0` silently no-ops for a fresh add — use the sentinel.
  Discovered by `RegisterHook`-capturing a real in-game drag (RegisterHook fires server-side for
  these RPCs), then replaying. Call on a player's `UInventoryUserComponent`.
- `Server_InventoryComponent_RemoveEntry(Inventory, entryActor)`
- `Server_CharacterInventoryComponent_DropItemAt(Inventory, Value, Location, Rotation)` /
  `PickupItem` / `DropItem` etc.
- `Server_GridInventoryComponent_SortEntries(inventories, sorter, order)`.
- Alt bulk add seen on `PlayerRpcChannel`: `Placeable_Server_FillWithItems(placeable, User, Items)`.

## Flags / territory (already known; re-confirmed)

`BP_ConZBaseManager_C._bases` = TMap BaseId→`BP_ConZBase_C` flag.
`_flagInfluenceRadius = 5000`, `_maxElementsPerFlag = 100`, `_flagOvertakeDuration = 86400`.
Flag name via `flag:GetBaseName()`. **A point is "inside" a flag by HORIZONTAL (X/Y)
distance ≤ radius** — the flag actor's reported Z is 0, so 3D distance is wrong.

## UE4SS API surface that matters here (from `_G` dump)

`FindAllOf`, `FindFirstOf`, `FindObjects`, `StaticFindObject`, `ForEachUObject`,
**`NotifyOnNewObject`** (hook item creation → could catch drops in real-time instead of
polling), `LoopAsync` / `ExecuteInGameThread` / `LoopInGameThreadWithDelay` (sweep timer),
`RegisterHook`, `GenerateSDK` / `GenerateLuaTypes` / `DumpUSMAP` (offline dumps).
`IterateLoadedObjects` does NOT exist. `RegisterConsoleCommandHandler` won't fire (gotcha
#7) — the admin-chat hook (`PlayerRpcChannel:Chat_Server_ProcessAdminCommand`) is the
server trigger.

## End-to-end loot-sorter pipeline (resolved)

1. **Sweep** on a timer (`LoopInGameThreadWithDelay`) — or hook `NotifyOnNewObject` for
   `OnTheFloor` items. Per loose item: id `_repServerEntitySetupAndId._value`, type = leaf
   class, world loc `_serverPresence.Data.Location`. Track first-seen → act at ≥ dwell (60s).
2. **Flag scope**: find the flag whose center is within `_flagInfluenceRadius` (X/Y) of the
   item. No flag ⇒ ignore (POI loot is naturally excluded).
3. **Candidate chests** = chest inventories whose owner `AChestItem` is inside that same flag.
4. **Match**: item type → leaf category → walk category ancestry; first chest whose
   `_nameableItemComponent._name` equals a node name wins. No match ⇒ log + leave.
5. **Move**: `Server_InventoryComponent_AddOrMoveEntry(chest._inventory, itemActor, slot)`.

## Open questions for the build (not blockers)

- **Virtualization**: will `OnTheFloor` items in an unattended base be live `AItem`s, or
  virtualized away? May need `ItemVirtualizationManager` interaction, or accept "works when
  a player is in range". Investigate before committing to the autonomous-loop promise.
- **`UInventoryUserComponent` instance** to call the RPC server-side when no player is
  online (autonomous cleanup). We used a live player's IUC; headless case unsolved — maybe
  `StaticConstructObject` one, or require a player online.
- ~~`entryLocation` slot encoding~~ — SOLVED: `Value=0x40000000` auto-places (see WRITE section).
- **Category taxonomy**: derive the DAG from vendor data (separate task) → config file.
