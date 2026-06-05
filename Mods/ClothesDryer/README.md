# ClothesDryer

A **server-side** SCUM mod (UE4SS). Turns an **Improvised Wardrobe** into a
powered **clothes dryer**: wet clothing left inside an activated wardrobe dries
automatically. A wardrobe becomes a dryer by consuming a build **recipe** placed
inside it.

Server-side only: clients stay vanilla, so **client BattlEye can stay on** and
nothing runs on players' PCs.

## Install

1. Copy this `ClothesDryer` folder into your server's
   `SCUM\Binaries\Win64\ue4ss\Mods\`.
2. Open `Scripts\main.lua` and set **`MOD_DIR`** (near the top) to the full path
   of this folder.
3. *(Optional — only for the per-player donation model.)* Drying works out of the
   box with no database. If you want to grant access to **specific players**
   (`dryer add <player>`), the mod reads `SCUM.db` read-only via `sqlite3.exe`:
   download the command-line tools from <https://sqlite.org/download.html> and put
   `sqlite3.exe` in this folder. Default-on and per-flag overrides need none of this.
4. The shared gating library is expected at `ue4ss\Mods\shared\Scripts\gating.lua`
   (shipped alongside, in the `shared` folder). Keep the `shared` folder next to
   this one.
5. Enable it: add this line to `ue4ss\Mods\mods.txt`
   ```
   ClothesDryer : 1
   ```
   Do **not** create `enabled.txt` — it silently overrides `mods.txt`.
6. Make sure `ue4ss\UE4SS-settings.ini` has:
   ```
   HookProcessInternal = 1
   HookProcessLocalScriptFunction = 1
   ```
7. Start the server, then check `ClothesDryer.log` (created in this folder) for
   `ClothesDryer loaded`.

## Using it

Type commands in **normal in-game chat** (not `#` admin commands). `dryer` shows
the full list. Quick start for a base owner:

1. Build (and place) an **Improvised Wardrobe** inside your flag.
2. Put the activation recipe in it: **5× Metal Scraps + any Alternator + 1× Wire
   + 5× Bolts** (stacks count by total quantity).
3. Stand next to the wardrobe and type **`dryer activate`**. The recipe is
   consumed and the wardrobe becomes a dryer.
4. Done. Drop wet clothes (and worn **bags/backpacks** — they're clothing too)
   inside; they dry within a few seconds while you're nearby.

Handy commands:

- `dryer check` — your wardrobes, recipe status, active dryers, and each
  garment's wetness
- `dryer scan` — list the exact item classes in your wardrobe (used to tune the
  recipe in `Config.lua`)
- `dryer now` — run a dry cycle immediately
- `dryer deactivate` — turn a dryer back into a plain wardrobe (no refund)
- `dryer status` / `dryer add <player>` — admin: access-control summary / enable
  drying for a player's base

## Notes

- **Activation keyed by location.** A dryer is remembered by where the wardrobe
  sits, so it survives renames and server restarts. **Moving** the wardrobe
  (pick up + replace) makes a new spot — re-run `dryer activate`.
- **Drying needs a player nearby.** SCUM only keeps container contents "live"
  while a player is observing them; closed-and-abandoned wardrobes have their
  contents virtualized out (they can't affect the world then anyway). Drying
  resumes the moment someone's around — which is whenever anyone actually uses
  it.
- **Still looks wet after it dried?** The server already set it dry; your client
  re-syncs a beat later (or on reopening the wardrobe).
- **Water containers are safe.** Only clothing is touched — canteens, bottles,
  etc. are never drained.

## Configuration (`Scripts/Config.lua`)

- `dryIntervalMs` — how often the dry cycle runs (default 4000 ms).
- `recipe` — the activation ingredients (class names + total counts). Use
  `dryer scan` to confirm class names on your build.
- `requireAdmin` — gate admin commands behind SCUM admin status (default true).
- `entitlementsEnabled` — when **true** the gate is active but ships **default-on**,
  so every flag dries out of the box. Restrict/sell access with `dryer default off`
  + per-player grants (`dryer add <player>`, the donation model — that's the only
  part that needs `sqlite3.exe`, install step 3) or per-flag overrides (no DB).
  When **false**, drying works in any flag and no DB is ever read. Edit, then
  `dryer reload` in chat (or restart).
