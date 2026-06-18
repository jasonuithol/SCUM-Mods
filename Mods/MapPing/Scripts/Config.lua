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
}
