-- FlagUpkeep — server-side UE4SS mod.
--
-- Periodically keeps a flag's base elements repaired to full health by consuming
-- toolkits stored in a designated "FlagUpkeep" container (chest/wardrobe) inside
-- that flag. Access is gated EXACTLY like GarbageGoober (per-player primary,
-- per-flag fallback, global default), driven by the same SCUM.db owner lookup.
-- Server-side only — coexists with client BattlEye.
--
-- Shared lineage: the access-control / flag-scoping / chat-command / timer layer
-- is copy-adapted from GarbageGoober (proven in production). Once both mods are
-- stable, the identical parts are the candidate for a shared lib/ (see README).
--
-- THE REPAIR PRIMITIVE ITSELF is pending recon — SCUM exposes no per-element
-- BaseElementId via reflection and the interaction-RPC route no-op'd for upgrade
-- (see memory reference-scum-base-building-architecture). We're capturing the
-- real repair call path first (LootSorterRecon PASS 33). Until that's wired,
-- FlagUpkeep.config.repairEnabled stays false and the engine only REPORTS what
-- it would repair (non-destructive) — it never touches elements or toolkits.
--
-- Enable by adding   FlagUpkeep : 1   to UE4SS Mods/mods.txt  (NEVER enabled.txt —
-- it silently overrides mods.txt). Requires HookProcessInternal=1 &
-- HookProcessLocalScriptFunction=1 in UE4SS-settings.ini for the chat trigger.

-- >>> set this to the mod's folder on your server <<<
local MOD_DIR = [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\FlagUpkeep]]
local SCRIPTS = MOD_DIR .. [[\Scripts]]
local LOGFILE = MOD_DIR .. [[\FlagUpkeep.log]]

FlagUpkeep = FlagUpkeep or {}
local FU = FlagUpkeep

-- Paths for the entitlement layer. The mod reads SCUM.db via the bundled
-- sqlite3.exe (fetched by install-libraries.ps1) and keeps its own store in
-- entitlements.lua. See Scripts/upkeep.lua + Scripts/Config.lua.
FU.modDir = MOD_DIR
FU.sqliteExe = MOD_DIR .. [[\sqlite3.exe]]
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

-- (re)load config + upkeep engine. Safe to call any time (e.g. after editing Config.lua).
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
        if FU.enabled ~= false and type(FU.upkeep) == "function" then
            pcall(FU.upkeep)
        end
        return false -- keep looping
    end)
    FU.log("upkeep timer armed @ " .. interval .. "ms (set FlagUpkeep.enabled=false to pause).")
end

-- ---- bootstrap -----------------------------------------------------------
do local f = io.open(LOGFILE, "w"); if f then f:write("===== FlagUpkeep started :: " .. ts() .. " =====\n"); f:close() end end

if not FU.reload() then
    FU.log("startup ABORTED: could not load config/engine.")
    return
end

-- Prime the entitlement store + set once at boot (so the first cycle has them).
if type(FU.loadStore) == "function" then pcall(FU.loadStore) end
if type(FU.ensureResolved) == "function" then pcall(FU.ensureResolved, true) end

FU.armTimer()

-- chat trigger: NORMAL chat (no "#") — type e.g.  upkeep now . Hooks the normal
-- chat-send RPC so SCUM never sees an admin command (no "Unrecognized command").
-- Thin delegator to the reloadable FU.onChatMessage in upkeep.lua, so command
-- tweaks apply via "upkeep reload" (no restart). Admin-gated in onChatMessage.
local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage"
local okHook, errHook = pcall(function()
    RegisterHook(TARGET, function(self, message, channel)
        if type(FU.onChatMessage) == "function" then pcall(FU.onChatMessage, self, message, channel) end
    end)
end)
FU.log(okHook and "ready: 'upkeep' chat trigger installed (normal chat, admin-gated)." or ("chat trigger FAILED: " .. tostring(errHook)))

-- final load banner
FU.log("=====================================================")
FU.log("FlagUpkeep is loaded. Type 'upkeep' in chat to see the available commands.")
FU.log("=====================================================")
