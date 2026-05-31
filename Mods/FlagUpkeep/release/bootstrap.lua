-- FlagUpkeep — release bootstrap (eval build).
--
-- This is the ONLY plaintext Lua in an eval package, and it holds no IP: it just
-- asks upkeep-core.exe to decrypt the real engine (Config + the shared gating
-- lib + upkeep, baked into the exe) and load() it into UE4SS's live Lua VM. The
-- decrypted source exists only in memory. The expiry/time-bomb lives in
-- upkeep-core.exe (native), not here.
--
-- Enable by adding   FlagUpkeep : 1   to UE4SS Mods/mods.txt  (NEVER enabled.txt).
-- Requires HookProcessInternal=1 & HookProcessLocalScriptFunction=1 in
-- UE4SS-settings.ini for the 'upkeep' chat trigger.

-- MOD_DIR arrives as the first vararg from the wrapper stub (the editable
-- plaintext line lives there); falls back to this default if run unwrapped.
local MOD_DIR = (...) or [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\FlagUpkeep]]
local LOGFILE = MOD_DIR .. [[\FlagUpkeep.log]]

FlagUpkeep = FlagUpkeep or {}
local FU = FlagUpkeep

FU.modDir   = MOD_DIR
FU.sqliteExe = MOD_DIR .. [[\sqlite3.exe]]
FU.storeFile = MOD_DIR .. [[\entitlements.lua]]
FU.coreExe   = MOD_DIR .. [[\upkeep-core.exe]]

local function ts() return os.date("%Y-%m-%d %H:%M:%S") end
function FU.log(m)
    local line = "[FlagUpkeep] " .. ts() .. " " .. tostring(m)
    print(line .. "\n")
    local f = io.open(LOGFILE, "a"); if f then f:write(line .. "\n"); f:close() end
end

-- Ask upkeep-core.exe to decrypt the engine to stdout, in memory. Same cmd.exe
-- quoting trick the DB reader uses: wrap the whole command in one extra pair of
-- quotes so cmd strips exactly one pair and the inner exe-path quoting survives.
local function dq(s) return '"' .. tostring(s) .. '"' end
local function emitSource()
    local inner = dq(FU.coreExe) .. " emit"
    local h = io.popen('"' .. inner .. '"', "r")
    if not h then return nil, "io.popen failed" end
    local src = h:read("*a"); h:close()
    if not src or src == "" then return nil, "upkeep-core emitted nothing (missing exe?)" end
    return src
end

-- (re)load the engine from upkeep-core. The chunk sets FU.config, runs the
-- gating lib + Gating.attach(FU, opts), then defines FU.upkeep/onChatMessage/etc.
function FU.reload()
    local src, err = emitSource()
    if not src then FU.log("RELOAD failed: " .. tostring(err)); return false end
    local chunk, cerr = load(src, "=upkeep-core")
    if not chunk then FU.log("RELOAD compile failed: " .. tostring(cerr)); return false end
    local ok, perr = pcall(chunk)
    if not ok then FU.log("RELOAD run failed: " .. tostring(perr)); return false end
    if type(FU.config) ~= "table" then FU.log("RELOAD: config not set by engine"); return false end
    FU.log("engine loaded (interval=" .. tostring(FU.config.upkeepIntervalMs) ..
        "ms, container='" .. tostring(FU.config.containerName) .. "')")
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
        return false
    end)
    FU.log("upkeep timer armed @ " .. interval .. "ms.")
end

-- ---- bootstrap -----------------------------------------------------------
do local f = io.open(LOGFILE, "w"); if f then f:write("===== FlagUpkeep started :: " .. ts() .. " =====\n"); f:close() end end

if not FU.reload() then
    FU.log("startup ABORTED: could not load engine (expired, or upkeep-core.exe missing?).")
    return
end

if type(FU.loadStore) == "function" then pcall(FU.loadStore) end
if type(FU.ensureResolved) == "function" then pcall(FU.ensureResolved, true) end

FU.armTimer()

-- chat trigger: NORMAL chat (no "#"). Thin delegator to FU.onChatMessage in the
-- (encrypted) engine, so it no-ops cleanly if the build has expired.
local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage"
local okHook, errHook = pcall(function()
    RegisterHook(TARGET, function(self, message, channel)
        if type(FU.onChatMessage) == "function" then pcall(FU.onChatMessage, self, message, channel) end
    end)
end)
FU.log(okHook and "ready: 'upkeep' chat trigger installed." or ("chat trigger FAILED: " .. tostring(errHook)))

FU.log("=====================================================")
FU.log("FlagUpkeep is loaded. Type 'upkeep' in chat to see the available commands.")
FU.log("=====================================================")
