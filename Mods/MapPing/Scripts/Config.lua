-- Config.lua — MapPing operator config. Edit, then 'ping reload' in chat (admin)
-- or restart the server. Returns one table.

return {
    -- ---- chat triggers --------------------------------------------------
    -- Typed as a normal chat message; matched EXACTLY (case-insensitive) so
    -- "pinging the base" won't fire. 'ping reload' (admin) is built in.
    pingTrigger = "ping",       -- share my current location to Discord
    calTrigger  = "pingcal",    -- log my raw world coords (sidecar calibration)

    -- ---- the sidecar ----------------------------------------------------
    -- The FastAPI + discord.py service. Usually runs on the SAME box as the
    -- dedicated server, hence localhost. Must match the sidecar's POST /ping.
    sidecarUrl  = "http://127.0.0.1:8765",
    apiKey      = "change-me",  -- must match SIDECAR_API_KEY in the sidecar's .env

    -- ---- transport ------------------------------------------------------
    -- curl is used to POST (launched DETACHED so network latency never stalls
    -- the server tick). Windows 10+ ships curl.exe on PATH; if yours isn't
    -- found, set an absolute path, e.g. [[C:\Windows\System32\curl.exe]].
    curlExe        = "curl",
    httpTimeoutSec = 5,

    -- ---- feedback -------------------------------------------------------
    -- Send a short confirmation back to the player in chat after a ping.
    replyInChat = true,

    -- ---- reverse path: Discord buttons -> in-game map markers -----------
    -- When enabled, the mod polls the sidecar's GET /commands and, for each
    -- "map_ping" command (from a Discord color button: green/red/pink/yellow/
    -- cyan/orange/violet/white), broadcasts a colored circle onto EVERY connected
    -- client's map. Colors are defined in MP.palette (pingback.lua).
    pollEnabled    = true,
    pollIntervalSec = 5,    -- how often to poll (keep >= httpTimeoutSec so a slow
                            -- GET can't overlap the next read)
    pingExpireSec   = 30,   -- a broadcast ping auto-clears after this many seconds
    pingRadiusCm    = 30000, -- circle radius in world cm (30000 = 300 m)

    -- ---- pulse animation ------------------------------------------------
    -- Broadcast circles "breathe" (radius oscillates) so they stand out from
    -- the static trader/outpost circles. The mod re-broadcasts on a slow timer
    -- while any ping is active (idle otherwise). Disable to get static circles.
    --
    -- NOTE: each re-broadcast forces every client to re-bake its map render
    -- target, so the interval must stay LARGE (custom zones aren't built for
    -- animation). Keep pulseIntervalMs high enough that the hitch is acceptable.
    pulseEnabled   = true,
    pulseIntervalMs = 1500, -- re-broadcast cadence (THE lag dial): each tick re-
                            -- multicasts the whole zone set, so smaller = smoother
                            -- but heavier. Read live, so 'ping reload' re-tunes it.
    pulsePeriodSec  = 5.0,  -- seconds per full breath (one shrink+grow cycle)
    pulseAmplitude  = 0.3,  -- radius swings to ±this fraction of base (0.3 = 70%..130%)
}
