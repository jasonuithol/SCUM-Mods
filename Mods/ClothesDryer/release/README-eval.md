# ClothesDryer — evaluation build

A **server-side** SCUM mod (UE4SS). Turns an **Improvised Wardrobe** into a
powered **clothes dryer**: wet clothing (and worn bags/backpacks) left inside an
activated wardrobe dries automatically. A wardrobe becomes a dryer by consuming a
build **recipe** placed inside it.

Server-side only: clients stay vanilla, so **client BattlEye can stay on** and
nothing runs on players' PCs.

This is a **time-limited evaluation build** (see Expiry at the bottom).

## Install

1. Copy this `ClothesDryer` folder into your server's
   `SCUM\Binaries\Win64\ue4ss\Mods\`.
2. Open `Scripts\main.lua` and set **`MOD_DIR`** (the first line) to the full
   path of this folder.
3. *(Only if the entitlement gate is on.)* Run **`install-libraries.ps1`** (or
   double-click `install-libraries.cmd`) in this folder. It downloads the
   public-domain `sqlite3.exe` used to read the save DB read-only. The save-DB
   path auto-derives from `MOD_DIR` for a standard server layout — no extra
   config needed.
4. Enable it: add this line to `ue4ss\Mods\mods.txt`
   ```
   ClothesDryer : 1
   ```
   Do **not** create `enabled.txt` — it silently overrides `mods.txt`.
5. Make sure `ue4ss\UE4SS-settings.ini` has:
   ```
   HookProcessInternal = 1
   HookProcessLocalScriptFunction = 1
   ```
6. Start the server, then check `ClothesDryer.log` (created in this folder) for
   `ClothesDryer is loaded`.

## Using it

Type commands in **normal in-game chat** (not `#` admin commands). `dryer` shows
the full list. Quick start for a base owner:

1. Build (and place) an **Improvised Wardrobe** inside your flag.
2. Put the activation recipe in it: **5× Metal Scraps + any Alternator + 1× Wire
   + 5× Bolts**.
3. Stand next to the wardrobe and type **`dryer activate`**. The recipe is
   consumed and the wardrobe becomes a dryer.
4. Done. Drop wet clothes (and worn bags/backpacks) inside; they dry within a few
   seconds while you're nearby.

Handy commands:

- `dryer check` — your wardrobes, recipe status, active dryers, each garment's
  wetness
- `dryer now` — run a dry cycle immediately
- `dryer deactivate` — turn a dryer back into a plain wardrobe (no refund)
- `dryer status` / `dryer add <player>` — admin: access-control summary / enable
  drying for a player's base

Drying is gated per base by default — an admin uses `dryer add <player>` to
enable a base, or `dryer default on` to enable every flag.

## Notes

- **Activation is keyed by location** — a dryer survives renames and restarts.
  *Moving* the wardrobe (pick up + replace) makes a new spot; re-run
  `dryer activate`.
- **Drying needs a player nearby.** SCUM keeps container contents live only while
  a player is observing them; closed-and-abandoned wardrobes virtualize their
  contents out (they can't affect the world then anyway). Drying resumes the
  moment someone's around — which is whenever anyone actually uses it.
- **Still looks wet after it dried?** The server already set it dry; your client
  re-syncs a beat later (or on reopening the wardrobe).
- **Water containers are safe** — only clothing is touched; canteens and bottles
  are never drained.
