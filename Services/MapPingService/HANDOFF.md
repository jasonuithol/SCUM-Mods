# Session handoff — Discord sidecar + SCUM MapPing

Written 2026-06-17. This captures everything built/decided in the session, so work
can resume on Windows without the chat history.

> **STATUS 2026-06-18: COMPLETE.** All five steps below are done — a player typing `ping`
> in-game posts their calibrated map location to Discord, verified across multiple regions.
>
> **Update 2026-06-18 (on Windows):** the sidecar is now **live end-to-end against real
> Discord**. Recreated the venv with **Python 3.12** (the machine defaults to 3.14, which
> lacks some wheels), created+invited the Discord bot, and verified a real `POST /ping`
> rendered the map marker and posted the embed to the channel. The marker lands slightly
> down-and-right of center for the test coords — expected, since world→pixel bounds are
> still the placeholder defaults (calibration = step 4, the only remaining sidecar-side
> tuning). Full Discord setup is now written up in **`SETUP.md`**.
>
> Also hardened startup error handling (previously a dead bot task was silent):
> - `main.py` — the bot task has a done-callback that logs any startup exception+traceback.
> - `bot.py` — `setup_hook` catches the `403 Forbidden` from slash-command sync and
>   re-raises a `RuntimeError` naming the guild and printing a ready-made invite link.
> So a failed start now says *why* in the console instead of just `discord_ready:false`.

## Goal

A SCUM (UE4SS) feature: a player types **`ping`** in in-game chat, and their map
location + name get posted to a Discord channel as an image with their position
marked on the SCUM map.

## Architecture (why two pieces)

We deliberately did **not** put the Discord connection inside the game mod. The
Discord Gateway is a persistent WebSocket with heartbeat/reconnect logic, which is
painful and risky to run inside UE4SS's Lua sandbox on the game thread. Instead:

```
player types "ping" in SCUM chat
   → MapPing mod (UE4SS Lua)         reads world coords + name
   → HTTP POST to localhost          {player, x, y}
   → sidecar (FastAPI + discord.py)  draws position on map PNG
   → Discord channel                 posts the image
```

Two codebases:
- **`~/Projects/DiscordBotTest`** (this folder) — the **sidecar** web service.
- **`~/Projects/SCUM-Mods/Mods/MapPing`** — the **UE4SS mod** (separate git repo,
  github.com/jasonuithol/SCUM-Mods, cloned this session).

