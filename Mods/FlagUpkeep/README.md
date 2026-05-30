# FlagUpkeep

A server-side UE4SS mod for SCUM. Periodically keeps a flag's base elements
repaired to full health, spending **repair points** that you bank by depositing
**toolboxes** into a designated container in your flag. Access is gated exactly
like [GarbageGoober](../GarbageGoober/README.md): per-player (the donation/premium
model) with a per-flag override and a global default, all driven by the same
read-only `SCUM.db` owner lookup.

Server-side only — it coexists with client BattlEye (use the `-nobattleye`
client launch flag if you run a local test client; never disable the BEService).

## Player quick-start

> Keep your base patched up automatically (paste-ready for a Discord / welcome message):
>
> 1. Build a chest or wardrobe **inside your flag** and name it **exactly** `FlagUpkeep`.
> 2. Put **toolboxes** in it — Tool Box = **100** repair points, Small Tool Box = **50**, Improvised Tool Box = **20**.
> 3. **Open the chest**, then type **`upkeep deposit`** in chat. Your toolboxes turn into repair points (the boxes get used up).
> 4. Done. Every hour the mod auto-repairs your damaged base, spending **1 point per element**.
>
> Handy commands:
> - `upkeep check` — your repair points + what's ready to deposit
> - `upkeep trigger 80` — only repair pieces under 80% (lower = save points, higher = stay raid-tough)
> - `upkeep now` — repair right now instead of waiting for the hourly run
>
> Gotchas:
> - **Deposit says it read 0?** You forgot to *open the chest* — open it and run `upkeep deposit` again.
> - **Just repaired but the wall still looks cracked?** Relog — the repair already happened on the server; your client just needs to re-sync.

## How it works

Repair is driven by the game's own `NetMulticast_InteractWithElement(170)` per
element, with element ids read from `SCUM.db` — it clamps each element to full HP
(see memory `reference-scum-base-building-architecture`). The **fuel is repair
points**, not the toolboxes directly, because a placed chest's contents
virtualize and can't be read reliably at arbitrary times. So:

1. Build a chest/wardrobe in your flag named exactly **`FlagUpkeep`**
   (`Config.containerName`) and put toolboxes in it.
2. **Open the chest** and run **`upkeep deposit`** — each toolbox's charges are
   banked as repair points for that flag and the box is consumed.
   Values: **Tool_Box = 100, Tool_Box_Small = 50, Improvised_Tool_Box = 20**.
   (A box that reads 0 — e.g. chest not open — is left untouched, so you never
   lose a full one to a misread.)
3. Every cycle (default **1 hour**), if your flag is enabled, the mod repairs
   elements below your **trigger** health, spending **1 point per element**.
   This uses the banked balance only, so it works with the chest closed and
   even unattended.

**Strategy:** 1 point fully repairs an element from *any* health level, so
repairing late (low trigger) conserves points but leaves the base weaker between
cycles; repairing early (high trigger) costs more points but stays raid-tough.
Each flag sets its own trigger with `upkeep trigger <percent>`.

> **Two lag effects to know:** element health is read from `SCUM.db`, which only
> updates on the server's periodic save (~minutes), so damage/repair take a save
> to show in `upkeep check`. And connected clients don't redraw repaired
> integrity until they re-sync (relog / move away+back) — the repair is applied
> server-side immediately regardless. A per-element cooldown
> (`Config.repairCooldownSec`) stops a quick re-run from spending a second point
> before the DB catches up.

## Chat commands (normal chat, no `#`)

| Command | Who | Effect |
| :-- | :-- | :-- |
| `upkeep` | anyone | help |
| `upkeep deposit` | anyone* | bank toolboxes in your **open** container as repair points |
| `upkeep check` | anyone | show repair points, depositable toolboxes, trigger + damage |
| `upkeep now` | anyone* | run upkeep on your flag now |
| `upkeep trigger <%>` | anyone* | repair elements once they drop below this health % |
| `upkeep pause` / `resume` | anyone* | stop/resume auto-upkeep for your flag |
| `upkeep status` / `list` | admin | access summary / full breakdown |
| `upkeep add` / `remove <player>` | admin | enable/disable a player (name or Steam64) |
| `upkeep flag on\|off\|clear [baseId]` | admin | per-flag override (blank = your flag) |
| `upkeep default on\|off` | admin | keep up every flag by default, or none |
| `upkeep pause-all` / `resume-all` | admin | pause/resume the whole job server-wide |
| `upkeep reload` | admin | reload `Config.lua` then run one cycle |
| `upkeep get-access-msg` / `set-access-msg …` | admin | customise the "not enabled" message |
| `upkeep damage [amt]` | admin | **TEST only** (needs `Config.allowTestDamage=true`): damage every element in your flag |

\* gated by entitlement for that flag.

## Install

1. `install-libraries.cmd` (fetches `sqlite3.exe`, SHA-256-verified, into this
   folder — it is **not** committed to git).
2. Copy this folder to `…\SCUM\Binaries\Win64\ue4ss\Mods\FlagUpkeep`.
3. Add `FlagUpkeep : 1` to `…\ue4ss\Mods\mods.txt`
   (**never** create `enabled.txt` — it silently overrides `mods.txt`).
4. Ensure `UE4SS-settings.ini` has `HookProcessInternal=1` and
   `HookProcessLocalScriptFunction=1` (needed for the chat trigger).
5. Edit `Scripts/main.lua`'s `MOD_DIR` and `Scripts/Config.lua` to taste
   (keep `allowTestDamage = false` on a real server), then start the server.

## Shared lineage / future library

The access-control, flag-scoping, `SCUM.db` reader, chat-command framework, and
timer in `Scripts/upkeep.lua` are copy-adapted from GarbageGoober's
`Scripts/sorter.lua` (proven in production). Now that a second consumer exists,
the identical parts are the candidate for a shared `lib/` — to be extracted once
both mods are stable.
