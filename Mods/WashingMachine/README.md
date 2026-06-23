# WashingMachine

A **server-side** SCUM mod (UE4SS). Turns an **Improvised Wardrobe** into a
**washing machine**: dirty clothing placed inside an activated wardrobe — together
with a full bar of soap — is washed **clean and left damp** when the owner runs
`washer wash` while **holding a full water bucket**. A wardrobe becomes a washer
by consuming a build **recipe** placed inside it.

Sibling of the **ClothesDryer** mod — wash the dirt out here, then dry it there.

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
none). Three ways to install follow — **Vortex** (easiest), or one of the two
manual walk-throughs (use one).

---

## Install — Vortex (easiest)

If you use the [Vortex](https://www.nexusmods.com/vortex) mod manager with the
[**SCUM (UE4SS)** game extension](https://www.nexusmods.com/site/mods/2018), this is by far the simplest path — Vortex sets up
UE4SS and enables the mod for you, so you can skip the manual UE4SS download, the
settings file, and the mod-list editing described below.

1. **Manage the game in Vortex** — *SCUM Dedicated Server* (server-side,
   recommended) or *SCUM* (single-player). The first time you manage it, the
   extension automatically downloads UE4SS and applies the SCUM-safe settings.
2. **Install this mod** — click **Mod Manager Download** on the Nexus *Files* page,
   or drag the mod's `.zip` onto Vortex's **Mods** tab.
3. **Enable** the mod and click **Deploy**. Vortex installs it to
   `…\ue4ss\Mods\WashingMachine\` and adds it to the UE4SS mod list for you.
4. **Launch** — click Vortex's **Play** button; it runs with BattlEye **off** by
   default (modded play), for both the dedicated server and single-player. A
   **"with BattlEye"** launcher tool is available if you ever need it. In game,
   type **`washer`** in normal chat to confirm it loaded.

Everything below is only needed for a **manual** install (without Vortex).

---

## Install — Dedicated server (recommended)

Server-side only: clients stay vanilla, so **client BattlEye stays on** and nothing
runs on players' PCs. Throughout, `<Win64>` means
`…\SCUM\Binaries\Win64\` — the folder that contains **`SCUMServer.exe`** (e.g.
`C:\Program Files (x86)\Steam\steamapps\common\SCUM Server\SCUM\Binaries\Win64\`).

1. **Install UE4SS into the server.** Extract the UE4SS download into `<Win64>\`
   so that **`dwmapi.dll`** and the **`ue4ss\`** folder sit directly next to
   `SCUMServer.exe`.
2. **Apply the SCUM-safe settings.** Take **`UE4SS-settings-SCUM.ini`** from this
   download, copy it to `<Win64>\ue4ss\`, and rename it to **`UE4SS-settings.ini`**
   (overwrite the one UE4SS shipped). Stock UE4SS settings crash SCUM on startup;
   this file is the SCUM-safe baseline and already enables the two hooks this mod
   needs (`HookProcessInternal = 1`, `HookProcessLocalScriptFunction = 1`).
3. **Install the mod.** Copy the single **`WashingMachine`** folder into
   `<Win64>\ue4ss\Mods\`. It is **self-contained** — the shared gating library is
   bundled inside it (`Scripts\gating.lua`), so there is **no separate `shared`
   folder** to install.
4. **Enable it.** Add an entry for this mod to `<Win64>\ue4ss\Mods\mods.json` (a
   JSON array):
   ```json
   { "mod_name": "WashingMachine", "mod_enabled": true }
   ```
   Current UE4SS builds use `mods.json`; older builds used a `mods.txt` line
   `WashingMachine : 1`. Do **not** create `enabled.txt` — it silently overrides the
   mod list.
5. **Launch.** Start `SCUMServer.exe` the way you normally do. BattlEye is **not
   involved server-side** — no launch flags needed here.
6. **Verify.** Open `<Win64>\ue4ss\Mods\WashingMachine\WashingMachine.log` and look
   for **`WashingMachine loaded`**. In game, type **`washer`** in normal chat — you
   should get the command list back.

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
3. **Install the mod.** Copy the single **`WashingMachine`** folder into
   `<Win64>\ue4ss\Mods\`. It is self-contained (gating library bundled inside) — no
   separate `shared` folder.
4. **Enable it.** Add an entry for this mod to `<Win64>\ue4ss\Mods\mods.json` (a
   JSON array):
   ```json
   { "mod_name": "WashingMachine", "mod_enabled": true }
   ```
   Current UE4SS builds use `mods.json`; older builds used a `mods.txt` line
   `WashingMachine : 1`. Do **not** create `enabled.txt` — it silently overrides the
   mod list.
5. **Launch the game correctly — this matters.** Leave the Windows **`BEService`**
   at its default (Manual) startup — you do **not** need to disable it. Launch
   **`SCUM.exe` directly** (the executable in `<Win64>\`, e.g. via a desktop
   shortcut) with **`-nobattleye`** in its arguments. Do **not** use Steam's *Play*
   button — Steam re-invokes the BattlEye launcher even with the flag set.
6. **Verify.** Open `<Win64>\ue4ss\Mods\WashingMachine\WashingMachine.log` and look
   for **`WashingMachine loaded`**. In your single-player game, type **`washer`** in
   normal chat — the `washer` commands work exactly as on a server.

---

## Optional: per-player access (donation model) — either setup

Washing works **out of the box with no database**. You only need this if you want to
grant access to **specific players** (`washer add <player>`), which reads `SCUM.db`
via `sqlite3.exe` and is **off by default**. To enable: download the command-line
tools from <https://sqlite.org/download.html>, keep **one** `sqlite3.exe` somewhere
on the machine, and set `Config.lua` → `sqliteExe` to that path (or `"sqlite3.exe"`
if it's on PATH). **Or** set it from chat without editing the file:
`washer set-sqlite <path-to-sqlite3.exe>` (`washer set-sqlite off` to clear). With
`sqliteExe = nil` (the default) no DB is ever read; default-on and per-flag
overrides never need it either.

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
  part that needs `sqlite3.exe`, the optional section above) or per-flag overrides
  (no DB). When **false**, washing works in any flag and no DB is ever read. Edit,
  then `washer reload` in chat (or restart).
