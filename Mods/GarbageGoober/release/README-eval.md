# GarbageGoober — evaluation build

A **server-side** SCUM loot-sorter (UE4SS). On a timer it sweeps loose ground
loot inside a flag's influence and moves each item into a chest **in that same
flag** whose custom name matches the item's category.

Server-side only: clients stay vanilla, so **client BattlEye can stay on** and
nothing runs on players' PCs.

This is a **time-limited evaluation build** (see Expiry at the bottom).

## Install

1. Copy this `GarbageGoober` folder into your server's
   `SCUM\Binaries\Win64\ue4ss\Mods\`.
2. Open `Scripts\main.lua` and set **`MOD_DIR`** (the first line) to the full
   path of this folder.
3. Run **`install-libraries.ps1`** (or double-click `install-libraries.cmd`) in
   this folder. It downloads the public-domain `sqlite3.exe` used to read the
   save DB read-only. (The save-DB path auto-derives from `MOD_DIR` for a
   standard server layout — no extra config needed.)
4. Enable it: add this line to `ue4ss\Mods\mods.txt`
   ```
   GarbageGoober : 1
   ```
   Do **not** create `enabled.txt` — it silently overrides `mods.txt`.
5. Make sure `ue4ss\UE4SS-settings.ini` has:
   ```
   HookProcessInternal = 1
   HookProcessLocalScriptFunction = 1
   ```
6. Start the server, then check `GarbageGoober.log` (created in this folder) for
   `GarbageGoober is loaded`.

## Using it

Type commands in **normal in-game chat** (not `#` admin commands). `goober`
shows the full list. Quick start:

- `goober` — command list
- `goober status` — access-control summary (admin)
- `goober add <player>` — enable sorting for a player's base (admin)
- `goober now` — sort the loose loot in your flag right now
- `goober chests` — show what category each chest in your flag matches

Name a chest after a **category** (e.g. `Ammo`, `Drink`, `FirstAid`) for fine
sorting, or after a **trader group** (`Armorer`, `Bartender`, `GeneralGoods`) to
catch a whole group. Loose loot within a flag's radius flows to the deepest
matching chest; unmatched items are left in place.

## Notes

- Sorting is gated per base by default — use `goober add <player>` (admin) to
  enable a base, or `goober default on` to sort every flag.
- SCUM only keeps loot/chests live within ~200m of a player, so a base with
  nobody nearby has nothing to sweep (by design).
