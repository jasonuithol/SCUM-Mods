# GarbageGoober

A **server-side** SCUM UE4SS mod that periodically tidies bases: it sweeps loose
loot lying on the ground inside a flag's influence and moves each item into a
chest **in that same flag** whose custom name matches the item's category.

Built for a **dedicated server** (runs server-side, so clients stay vanilla and
**client BattlEye stays on** — the recommended setup). It also works in
**client-hosted single-player**, with the caveats called out in that section
below. Pick the matching walk-through.

## How it works

On a timer (default 60s) the mod:

1. Enumerates every loose, on-the-floor item that isn't a placed deployable.
2. Finds which **flag** (`ConZBase`) each item sits inside, using the flag's
   influence radius (`_flagInfluenceRadius`, 5000cm / 50m on stock SCUM).
3. Skips flags that aren't **enabled for sorting** (see Access control).
4. Considers only chests **inside that same flag** as destinations.
5. Builds a category **path** for the item (general → specific) from
   `categories.yaml` and looks for a chest whose name matches a path node,
   **most-specific first**, falling back toward the general node. First match wins.
6. Moves the item into that chest. No match → the item is left alone and logged.

> **Scope limit (by design):** SCUM only keeps loot and chests as live objects
> within ~200m of a player. A base with nobody nearby has neither loose loot nor
> chests in the world, so the sweep simply finds nothing there. Tidying a truly
> unattended base would require offline DB editing, not this runtime sweep.

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
`C:\Program Files (x86)\Steam\steamapps\common\SCUM Server\SCUM\Binaries\Win64\`).

1. **Install UE4SS into the server.** Extract the UE4SS download into `<Win64>\`
   so that **`dwmapi.dll`** and the **`ue4ss\`** folder sit directly next to
   `SCUMServer.exe`.
2. **Apply the SCUM-safe settings.** Take **`UE4SS-settings-SCUM.ini`** from this
   download, copy it to `<Win64>\ue4ss\`, and rename it to **`UE4SS-settings.ini`**
   (overwrite the one UE4SS shipped). Stock UE4SS settings crash SCUM on startup;
   this file is the SCUM-safe baseline and already enables the two hooks this mod
   needs (`HookProcessInternal = 1`, `HookProcessLocalScriptFunction = 1`).
3. **Install the mod.** Copy the single **`GarbageGoober`** folder into
   `<Win64>\ue4ss\Mods\`. It is **self-contained** — the shared gating library is
   bundled inside it (`Scripts\gating.lua`), so there is **no separate `shared`
   folder** to install.
4. **Point the mod at itself.** Open
   `<Win64>\ue4ss\Mods\GarbageGoober\Scripts\main.lua` and set **`MOD_DIR`** (near
   the top) to that folder's full path, e.g.
   `C:\Program Files (x86)\Steam\steamapps\common\SCUM Server\SCUM\Binaries\Win64\ue4ss\Mods\GarbageGoober`.
5. **Enable it.** Add this line to `<Win64>\ue4ss\Mods\mods.txt`:
   ```
   GarbageGoober : 1
   ```
   Do **not** create `enabled.txt` — it silently overrides `mods.txt`.
6. **Launch.** Start `SCUMServer.exe` the way you normally do. BattlEye is **not
   involved server-side** — no launch flags needed here.
7. **Verify.** Open `<Win64>\ue4ss\Mods\GarbageGoober\GarbageGoober.log` and look
   for **`GarbageGoober is loaded`**. In game, type **`goober`** in normal chat —
   you should get the command list back.

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
3. **Install the mod.** Copy the single **`GarbageGoober`** folder into
   `<Win64>\ue4ss\Mods\`. It is self-contained (gating library bundled inside) — no
   separate `shared` folder.
4. **Point the mod at itself.** Open
   `<Win64>\ue4ss\Mods\GarbageGoober\Scripts\main.lua` and set **`MOD_DIR`** to that
   folder's full **client** path, e.g.
   `C:\Program Files (x86)\Steam\steamapps\common\SCUM\SCUM\Binaries\Win64\ue4ss\Mods\GarbageGoober`.
5. **Enable it.** Add this line to `<Win64>\ue4ss\Mods\mods.txt`:
   ```
   GarbageGoober : 1
   ```
   Do **not** create `enabled.txt` — it silently overrides `mods.txt`.
6. **Launch the game correctly — this matters.** Leave the Windows **`BEService`**
   at its default (Manual) startup — you do **not** need to disable it. Launch
   **`SCUM.exe` directly** (the executable in `<Win64>\`, e.g. via a desktop
   shortcut) with **`-nobattleye`** in its arguments. Do **not** use Steam's *Play*
   button — Steam re-invokes the BattlEye launcher even with the flag set.
7. **Verify.** Open `<Win64>\ue4ss\Mods\GarbageGoober\GarbageGoober.log` and look
   for **`GarbageGoober is loaded`**. In your single-player game, type **`goober`**
   in normal chat — the `goober` commands work exactly as on a server.

---

## Optional: per-player access (donation model) — either setup

Sorting works **out of the box with no database**. You only need this if you want to
grant access to **specific players** (`goober add <player>`), which reads `SCUM.db`
read-only via `sqlite3.exe` and is **off by default**. To enable: download the
command-line tools from <https://sqlite.org/download.html>, keep **one**
`sqlite3.exe` somewhere on the machine, and in `Scripts/Config.lua` set `sqliteExe`
to that path (or `"sqlite3.exe"` if it's on PATH) plus `dbPath` to your `SCUM.db`.
**Or** set it from chat without editing the file: `goober set-sqlite
<path-to-sqlite3.exe>` (`goober set-sqlite off` to clear). With `sqliteExe = nil`
(the default) no DB is ever read; default-on and per-flag overrides never need it.

## Access control (who gets sorted)

With `entitlementsEnabled = true` (default) the gate is active. Out of the box the
**global default is ON**, so every flag is sorted — the mod just works. The gate
lets you restrict or sell access:

- **Per player (primary):** an admin runs `goober add <player>` to enable that
  player's base(s). This is the only feature that needs a database: the owner→base
  link is read from `SCUM.db` read-only via a **user-supplied `sqlite3.exe`** (see
  the optional section above). Entitlements are stored as stable Steam64 IDs, so
  they survive name changes and base rebuilds.
- **Per flag (fallback):** `goober flag on|off|clear` forces a specific base
  on/off, overriding the per-player decision. **No database needed.**
- **Global default:** `goober default on|off` sets what un-granted bases do
  (ships ON). **No database needed.**
- **Player opt-out:** a player can `goober pause` / `resume` sorting for their own
  flag.

Precedence: per-flag override > player-enabled > global default, and a player
pause suppresses sorting on top of that. The DB / `sqlite3.exe` is read **only**
once at least one player has been granted; default-on and per-flag use need none.
Set `entitlementsEnabled = false` to drop the gate entirely and sort every flag.

Enabled players, flag overrides, pauses, and the custom access message all persist
in `entitlements.lua` in the mod folder, surviving reloads **and** server restarts.

## Configure

Operator-facing settings live in `Scripts/Config.lua`; the category tree lives in
`Scripts/categories.yaml`:

- `sweepIntervalMs` — sweep period. Changing it needs a restart; use `goober now`
  meanwhile.
- `flagRadiusOverride` — `nil` reads the live game radius; set a number to force one.
- `nameContains` — exact chest-name match (false) vs substring match (true).
- `chatTrigger` — the word that starts a command in normal chat (default `goober`).
- `requireAdmin` — `true` (default) gates the **admin** commands behind
  `IsUserAdmin`; the player commands stay open. `false` lets anyone run everything.
- `entitlementsEnabled` / `dbPath` / `sqliteExe` / `resyncIntervalMs` — the access
  gate (above), the path to `SCUM.db`, the sqlite binary (`nil` = **disabled**, no
  DB read; set a path or `"sqlite3.exe"` on PATH to enable per-player grants), and
  how often the owner map is refreshed from the DB.
- `notEnabledMessage` — what a non-enabled player sees on a user command
  (`"default"`, `nil`/`off` = silent, or a custom string/list). Override it live
  with `goober set-access-msg`.
- `categories.yaml` — the category tree, organized **Trader > Category** from
  SCUM's real vendor categories (~98% of known item IDs mapped). It can optionally
  be pulled from a Gist on `goober reload`. Refine from live data with
  `goober classes`.

Name your chests after a **category** leaf (e.g. `Ammo`, `Drink`, `FirstAid`) for
fine sorting, or after a **trader** group (e.g. `Armorer`, `Bartender`,
`GeneralGoods`) to catch a whole group; loot flows to the deepest match.

## Chat commands

Typed in **normal** chat (no `#`), starting with the trigger word, e.g. `goober now`.
They aren't SCUM admin commands, so they never produce an "Unrecognized command"
reply — but the typed text appears in chat to whoever shares the channel. The
mod's replies are private to the player who issued the command.

