-- washer.lua — WashingMachine's mod-specific engine. The shared gating layer
-- (helpers, world enumeration, SCUM.db, entitlement store/resolution, access
-- commands, chat reply/onChatMessage) is installed onto WM by the shared library
-- (main.lua -> gating.lua) BEFORE this file loads. Here we keep only what's
-- specific to WashingMachine: wardrobe collection, the activation recipe
-- (match + consume), the WASH action, activation persistence, help, dispatch.
--
-- Unlike the dryer (a timed loop), washing is INSTANT + command-triggered
-- ('washer wash'): the player stands by an activated washer holding a FULL water
-- bucket, with a full bar of soap + dirty clothes inside; the wash cleans the
-- clothes (SetDirtiness 0), leaves them damp (SetWaterWeight 5%), consumes the
-- soap (DestroyInternal), and empties the held bucket.

WashingMachine = WashingMachine or {}
local WM = WashingMachine

-- shared helpers installed by gating.attach
local pcs, isValid, classOf, fullName, presClass = WM.pcs, WM.isValid, WM.classOf, WM.fullName, WM.presClass
local actorLoc, hdist, trim = WM.actorLoc, WM.hdist, WM.trim
local collectFlags, flagFor, findIUC = WM.collectFlags, WM.flagFor, WM.findIUC
local currentFlagBaseId = WM.currentFlagBaseId
local flagEnabled, flagEnabledForIssuer = WM.flagEnabled, WM.flagEnabledForIssuer
local replyNotEnabled = WM.replyNotEnabled

local function cfg() return WM.config or {} end

-- ---- clothing (AClothesItem) — wash levers -----------------------------------
local CLOTHESITEM = pcs(function() return StaticFindObject("/Script/SCUM.ClothesItem") end, nil)
local function isClothing(it)
    if not pcs(function() return it:IsA(CLOTHESITEM) end, false) then return false end
    return (pcs(function() return it:GetMaxPossibleWaterWeight() end, 0) or 0) > 0  -- max>0 skips ghost dupes
end
-- dirtiness has no getter; read the replicated field directly (safe scalar read).
local function dirtinessOf(it) return tonumber(pcs(function() return it._dirtiness end, 0)) or 0 end
-- clean + leave damp (proven 2026-06-04/05).
local function washItem(it)
    local maxw = tonumber(pcs(function() return it:GetMaxPossibleWaterWeight() end, 0)) or 0
    local damp = maxw * (cfg().dampFraction or 0.05)
    local ok = pcall(function() it:SetDirtiness(0.0) end)
    pcall(function() it:SetWaterWeight(damp) end)
    return ok
end

-- ---- component-quantity maps (read via the component, mapped back via GetOwner) ----
-- Item COMPONENTS can't be iterated from an item (crashes, gotcha #16), but
-- enumerating a component CLASS and reading its GetOwner() is a different, safe
-- path. Build map: item fullName -> quantity, for any *quantity* component class.
local function qtyMapFor(compClass)
    local m = {}
    local comps = pcs(function() return FindAllOf(compClass) end, nil)
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
local function buildQtyMap() return qtyMapFor("StackableItemComponent") end  -- stacks (recipe counting)
local function soapUsageMap() return qtyMapFor("DiscreteUsageItemComponent") end  -- soap bar usage (~100 = full)

-- map item fullName -> its UBasicGameResourceContainerComponent (bucket water).
-- _repResourceAmount holds the liquid amount (~9.99 = a full bucket). PASS 57.
local function bucketCompMap()
    local m = {}
    local comps = pcs(function() return FindAllOf("BasicGameResourceContainerComponent") end, nil)
    if not comps then return m end
    for i = 1, #comps do
        local c = comps[i]
        if isValid(c) then
            local owner = pcs(function() return c:GetOwner() end, nil)
            local fn = isValid(owner) and fullName(owner) or nil
            if fn and not m[fn] then m[fn] = c end
        end
    end
    return m
