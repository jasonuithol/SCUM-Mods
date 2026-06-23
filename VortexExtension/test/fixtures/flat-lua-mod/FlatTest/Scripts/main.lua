-- FlatTest — a minimal, MANIFEST-LESS UE4SS Lua mod.
--
-- Purpose: verify the SCUM (UE4SS) Vortex extension's GENERIC installer — the
-- path taken by any "flat" third-party Lua mod that carries NO ue4ss.mod.json.
-- It is packaged the normal UE4SS way (<ModName>/Scripts/main.lua), so the
-- extension must detect it structurally and re-root it under ue4ss/Mods/.
--
-- Expected after Install + Deploy + Launch:
--   * deploys to  ...\SCUM\Binaries\Win64\ue4ss\Mods\FlatTest\Scripts\main.lua
--   * "FlatTest" is mod_enabled:true in  ...\ue4ss\Mods\mods.json
--   * UE4SS.log contains the [FlatTest] lines below
--   * a marker file  ...\ue4ss\Mods\FlatTest\FlatTest.loaded.txt  is written
--
-- Safe by construction: no game hooks, no chat, everything guarded by pcall so
-- it can never poison the UE4SS Lua VM.

print("[FlatTest] ===================================================")
print("[FlatTest] flat (manifest-less) Lua mod loaded via the generic installer")
print("[FlatTest] ===================================================")

-- Resolve our own folder from main.lua's own path (the same reflection trick the
-- real mods use), then drop a marker file so "did it load + is the path right"
-- is checkable without reading UE4SS.log.
local ok, err = pcall(function()
    local src = ((debug and debug.getinfo) and debug.getinfo(1, "S").source) or ""
    local dir = (src:gsub("^@", "")):match("^(.*)[/\\][^/\\]+[/\\][^/\\]+$")
    if dir and #dir > 0 then
        local f = io.open(dir .. "\\FlatTest.loaded.txt", "w")
        if f then
            f:write("FlatTest loaded OK via the generic installer\n")
            f:close()
        end
        print("[FlatTest] marker written under " .. dir)
    else
        print("[FlatTest] could not resolve own dir (reflection unavailable)")
    end
end)
if not ok then
    print("[FlatTest] marker step error: " .. tostring(err))
end