**Player commands** (open to anyone):

| Command | Effect |
|---|---|
| `goober` | show the help / command list |
| `goober now` | sort the loose loot in your flag right now |
| `goober pause` / `resume` | stop / resume auto-sorting your flag |
| `goober types` | list categories; `goober types <name>` = its sub-types |
| `goober chests` | audit chests in your flag: each chest's category |

**Admin commands** (require `IsUserAdmin` when `requireAdmin = true`; hidden from
non-admins in the help):

| Command | Effect |
|---|---|
| `goober pause-all` / `resume-all` | pause / resume the automatic sweep server-wide |
| `goober classes` | dump every distinct live item class + its category (to the log) |
| `goober reload` | reload `Config.lua` + `categories.yaml` + `sorter.lua`, then sweep once |
| `goober list` | enabled players, flag overrides, and the resolved result |
| `goober status` | one-line access summary |
| `goober add` / `remove <player>` | enable / disable sorting for a player (name or Steam64) |
| `goober flag on\|off\|clear [baseId]` | per-flag override (blank = your current flag) |
| `goober default on\|off` | sort every flag by default, or none |
| `goober get-access-msg` / `set-access-msg <text\|default\|off\|reset>` | view / set the "not enabled" message |

Command handling lives in `sorter.lua`, so it hot-reloads with `goober reload`;
only changes to `main.lua` need a server restart.

## Logs

`GarbageGoober.log` in the mod folder (truncated each server start). `print`
output also goes to the UE4SS console.

## Files

- `Scripts/main.lua` — bootstrap, sweep timer, `goober` chat trigger, loads the gating lib.
- `Scripts/sorter.lua` — sweep engine + goober commands (enumerate → gate → match → move).
- `Scripts/Config.lua` — operator-editable settings.
- `Scripts/categories.yaml` — the category tree (optionally Gist-backed).
- `Scripts/gating.lua` — the shared entitlement/flag-scope/SCUM.db/chat library,
  **bundled inside this mod** (the same lib ClothesDryer / WashingMachine /
  FlagUpkeep use). The mod is self-contained — no separate `shared` folder.
- `entitlements.lua` — runtime access state (generated on the server; not in git).
- `sqlite3.exe` — only for per-player grants; user-supplied, off by default (point
  `Config.sqliteExe` at one copy, or use one on PATH; not in git).
