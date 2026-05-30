-- upkeep.lua — FlagUpkeep engine. Defines FlagUpkeep.upkeep() and helpers.
-- Loaded (and hot-reloadable) by main.lua. Reads FlagUpkeep.config / .log.
-- Pure logic: no timers or hooks installed here.
--
-- The access-control / flag-scoping / DB / chat-command code below is
-- copy-adapted from GarbageGoober's sorter.lua (proven in production). The only
-- FlagUpkeep-specific logic is: find the "FlagUpkeep" container(s) in a flag,
-- read the toolkits inside, and repair the flag's base elements. The repair
-- PRIMITIVE is pending recon (see FU.repairFlag) — until config.repairEnabled is
-- true it is a non-destructive report.

FlagUpkeep = FlagUpkeep or {}
local FU = FlagUpkeep

-- ---- tiny safe-reflection helpers (proven in recon) ----------------------
local function pcs(fn, dflt) local ok, v = pcall(fn); if ok and v ~= nil then return v end; return dflt end
local function isValid(o) return o ~= nil and pcs(function() return o:IsValid() end, false) end
local function classOf(o) return pcs(function() return o:GetClass():GetFName():ToString() end, "?") end
-- stable per-UObject identity (unique object path); userdata identity is NOT
-- stable across separate FindAllOf passes, so use this to key/compare objects.
local function fullName(o) return pcs(function() return o:GetFullName() end, nil) end

local function presClass(it)
    local p = pcs(function() return it._serverPresence end, nil)
    if not isValid(p) then return nil end
    return classOf(p)
end

local function xyz(v)
    if not v then return nil end
    local x = pcs(function() return v.X end, nil)
    if not x then return nil end
    return x, pcs(function() return v.Y end, nil) or 0, pcs(function() return v.Z end, nil) or 0
end

local function presLoc(item)
    local p = pcs(function() return item._serverPresence end, nil)
    local d = p and pcs(function() return p.Data end, nil) or nil
    return xyz(d and pcs(function() return d.Location end, nil) or nil)
end

-- placed-actor world pos (flags, chests): the actor transform is authoritative;
-- fall back to floor presence if needed.
local function actorLoc(actor)
    local x, y, z = xyz(pcs(function() return actor:K2_GetActorLocation() end, nil))
    if x then return x, y, z end
    return presLoc(actor)
end

local function hdist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

local function findAllAny(...)
    for _, n in ipairs({ ... }) do
        local l = FindAllOf(n)
        if l and #l > 0 then return l end
    end
    return nil
end

local function trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
local function fstr(s)
    if type(s) == "string" then return s end
    if type(s) == "userdata" then return pcs(function() return s:ToString() end, nil) end
    return nil
end

-- ---- world enumeration ---------------------------------------------------

