-- BulkUpgrade — SERVER-SIDE UE4SS hot-reload harness for a SCUM dedicated server.
--
-- A headless server has no keyboard (no F11 hot-reload), so this bootstrap hooks
-- the admin-command RPC and, when the admin types "#bu" in chat, re-reads and
-- runs an external live.lua. That gives a no-restart iteration loop, and hands
-- live.lua the calling player's context:
--    BU.channel    = the PlayerRpcChannel instance
--    BU.controller = their BP_ConZPlayerController_C  (use for location/flag scope)
--
-- Deploy: copy UE4SS (dwmapi.dll + ue4ss/) into <server>/SCUM/Binaries/Win64,
-- enable HookProcessInternal=1 and HookProcessLocalScriptFunction=1 in
-- UE4SS-settings.ini, and set LIVE below to wherever you keep live.lua.
-- See docs/server-side-upgrade-findings.md for the full story.

local TAG = "[BulkUpgrade] "
BU = BU or {}
function BU.log(m) print(TAG .. tostring(m) .. "\n") end
function BU.safe(fn)
    local ok, r = pcall(fn)
    if ok then return tostring(r) else return "<err: " .. tostring(r) .. ">" end
end

-- EDIT this to your server's path to live.lua:
local LIVE = [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\BulkUpgrade\Scripts\live.lua]]

function BU.runLive()
    local f = io.open(LIVE, "r")
    if not f then BU.log("cannot open live.lua (" .. LIVE .. ")"); return end
    local src = f:read("*a"); f:close()
    local chunk, cerr = load(src, "@live.lua")
    if not chunk then BU.log("live.lua COMPILE error: " .. tostring(cerr)); return end
    BU.log("---- running live.lua ----")
    local ok, rerr = pcall(chunk)
    if not ok then BU.log("live.lua RUNTIME error: " .. tostring(rerr)) end
    BU.log("---- live.lua done ----")
end

local TARGET = "/Script/SCUM.PlayerRpcChannel:Chat_Server_ProcessAdminCommand"
local ok, err = pcall(function()
    RegisterHook(TARGET, function(self, commandText)
        local cmd = BU.safe(function() return commandText:get():ToString() end)
        BU.log("admin cmd: " .. cmd)
        BU.channel = self:get()
        BU.controller = nil
        pcall(function() BU.controller = BU.channel:GetOuter() end)
        if cmd == "bu" then BU.runLive() end
    end)
end)
if ok then
    BU.log("bootstrap ready: hook installed. Type  #bu  in chat to run live.lua.")
else
    BU.log("bootstrap FAILED to hook: " .. tostring(err))
end