end

-- the chat issuer's pawn (for the HELD bucket). Same route the lib uses.
local function callerPawn()
    local ctrl = WM.controller
    if not ctrl then return nil end
    local p = pcs(function() return ctrl:K2_GetPawn() end, nil)
    if not isValid(p) then p = pcs(function() return ctrl.Pawn end, nil) end
    return isValid(p) and p or nil
end

-- returns (held, comp, amount) if the issuer holds a full water bucket, else
-- (nil, reason). The bucket MUST be held — buckets auto-empty in containers.
local function heldFullBucket()
    local pawn = callerPawn()
    if not pawn then return nil, "couldn't find your character" end
    local held = pcs(function() return pawn:GetItemInHands() end, nil)
    if not isValid(held) then return nil, "hold a FULL water bucket in your hands, then 'washer wash'" end
    if classOf(held) ~= cfg().bucketClass then
        return nil, "you're holding a " .. tostring(classOf(held)) .. ", not a water bucket"
    end
    local comp = bucketCompMap()[fullName(held)]
    local amt = comp and tonumber(pcs(function() return comp._repResourceAmount end, nil)) or nil
    if not comp or not amt then return nil, "couldn't read the held bucket's water level" end
    if amt < (cfg().bucketFullAmount or 9.0) then
        return nil, string.format("your bucket isn't full enough (%.1f) — fill it first", amt)
    end
    return held, comp, amt
end
local function emptyBucket(comp)
    pcall(function() comp._repResourceAmount = 0.0 end)
    pcall(function() comp:OnRep_ResourceAmount() end)
end

