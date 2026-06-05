-- dryer.lua — ClothesDryer's mod-specific engine. The shared gating layer
-- (helpers, world enumeration, SCUM.db, entitlement store/resolution, access
-- commands, chat reply/onChatMessage) is installed onto CD by the shared library
-- (main.lua -> gating.lua) BEFORE this file loads. Here we keep only what's
-- specific to ClothesDryer: wardrobe collection, the activation recipe
-- (match + consume), the dry action, activation persistence, help, dispatch.

ClothesDryer = ClothesDryer or {}
local CD = ClothesDryer

-- shared helpers installed by gating.attach
local pcs, isValid, classOf, fullName, presClass = CD.pcs, CD.isValid, CD.classOf, CD.fullName, CD.presClass
local actorLoc, hdist, trim = CD.actorLoc, CD.hdist, CD.trim
local collectFlags, flagFor, findIUC = CD.collectFlags, CD.flagFor, CD.findIUC
local currentFlagBaseId = CD.currentFlagBaseId
local flagEnabled, flagEnabledForIssuer = CD.flagEnabled, CD.flagEnabledForIssuer
local replyNotEnabled = CD.replyNotEnabled

local function cfg() return CD.config or {} end

-- ---- IWettable clothing (proven safe: item-level interface, no components) ----
local CLOTHESITEM = pcs(function() return StaticFindObject("/Script/SCUM.ClothesItem") end, nil)
local function isClothing(it)
    if not pcs(function() return it:IsA(CLOTHESITEM) end, false) then return false end
    return (pcs(function() return it:GetMaxPossibleWaterWeight() end, 0) or 0) > 0  -- max>0 skips ghost dupes
end
local function waterOf(it) return tonumber(pcs(function() return it:GetWaterWeight() end, 0)) or 0 end

-- ---- stack quantity (read via the component, mapped back through GetOwner) ----
-- Item COMPONENTS can't be iterated from an item (crashes, gotcha #16), but
-- enumerating a component CLASS and reading its GetOwner() is a different path.
-- Build a map: item fullName -> stack quantity (_repQuantity). Non-stackables
-- have no such component and default to 1. Fully pcall-guarded.
local function buildQtyMap()
    local m = {}
    local comps = pcs(function() return FindAllOf("StackableItemComponent") end, nil)
    if not comps then return m end
    for i = 1, #comps do
        local c = comps[i]
        if isValid(c) then
            local owner = pcs(function() return c:GetOwner() end, nil)
            local q = pcs(function() return c._repQuantity end, nil)
            if isValid(owner) and q then
                local fn = fullName(owner)
                if fn then m[fn] = tonumber(q) or m[fn] end
            end
        end
    end
    return m
end
local function dryItem(it) return (pcall(function() it:SetWaterWeight(0.0) end)) end

