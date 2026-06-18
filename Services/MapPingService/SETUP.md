# Sidecar setup (Windows)

End-to-end setup for the SCUM Discord sidecar: Python environment, the Discord bot,
and a smoke test. The companion piece — the in-game UE4SS mod — is covered in
`HANDOFF.md` (Part 2) and the mod repo's own README.

---

## 1. Python environment

Use **Python 3.12** (the tested version). The machine may default to a newer Python
(e.g. 3.14) that doesn't yet have wheels for every dependency, so pin 3.12 explicitly.

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
```

> Do **not** reuse a `.venv` copied from Linux — recreate it fresh on Windows.
> A copied `__pycache__\` is harmless and can be deleted.

You fill in `.env` in step 2 below.

---

## 2. Create and configure the Discord bot

### 2a. Create the application + bot
1. Go to <https://discord.com/developers/applications> → **New Application**, name it,
   accept terms → **Create**.
2. Left sidebar → **Bot**. Click **Reset Token** → **Copy**. This is your
   `DISCORD_BOT_TOKEN`. You only see it once; if lost, just Reset Token again.
   - Treat the token like a password. If it ever leaks, reset it immediately —
     a reset instantly invalidates the old one.
3. Still on **Bot**: confirm **"Requires OAuth2 Code Grant"** is **OFF** (it breaks
   plain invite links). Setting **Public Bot** ON is convenient but optional.
4. **Message Content Intent**: under *Privileged Gateway Intents*, you can leave this
   **OFF**. The sidecar uses `discord.Intents.default()` and drives everything through
   slash commands + buttons, which do not need it. (The startup log prints a harmless
   "Privileged message content intent is missing" warning either way — ignore it.)

### 2b. Invite the bot to your server
The bot does **nothing** until it's a member of your server. Until then, startup fails
with a `403 Forbidden (Missing Access)` on slash-command sync.

Open this URL **in a browser where you're logged into Discord**, on an account with
**Manage Server** permission on the target server:

```
https://discord.com/api/oauth2/authorize?client_id=<APPLICATION_ID>&permissions=52224&scope=bot+applications.commands
```

- `<APPLICATION_ID>` = your app's **Application ID** (Developer Portal → *General
  Information*; it's also the bot user's ID).
- `permissions=52224` = View Channels + Send Messages + Embed Links + Attach Files
  (everything the sidecar needs to post the map embed).
- Both scopes matter: `bot` adds the bot, `applications.commands` enables the
  `/broadcast` and `/controls` slash commands.

On the page: pick your server in the **Add to Server** dropdown → **Continue** →
**Authorize** → solve the captcha. The bot then appears in your member list (offline
until the sidecar runs).

> **Convenience:** if the sidecar starts before the bot is invited, it now logs a
> ready-to-click invite link built from the bot's own application ID — just copy it
> from the error in the console. (See "Error handling" below.)

If the invite link misbehaves:
- **No server dropdown / login screen** → you're not logged in, or on the wrong
  account. Log into the correct account in that browser and reopen the link.
- **Can't select your server** → you lack *Manage Server* there; use the owner account.
- **Immediate error page** → check *Requires OAuth2 Code Grant* is OFF (step 2a.3).

### 2c. Get the channel and server IDs
Enable **Developer Mode**: Discord → **User Settings → Advanced → Developer Mode (ON)**.
Then:
- **Channel ID** (`DISCORD_CHANNEL_ID`): right-click the target text channel →
  **Copy Channel ID**.
- **Server/Guild ID** (`DISCORD_GUILD_ID`): right-click the server icon →
  **Copy Server ID**. This gives *instant* slash-command sync; leave it unset for a
  global sync that can take up to an hour to appear.

### 2d. Fill in `.env`
```
DISCORD_BOT_TOKEN=<the token from 2a>
DISCORD_CHANNEL_ID=<from 2c>
DISCORD_GUILD_ID=<from 2c>
SIDECAR_API_KEY=change-me      # change this; the mod must send the same value
HOST=127.0.0.1
PORT=8765
```

---

## 3. The map image

Drop a SCUM map PNG at the path in `MAP_IMAGE_PATH` (default `scum_map.png` in this
folder). It's gitignored (may be copyrighted) and is never committed. Without it,
`POST /ping` errors when it tries to render.

---

## 4. Run and smoke-test

```powershell
.\.venv\Scripts\python.exe main.py
```

Healthy startup logs `Discord bot connected as <name>` and:

```powershell
(Invoke-WebRequest http://127.0.0.1:8765/health -UseBasicParsing).Content
# -> {"ok":true,"discord_ready":true}
```

Fire a test ping (posts a marked map image to your channel):

```powershell
Invoke-WebRequest -Uri http://127.0.0.1:8765/ping -Method POST `
  -ContentType "application/json" -Headers @{"X-API-Key"="change-me"} `
  -Body '{"player":"Test","x":200000,"y":-150000}' -UseBasicParsing
# -> {"sent":true}, and a "📍 Map Ping" embed appears in Discord
```

The marker position will be **uncalibrated** (placeholder world bounds in `config.py`)
until you do the in-game calibration in `HANDOFF.md` step 4.

### Reverse path (Ping Green / Ping Red buttons)

Each map ping is posted **with two buttons**, *Ping Green* and *Ping Red*. Clicking
one queues a `map_ping` command (`GET /commands`) that the MapPing mod polls and
broadcasts as a colored circle onto every player's in-game map.

This half only completes the loop when the **mod is running and polling** — the
sidecar just queues the command. To confirm the sidecar side alone, click a button,
then read the queue back:

```powershell
Invoke-WebRequest http://127.0.0.1:8765/commands -Headers @{"X-API-Key"="change-me"} -UseBasicParsing
# -> {"commands":[{"action":"map_ping","x":...,"y":...,"color":"red",...}]}
```

(That `GET` drains the queue, so the mod won't also see it — only check this way when
the mod isn't polling.) The in-game half is configured in the mod's `Config.lua`
(`pollEnabled`, `pollIntervalSec`, `pingExpireSec`, `pingRadiusCm`).

---

## Error handling (what failure looks like)

The bot runs as a background task on the web server's event loop. Startup failures are
logged with a clear cause instead of silently leaving `discord_ready` false:

- **Bot not in the configured guild** → `403 Forbidden` is caught and re-raised as a
  `RuntimeError` that names the guild and prints a ready-made invite link.
- **Bad token / other startup errors** → surfaced by a task done-callback in `main.py`
  that logs the exception and traceback.

So if `discord_ready` stays `false`, read the console — the reason and fix are there.

---

## Troubleshooting quick reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `discord_ready:false`, `403 Missing Access` in log | Bot not invited / wrong `DISCORD_GUILD_ID` | Invite via 2b, or fix the ID in `.env` |
| `LoginFailure` in log | Bad/reset `DISCORD_BOT_TOKEN` | Re-copy token (2a), update `.env` |
| `401` from `/ping` or `/event` | `X-API-Key` header missing/wrong | Send header matching `SIDECAR_API_KEY` |
| `503 Discord not connected yet` | Bot task died or still starting | Check log for the startup error |
| Slash commands don't appear | Global sync pending, or `DISCORD_GUILD_ID` unset | Set guild ID for instant sync; restart |