-- ---- wardrobe collection (owner == washerClass), keeps owner + location -------
local function collectWardrobes()
    local want = cfg().washerClass
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
                        -- duplicates of the same item (observed: activation reported
                        -- "8/8 consumed" from 6 real entries, leaving a real hose
                        -- because a ghost's DestroyInternal no-ops but pcall-succeeds).
                        -- Keeping one ref per fullName makes scan/check/recipe exact.
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

-- stable id for a (static) wardrobe = its location on a 10cm grid.
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
WM.washers = WM.washers or {}

function WM.loadWashers()
    WM.washers = {}
    local f = WM.washersFile and io.open(WM.washersFile, "r") or nil
    if not f then return end
    local src = f:read("*a"); f:close()
    local chunk = load(src, "@washers"); if not chunk then return end
    local ok, t = pcall(chunk)
    if ok and type(t) == "table" and type(t.activated) == "table" then
        for k, v in pairs(t.activated) do
            if type(k) == "string" then WM.washers[k] = math.tointeger(tonumber(v)) or true end
        end
    end
end

function WM.saveWashers()
    local f = WM.washersFile and io.open(WM.washersFile, "w") or nil
    if not f then WM.log("could not write washers file: " .. tostring(WM.washersFile)); return false end
    f:write("-- active washers (wardrobe locKey -> baseId). Written by 'washer activate'.\n")
    f:write("return {\n  activated = {\n")
    local keys = {}; for k in pairs(WM.washers) do keys[#keys + 1] = k end; table.sort(keys)
    for _, k in ipairs(keys) do
        local v = WM.washers[k]
        f:write(string.format("    [%q] = %s,\n", k, type(v) == "number" and tostring(v) or "true"))
    end
    f:write("  },\n}\n")
    f:close()
    return true
end

-- ---- recipe (match + consume) ------------------------------------------------
function WM.recipeStr()
    local parts = {}
    for _, ing in ipairs(cfg().recipe or {}) do parts[#parts + 1] = string.format("%dx %s", ing.count or 1, ing.name or ing.classes[1]) end
    return table.concat(parts, " + ")
end

-- returns (consumeList) if the wardrobe's items satisfy the recipe, else
-- (nil, missingList). Counting is by TOTAL stack quantity; consumption removes
-- WHOLE entries smallest-stack-first to minimise waste.
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
        local cand = {}
        for _, cls in ipairs(ing.classes or {}) do
            for _, e in ipairs(pool[cls] or {}) do cand[#cand + 1] = e end
        end
        table.sort(cand, function(a, b) return a.q < b.q end)
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

-- permanently consume an item entry by destroying it IN PLACE (proven 2026-06-04).
-- Async — isValid() still reads true the same frame — so count success by the call.
local function consumeItem(item)
    if not isValid(item) then return false end
    return (pcall(function() item:DestroyInternal() end))
end

-- ---- the wash action ---------------------------------------------------------
-- 'washer wash' — clean + dampen the dirty clothes in your active washer, consume
-- one full bar of soap from it, and empty your held full water bucket.
function WM.cmdWash()
    local baseId = currentFlagBaseId()
    if not baseId then WM.reply("stand in your flag near the washer (holding a full water bucket), then 'washer wash'"); return end
    WM.ensureResolved(false)
    if not flagEnabledForIssuer(baseId) then replyNotEnabled(); return end
    local flag; for _, f in ipairs(collectFlags()) do if f.baseId == baseId then flag = f; break end end
    if not flag then WM.reply("couldn't resolve your flag"); return end

    -- 1) an ACTIVE washer in this flag the player is loaded near
    local chosen
    local range = cfg().washLoadedRangeCm or 20000
    for _, w in pairs(collectWardrobes()) do
        if w.x and hdist(w.x, w.y, flag.x, flag.y) <= flag.radius then
            local lk = locKey(w.x, w.y, w.z)
            if WM.washers[lk] then
                local _, dist = nearestPawn(w.x, w.y)
                if dist and dist <= range then chosen = w; break end
            end
        end
    end
    if not chosen then WM.reply("no ACTIVE washer with items found near you in your flag ('washer activate' first)"); return end

    -- 2) held full water bucket  (held=nil on failure, with the reason in 2nd slot)
    local held, bucketComp, amt = heldFullBucket()
    if not held then WM.reply(bucketComp or "hold a full water bucket"); return end

    -- 3) a full bar of soap inside the washer
    local usage = soapUsageMap()
    local soap
    for _, it in ipairs(chosen.items) do
        if classOf(it) == cfg().soapClass then
            local u = tonumber(usage[fullName(it)] or 0) or 0
            if u >= (cfg().soapFullUsage or 90) then soap = it; break end
        end
    end
    if not soap then WM.reply("put a FULL bar of " .. tostring(cfg().soapClass) .. " in the washer"); return end

    -- 4) the dirty clothes inside the washer
    local dirty = {}
    for _, it in ipairs(chosen.items) do
        if isClothing(it) and dirtinessOf(it) > (cfg().dirtThreshold or 0.05) then dirty[#dirty + 1] = it end
    end
    if #dirty == 0 then WM.reply("no dirty clothes in the washer — put some in (and they must be dirty)"); return end

    -- 5) DO IT: wash each garment, consume the soap, empty the bucket
    local washed = 0
    for _, it in ipairs(dirty) do if washItem(it) then washed = washed + 1 end end
    consumeItem(soap)
    emptyBucket(bucketComp)

    WM.log(string.format("wash @%s base %s: washed %d garment(s), consumed 1 soap, emptied bucket (%.1f)",
        locKey(chosen.x, chosen.y, chosen.z), tostring(baseId), washed, amt or 0))
    WM.reply(string.format("WASHED %d garment(s) — now clean + damp. Used 1 bar of soap and your bucket of water.", washed))
end

