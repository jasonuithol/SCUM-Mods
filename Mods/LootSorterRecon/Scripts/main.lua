-- LootSorterRecon — server-side UE4SS recon harness for the planned loot-sorter.
--
-- A headless dedicated server has no keyboard (no F11 hot-reload), so this
-- bootstrap hooks the admin-command RPC and, when an admin types "#lsr" in
-- chat, re-reads and runs an external live.lua. That gives a no-restart
-- iteration loop and hands live.lua the caller's context:
--    LSR.channel    = the PlayerRpcChannel instance
--    LSR.controller = their BP_ConZPlayerController_C (used for location/flag)
--
-- Requires (already set on this server's UE4SS-settings.ini):
--    HookProcessInternal = 1
--    HookProcessLocalScriptFunction = 1
--
-- READ-ONLY recon: live.lua only enumerates and dumps classes/properties to a
-- text file. It mutates NOTHING in the game. Mirrors the BulkUpgrade harness.

local TAG = "[LootSorterRecon] "
LSR = LSR or {}
function LSR.log(m) print(TAG .. tostring(m) .. "\n") end
function LSR.safe(fn)
    local ok, r = pcall(fn)
    if ok then return tostring(r) else return "<err: " .. tostring(r) .. ">" end
end

-- EDIT this to your server's path to live.lua:
local LIVE = [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\LootSorterRecon\Scripts\live.lua]]

function LSR.runLive()
    local f = io.open(LIVE, "r")
    if not f then LSR.log("cannot open live.lua (" .. LIVE .. ")"); return end
    local src = f:read("*a"); f:close()
    local chunk, cerr = load(src, "@live.lua")
    if not chunk then LSR.log("live.lua COMPILE error: " .. tostring(cerr)); return end
    LSR.log("---- running live.lua ----")
    local ok, rerr = pcall(chunk)
    if not ok then LSR.log("live.lua RUNTIME error: " .. tostring(rerr)) end
    LSR.log("---- live.lua done ----")
end

local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_ProcessAdminCommand"
local ok, err = pcall(function()
    RegisterHook(TARGET, function(self, commandText)
        local cmd = LSR.safe(function() return commandText:get():ToString() end)
        LSR.log("admin cmd: " .. cmd)
        LSR.channel = self:get()
        LSR.controller = nil
        pcall(function() LSR.controller = LSR.channel:GetOuter() end)
        if cmd == "lsr" then LSR.runLive() end
    end)
end)
if ok then
    LSR.log("bootstrap ready: hook installed. Type  #lsr  in chat to run live.lua.")
else
    LSR.log("bootstrap FAILED to hook: " .. tostring(err))
end
