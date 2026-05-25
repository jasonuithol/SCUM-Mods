# Recon archive

Raw reverse-engineering output from the SCUM base-building work, plus the throwaway
probe scripts that produced it. This is the lab notebook — kept for provenance.
The conclusions live in the top-level [`README.md`](../../README.md); the working
tool is [`tools/db_tier.py`](../../tools/db_tier.py).

## Start here (the findings that mattered)

| File | What it captured |
| :--- | :--- |
| `recon_enum.txt` | Full `EInteractionType` enum — incl. **`UpgradeBaseElement = 180`**, the in-game upgrade interaction. |
| `recon_params.txt` | Parameter *types* of the interaction RPCs (`InteractWithObjectOnServer`, `NetMulticast_InteractWithElement`, …). |
| `recon_structs.txt` | Field layouts of the interaction structs (`ConZBaseElementInteractionData`, etc.) — incl. the `BaseElementId` we needed. |
| `recon_funcs.txt` | All functions on `ConZBaseManager` / `ConZBaseElement` / `ConZBase`. |
| `recon_v26_catalog.txt` | Every base-element mesh + tier present in a fully-built base (149 HISM entries). |

## Why the live mod route was abandoned (the dead ends)

| File | What it ruled out |
| :--- | :--- |
| `recon_bases.txt` | `ConZBaseManager._bases` is just `BaseId → flag actor` — no element list. |
| `recon_elemprops.txt` | Flag/element/manager actors expose no per-element-ID collection. |
| `recon_custom.txt` | The interaction HISM has no per-instance custom data (no IDs there). |
| `recon_interact.txt` | The pawn has no interaction *component* — ID resolution is native-only. |
| `recon_upgrade.txt` | The upgrade RPC: `BaseElementId=0` no-ops; a real ID **hangs** the game. |

Conclusion: element IDs aren't reachable via UE reflection → drive the upgrade by
editing the save DB instead (see top-level README).

## Module / class discovery

| File | What it captured |
| :--- | :--- |
| `recon_v28.txt` | Module = `/Script/SCUM`; confirmed `EInteractionType` exists; no developer flag. |
| `recon_v29.txt` | Native member dumps of `ConZPlayerController` / `ConZPlayerState` / `PlayerRpcChannel` / `ConZBaseManager` / `ConZBase`. |
| `recon_v26_probe.txt` | `PlayerRpcChannel` RPC surface (where `InteractWithObjectOnServer` lives). |
| `recon_v27.txt` | Truncated — the run that hard-crashed from walking the super-class chain. |
| `recon_v5.txt`–`recon_v17.txt`, `recon_v25.txt` | Early FlagUpgrade dumps: HISM-instance layout, base-element class catalog, and the LoadAsset/mesh-swap experiments. |

## Probe scripts (`*.py`)

Run against `%LOCALAPPDATA%\SCUM\Saved\SaveFiles\SCUM.db` (read-only). Hardcoded
output paths point at `.staging/`; kept as a record of how the schema was mapped.

| Script | Purpose |
| :--- | :--- |
| `dbread.py` | First read of `SCUM.db` — found the `base` / `base_element` tables. |
| `dbexplore.py` | Looked for player/prisoner location tables (to scope by flag). |
| `dbcheck.py` | Validated `Twig → BPC_…_Cement` asset paths and element-health semantics. |
| `db_upgrade.py` | The original one-shot Twig→Cement DB edit — **superseded by `tools/db_tier.py`**. |
| `inspect_pak.py` | Leftover from earlier PAK-mod cooking experiments. |
