-- MapPing engine (reloadable). Installs MP.onChatMessage, which the chat hook in
-- main.lua delegates to. Reads the caller's world position + name and POSTs them
-- to the sidecar. 'pingcal' logs raw coords for calibrating the sidecar bounds.

local MP = MapPing
local C  = MP.config

-- safe-call: game accessors can throw or return nil, especially mid-spawn. Every
-- UObject touch goes through this so a malformed message never crashes the server.
local function pcs(fn, fallback)
    local ok, v = pcall(fn)
    if ok then return v end
    return fallback
end

local function xyz(v)
    if not v then return nil end
    local x = pcs(function() return v.X end, nil)
    if not x then return nil end
    return x, pcs(function() return v.Y end, nil) or 0, pcs(function() return v.Z end, nil) or 0
end

-- Minimal JSON string escape (player names can contain quotes/backslashes).
local function jstr(s)
    s = tostring(s or "")
    s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    return '"' .. s .. '"'
end

-- Resolve the calling player from the RPC channel: the channel's Outer is the
-- AConZPlayerController (see gating.lua:739), which gives the name + character.
local function resolveCaller(self)
    local chan = pcs(function() return self:get() end, nil)
    local ctrl = chan and pcs(function() return chan:GetOuter() end, nil) or nil
    if not ctrl then return nil end
    local name = pcs(function() return ctrl:GetUserName2():ToString() end, nil)
        or pcs(function() return ctrl:GetUserProfileName():ToString() end, "Unknown")
    local pris = pcs(function() return ctrl:GetPrisoner() end, nil)
    local x, y, z = xyz(pcs(function() return pris:K2_GetActorLocation() end, nil))
    return {
        chan = chan,
        ps = pcs(function() return ctrl.PlayerState end, nil),
        name = name, x = x, y = y, z = z,
        admin = (pcs(function() return ctrl:IsUserAdmin() end, false) == true),
    }
end

-- Reply to the caller in chat. QUEUED via ExecuteWithDelay so it renders AFTER
-- the player's own echoed message (the hook fires while SCUM is still
-- broadcasting it). Channel type 6 = server message. See gating.lua:692.
local CHAT_SERVERMESSAGE = 6
local function reply(caller, text)
    if not (C.replyInChat and caller and caller.chan) then return end
    local send = function()
        pcall(function()
            caller.chan:Chat_Client_SendMessageToChat(
                "[MapPing] " .. tostring(text), caller.ps, {}, CHAT_SERVERMESSAGE, false)
        end)
    end
    if type(ExecuteWithDelay) == "function" then ExecuteWithDelay(120, send) else send() end
end

-- POST JSON to the sidecar WITHOUT blocking the game thread. The body is written
-- to a temp file (dodges Windows cmd quoting of JSON) and curl is launched
-- DETACHED via `start "" /B`, so os.execute returns immediately.
local function postJson(path, body)
    local curl = C.curlExe or "curl"
    local url  = (C.sidecarUrl or "http://127.0.0.1:8765") .. path
    local key  = C.apiKey or "change-me"
    local timeout = tostring(C.httpTimeoutSec or 5)
    local tmp = (MP.modDir or ".") .. [[\.ping_post.json]]
    local f = io.open(tmp, "w")
    if not f then MP.log("postJson: cannot write temp " .. tmp); return false end
    f:write(body); f:close()
    local cmd = string.format(
        'start "" /B %s -s -m %s -X POST "%s" -H "Content-Type: application/json" '
        .. '-H "X-API-Key: %s" --data-binary @"%s" >nul 2>&1',
        curl, timeout, url, key, tmp)
    os.execute(cmd)
    return true
end

local function doPing(caller)
    if not caller.x then
        MP.log("ping by " .. tostring(caller.name) .. ": could not read location")
        reply(caller, "couldn't read your position — try again once you've fully spawned in")
        return
    end
    local body = string.format('{"player":%s,"x":%s,"y":%s}',
        jstr(caller.name), tostring(caller.x), tostring(caller.y))
    MP.log(string.format("ping by %s @ (%.1f, %.1f, %.1f)",
        tostring(caller.name), caller.x, caller.y, caller.z or 0))
    postJson("/ping", body)
    reply(caller, "📍 location shared to Discord")
end

-- Calibration helper: just log + echo the raw world coords. Stand at two known
-- spots on your map image, run 'pingcal', and use the logged X/Y to solve the
-- sidecar's WORLD_MIN/MAX_X/Y bounds.
local function doCal(caller)
    if not caller.x then reply(caller, "couldn't read your position"); return end
    MP.log(string.format("CALIBRATION  %s  X=%.2f  Y=%.2f  Z=%.2f",
        tostring(caller.name), caller.x, caller.y, caller.z or 0))
    reply(caller, string.format("cal: X=%.1f  Y=%.1f  Z=%.1f  (written to MapPing.log)",
        caller.x, caller.y, caller.z or 0))
end

-- Entry point, called from main.lua's chat hook for EVERY chat line, so it must
-- bail cheaply on non-matching messages before touching any UObjects.
function MP.onChatMessage(self, message, channel)
    local msg = ""
    pcall(function() msg = message:get():ToString() end)
    if type(msg) ~= "string" or msg == "" then return end
    local low = msg:gsub("^%s+", ""):gsub("%s+$", ""):lower()  -- trim + lowercase

    local pingT = (C.pingTrigger or "ping"):lower()
    local calT  = (C.calTrigger or "pingcal"):lower()
    local isPing, isCal, isReload = (low == pingT), (low == calT), (low == pingT .. " reload")
    if not (isPing or isCal or isReload) then return end

    local caller = resolveCaller(self)
    if not caller then MP.log("chat trigger: could not resolve caller"); return end

    if isReload then
        if not caller.admin then reply(caller, "reload is admin-only"); return end
        reply(caller, MP.reload() and "reloaded config + engine" or "reload FAILED (see log)")
    elseif isCal then
        doCal(caller)
    else
        doPing(caller)
    end
end
