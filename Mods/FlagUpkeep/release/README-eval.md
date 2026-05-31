# FlagUpkeep — evaluation build

A **server-side** SCUM mod (UE4SS). On a timer it keeps a flag's base elements
repaired to full health, paid for with **repair points** you bank by depositing
**toolboxes** into a chest in that flag.

Server-side only: clients stay vanilla, so **client BattlEye can stay on** and
nothing runs on players' PCs.

This is a **time-limited evaluation build** (see Expiry at the bottom).

## Install

1. Copy this `FlagUpkeep` folder into your server's
   `SCUM\Binaries\Win64\ue4ss\Mods\`.
2. Open `Scripts\main.lua` and set **`MOD_DIR`** (the first line) to the full
   path of this folder.
3. Run **`install-libraries.ps1`** (or double-click `install-libraries.cmd`) in
   this folder. It downloads the public-domain `sqlite3.exe` used to read the
   save DB read-only. (The save-DB path auto-derives from `MOD_DIR` for a
   standard server layout — no extra config needed.)
4. Enable it: add this line to `ue4ss\Mods\mods.txt`
   ```
   FlagUpkeep : 1
   ```
   Do **not** create `enabled.txt` — it silently overrides `mods.txt`.
5. Make sure `ue4ss\UE4SS-settings.ini` has:
   ```
   HookProcessInternal = 1
   HookProcessLocalScriptFunction = 1
   ```
6. Start the server, then check `FlagUpkeep.log` (created in this folder) for
   `FlagUpkeep is loaded`.

## Using it

Type commands in **normal in-game chat** (not `#` admin commands). `upkeep`
shows the full list. Quick start for a base owner:

1. Build a chest or wardrobe **inside your flag** and name it **exactly**
   `FlagUpkeep`.
2. Put **toolboxes** in it — Tool Box = **100** repair points, Small Tool Box =
   **50**, Improvised Tool Box = **20**.
3. **Open the chest**, then type **`upkeep deposit`** in chat. Your toolboxes
   turn into repair points (the boxes get used up).
4. Done. Every hour the mod auto-repairs your damaged base, spending **1 point
   per element**.

Handy commands:

- `upkeep check` — your repair points + what's ready to deposit + trigger/damage
- `upkeep now` — repair right now instead of waiting for the hourly run
- `upkeep trigger 80` — only repair pieces under 80% (lower = save points,
  higher = stay raid-tough; 1 point fully repairs from any level)
- `upkeep status` / `upkeep add <player>` — admin: access-control summary /
  enable upkeep for a player's base

Upkeep is gated per base by default — an admin uses `upkeep add <player>` to
enable a base, or `upkeep default on` to keep up every flag.

## Notes

- **Deposit says it read 0?** You forgot to *open the chest* — open it and run
  `upkeep deposit` again. (A box that reads 0 is left untouched, so you never
  lose a full one to a misread.)
- **Just repaired but the wall still looks cracked?** Relog — the repair already
  happened on the server; your client just needs to re-sync.
- Element health is read from the save DB, which updates on the server's
  periodic save (~minutes), so damage/repair take a save to show in
  `upkeep check`.
- SCUM only keeps bases live within ~200m of a player, but repair spends the
  **banked point balance** — so it works with the chest closed and the base
  unattended (as long as the base is loaded for the periodic cycle).
