# MapPingService — SCUM Discord sidecar

The companion web service for the **MapPing** UE4SS mod (`../../Mods/MapPing/`). A small
process that owns the Discord connection so the mod doesn't have to.

> **New here? Read [`SETUP.md`](SETUP.md)** for the full step-by-step (Python env, Discord
> bot creation + invite, IDs, calibration, smoke test). This README is the quick reference.
>
> The mod and this service share a secret: `Config.lua`'s `apiKey` must equal this
> service's `SIDECAR_API_KEY`.

```
UE4SS Lua mod  ──HTTP──►  this sidecar  ──Gateway (WebSocket)──►  Discord
 (emits events)          (FastAPI + discord.py)
```

- **Mod → Discord:** the mod `POST`s in-game events to `/event` and map pings to `/ping`; the bot relays them to a channel.
- **Discord → Mod:** Discord slash commands and buttons enqueue commands; the mod polls `/commands` and acts on them in-game. In particular, each map ping is posted with **Ping Green / Ping Red** buttons that broadcast a colored circle back onto every player's in-game map.

The Discord Gateway (a long-lived WebSocket with heartbeat/reconnect) runs as a background task on the same asyncio loop as the FastAPI server, so a single `python main.py` runs both.

## Setup

1. Create a bot at <https://discord.com/developers/applications>, copy its **token**, and invite it to your server with the `applications.commands` and `bot` scopes.
2. Enable Developer Mode in Discord, right-click your target channel → **Copy Channel ID**.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env      # then edit .env with your token, channel ID, guild ID
python main.py
```

## Endpoints

| Method | Path | Who calls it | Purpose |
|---|---|---|---|
| GET | `/health` | you | Liveness + whether Discord is connected |
| POST | `/event` | the mod | Relay an in-game event to Discord |
| POST | `/ping` | the mod | Draw a player's position on the map and post it |
| GET | `/commands` | the mod | Drain commands issued from Discord |

All except `/health` require the `X-API-Key` header matching `SIDECAR_API_KEY`.

## Map pings

When a player types `ping` in-game, the mod sends their name and world coords to
`POST /ping`; the sidecar marks the spot on the map image and posts it to the channel
**with two buttons, Ping Green and Ping Red** (see below).

Two things you must provide:

1. **The map image** — drop a SCUM map PNG at the path in `MAP_IMAGE_PATH` (default `scum_map.png`).
2. **Calibration** — set `WORLD_MIN_X/MAX_X/MIN_Y/MAX_Y` in `.env` so world coords land on the
   right pixels. Find two known points (their world coords + where they sit on the image) and
   solve for the bounds. If the result is mirrored, swap that axis's min/max.

Test it without the game:

```bash
curl -X POST http://127.0.0.1:8765/ping \
  -H "Content-Type: application/json" -H "X-API-Key: change-me" \
  -d '{"player":"Bob_Survivor","x":200000,"y":-150000}'
```

### Ping back to the game (the Green/Red buttons)

Every `/ping` post includes two buttons, **Ping Green** and **Ping Red** (handled by
`PingButtons` in `bot.py`). Clicking one enqueues a `map_ping` command:

```json
{"action": "map_ping", "x": <world x>, "y": <world y>, "color": "green|red", "player": "...", "by": "<discord user>"}
```

The MapPing mod polls `GET /commands`, picks it up, and draws a colored circle at
that spot on every connected player's in-game map (auto-expiring). Anyone who can see
the message can click; the click position is the original pinger's location.

The buttons are a **per-message** (non-persistent) view, so they carry the ping's
x/y in memory and stop working after a sidecar restart — fine for ephemeral pings.

### Quick test (no game needed)

```bash
curl -X POST http://127.0.0.1:8765/event \
  -H "Content-Type: application/json" -H "X-API-Key: change-me" \
  -d '{"type":"status","message":"Server is online"}'
```

Then in Discord try `/broadcast hello` or `/controls`, and read the queued command back:

```bash
curl http://127.0.0.1:8765/commands -H "X-API-Key: change-me"
```

## The mod side

The actual UE4SS mod that drives this service lives in **`../../Mods/MapPing/`** — see its
README for install + the chat hook details. In short: it reads the caller's name + world
coords on the `ping` chat trigger and `POST`s them to `/ping` here (curl, launched detached).
