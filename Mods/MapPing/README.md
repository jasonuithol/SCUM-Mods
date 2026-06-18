# MapPing

A server-side SCUM (UE4SS) mod: when a player types **`ping`** in chat, their
in-game position and name are sent to a small companion web service (the
**sidecar**), which draws the spot on the SCUM map and posts it to a Discord
channel.

```
player types "ping"  ──►  MapPing (this mod)  ──HTTP──►  sidecar  ──►  Discord
                          reads name + coords           (FastAPI +
                                                          discord.py)
```

Server-side only — no client files, so it coexists with BattlEye.

> **Companion service:** the sidecar this mod talks to lives in this same repo at
> [`../../Services/MapPingService/`](../../Services/MapPingService/). Its `SIDECAR_API_KEY`
> must match this mod's `Config.lua` `apiKey`. Full setup walkthrough:
> [`Services/MapPingService/SETUP.md`](../../Services/MapPingService/SETUP.md).

## Chat commands

| Typed in chat | Who | Does |
|---|---|---|
| `ping` | anyone | Share your current location to Discord |
| `pingcal` | anyone | Log your raw world coords (for calibration) — see below |
| `ping reload` | admin | Hot-reload `Config.lua` + `ping.lua` (no restart) |

Matching is exact and case-insensitive, so normal sentences containing "ping" don't fire.

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

## Notes / tuning

- **Non-blocking:** curl is launched detached (`start "" /B`) so network latency
  never stalls the server tick. Windows 10+ ships `curl.exe`; set `curlExe` to an
  absolute path in `Config.lua` if it isn't found.
- **Safety:** every game-object access is wrapped in `pcall`, and the chat handler
  bails cheaply on non-matching messages before touching any UObject.
- The chat hook is `/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage`,
  the same one the other mods in this repo use.
