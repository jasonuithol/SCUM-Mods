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
3. Considers only chests **inside that same flag** as destinations.
4. Builds a category **path** for the item (general → specific) from `Config.lua`
   and looks for a chest whose name matches a path node, **most-specific first**,
   falling back toward the general node. First match wins.
5. Moves the item into that chest. No match → the item is left alone and logged.

> **Scope limit (by design):** SCUM only keeps loot and chests as live objects
> within ~200m of a player. A base with nobody nearby has neither loose loot nor
> chests in the world, so the sweep simply finds nothing there. Tidying a truly
> unattended base would require offline DB editing, not this runtime sweep.

## Install

1. Copy the `GarbageGoober` folder to your server's
   `SCUM/Binaries/Win64/ue4ss/Mods/`.
2. Edit `Scripts/main.lua` → `MOD_DIR` if your path differs from the default.
3. Enable it in `ue4ss/Mods/mods.txt`:
   ```
   GarbageGoober : 1
   ```
   **Do not** create an `enabled.txt` — it silently overrides `mods.txt`.
4. For the `goober` chat trigger, `ue4ss/UE4SS-settings.ini` needs:
   ```
   HookProcessInternal = 1
   HookProcessLocalScriptFunction = 1
   ```

## Configure

Everything operator-facing lives in `Scripts/Config.lua`:

- `sweepIntervalMs` — sweep period. Changing it needs a restart (the timer
  interval is fixed at load); use `goober now` to sweep on demand meanwhile.
- `flagRadiusOverride` — `nil` reads the live game radius; set a number to force one.
- `nameContains` — exact chest-name match (false) vs substring match (true).
- `chatTrigger` — the word that starts a command in normal chat (default `goober`).
- `requireAdmin` — `true` only lets SCUM admins drive the mod via chat.
- `rules` / `defaultPath` — the category tree, organized **Trader > Category**
  using SCUM's real vendor categories. Refine it from live data (see below).

Name your chests after a **category** leaf (e.g. `Ammo`, `Drink`, `Feet`) for
fine sorting, or after a **trader** group (e.g. `Armorer`, `Bartender`,
`GeneralGoods`) to catch a whole group; loot flows to the deepest match.

## Chat commands (admin only — typed in NORMAL chat, no `#`)

Commands are typed as normal chat starting with the trigger word, e.g. `goober now`.
They are **not** SCUM admin commands, so they never produce an "Unrecognized
command" reply — but the text does appear in chat to whoever shares the channel.
Only SCUM admins are obeyed (`requireAdmin`).

| Command           | Effect                                             |
|-------------------|----------------------------------------------------|
| `goober`          | show the help / command list                       |
| `goober now`      | run one sweep now                                  |
| `goober classes`  | dump every distinct live item class + its category (tree-building) |
| `goober chests`   | audit chests in your current flag: each chest's category/parent, or `[UNMATCHED]` |
| `goober types`    | list top-level categories; `goober types <name>` lists that category's sub-types |
| `goober reload`   | reload `Config.lua` + `sorter.lua`, then sweep once |
| `goober pause`    | pause the timer                                    |
| `goober resume`   | resume the timer                                   |

Command handling lives in `sorter.lua`, so it hot-reloads with `goober reload`;
only changes to `main.lua` itself need a server restart.

## Logs

`GarbageGoober.log` in the mod folder (truncated each server start). `print`
output also goes to the UE4SS console.

## Files

- `Scripts/main.lua` — bootstrap, sweep timer, `goober` chat trigger.
- `Scripts/sorter.lua` — the sweep engine (enumerate → flag-scope → match → move).
- `Scripts/Config.lua` — operator-editable settings + category rules.