-- ---- wardrobe collection (owner == dryerClass), keeps owner + location -------
-- { [ownerFullName] = { owner=, x=, y=, z=, items={...} } } — only non-empty
-- wardrobes appear (built from items, like the lib's collectContainerContents).
local function collectWardrobes()
    local want = cfg().dryerClass
    local map = {}
    local items = FindAllOf("Item") or {}
    for i = 1, #items do
        local it = items[i]
        if isValid(it) then
            local pc = presClass(it)
            if pc and pc:find("InTheInventory", 1, true) then
                local inv = pcs(function() return it._serverPresence._inventory end, nil)
                local owner = inv and pcs(function() return inv:GetOwner() end, nil) or nil
                if isValid(owner) and classOf(owner) == want then
                    local key = fullName(owner)
                    if key then
                        local rec = map[key]
                        if not rec then
                            local x, y, z = actorLoc(owner)
                            rec = { owner = owner, x = x, y = y, z = z, items = {}, seen = {} }
                            map[key] = rec
                        end
                        -- DEDUPE by item fullName: FindAllOf("Item") can return ghost
                        -- duplicates of the same item, which over-consume the recipe
                        -- on activation (a ghost's DestroyInternal pcall-succeeds but
                        -- no-ops, leaving a real item). Keep one ref per fullName.
                        local ifn = fullName(it)
                        if ifn and not rec.seen[ifn] then
                            rec.seen[ifn] = true
                            rec.items[#rec.items + 1] = it
                        end
                    end
                end
            end
        end
    end
    return map
end

-- stable id for a (static) wardrobe = its location on a 10cm grid. Deployables
-- never move, so this survives restarts (actor userdata pointers don't).
local function locKey(x, y, z)
    if not x then return nil end
    return string.format("%d,%d,%d", math.floor(x/10+0.5), math.floor(y/10+0.5), math.floor(z/10+0.5))
end

-- live player pawn nearest to (x,y) -> pawn, distCm (doubles as "is it loaded?")
local function nearestPawn(x, y)
    local best, bestd
    local l = FindAllOf("BP_Prisoner_C")
    if l then for i = 1, #l do
        local p = l[i]
        if isValid(p) then
            local px, py = actorLoc(p)
            if px then local d = hdist(px, py, x, y); if not bestd or d < bestd then best, bestd = p, d end end
        end
    end end
    return best, bestd
end

-- ---- activation persistence (mod-owned file: locKey -> baseId) ---------------
CD.dryers = CD.dryers or {}

function CD.loadDryers()
    CD.dryers = {}
    local f = CD.dryersFile and io.open(CD.dryersFile, "r") or nil
    if not f then return end
    local src = f:read("*a"); f:close()
    local chunk = load(src, "@dryers"); if not chunk then return end
    local ok, t = pcall(chunk)
    if ok and type(t) == "table" and type(t.activated) == "table" then
        for k, v in pairs(t.activated) do
            if type(k) == "string" then CD.dryers[k] = math.tointeger(tonumber(v)) or true end
        end
    end
end

function CD.saveDryers()
    local f = CD.dryersFile and io.open(CD.dryersFile, "w") or nil
    if not f then CD.log("could not write dryers file: " .. tostring(CD.dryersFile)); return false end
    f:write("-- active dryers (wardrobe locKey -> baseId). Written by 'dryer activate'.\n")
    f:write("return {\n  activated = {\n")
    local keys = {}; for k in pairs(CD.dryers) do keys[#keys + 1] = k end; table.sort(keys)
    for _, k in ipairs(keys) do
        local v = CD.dryers[k]
        f:write(string.format("    [%q] = %s,\n", k, type(v) == "number" and tostring(v) or "true"))
    end
    f:write("  },\n}\n")
    f:close()
    return true
end

-- ---- recipe (match + consume) ------------------------------------------------
function CD.recipeStr()
    local parts = {}
    for _, ing in ipairs(cfg().recipe or {}) do parts[#parts + 1] = string.format("%dx %s", ing.count or 1, ing.name or ing.classes[1]) end
    return table.concat(parts, " + ")
end

-- returns (consumeList) if the wardrobe's items satisfy the recipe, else
-- (nil, missingList). Counting is by TOTAL stack quantity (_repQuantity via
-- buildQtyMap), not entry count, so a stack of 5 bolts counts as 5. Consumption
-- removes WHOLE entries (no partial-stack RPC exists), smallest-stack-first to
-- minimise waste — exact provided amounts consume exactly what you put in.
local function recipeMatch(items)
    local qty = buildQtyMap()
    local pool = {}  -- class -> { {it=, q=}, ... }
    for _, it in ipairs(items) do
        local c = classOf(it)
        pool[c] = pool[c] or {}
        pool[c][#pool[c] + 1] = { it = it, q = qty[fullName(it)] or 1 }
    end
    local consume, missing = {}, {}
    for _, ing in ipairs(cfg().recipe or {}) do
        local need = ing.count or 1
        local cand = {}  -- candidate entries across all accepted classes
        for _, cls in ipairs(ing.classes or {}) do
            for _, e in ipairs(pool[cls] or {}) do cand[#cand + 1] = e end
        end
        table.sort(cand, function(a, b) return a.q < b.q end)  -- smallest stacks first
        local got = 0
        for _, e in ipairs(cand) do
            if got >= need then break end
            consume[#consume + 1] = e.it
            got = got + e.q
        end
        if got < need then missing[#missing + 1] = string.format("%s (need %d, have %d)", ing.name or "?", need, got) end
    end
    if #missing > 0 then return nil, missing end
    return consume
end

-- permanently consume an item entry by destroying it IN PLACE via
-- AItem:DestroyInternal() (proven live 2026-06-04 — item vanishes, nothing hits
-- the floor; the container's OnContainedItemDestroyed cleans up the slot). NOTE:
-- destruction is async — isValid() still reads true the same frame — so we count
-- success by the call returning, NOT by an immediate re-check. RemoveEntry is NOT
-- used (it only drops the item to the floor). iuc kept for signature symmetry.
local function consumeItem(iuc, item)
    if not isValid(item) then return false end
    return (pcall(function() item:DestroyInternal() end))
end

-- ---- the dry cycle -----------------------------------------------------------
function CD.dryCycle()
    if CD.enabled == false then return end
    CD.ensureResolved(false)
    local wardrobes = collectWardrobes()
    local flags = collectFlags()
    local active, dried = 0, 0
    for _, w in pairs(wardrobes) do
        local lk = locKey(w.x, w.y, w.z)
        if lk and CD.dryers[lk] then
            active = active + 1
            local flag = flagFor(w.x, w.y, flags)
            local enabled = (not cfg().entitlementsEnabled) or (flag and flagEnabled(flag))
            if enabled then
                local _, dist = nearestPawn(w.x, w.y)
                local range = cfg().dryLoadedRangeCm or 20000
                if dist and dist <= range then
                    for _, it in ipairs(w.items) do
                        if isClothing(it) and waterOf(it) > (cfg().dryThreshold or 1.0) then
                            if dryItem(it) then dried = dried + 1 end
                        end
                    end
                end
            end
        end
    end
    if dried > 0 then CD.log(string.format("dry cycle: %d active dryer(s), dried %d item(s)", active, dried)) end
    return active, dried
end

-- ---- user commands -----------------------------------------------------------
-- 'dryer scan' — dump the classes of items in the wardrobe(s) in your flag, so we
-- can lock the exact recipe class names. Also shows clothing water levels.
function CD.cmdScan()
    local scanFile = CD.modDir and (CD.modDir .. [[\scan.txt]]) or nil
    local sf = scanFile and io.open(scanFile, "w") or nil
    local say = function(s)
        CD.reply(s, true)
        if sf then sf:write(tostring(s) .. "\n") end
    end
    local baseId = currentFlagBaseId()
    local flag; for _, f in ipairs(collectFlags()) do if f.baseId == baseId then flag = f; break end end
    local wardrobes = collectWardrobes()
    local n = 0
    for _, w in pairs(wardrobes) do
        if (not flag) or (w.x and hdist(w.x, w.y, flag.x, flag.y) <= flag.radius) then
            n = n + 1
            say(string.format("wardrobe @%s  (%d entry/entries):", locKey(w.x, w.y, w.z), #w.items))
            local qty = buildQtyMap()
            local byCls = {}
            for _, it in ipairs(w.items) do
                local c = classOf(it)
                local rec = byCls[c]; if not rec then rec = { entries = 0, total = 0, water = isClothing(it) and waterOf(it) or nil }; byCls[c] = rec end
                rec.entries = rec.entries + 1
                rec.total = rec.total + (qty[fullName(it)] or 1)
            end
            for c, rec in pairs(byCls) do
                say(string.format("   %s  x%d total (%d entr%s)%s", c, rec.total, rec.entries,
                    rec.entries == 1 and "y" or "ies",
                    rec.water and string.format("  water=%.0f", rec.water) or ""))
            end
        end
    end
    if n == 0 then
        say("no '" .. tostring(cfg().dryerClass) .. "' with items found in your flag — put items in a wardrobe and stand near it")
        -- DIAGNOSTIC: dump every container owner class we CAN see (with item counts),
        -- so we can identify the real wardrobe class if our guess is wrong.
        say("-- diagnostic: container owner classes currently visible --")
        local owners = {}
        local items = FindAllOf("Item") or {}
        for i = 1, #items do
            local it = items[i]
            if isValid(it) then
                local pc = presClass(it)
                if pc and pc:find("InTheInventory", 1, true) then
                    local inv = pcs(function() return it._serverPresence._inventory end, nil)
                    local owner = inv and pcs(function() return inv:GetOwner() end, nil) or nil
                    if isValid(owner) then
                        local oc = classOf(owner) or "?"
                        owners[oc] = (owners[oc] or 0) + 1
                    end
                end
            end
        end
        local any = false
        for oc, cnt in pairs(owners) do any = true; say(string.format("   %dx items in owner: %s", cnt, oc)) end
        if not any then say("   (no container-held items visible at all — stand closer / contents may be virtualized)") end
    end
    say("recipe to activate: " .. CD.recipeStr() .. "   (put these in, then 'dryer activate')")
    if sf then sf:close(); CD.log("scan written to " .. scanFile) end
end

-- 'dryer check' — show your flag's wardrobes, recipe status, activation state.
-- Reports TOTAL clothing items seen + each one's water value (not just a wet
-- count) so "0 wet" caused by DRYING is distinguishable from "0 wet" caused by
-- the contents being invisible (0 clothing found). Also written to check.txt.
function CD.cmdCheck()
    local checkFile = CD.modDir and (CD.modDir .. [[\check.txt]]) or nil
    local cf = checkFile and io.open(checkFile, "w") or nil
    local say = function(s) CD.reply(s, true); if cf then cf:write(tostring(s) .. "\n") end end
    local function finish() if cf then cf:close() end end
    local baseId = currentFlagBaseId()
    if not baseId then say("stand in your flag to check its dryers"); finish(); return end
    local flag; for _, f in ipairs(collectFlags()) do if f.baseId == baseId then flag = f; break end end
    if not flag then say("couldn't resolve your flag"); finish(); return end
    local wardrobes = collectWardrobes()
    local n = 0
    for _, w in pairs(wardrobes) do
        if w.x and hdist(w.x, w.y, flag.x, flag.y) <= flag.radius then
            n = n + 1
            local lk = locKey(w.x, w.y, w.z)
            local activeStr = CD.dryers[lk] and "ACTIVE dryer" or "inactive wardrobe"
            local clothes, wet = 0, 0
            for _, it in ipairs(w.items) do
                if isClothing(it) then
                    clothes = clothes + 1
                    local wv = waterOf(it)
                    if wv > (cfg().dryThreshold or 1) then wet = wet + 1 end
                    say(string.format("   garment %s: water=%.0f %s", classOf(it) or "?", wv, wv > (cfg().dryThreshold or 1) and "WET" or "dry"))
                end
            end
            say(string.format("wardrobe @%s — %s, %d clothing item(s) seen, %d WET", lk, activeStr, clothes, wet))
            if not CD.dryers[lk] then
                local c, m = recipeMatch(w.items)
                if c then say("   recipe COMPLETE — 'dryer activate' to turn it on")
                else say("   recipe missing: " .. table.concat(m, ", ")) end
            end
        end
    end
    if n == 0 then say("no '" .. tostring(cfg().dryerClass) .. "' with items in your flag") end
    finish()
end

-- 'dryer activate' — consume the recipe from a wardrobe in your flag, mark it active.
function CD.cmdActivate()
    local baseId = currentFlagBaseId()
    if not baseId then CD.reply("stand in your flag near the wardrobe, then 'dryer activate'"); return end
    CD.ensureResolved(false)
    if not flagEnabledForIssuer(baseId) then replyNotEnabled(); return end
    local flag; for _, f in ipairs(collectFlags()) do if f.baseId == baseId then flag = f; break end end
    if not flag then CD.reply("couldn't resolve your flag"); return end

    local chosen, consume, lastMissing
    for _, w in pairs(collectWardrobes()) do
        if w.x and hdist(w.x, w.y, flag.x, flag.y) <= flag.radius then
            local lk = locKey(w.x, w.y, w.z)
            if not CD.dryers[lk] then
                local c, m = recipeMatch(w.items)
                if c then chosen, consume = w, c; break else lastMissing = m end
            end
        end
    end
    if not chosen then
        if lastMissing then CD.reply("recipe incomplete — missing: " .. table.concat(lastMissing, ", "))
        else CD.reply("no inactive wardrobe with items in your flag. Put the recipe in one: " .. CD.recipeStr()) end
        return
    end
    local removed = 0
    for _, it in ipairs(consume) do if consumeItem(nil, it) then removed = removed + 1 end end
    local lk = locKey(chosen.x, chosen.y, chosen.z)
    CD.dryers[lk] = baseId
    CD.saveDryers()
    CD.log(string.format("activated dryer @%s base %s, consumed %d/%d entr(ies): %s", lk, tostring(baseId), removed, #consume, CD.recipeStr()))
    CD.reply("DRYER ACTIVATED — consumed " .. CD.recipeStr() .. ". Wet clothes left in it now dry automatically.")
end

-- 'dryer deactivate' — turn off the active dryer(s) in your flag (no refund).
-- Works off the persisted store (locKey -> baseId), NOT the world: an active
-- dryer that's empty or unloaded won't appear in collectWardrobes() but is still
-- in CD.dryers, so match by your current flag's baseId.
function CD.cmdDeactivate()
    local baseId = currentFlagBaseId()
    if not baseId then CD.reply("stand in your flag, then 'dryer deactivate'"); return end
    CD.ensureResolved(false)
    if not flagEnabledForIssuer(baseId) then replyNotEnabled(); return end
    local off = 0
    for lk, bid in pairs(CD.dryers) do
        if bid == baseId then CD.dryers[lk] = nil; off = off + 1 end
    end
    if off > 0 then CD.saveDryers(); CD.reply(string.format("deactivated %d dryer(s) in your flag (ingredients NOT refunded)", off))
    else CD.reply("no active dryer found in your flag (it must be in the flag you're standing in)") end
end

-- ---- help + dispatch ---------------------------------------------------------
local function helpLines(includeAdmin)
    local sec = math.floor((cfg().dryIntervalMs or 4000) / 1000)
    local h = {
        "ClothesDryer — turn an Improvised Wardrobe into a powered clothes dryer.",
        "Put " .. CD.recipeStr() .. " in a wardrobe in your flag, then 'dryer activate'.",
        "Wet clothes left in an active dryer dry automatically (every " .. sec .. "s). Commands:",
        "  dryer            — this help",
        "  dryer scan       — list item classes in your flag's wardrobe(s) (to set recipe)",
        "  dryer check      — show your wardrobes, recipe status, active dryers",
        "  dryer activate   — consume the recipe in your wardrobe, make it a dryer",
        "  dryer now        — run a dry cycle immediately",
        "  dryer deactivate — turn off your dryer(s)",
    }
    if includeAdmin then
        h[#h + 1] = "  -- admin --"
        h[#h + 1] = "  dryer reload     — reload Config.lua"
        h[#h + 1] = "  dryer pause-all / resume-all — stop / resume drying server-wide"
        if cfg().entitlementsEnabled then
            h[#h + 1] = "  -- admin: access control (per player; per flag = fallback) --"
            h[#h + 1] = "  dryer list / status — enabled players + overrides / summary"
            h[#h + 1] = "  dryer add/remove <player> — enable / disable a player"
            h[#h + 1] = "  dryer flag on|off|clear [baseId] — per-flag override"
            h[#h + 1] = "  dryer default on|off — default-enable every flag, or none"
            h[#h + 1] = "  dryer get-access-msg / set-access-msg <text|default|off|reset>"
            h[#h + 1] = "  dryer set-sqlite <path to sqlite3.exe | sqlite3.exe | off> — location of sqlite3.exe (for add/remove)"
        end
    end
    return h
end
function CD.replyHelp() for _, l in ipairs(helpLines(CD.callerIsAdmin == true)) do CD.reply(l, true) end end

local USER_CMDS = { [""] = true, scan = true, check = true, activate = true, now = true, deactivate = true }

function CD.handleCommand(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local word = (arg == "") and "" or (arg:match("^(%S+)") or "")
    if not USER_CMDS[word] and (cfg().requireAdmin ~= false) and not CD.callerIsAdmin then
        CD.reply("'dryer " .. word .. "' is admin-only"); return
    end
    if arg == "" then CD.replyHelp()
    elseif arg == "scan" then pcall(CD.cmdScan)
    elseif arg == "check" then pcall(CD.cmdCheck)
    elseif arg == "activate" then pcall(CD.cmdActivate)
    elseif arg == "deactivate" then pcall(CD.cmdDeactivate)
    elseif arg == "now" then
        local _, d = CD.dryCycle()
        CD.reply(string.format("ran a dry cycle — dried %d garment(s)", d or 0))
    elseif arg == "reload" then
        if CD.reload and CD.reload() then CD.reply("reloaded Config.lua") else CD.reply("reload FAILED (see log)") end
    elseif arg == "pause-all" then CD.enabled = false; CD.reply("drying paused server-wide")
    elseif arg == "resume-all" then CD.enabled = true; CD.reply("drying resumed server-wide")
    elseif arg == "list" then CD.cmdList()
    elseif arg == "status" then CD.cmdStatus()
    elseif arg:sub(1, 4) == "add " then local who = trim(arg:sub(5)); if who == "" then CD.reply("usage: dryer add <player>") else CD.cmdAdd(who) end
    elseif arg:sub(1, 7) == "remove " then local who = trim(arg:sub(8)); if who == "" then CD.reply("usage: dryer remove <player>") else CD.cmdRemove(who) end
    elseif arg == "flag" or arg:sub(1, 5) == "flag " then CD.handleFlagCmd(trim(arg:sub(5)))
    elseif arg:sub(1, 8) == "default " then local m = trim(arg:sub(9)):lower(); if m ~= "on" and m ~= "off" then CD.reply("usage: dryer default on|off") else CD.cmdDefault(m) end
    elseif arg == "get-access-msg" then CD.cmdGetAccessMsg()
    elseif arg == "set-access-msg" or arg:sub(1, 15) == "set-access-msg " then CD.cmdSetAccessMsg(arg:sub(16))
    elseif arg == "get-sqlite" then CD.cmdGetSqlite()
    elseif arg == "set-sqlite" or arg:sub(1, 11) == "set-sqlite " then CD.cmdSetSqlite(arg:sub(12))
    else CD.reply("Command unrecognised: '" .. arg .. "'  — type 'dryer' for the list") end
end

CD.log("dryer.lua loaded (engine ready; dryerClass=" .. tostring(cfg().dryerClass) .. ").")