-- ---- user commands -----------------------------------------------------------
-- 'washer scan' — dump the classes of items in the wardrobe(s) in your flag (to
-- lock recipe class names — especially the HOSE). Also written to scan.txt.
function WM.cmdScan()
    local scanFile = WM.modDir and (WM.modDir .. [[\scan.txt]]) or nil
    local sf = scanFile and io.open(scanFile, "w") or nil
    local say = function(s) WM.reply(s, true); if sf then sf:write(tostring(s) .. "\n") end end
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
                local rec = byCls[c]; if not rec then rec = { entries = 0, total = 0, dirt = isClothing(it) and dirtinessOf(it) or nil }; byCls[c] = rec end
                rec.entries = rec.entries + 1
                rec.total = rec.total + (qty[fullName(it)] or 1)
            end
            for c, rec in pairs(byCls) do
                say(string.format("   %s  x%d total (%d entr%s)%s", c, rec.total, rec.entries,
                    rec.entries == 1 and "y" or "ies",
                    rec.dirt and string.format("  dirt=%.2f", rec.dirt) or ""))
            end
        end
    end
    if n == 0 then
        say("no '" .. tostring(cfg().washerClass) .. "' with items found in your flag — put items in a wardrobe and stand near it")
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
                    if isValid(owner) then local oc = classOf(owner) or "?"; owners[oc] = (owners[oc] or 0) + 1 end
                end
            end
        end
        local any = false
        for oc, cnt in pairs(owners) do any = true; say(string.format("   %dx items in owner: %s", cnt, oc)) end
        if not any then say("   (no container-held items visible at all — stand closer / contents may be virtualized)") end
    end
    say("recipe to activate: " .. WM.recipeStr() .. "   (put these in, then 'washer activate')")
    if sf then sf:close(); WM.log("scan written to " .. scanFile) end
end

-- 'washer check' — your flag's wardrobes, recipe/activation status, each
-- garment's dirtiness, soap present?, held-bucket state. Also written to check.txt.
function WM.cmdCheck()
    local checkFile = WM.modDir and (WM.modDir .. [[\check.txt]]) or nil
    local cf = checkFile and io.open(checkFile, "w") or nil
    local say = function(s) WM.reply(s, true); if cf then cf:write(tostring(s) .. "\n") end end
    local function finish() if cf then cf:close() end end
    local baseId = currentFlagBaseId()
    if not baseId then say("stand in your flag to check its washers"); finish(); return end
    local flag; for _, f in ipairs(collectFlags()) do if f.baseId == baseId then flag = f; break end end
    if not flag then say("couldn't resolve your flag"); finish(); return end
    local usage = soapUsageMap()
    local wardrobes = collectWardrobes()
    local n = 0
    for _, w in pairs(wardrobes) do
        if w.x and hdist(w.x, w.y, flag.x, flag.y) <= flag.radius then
            n = n + 1
            local lk = locKey(w.x, w.y, w.z)
            local activeStr = WM.washers[lk] and "ACTIVE washer" or "inactive wardrobe"
            local clothes, dirty, soap = 0, 0, false
            for _, it in ipairs(w.items) do
                if isClothing(it) then
                    clothes = clothes + 1
                    local dv = dirtinessOf(it)
                    if dv > (cfg().dirtThreshold or 0.05) then dirty = dirty + 1 end
                    say(string.format("   garment %s: dirt=%.2f %s", classOf(it) or "?", dv, dv > (cfg().dirtThreshold or 0.05) and "DIRTY" or "clean"))
                elseif classOf(it) == cfg().soapClass then
                    local u = tonumber(usage[fullName(it)] or 0) or 0
                    if u >= (cfg().soapFullUsage or 90) then soap = true end
                    say(string.format("   soap %s: usage=%d %s", classOf(it), u, u >= (cfg().soapFullUsage or 90) and "(full bar)" or "(not full)"))
                end
            end
            say(string.format("wardrobe @%s — %s, %d clothing (%d DIRTY), soap=%s", lk, activeStr, clothes, dirty, soap and "yes" or "no"))
            if not WM.washers[lk] then
                local c, m = recipeMatch(w.items)
                if c then say("   recipe COMPLETE — 'washer activate' to turn it on")
                else say("   recipe missing: " .. table.concat(m, ", ")) end
            end
        end
    end
    if n == 0 then say("no '" .. tostring(cfg().washerClass) .. "' with items in your flag") end
    -- held bucket status (handy before washing); held=nil on failure, reason in 2nd slot
    local hb, hbReasonOrComp, hbAmt = heldFullBucket()
    if hb then say(string.format("held bucket: FULL (%.1f) — ready", hbAmt))
    else say("held bucket: " .. tostring(hbReasonOrComp)) end
    finish()
