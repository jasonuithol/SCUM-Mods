-- ClothesDryer — release bootstrap (eval build).
--
-- This is the ONLY plaintext Lua in an eval package, and it holds no IP: it just
-- asks dryer-core.exe to decrypt the real engine (Config + the shared gating lib
-- + dryer, baked into the exe) and load() it into UE4SS's live Lua VM. The
-- decrypted source exists only in memory. The expiry/time-bomb lives in
-- dryer-core.exe (native), not here.
--
-- Enable by adding   ClothesDryer : 1   to UE4SS Mods/mods.txt  (NEVER enabled.txt).
-- Requires HookProcessInternal=1 & HookProcessLocalScriptFunction=1 in
-- UE4SS-settings.ini for the 'dryer' chat trigger.

-- MOD_DIR arrives as the first vararg from the wrapper stub (the editable
-- plaintext line lives there); falls back to this default if run unwrapped.
local MOD_DIR = (...) or [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\ClothesDryer]]
local LOGFILE = MOD_DIR .. [[\ClothesDryer.log]]

ClothesDryer = ClothesDryer or {}
local CD = ClothesDryer

CD.modDir    = MOD_DIR
CD.sqliteExe = MOD_DIR .. [[\sqlite3.exe]]
CD.storeFile = MOD_DIR .. [[\entitlements.lua]]
CD.dryersFile = MOD_DIR .. [[\dryers.lua]]
CD.coreExe   = MOD_DIR .. [[\dryer-core.exe]]

local function ts() return os.date("%Y-%m-%d %H:%M:%S") end
function CD.log(m)
    local line = "[ClothesDryer] " .. ts() .. " " .. tostring(m)
    print(line .. "\n")
    local f = io.open(LOGFILE, "a"); if f then f:write(line .. "\n"); f:close() end
end

-- Ask dryer-core.exe to decrypt the engine to stdout, in memory. Same cmd.exe
-- quoting trick the DB reader uses: wrap the whole command in one extra pair of
-- quotes so cmd strips exactly one pair and the inner exe-path quoting survives.
local function dq(s) return '"' .. tostring(s) .. '"' end
local function emitSource()
    local inner = dq(CD.coreExe) .. " emit"
    local h = io.popen('"' .. inner .. '"', "r")
    if not h then return nil, "io.popen failed" end
    local src = h:read("*a"); h:close()
    if not src or src == "" then return nil, "dryer-core emitted nothing (missing exe?)" end
    return src
end

-- (re)load the engine from dryer-core. The chunk sets CD.config, runs the gating
-- lib + Gating.attach(CD, opts), then defines CD.dryCycle/onChatMessage/etc.
function CD.reload()
    local src, err = emitSource()
    if not src then CD.log("RELOAD failed: " .. tostring(err)); return false end
    local chunk, cerr = load(src, "=dryer-core")
    if not chunk then CD.log("RELOAD compile failed: " .. tostring(cerr)); return false end
    local ok, perr = pcall(chunk)
    if not ok then CD.log("RELOAD run failed: " .. tostring(perr)); return false end
    if type(CD.config) ~= "table" then CD.log("RELOAD: config not set by engine"); return false end
    CD.log("engine loaded (interval=" .. tostring(CD.config.dryIntervalMs) ..
        "ms, dryerClass='" .. tostring(CD.config.dryerClass) .. "')")
    return true
end

-- install the periodic dry cycle exactly once (interval fixed at load time)
function CD.armTimer()
    if CD.timerArmed then return end
    CD.timerArmed = true
    local interval = (CD.config and CD.config.dryIntervalMs) or 4000
    LoopAsync(interval, function()
        if CD.enabled ~= false and type(CD.dryCycle) == "function" then
            pcall(CD.dryCycle)
        end
        return false
    end)
    CD.log("dry-cycle timer armed @ " .. interval .. "ms.")
end

-- ---- bootstrap -----------------------------------------------------------
do local f = io.open(LOGFILE, "w"); if f then f:write("===== ClothesDryer started :: " .. ts() .. " =====\n"); f:close() end end

if not CD.reload() then
    CD.log("startup ABORTED: could not load engine (expired, or dryer-core.exe missing?).")
    return
end

if type(CD.loadStore) == "function" then pcall(CD.loadStore) end       -- entitlements (shared lib)
if type(CD.loadDryers) == "function" then pcall(CD.loadDryers) end      -- active dryers (mod-owned)
if type(CD.ensureResolved) == "function" then pcall(CD.ensureResolved, true) end

CD.armTimer()

-- chat trigger: NORMAL chat (no "#"). Thin delegator to CD.onChatMessage in the
-- (encrypted) engine, so it no-ops cleanly if the build has expired.
local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage"
local okHook, errHook = pcall(function()
    RegisterHook(TARGET, function(self, message, channel)
        if type(CD.onChatMessage) == "function" then pcall(CD.onChatMessage, self, message, channel) end
    end)
end)
CD.log(okHook and "ready: 'dryer' chat trigger installed." or ("chat trigger FAILED: " .. tostring(errHook)))

CD.log("=====================================================")
CD.log("ClothesDryer is loaded. Type 'dryer' in chat to see the available commands.")
CD.log("=====================================================")
