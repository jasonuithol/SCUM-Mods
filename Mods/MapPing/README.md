# MapPing

A server-side SCUM (UE4SS) mod with a **two-way** Discord bridge for map pings:

**Out — in-game → Discord.** When a player types **`ping`** in chat, their in-game
position and name are sent to a companion web service (the **sidecar**), which draws
the spot on the SCUM map and posts it to a Discord channel.

**Back — Discord → in-game.** That Discord message carries a row of color buttons
(green, red, hot pink, yellow, cyan, orange, violet, white). Clicking one broadcasts
a circle of that color at the location onto **every connected player's in-game map**
(auto-clearing after a timeout).

```
                 ┌─────────────────────────── out ──────────────────────────┐
player types     │  MapPing  ──HTTP POST /ping──►  sidecar  ──►  Discord      │
"ping"  ─────────┘  (name+coords)                 (map img)     (embed + 2 buttons)
                 ┌─────────────────────────── back ─────────────────────────┐
all clients' map │  MapPing  ◄──HTTP GET /commands── sidecar ◄── button click │
 ◄── colored ────┘  (poll, then broadcast a custom-zone circle to everyone)   │
   circle
```

Server-side only — no client files, so it coexists with BattlEye.

> **Companion service:** the sidecar this mod talks to lives in this same repo at
> [`../../Services/MapPingService/`](../../Services/MapPingService/). Its `SIDECAR_API_KEY`
> must match this mod's `Config.lua` `apiKey`. Full setup walkthrough:
> [`Services/MapPingService/SETUP.md`](../../Services/MapPingService/SETUP.md).

## Chat commands

| Typed in chat | Who | Does |
|---|---|---|
| `ping` | anyone | Share your current location to Discord (posts a map + color buttons) |
| `pingcal` | anyone | Log your raw world coords (for calibration) — see below |
| `ping reload` | admin | Hot-reload `Config.lua` + `ping.lua` + `pingback.lua` (no restart) |

Matching is exact and case-insensitive, so normal sentences containing "ping" don't fire.

## How the reverse path works (Discord buttons → in-game)

The mod can't receive pushes (UE4SS Lua can't host a server), so it **polls** the
sidecar on a timer (`GET /commands`, non-blocking detached curl). Each color
button click enqueues a `map_ping` command (with its `color`) in the sidecar; the
next poll picks it up and draws a circle on everyone's map via SCUM's **custom-zone**
system
(`UCustomZoneRegistry:NetMulticast_ReceiveCustomZoneData` on the GameState). Pings
are tracked in an active list and auto-expire; existing server zones (trader/outpost
circles) are always preserved.

This is purely a **visual** overlay — the ping config uses `EventHandlingMethod =
Ignore`, so it has no effect on gameplay (building, lockpicking, etc.).

> The crash-free recipe behind this (and the gotchas — e.g. never hand-build a
> struct with an `FName` field) was reverse-engineered in
> [`../CustomZoneProbe/`](../CustomZoneProbe/); its README documents the details.

## Install