-- All flags: { {actor=, x=, y=, radius=, baseId=} }.  baseId comes from
-- ConZBaseManager._bases (the BaseId->flag map); that key equals SCUM.db base.id,
-- so it's how the entitlement gate looks a flag up. Falls back to FindAllOf
-- (baseId=nil) if the map is unreadable.
local function collectFlags()
    local mgr
    local mgrs = findAllAny("BP_ConZBaseManager_C", "ConZBaseManager")
    if mgrs then for i = 1, #mgrs do if isValid(mgrs[i]) then mgr = mgrs[i]; break end end end

    local radius = FU.config.flagRadiusOverride
    if not radius and mgr then
        local r = pcs(function() return mgr._flagInfluenceRadius end, nil)
        if r and r > 0 then radius = r end
    end
    radius = radius or 5000

    local flags, seen = {}, {}
    local bases = mgr and pcs(function() return mgr._bases end, nil) or nil
    if bases then
        pcall(function()
            bases:ForEach(function(k, v)
                local id = pcs(function() return k:get() end, nil)
                local f = pcs(function() return v:get() end, nil)
                if isValid(f) and not seen[f] then
                    seen[f] = true
                    local x, y = actorLoc(f)
                    if x then
                        if id then id = math.tointeger(id) or id end
                        flags[#flags + 1] = { actor = f, x = x, y = y, radius = radius, baseId = id }
                    end
                end
            end)
        end)
    end
    if #flags == 0 then
        local list = findAllAny("BP_ConZBase_C", "ConZBase")
        if list then for i = 1, #list do
            local f = list[i]
            if isValid(f) and not seen[f] then
                seen[f] = true
                local x, y = actorLoc(f)
                if x then flags[#flags + 1] = { actor = f, x = x, y = y, radius = radius, baseId = nil } end
            end
        end end
    end
    return flags, radius
end

-- All named chests/containers: { {inv=, owner=, name=, x=, y=} }
local function collectChests()
    local out = {}
    local comps = FindAllOf("ChestInventoryComponent")
    if comps then for i = 1, #comps do
        local inv = comps[i]
        if isValid(inv) then
            local owner = pcs(function() return inv:GetOwner() end, nil)
            local name = owner and fstr(pcs(function() return owner._nameableItemComponent._name end, nil)) or nil
            local x, y
            if owner then x, y = actorLoc(owner) end
            out[#out + 1] = { inv = inv, owner = owner, name = name and trim(name) or nil, x = x, y = y }
        end
    end end
    return out
end

-- Map each container to its contents: { [ownerFullName] = {ocls=, items={...}} }.
-- Contents are tracked item-side (presence InTheInventory -> _inventory -> owner),
-- so reverse it. Keyed by the owner's GetFullName() (stable across FindAllOf
-- passes, unlike userdata). Used to read the toolkits inside a FlagUpkeep box.
local function collectContainerContents()
    local map = {}
    local items = FindAllOf("Item")
    if items then for i = 1, #items do
        local it = items[i]
        if isValid(it) then
            local pc = presClass(it)
            if pc and pc:find("InTheInventory", 1, true) then
                local inv = pcs(function() return it._serverPresence._inventory end, nil)
                local owner = inv and pcs(function() return inv:GetOwner() end, nil) or nil
                local key = isValid(owner) and fullName(owner) or nil
                if key then
                    local rec = map[key]
                    if not rec then rec = { ocls = classOf(owner), items = {} }; map[key] = rec end
                    rec.items[#rec.items + 1] = it
                end
            end
        end
    end end
    return map
end

-- One InventoryUserComponent to drive item RPCs (any online player's works).
local function findIUC()
    local l = FindAllOf("InventoryUserComponent")
    if l then for i = 1, #l do if isValid(l[i]) then return l[i] end end end
    return nil
end

-- ---- scoping + matching --------------------------------------------------

-- nearest flag whose centre is within its radius of (x,y); nil if outside all
local function flagFor(x, y, flags)
    if not x then return nil end
    local best, bestd
    for _, f in ipairs(flags) do
        if f.x then
            local d = hdist(x, y, f.x, f.y)
            if d <= f.radius and (not bestd or d < bestd) then best, bestd = f, d end
        end
    end
    return best
end

local function nameMatches(a, chestName)
    if not chestName then return false end
    local la, lb = a:lower(), chestName:lower()
    if FU.config.nameContains then return lb:find(la, 1, true) ~= nil end
    return la == lb
end

-- is this content item a repair toolkit? Exact class match against the configured
-- toolbox set (config.toolkitClasses). Each toolbox's CHARGES are read live from
-- its UDiscreteUsageItemComponent._repQuantity, not from config — config just
-- whitelists which item classes count (Tool_Box_C=100, Tool_Box_Small_C=50,
-- Improvised_Tool_Box_C=20 charges when full).
local function isToolkit(cls)
    for _, k in ipairs(FU.config.toolkitClasses or {}) do
        if cls == k then return true end
    end
    return false
end

-- ---- DB access via the bundled sqlite3.exe (read-only) -------------------
-- Every query below is a FIXED constant: no untrusted input is interpolated into
-- SQL or the command line. Player-name matching for add/remove is done in Lua
-- against the full user list, so there is zero SQL/shell-injection surface.
local OWNER_SQL = "SELECT b.id, up.user_id FROM base b JOIN user_profile up ON up.id=b.owner_user_profile_id WHERE b.is_owned_by_player=1;"
local USERS_SQL = "SELECT u.id, COALESCE(up.name,''), COALESCE(u.name,'') FROM user u LEFT JOIN user_profile up ON up.user_id=u.id;"
local STEAM64_PAT = "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$" -- 17 digits

local function dq(s) return '"' .. tostring(s) .. '"' end

function FU.dbRows(sql)
    local exe = (FU.config and FU.config.sqliteExe) or FU.sqliteExe
    local db = FU.config and FU.config.dbPath
    if not exe or not db then return nil, "sqlite/db path not configured" end
    local inner = string.format('%s -readonly -batch -noheader -separator "|" %s %s 2>&1',
        dq(exe), dq(db), dq(sql))
    local h = io.popen('"' .. inner .. '"', "r")
    if not h then return nil, "io.popen failed" end
    local rows, errline = {}, nil
    for line in h:lines() do
        line = (line:gsub("\r$", ""))
        if line:match("^Error:") then
            errline = line
        elseif line ~= "" then
            local fields = {}
            for f in (line .. "|"):gmatch("(.-)|") do fields[#fields + 1] = f end
            rows[#rows + 1] = fields
        end
    end
    h:close()
    if errline then return nil, errline end
    return rows
end

-- ---- entitlement store (entitlements.lua in this mod's folder) ------------
-- pausedFlags = baseIds a player has paused (user 'upkeep pause'); a per-flag
-- opt-out applied on top of the admin entitlement (suppresses upkeep there).
-- triggerOverrides = per-flag repair threshold (fraction 0..1); a player sets it
-- with 'upkeep trigger <percent>'. Falls back to config.repairBelowFraction.
-- repairPoints = per-flag balance of repair points (1 point repairs 1 element);
-- topped up by 'upkeep deposit' converting toolboxes, spent by repairs.
local function defaultStore() return { defaultEnabled = false, players = {}, flagOverrides = {}, pausedFlags = {}, triggerOverrides = {}, repairPoints = {} } end

function FU.loadStore()
    FU.store = defaultStore()
    local f = FU.storeFile and io.open(FU.storeFile, "r") or nil
    if not f then return end
    local src = f:read("*a"); f:close()
    local chunk = load(src, "@entitlements.lua")
    local ok, t = false, nil
    if chunk then ok, t = pcall(chunk) end
    if ok and type(t) == "table" then
        FU.store.defaultEnabled = (t.defaultEnabled == true)
        if type(t.players) == "table" then
            for _, s in ipairs(t.players) do FU.store.players[#FU.store.players + 1] = tostring(s) end
        end
        if type(t.flagOverrides) == "table" then
            for k, v in pairs(t.flagOverrides) do
                local id = math.tointeger(tonumber(k))
                if id ~= nil then FU.store.flagOverrides[id] = (v == true) end
            end
        end
        if type(t.pausedFlags) == "table" then
            for _, b in ipairs(t.pausedFlags) do
                local id = math.tointeger(tonumber(b))
                if id ~= nil then FU.store.pausedFlags[id] = true end
            end
        end
        if type(t.triggerOverrides) == "table" then
            for k, v in pairs(t.triggerOverrides) do
                local id = math.tointeger(tonumber(k))
                local frac = tonumber(v)
                if id ~= nil and frac and frac > 0 and frac <= 1 then FU.store.triggerOverrides[id] = frac end
            end
        end
        if type(t.repairPoints) == "table" then
            for k, v in pairs(t.repairPoints) do
                local id = math.tointeger(tonumber(k))
                local n = math.tointeger(tonumber(v))
                if id ~= nil and n and n > 0 then FU.store.repairPoints[id] = n end
            end
        end
        if type(t.accessMessage) == "string" then FU.store.accessMessage = t.accessMessage end
    end
end

local function serializeStore(s)
    local out = {
        "-- FlagUpkeep entitlement store. Written by the upkeep chat commands;",
        "-- hand-edits are fine (then 'upkeep reload'). players = Steam64 IDs.",
        "return {",
        "  defaultEnabled = " .. (s.defaultEnabled and "true" or "false") .. ",",
        "  players = {",
    }
    for _, sid in ipairs(s.players) do out[#out + 1] = string.format("    %q,", tostring(sid)) end
    out[#out + 1] = "  },"
    out[#out + 1] = "  flagOverrides = {"
    local keys = {}
    for k in pairs(s.flagOverrides) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        out[#out + 1] = string.format("    [%d] = %s,", k, s.flagOverrides[k] and "true" or "false")
    end
    out[#out + 1] = "  },"
    out[#out + 1] = "  pausedFlags = {"
    local pk = {}
    for k in pairs(s.pausedFlags or {}) do pk[#pk + 1] = k end
    table.sort(pk)
    out[#out + 1] = "    " .. table.concat(pk, ", ")
    out[#out + 1] = "  },"
    out[#out + 1] = "  triggerOverrides = {"
    local tk = {}
    for k in pairs(s.triggerOverrides or {}) do tk[#tk + 1] = k end
    table.sort(tk)
    for _, k in ipairs(tk) do
        out[#out + 1] = string.format("    [%d] = %s,", k, tostring(s.triggerOverrides[k]))
    end
    out[#out + 1] = "  },"
    out[#out + 1] = "  repairPoints = {"
    local rk = {}
    for k in pairs(s.repairPoints or {}) do rk[#rk + 1] = k end
    table.sort(rk)
    for _, k in ipairs(rk) do
        out[#out + 1] = string.format("    [%d] = %d,", k, s.repairPoints[k])
    end
    out[#out + 1] = "  },"
    if s.accessMessage ~= nil then
        out[#out + 1] = string.format("  accessMessage = %q,", tostring(s.accessMessage))
    end
    out[#out + 1] = "}"
    return table.concat(out, "\n") .. "\n"
end

function FU.saveStore()
    if not FU.store then return false end
    local f = FU.storeFile and io.open(FU.storeFile, "w") or nil
    if not f then FU.log("could not write store: " .. tostring(FU.storeFile)); return false end
    f:write(serializeStore(FU.store)); f:close()
    return true
end

local function tcount(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end

-- recompute FU.resolved.enabled (set of baseIds to upkeep) from ownerMap + store.
-- Precedence per base: per-flag override > player-entitled > global default.
local function recomputeEnabled()
    local s = FU.store or defaultStore()
    local owners = FU.ownerMap or {}
    local entitled = {}
    for _, sid in ipairs(s.players) do entitled[sid] = true end
    local consider = {}
    for baseId in pairs(owners) do consider[baseId] = true end
    for baseId in pairs(s.flagOverrides) do consider[baseId] = true end
    local paused = s.pausedFlags or {}
    local enabledBases, enabled, n = {}, {}, 0
    for baseId in pairs(consider) do
        local ov = s.flagOverrides[baseId]
        local en
        if ov ~= nil then en = ov
        elseif owners[baseId] and entitled[owners[baseId]] then en = true
        else en = s.defaultEnabled end
        if en then
            enabledBases[baseId] = true
            if not paused[baseId] then enabled[baseId] = true; n = n + 1 end
        end
    end
    FU.resolved = {
        enabled = enabled,
        enabledBases = enabledBases,
        defaultEnabled = s.defaultEnabled,
        counts = { enabled = n, bases = tcount(owners), players = #s.players,
                   overrides = tcount(s.flagOverrides), paused = tcount(paused) },
    }
end

function FU.ensureResolved(force)
    local cfg = FU.config or {}
    if not cfg.entitlementsEnabled then FU.resolved = nil; return true end
    if not FU.store then FU.loadStore() end
    local intervalSec = (cfg.resyncIntervalMs or 300000) / 1000
    local fresh = FU.ownerMap and FU.ownerMapAt and (os.time() - FU.ownerMapAt) < intervalSec
    if force or not fresh then
        local rows, err = FU.dbRows(OWNER_SQL)
        if rows then
            local m = {}
            for _, r in ipairs(rows) do
                local id = math.tointeger(tonumber(r[1]))
                if id ~= nil then m[id] = r[2] end
            end
            FU.ownerMap = m
            FU.ownerMapAt = os.time()
        else
            FU.log("entitlement DB read failed: " .. tostring(err))
        end
    end
    if not FU.ownerMap then FU.resolved = nil; return false end
    recomputeEnabled()
    return true
end

function FU.resolvePlayer(arg)
    arg = trim(arg or "")
    if arg == "" then return { status = "notfound" } end
    local rows, err = FU.dbRows(USERS_SQL)
    if not rows then FU.log("resolvePlayer DB read failed: " .. tostring(err)); return { status = "dberror" } end
    if arg:match(STEAM64_PAT) then
        for _, r in ipairs(rows) do
            if r[1] == arg then return { status = "ok", id = r[1], name = (r[2] ~= "" and r[2] or r[3]) } end
        end
        return { status = "pregrant", id = arg }
    end
    local low = arg:lower()
    local matches = {}
    for _, r in ipairs(rows) do
        if (r[2] or ""):lower() == low or (r[3] or ""):lower() == low then
            matches[r[1]] = (r[2] ~= "" and r[2] or r[3])
        end
    end
    local ids = {}
    for sid in pairs(matches) do ids[#ids + 1] = sid end
    if #ids == 1 then return { status = "ok", id = ids[1], name = matches[ids[1]] } end
    if #ids > 1 then return { status = "ambiguous", matches = matches } end
    return { status = "notfound" }
end

-- is this flag enabled for upkeep? Fail-closed: gate on but unverifiable => no.
local function flagEnabled(flag)
    if not (FU.config and FU.config.entitlementsEnabled) then return true end
    local r = FU.resolved
    if not r or not r.enabled then return false end
    local bid = flag.baseId
    if bid == nil then return false end
    return r.enabled[bid] == true
end

local function currentFlagBaseId()
    local ctrl = FU.controller
    if not ctrl then return nil end
    local pawn = pcs(function() return ctrl:K2_GetPawn() end, nil)
    if not isValid(pawn) then pawn = pcs(function() return ctrl.Pawn end, nil) end
    if not isValid(pawn) then return nil end
    local ax, ay = actorLoc(pawn)
    if not ax then return nil end
    local flags = collectFlags()
    local flag = flagFor(ax, ay, flags)
    return flag and flag.baseId or nil
end

local function flagEnabledForIssuer(baseId)
    if not (FU.config and FU.config.entitlementsEnabled) then return true end
    return (FU.resolved and FU.resolved.enabledBases and FU.resolved.enabledBases[baseId]) == true
end

-- the repair-trigger threshold (health fraction) for a base: per-flag override
-- (set via 'upkeep trigger') else the global config default.
local function triggerFor(baseId)
    local s = FU.store
    local f = s and s.triggerOverrides and baseId ~= nil and s.triggerOverrides[baseId]
    if type(f) == "number" then return f end
    return FU.config.repairBelowFraction or 0.90
end

-- ---- access-control chat commands (verbatim model from GarbageGoober) -----

function FU.handleFlagCmd(rest)
    local mode, idtok = (rest or ""):match("^(%S*)%s*(%S*)$")
    mode = (mode or ""):lower()
    if mode ~= "on" and mode ~= "off" and mode ~= "clear" then
        FU.reply("usage: upkeep flag on|off|clear [baseId]  (no id = your current flag)")
        return
    end
    local baseId
    if idtok and idtok ~= "" then
        local n = tonumber(idtok)
        baseId = n and math.tointeger(n) or nil
        if not baseId then FU.reply("baseId must be a whole number"); return end
    else
        baseId = currentFlagBaseId()
        if not baseId then
            FU.reply("stand in the flag you mean, or give its id: upkeep flag " .. mode .. " <baseId>")
            return
        end
    end
    if not FU.store then FU.loadStore() end
    if mode == "clear" then
        if FU.store.flagOverrides[baseId] ~= nil then
            FU.store.flagOverrides[baseId] = nil
            FU.reply("cleared override on base " .. baseId .. " (back to player/default)")
        else
            FU.reply("base " .. baseId .. " had no override")
        end
    else
        FU.store.flagOverrides[baseId] = (mode == "on")
        FU.reply("base " .. baseId .. " override set to " .. mode:upper())
    end
    FU.saveStore()
    FU.ensureResolved(true)
end

function FU.cmdList()
    if not FU.store then FU.loadStore() end
    FU.ensureResolved(true)
    local s = FU.store
    FU.reply("FlagUpkeep access (default: " .. (s.defaultEnabled and "ON" or "OFF") .. ")", true)
    local users = FU.dbRows(USERS_SQL) or {}
    local nameOf = {}
    for _, u in ipairs(users) do nameOf[u[1]] = (u[2] ~= "" and u[2] or u[3]) end
    FU.reply("enabled players (" .. #s.players .. "):", true)
    if #s.players == 0 then FU.reply("  (none)", true) end
    for _, sid in ipairs(s.players) do
        local bids = {}
        for baseId, owner in pairs(FU.ownerMap or {}) do if owner == sid then bids[#bids + 1] = baseId end end
        table.sort(bids)
        local where = #bids > 0 and ("base " .. table.concat(bids, ", ")) or "no base yet"
        FU.reply(string.format("  %s  %s  -> %s", sid, nameOf[sid] or "?", where), true)
    end
    local ovk = {}
    for k in pairs(s.flagOverrides) do ovk[#ovk + 1] = k end
    table.sort(ovk)
    FU.reply("flag overrides (" .. #ovk .. "):", true)
    if #ovk == 0 then FU.reply("  (none)", true) end
    for _, k in ipairs(ovk) do FU.reply("  base " .. k .. " -> " .. (s.flagOverrides[k] and "ON" or "OFF"), true) end
    local c = (FU.resolved and FU.resolved.counts) or {}
    FU.reply(string.format("result: %d of %d player-owned base(s) will be kept up", c.enabled or 0, c.bases or 0), true)
end

function FU.cmdStatus()
    if not FU.store then FU.loadStore() end
    FU.ensureResolved(true)
    local s = FU.store
    local c = (FU.resolved and FU.resolved.counts) or {}
    FU.reply(string.format("default=%s  players=%d  flag overrides=%d  paused=%d  -> %d/%d base(s) kept up",
        s.defaultEnabled and "ON" or "OFF", #s.players, tcount(s.flagOverrides), tcount(s.pausedFlags),
        c.enabled or 0, c.bases or 0), true)
    if not FU.config.repairEnabled then
        FU.reply("NOTE: repair is DISABLED in config (report-only mode)", true)
    elseif not FU.config.requireRepairPoints then
        FU.reply("NOTE: requireRepairPoints=false — repairing for free (no points consumed)", true)
    end
    if FU.enabled == false then FU.reply("auto-upkeep is PAUSED server-wide (pause-all active)", true) end
end

function FU.cmdAdd(who)
    if not FU.store then FU.loadStore() end
    local r = FU.resolvePlayer(who)
    if r.status == "dberror" then FU.reply("DB read failed (see log)"); return end
    if r.status == "notfound" then FU.reply("no player matched '" .. who .. "' (try their Steam64 ID)"); return end
    if r.status == "ambiguous" then
        FU.reply("'" .. who .. "' matches several players - add by Steam64:", true)
        for sid, nm in pairs(r.matches) do FU.reply("  " .. sid .. "  " .. tostring(nm), true) end
        return
    end
    local sid, nm = r.id, r.name
    for _, p in ipairs(FU.store.players) do
        if p == sid then FU.reply((nm or sid) .. " is already enabled"); return end
    end
    FU.store.players[#FU.store.players + 1] = sid
    FU.saveStore()
    FU.ensureResolved(true)
    local bids = {}
    for baseId, owner in pairs(FU.ownerMap or {}) do if owner == sid then bids[#bids + 1] = baseId end end
    table.sort(bids)
    local tail
    if #bids > 0 then tail = "now keeping up base " .. table.concat(bids, ", ")
    elseif r.status == "pregrant" then tail = "not seen on this server yet - applies when they build"
    else tail = "no base owned yet" end
    FU.reply("enabled " .. (nm or sid) .. " (" .. sid .. ") - " .. tail)
end

function FU.cmdRemove(who)
    if not FU.store then FU.loadStore() end
    who = trim(who)
    local target
    for _, p in ipairs(FU.store.players) do if p == who then target = who; break end end
    if not target then
        local r = FU.resolvePlayer(who)
        if r.status == "ambiguous" then
            FU.reply("'" .. who .. "' matches several players - remove by Steam64:", true)
            for sid, nm in pairs(r.matches) do FU.reply("  " .. sid .. "  " .. tostring(nm), true) end
            return
        end
        if r.id then
            for _, p in ipairs(FU.store.players) do if p == r.id then target = r.id; break end end
        end
    end
    if not target then FU.reply("'" .. who .. "' is not in the enabled list"); return end
    local kept = {}
    for _, p in ipairs(FU.store.players) do if p ~= target then kept[#kept + 1] = p end end
    FU.store.players = kept
    FU.saveStore()
    FU.ensureResolved(true)
    FU.reply("removed " .. target .. " from enabled players")
end

function FU.cmdDefault(mode)
    if not FU.store then FU.loadStore() end
    FU.store.defaultEnabled = (mode == "on")
    FU.saveStore()
    FU.ensureResolved(true)
    local c = (FU.resolved and FU.resolved.counts) or {}
    FU.reply(string.format("global default set to %s - %d/%d base(s) now kept up", mode:upper(), c.enabled or 0, c.bases or 0))
end

local DEFAULT_NOT_ENABLED = "upkeep isn't enabled for your base — ask an admin to enable it"
local SILENT_TOKENS = { off = true, none = true, silent = true, ["nil"] = true, [""] = true }

local function accessSetting()
    if FU.store and FU.store.accessMessage ~= nil then return FU.store.accessMessage, "command" end
    return (FU.config and FU.config.notEnabledMessage), "config"
end

local function replyNotEnabled()
    local m = accessSetting()
    if m == nil then return end
    if type(m) == "string" then
        local low = m:lower()
        if SILENT_TOKENS[low] then return end
        if low == "default" then FU.reply(DEFAULT_NOT_ENABLED, true); return end
        FU.reply(m, true)
    elseif type(m) == "table" then
        for _, l in ipairs(m) do FU.reply(tostring(l), true) end
    end
end

function FU.cmdPauseFlag(pause)
    if not FU.store then FU.loadStore() end
    FU.store.pausedFlags = FU.store.pausedFlags or {}
    local baseId = currentFlagBaseId()
    if not baseId then
        FU.reply("stand in the flag you want to " .. (pause and "pause" or "resume") .. " upkeep for")
        return
    end
    FU.ensureResolved(false)
    if not flagEnabledForIssuer(baseId) then replyNotEnabled(); return end
    if pause then
        FU.store.pausedFlags[baseId] = true
        FU.reply("upkeep PAUSED for your flag (base " .. baseId .. ") — 'upkeep resume' to undo")
    elseif FU.store.pausedFlags[baseId] then
        FU.store.pausedFlags[baseId] = nil
        FU.reply("upkeep RESUMED for your flag (base " .. baseId .. ")")
    else
        FU.reply("your flag (base " .. baseId .. ") was not paused")
    end
    FU.saveStore()
    FU.ensureResolved(true)
end

-- user 'upkeep trigger [percent|clear]' — set the repair health threshold for the
-- flag the issuer is standing in (elements below it get repaired). Lower = repair
-- later (saves charges, more raid-risk); higher = repair sooner. Blank = show it.
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
        FU.reply(string.format("base %d repair trigger = %.0f%% (%s). Set with 'upkeep trigger <1-100>' or 'clear'",
            baseId, cur * 100, src), true)
        return
    end
    if arg == "clear" then
        FU.store.triggerOverrides[baseId] = nil
        FU.saveStore()
        FU.reply(string.format("base %d trigger cleared — using server default %.0f%%",
            baseId, (FU.config.repairBelowFraction or 0.90) * 100))
        return
    end
    local pct = tonumber(arg:match("^(%d+%.?%d*)"))
    if not pct or pct <= 0 or pct > 100 then FU.reply("usage: upkeep trigger <1-100> | clear"); return end
    FU.store.triggerOverrides[baseId] = pct / 100
    FU.saveStore()
    FU.reply(string.format("base %d repair trigger set to %.0f%% — elements below that get repaired", baseId, pct))
end

function FU.cmdGetAccessMsg()
    if not FU.store then FU.loadStore() end
    local m, src = accessSetting()
    if m == nil then FU.reply("access-msg [" .. src .. "]: SILENT (non-enabled players see nothing)"); return end
    if type(m) == "table" then
        FU.reply("access-msg [" .. src .. "] (" .. #m .. " lines):")
        for _, l in ipairs(m) do FU.reply("  " .. tostring(l), true) end
        return
    end
    local low = tostring(m):lower()
    if SILENT_TOKENS[low] then
        FU.reply("access-msg [" .. src .. "]: SILENT (non-enabled players see nothing)")
    elseif low == "default" then
        FU.reply("access-msg [" .. src .. "]: default => " .. DEFAULT_NOT_ENABLED)
    else
        FU.reply("access-msg [" .. src .. "]: " .. tostring(m))
    end
end

function FU.cmdSetAccessMsg(text)
    if not FU.store then FU.loadStore() end
    text = trim(text or "")
    if text == "" then FU.reply("usage: upkeep set-access-msg <text> | default | off | reset"); return end
    local low = text:lower()
    if low == "reset" then
        FU.store.accessMessage = nil
        FU.saveStore()
        FU.reply("access-msg reset — now using Config.lua's notEnabledMessage")
        return
    end
    FU.store.accessMessage = text
    FU.saveStore()
    if SILENT_TOKENS[low] then
        FU.reply("access-msg set to SILENT — non-enabled players will see nothing")
    elseif low == "default" then
        FU.reply("access-msg set to the built-in default")
    else
        FU.reply("access-msg set to: " .. text)
    end
end

-- ---- FlagUpkeep-specific: containers, toolkits, repair --------------------

-- The FlagUpkeep container(s) inside one flag: chests within the flag radius
-- whose custom name matches config.containerName.
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

-- The toolkit items inside a set of containers (flat list of item actors).
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

-- ---- the repair primitive (RE'd + VERIFIED 2026-05-30; see memory
-- reference-scum-base-building-architecture). The per-element BaseElementId is
-- read from SCUM.db (base_element.element_id); repair is driven by the game's own
-- NetMulticast_InteractWithElement(170 RepairBaseElement) with a large RepairValue
-- that the game CLAMPS to full HP (no maxHP needed, no crash). Toolkits are
-- consumed by destroying the item actor directly. -----------------------------

local REPAIR_INTERACTION = 170      -- EInteractionType.RepairBaseElement (per-element, by id)
local REPAIR_VALUE_FULL  = 100000.0 -- large RepairValue -> game clamps the element to full HP
-- All base_elements below full health. CONSTANT SQL: base_id grouping and the
-- repair-threshold are applied in Lua, so no dynamic/untrusted value ever enters
-- SQL (same zero-injection rule as the owner query).
local DAMAGED_SQL = "SELECT base_id, element_id, location_x, location_y, location_z, element_health FROM base_element WHERE element_health < 1.0;"
-- every element of every base (the admin test-damage command filters base_id in Lua)
local ALL_ELEMENTS_SQL = "SELECT base_id, element_id, location_x, location_y, location_z FROM base_element;"

-- Replication/order tag for the repair multicast. The server-side health change
-- applies regardless of this value (recon); we just increment so successive calls
-- differ. Kept modest (NOT a huge seed) to avoid desyncing connected clients'
-- base visuals — see the live-test caveat in memory.
function FU.nextDataVersion()
    FU.dataVersion = (FU.dataVersion or 1000) + 1
    return FU.dataVersion
end

-- the ConZBaseManager singleton (drives the repair multicast)
local function findManager()
    for _, n in ipairs({ "BP_ConZBaseManager_C", "ConZBaseManager" }) do
        local l = FindAllOf(n)
        if l then for i = 1, #l do if isValid(l[i]) then return l[i] end end end
    end
    return nil
end

-- any live prisoner pawn, to pass as the interaction's User (recon passed the
-- caller's pawn; a valid prisoner is the safe choice). nil if none online.
local function findPawn()
    local l = FindAllOf("BP_Prisoner_C")
    if l then for i = 1, #l do if isValid(l[i]) then return l[i] end end end
    return nil
end

-- damaged elements grouped by base_id: { [baseId] = { {id=,x=,y=,z=,hp=}, ... } }.
-- Reads the DB once per cycle; each base keeps only elements below ITS trigger
-- threshold (per-flag override else the global default). Sorted most-damaged
-- first so scarce charges fix the weakest elements when there aren't enough.
local function fetchDamagedByBase()
    local rows, err = FU.dbRows(DAMAGED_SQL)
    if not rows then FU.log("upkeep: damaged-element DB read failed: " .. tostring(err)); return nil end
    local map = {}
    for _, r in ipairs(rows) do
        local bid = math.tointeger(tonumber(r[1]))
        local hp = tonumber(r[6]) or 1.0
        if bid and hp < triggerFor(bid) then
            local rec = map[bid]; if not rec then rec = {}; map[bid] = rec end
            rec[#rec + 1] = { id = math.tointeger(tonumber(r[2])), x = tonumber(r[3]), y = tonumber(r[4]), z = tonumber(r[5]), hp = hp }
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

-- TEST ONLY: damage one element by <amount> HP via the proven ApplyDamageToBaseElement
-- primitive. Unclamped — a large amount can drop a low-HP element to 0 and destroy it.
local function damageElement(mgr, baseId, el, amount)
    local loc = { X = el.x, Y = el.y, Z = el.z }
    return pcall(function()
        mgr:NetMulticast_ApplyDamageToBaseElement(FU.nextDataVersion(), baseId, el.id, loc, amount)
    end)
end

-- A toolbox's charge component (UDiscreteUsageItemComponent; _repQuantity = charges
-- remaining), read DIRECTLY off the LIVE item via GetComponentByClass (verified
-- PASS 41). We do NOT use FindAllOf("DiscreteUsageItemComponent")+GetOwner: items
-- in a placed chest virtualize out of FindAllOf and tracing them back crashes the
-- server. So we only ever read charges off items we already hold live (from the
-- container-contents scan), which is safe.
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

-- per-flag repair-point balance (persisted in the store)
local function pointsOf(baseId)
    return (FU.store and FU.store.repairPoints and baseId ~= nil and FU.store.repairPoints[baseId]) or 0
end

-- Repair a flag's damaged base elements, spending REPAIR POINTS (1 point = 1
-- element repaired to full, from any health level). Points are pre-banked via
-- 'upkeep deposit', so repair reads no live toolboxes and works unattended.
-- requireRepairPoints=false repairs for free. Returns (repaired, pointsSpent).
function FU.repairFlag(flag, damaged)
    if not FU.config.repairEnabled then return 0, 0 end
    if not damaged or #damaged == 0 then return 0, 0 end
    local mgr = findManager()
    if not mgr then FU.log("  repairFlag: no ConZBaseManager — skipping"); return 0, 0 end
    local user = findPawn() -- may be nil

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
        if needPts and (bal - spent) <= 0 then break end -- out of points
        if el.id and FU.repairedAt[el.id] and (now - FU.repairedAt[el.id]) < cd then
            -- repaired recently: the DB health read lags a save cycle, so it still
            -- reads as damaged. Skip so we don't spend a second point on it.
            skipped = skipped + 1
        else
            if repairElement(mgr, flag.baseId, el, user) then
                repaired = repaired + 1
                if el.id then FU.repairedAt[el.id] = now end
                if needPts then spent = spent + 1 end
                FU.log(string.format("  repaired element %s (was %.0f%%) in base %s",
                    tostring(el.id), (el.hp or 0) * 100, tostring(flag.baseId)))
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
        FU.log(string.format("  base %s: spent %d repair point(s), %d left",
            tostring(flag.baseId), spent, pointsOf(flag.baseId)))
    end
    return repaired, spent
end

-- ---- the upkeep cycle ----------------------------------------------------
-- onlyBaseId (optional): restrict to one flag (for user 'upkeep now').
function FU.upkeep(onlyBaseId)
    FU.ensureResolved(false)
    if not FU.store then FU.loadStore() end -- needed for per-flag trigger overrides
    if FU.config.entitlementsEnabled and not FU.resolved then
        FU.log("upkeep: gate ON but no enabled set (DB read failed?) — NOT running (fail-closed). " ..
            "Check sqlite3.exe/dbPath; run 'upkeep status'.")
    end

    local flags, radius = collectFlags()
    if onlyBaseId then
        local only = {}
        for _, f in ipairs(flags) do if f.baseId == onlyBaseId then only[#only + 1] = f end end
        flags = only
    end
    if #flags == 0 then
        FU.log("upkeep: no flags found in world — skipping.")
        return "no flags found"
    end
    -- damaged elements (by base_id) from the save DB; only when repair is on
    local damagedByBase = (FU.config.repairEnabled and fetchDamagedByBase()) or {}

    FU.log(string.format("upkeep start: %d flag(s), radius=%dcm%s%s",
        #flags, radius,
        FU.config.entitlementsEnabled and (" | gate ON (" ..
            (FU.resolved and FU.resolved.counts and FU.resolved.counts.enabled or 0) .. " base(s) enabled)") or " | gate OFF",
        FU.config.repairEnabled and "" or " | REPAIR DISABLED (report-only)"))

    local repaired, spent, kept, noPoints, disabled, clean = 0, 0, 0, 0, 0, 0
    for _, flag in ipairs(flags) do
        if not flagEnabled(flag) then
            disabled = disabled + 1
        else
            local damaged = damagedByBase[flag.baseId] or {}
            if not FU.config.repairEnabled then
                -- report-only: just note what we'd service
                if #damaged == 0 then clean = clean + 1 else
                    FU.log(string.format("  base %s: %d element(s) below %.0f%% (repair disabled)",
                        tostring(flag.baseId), #damaged, triggerFor(flag.baseId) * 100))
                end
            elseif #damaged == 0 then
                clean = clean + 1 -- nothing below threshold; nothing to do
            elseif FU.config.requireRepairPoints and pointsOf(flag.baseId) <= 0 then
                noPoints = noPoints + 1
                FU.log(string.format("  base %s: %d damaged but 0 repair points — deposit toolboxes to top up",
                    tostring(flag.baseId), #damaged))
            else
                FU.log(string.format("  base %s: %d damaged element(s); %d repair point(s) available",
                    tostring(flag.baseId), #damaged, pointsOf(flag.baseId)))
                local r, c = FU.repairFlag(flag, damaged)
                repaired = repaired + (r or 0)
                spent = spent + (c or 0)
                if (r or 0) > 0 then kept = kept + 1 end
            end
        end
    end

    FU.log(string.format("upkeep done: serviced=%d  repaired=%d  points-spent=%d  | disabled=%d  no-points=%d  already-ok=%d",
        kept, repaired, spent, disabled, noPoints, clean))
    return string.format("serviced %d base(s); repaired %d element(s); spent %d repair point(s)%s",
        kept, repaired, spent, FU.config.repairEnabled and "" or " [repair disabled]")
end

-- upkeep check — audit the issuer's CURRENT flag: the FlagUpkeep container(s)
-- and how many toolkits they hold. Read-only. Echoes to chat + log.
function FU.cmdCheck()
    -- echo each line to BOTH the issuer's chat and the log (so 'check the log' works)
    local function say(s) FU.reply(s, true); FU.log("  [check] " .. s) end
    local ctrl = FU.controller
    local ax, ay
    if ctrl ~= nil then
        local pawn = pcs(function() return ctrl:K2_GetPawn() end, nil)
        if not isValid(pawn) then pawn = pcs(function() return ctrl.Pawn end, nil) end
        if isValid(pawn) then ax, ay = actorLoc(pawn) end
    end
    if not ax then say("couldn't get your location"); return end
    local flags = collectFlags()
    local flag = flagFor(ax, ay, flags)
    if not flag then say("you're not in a flag zone"); return end

    if not FU.store then FU.loadStore() end
    local frac = triggerFor(flag.baseId)
    say(string.format("base %s: %d repair point(s) banked", tostring(flag.baseId), pointsOf(flag.baseId)))

    local containers = upkeepContainersIn(flag, collectChests())
    if #containers == 0 then
        say(string.format("no '%s' container (build a chest/wardrobe named exactly that to deposit toolboxes)",
            FU.config.containerName))
    else
        local tks = toolkitsIn(containers, collectContainerContents())
        local byCls, depositable = {}, 0
        for _, it in ipairs(tks) do
            local c = classOf(it)
            local ch = chargesOf(it)
            local rec = byCls[c]; if not rec then rec = { n = 0, ch = 0 }; byCls[c] = rec end
            rec.n = rec.n + 1; rec.ch = rec.ch + ch; depositable = depositable + ch
        end
        say(string.format("'%s' container: %d toolbox(es) = %d depositable point(s)",
            FU.config.containerName, #tks, depositable))
        for c, rec in pairs(byCls) do say(string.format("  %dx %s (%d pts)", rec.n, c, rec.ch)) end
        if depositable > 0 then say("  -> 'upkeep deposit' (with the chest OPEN) to bank them") end
        if #tks > 0 and depositable == 0 then say("  (these read 0 pts — already deposited, or open the chest to read them)") end
    end

    local dmg = FU.dbRows(DAMAGED_SQL)
    if dmg then
        local n = 0
        for _, r in ipairs(dmg) do
            if math.tointeger(tonumber(r[1])) == flag.baseId and (tonumber(r[6]) or 1) < frac then n = n + 1 end
        end
        say(string.format("trigger=%.0f%% — %d element(s) below it (need %d point(s) to repair)", frac * 100, n, n))
    end
    if not FU.config.repairEnabled then
        say("(repair is DISABLED in config — this is a report only)")
    end
end

-- user 'upkeep deposit' — convert the toolboxes in the (OPEN) FlagUpkeep container
-- into repair points for this flag, destroying them. Reads each box's live charges;
-- a box reading 0 (chest not open / virtualized) is LEFT ALONE so a full box is
-- never lost. So: open the chest, then 'upkeep deposit'.
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
    if #containers == 0 then
        FU.reply(string.format("no '%s' container in your flag", FU.config.containerName)); return
    end
    local tks = toolkitsIn(containers, collectContainerContents())
    if #tks == 0 then
        FU.reply("no toolboxes in the container — put some in and make sure the chest is OPEN"); return
    end
    local gained, banked, zero = 0, 0, 0
    for _, it in ipairs(tks) do
        local ch = chargesOf(it)
        if ch > 0 then
            gained = gained + ch; banked = banked + 1
            pcall(function() it:K2_DestroyActor() end) -- consumed into points
        else
            zero = zero + 1
        end
    end
    if gained > 0 then
        FU.store.repairPoints[baseId] = (FU.store.repairPoints[baseId] or 0) + gained
        FU.saveStore()
    end
    local bal = FU.store.repairPoints[baseId] or 0
    FU.log(string.format("deposit: base %d +%d point(s) from %d box(es) (%d read 0) -> %d total", baseId, gained, banked, zero, bal))
    local msg = string.format("deposited %d repair point(s) from %d toolbox(es) — balance %d", gained, banked, bal)
    if zero > 0 then msg = msg .. string.format("  (%d box(es) read 0 — OPEN the chest and retry)", zero) end
    FU.reply(msg)
end

-- admin TEST tool 'upkeep damage [amount]' — damage every element in the issuer's
-- flag by <amount> HP (default 200) so there's something to repair. Gated behind
-- config.allowTestDamage so it can't fire on a production server. ApplyDamage is
-- unclamped: a high amount can destroy low-HP elements. Admin-only (not a USER_CMD).
function FU.cmdDamage(arg)
    if not (FU.config and FU.config.allowTestDamage) then
        FU.reply("test-damage is disabled — set allowTestDamage=true in Config.lua then 'upkeep reload'")
        return
    end
    -- default small: big absolute damage DESTROYS low-HP pieces. For testing,
    -- prefer a small amount + a high 'upkeep trigger' so damaged-but-alive pieces
    -- still fall below the trigger.
    local amount = tonumber((trim(arg or "")):match("^(%d+%.?%d*)")) or 50
    if amount <= 0 then amount = 50 end
    local baseId = currentFlagBaseId()
    if not baseId then FU.reply("stand in the flag whose elements you want to damage"); return end
    local mgr = findManager()
    if not mgr then FU.reply("no ConZBaseManager found"); return end
    local rows = FU.dbRows(ALL_ELEMENTS_SQL)
    if not rows then FU.reply("element DB read failed (see log)"); return end
    local n = 0
    for _, r in ipairs(rows) do
        if math.tointeger(tonumber(r[1])) == baseId then
            local el = { id = math.tointeger(tonumber(r[2])), x = tonumber(r[3]), y = tonumber(r[4]), z = tonumber(r[5]) }
            if el.id and damageElement(mgr, baseId, el, amount) then n = n + 1 end
        end
    end
    FU.log(string.format("TEST damage: base %d — %d element(s) by %.0f HP", baseId, n, amount))
    FU.reply(string.format("TEST: damaged %d element(s) by %.0f HP. Health shows in the DB after the", n, amount), true)
    FU.reply("server's next save (~mins), THEN 'upkeep now'. Use 'upkeep trigger 99' so light damage qualifies.", true)
end

-- ---- chat help + reply ---------------------------------------------------
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
            h[#h + 1] = "  upkeep list         — enabled players / flag overrides / result"
            h[#h + 1] = "  upkeep status       — one-line access summary"
            h[#h + 1] = "  upkeep add/remove <player> — enable / disable upkeep for a player (name or Steam64)"
            h[#h + 1] = "  upkeep flag on|off|clear [baseId] — per-flag override (blank=your flag)"
            h[#h + 1] = "  upkeep default on|off — keep up every flag by default, or none"
            h[#h + 1] = "  upkeep get-access-msg / set-access-msg <text|default|off|reset>"
        end
    end
    return h
end
local function printHelp() for _, l in ipairs(helpLines(true)) do FU.log(l) end end

local CHAT_SERVERMESSAGE = 6
function FU.reply(text, raw)
    local chan, ctrl = FU.channel, FU.controller
    if chan == nil then return false end
    local ps = nil
    if ctrl ~= nil then ps = pcs(function() return ctrl.PlayerState end, nil) end
    local msg = raw and tostring(text) or ("[FlagUpkeep] " .. tostring(text))
    local ok = pcall(function()
        chan:Chat_Client_SendMessageToChat(msg, ps, {}, CHAT_SERVERMESSAGE, false)
    end)
    return ok
end

function FU.replyHelp() for _, l in ipairs(helpLines(FU.callerIsAdmin == true)) do FU.reply(l, true) end end

-- ---- command dispatch ----------------------------------------------------
local USER_CMDS = { [""] = true, check = true, now = true, pause = true, resume = true, trigger = true, deposit = true }

function FU.handleCommand(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local word = (arg == "") and "" or (arg:match("^(%S+)") or "")
    if not USER_CMDS[word] and (not FU.config or FU.config.requireAdmin ~= false) and not FU.callerIsAdmin then
        FU.log("ignored 'upkeep " .. arg .. "' — admin-only (sender not admin)")
        FU.reply("'upkeep " .. word .. "' is admin-only")
        return
    end
    if arg == "" then
        printHelp()
        FU.replyHelp()
    elseif arg == "now" then
        local baseId = currentFlagBaseId()
        if FU.enabled == false then
            FU.reply("upkeep is paused server-wide (an admin ran 'upkeep pause-all')")
        elseif not baseId then
            FU.reply("stand in your flag, then 'upkeep now' to run it")
        else
            FU.ensureResolved(false)
            local r = FU.resolved
            local gateOn = FU.config.entitlementsEnabled
            local serviceable = (not gateOn) or (r and r.enabled and r.enabled[baseId] == true)
            if serviceable then
                FU.log("manual upkeep of base " .. baseId .. " (upkeep now)")
                local ok, s = pcall(FU.upkeep, baseId)
                FU.reply(ok and (s or "done") or "upkeep error (see log)")
            elseif r and r.enabledBases and r.enabledBases[baseId] then
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
    else
        FU.log("unrecognised command 'upkeep " .. arg .. "'")
        FU.reply("Command unrecognised: '" .. arg .. "'")
        FU.reply("Type 'upkeep' for a list of valid commands")
    end
end

-- Called from main.lua's chat hook with the live RemoteUnrealParams for
-- Chat_Server_BroadcastChatMessage(Message, Channel). If the message is one of
-- our commands ("upkeep ..."), handle it. We do NOT mutate the message.
function FU.onChatMessage(self, messageParam)
    local msg = ""
    pcall(function() msg = messageParam:get():ToString() end)
    if type(msg) ~= "string" or msg == "" then return end
    local trig = ((FU.config and FU.config.chatTrigger) or "upkeep"):lower()
    local low = msg:lower()
    if low ~= trig and low:sub(1, #trig + 1) ~= (trig .. " ") then return end
    local chan = pcs(function() return self:get() end, nil)
    local ctrl = chan and pcs(function() return chan:GetOuter() end, nil) or nil
    FU.channel = chan
    FU.controller = ctrl
    FU.callerIsAdmin = (ctrl ~= nil) and (pcs(function() return ctrl:IsUserAdmin() end, false) == true)
    FU.handleCommand((#msg <= #trig) and "" or msg:sub(#trig + 2))
end

FU.log("upkeep.lua loaded (engine ready" .. (FU.config and FU.config.repairEnabled and "" or "; REPORT-ONLY, repair recon pending") .. ").")
