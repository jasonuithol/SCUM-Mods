# SCUM Base-Building Tier Tool & Modding Research

Tools and reverse-engineering notes for modding **SCUM** (UE 4.27.2, build 1.2.3.2 CL-115523).

The headline deliverable is **`db_tier`** — an offline tool that bulk **upgrades/downgrades every base-building element's tier** (Twig → Wood → Metal → Brick → Cement) by editing SCUM's local SQLite save database. The change is a *real, persistent* tier change (correct mesh, HP, raid-resistance), because SCUM rebuilds each element from the DB on world load.

> **Scope / ethics:** this only works where you have the save file — **single-player sandbox and your own dedicated server**. It is impossible on someone else's server (no DB access), which is exactly the intended boundary. Use it only on bases/servers you own.

---

## `db_tier` — the tier editor

`.staging/db_tier.py` (also buildable to a standalone `db_tier.exe`, see below).

```
python db_tier.py (--tier NAME | --levels N) [--playerid ID] [--apply] [--db PATH]
```

| Parameter | Meaning |
| :--- | :--- |
| `--tier NAME` | **Absolute** target tier: `twig`/`wood`/`metal`/`brick`/`cement`. Clamped to each shape's cap (e.g. doors stop at Metal). Best when the base is a mix of tiers. |
| `--levels N` | **Relative**: raise N tiers; **negative downgrades** (`-5` → Twig). Clamped per shape. |
| `--playerid ID` | **Server mode** — target bases where `owner_user_profile_id = ID`. Omit → **sandbox mode** (your `is_owned_by_player` flag). |
| `--apply` | Actually write. **Without it, it's a dry-run** (preview only; read-only, safe even while SCUM runs). |
| `--db PATH` | Use a different `SCUM.db` (e.g. a server's). Default: your local save. |

Run with **no arguments** to print this help.

### Workflow

1. **Quit SCUM to desktop** (releases the DB; the tool refuses to write while the game holds it).
2. Preview, then apply:
   ```
   python db_tier.py --tier cement            # dry-run: see the plan
   python db_tier.py --tier cement --apply    # do it (backs up the DB first)
   ```
3. **Relaunch and load** — SCUM rebuilds the elements at the new tier.

`--apply` always writes a timestamped backup (`SCUM.db.bak-<ts>`) next to the save first.

### Build a standalone binary

```
pip install pyinstaller
pyinstaller --onefile --console db_tier.py
# -> dist/db_tier.exe  (no Python needed to run)
```

---

## How it works (and why it's a DB edit, not a live mod)

SCUM persists the whole world — including every base element — to a local SQLite DB:

```
%LOCALAPPDATA%\SCUM\Saved\SaveFiles\SCUM.db
```

In the `base_element` table, the **`asset` column is the element's class path, which *is* its tier**:

```
Twig:          /Game/ConZ_Files/.../Modular/BP_Base_Modular_<Shape>_Twig...
Wood/.../Cement: /Game/ConZ_Files/.../Modular/BPC_Base_Modular_<Shape>_<Tier>...   (note the BPC_ prefix)
```

Rewriting that string to a higher/lower tier, then reloading, makes SCUM reconstruct the element at the new tier via its normal, fully-supported load path. `element_health` is a 0–1 fraction, so the new tier loads at full HP automatically.

**Why not do it live from the UE4SS mod?** The in-game upgrade is `EInteractionType::UpgradeBaseElement` (value `180`), sent via `PlayerRpcChannel.InteractWithObjectOnServer(...)`. But it needs the element's `BaseElementId`, which is only resolved natively from the player's aim-trace — not reachable through UE reflection. Feeding a real ID (read from the DB) into the RPC **hangs the game** (the native upgrade handler called without its interaction context). The DB edit sidesteps all of that.

`db_tier` learns which (shape, tier) classes are valid from the live DB **plus every `SCUM*.db` backup** in the save folder — so it still knows the full tier chain even after a downgrade has wiped the higher-tier strings out of the live DB. Per-shape caps (e.g. doors → Metal) and non-upgradeable pieces (ladders, camo nets, the flag) are handled automatically.

---

## `FlagUpgrade` — the UE4SS research harness

`Mods/FlagUpgrade/Scripts/main.lua` is a tiny **bootstrap** that, on **F11**, executes `.staging/live.lua` fresh each press — a hot-reload loop so the actual logic can be iterated without restarting SCUM. This is how the base-building system was reverse-engineered (HISM layout, the interaction RPCs, the `EInteractionType` enum, struct layouts). It is **not** required for `db_tier`.

It runs under UE4SS (Experimental v3.0.1, from the `herbie96x/SCUM-AllowMods` bundle), which is unpacked into the game's `Win64` folder. Launch by running `SCUM.exe` directly with `-nobattleye`; leave the BattlEye service at its default `Manual` (don't disable it), and never create an `enabled.txt` (it overrides `mods.txt`).

---

## Repo layout

```
db_tier  ──────────────  .staging/db_tier.py        # the tier tool (main deliverable)
helper/recon scripts ──  .staging/db_upgrade.py, dbread.py, dbcheck.py,
                         dbexplore.py, inspect_pak.py
hot-reload mod ────────  Mods/FlagUpgrade/Scripts/main.lua  (+ .staging/live.lua)
research notes ────────  .staging/recon_*.txt        # the lab notebook (see below)
```

Build artifacts, the SCUM-AllowMods bundle, DLLs, the `.exe`, PAKs, zips, and DB
backups (save data) are **git-ignored** — they're large, binary, third-party, or personal.

### Research notes (`.staging/recon_*.txt`)

Key references produced during the reverse-engineering:

- `recon_enum.txt` — the full `EInteractionType` enum (incl. `UpgradeBaseElement = 180`).
- `recon_structs.txt` — interaction struct field layouts.
- `recon_params.txt` / `recon_funcs.txt` — interaction-function signatures.
- `recon_v26_catalog.txt` — every base-element mesh/tier in a built base.
- `recon_bases.txt`, `recon_custom.txt`, `recon_elemprops.txt`, `recon_interact.txt` — the dead-ends that proved the DB route was necessary.

---

## Safety

- Dry-run is the default; `--apply` is required to write.
- Every `--apply` backs up `SCUM.db` first, and refuses to run while SCUM is open.
- Scope is always a single player's own flag(s) — sandbox auto-detects you, server uses `--playerid`.