1. Install official **RE-UE4SS** into `...\SCUM\Binaries\Win64\`.
2. Copy the `MapPing\` folder into `...\SCUM\Binaries\Win64\ue4ss\Mods\`.
3. Replace the shipped `ue4ss\UE4SS-settings.ini` with the bundled
   `UE4SS-settings-SCUM.ini` (stock settings crash SCUM; this enables only
   `HookProcessInternal` + `HookProcessLocalScriptFunction`, which the chat hook needs).
4. Add `MapPing : 1` to `ue4ss\Mods\mods.txt` (**not** `enabled.txt`).
5. Edit the `MOD_DIR` path at the top of `Scripts\main.lua` to match your server.
6. Edit `Scripts\Config.lua` — set `sidecarUrl` and `apiKey` to match your sidecar.
7. Start the sidecar (separate project), then start the server. Watch `MapPing.log`.

## Calibration (do this once)

The sidecar converts world coordinates to map pixels using configured world
bounds. To find them:

1. In-game, stand somewhere you can pinpoint on the map image and type `pingcal`.
   The raw `X`/`Y` are written to `MapPing.log` and echoed back in chat.
2. Do it again at a second, far-apart spot.
3. Give those two `(world X, world Y)` ↔ `(pixel on image)` pairs to the sidecar's
   `WORLD_MIN/MAX_X/Y` settings (solve the linear mapping). If the result is
   mirrored on an axis, swap that axis's min/max.

> The in-game broadcast (reverse path) needs **no** calibration — custom-zone
> coordinates are raw world centimetres, the same values the ping already captured.

## Config (`Scripts/Config.lua`)

Forward path: `pingTrigger`, `calTrigger`, `sidecarUrl`, `apiKey`, `curlExe`,
`httpTimeoutSec`, `replyInChat`.

Reverse path:

| Setting | Default | Meaning |
|---|---|---|
| `pollEnabled` | `true` | Poll the sidecar for Discord button pings |
| `pollIntervalSec` | `5` | How often to poll (keep ≥ `httpTimeoutSec`) |
| `pingExpireSec` | `30` | A broadcast ping auto-clears after this many seconds |
| `pingRadiusCm` | `30000` | Circle radius in world cm (30000 = 300 m) |
| `pulseEnabled` | `true` | Animate ping circles (radius "breathes") — see warning below |
| `pulseIntervalMs` | `1500` | Re-broadcast cadence — **keep high** (see warning) |
| `pulsePeriodSec` | `5.0` | Seconds per full breath (one shrink+grow cycle) |
| `pulseAmplitude` | `0.3` | Radius swing as a fraction of base (`0.3` = 70%…130%) |

### Pulse animation (and why the interval must stay high)

Ping circles "breathe" so they stand out from the static trader/outpost circles.
There's no client-side tween, so the mod **re-broadcasts the whole zone set on a
timer** (`pulseIntervalMs`) with each ping's radius scaled by a sine wave; it's idle
when no pings are active.

> ⚠️ **Each re-broadcast forces every client to re-bake its map render target** —
> SCUM's custom-zone system is built for occasional admin edits, not animation. So
> `pulseIntervalMs` is a lag dial that must stay **high** (1500 ms is the tested
> default). Low values don't just lag: ~500 ms was observed to **desync the client
> map overlay into a stuck "ghost" circle** that only a reconnect clears. Set
> `pulseEnabled = false` for zero-cost static circles. The pulse interval/period are
> read from live config, so `ping reload` re-tunes them without a restart.

### Ping colors

The palette lives in `pingback.lua` as `MP.palette` (color name → `FLinearColor`
fractions; alpha is fixed at `0.55`). Ships with `green`, `red`, `pink` (hot pink),
`yellow`, `cyan`, `orange`, `violet`, `white`. To add one: add an entry here **and**
a matching `(key, emoji, label, style)` row in the sidecar's `PING_COLORS` (`bot.py`)
— the `color` key must match on both sides. Unknown colors fall back to `green`.
`applyPings` builds the custom-zone configs on the fly, one per color actually in use.

## Files

- `Scripts/main.lua` — bootstrap: registers the chat hook; `MP.reload()` (re)starts
  the poll + pulse loops (guarded), so `ping reload` activates them without a restart.
- `Scripts/ping.lua` — reloadable engine for the **out** path (`ping`/`pingcal`).
- `Scripts/pingback.lua` — reloadable engine for the **back** path (JSON decode,
  poll loop, custom-zone broadcast, active-ping expiry, pulse animation, color palette).
- `Scripts/Config.lua` — operator config.

## Notes / tuning

- **Non-blocking:** all curl calls are launched detached (`start "" /B`) so network
  latency never stalls the server tick. The reverse poll is decoupled — each tick
  reads the previous response file, then launches the next GET. Windows 10+ ships
  `curl.exe`; set `curlExe` to an absolute path in `Config.lua` if it isn't found.
- **Safety:** every game-object access is wrapped in `pcall`; the JSON decoder
  returns `nil` on malformed input rather than throwing; a bad command can't crash
  the server tick.
- The chat hook is `/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage`,
  the same one the other mods in this repo use.
- Discord buttons are per-message, so they stop working if the **sidecar** restarts
  (in-flight pings are unaffected). Making them survive a sidecar restart is a
  future refinement.
