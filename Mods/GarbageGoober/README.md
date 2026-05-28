# GarbageGoober

A **server-side** SCUM UE4SS mod that periodically tidies bases: it sweeps loose
loot lying on the ground inside a flag's influence and moves each item into a
chest **in that same flag** whose custom name matches the item's category.

Server-side only — it works with client BattlEye on. Nothing runs on players' PCs.

## How it works

On a timer (default 60s) the mod:

1. Enumerates every loose, on-the-floor item that isn't a placed deployable.
2. Finds which **flag** (`ConZBase`) each item sits inside, using the flag's
   influence radius (`_flagInfluenceRadius`, 5000cm / 50m on stock SCUM).
3. Skips flags that aren't **enabled for sorting** (see Access control).
4. Considers only chests **inside that same flag** as destinations.
5. Builds a category **path** for the item (general → specific) from `Config.lua`
   and looks for a chest whose name matches a path node, **most-specific first**,
   falling back toward the general node. First match wins.
6. Moves the item into that chest. No match → the item is left alone and logged.

> **Scope limit (by design):** SCUM only keeps loot and chests as live objects
> within ~200m of a player. A base with nobody nearby has neither loose loot nor
> chests in the world, so the sweep simply finds nothing there. Tidying a truly
> unattended base would require offline DB editing, not this runtime sweep.

## Install

1. Copy the `GarbageGoober` folder to your server's
   `SCUM/Binaries/Win64/ue4ss/Mods/`.
2. Run **`install-libraries.ps1`** (or double-click `install-libraries.cmd`) in
   the mod folder. It downloads the official public-domain `sqlite3.exe` from
   sqlite.org (verified against a pinned SHA-256); the mod uses it to read the
   save DB read-only. The binary is intentionally not committed to git.
3. Edit `Scripts/main.lua` → `MOD_DIR` if your path differs from the default, and
   `Scripts/Config.lua` → `dbPath` to point at your server's `SCUM.db`.
4. Enable it in `ue4ss/Mods/mods.txt`:
   ```
   GarbageGoober : 1
   ```
   **Do not** create an `enabled.txt` — it silently overrides `mods.txt`.
5. For the `goober` chat trigger, `ue4ss/UE4SS-settings.ini` needs:
   ```
   HookProcessInternal = 1
   HookProcessLocalScriptFunction = 1
   ```

## Access control (who gets sorted)

With `entitlementsEnabled = true` (default), a flag is only swept if it's
**enabled** — so sorting can be sold or granted as a perk:

- **Per player (primary):** an admin runs `goober add <player>` to enable that
  player's base(s). The owner→base link is read from `SCUM.db` read-only (via the
  bundled `sqlite3.exe`); entitlements are stored as stable Steam64 IDs, so they
  survive name changes and base rebuilds.
- **Per flag (fallback):** `goober flag on|off|clear` forces a specific base
  on/off, overriding the per-player decision.
- **Global default:** `goober default on|off` sets what un-granted bases do.
- **Player opt-out:** a player can `goober pause` / `resume` sorting for their own
  flag.

Precedence: per-flag override > player-enabled > global default, and a player
pause suppresses sorting on top of that. Set `entitlementsEnabled = false` to drop
the gate entirely and sort every flag.

Enabled players, flag overrides, pauses, and the custom access message all persist
in `entitlements.lua` in the mod folder, surviving reloads **and** server restarts.

## Configure

Operator-facing settings live in `Scripts/Config.lua`:

- `sweepIntervalMs` — sweep period. Changing it needs a restart; use `goober now`
  meanwhile.
- `flagRadiusOverride` — `nil` reads the live game radius; set a number to force one.
- `nameContains` — exact chest-name match (false) vs substring match (true).
- `chatTrigger` — the word that starts a command in normal chat (default `goober`).
- `requireAdmin` — `true` (default) gates the **admin** commands behind
  `IsUserAdmin`; the player commands stay open. `false` lets anyone run everything.
- `entitlementsEnabled` / `dbPath` / `sqliteExe` / `resyncIntervalMs` — the access
  gate (above), the path to `SCUM.db`, the sqlite binary (`nil` = the bundled
  copy), and how often the owner map is refreshed from the DB.
- `notEnabledMessage` — what a non-enabled player sees on a user command
  (`"default"`, `nil`/`off` = silent, or a custom string/list). Override it live
  with `goober set-access-msg`.
- `rules` / `defaultPath` — the category tree, organized **Trader > Category**
  from SCUM's real vendor categories (~98% of known item IDs mapped). Refine from
  live data with `goober classes`.

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
| `goober reload` | reload `Config.lua` + `sorter.lua`, then sweep once |
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

- `Scripts/main.lua` — bootstrap, sweep timer, `goober` chat trigger.
- `Scripts/sorter.lua` — sweep engine + command handling (enumerate → gate → match → move).
- `Scripts/Config.lua` — operator-editable settings + category rules.
- `install-libraries.ps1` / `.cmd` — fetch the bundled `sqlite3.exe`.
- `entitlements.lua` — runtime access state (generated on the server; not in git).
- `sqlite3.exe` — downloaded by the install script (not in git).
