# MapPing

A server-side SCUM (UE4SS) mod with a **two-way** Discord bridge for map pings:

**Out — in-game → Discord.** When a player types **`ping`** in chat, their in-game
position and name are sent to a companion web service (the **sidecar**), which draws
the spot on the SCUM map and posts it to a Discord channel.

**Back — Discord → in-game.** That Discord message carries two buttons, **Ping
Green** and **Ping Red**. Clicking one broadcasts a colored circle at that location
onto **every connected player's in-game map** (auto-clearing after a timeout).

```
                 ┌─────────────────────────── out ──────────────────────────┐
player types     │  MapPing  ──HTTP POST /ping──►  sidecar  ──►  Discord      │
"ping"  ─────────┘  (name+coords)                 (map img)     (embed + 2 buttons)
                 ┌─────────────────────────── back ─────────────────────────┐
all clients' map │  MapPing  ◄──HTTP GET /commands── sidecar ◄── button click │
 ◄── red/green ──┘  (poll, then broadcast a custom-zone circle to everyone)   │
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
| `ping` | anyone | Share your current location to Discord (posts a map + Green/Red buttons) |
| `pingcal` | anyone | Log your raw world coords (for calibration) — see below |
| `ping reload` | admin | Hot-reload `Config.lua` + `ping.lua` + `pingback.lua` (no restart) |

Matching is exact and case-insensitive, so normal sentences containing "ping" don't fire.

## How the reverse path works (Discord buttons → in-game)

The mod can't receive pushes (UE4SS Lua can't host a server), so it **polls** the
sidecar on a timer (`GET /commands`, non-blocking detached curl). Each **Ping
Green/Red** button click enqueues a `map_ping` command in the sidecar; the next poll
picks it up and draws a circle on everyone's map via SCUM's **custom-zone** system
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

Ping colors live in `pingback.lua` (`MP.applyPings`).

## Files

- `Scripts/main.lua` — bootstrap: registers the chat hook + starts the poll loop.
- `Scripts/ping.lua` — reloadable engine for the **out** path (`ping`/`pingcal`).
- `Scripts/pingback.lua` — reloadable engine for the **back** path (JSON decode,
  poll loop, custom-zone broadcast, active-ping expiry).
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
