# WashingMachine

A **server-side** SCUM mod (UE4SS). Turns an **Improvised Wardrobe** into a
**washing machine**: dirty clothing placed inside an activated wardrobe — together
with a full bar of soap — is washed **clean and left damp** when the owner runs
`washer wash` while **holding a full water bucket**. A wardrobe becomes a washer
by consuming a build **recipe** placed inside it.

Sibling of the **ClothesDryer** mod — wash the dirt out here, then dry it there.

Server-side only: clients stay vanilla, so **client BattlEye can stay on** and
nothing runs on players' PCs.

## Install

1. Copy this `WashingMachine` folder into your server's
   `SCUM\Binaries\Win64\ue4ss\Mods\`.
2. Open `Scripts\main.lua` and set **`MOD_DIR`** (near the top) to the full path
   of this folder.
3. *(Optional — only for the per-player donation model.)* Washing works out of the
   box with no database. Granting access to **specific players** (`washer add
   <player>`) reads `SCUM.db` via `sqlite3.exe` and is **off by default**. To
   enable: download the command-line tools from <https://sqlite.org/download.html>,
   keep **one** `sqlite3.exe` on the server (e.g. `…\ue4ss\Mods\shared\`), and set
   `Config.lua` → `sqliteExe` to that path (or `"sqlite3.exe"` for PATH). **Or skip
   the file edit** and set it from chat: `washer set-sqlite <path-to-sqlite3.exe>`
   (`washer set-sqlite off` to clear). With `sqliteExe = nil` (default) no DB is
   read. Default-on/per-flag never need it.
4. The shared gating library is expected at `ue4ss\Mods\shared\Scripts\gating.lua`
   (shipped with ClothesDryer / FlagUpkeep / GarbageGoober). Keep the `shared`
   folder alongside this one.
5. Enable it: add this line to `ue4ss\Mods\mods.txt`
   ```
   WashingMachine : 1
   ```
   Do **not** create `enabled.txt` — it silently overrides `mods.txt`.
6. Make sure `ue4ss\UE4SS-settings.ini` has:
   ```
   HookProcessInternal = 1
   HookProcessLocalScriptFunction = 1
   ```
7. Start the server, then check `WashingMachine.log` (created in this folder) for
   `WashingMachine loaded`.

## Using it

Type commands in **normal in-game chat** (not `#` admin commands). `washer` shows
the full list. Quick start for a base owner:

1. Build (and place) an **Improvised Wardrobe** inside your flag.
2. Put the activation recipe in it: **5× Metal Scraps + any Alternator + 1× Wire
   + 5× Bolts + 2× Hoses** (stacks count by total quantity).
   - The **hose** leaf-class name in `Config.lua` is a best guess. Put a hose in
     the wardrobe and run **`washer scan`** to read its real class, then fix the
     `Hoses` entry in `Config.lua` and `washer reload`.
3. Stand next to the wardrobe and type **`washer activate`**. The recipe is
   consumed and the wardrobe becomes a washer.
4. To wash a load:
   - Put a **full bar of soap** and the **dirty clothes** inside the wardrobe.
   - **Hold a full water bucket** in your hands (buckets auto-empty when placed
     in a container, so it must be held — not put in the wardrobe).
   - Stand next to the washer and type **`washer wash`**.
   - The clothes become **clean + damp**, the **soap is consumed**, and the
     **bucket is emptied**. (Dry the damp clothes with the ClothesDryer mod.)

Handy commands:

- `washer check` — your wardrobes, recipe status, each garment's dirtiness, soap
  present?, and whether your held bucket is full
- `washer scan` — list the exact item classes in your wardrobe (used to tune the
  recipe in `Config.lua`, e.g. the hose)
- `washer deactivate` — turn a washer back into a plain wardrobe (no refund)
- `washer status` / `washer add <player>` — admin: access-control summary /
  enable washing for a player's base

## Notes

- **Washing is on-demand, not automatic.** Unlike the dryer (a timed loop), the
  washer only acts when you run `washer wash` — that's when the soap and water are
  consumed. So nothing is used up until you choose to wash.
- **The bucket must be held.** SCUM empties a water bucket the instant it's placed
  in a container, so it can't go in the wardrobe — hold it while you run the
  command.
- **Activation keyed by location.** A washer is remembered by where the wardrobe
  sits, so it survives renames and server restarts. **Moving** the wardrobe
  (pick up + replace) makes a new spot — re-run `washer activate`.
- **Washing needs you nearby.** SCUM only keeps container contents "live" while a
  player is observing them, so stand by the washer when you run `washer wash`.
- **Still looks dirty/dry after washing?** The server already cleaned + dampened
  it; your client re-syncs a beat later (or on reopening the wardrobe).
- **Water containers are safe.** Only clothing is cleaned/dampened — canteens,
  bottles, etc. are never touched (the held bucket is the one intentional drain).

## Configuration (`Scripts/Config.lua`)

- `recipe` — the activation ingredients (class names + total counts). Use
  `washer scan` to confirm class names on your build (especially the **hose**).
- `dampFraction` — how wet washed clothes are left, as a fraction of their max
  (default 0.05 = 5%).
- `soapClass` / `soapFullUsage` — what counts as a full bar of soap to consume.
- `bucketClass` / `bucketFullAmount` — what counts as a full water bucket to empty.
- `dirtThreshold` — minimum dirtiness for a garment to be considered "dirty".
- `requireAdmin` — gate admin commands behind SCUM admin status (default true).
- `entitlementsEnabled` — when **true** the gate is active but ships **default-on**,
  so every flag washes out of the box. Restrict/sell access with `washer default off`
  + per-player grants (`washer add <player>`, the donation model — that's the only
  part that needs `sqlite3.exe`, install step 3) or per-flag overrides (no DB).
  When **false**, washing works in any flag and no DB is ever read. Edit, then
  `washer reload` in chat (or restart).
