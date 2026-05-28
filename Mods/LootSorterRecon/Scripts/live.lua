-- live.lua PASS 22 — os.execute / io.popen / Python availability probe.
--
-- The per-player loot-sorter gate needs SCUM.db (owner lives there, not on the
-- flag actor). UE4SS Lua has no SQLite, so the mod will shell out to Python.
-- This probe confirms the mod CAN shell out from this UE4SS build, and that the
-- spawned Python can open the server DB read-only. If both work, the whole
-- per-player architecture is unblocked. Read-only; touches nothing in-game.

local DIR = [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\LootSorterRecon]]
local OUT = DIR .. [[\recon_osexec.txt]]
local DB  = [[C:\scumserver\SCUM\Saved\SaveFiles\SCUM.db]]

local function appendln(s) local g=io.open(OUT,"a"); if g then g:write(tostring(s).."\n"); g:close() end end
local function readAll(p) local f=io.open(p,"r"); if not f then return nil end; local s=f:read("*a"); f:close(); return s end

do local f=io.open(OUT,"w"); if f then f:write("===== PASS 22 os.execute / python probe :: "..os.date("%Y-%m-%d %H:%M:%S").." =====\n\n"); f:close() end end

appendln("type(os.execute) = " .. type(os.execute))
appendln("type(io.popen)   = " .. type(io.popen))
appendln("type(os.getenv)  = " .. type(os.getenv))
appendln("")

-- 1) os.execute can run at all? -------------------------------------------
if type(os.execute) == "function" then
    local probePy = DIR .. [[\probe_py.txt]]
    local cmd1 = string.format('cmd /c python --version > "%s" 2>&1', probePy)
    appendln("os.execute #1: " .. cmd1)
    local a, b, c = os.execute(cmd1)
    appendln("  returned: a=" .. tostring(a) .. " b=" .. tostring(b) .. " c=" .. tostring(c))
    appendln("  probe_py.txt = " .. (readAll(probePy) and ("[" .. (readAll(probePy):gsub("%s+$","")) .. "]") or "<not written>"))
    appendln("")

    -- 2) spawned python can import sqlite3 + open the server DB read-only? --
    local probeDb = DIR .. [[\probe_sqlite.txt]]
    local py = 'import sqlite3; c=sqlite3.connect(\'file:' .. DB:gsub('\\','/') .. '?mode=ro\', uri=True);'
            .. ' print(\'sqlite\', sqlite3.sqlite_version);'
            .. ' print(\'bases\', c.execute(\'SELECT COUNT(*) FROM base\').fetchone()[0])'
    local cmd2 = string.format('cmd /c python -c "%s" > "%s" 2>&1', py, probeDb)
    appendln("os.execute #2 (open DB ro + count bases):")
    appendln("  " .. cmd2)
    os.execute(cmd2)
    appendln("  probe_sqlite.txt:")
    local r = readAll(probeDb)
    if r then for line in r:gmatch("[^\r\n]+") do appendln("    " .. line) end else appendln("    <not written>") end
    appendln("")
else
    appendln("os.execute NOT available — will need an external resolver process instead.")
end

-- 3) io.popen (capture stdout directly, no temp file) ---------------------
if type(io.popen) == "function" then
    appendln("io.popen test: python --version")
    local ok, out = pcall(function()
        local h = io.popen("python --version 2>&1"); if not h then return "<popen returned nil>" end
        local s = h:read("*a"); h:close(); return s
    end)
    appendln("  ok=" .. tostring(ok) .. " out=[" .. tostring(out and (tostring(out):gsub("%s+$","")) or "nil") .. "]")
else
    appendln("io.popen NOT available.")
end

appendln("\n-- done --")
print("[lsr] PASS 22 os.execute/python probe written")
