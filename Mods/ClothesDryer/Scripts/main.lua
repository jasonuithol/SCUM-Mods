-- ClothesDryer — server-side UE4SS mod.
--
-- Turns an ACTIVATED Improvised Wardrobe (Wardrobe_Improvised_Wood_C) into a
-- powered clothes dryer: wet clothing left inside it is dried automatically
-- (item:SetWaterWeight(0), the IWettable lever — proven 2026-06-03). A wardrobe
-- is activated by 'dryer activate', which consumes a recipe (metal scraps +
-- alternator + wire + bolts) placed in it. Server-side only; coexists with BattlEye.
--
-- The access-control / flag-scoping / SCUM.db / chat-command framework lives in
-- the shared library  ..\shared\Scripts\gating.lua  (also used by FlagUpkeep /
-- GarbageGoober). This file loads it and calls Gating.attach(CD, opts); the
-- mod-specific engine (dry cycle, recipe, activation, commands) is in dryer.lua.
--
-- Enable by adding   ClothesDryer : 1   to UE4SS Mods/mods.txt (NEVER enabled.txt).
-- Needs HookProcessInternal=1 & HookProcessLocalScriptFunction=1 in UE4SS-settings
-- .ini for the chat trigger (same as FlagUpkeep).

-- >>> set this to the mod's folder on your server <<<
local MOD_DIR = [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\ClothesDryer]]
local SCRIPTS = MOD_DIR .. [[\Scripts]]
local LOGFILE = MOD_DIR .. [[\ClothesDryer.log]]
local LIB     = MOD_DIR .. [[\..\shared\Scripts\gating.lua]]

ClothesDryer = ClothesDryer or {}
local CD = ClothesDryer

CD.modDir = MOD_DIR
CD.sqliteExe = MOD_DIR .. [[\sqlite3.exe]]
CD.storeFile = MOD_DIR .. [[\entitlements.lua]]
CD.dryersFile = MOD_DIR .. [[\dryers.lua]]

local function ts() return os.date("%Y-%m-%d %H:%M:%S") end
function CD.log(m)
    local line = "[ClothesDryer] " .. ts() .. " " .. tostring(m)
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

function CD.reload()
    local ok, res = runFile(SCRIPTS .. [[\Config.lua]])
    if ok and type(res) == "table" then
        CD.config = res
        CD.log("config loaded (dryerClass='" .. tostring(res.dryerClass) .. "', interval=" .. tostring(res.dryIntervalMs) .. "ms)")
    else
        CD.log("CONFIG load FAILED: " .. tostring(res) .. " — keeping previous config")
        if not CD.config then return false end
    end

    CD.trigger = (CD.config and CD.config.chatTrigger) or "dryer"
    CD.tag = "ClothesDryer"
    local okL, G = runFile(LIB)
    if not okL or type(G) ~= "table" or type(G.attach) ~= "function" then
        CD.log("gating lib load FAILED (" .. tostring(G) .. ") — expected " .. LIB); return false
    end
    G.attach(CD, {
        defaultNotEnabled = "drying isn't enabled for your base — ask an admin to enable it",
    })

    local ok2, e2 = runFile(SCRIPTS .. [[\dryer.lua]])
    if not ok2 then CD.log("dryer.lua load FAILED: " .. tostring(e2)); return false end
    return true
end

function CD.armTimer()
    if CD.timerArmed then return end
    CD.timerArmed = true
    local interval = (CD.config and CD.config.dryIntervalMs) or 4000
    LoopAsync(interval, function()
        if CD.enabled ~= false and type(CD.dryCycle) == "function" then pcall(CD.dryCycle) end
        return false -- keep looping
    end)
    CD.log("dry-cycle timer armed @ " .. interval .. "ms (set ClothesDryer.enabled=false to pause).")
end

-- ---- bootstrap -----------------------------------------------------------
do local f = io.open(LOGFILE, "w"); if f then f:write("===== ClothesDryer started :: " .. ts() .. " =====\n"); f:close() end end

if not CD.reload() then
    CD.log("startup ABORTED: could not load config/lib/engine.")
    return
end

if type(CD.loadStore) == "function" then pcall(CD.loadStore) end        -- entitlements (shared lib)
if type(CD.loadDryers) == "function" then pcall(CD.loadDryers) end       -- active dryers (mod-owned)
if type(CD.ensureResolved) == "function" then pcall(CD.ensureResolved, true) end

CD.armTimer()

-- chat trigger: NORMAL chat (no "#"). Delegates to the lib's CD.onChatMessage.
local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage"
local okHook, errHook = pcall(function()
    RegisterHook(TARGET, function(self, message, channel)
        if type(CD.onChatMessage) == "function" then pcall(CD.onChatMessage, self, message, channel) end
    end)
end)
CD.log(okHook and "ready: 'dryer' chat trigger installed (normal chat)." or ("chat trigger FAILED: " .. tostring(errHook)))

CD.log("=====================================================")
CD.log("ClothesDryer loaded. Type 'dryer' in chat for commands.")
CD.log("=====================================================")
