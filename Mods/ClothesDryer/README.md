# ClothesDryer

A **server-side** SCUM mod (UE4SS). Turns an **Improvised Wardrobe** into a
powered **clothes dryer**: wet clothing left inside an activated wardrobe dries
automatically. A wardrobe becomes a dryer by consuming a build **recipe** placed
inside it.

Built for a **dedicated server** (runs server-side, so clients stay vanilla and
**client BattlEye stays on** — the recommended setup). It also works in
**client-hosted single-player**, with the caveats called out in that section
below. Pick the matching walk-through.

## What you need (both setups)

- **SCUM** — a dedicated server you administer (SteamCMD app `3792580`) **or**, for
  single-player, your own SCUM game client.
- **UE4SS** — the loader this mod runs inside. Get it from the RE-UE4SS
  **experimental-latest** page and download the file named **`UE4SS_v3.0.1-*.zip`**
  (e.g. `UE4SS_v3.0.1-954-g272ce2f8.zip`; the exact build number changes over time):
  <https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest>.
  You need **this** build line — it uses the modern **`ue4ss\` sub-folder layout**
  that every path below assumes (`dwmapi.dll` next to the game `.exe`, everything
  else under `ue4ss\`). The older *stable* `v3.0.1` download uses a different, flat
  layout and will **not** match these steps — don't use it. What actually makes
  UE4SS stable on SCUM is the shipped `UE4SS-settings-SCUM.ini` (step 2 below), not
  the exact build number.

This mod is **pure Lua** — it ships no `.pak`, so it needs **only UE4SS itself**.
The old `-fileopenlog` / `-fileloadlog` launch flag and the **SCUM-AllowMods** PAK
patch are **not** required (those only re-enable *unsigned PAK* mods; this mod has
none). Two separate, complete walk-throughs follow — use **one**.

---

## Install — Dedicated server (recommended)

Server-side only: clients stay vanilla, so **client BattlEye stays on** and nothing
runs on players' PCs. Throughout, `<Win64>` means
`…\SCUM\Binaries\Win64\` — the folder that contains **`SCUMServer.exe`** (e.g.
`C:\scumserver\SCUM\Binaries\Win64\`).

1. **Install UE4SS into the server.** Extract the UE4SS download into `<Win64>\`
   so that **`dwmapi.dll`** and the **`ue4ss\`** folder sit directly next to
   `SCUMServer.exe`.
2. **Apply the SCUM-safe settings.** Take **`UE4SS-settings-SCUM.ini`** from this
   download, copy it to `<Win64>\ue4ss\`, and rename it to **`UE4SS-settings.ini`**
   (overwrite the one UE4SS shipped). Stock UE4SS settings crash SCUM on startup;
   this file is the SCUM-safe baseline and already enables the two hooks this mod
   needs (`HookProcessInternal = 1`, `HookProcessLocalScriptFunction = 1`).
3. **Install the mod.** Copy the single **`ClothesDryer`** folder into
   `<Win64>\ue4ss\Mods\`. It is **self-contained** — the shared gating library is
   bundled inside it (`Scripts\gating.lua`), so there is **no separate `shared`
   folder** to install.
4. **Point the mod at itself.** Open
   `<Win64>\ue4ss\Mods\ClothesDryer\Scripts\main.lua` and set **`MOD_DIR`** (near
   the top) to that folder's full path, e.g.
   `C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\ClothesDryer`.
5. **Enable it.** Add this line to `<Win64>\ue4ss\Mods\mods.txt`:
   ```
   ClothesDryer : 1
   ```
   Do **not** create `enabled.txt` — it silently overrides `mods.txt`.
6. **Launch.** Start `SCUMServer.exe` the way you normally do. BattlEye is **not
   involved server-side** — no launch flags needed here.
7. **Verify.** Open `<Win64>\ue4ss\Mods\ClothesDryer\ClothesDryer.log` and look for
   **`ClothesDryer loaded`**. In game, type **`dryer`** in normal chat — you should
   get the command list back.

---

## Install — Single-player / client-hosted (your own risk)

> **⚠ Read this first.** Single-player has **no separate server process**, so this
> mod has to run **inside your own SCUM client**, which means injecting UE4SS and
> launching with **`-nobattleye`**. That is **client-side modding, and BattlEye can
> ban your SCUM account for it.** Do this only on **your own account and entirely
> at your own risk.** If you can use a dedicated server instead, do — that keeps
> client BattlEye on and carries no such risk.

Throughout, `<Win64>` means your **client's**
`…\SCUM\Binaries\Win64\` — the folder that contains **`SCUM.exe`** (default Steam
path: `C:\Program Files (x86)\Steam\steamapps\common\SCUM\SCUM\Binaries\Win64\`).

1. **Install UE4SS into the client.** Extract the UE4SS download into `<Win64>\`
   so that **`dwmapi.dll`** and the **`ue4ss\`** folder sit directly next to
   `SCUM.exe`.
2. **Apply the SCUM-safe settings.** Take **`UE4SS-settings-SCUM.ini`** from this
   download, copy it to `<Win64>\ue4ss\`, and rename it to **`UE4SS-settings.ini`**
   (overwrite the one UE4SS shipped).
3. **Install the mod.** Copy the single **`ClothesDryer`** folder into
   `<Win64>\ue4ss\Mods\`. It is self-contained (gating library bundled inside) — no
   separate `shared` folder.
4. **Point the mod at itself.** Open
   `<Win64>\ue4ss\Mods\ClothesDryer\Scripts\main.lua` and set **`MOD_DIR`** to that
   folder's full **client** path, e.g.
   `C:\Program Files (x86)\Steam\steamapps\common\SCUM\SCUM\Binaries\Win64\ue4ss\Mods\ClothesDryer`.
5. **Enable it.** Add this line to `<Win64>\ue4ss\Mods\mods.txt`:
   ```
   ClothesDryer : 1
   ```
   Do **not** create `enabled.txt` — it silently overrides `mods.txt`.
6. **Launch the game correctly — this matters.** Leave the Windows **`BEService`**
   at its default (Manual) startup — you do **not** need to disable it. Launch
   **`SCUM.exe` directly** (the executable in `<Win64>\`, e.g. via a desktop
   shortcut) with **`-nobattleye`** in its arguments. Do **not** use Steam's *Play*
   button — Steam re-invokes the BattlEye launcher even with the flag set.
7. **Verify.** Open `<Win64>\ue4ss\Mods\ClothesDryer\ClothesDryer.log` and look for
   **`ClothesDryer loaded`**. In your single-player game, type **`dryer`** in normal
   chat — the `dryer` commands work exactly as on a server.

---

## Optional: per-player access (donation model) — either setup

Drying works **out of the box with no database**. You only need this if you want to
grant access to **specific players** (`dryer add <player>`), which reads `SCUM.db`
via `sqlite3.exe` and is **off by default**. To enable: download the command-line
tools from <https://sqlite.org/download.html>, keep **one** `sqlite3.exe` somewhere
on the machine, and set `Config.lua` → `sqliteExe` to that path (or `"sqlite3.exe"`
if it's on PATH). **Or** set it from chat without editing the file:
`dryer set-sqlite <path-to-sqlite3.exe>` (`dryer set-sqlite off` to clear). With
`sqliteExe = nil` (the default) no DB is ever read; default-on and per-flag
overrides never need it either.

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
- **A tiny bit of residual wetness (~1%) can remain.** This is harmless and clears
  up very quickly on its own — wear the garment in the **sun**, or stand near a
  **fire**, and the last of it dries off in moments.
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
