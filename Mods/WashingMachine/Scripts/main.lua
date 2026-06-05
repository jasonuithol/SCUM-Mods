-- WashingMachine — server-side UE4SS mod. Sibling of ClothesDryer.
--
-- Turns an ACTIVATED Improvised Wardrobe (Wardrobe_Improvised_Wood_C) into a
-- washing machine: dirty clothing placed inside, together with a full bar of
-- soap, is washed clean and left damp when the player runs 'washer wash' while
-- HOLDING a full water bucket. Washing is INSTANT and command-triggered (not a
-- timed loop like the dryer) — it consumes the soap and empties the held bucket.
--
-- Levers (all proven via recon, 2026-06-05):
--   clean  = AClothesItem:SetDirtiness(0)
--   damp   = SetWaterWeight(0.05 * GetMaxPossibleWaterWeight())
--   soap   = Soap_C (full bar = DiscreteUsageItemComponent._repQuantity ~100) -> DestroyInternal()
--   bucket = held Water_Bucket_C: UBasicGameResourceContainerComponent._repResourceAmount=0 + OnRep_ResourceAmount()
--
-- A wardrobe is activated by 'washer activate', which consumes a recipe (the
-- dryer recipe + 2 hoses) placed in it. Server-side only; coexists with BattlEye.
--
-- The access-control / flag-scoping / SCUM.db / chat-command framework lives in
-- the shared library  ..\shared\Scripts\gating.lua  (also used by ClothesDryer /
-- FlagUpkeep / GarbageGoober). This file loads it and calls Gating.attach(WM, opts);
-- the mod-specific engine (wash action, recipe, activation, commands) is in washer.lua.
--
-- Enable by adding   WashingMachine : 1   to UE4SS Mods/mods.txt (NEVER enabled.txt).
-- Needs HookProcessInternal=1 & HookProcessLocalScriptFunction=1 in UE4SS-settings.ini.

-- >>> set this to the mod's folder on your server <<<
local MOD_DIR = [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\WashingMachine]]
local SCRIPTS = MOD_DIR .. [[\Scripts]]
local LOGFILE = MOD_DIR .. [[\WashingMachine.log]]
local LIB     = MOD_DIR .. [[\..\shared\Scripts\gating.lua]]

WashingMachine = WashingMachine or {}
local WM = WashingMachine

WM.modDir = MOD_DIR
WM.sqliteExe = MOD_DIR .. [[\sqlite3.exe]]
WM.storeFile = MOD_DIR .. [[\entitlements.lua]]
WM.washersFile = MOD_DIR .. [[\washers.lua]]

local function ts() return os.date("%Y-%m-%d %H:%M:%S") end
function WM.log(m)
    local line = "[WashingMachine] " .. ts() .. " " .. tostring(m)
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

function WM.reload()
    local ok, res = runFile(SCRIPTS .. [[\Config.lua]])
    if ok and type(res) == "table" then
        WM.config = res
        WM.log("config loaded (washerClass='" .. tostring(res.washerClass) .. "')")
    else
        WM.log("CONFIG load FAILED: " .. tostring(res) .. " — keeping previous config")
        if not WM.config then return false end
    end

    WM.trigger = (WM.config and WM.config.chatTrigger) or "washer"
    WM.tag = "WashingMachine"
    local okL, G = runFile(LIB)
    if not okL or type(G) ~= "table" or type(G.attach) ~= "function" then
        WM.log("gating lib load FAILED (" .. tostring(G) .. ") — expected " .. LIB); return false
    end
    G.attach(WM, {
        defaultNotEnabled = "washing isn't enabled for your base — ask an admin to enable it",
    })

    local ok2, e2 = runFile(SCRIPTS .. [[\washer.lua]])
    if not ok2 then WM.log("washer.lua load FAILED: " .. tostring(e2)); return false end
    return true
end

-- ---- bootstrap -----------------------------------------------------------
do local f = io.open(LOGFILE, "w"); if f then f:write("===== WashingMachine started :: " .. ts() .. " =====\n"); f:close() end end

if not WM.reload() then
    WM.log("startup ABORTED: could not load config/lib/engine.")
    return
end

if type(WM.loadStore) == "function" then pcall(WM.loadStore) end          -- entitlements (shared lib)
if type(WM.loadWashers) == "function" then pcall(WM.loadWashers) end       -- active washers (mod-owned)
if type(WM.ensureResolved) == "function" then pcall(WM.ensureResolved, true) end

-- chat trigger: NORMAL chat (no "#"). Delegates to the lib's WM.onChatMessage.
local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage"
local okHook, errHook = pcall(function()
    RegisterHook(TARGET, function(self, message, channel)
        if type(WM.onChatMessage) == "function" then pcall(WM.onChatMessage, self, message, channel) end
    end)
end)
WM.log(okHook and "ready: 'washer' chat trigger installed (normal chat)." or ("chat trigger FAILED: " .. tostring(errHook)))

WM.log("=====================================================")
WM.log("WashingMachine loaded. Type 'washer' in chat for commands.")
WM.log("=====================================================")
