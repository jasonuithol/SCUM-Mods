-- upkeep.lua — FlagUpkeep's mod-specific engine. The shared gating layer
-- (helpers, world enumeration, SCUM.db, entitlement store/resolution, access
-- commands, chat reply/onChatMessage) is installed onto FU by the shared library
-- (see main.lua -> gating.lua) BEFORE this file loads. Here we keep only what's
-- specific to FlagUpkeep: repair points (deposit/spend), the repair action, the
-- per-flag trigger, help text, and command dispatch.

FlagUpkeep = FlagUpkeep or {}
local FU = FlagUpkeep

-- shared helpers installed by gating.attach (aliased for brevity)
local pcs, isValid, classOf, fullName = FU.pcs, FU.isValid, FU.classOf, FU.fullName
local actorLoc, hdist, trim, nameMatches = FU.actorLoc, FU.hdist, FU.trim, FU.nameMatches
local collectFlags, collectChests = FU.collectFlags, FU.collectChests
local collectContainerContents, flagFor = FU.collectContainerContents, FU.flagFor
local findIUC = FU.findIUC
local currentFlagBaseId = FU.currentFlagBaseId
local flagEnabled, flagEnabledForIssuer = FU.flagEnabled, FU.flagEnabledForIssuer
local replyNotEnabled = FU.replyNotEnabled

-- ---- toolboxes, trigger, containers --------------------------------------

-- exact-class match against config.toolkitClasses (charges read live per item)
local function isToolkit(cls)
    for _, k in ipairs(FU.config.toolkitClasses or {}) do
        if cls == k then return true end
    end
    return false
end

-- the repair-trigger threshold for a base: per-flag override else global default.
local function triggerFor(baseId)
    local s = FU.store
    local f = s and s.triggerOverrides and baseId ~= nil and s.triggerOverrides[baseId]
    if type(f) == "number" then return f end
    return FU.config.repairBelowFraction or 0.90
end

-- format a health fraction as a clean percent string WITHOUT misleading rounding:
-- 0.995 -> "99.5" (not "100"), 0.90 -> "90", 0.99955 -> "99.96". (%.0f rounds 99.5
-- up to 100, which made a 99.5% trigger look like 100% — confusing.)
local function pctStr(frac)
    local p = (tonumber(frac) or 0) * 100
    local r = math.floor(p + 0.5)
    if math.abs(p - r) < 1e-9 then return string.format("%d", r) end
    return (string.format("%.2f", p):gsub("0+$", ""):gsub("%.$", ""))
end