A discrete chat "ping" was the key realization: it's a single coordinate captured
on a click/command, NOT continuous mouse tracking — so no Discord Activity / embedded
web app is needed. (An Activity would only be required for real-time cursor tracking,
which this feature doesn't need.)

---

## Part 1 — The sidecar (this folder, `DiscordBotTest`)

Python 3.12. FastAPI + discord.py share one asyncio loop: the Discord Gateway runs
as a background task started in FastAPI's `lifespan`, so `python main.py` runs both
the web server and the bot.

### Files
| File | Purpose |
|---|---|
| `main.py` | FastAPI app + lifespan that starts/stops the bot. Endpoints below. |
| `bot.py` | discord.py bot: `send_to_channel`, `send_ping`, slash commands `/broadcast` + `/controls`, a persistent button view, and an in-memory command queue. |
| `map_render.py` | Pillow: converts world coords → map pixels (linear calibration, Y-flipped) and draws a crosshair + dot + player-name label. |
| `config.py` | Settings via pydantic-settings, loaded from `.env`. |
| `.env.example` | Copy to `.env` and fill in. |
| `ue4ss_example.lua` | Early standalone Lua sketch (superseded by the real MapPing mod). |
| `requirements.txt` | fastapi, uvicorn, discord.py, pydantic-settings, Pillow. |
| `README.md` | Setup + endpoint docs. |
| `SETUP.md` | Step-by-step Windows + Discord bot setup (token, invite, IDs, smoke test). |

### Endpoints (all but `/health` require header `X-API-Key: <SIDECAR_API_KEY>`)
| Method | Path | Caller | Purpose |
|---|---|---|---|
| GET | `/health` | you | Liveness + `discord_ready` |
| POST | `/event` | mod | Relay a text event to the channel |
| POST | `/ping` | mod | Body `{player, x, y}` → marked map image to channel |
| GET | `/commands` | mod | Drain commands queued by Discord slash/buttons |

### Run
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env      # fill in DISCORD_BOT_TOKEN, DISCORD_CHANNEL_ID, DISCORD_GUILD_ID
python main.py
```

> **On Windows, do NOT reuse the `.venv` from Linux** — a Linux virtualenv won't run
> on Windows even if it got copied across. Recreate it fresh, and `copy .env.example .env`:
> ```
> python -m venv .venv
> .venv\Scripts\activate
> pip install -r requirements.txt
> copy .env.example .env
> python main.py
> ```
> A copied `__pycache__/` is harmless and can be deleted.

> **Repo rename note:** on the Windows partition the SCUM mod repo was copied as
> `SCUM-Modding` (it was `SCUM-Mods` on Linux). Same files; just look under
> `SCUM-Modding\Mods\MapPing`. Paths below that say `~/Projects/SCUM-Mods/...` are the
> old Linux paths.

### Verified this session
- App imports; all routes mount; `/broadcast` + `/controls` register.
- Auth: missing/bad `X-API-Key` → 401; correct key works.
- Command queue enqueues + drains.
- `map_render`: world `(0,0)` → image center; `(+x, −y)` lands right-of/below center;
  output PNG renders the marker + name correctly.

### Verified 2026-06-18 (live)
- Connected to **real Discord** as the bot; `/health` → `discord_ready:true`.
- Slash commands synced to the guild (instant, because `DISCORD_GUILD_ID` is set).
- `POST /ping` with a real `scum_map.png` → "📍 Map Ping" embed + marked image posted
  to the channel (HTTP 200, no errors). Marker offset is the expected uncalibrated guess.

---

## Part 2 — The MapPing mod (`~/Projects/SCUM-Mods/Mods/MapPing`)

Server-side UE4SS Lua mod. No client files (BattlEye-safe). Built to match the other
mods in that repo (MOD_DIR/log/hot-reload pattern), but WITHOUT the gating/entitlement
framework — anyone can ping their own location.

### Files
- `Scripts/main.lua` — bootstrap + registers the chat hook.
- `Scripts/ping.lua` — reloadable engine: resolve caller, build JSON, fire curl, calibration.
- `Scripts/Config.lua` — sidecar URL, API key, triggers, curl path.
- `UE4SS-settings-SCUM.ini` — SCUM-safe UE4SS config (copied from WashingMachine).
- `README.md`, `LICENSE`, `package.sh`.

### How it hooks chat (discovered in the SCUM-Mods repo)
```
RegisterHook("/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage",
    function(self, message, channel) ... end)
```
This is the **server-side RPC** fired when a player chats — used by 5 other mods in
that repo. Resolve the player:
```lua
local chan = self:get()
local ctrl = chan:GetOuter()                  -- AConZPlayerController
local name = ctrl:GetUserName2():ToString()   -- player name
local loc  = ctrl:GetPrisoner():K2_GetActorLocation()  -- FVector world coords (cm)
```
Full reverse-engineered SDK lives at
`~/Projects/SCUM-Mods/docs/recon/sdk/SCUM-types-1.3.0.lua`.

### Chat commands
| Typed | Who | Does |
|---|---|---|
| `ping` | anyone | POST location to the sidecar |
| `pingcal` | anyone | Log raw `X/Y/Z` to `MapPing.log` + echo in chat (for calibration) |
| `ping reload` | admin | Hot-reload Config.lua + ping.lua |

Matching is exact + case-insensitive (so "pinging the base" won't fire). curl is
launched **detached** (`start "" /B`) so network latency never stalls the server tick.
Every game access is `pcall`-wrapped. JSON body posted is `{"player","x","y"}` (name
properly escaped).

### Verified this session
- All Lua files compile under LuaJIT (what UE4SS runs).
- Drove `ping.lua` with stubbed UE4SS globals + a fake RPC channel: `ping` builds the
  correct curl command; case/whitespace handled; `pingcal` skips HTTP and reports
  coords; `ping reload` admin-gated; unrelated chat ignored.
- JSON body parses and matches the sidecar's `/ping` model; embedded quotes in names
  escaped correctly.
- `package.sh` builds `dist/MapPing-1.0.0.zip` with the right layout.

---

## What's LEFT to do (on Windows)

1. ~~**Create the Discord bot**~~ — **DONE 2026-06-18.** Bot created, invited, connected;
   token/channel/guild in `.env`. Full walkthrough now in `SETUP.md`.

2. ~~**Supply the map image**~~ — **DONE 2026-06-18.** `scum_map.png` is in place and a
   test ping rendered + posted successfully.

3. ~~**Deploy the mod**~~ — **DONE 2026-06-18.** RE-UE4SS was *already installed* on this
   server (dwmapi proxy + working `GarbageGoober`/`WashingMachine` mods), so deploy was
   just: copy `MapPing\` into
   `C:\Program Files (x86)\Steam\steamapps\common\SCUM Server\SCUM\Binaries\Win64\ue4ss\Mods\`
   and add `MapPing : 1` to `mods.txt`. Notes:
   - `MOD_DIR` in `main.lua` already matched that path; `Config.lua` `apiKey`/`sidecarUrl`
     already matched the sidecar — no edits needed.
   - **Did NOT replace `UE4SS-settings.ini`** — the existing one already has
     `HookProcessInternal=1` + `HookProcessLocalScriptFunction=1` (other hook mods rely
     on it). The bundled `-SCUM.ini` is only for a fresh UE4SS install.
   - `System32\curl.exe` is present, so `curlExe="curl"` resolves for the server process.
   - Verified via `MapPing.log`: config loaded, chat triggers installed, no errors.

4. ~~**Calibrate the world→pixel mapping**~~ — **DONE 2026-06-18.** Corner-probing is NOT
   possible (SCUM warns "out of bounds" and kills you after ~10s — no edge clamp), so we
   calibrated from two ordinary in-game `ping`s and the matching pixels on the map image:
   - `world (-634648, 416571) -> px (1054, 164)`
   - `world ( 138139,-213358) -> px ( 401, 692)`
   - Solved into `config.py`: `world_min_x=612703, world_max_x=-906836,
     world_min_y=-910096, world_max_y=612231`. **X axis is inverted** (min > max:
     negative world X is map-right); Y is normal. Both spans ≈1.52M cm (square map, good).
   - `map_render.py` now logs `world -> px / frac / bounds` on every render to make any
     future re-calibration a quick read-the-log loop.

5. ~~**Test end-to-end**~~ — **DONE 2026-06-18.** Live `ping` from 3 different map regions
   all landed accurately in Discord. **Full pipeline working end-to-end.** 🎉

## Quick reference
- Sidecar default: `http://127.0.0.1:8765`, auth header `X-API-Key`.
- Sidecar lives on the SAME box as the SCUM server, hence localhost.
- Smoke-test the sidecar without the game:
  ```
  curl -X POST http://127.0.0.1:8765/ping -H "Content-Type: application/json" \
    -H "X-API-Key: change-me" -d '{"player":"Test","x":200000,"y":-150000}'
  ```
