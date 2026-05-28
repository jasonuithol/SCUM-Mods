-- GarbageGoober — server-side UE4SS mod.
--
-- Periodically sweeps loose ground loot that sits inside a flag's influence and
-- moves each item into a chest IN THE SAME FLAG whose custom name matches the
-- item's category (most-specific first, falling back up the tree; no match =>
-- item left in place + logged). Server-side only — coexists with client BattlEye.
--
-- Recon-confirmed building blocks (see memory [[project-loot-sorter]],
-- [[reference-scum-item-inventory-model]], docs/recon/loot-sorter-model-2026-05-27.md):
--   * loose loot = AItem w/ UItemPresence_OnTheFloor  (FindAllOf("Item"))
--   * chests     = AChestItem owning a ChestInventoryComponent; name in
--                  _nameableItemComponent._name
--   * flag scope = ConZBase actors + _flagInfluenceRadius (5000cm / 50m)
--   * the move   = UInventoryUserComponent:Server_InventoryComponent_AddOrMoveEntry(
--                    chestInv, item, {Value=0x40000000})  -- auto-place; safe off-thread
--   * loot/chests are live actors only within ~200m of a player, so the sweep
--     no-ops on truly unattended bases (by design — a player must be nearby).
--
-- Enable by adding   GarbageGoober : 1   to UE4SS Mods/mods.txt  (NEVER enabled.txt —
-- it silently overrides mods.txt). Requires HookProcessInternal=1 &
-- HookProcessLocalScriptFunction=1 in UE4SS-settings.ini for the goober chat trigger.

-- >>> set this to the mod's folder on your server <<<
local MOD_DIR = [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\GarbageGoober]]
local SCRIPTS = MOD_DIR .. [[\Scripts]]
local LOGFILE = MOD_DIR .. [[\GarbageGoober.log]]

GarbageGoober = GarbageGoober or {}
local GG = GarbageGoober

-- Paths for the entitlement layer. The mod reads SCUM.db via the bundled
-- sqlite3.exe (fetched by install-libraries.ps1) and keeps its own store in
-- entitlements.lua. See Scripts/sorter.lua + Scripts/Config.lua.
GG.modDir = MOD_DIR
GG.sqliteExe = MOD_DIR .. [[\sqlite3.exe]]
GG.storeFile = MOD_DIR .. [[\entitlements.lua]]

local function ts() return os.date("%Y-%m-%d %H:%M:%S") end
function GG.log(m)
    local line = "[GarbageGoober] " .. ts() .. " " .. tostring(m)
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

-- (re)load config + sweep engine. Safe to call any time (e.g. after editing Config.lua).
function GG.reload()
    local ok, res = runFile(SCRIPTS .. [[\Config.lua]])
    if ok and type(res) == "table" then
        GG.config = res
        GG.log("config loaded (interval=" .. tostring(res.sweepIntervalMs) ..
            "ms, rules=" .. tostring(#(res.rules or {})) .. ")")
    else
        GG.log("CONFIG load FAILED: " .. tostring(res) .. " — keeping previous config")
        if not GG.config then return false end
    end
    local ok2, e2 = runFile(SCRIPTS .. [[\sorter.lua]])
    if not ok2 then GG.log("sorter.lua load FAILED: " .. tostring(e2)); return false end
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
        return false -- keep looping
    end)
    GG.log("sweep timer armed @ " .. interval .. "ms (set GarbageGoober.enabled=false to pause).")
end

-- ---- bootstrap -----------------------------------------------------------
do local f = io.open(LOGFILE, "w"); if f then f:write("===== GarbageGoober started :: " .. ts() .. " =====\n"); f:close() end end

if not GG.reload() then
    GG.log("startup ABORTED: could not load config/engine.")
    return
end

-- Prime the entitlement store + set once at boot (so the first sweep has them).
if type(GG.loadStore) == "function" then pcall(GG.loadStore) end
if type(GG.ensureResolved) == "function" then pcall(GG.ensureResolved, true) end

GG.armTimer()

-- chat trigger: NORMAL chat (no "#") — type e.g.  goober now . Hooks the normal
-- chat-send RPC so SCUM never sees an admin command (no "Unrecognized command").
-- Thin delegator to the reloadable GG.onChatMessage in sorter.lua, so command
-- tweaks apply via "goober reload" (no restart). Admin-gated in onChatMessage.
local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage"
local okHook, errHook = pcall(function()
    RegisterHook(TARGET, function(self, message, channel)
        if type(GG.onChatMessage) == "function" then pcall(GG.onChatMessage, self, message, channel) end
    end)
end)
GG.log(okHook and "ready: 'goober' chat trigger installed (normal chat, admin-gated)." or ("chat trigger FAILED: " .. tostring(errHook)))

-- final load banner
GG.log("=====================================================")
GG.log("GarbageGoober is loaded. Type 'goober' in chat to see the available commands.")
GG.log("=====================================================")