end

-- 'washer activate' — consume the recipe from a wardrobe in your flag, mark it active.
function WM.cmdActivate()
    local baseId = currentFlagBaseId()
    if not baseId then WM.reply("stand in your flag near the wardrobe, then 'washer activate'"); return end
    WM.ensureResolved(false)
    if not flagEnabledForIssuer(baseId) then replyNotEnabled(); return end
    local flag; for _, f in ipairs(collectFlags()) do if f.baseId == baseId then flag = f; break end end
    if not flag then WM.reply("couldn't resolve your flag"); return end

    local chosen, consume, lastMissing
    for _, w in pairs(collectWardrobes()) do
        if w.x and hdist(w.x, w.y, flag.x, flag.y) <= flag.radius then
            local lk = locKey(w.x, w.y, w.z)
            if not WM.washers[lk] then
                local c, m = recipeMatch(w.items)
                if c then chosen, consume = w, c; break else lastMissing = m end
            end
        end
    end
    if not chosen then
        if lastMissing then WM.reply("recipe incomplete — missing: " .. table.concat(lastMissing, ", "))
        else WM.reply("no inactive wardrobe with items in your flag. Put the recipe in one: " .. WM.recipeStr()) end
        return
    end
    local removed = 0
    for _, it in ipairs(consume) do if consumeItem(it) then removed = removed + 1 end end
    local lk = locKey(chosen.x, chosen.y, chosen.z)
    WM.washers[lk] = baseId
    WM.saveWashers()
    WM.log(string.format("activated washer @%s base %s, consumed %d/%d entr(ies): %s", lk, tostring(baseId), removed, #consume, WM.recipeStr()))
    WM.reply("WASHER ACTIVATED — consumed " .. WM.recipeStr() .. ". Put soap + dirty clothes in it, hold a full bucket, then 'washer wash'.")
end

-- 'washer deactivate' — turn off the active washer(s) in your flag (no refund).
-- Works off the persisted store (locKey -> baseId), NOT the world: an active
-- washer that's empty or unloaded won't appear in collectWardrobes() but is still
-- in WM.washers, so match by your current flag's baseId.
function WM.cmdDeactivate()
    local baseId = currentFlagBaseId()
    if not baseId then WM.reply("stand in your flag, then 'washer deactivate'"); return end
    WM.ensureResolved(false)
    if not flagEnabledForIssuer(baseId) then replyNotEnabled(); return end
    local off = 0
    for lk, bid in pairs(WM.washers) do
        if bid == baseId then WM.washers[lk] = nil; off = off + 1 end
    end
    if off > 0 then WM.saveWashers(); WM.reply(string.format("deactivated %d washer(s) in your flag (ingredients NOT refunded)", off))
    else WM.reply("no active washer found in your flag (it must be in the flag you're standing in)") end
end

-- ---- help + dispatch ---------------------------------------------------------
local function helpLines(includeAdmin)
    local h = {
        "WashingMachine — turn an Improvised Wardrobe into a washing machine.",
        "Put " .. WM.recipeStr() .. " in a wardrobe in your flag, then 'washer activate'.",
        "To wash: put a full bar of soap + dirty clothes in it, HOLD a full water bucket, 'washer wash'.",
        "  washer            — this help",
        "  washer scan       — list item classes in your flag's wardrobe(s) (to set recipe/find the hose)",
        "  washer check      — show your wardrobes, recipe status, dirtiness, soap, held bucket",
        "  washer activate   — consume the recipe in your wardrobe, make it a washer",
        "  washer wash       — wash the load (clean + damp), consume soap, empty held bucket",
        "  washer deactivate — turn off your washer(s)",
    }
    if includeAdmin then
        h[#h + 1] = "  -- admin --"
        h[#h + 1] = "  washer reload     — reload Config.lua"
        if cfg().entitlementsEnabled then
            h[#h + 1] = "  -- admin: access control (per player; per flag = fallback) --"
            h[#h + 1] = "  washer list / status — enabled players + overrides / summary"
            h[#h + 1] = "  washer add/remove <player> — enable / disable a player"
            h[#h + 1] = "  washer flag on|off|clear [baseId] — per-flag override"
            h[#h + 1] = "  washer default on|off — default-enable every flag, or none"
            h[#h + 1] = "  washer get-access-msg / set-access-msg <text|default|off|reset>"
            h[#h + 1] = "  washer set-sqlite <path to sqlite3.exe | sqlite3.exe | off> — location of sqlite3.exe (for add/remove)"
        end
    end
    return h
end
function WM.replyHelp() for _, l in ipairs(helpLines(WM.callerIsAdmin == true)) do WM.reply(l, true) end end

local USER_CMDS = { [""] = true, scan = true, check = true, activate = true, wash = true, deactivate = true }

function WM.handleCommand(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local word = (arg == "") and "" or (arg:match("^(%S+)") or "")
    if not USER_CMDS[word] and (cfg().requireAdmin ~= false) and not WM.callerIsAdmin then
        WM.reply("'washer " .. word .. "' is admin-only"); return
    end
    if arg == "" then WM.replyHelp()
    elseif arg == "scan" then pcall(WM.cmdScan)
    elseif arg == "check" then pcall(WM.cmdCheck)
    elseif arg == "activate" then pcall(WM.cmdActivate)
    elseif arg == "deactivate" then pcall(WM.cmdDeactivate)
    elseif arg == "wash" then pcall(WM.cmdWash)
    elseif arg == "reload" then
        if WM.reload and WM.reload() then WM.reply("reloaded Config.lua") else WM.reply("reload FAILED (see log)") end
    elseif arg == "list" then WM.cmdList()
    elseif arg == "status" then WM.cmdStatus()
    elseif arg:sub(1, 4) == "add " then local who = trim(arg:sub(5)); if who == "" then WM.reply("usage: washer add <player>") else WM.cmdAdd(who) end
    elseif arg:sub(1, 7) == "remove " then local who = trim(arg:sub(8)); if who == "" then WM.reply("usage: washer remove <player>") else WM.cmdRemove(who) end
    elseif arg == "flag" or arg:sub(1, 5) == "flag " then WM.handleFlagCmd(trim(arg:sub(5)))
    elseif arg:sub(1, 8) == "default " then local m = trim(arg:sub(9)):lower(); if m ~= "on" and m ~= "off" then WM.reply("usage: washer default on|off") else WM.cmdDefault(m) end
    elseif arg == "get-access-msg" then WM.cmdGetAccessMsg()
    elseif arg == "set-access-msg" or arg:sub(1, 15) == "set-access-msg " then WM.cmdSetAccessMsg(arg:sub(16))
    elseif arg == "get-sqlite" then WM.cmdGetSqlite()
    elseif arg == "set-sqlite" or arg:sub(1, 11) == "set-sqlite " then WM.cmdSetSqlite(arg:sub(12))
    else WM.reply("Command unrecognised: '" .. arg .. "'  — type 'washer' for the list") end
end

WM.log("washer.lua loaded (engine ready; washerClass=" .. tostring(cfg().washerClass) .. ").")
