-- GarbageGoober — release bootstrap (eval build).
--
-- This is the ONLY plaintext Lua in an eval package, and it holds no IP: it just
-- asks goober-core.exe to decrypt the real engine (Config + sorter, shipped
-- encrypted in payload.bin) and load() it into UE4SS's live Lua VM. The
-- decrypted source exists only in memory. The expiry/time-bomb lives in
-- goober-core.exe (native), not here.
--
-- Enable by adding   GarbageGoober : 1   to UE4SS Mods/mods.txt  (NEVER enabled.txt).
-- Requires HookProcessInternal=1 & HookProcessLocalScriptFunction=1 in
-- UE4SS-settings.ini for the goober chat trigger.

-- MOD_DIR arrives as the first vararg from the wrapper stub (the editable
-- plaintext line lives there); falls back to this default if run unwrapped.
local MOD_DIR = (...) or [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\GarbageGoober]]
local LOGFILE = MOD_DIR .. [[\GarbageGoober.log]]

GarbageGoober = GarbageGoober or {}
local GG = GarbageGoober

GG.modDir   = MOD_DIR
GG.sqliteExe = MOD_DIR .. [[\sqlite3.exe]]
GG.storeFile = MOD_DIR .. [[\entitlements.lua]]
GG.coreExe   = MOD_DIR .. [[\goober-core.exe]]

local function ts() return os.date("%Y-%m-%d %H:%M:%S") end
function GG.log(m)
    local line = "[GarbageGoober] " .. ts() .. " " .. tostring(m)
    print(line .. "\n")
    local f = io.open(LOGFILE, "a"); if f then f:write(line .. "\n"); f:close() end
end

-- Ask goober-core.exe to decrypt the engine to stdout, in memory. Same cmd.exe
-- quoting trick the DB reader uses: wrap the whole command in one extra pair of
-- quotes so cmd strips exactly one pair and the inner exe-path quoting survives.
local function dq(s) return '"' .. tostring(s) .. '"' end
local function emitSource()
    local inner = dq(GG.coreExe) .. " emit"
    local h = io.popen('"' .. inner .. '"', "r")
    if not h then return nil, "io.popen failed" end
    local src = h:read("*a"); h:close()
    if not src or src == "" then return nil, "goober-core emitted nothing (missing exe/payload?)" end
    return src
end

-- (re)load the engine from goober-core. Defines GG.config + GG.sweep/etc.
function GG.reload()
    local src, err = emitSource()
    if not src then GG.log("RELOAD failed: " .. tostring(err)); return false end
    local chunk, cerr = load(src, "=goober-core")
    if not chunk then GG.log("RELOAD compile failed: " .. tostring(cerr)); return false end
    local ok, perr = pcall(chunk)
    if not ok then GG.log("RELOAD run failed: " .. tostring(perr)); return false end
    if type(GG.config) ~= "table" then GG.log("RELOAD: config not set by engine"); return false end
    GG.log("engine loaded (interval=" .. tostring(GG.config.sweepIntervalMs) ..
        "ms, rules=" .. tostring(#(GG.config.rules or {})) .. ")")
    return true
end

-- install the periodic sweep exactly once (interval fixed at load time)
function GG.armTimer()
    if GG.timerArmed then return end
    GG.timerArmed = true
    local interval = (GG.config and GG.config.sweepIntervalMs) or 60000
    LoopAsync(interval, function()
        if GG.enabled ~= false and type(GG.sweep) == "function" then
            pcall(GG.sweep)
        end
        return false
    end)
    GG.log("sweep timer armed @ " .. interval .. "ms.")
end

-- ---- bootstrap -----------------------------------------------------------
do local f = io.open(LOGFILE, "w"); if f then f:write("===== GarbageGoober started :: " .. ts() .. " =====\n"); f:close() end end

if not GG.reload() then
    GG.log("startup ABORTED: could not load engine (expired, or goober-core.exe/payload.bin missing?).")
    return
end

if type(GG.loadStore) == "function" then pcall(GG.loadStore) end
if type(GG.ensureResolved) == "function" then pcall(GG.ensureResolved, true) end

GG.armTimer()

-- chat trigger: NORMAL chat (no "#"). Thin delegator to GG.onChatMessage in the
-- (encrypted) engine, so it no-ops cleanly if the build has expired.
local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage"
local okHook, errHook = pcall(function()
    RegisterHook(TARGET, function(self, message, channel)
        if type(GG.onChatMessage) == "function" then pcall(GG.onChatMessage, self, message, channel) end
    end)
end)
GG.log(okHook and "ready: 'goober' chat trigger installed." or ("chat trigger FAILED: " .. tostring(errHook)))

GG.log("=====================================================")
GG.log("GarbageGoober is loaded. Type 'goober' in chat to see the available commands.")
GG.log("=====================================================")
