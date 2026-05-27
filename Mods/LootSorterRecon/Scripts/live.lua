-- live.lua PASS 20 — ADMIN-COMMAND REGISTRY recon (READ-ONLY).
--
-- Goal: learn how SCUM stores/recognises "#" admin commands so we can assess
-- registering a custom "goober" command (to kill the "Unrecognized command"
-- reply WITHOUT mutating live UFunction args, which crashed the server).
--
-- Dumps, all read-only:
--   * sample UAdminCommand objects: _verb (name), _requiredExecutorLevel (tier),
--     _isEnabled, _shouldExecuteOnServer, owning class.
--   * UAdminCommandRegistry._commands (TArray<TSubclassOf<UAdminCommand>>): count
--     + whether iterable/readable.
--   * UAdminCommandCompletionManager._commands (TMap<FString,TSubclassOf>): count
--     + sample keys (this is the name->class map the dispatcher may use).
-- Nothing is mutated. Run #lsr, then share recon_admincmds.txt.

local OUT = [[C:\scumserver\SCUM\Binaries\Win64\ue4ss\Mods\LootSorterRecon\recon_admincmds.txt]]

local function appendln(s) local g=io.open(OUT,"a"); if g then g:write(tostring(s).."\n"); g:close() end end
local function pcs(fn, dflt) local ok, v = pcall(fn); if ok and v ~= nil then return v end; return dflt end
local function isValid(o) return o ~= nil and pcs(function() return o:IsValid() end, false) end
local function classOf(o) return pcs(function() return o:GetClass():GetFName():ToString() end, "?") end
local function fstr(s)
    if type(s) == "string" then return s end
    if type(s) == "userdata" then return pcs(function() return s:ToString() end, "<ud>") end
    if s == nil then return "<nil>" end
    return tostring(s)
end

do local f=io.open(OUT,"w"); if f then f:write("===== PASS 20 ADMIN-CMD REGISTRY recon :: "..os.date("%Y-%m-%d %H:%M:%S").." =====\n\n"); f:close() end end

-- 1) sample UAdminCommand objects (CDOs or instances) -----------------------
appendln("-- UAdminCommand objects (FindAllOf 'AdminCommand') --")
local cmds = FindAllOf("AdminCommand")
appendln("count = " .. (cmds and #cmds or 0))
if cmds then
    local shown = 0
    for i = 1, #cmds do
        local c = cmds[i]
        if c ~= nil then
            local verb = fstr(pcs(function() return c._verb end, nil))
            local tier = pcs(function() return c._requiredExecutorLevel end, "?")
            local en   = pcs(function() return c._isEnabled end, "?")
            local srv  = pcs(function() return c._shouldExecuteOnServer end, "?")
            local nreq = pcs(function() return c._numberOfRequiredArguments end, "?")
            appendln(string.format("  [%s] verb='%s' tier=%s enabled=%s server=%s reqArgs=%s",
                classOf(c), verb, tostring(tier), tostring(en), tostring(srv), tostring(nreq)))
            shown = shown + 1
            if shown >= 25 then appendln("  ...(truncated at 25)"); break end
        end
    end
end

-- 2) UAdminCommandRegistry._commands (array of command classes) -------------
appendln("\n-- UAdminCommandRegistry --")
local regs = FindAllOf("AdminCommandRegistry")
appendln("registry instances = " .. (regs and #regs or 0))
if regs and #regs > 0 then
    local reg = regs[1]
    local arr = pcs(function() return reg._commands end, nil)
    if arr == nil then
        appendln("  _commands = <nil/unreadable>")
    else
        local n = pcs(function() return #arr end, nil)
        appendln("  _commands #= " .. tostring(n))
        if n and n > 0 then
            for i = 1, math.min(n, 8) do
                local entry = pcs(function() return arr[i] end, nil)
                appendln(string.format("    [%d] %s (%s)", i, fstr(pcs(function() return entry:GetFName():ToString() end, nil)), type(entry)))
            end
        end
    end
end

-- 3) UAdminCommandCompletionManager._commands (name -> class TMap) ----------
appendln("\n-- UAdminCommandCompletionManager --")
local mans = FindAllOf("AdminCommandCompletionManager")
appendln("completion-manager instances = " .. (mans and #mans or 0))
if mans and #mans > 0 then
    local man = mans[1]
    local m = pcs(function() return man._commands end, nil)
    if m == nil then
        appendln("  _commands = <nil/unreadable>")
    else
        appendln("  _commands type=" .. type(m))
        local cnt = 0
        local ok = pcall(function()
            m:ForEach(function(k, v)
                cnt = cnt + 1
                if cnt <= 12 then
                    appendln(string.format("    '%s' -> %s",
                        fstr(pcs(function() return k:get() end, k)),
                        fstr(pcs(function() return v:get():GetFName():ToString() end, nil))))
                end
            end)
        end)
        appendln("  ForEach ok=" .. tostring(ok) .. " counted=" .. cnt)
    end
end

appendln("\n-- done --")
print("[lsr] PASS 20 admin-cmd recon written")
