# Live online-upgrade investigation — conclusion (2026-05-26)

Continuation of `bulk-upgrade-pivot-2026-05-26.md`. We chose to attempt the full
online replay on the self-hosted test server (new SCUM build, BattlEye off,
server-side UE4SS). This documents what was proven and where it stalled, so the
dead ends and the real mechanism are both on record.

## TL;DR

- **The real upgrade mechanism is now known** (a genuine result): upgrading a base
  element is a server-authoritative **destroy + respawn**, not an "interaction".
- **It is reachable from server-side Lua** — the multicasts fire when we call them.
- **But driving it from hand-built structs hard-crashes the server with zero
  diagnostic**, because UE4SS can't read the real struct *contents* to copy them.
- The reliable, equivalent result remains **`tools/db_tier.py`** (offline class
  rewrite = the persistent form of the same destroy+respawn), restart-based.

## What was tested, in order

1. **New build = unchanged architecture.** Re-dumped server-side: `ConZBaseElement`
   has 0 functions; one HISM container actor (no per-element actors);
   `PlayerRpcChannel` has no new upgrade RPC. Reflection enumerate-and-mutate is dead.

2. **The interaction RPC was the WRONG path.** Hooked
   `PlayerRpcChannel:InteractWithObjectOnServer`,
   `ConZBaseManager:NetMulticast_InteractWithElement`, and
   `ConZBase:OnElementInteracted`, then performed a **real in-game upgrade**
   (twig→wood, god-mode fill). **None fired.** That's why every server-side call we
   made to those returned `ok=true` and did nothing — they aren't the upgrade path.
   (The recon's `EInteractionType::UpgradeBaseElement = 180` assumption was wrong for
   the actual mesh/tier upgrade.)

3. **The REAL path: destroy + respawn multicasts.** A real upgrade fires, in order:
   - `ConZBaseManager.NetMulticast_DestroyElement(dataVersion, ElementIdentifier{BaseId,ElementID,Location}, reason=2, cascade=false)`
   - `ConZBaseManager.NetMulticast_SpawnBaseElement(dataVersion+1, Transform, baseData:ConZBaseData, ElementClass=<higher-tier>, ElementID=<FRESH>, OwnerUserProfileId, CreatorPrisonerId, IsOwnedByPlayer=true, params:BaseElementSpawnParams)`

   `dataVersion` is a global monotonic counter (+1 per multicast; observed 35→36,
   39→40). The spawned element gets a freshly-allocated `ElementID` (51, 52, …).
   `SpawnBaseElement` creates a **real authoritative element** — not the cosmetic
   HISM-only instance that was the earlier dead end. Both are NetMulticasts, so they
   are callable from server authority.

4. **The save DB has everything needed.** `base_element` columns:
   `element_id, base_id, location_{x,y,z}, rotation_{pitch,yaw,roll}, scale_{x,y,z},
   asset, element_health, owner_profile_id, quality, creator_prisoner_id`. `base`:
   `id, location_{x,y}, size_{x,y}, name, owner_user_profile_id, is_owned_by_player,
   bounds_{min,max}_{x,y}`. So both multicast arg-sets are derivable from the DB.

5. **Replay attempt → hard crash.** Drove `NetMulticast_SpawnBaseElement` server-side
   with a hand-built element (DB-derived transform + reconstructed `ConZBaseData` +
   guessed `BaseElementSpawnParams`, fresh id 9001, wood class, dataVersion 42). The
   call **fired and replicated** (client showed a brief construction hourglass), then
   the server **hard-crashed ~5–10s later** — no crash dump, no callstack
   (BattlEye-off server writes none), and `POST-CALL` never flushed. The element was
   **not persisted**; the DB stayed intact at 49 elements.

## Why it stalled

- **No way to copy the real structs.** UE4SS hook params deref to a struct with no
  `GetFullName` and field indexing returns nil, so `ConZBaseData` / `Transform` /
  `BaseElementSpawnParams` must be rebuilt by guesswork. Likely crash culprits:
  `BaseSize=(0,0)`, missing/zero `EntityId`+`ShelterId` in params, or a stale
  `dataVersion`.
- **No diagnostic signal.** A wrong field hard-crashes the server with no log — the
  debug loop is crash → restart → reconnect → retry, with zero feedback on which
  field was wrong.
- **Deployment gate.** Even a clean replay only helps production if the rented host
  permits server-side UE4SS/DLL injection under BattlEye — unconfirmed. Confirm this
  with the host *before* investing further; if it's "no", the whole live route is
  moot and `db_tier` is the answer regardless.

## Recommendation

- **Use `tools/db_tier.py`** on the server's `SCUM.db` during a restart/maintenance
  window. It rewrites each element's `asset` to the cement class — the persistent
  form of the same destroy+respawn we observed — and **fully eliminates the admin's
  manual per-element god-mode filling** (the actual pain). Reliable, survived today's
  patch, no crash risk, no injection dependency. Only compromise: needs a restart.

## Untried higher-signal lead (if the live route is revisited)

Reuse the **game's own** `baseData`/`params` structs instead of reconstructing them:
hook `SpawnBaseElement`, have the admin perform one real upgrade to "prime" valid
structs, then replicate them to other elements (swap class→cement, fresh ElementID,
per-element transform from the DB). Avoids the malformed-struct crash, but needs a
manual prime upgrade per base, reentrancy handling, a correct `dataVersion`, and is
still gated by host injection under BattlEye.