-- the FlagUpkeep container(s) inside one flag (chests named config.containerName)
local function upkeepContainersIn(flag, chests)
    local out = {}
    for _, c in ipairs(chests) do
        if c.name and c.x and hdist(c.x, c.y, flag.x, flag.y) <= flag.radius
            and nameMatches(FU.config.containerName, c.name) then
            out[#out + 1] = c
        end
    end
    return out
end

-- toolbox item actors inside a set of containers (live items only)
local function toolkitsIn(containers, contentsMap)
    local out = {}
    for _, c in ipairs(containers) do
        local rec = c.owner and contentsMap[fullName(c.owner)] or nil
        if rec then
            for _, it in ipairs(rec.items) do
                if isToolkit(classOf(it)) then out[#out + 1] = it end
            end
        end
    end
    return out
end

-- ---- charges (toolbox _repQuantity), read off the LIVE item ---------------
local DUC = pcs(function() return StaticFindObject("/Script/SCUM.DiscreteUsageItemComponent") end, nil)
local function chargeCompOf(item)
    if not DUC then return nil end
    local c = pcs(function() return item:GetComponentByClass(DUC) end, nil)
    return isValid(c) and c or nil
end
local function chargesOf(item)
    local c = chargeCompOf(item)
    if not c then return 0 end
    return math.tointeger(tonumber(pcs(function() return c._repQuantity end, 0))) or 0
end

-- PERMANENTLY remove a toolbox from its chest (persisted), via the inventory RPC.
-- K2_DestroyActor only drops the actor in-memory — the item returns on relog — so
-- we use Server_InventoryComponent_RemoveEntry (same family as AddOrMoveEntry,
-- which the loot-sorter proves persists). Returns ok.
local function consumeFromChest(iuc, item)
    local inv = pcs(function() return item._serverPresence._inventory end, nil)
    if not (iuc and isValid(inv)) then return false end
    return (pcall(function() iuc:Server_InventoryComponent_RemoveEntry(inv, item) end))
end

-- ---- repair primitive + damaged-element source ---------------------------
local REPAIR_INTERACTION = 170      -- EInteractionType.RepairBaseElement
local REPAIR_VALUE_FULL  = 100000.0 -- large -> game clamps the element to full HP
-- CONSTANT SQL (base_id/threshold filtered in Lua => zero injection)
local DAMAGED_SQL = "SELECT base_id, element_id, location_x, location_y, location_z, element_health FROM base_element WHERE element_health < 1.0;"
local ALL_ELEMENTS_SQL = "SELECT base_id, element_id, location_x, location_y, location_z FROM base_element;"

function FU.nextDataVersion()
    FU.dataVersion = (FU.dataVersion or 1000) + 1
    return FU.dataVersion
end

local function findManager()
    for _, n in ipairs({ "BP_ConZBaseManager_C", "ConZBaseManager" }) do
        local l = FindAllOf(n)
        if l then for i = 1, #l do if isValid(l[i]) then return l[i] end end end
    end
    return nil
end

-- the live player pawn NEAREST to (x,y); returns pawn, distCm (nil,nil if none live).
-- A repair multicast only lands when the base's elements are streamed in, which in
-- SCUM happens only with a player within range — so the nearest pawn doubles as the
-- "is this base loaded?" probe AND the interaction User.
local function nearestPawn(x, y)
    local best, bestd
    local l = FindAllOf("BP_Prisoner_C")
    if l then for i = 1, #l do
        local p = l[i]
        if isValid(p) then
            local px, py = actorLoc(p)
            if px then
                local d = hdist(px, py, x, y)
                if not bestd or d < bestd then best, bestd = p, d end
            end
        end
    end end
    return best, bestd
end

-- Elements the TEST damage tool hit but the DB hasn't flushed yet. Multicast HP
-- changes (our damage AND repair) only reach SCUM.db on a full/shutdown save — a
-- just-damaged element still reads full in the DB — so 'check'/'now' driven off the
-- DB alone would see nothing right after 'upkeep damage'. We track the damaged set
-- in memory so the test loop is immediate; each is cleared when repaired.
-- Keyed [baseId][elementId] = { id, x, y, z }.
FU.testDamaged = FU.testDamaged or {}

-- damaged elements grouped by base_id (below ITS trigger, weakest first) from the
-- save DB, PLUS any in-memory test-damaged elements (treated as fully damaged so
-- they always qualify, flagged .test). Used by both the cycle and 'upkeep check'.
local function fetchDamagedByBase()
    local rows, err = FU.dbRows(DAMAGED_SQL)
    if not rows then FU.log("upkeep: damaged-element DB read failed: " .. tostring(err)); return nil end
    local map, seen = {}, {}
    for _, r in ipairs(rows) do
        local bid = math.tointeger(tonumber(r[1]))
        local hp = tonumber(r[6]) or 1.0
        if bid and hp < triggerFor(bid) then
            local id = math.tointeger(tonumber(r[2]))
            local rec = map[bid]; if not rec then rec = {}; map[bid] = rec end
            rec[#rec + 1] = { id = id, x = tonumber(r[3]), y = tonumber(r[4]), z = tonumber(r[5]), hp = hp }
            seen[bid] = seen[bid] or {}; if id then seen[bid][id] = true end
        end
    end
    for bid, els in pairs(FU.testDamaged) do
        for id, e in pairs(els) do
            if not (seen[bid] and seen[bid][id]) then
                local rec = map[bid]; if not rec then rec = {}; map[bid] = rec end
                rec[#rec + 1] = { id = id, x = e.x, y = e.y, z = e.z, hp = 0.0, test = true }
            end
        end
    end
    for _, rec in pairs(map) do table.sort(rec, function(a, b) return (a.hp or 1) < (b.hp or 1) end) end
    return map
end

-- repair ONE element to full via the game's own repair interaction. Returns ok.
local function repairElement(mgr, baseId, el, user)
    local baseData = { BaseId = baseId, BaseLocation = { X = el.x, Y = el.y, Z = el.z } }
    local elemData = {
        BaseElementId = el.id, GardenId = 0,
        BaseElementLocation = { X = el.x, Y = el.y, Z = el.z },
        RepairValue = REPAIR_VALUE_FULL, InteractionTimestamp = 0, IntegerData = 0,
    }
    return pcall(function()
        mgr:NetMulticast_InteractWithElement(FU.nextDataVersion(), REPAIR_INTERACTION, baseData, elemData, user)
    end)
end

-- TEST ONLY: damage one element by <amount> HP (unclamped — can destroy low-HP).
local function damageElement(mgr, baseId, el, amount)
    local loc = { X = el.x, Y = el.y, Z = el.z }
    return pcall(function()
        mgr:NetMulticast_ApplyDamageToBaseElement(FU.nextDataVersion(), baseId, el.id, loc, amount)
    end)
end

-- ---- repair points (per-flag balance in the store) -----------------------
local function pointsOf(baseId)
    return (FU.store and FU.store.repairPoints and baseId ~= nil and FU.store.repairPoints[baseId]) or 0
end

-- Repair a flag's damaged elements, spending repair points (1 point = 1 element).
-- Returns (repaired, pointsSpent, status) — status "notloaded" when skipped because
-- no player is within range (base not streamed in), else nil.
function FU.repairFlag(flag, damaged)
    if not FU.config.repairEnabled then return 0, 0 end
    if not damaged or #damaged == 0 then return 0, 0 end
    local mgr = findManager()
    if not mgr then FU.log("  repairFlag: no ConZBaseManager — skipping"); return 0, 0 end

    -- POINT-ACCOUNTING GUARD: a repair multicast only takes effect on a LOADED base
    -- (elements streamed in), which needs a player within range. With nobody near,
    -- the call no-ops and we'd burn points for an invisible non-repair. So require a
    -- nearby pawn — it's our best confirmable proxy for "the repair can land" — and
    -- pass it as the interaction User. No pawn in range => skip, spend nothing.
    local user, dist = nearestPawn(flag.x, flag.y)
    local range = FU.config.repairLoadedRangeCm or 20000
    if not user or (dist and dist > range) then
        FU.log(string.format("  base %s: no player within %dcm (base not loaded) — skipping, 0 points spent",
            tostring(flag.baseId), range))
        return 0, 0, "notloaded"
    end

    local needPts = FU.config.requireRepairPoints
    local bal = pointsOf(flag.baseId)
    if needPts and bal <= 0 then
        FU.log(string.format("  base %s: %d damaged but 0 repair points — 'upkeep deposit' toolboxes to top up",
            tostring(flag.baseId), #damaged))
        return 0, 0
    end

    FU.repairedAt = FU.repairedAt or {} -- elementId -> os.time() of last repair
    local cd = FU.config.repairCooldownSec or 300
    local now = os.time()
    local cap = FU.config.maxPointsPerCycle -- nil = no cap
    local repaired, spent, skipped = 0, 0, 0
    for _, el in ipairs(damaged) do
        if cap and repaired >= cap then break end
        if needPts and (bal - spent) <= 0 then break end
        if el.id and not el.test and FU.repairedAt[el.id] and (now - FU.repairedAt[el.id]) < cd then
            skipped = skipped + 1 -- repaired recently; DB health still catching up (test damage bypasses)
        else
            if repairElement(mgr, flag.baseId, el, user) then
                repaired = repaired + 1
                if el.id then
                    FU.repairedAt[el.id] = now
                    if FU.testDamaged[flag.baseId] then FU.testDamaged[flag.baseId][el.id] = nil end
                end
                if needPts then spent = spent + 1 end
                FU.log(string.format("  repaired element %s (was %s%%) in base %s",
                    tostring(el.id), pctStr(el.hp or 0), tostring(flag.baseId)))
            else
                FU.log(string.format("  ERROR repairing element %s in base %s", tostring(el.id), tostring(flag.baseId)))
            end
        end
    end
    if needPts and spent > 0 then
        FU.store.repairPoints[flag.baseId] = math.max(0, bal - spent)
        FU.saveStore()
    end
    if skipped > 0 then
        FU.log(string.format("  base %s: skipped %d recently-repaired element(s) (DB health still catching up)",
            tostring(flag.baseId), skipped))
    end
    if needPts then
        FU.log(string.format("  base %s: spent %d repair point(s), %d left", tostring(flag.baseId), spent, pointsOf(flag.baseId)))
    end
    return repaired, spent
end

-- ---- the upkeep cycle ----------------------------------------------------
function FU.upkeep(onlyBaseId)
    FU.ensureResolved(false)
    if not FU.store then FU.loadStore() end -- per-flag trigger overrides
    if FU.config.entitlementsEnabled and not FU.resolved then
        FU.log("upkeep: gate ON but no enabled set (DB read failed?) — NOT running (fail-closed).")
    end

    local flags, radius = collectFlags()
    if onlyBaseId then
        local only = {}
        for _, f in ipairs(flags) do if f.baseId == onlyBaseId then only[#only + 1] = f end end
        flags = only
    end
    if #flags == 0 then FU.log("upkeep: no flags found in world — skipping."); return "no flags found" end

    local damagedByBase = (FU.config.repairEnabled and fetchDamagedByBase()) or {}

    FU.log(string.format("upkeep start: %d flag(s), radius=%dcm%s%s", #flags, radius,
        FU.config.entitlementsEnabled and (" | gate ON (" ..
            (FU.resolved and FU.resolved.counts and FU.resolved.counts.enabled or 0) .. " base(s) enabled)") or " | gate OFF",
        FU.config.repairEnabled and "" or " | REPAIR DISABLED (report-only)"))

    local repaired, spent, kept, noPoints, disabled, clean, notLoaded = 0, 0, 0, 0, 0, 0, 0
    for _, flag in ipairs(flags) do
        if not flagEnabled(flag) then
            disabled = disabled + 1
        else
            local damaged = damagedByBase[flag.baseId] or {}
            if not FU.config.repairEnabled then
                if #damaged == 0 then clean = clean + 1 else
                    FU.log(string.format("  base %s: %d element(s) below %s%% (repair disabled)",
                        tostring(flag.baseId), #damaged, pctStr(triggerFor(flag.baseId))))
                end
            elseif #damaged == 0 then
                clean = clean + 1
            elseif FU.config.requireRepairPoints and pointsOf(flag.baseId) <= 0 then
                noPoints = noPoints + 1
                FU.log(string.format("  base %s: %d damaged but 0 repair points — deposit toolboxes to top up",
                    tostring(flag.baseId), #damaged))
            else
                FU.log(string.format("  base %s: %d damaged element(s); %d repair point(s) available",
                    tostring(flag.baseId), #damaged, pointsOf(flag.baseId)))
                local r, c, st = FU.repairFlag(flag, damaged)
                repaired = repaired + (r or 0); spent = spent + (c or 0)
                if (r or 0) > 0 then kept = kept + 1 end
                if st == "notloaded" then notLoaded = notLoaded + 1 end
            end
        end
    end

    FU.log(string.format("upkeep done: serviced=%d  repaired=%d  points-spent=%d  | disabled=%d  no-points=%d  already-ok=%d  not-loaded=%d",
        kept, repaired, spent, disabled, noPoints, clean, notLoaded))
    local extra = FU.config.repairEnabled and "" or " [repair disabled]"
    if notLoaded > 0 then
        extra = extra .. string.format(" — %d base(s) skipped: not loaded (no one near; repair runs when someone's at the base, 0 points spent)", notLoaded)
    end
    return string.format("serviced %d base(s); repaired %d element(s); spent %d repair point(s)%s",
        kept, repaired, spent, extra)
end

-- ---- user commands: check, deposit, trigger, (admin) damage --------------
function FU.cmdCheck()
    local function say(s) FU.reply(s, true); FU.log("  [check] " .. s) end
    local ctrl = FU.controller
    local ax, ay
    if ctrl ~= nil then
        local pawn = pcs(function() return ctrl:K2_GetPawn() end, nil)
        if not isValid(pawn) then pawn = pcs(function() return ctrl.Pawn end, nil) end
        if isValid(pawn) then ax, ay = actorLoc(pawn) end
    end
    if not ax then say("couldn't get your location"); return end
    local flag = flagFor(ax, ay, collectFlags())
    if not flag then say("you're not in a flag zone"); return end

    if not FU.store then FU.loadStore() end
    local frac = triggerFor(flag.baseId)
    say(string.format("base %s: %d repair point(s) banked", tostring(flag.baseId), pointsOf(flag.baseId)))

    local containers = upkeepContainersIn(flag, collectChests())
    if #containers == 0 then
        say(string.format("no '%s' container (build a chest/wardrobe named exactly that to deposit toolboxes)", FU.config.containerName))
    else
        local tks = toolkitsIn(containers, collectContainerContents())
        local byCls, depositable = {}, 0
        for _, it in ipairs(tks) do
            local c = classOf(it); local ch = chargesOf(it)
            local rec = byCls[c]; if not rec then rec = { n = 0, ch = 0 }; byCls[c] = rec end
            rec.n = rec.n + 1; rec.ch = rec.ch + ch; depositable = depositable + ch
        end
        say(string.format("'%s' container: %d toolbox(es) = %d depositable point(s)", FU.config.containerName, #tks, depositable))
        for c, rec in pairs(byCls) do say(string.format("  %dx %s (%d pts)", rec.n, c, rec.ch)) end
        if depositable > 0 then say("  -> 'upkeep deposit' (with the chest OPEN) to bank them") end
        if #tks > 0 and depositable == 0 then say("  (these read 0 pts — already deposited, or open the chest to read them)") end
    end

    local map = fetchDamagedByBase()
    if map then
        local dmg = map[flag.baseId] or {}
        local n, nTest = #dmg, 0
        for _, e in ipairs(dmg) do if e.test then nTest = nTest + 1 end end
        if nTest > 0 then
            say(string.format("trigger=%s%% — %d element(s) below it (need %d point(s) to repair; %d test-damaged, not yet in DB)", pctStr(frac), n, n, nTest))
        else
            say(string.format("trigger=%s%% — %d element(s) below it (need %d point(s) to repair)", pctStr(frac), n, n))
        end
    end
    if not FU.config.repairEnabled then say("(repair is DISABLED in config — this is a report only)") end
end

-- 'upkeep deposit' — convert toolboxes in the (OPEN) container to repair points,
-- destroying them. A box reading 0 is left alone (never lose a full one).
function FU.cmdDeposit()
    if not FU.store then FU.loadStore() end
    FU.store.repairPoints = FU.store.repairPoints or {}
    local baseId = currentFlagBaseId()
    if not baseId then FU.reply("stand in your flag (chest OPEN), then 'upkeep deposit'"); return end
    FU.ensureResolved(false)
    if not flagEnabledForIssuer(baseId) then replyNotEnabled(); return end
    local flag
    for _, f in ipairs(collectFlags()) do if f.baseId == baseId then flag = f; break end end
    if not flag then FU.reply("couldn't resolve your flag"); return end
    local containers = upkeepContainersIn(flag, collectChests())
    if #containers == 0 then FU.reply(string.format("no '%s' container in your flag", FU.config.containerName)); return end
    local tks = toolkitsIn(containers, collectContainerContents())
    if #tks == 0 then FU.reply("no toolboxes in the container — put some in and make sure the chest is OPEN"); return end
    local iuc = findIUC()
    if not iuc then FU.reply("can't deposit right now (no inventory component live) — stay near the base and retry"); return end
    -- credit points ONLY for boxes we actually removed (no credit-then-box-survives dupe)
    local gained, banked, skipped = 0, 0, 0
    for _, it in ipairs(tks) do
        local ch = chargesOf(it)
        if ch > 0 and consumeFromChest(iuc, it) then
            gained = gained + ch; banked = banked + 1
        else
            skipped = skipped + 1 -- read 0 (chest not open) or couldn't be removed
        end
    end
    if gained > 0 then
        FU.store.repairPoints[baseId] = (FU.store.repairPoints[baseId] or 0) + gained
        FU.saveStore()
    end
    local bal = FU.store.repairPoints[baseId] or 0
    FU.log(string.format("deposit: base %d +%d point(s) from %d box(es) (%d skipped) -> %d total", baseId, gained, banked, skipped, bal))
    local msg = string.format("deposited %d repair point(s) from %d toolbox(es) — balance %d", gained, banked, bal)
    if skipped > 0 then msg = msg .. string.format("  (%d box(es) skipped — OPEN the chest and retry)", skipped) end
    FU.reply(msg)
end

-- 'upkeep trigger [percent|clear]' — per-flag repair health threshold.
function FU.cmdTrigger(arg)
    if not FU.store then FU.loadStore() end
    FU.store.triggerOverrides = FU.store.triggerOverrides or {}
    local baseId = currentFlagBaseId()
    if not baseId then FU.reply("stand in your flag, then 'upkeep trigger <percent>'"); return end
    FU.ensureResolved(false)
    if not flagEnabledForIssuer(baseId) then replyNotEnabled(); return end
    arg = trim(arg or ""):lower()
    if arg == "" then
        local cur = triggerFor(baseId)
        local src = FU.store.triggerOverrides[baseId] and "your setting" or "server default"
        FU.reply(string.format("base %d repair trigger = %s%% (%s). Set with 'upkeep trigger <1-100>' or 'clear'", baseId, pctStr(cur), src), true)
        return
    end
    if arg == "clear" then
        FU.store.triggerOverrides[baseId] = nil; FU.saveStore()
        FU.reply(string.format("base %d trigger cleared — using server default %s%%", baseId, pctStr(FU.config.repairBelowFraction or 0.90)))
        return
    end
    local pct = tonumber(arg:match("^(%d+%.?%d*)"))
    if not pct or pct <= 0 or pct > 100 then FU.reply("usage: upkeep trigger <1-100> | clear"); return end
    FU.store.triggerOverrides[baseId] = pct / 100; FU.saveStore()
    FU.reply(string.format("base %d repair trigger set to %.0f%% — elements below that get repaired", baseId, pct))
end

-- admin TEST tool (gated by config.allowTestDamage): damage every element in the flag.
function FU.cmdDamage(arg)
    if not (FU.config and FU.config.allowTestDamage) then
        FU.reply("test-damage is disabled — set allowTestDamage=true in Config.lua then 'upkeep reload'")
        return
    end
    local amount = tonumber((trim(arg or "")):match("^(%d+%.?%d*)")) or 50
    if amount <= 0 then amount = 50 end
    local baseId = currentFlagBaseId()
    if not baseId then FU.reply("stand in the flag whose elements you want to damage"); return end
    local mgr = findManager()
    if not mgr then FU.reply("no ConZBaseManager found"); return end
    local rows = FU.dbRows(ALL_ELEMENTS_SQL)
    if not rows then FU.reply("element DB read failed (see log)"); return end
    FU.testDamaged[baseId] = FU.testDamaged[baseId] or {}
    local n = 0
    for _, r in ipairs(rows) do
        if math.tointeger(tonumber(r[1])) == baseId then
            local el = { id = math.tointeger(tonumber(r[2])), x = tonumber(r[3]), y = tonumber(r[4]), z = tonumber(r[5]) }
            if el.id and damageElement(mgr, baseId, el, amount) then
                n = n + 1
                FU.testDamaged[baseId][el.id] = el -- track: multicast damage won't hit the DB until a full save
            end
        end
    end
    FU.log(string.format("TEST damage: base %d — %d element(s) by %.0f HP (tracked in-memory; DB lags until full save)", baseId, n, amount))
    FU.reply(string.format("TEST: damaged %d element(s) by %.0f HP — they now count as repairable immediately.", n, amount), true)
    FU.reply("Run 'upkeep check' to see them, then 'upkeep now' to repair (each clears as it's repaired).", true)
end

-- ---- help + command dispatch ---------------------------------------------
local function helpLines(includeAdmin)
    local sec = math.floor(((FU.config and FU.config.upkeepIntervalMs) or 3600000) / 1000)
    local h = {
        "FlagUpkeep — keeps your base elements repaired using REPAIR POINTS, banked",
        "from toolboxes you 'deposit' from a '" .. ((FU.config and FU.config.containerName) or "FlagUpkeep") .. "' chest in your flag.",
        "Runs automatically every " .. sec .. "s. Commands (type in normal chat):",
        "  upkeep              — show this help",
        "  upkeep deposit      — bank toolboxes in your OPEN container as repair points",
        "  upkeep check        — show repair points, depositable toolboxes + trigger",
        "  upkeep now          — run upkeep on your flag right now",
        "  upkeep trigger <%>  — repair elements once they drop below this health %",
        "  upkeep pause/resume — stop / resume auto-upkeep for your flag",
    }
    if includeAdmin then
        h[#h + 1] = "  -- admin --"
        h[#h + 1] = "  upkeep pause-all/resume-all — pause / resume auto-upkeep server-wide"
        h[#h + 1] = "  upkeep reload       — reload Config.lua, then run one cycle"
        if FU.config and FU.config.allowTestDamage then
            h[#h + 1] = "  upkeep damage [amt] — TEST: damage every element in your flag by <amt> HP"
        end
        if FU.config and FU.config.entitlementsEnabled then
            h[#h + 1] = "  -- admin: access control (per player; per flag = fallback) --"
            h[#h + 1] = "  upkeep list / status — enabled players + overrides / one-line summary"
            h[#h + 1] = "  upkeep add/remove <player> — enable / disable a player (name or Steam64)"
            h[#h + 1] = "  upkeep flag on|off|clear [baseId] — per-flag override (blank=your flag)"
            h[#h + 1] = "  upkeep default on|off — keep up every flag by default, or none"
            h[#h + 1] = "  upkeep get-access-msg / set-access-msg <text|default|off|reset>"
            h[#h + 1] = "  upkeep set-sqlite <path to sqlite3.exe | sqlite3.exe | off> — location of sqlite3.exe (for add/remove)"
        end
    end
    return h
end
local function printHelp() for _, l in ipairs(helpLines(true)) do FU.log(l) end end
function FU.replyHelp() for _, l in ipairs(helpLines(FU.callerIsAdmin == true)) do FU.reply(l, true) end end

local USER_CMDS = { [""] = true, check = true, deposit = true, now = true, pause = true, resume = true, trigger = true }

function FU.handleCommand(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local word = (arg == "") and "" or (arg:match("^(%S+)") or "")
    if not USER_CMDS[word] and (not FU.config or FU.config.requireAdmin ~= false) and not FU.callerIsAdmin then
        FU.log("ignored 'upkeep " .. arg .. "' — admin-only (sender not admin)")
        FU.reply("'upkeep " .. word .. "' is admin-only")
        return
    end
    if arg == "" then
        printHelp(); FU.replyHelp()
    elseif arg == "now" then
        local baseId = currentFlagBaseId()
        if FU.enabled == false then
            FU.reply("upkeep is paused server-wide (an admin ran 'upkeep pause-all')")
        elseif not baseId then
            FU.reply("stand in your flag, then 'upkeep now' to run it")
        else
            FU.ensureResolved(false)
            local gateOn = FU.config.entitlementsEnabled
            -- access via the gate function (honours override > player > GLOBAL DEFAULT),
            -- NOT the resolved owner set directly — default-on bases aren't in that set
            -- when sqlite is off (empty owner map). Same decision the timer uses.
            local access = (not gateOn) or flagEnabledForIssuer(baseId)
            local paused = FU.resolved and FU.resolved.paused and FU.resolved.paused[baseId]
            if access and not paused then
                FU.log("manual upkeep of base " .. baseId .. " (upkeep now)")
                local ok, s = pcall(FU.upkeep, baseId)
                FU.reply(ok and (s or "done") or "upkeep error (see log)")
            elseif access and paused then
                FU.reply("upkeep is paused for your base — 'upkeep resume' to turn it back on")
            else
                replyNotEnabled()
            end
        end
    elseif arg == "check" then
        FU.log("auditing upkeep container in your flag (upkeep check)")
        if type(FU.cmdCheck) == "function" then pcall(FU.cmdCheck) end
    elseif arg == "deposit" then
        FU.log("depositing toolboxes as repair points (upkeep deposit)")
        if type(FU.cmdDeposit) == "function" then pcall(FU.cmdDeposit) end
    elseif arg == "reload" then
        if FU.reload and FU.reload() then
            FU.log("reloaded; running one cycle")
            local ok, s = pcall(FU.upkeep)
            FU.reply("reloaded — " .. (ok and (s or "done") or "upkeep error"))
        else
            FU.reply("reload FAILED (see log)")
        end
    elseif arg == "pause" then
        FU.cmdPauseFlag(true)
    elseif arg == "resume" then
        FU.cmdPauseFlag(false)
    elseif arg == "trigger" or arg:sub(1, 8) == "trigger " then
        FU.cmdTrigger(arg:sub(9))
    elseif arg == "damage" or arg:sub(1, 7) == "damage " then
        FU.cmdDamage(arg:sub(8))
    elseif arg == "pause-all" then
        FU.enabled = false; FU.log("global auto-upkeep PAUSED (pause-all)"); FU.reply("auto-upkeep paused server-wide")
    elseif arg == "resume-all" then
        FU.enabled = true; FU.log("global auto-upkeep RESUMED (resume-all)"); FU.reply("auto-upkeep resumed server-wide")
    elseif arg == "list" then
        FU.log("entitlement list (upkeep list)"); FU.cmdList()
    elseif arg == "status" then
        FU.cmdStatus()
    elseif arg:sub(1, 4) == "add " then
        local who = trim(arg:sub(5))
        if who == "" then FU.reply("usage: upkeep add <player name or Steam64>") else FU.cmdAdd(who) end
    elseif arg:sub(1, 7) == "remove " then
        local who = trim(arg:sub(8))
        if who == "" then FU.reply("usage: upkeep remove <player name or Steam64>") else FU.cmdRemove(who) end
    elseif arg == "flag" or arg:sub(1, 5) == "flag " then
        FU.handleFlagCmd(trim(arg:sub(5)))
    elseif arg:sub(1, 8) == "default " then
        local m = trim(arg:sub(9)):lower()
        if m ~= "on" and m ~= "off" then FU.reply("usage: upkeep default on|off") else FU.cmdDefault(m) end
    elseif arg == "get-access-msg" then
        FU.cmdGetAccessMsg()
    elseif arg == "set-access-msg" or arg:sub(1, 15) == "set-access-msg " then
        FU.cmdSetAccessMsg(arg:sub(16))
    elseif arg == "get-sqlite" then
        FU.cmdGetSqlite()
    elseif arg == "set-sqlite" or arg:sub(1, 11) == "set-sqlite " then
        FU.cmdSetSqlite(arg:sub(12))
    else
        FU.log("unrecognised command 'upkeep " .. arg .. "'")
        FU.reply("Command unrecognised: '" .. arg .. "'")
        FU.reply("Type 'upkeep' for a list of valid commands")
    end
end

FU.log("upkeep.lua loaded (engine ready" .. (FU.config and FU.config.repairEnabled and "" or "; REPORT-ONLY, repair disabled") .. ").")
