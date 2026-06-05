-- FlagUpkeep — server-side UE4SS mod.
--
-- Periodically keeps a flag's base elements repaired to full health, spending
-- REPAIR POINTS banked (via 'upkeep deposit', chest OPEN) from toolboxes in a
-- designated "FlagUpkeep" container. Access is gated per-player / per-flag /
-- default. Server-side only — coexists with client BattlEye.
--
-- The access-control / flag-scoping / SCUM.db / chat-command framework lives in
-- the shared library  ..\shared\Scripts\gating.lua  (also used by GarbageGoober's
-- lineage). This file loads it and calls Gating.attach(FU, opts); the mod-specific
-- engine (the repair action, deposit, trigger, help, dispatch) is in upkeep.lua.
--
-- Enable by adding   FlagUpkeep : 1   to UE4SS Mods/mods.txt  (NEVER enabled.txt —
-- it silently overrides mods.txt). Requires HookProcessInternal=1 &
-- HookProcessLocalScriptFunction=1 in UE4SS-settings.ini for the chat trigger.

-- >>> set this to the mod's folder on your server <<<
local MOD_DIR = [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\FlagUpkeep]]
local SCRIPTS = MOD_DIR .. [[\Scripts]]
local LOGFILE = MOD_DIR .. [[\FlagUpkeep.log]]
-- shared gating library (sibling 'shared' folder; NOT a mod, so UE4SS ignores it)
local LIB = MOD_DIR .. [[\..\shared\Scripts\gating.lua]]

FlagUpkeep = FlagUpkeep or {}
local FU = FlagUpkeep

FU.modDir = MOD_DIR
FU.storeFile = MOD_DIR .. [[\entitlements.lua]]

local function ts() return os.date("%Y-%m-%d %H:%M:%S") end
function FU.log(m)
    local line = "[FlagUpkeep] " .. ts() .. " " .. tostring(m)
    print(line .. "\n")
    local f = io.open(LOGFILE, "a"); if f then f:write(line .. "\n"); f:close() end
end

-- run a Lua file; returns (ok, result-or-error)
local function runFile(path)
    local f = io.open(path, "r")
    if not f then return false, "cannot open " .. path end
    local src = f:read("*a"); f:close()
    local chunk, cerr = load(src, "@" .. path)
    if not chunk then return false, "compile: " .. tostring(cerr) end
    return pcall(chunk)
end

-- (re)load config + shared gating lib + upkeep engine. Safe to call any time.
function FU.reload()
    local ok, res = runFile(SCRIPTS .. [[\Config.lua]])
    if ok and type(res) == "table" then
        FU.config = res
        FU.log("config loaded (interval=" .. tostring(res.upkeepIntervalMs) ..
            "ms; container='" .. tostring(res.containerName) .. "')")
    else
        FU.log("CONFIG load FAILED: " .. tostring(res) .. " — keeping previous config")
        if not FU.config then return false end
    end

    -- shared gating layer: install the access/flag/DB/chat building blocks onto FU
    FU.trigger = (FU.config and FU.config.chatTrigger) or "upkeep"
    FU.tag = "FlagUpkeep"
    local okL, G = runFile(LIB)
    if not okL or type(G) ~= "table" or type(G.attach) ~= "function" then
        FU.log("gating lib load FAILED (" .. tostring(G) .. ") — expected " .. LIB)
        return false
    end
    G.attach(FU, {
        storeExtra = { triggerOverrides = "floatmap", repairPoints = "intmap" },
        defaultNotEnabled = "upkeep isn't enabled for your base — ask an admin to enable it",
        statusExtra = function(M)
            if not M.config.repairEnabled then
                M.reply("NOTE: repair is DISABLED in config (report-only mode)", true)
            elseif not M.config.requireRepairPoints then
                M.reply("NOTE: requireRepairPoints=false — repairing for free (no points consumed)", true)
            end
        end,
    })

    local ok2, e2 = runFile(SCRIPTS .. [[\upkeep.lua]])
    if not ok2 then FU.log("upkeep.lua load FAILED: " .. tostring(e2)); return false end
    return true
end

-- install the periodic upkeep cycle exactly once (interval fixed at load time)
function FU.armTimer()
    if FU.timerArmed then return end
    FU.timerArmed = true
    local interval = (FU.config and FU.config.upkeepIntervalMs) or 3600000
    LoopAsync(interval, function()
        if FU.enabled ~= false and type(FU.upkeep) == "function" then pcall(FU.upkeep) end
        return false -- keep looping
    end)
    FU.log("upkeep timer armed @ " .. interval .. "ms (set FlagUpkeep.enabled=false to pause).")
end

-- ---- bootstrap -----------------------------------------------------------
do local f = io.open(LOGFILE, "w"); if f then f:write("===== FlagUpkeep started :: " .. ts() .. " =====\n"); f:close() end end

if not FU.reload() then
    FU.log("startup ABORTED: could not load config/lib/engine.")
    return
end

if type(FU.loadStore) == "function" then pcall(FU.loadStore) end
if type(FU.ensureResolved) == "function" then pcall(FU.ensureResolved, true) end

FU.armTimer()

-- chat trigger: NORMAL chat (no "#"). Thin delegator to the lib's FU.onChatMessage
-- (installed by attach), which resolves the caller then calls FU.handleCommand.
local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage"
local okHook, errHook = pcall(function()
    RegisterHook(TARGET, function(self, message, channel)
        if type(FU.onChatMessage) == "function" then pcall(FU.onChatMessage, self, message, channel) end
    end)
end)
FU.log(okHook and "ready: 'upkeep' chat trigger installed (normal chat, admin-gated)." or ("chat trigger FAILED: " .. tostring(errHook)))

FU.log("=====================================================")
FU.log("FlagUpkeep is loaded. Type 'upkeep' in chat to see the available commands.")
FU.log("=====================================================")
