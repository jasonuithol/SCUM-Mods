-- FlagUpgrade -- BOOTSTRAP v2 (auto-watch).
-- Reads + executes <project>\.staging\live.lua. Two triggers:
--   * F11            -> run live.lua now (manual fallback)
--   * auto-watch     -> if LoopAsync + ExecuteInGameThread exist, re-run live.lua
--                       automatically whenever its contents change (edit-and-go,
--                       no keypress). Stay in the map and saved recons just run.
-- Iterate by editing live.lua only; this file stays stable.

local ModName = "FlagUpgrade"
local LIVE = [[C:\Users\jason\Desktop\Projects\SCUM-Modding\.staging\live.lua]]

print(string.format("[%s] BOOTSTRAP v2 loaded\n", ModName))

local function read_live()
    local fh = io.open(LIVE, "r"); if not fh then return nil end
    local src = fh:read("*a"); fh:close(); return src
end

local function exec_src(src, how)
    local chunk, lerr = load(src, "@live.lua")
    if not chunk then print(string.format("[%s] live.lua COMPILE error: %s\n", ModName, tostring(lerr))); return end
    print(string.format("[%s] running live.lua (%s)\n", ModName, how))
    local ok, rerr = pcall(chunk)
    if not ok then print(string.format("[%s] live.lua RUNTIME error: %s\n", ModName, tostring(rerr)))
    else print(string.format("[%s] live.lua done\n", ModName)) end
end

local function run_manual()
    local src = read_live()
    if not src then print(string.format("[%s] live.lua not found\n", ModName)); return end
    exec_src(src, "manual F11")
end

RegisterKeyBindAsync(Key.F11, {}, run_manual)

-- auto-watch: poll the file on an async thread, run changes on the game thread
local last_src = read_live()
if type(LoopAsync) == "function" and type(ExecuteInGameThread) == "function" then
    print(string.format("[%s] auto-watch ENABLED -- edit live.lua and it runs itself (~2s)\n", ModName))
    LoopAsync(1500, function()
        local src = read_live()
        if src and src ~= last_src then
            last_src = src
            ExecuteInGameThread(function() exec_src(src, "auto on change") end)
        end
        return false  -- keep looping
    end)
else
    print(string.format("[%s] auto-watch unavailable; use F11\n", ModName))
end
