-- MapPing — server-side UE4SS mod for SCUM.
--
-- When a player types "ping" in chat, this mod reads their in-game position and
-- name and POSTs them to a local "sidecar" web service (FastAPI + discord.py),
-- which draws the position on the SCUM map and posts it to a Discord channel.
-- "pingcal" logs the raw world coordinates so you can calibrate the sidecar's
-- world->pixel mapping. "ping reload" (admin) hot-reloads Config.lua + ping.lua.
--
-- Server-side only; no client files, so it coexists with BattlEye.
--
-- Chat hook proven in this repo (FlagUpkeep / WashingMachine / GarbageGoober):
--   /Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage(message, channel)
--
-- Enable by adding   MapPing : 1   to UE4SS Mods/mods.txt (NEVER enabled.txt).
-- Needs HookProcessInternal=1 & HookProcessLocalScriptFunction=1 in
-- UE4SS-settings.ini (use the bundled UE4SS-settings-SCUM.ini).

-- >>> set this to the mod's folder on your server <<<
local MOD_DIR = [[C:\Program Files (x86)\Steam\steamapps\common\SCUM Server\SCUM\Binaries\Win64\ue4ss\Mods\MapPing]]
local SCRIPTS = MOD_DIR .. [[\Scripts]]
local LOGFILE = MOD_DIR .. [[\MapPing.log]]

MapPing = MapPing or {}
local MP = MapPing
MP.modDir = MOD_DIR

local function ts() return os.date("%Y-%m-%d %H:%M:%S") end
function MP.log(m)
    local line = "[MapPing] " .. ts() .. " " .. tostring(m)
    print(line .. "\n")
    local f = io.open(LOGFILE, "a"); if f then f:write(line .. "\n"); f:close() end
end

local function runFile(path)
    local f = io.open(path, "r")
    if not f then return false, "cannot open " .. path end
    local src = f:read("*a"); f:close()
    local chunk, cerr = load(src, "@" .. path)
    if not chunk then return false, "compile: " .. tostring(cerr) end
    return pcall(chunk)
end

-- Load Config.lua then the reloadable engine ping.lua. Re-runnable live via the
-- 'ping reload' chat command (admin-gated in ping.lua).
function MP.reload()
    local ok, res = runFile(SCRIPTS .. [[\Config.lua]])
    if ok and type(res) == "table" then
        MP.config = res
        MP.log("config loaded (sidecar='" .. tostring(res.sidecarUrl) .. "')")
    else
        MP.log("CONFIG load FAILED: " .. tostring(res) .. " — keeping previous config")
        if not MP.config then return false end
    end
    local ok2, e2 = runFile(SCRIPTS .. [[\ping.lua]])
    if not ok2 then MP.log("ping.lua load FAILED: " .. tostring(e2)); return false end
    local ok3, e3 = runFile(SCRIPTS .. [[\pingback.lua]])
    if not ok3 then MP.log("pingback.lua load FAILED: " .. tostring(e3)); return false end
    -- Ensure the reverse-path loops are running. Both are guarded against
    -- duplicates, so calling them here makes 'ping reload' enough to activate
    -- them (the bootstrap only runs once, on server start).
    if type(MP.startPolling) == "function" then pcall(MP.startPolling) end
    if type(MP.startPulsing) == "function" then pcall(MP.startPulsing) end
    return true
end

-- ---- bootstrap -----------------------------------------------------------
do local f = io.open(LOGFILE, "w"); if f then f:write("===== MapPing started :: " .. ts() .. " =====\n"); f:close() end end

if not MP.reload() then
    MP.log("startup ABORTED: could not load config/engine.")
    return
end

-- chat trigger: NORMAL chat. Delegates to MP.onChatMessage in ping.lua (resolved
-- by name on every call, so 'ping reload' swaps the handler live).
local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage"
local okHook, errHook = pcall(function()
    RegisterHook(TARGET, function(self, message, channel)
        if type(MP.onChatMessage) == "function" then pcall(MP.onChatMessage, self, message, channel) end
    end)
end)
MP.log(okHook and "ready: 'ping' / 'pingcal' chat triggers installed."
    or ("chat trigger FAILED: " .. tostring(errHook)))

-- reverse path: the poll + pulse loops are started inside MP.reload() (above),
-- so they come up here on first load and also (re)start on 'ping reload'.

MP.log("=====================================================")
MP.log("MapPing loaded. Players type 'ping' in chat to share their location.")
MP.log("Discord color buttons broadcast back to all clients' maps (pulsing circles).")
MP.log("=====================================================")
