-- sorter.lua — GarbageGoober sweep engine. Defines GarbageGoober.sweep() and helpers.
-- Loaded (and hot-reloadable) by main.lua. Reads GarbageGoober.config / GarbageGoober.log.
-- Pure logic: no timers or hooks installed here.

GarbageGoober = GarbageGoober or {}
local GG = GarbageGoober

local AUTOPLACE = 1073741824 -- FInventoryEntryLocation.Value: auto-place in first free slot

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

-- loose item world pos: from its floor presence (PASS-19-proven; an item actor's
-- own transform can be stale/zero — don't trust K2_GetActorLocation for items).
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

-- FindAllOf the first of several candidate class names that yields a non-empty list
local function findAllAny(...)
    for _, n in ipairs({ ... }) do
        local l = FindAllOf(n)
        if l and #l > 0 then return l end
    end
    return nil
end

-- ---- deployable exclusion (placed structures are NOT loose loot) ---------
local chestItemClass = pcs(function() return StaticFindObject("/Script/SCUM.ChestItem") end, nil)
local DEPLOYABLE_KW = { "chest", "bonfire", "campfire", "fireplace", "trap", "shelter",
    "flag", "tent", "torch", "lantern", "sign", "barrel" }
local function isDeployable(it)
    if isValid(chestItemClass) and pcs(function() return it:IsA(chestItemClass) end, false) then return true end
    local low = classOf(it):lower()
    for _, k in ipairs(DEPLOYABLE_KW) do if low:find(k, 1, true) then return true end end
    return false
end

-- ---- string match helpers ------------------------------------------------
local function trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
local function fstr(s) -- normalise an FString/userdata/string to a plain string
    if type(s) == "string" then return s end
    if type(s) == "userdata" then return pcs(function() return s:ToString() end, nil) end
    return nil
end

-- ---- world enumeration ---------------------------------------------------

-- All flags: { {actor=, x=, y=, radius=, baseId=} }.
-- baseId comes from ConZBaseManager._bases (the BaseId->flag map); that key
-- equals SCUM.db base.id, so it's how the entitlement gate looks a flag up.
-- The flag ACTOR has no readable id property (recon pass 21), so _bases is the
-- only live source. Falls back to FindAllOf (baseId=nil) if the map is unreadable.
local function collectFlags()
    local mgr
    local mgrs = findAllAny("BP_ConZBaseManager_C", "ConZBaseManager")
    if mgrs then for i = 1, #mgrs do if isValid(mgrs[i]) then mgr = mgrs[i]; break end end end

    local radius = GG.config.flagRadiusOverride
    if not radius and mgr then
        local r = pcs(function() return mgr._flagInfluenceRadius end, nil)
        if r and r > 0 then radius = r end
    end
    radius = radius or 5000

    local flags, seen = {}, {}
    -- primary: ConZBaseManager._bases (BaseId -> flag actor)
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
    -- fallback: enumerate flag actors directly (no baseId -> can't gate by owner)
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

-- All named chests: { {inv=, owner=, name=, x=, y=} }
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

-- All loose (non-deployable, on-the-floor) items: { {item=, class=, x=, y=} }
local function collectLooseLoot()
    local out = {}
    local items = FindAllOf("Item")
    if items then for i = 1, #items do
        local it = items[i]
        if isValid(it) then
            local pc = presClass(it)
            if pc and pc:find("OnTheFloor", 1, true) and not isDeployable(it) then
                local x, y = presLoc(it)
                out[#out + 1] = { item = it, class = classOf(it), x = x, y = y }
            end
        end
    end end
    return out
end

-- Map each container to its contents: { [ownerFullName] = {ocls=, items={...}} }.
-- Contents are tracked item-side (presence InTheInventory -> _inventory -> owner),
-- so reverse it. Keyed by the owner's GetFullName() (stable across FindAllOf
-- passes, unlike userdata). Used by the sweep to empty a loose container.
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

-- One InventoryUserComponent to drive the move RPC (any online player's works).
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

-- category path (general..specific) for an item class, from config rules.
-- returns (path, isDefault) — isDefault true when no rule matched (fell to defaultPath).
local function categoryPath(cls)
    local low = cls:lower()
    for _, rule in ipairs(GG.config.rules or {}) do
        if rule.match and low:find(rule.match:lower(), 1, true) then return rule.path, false end
    end
    return GG.config.defaultPath, true
end

local function nameMatches(node, chestName)
    if not chestName then return false end
    local a, b = node:lower(), chestName:lower()
    if GG.config.nameContains then return b:find(a, 1, true) ~= nil end
    return a == b
end

-- pick a chest in `candidates` matching `path`, most-specific (end) first
local function matchChest(path, candidates)
    if not path then return nil end
    for i = #path, 1, -1 do
        local node = path[i]
        for _, c in ipairs(candidates) do
            if nameMatches(node, c.name) then return c, node end
        end
    end
    return nil
end

-- ---- entitlement gate (per-player primary, per-flag fallback) ------------
-- The flag owner isn't readable from the live actor, so the mod reads SCUM.db
-- read-only via the bundled sqlite3.exe to map baseId -> owner Steam64, keeps
-- its own store (entitlements.lua), and computes the enabled-baseId set in Lua.
-- All SQL is constant; the only untrusted input (a player name) is matched in
-- Lua against the user list, so there's no SQL/shell-injection surface.

-- ---- DB access via the bundled sqlite3.exe (read-only) -------------------
-- Every query below is a FIXED constant: no untrusted input is interpolated
-- into SQL or the command line. Player-name matching for add/remove is done
-- in Lua against the full user list, so there is zero SQL/shell-injection
-- surface. sqlite3.exe is fetched by install-libraries.ps1.
local OWNER_SQL = "SELECT b.id, up.user_id FROM base b JOIN user_profile up ON up.id=b.owner_user_profile_id WHERE b.is_owned_by_player=1;"
local USERS_SQL = "SELECT u.id, COALESCE(up.name,''), COALESCE(u.name,'') FROM user u LEFT JOIN user_profile up ON up.user_id=u.id;"
local STEAM64_PAT = "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$" -- 17 digits

local function dq(s) return '"' .. tostring(s) .. '"' end

-- run a fixed SELECT through sqlite3.exe; returns array-of-rows (each row an
-- array of pipe-split fields), or nil+err. Read-only; safe while the game runs.
function GG.dbRows(sql)
    local exe = (GG.config and GG.config.sqliteExe) or GG.sqliteExe
    local db = GG.config and GG.config.dbPath
    if not exe or not db then return nil, "sqlite/db path not configured" end
    -- Wrap the whole command in one extra pair of quotes: cmd.exe strips exactly
    -- one outer pair, leaving the inner quoting (which protects spaces in the
    -- exe/db paths) intact. 2>&1 lets us see sqlite errors on stdout.
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
-- pausedFlags = baseIds a player has paused (user 'goober pause'); a per-flag
-- opt-out applied on top of the admin entitlement (suppresses sorting there).
local function defaultStore() return { defaultEnabled = false, players = {}, flagOverrides = {}, pausedFlags = {} } end

function GG.loadStore()
    GG.store = defaultStore()
    local f = GG.storeFile and io.open(GG.storeFile, "r") or nil
    if not f then return end
    local src = f:read("*a"); f:close()
    local chunk = load(src, "@entitlements.lua")
    local ok, t = false, nil
    if chunk then ok, t = pcall(chunk) end
    if ok and type(t) == "table" then
        GG.store.defaultEnabled = (t.defaultEnabled == true)
        if type(t.players) == "table" then
            for _, s in ipairs(t.players) do GG.store.players[#GG.store.players + 1] = tostring(s) end
        end
        if type(t.flagOverrides) == "table" then
            for k, v in pairs(t.flagOverrides) do
                local id = math.tointeger(tonumber(k))
                if id ~= nil then GG.store.flagOverrides[id] = (v == true) end
            end
        end
        if type(t.pausedFlags) == "table" then
            for _, b in ipairs(t.pausedFlags) do
                local id = math.tointeger(tonumber(b))
                if id ~= nil then GG.store.pausedFlags[id] = true end
            end
        end
        if type(t.accessMessage) == "string" then GG.store.accessMessage = t.accessMessage end
    end
end

local function serializeStore(s)
    local out = {
        "-- GarbageGoober entitlement store. Written by the goober chat commands;",
        "-- hand-edits are fine (then 'goober reload'). players = Steam64 IDs.",
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
    if s.accessMessage ~= nil then
        out[#out + 1] = string.format("  accessMessage = %q,", tostring(s.accessMessage))
    end
    out[#out + 1] = "}"
    return table.concat(out, "\n") .. "\n"
end

function GG.saveStore()
    if not GG.store then return false end
    local f = GG.storeFile and io.open(GG.storeFile, "w") or nil
    if not f then GG.log("could not write store: " .. tostring(GG.storeFile)); return false end
    f:write(serializeStore(GG.store)); f:close()
    return true
end

local function tcount(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end

-- recompute GG.resolved.enabled (set of baseIds to sort) from ownerMap + store.
-- Precedence per base: per-flag override > player-entitled > global default.
local function recomputeEnabled()
    local s = GG.store or defaultStore()
    local owners = GG.ownerMap or {} -- { [baseId] = ownerSteam64 }
    local entitled = {}
    for _, sid in ipairs(s.players) do entitled[sid] = true end
    local consider = {}
    for baseId in pairs(owners) do consider[baseId] = true end
    for baseId in pairs(s.flagOverrides) do consider[baseId] = true end
    local paused = s.pausedFlags or {}
    -- enabledBases = the access decision (override > player > default), ignoring pause.
    -- enabled = enabledBases minus player-paused flags (what actually gets sorted).
    local enabledBases, enabled, n = {}, {}, 0
    for baseId in pairs(consider) do
        local ov = s.flagOverrides[baseId]
        local en
        if ov ~= nil then en = ov
        elseif owners[baseId] and entitled[owners[baseId]] then en = true
        else en = s.defaultEnabled end
        if en then
            enabledBases[baseId] = true
            if not paused[baseId] then enabled[baseId] = true; n = n + 1 end -- player pause overrides
        end
    end
    GG.resolved = {
        enabled = enabled,
        enabledBases = enabledBases,
        defaultEnabled = s.defaultEnabled,
        counts = { enabled = n, bases = tcount(owners), players = #s.players,
                   overrides = tcount(s.flagOverrides), paused = tcount(paused) },
    }
end

-- refresh the owner map from the DB (throttled by resyncIntervalMs) then
-- recompute the enabled set. force=true refreshes now. No-op (clears) if off.
function GG.ensureResolved(force)
    local cfg = GG.config or {}
    if not cfg.entitlementsEnabled then GG.resolved = nil; return true end
    if not GG.store then GG.loadStore() end
    local intervalSec = (cfg.resyncIntervalMs or 300000) / 1000
    local fresh = GG.ownerMap and GG.ownerMapAt and (os.time() - GG.ownerMapAt) < intervalSec
    if force or not fresh then
        local rows, err = GG.dbRows(OWNER_SQL)
        if rows then
            local m = {}
            for _, r in ipairs(rows) do
                local id = math.tointeger(tonumber(r[1]))
                if id ~= nil then m[id] = r[2] end
            end
            GG.ownerMap = m
            GG.ownerMapAt = os.time()
        else
            GG.log("entitlement DB read failed: " .. tostring(err))
        end
    end
    if not GG.ownerMap then GG.resolved = nil; return false end
    recomputeEnabled()
    return true
end

-- resolve a typed name/Steam64 -> { status, id, name, matches }.
-- status: ok | pregrant (valid id, not in DB yet) | ambiguous | notfound | dberror
function GG.resolvePlayer(arg)
    arg = trim(arg or "")
    if arg == "" then return { status = "notfound" } end
    local rows, err = GG.dbRows(USERS_SQL)
    if not rows then GG.log("resolvePlayer DB read failed: " .. tostring(err)); return { status = "dberror" } end
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

-- is this flag's loot allowed to be sorted? Fail-closed: if the gate is on but
-- we can't verify (no resolved set, or unknown baseId), do NOT sort.
local function flagEnabled(flag)
    if not (GG.config and GG.config.entitlementsEnabled) then return true end
    local r = GG.resolved
    if not r or not r.enabled then return false end
    local bid = flag.baseId
    if bid == nil then return false end
    return r.enabled[bid] == true
end

-- baseId of the flag the issuing admin is standing in (for "goober flag" w/o id)
local function currentFlagBaseId()
    local ctrl = GG.controller
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

-- "goober flag on|off|clear [baseId]" — baseId optional (defaults to the flag
-- the admin is standing in). Sets/clears the per-flag override in the store.
function GG.handleFlagCmd(rest)
    local mode, idtok = (rest or ""):match("^(%S*)%s*(%S*)$")
    mode = (mode or ""):lower()
    if mode ~= "on" and mode ~= "off" and mode ~= "clear" then
        GG.reply("usage: goober flag on|off|clear [baseId]  (no id = your current flag)")
        return
    end
    local baseId
    if idtok and idtok ~= "" then
        local n = tonumber(idtok)
        baseId = n and math.tointeger(n) or nil
        if not baseId then GG.reply("baseId must be a whole number"); return end
    else
        baseId = currentFlagBaseId()
        if not baseId then
            GG.reply("stand in the flag you mean, or give its id: goober flag " .. mode .. " <baseId>")
            return
        end
    end
    if not GG.store then GG.loadStore() end
    if mode == "clear" then
        if GG.store.flagOverrides[baseId] ~= nil then
            GG.store.flagOverrides[baseId] = nil
            GG.reply("cleared override on base " .. baseId .. " (back to player/default)")
        else
            GG.reply("base " .. baseId .. " had no override")
        end
    else
        GG.store.flagOverrides[baseId] = (mode == "on")
        GG.reply("base " .. baseId .. " override set to " .. mode:upper())
    end
    GG.saveStore()
    GG.ensureResolved(true)
end

-- list every entitled player + their owned base(s), the flag overrides, and the
-- net result. Reads the DB for names/owners; echoes to the issuer's chat.
function GG.cmdList()
    if not GG.store then GG.loadStore() end
    GG.ensureResolved(true)
    local s = GG.store
    GG.reply("GarbageGoober access (default: " .. (s.defaultEnabled and "ON" or "OFF") .. ")", true)
    local users = GG.dbRows(USERS_SQL) or {}
    local nameOf = {}
    for _, u in ipairs(users) do nameOf[u[1]] = (u[2] ~= "" and u[2] or u[3]) end
    GG.reply("enabled players (" .. #s.players .. "):", true)
    if #s.players == 0 then GG.reply("  (none)", true) end
    for _, sid in ipairs(s.players) do
        local bids = {}
        for baseId, owner in pairs(GG.ownerMap or {}) do if owner == sid then bids[#bids + 1] = baseId end end
        table.sort(bids)
        local where = #bids > 0 and ("base " .. table.concat(bids, ", ")) or "no base yet"
        GG.reply(string.format("  %s  %s  -> %s", sid, nameOf[sid] or "?", where), true)
    end
    local ovk = {}
    for k in pairs(s.flagOverrides) do ovk[#ovk + 1] = k end
    table.sort(ovk)
    GG.reply("flag overrides (" .. #ovk .. "):", true)
    if #ovk == 0 then GG.reply("  (none)", true) end
    for _, k in ipairs(ovk) do GG.reply("  base " .. k .. " -> " .. (s.flagOverrides[k] and "ON" or "OFF"), true) end
    local c = (GG.resolved and GG.resolved.counts) or {}
    GG.reply(string.format("result: %d of %d player-owned base(s) will be sorted", c.enabled or 0, c.bases or 0), true)
end

function GG.cmdStatus()
    if not GG.store then GG.loadStore() end
    GG.ensureResolved(true)
    local s = GG.store
    local c = (GG.resolved and GG.resolved.counts) or {}
    GG.reply(string.format("default=%s  players=%d  flag overrides=%d  paused=%d  -> %d/%d base(s) sorted",
        s.defaultEnabled and "ON" or "OFF", #s.players, tcount(s.flagOverrides), tcount(s.pausedFlags),
        c.enabled or 0, c.bases or 0), true)
    if GG.enabled == false then GG.reply("auto-sweep is PAUSED server-wide (pause-all active)", true) end
end

function GG.cmdAdd(who)
    if not GG.store then GG.loadStore() end
    local r = GG.resolvePlayer(who)
    if r.status == "dberror" then GG.reply("DB read failed (see log)"); return end
    if r.status == "notfound" then GG.reply("no player matched '" .. who .. "' (try their Steam64 ID)"); return end
    if r.status == "ambiguous" then
        GG.reply("'" .. who .. "' matches several players - add by Steam64:", true)
        for sid, nm in pairs(r.matches) do GG.reply("  " .. sid .. "  " .. tostring(nm), true) end
        return
    end
    local sid, nm = r.id, r.name
    for _, p in ipairs(GG.store.players) do
        if p == sid then GG.reply((nm or sid) .. " is already enabled"); return end
    end
    GG.store.players[#GG.store.players + 1] = sid
    GG.saveStore()
    GG.ensureResolved(true)
    local bids = {}
    for baseId, owner in pairs(GG.ownerMap or {}) do if owner == sid then bids[#bids + 1] = baseId end end
    table.sort(bids)
    local tail
    if #bids > 0 then tail = "now sorting base " .. table.concat(bids, ", ")
    elseif r.status == "pregrant" then tail = "not seen on this server yet - applies when they build"
    else tail = "no base owned yet" end
    GG.reply("enabled " .. (nm or sid) .. " (" .. sid .. ") - " .. tail)
end

function GG.cmdRemove(who)
    if not GG.store then GG.loadStore() end
    who = trim(who)
    local target
    for _, p in ipairs(GG.store.players) do if p == who then target = who; break end end
    if not target then
        local r = GG.resolvePlayer(who)
        if r.status == "ambiguous" then
            GG.reply("'" .. who .. "' matches several players - remove by Steam64:", true)
            for sid, nm in pairs(r.matches) do GG.reply("  " .. sid .. "  " .. tostring(nm), true) end
            return
        end
        if r.id then
            for _, p in ipairs(GG.store.players) do if p == r.id then target = r.id; break end end
        end
    end
    if not target then GG.reply("'" .. who .. "' is not in the enabled list"); return end
    local kept = {}
    for _, p in ipairs(GG.store.players) do if p ~= target then kept[#kept + 1] = p end end
    GG.store.players = kept
    GG.saveStore()
    GG.ensureResolved(true)
    GG.reply("removed " .. target .. " from enabled players")
end

function GG.cmdDefault(mode)
    if not GG.store then GG.loadStore() end
    GG.store.defaultEnabled = (mode == "on")
    GG.saveStore()
    GG.ensureResolved(true)
    local c = (GG.resolved and GG.resolved.counts) or {}
    GG.reply(string.format("global default set to %s - %d/%d base(s) now sorted", mode:upper(), c.enabled or 0, c.bases or 0))
end

-- The "not enabled" message a player sees. Source: a runtime override set via
-- 'goober set-access-msg' (persisted in the store) takes priority; otherwise
-- Config.notEnabledMessage. Value meaning: "default" = built-in line; nil = stay
-- silent (pretend the feature isn't there); off/none/silent = also silent; any
-- other string/list = that custom message.
local DEFAULT_NOT_ENABLED = "sorting isn't enabled for your base — ask an admin to enable it"
local SILENT_TOKENS = { off = true, none = true, silent = true, ["nil"] = true, [""] = true }

-- returns (value, source): value is string|table|nil; source is "command" or "config"
local function accessSetting()
    if GG.store and GG.store.accessMessage ~= nil then return GG.store.accessMessage, "command" end
    return (GG.config and GG.config.notEnabledMessage), "config"
end

local function replyNotEnabled()
    local m = accessSetting()
    if m == nil then return end -- silent: pretend the feature isn't there
    if type(m) == "string" then
        local low = m:lower()
        if SILENT_TOKENS[low] then return end
        if low == "default" then GG.reply(DEFAULT_NOT_ENABLED, true); return end
        GG.reply(m, true)
    elseif type(m) == "table" then
        for _, l in ipairs(m) do GG.reply(tostring(l), true) end
    end
end

-- is the issuer's current flag enabled for sorting (access decision, ignoring
-- pause)? nil baseId = not in a flag. Used to gate the user action commands.
local function flagEnabledForIssuer(baseId)
    if not (GG.config and GG.config.entitlementsEnabled) then return true end
    return (GG.resolved and GG.resolved.enabledBases and GG.resolved.enabledBases[baseId]) == true
end

-- user 'goober pause'/'goober resume' — toggle a per-flag sorting opt-out for the
-- flag the issuer is standing in (anyone with access to the flag can toggle it).
function GG.cmdPauseFlag(pause)
    if not GG.store then GG.loadStore() end
    GG.store.pausedFlags = GG.store.pausedFlags or {} -- older in-memory stores lack this field
    local baseId = currentFlagBaseId()
    if not baseId then
        GG.reply("stand in the flag you want to " .. (pause and "pause" or "resume") .. " sorting for")
        return
    end
    GG.ensureResolved(false)
    if not flagEnabledForIssuer(baseId) then replyNotEnabled(); return end
    if pause then
        GG.store.pausedFlags[baseId] = true
        GG.reply("sorting PAUSED for your flag (base " .. baseId .. ") — 'goober resume' to undo")
    elseif GG.store.pausedFlags[baseId] then
        GG.store.pausedFlags[baseId] = nil
        GG.reply("sorting RESUMED for your flag (base " .. baseId .. ")")
    else
        GG.reply("your flag (base " .. baseId .. ") was not paused")
    end
    GG.saveStore()
    GG.ensureResolved(true)
end

-- admin 'goober get-access-msg' — show the current "not enabled" message + source.
function GG.cmdGetAccessMsg()
    if not GG.store then GG.loadStore() end
    local m, src = accessSetting()
    if m == nil then GG.reply("access-msg [" .. src .. "]: SILENT (non-enabled players see nothing)"); return end
    if type(m) == "table" then
        GG.reply("access-msg [" .. src .. "] (" .. #m .. " lines):")
        for _, l in ipairs(m) do GG.reply("  " .. tostring(l), true) end
        return
    end
    local low = tostring(m):lower()
    if SILENT_TOKENS[low] then
        GG.reply("access-msg [" .. src .. "]: SILENT (non-enabled players see nothing)")
    elseif low == "default" then
        GG.reply("access-msg [" .. src .. "]: default => " .. DEFAULT_NOT_ENABLED)
    else
        GG.reply("access-msg [" .. src .. "]: " .. tostring(m))
    end
end

-- admin 'goober set-access-msg <text|default|off|reset>' — set the message (stored
-- persistently, overrides Config). default=built-in, off/none/silent=show nothing,
-- reset=clear the override and fall back to Config.notEnabledMessage.
function GG.cmdSetAccessMsg(text)
    if not GG.store then GG.loadStore() end
    text = trim(text or "")
    if text == "" then GG.reply("usage: goober set-access-msg <text> | default | off | reset"); return end
    local low = text:lower()
    if low == "reset" then
        GG.store.accessMessage = nil
        GG.saveStore()
        GG.reply("access-msg reset — now using Config.lua's notEnabledMessage")
        return
    end
    GG.store.accessMessage = text
    GG.saveStore()
    if SILENT_TOKENS[low] then
        GG.reply("access-msg set to SILENT — non-enabled players will see nothing")
    elseif low == "default" then
        GG.reply("access-msg set to the built-in default")
    else
        GG.reply("access-msg set to: " .. text)
    end
end

-- Recursively move a loose container's contents into matching category chests
-- (candidates = chests in the same flag). Nested containers are unpacked first,
-- then sorted themselves. Returns (moved, remaining): remaining = contents that
-- matched no chest (left inside). Uses the same AddOrMoveEntry move as the sort.
-- NOTE: drop-to-floor RPCs (DropItem/DropItemAt) no-op from a server mod, so we
-- move contents straight to their destination instead of dropping them.
local function emptyContainerInto(iuc, container, contentsMap, candidates, depth)
    local key = fullName(container)
    local rec = key and contentsMap[key]
    if not rec then return 0, 0 end
    local moved, remaining = 0, 0
    for _, child in ipairs(rec.items) do
        if depth < 6 then
            local m = emptyContainerInto(iuc, child, contentsMap, candidates, depth + 1)
            moved = moved + m
        end
        local cls = classOf(child)
        local path = categoryPath(cls)
        local chest = matchChest(path, candidates)
        if chest then
            local ok = pcall(function()
                iuc:Server_InventoryComponent_AddOrMoveEntry(chest.inv, child, { Value = AUTOPLACE })
            end)
            if ok then
                moved = moved + 1
                GG.log(string.format("  emptied %s -> chest '%s'", cls, chest.name))
            else
                remaining = remaining + 1
                GG.log(string.format("  ERROR emptying %s -> '%s'", cls, chest.name))
            end
        else
            remaining = remaining + 1
        end
    end
    return moved, remaining
end

-- ---- the sweep -----------------------------------------------------------
-- onlyBaseId (optional): restrict the sweep to that one flag (for the user
-- 'goober now', which sorts just the flag the issuer is standing in).
function GG.sweep(onlyBaseId)
    local iuc = findIUC()
    if not iuc then
        GG.log("sweep: no InventoryUserComponent (no player online / near) — nothing live to sort, skipping.")
        return "no player nearby — nothing to sort"
    end

    -- refresh the per-player/per-flag entitlement set (throttled; see Config)
    GG.ensureResolved(false)
    if GG.config.entitlementsEnabled and not GG.resolved then
        GG.log("sweep: gate ON but no enabled set (DB read failed?) — NOT sorting " ..
            "(fail-closed). Check sqlite3.exe/dbPath; run 'goober status'.")
    end

    local flags, radius = collectFlags()
    if onlyBaseId then
        local only = {}
        for _, f in ipairs(flags) do if f.baseId == onlyBaseId then only[#only + 1] = f end end
        flags = only
    end
    if #flags == 0 then
        GG.log("sweep: no flags found in world — skipping.")
        return "no flags found"
    end
    local chests = collectChests()
    local items = collectLooseLoot()
    local contentsMap = GG.config.emptyContainers and collectContainerContents() or {}

    GG.log(string.format("sweep start: %d loose item(s), %d chest(s), %d flag(s), radius=%dcm%s",
        #items, #chests, #flags, radius,
        GG.config.entitlementsEnabled and (" | gate ON (" ..
            (GG.resolved and GG.resolved.counts and GG.resolved.counts.enabled or 0) .. " base(s) enabled)") or " | gate OFF"))

    local moved, noFlag, disabled, noChest, noMatch, errs = 0, 0, 0, 0, 0, 0
    local emptied = 0 -- items pulled out of containers into chests
    local unmapped = {} -- distinct item classes that hit no rule (tree gaps)
    for _, it in ipairs(items) do
        local flag = flagFor(it.x, it.y, flags)
        if not flag then
            noFlag = noFlag + 1 -- POI / outside any flag — not ours to touch
        elseif not flagEnabled(flag) then
            disabled = disabled + 1 -- flag's owner not entitled (or per-flag override OFF)
        else
            -- candidate chests = those inside the SAME flag's influence
            local candidates = {}
            for _, c in ipairs(chests) do
                if c.name and c.x and hdist(c.x, c.y, flag.x, flag.y) <= flag.radius then
                    candidates[#candidates + 1] = c
                end
            end
            if #candidates == 0 then
                noChest = noChest + 1
            else
                -- if this loose item is itself a container, empty its contents
                -- into the flag's chests first, then sort the emptied container.
                if GG.config.emptyContainers then
                    local rec = contentsMap[fullName(it.item)]
                    if rec then
                        GG.log(string.format("  unpacking %s (%d item(s) inside)", it.class, #rec.items))
                        emptied = emptied + emptyContainerInto(iuc, it.item, contentsMap, candidates, 0)
                    end
                end
                local path, isDefault = categoryPath(it.class)
                if isDefault then unmapped[it.class] = true end
                local chest, node = matchChest(path, candidates)
                if not chest then
                    noMatch = noMatch + 1
                    GG.log(string.format("  no chest for %s (path=%s)", it.class,
                        path and ("{" .. table.concat(path, ">") .. "}") or "<none>"))
                else
                    local ok, e = pcall(function()
                        iuc:Server_InventoryComponent_AddOrMoveEntry(chest.inv, it.item, { Value = AUTOPLACE })
                    end)
                    if ok then
                        moved = moved + 1
                        GG.log(string.format("  moved %s -> chest '%s'", it.class, chest.name))
                    else
                        errs = errs + 1
                        GG.log(string.format("  ERROR moving %s -> '%s': %s", it.class, chest.name, tostring(e)))
                    end
                end
            end
        end
    end

    GG.log(string.format("sweep done: moved=%d  emptied=%d  disabled=%d  outside-flag=%d  no-chest-in-flag=%d  no-name-match=%d  errors=%d",
        moved, emptied, disabled, noFlag, noChest, noMatch, errs))
    local gaps = {}
    for cls in pairs(unmapped) do gaps[#gaps + 1] = cls end
    if #gaps > 0 then
        table.sort(gaps)
        GG.log("  unmapped (no rule -> default): " .. table.concat(gaps, ", "))
    end
    return string.format("moved %d  emptied %d  (%d disabled, %d no-chest, %d no-match)", moved, emptied, disabled, noChest, noMatch)
end

-- goober classes — dump every distinct item class currently in the world and
-- how it maps, to build/refine the category tree from real names. Read-only.
function GG.dumpClasses()
    local items = FindAllOf("Item")
    local seen, rows = {}, {}
    if items then for i = 1, #items do
        local it = items[i]
        if isValid(it) then
            local c = classOf(it)
            if c ~= "?" and not seen[c] then
                seen[c] = true
                local p, isDef = categoryPath(c)
                local tag = isDeployable(it) and "   [deployable - skipped]"
                    or (isDef and "   [UNMAPPED]" or "")
                rows[#rows + 1] = string.format("  %-44s -> %s%s", c,
                    p and table.concat(p, ">") or "<none>", tag)
            end
        end
    end end
    table.sort(rows)
    GG.log(string.format("class dump: %d distinct item class(es) live --", #rows))
    for _, r in ipairs(rows) do GG.log(r) end
    GG.log("class dump done.")
    return #rows
end

-- Build the category tree from the config paths, at ANY depth. Returns:
--   roots[node]=true       (a path's first element — top-level categories)
--   childrenOf[node]={..}  (direct children; every node is a key, leaves map to {})
--   parentOf[child]=parent (nil for roots)
local function buildCategoryTree()
    local roots, childrenOf, parentOf = {}, {}, {}
    local function addPath(p)
        if not p or not p[1] then return end
        roots[p[1]] = true
        for i = 1, #p do childrenOf[p[i]] = childrenOf[p[i]] or {} end
        for i = 2, #p do parentOf[p[i]] = p[i - 1]; childrenOf[p[i - 1]][p[i]] = true end
    end
    for _, rule in ipairs(GG.config.rules or {}) do addPath(rule.path) end
    addPath(GG.config.defaultPath)
    return roots, childrenOf, parentOf
end

-- goober chests — audit the chests in the issuer's CURRENT flag: for each, show
-- the category-tree node its custom name maps to (and that node's parent), or
-- [UNMATCHED] if the name matches no node (so it never receives sorted loot).
-- Read-only. Echoes to chat (capped) and full to the log.
function GG.dumpChests()
    -- where is the admin standing -> which flag
    local ctrl = GG.controller
    local ax, ay
    if ctrl ~= nil then
        local pawn = pcs(function() return ctrl:K2_GetPawn() end, nil)
        if not isValid(pawn) then pawn = pcs(function() return ctrl.Pawn end, nil) end
        if isValid(pawn) then ax, ay = actorLoc(pawn) end
    end
    if not ax then GG.log("chests: couldn't get your location"); GG.reply("couldn't get your location"); return end
    local flags = collectFlags()
    local flag = flagFor(ax, ay, flags)
    if not flag then GG.log("chests: you are not inside any flag zone"); GG.reply("you're not in a flag zone"); return end

    -- category tree from the live config (any depth); lowercase lookup for names
    local _, childrenOf, parentOf = buildCategoryTree()
    local nodeByLower = {}
    for nm in pairs(childrenOf) do nodeByLower[nm:lower()] = nm end

    GG.log("chests in your flag --")
    local n, shownChat = 0, 0
    for _, c in ipairs(collectChests()) do
        if c.x and hdist(c.x, c.y, flag.x, flag.y) <= flag.radius then
            n = n + 1
            local nm, line = c.name, nil
            if nm == nil or nm == "" then
                line = "  <unnamed chest> -> [UNMATCHED]"
            else
                local node = nodeByLower[nm:lower()]
                if node then
                    local par = parentOf[node]
                    line = par and string.format("  '%s' -> parent: %s", nm, par)
                        or string.format("  '%s' -> (top-level, catch-all)", nm)
                else
                    line = string.format("  '%s' -> [UNMATCHED]", nm)
                end
            end
            GG.log(line)
            if shownChat < 15 then GG.reply(line, true); shownChat = shownChat + 1 end
        end
    end
    if n == 0 then
        GG.log("  (no chests in this flag)"); GG.reply("no chests in your flag")
    elseif shownChat < n then
        GG.reply(string.format("...(%d chests total)", n))
    end
    GG.log("chests done.")
end

-- goober types [name] — with no arg, list the top-level categories (trader
-- groups); with a top-level category name, list its child categories; otherwise
-- "Not a category". Derived live from the config tree.
function GG.dumpTypes(arg)
    local roots, childrenOf, parentOf = buildCategoryTree()
    local function sortedKeys(tbl)
        local k = {}
        for name in pairs(tbl or {}) do k[#k + 1] = name end
        table.sort(k)
        return k
    end
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "" then
        -- the implicit root: top-level categories are its children
        GG.reply("(top level): parent=none children=[" .. table.concat(sortedKeys(roots), ", ") .. "]")
        return
    end
    -- resolve the node name case-insensitively
    local node
    for name in pairs(childrenOf) do if name:lower() == arg:lower() then node = name; break end end
    if not node then
        GG.reply("Not a category: " .. arg)
        return
    end
    GG.reply(node .. ": parent=" .. (parentOf[node] or "none") ..
        " children=[" .. table.concat(sortedKeys(childrenOf[node]), ", ") .. "]")
end

-- ---- admin chat commands -------------------------------------------------
-- Build the help text (commands + descriptions), shared by the log (printHelp)
-- and the in-game reply (GG.replyHelp). Built fresh so the live sweep interval
-- and trigger word are accurate.
-- includeAdmin=true also lists the admin commands (used for the log + when an
-- admin issues the help). Regular users only see the user commands.
local function helpLines(includeAdmin)
    local sec = math.floor(((GG.config and GG.config.sweepIntervalMs) or 60000) / 1000)
    local h = {
        "GarbageGoober — auto-sorts loose ground loot inside a flag into chests",
        "named after each item's category (e.g. Ammo, Food, Armorer).",
        "Runs automatically every " .. sec .. "s. Commands (type in normal chat):",
        "  goober              — show this help",
        "  goober now          — sort the loose loot in your flag right now",
        "  goober pause/resume — stop / resume auto-sorting your flag",
        "  goober types        — list categories ('goober types <name>' = its sub-types)",
        "  goober chests       — audit chests in your flag: each chest's category",
    }
    if includeAdmin then
        h[#h + 1] = "  -- admin --"
        h[#h + 1] = "  goober pause-all/resume-all — pause / resume the automatic sweep server-wide"
        h[#h + 1] = "  goober classes      — list every live item class + its category (to the log)"
        h[#h + 1] = "  goober reload       — reload Config.lua (categories/settings), then sort once"
        if GG.config and GG.config.entitlementsEnabled then
            h[#h + 1] = "  -- admin: access control (per player; per flag = fallback) --"
            h[#h + 1] = "  goober list         — enabled players / flag overrides / result"
            h[#h + 1] = "  goober status       — one-line access summary"
            h[#h + 1] = "  goober add/remove <player> — enable / disable the sorter for a player (name or Steam64)"
            h[#h + 1] = "  goober flag on|off|clear [baseId] — per-flag override (blank=your flag)"
            h[#h + 1] = "  goober default on|off — sort every flag by default, or none"
            h[#h + 1] = "  goober get-access-msg / set-access-msg <text|default|off|reset>"
        end
    end
    return h
end
local function printHelp() for _, l in ipairs(helpLines(true)) do GG.log(l) end end

-- Reply in-game (chat box) to the admin who issued the current chat command,
-- via the Chat_Client_SendMessageToChat server->client RPC on their channel.
-- Channel 6 = EChatType.ServerMessage; net-id passed as an empty struct.
-- No-op if we have no live channel (e.g. timer sweeps). pcall-guarded; a failure
-- just means log-only.
local CHAT_SERVERMESSAGE = 6
function GG.reply(text, raw)
    local chan, ctrl = GG.channel, GG.controller
    if chan == nil then return false end
    local ps = nil
    if ctrl ~= nil then ps = pcs(function() return ctrl.PlayerState end, nil) end
    local msg = raw and tostring(text) or ("[GarbageGoober] " .. tostring(text))
    local ok = pcall(function()
        chan:Chat_Client_SendMessageToChat(msg, ps, {}, CHAT_SERVERMESSAGE, false)
    end)
    return ok
end

-- send the help to the issuer's chat; admins also see the admin commands.
function GG.replyHelp() for _, l in ipairs(helpLines(GG.callerIsAdmin == true)) do GG.reply(l, true) end end

-- dispatch "goober <arg>" (arg = text after "goober", already prefix-stripped)
-- commands open to any player; everything else is admin-only (gated below).
local USER_CMDS = { [""] = true, types = true, chests = true, now = true, pause = true, resume = true }

function GG.handleCommand(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local word = (arg == "") and "" or (arg:match("^(%S+)") or "")
    if not USER_CMDS[word] and (not GG.config or GG.config.requireAdmin ~= false) and not GG.callerIsAdmin then
        GG.log("ignored 'goober " .. arg .. "' — admin-only (sender not admin)")
        GG.reply("'goober " .. word .. "' is admin-only")
        return
    end
    if arg == "" then
        printHelp()
        GG.replyHelp()
    elseif arg == "now" then
        -- user: sort only the flag the issuer is standing in (if it's enabled)
        local baseId = currentFlagBaseId()
        if GG.enabled == false then
            GG.reply("sorting is paused server-wide (an admin ran 'goober pause-all')")
        elseif not baseId then
            GG.reply("stand in your flag, then 'goober now' to sort it")
        else
            GG.ensureResolved(false)
            local r = GG.resolved
            local gateOn = GG.config.entitlementsEnabled
            local sortable = (not gateOn) or (r and r.enabled and r.enabled[baseId] == true)
            if sortable then
                GG.log("manual sweep of base " .. baseId .. " (goober now)")
                local ok, s = pcall(GG.sweep, baseId)
                GG.reply(ok and (s or "swept") or "sweep error (see log)")
            elseif r and r.enabledBases and r.enabledBases[baseId] then
                -- enabled, but the owner paused it (not-enabled would take precedence above)
                GG.reply("sorting is paused for your base — 'goober resume' to turn it back on")
            else
                replyNotEnabled()
            end
        end
    elseif arg == "classes" then
        GG.log("dumping distinct live item classes (goober classes)")
        local n = 0
        if type(GG.dumpClasses) == "function" then local ok, r = pcall(GG.dumpClasses); if ok and r then n = r end end
        GG.reply(n .. " item classes found")
    elseif arg == "chests" then
        GG.log("auditing chests in your flag (goober chests)")
        if type(GG.dumpChests) == "function" then pcall(GG.dumpChests) end
    elseif arg == "types" then
        if type(GG.dumpTypes) == "function" then pcall(GG.dumpTypes, "") end
    elseif arg:sub(1, 6) == "types " then
        if type(GG.dumpTypes) == "function" then pcall(GG.dumpTypes, arg:sub(7)) end
    elseif arg == "reload" then
        if GG.reload and GG.reload() then
            -- GG.reload re-ran Config + engine (local categories); now pull the
            -- latest rules from the remote URL (if configured) on top.
            GG.loadCategories(true)
            local s2 = tostring(GG.categoriesSource or "")
            local where = s2:find("^remote") and "pulled remote rules"
                or (s2:find("^cache") and "used cached rules" or "used local rules")
            GG.log("reloaded; running one sweep")
            local ok, s = pcall(GG.sweep)
            GG.reply("reloaded (" .. where .. ") — " .. (ok and (s or "swept") or "sweep error"))
        else
            GG.reply("reload FAILED (see log)")
        end
    elseif arg == "pause" then
        GG.cmdPauseFlag(true)
    elseif arg == "resume" then
        GG.cmdPauseFlag(false)
    elseif arg == "pause-all" then
        GG.enabled = false; GG.log("global auto-sweep PAUSED (pause-all)"); GG.reply("auto-sweep paused server-wide")
    elseif arg == "resume-all" then
        GG.enabled = true; GG.log("global auto-sweep RESUMED (resume-all)"); GG.reply("auto-sweep resumed server-wide")
    elseif arg == "list" then
        GG.log("entitlement list (goober list)"); GG.cmdList()
    elseif arg == "status" then
        GG.cmdStatus()
    elseif arg:sub(1, 4) == "add " then
        local who = trim(arg:sub(5))
        if who == "" then GG.reply("usage: goober add <player name or Steam64>") else GG.cmdAdd(who) end
    elseif arg:sub(1, 7) == "remove " then
        local who = trim(arg:sub(8))
        if who == "" then GG.reply("usage: goober remove <player name or Steam64>") else GG.cmdRemove(who) end
    elseif arg == "flag" or arg:sub(1, 5) == "flag " then
        GG.handleFlagCmd(trim(arg:sub(5)))
    elseif arg:sub(1, 8) == "default " then
        local m = trim(arg:sub(9)):lower()
        if m ~= "on" and m ~= "off" then GG.reply("usage: goober default on|off") else GG.cmdDefault(m) end
    elseif arg == "get-access-msg" then
        GG.cmdGetAccessMsg()
    elseif arg == "set-access-msg" or arg:sub(1, 15) == "set-access-msg " then
        GG.cmdSetAccessMsg(arg:sub(16))
    else
        GG.log("unrecognised command 'goober " .. arg .. "'")
        GG.reply("Command unrecognised: '" .. arg .. "'")
        GG.reply("Type 'goober' for a list of valid commands")
    end
end

-- Called from main.lua's chat hook with the live RemoteUnrealParams for
-- Chat_Server_BroadcastChatMessage(Message, Channel). If the message is one of
-- our commands ("goober ..."), handle it. We do NOT mutate the message (live
-- UFunction-arg mutation crashes — see gotchas), so it still shows in chat.
-- Per-command access control happens in handleCommand: a few read-only commands
-- (help/types/chests) are open to any player; the rest require admin (unless
-- config.requireAdmin=false). We resolve the caller's admin status here.
function GG.onChatMessage(self, messageParam)
    local msg = ""
    pcall(function() msg = messageParam:get():ToString() end)
    if type(msg) ~= "string" or msg == "" then return end
    local trig = ((GG.config and GG.config.chatTrigger) or "goober"):lower()
    local low = msg:lower()
    if low ~= trig and low:sub(1, #trig + 1) ~= (trig .. " ") then return end -- not ours
    local chan = pcs(function() return self:get() end, nil)
    local ctrl = chan and pcs(function() return chan:GetOuter() end, nil) or nil
    GG.channel = chan
    GG.controller = ctrl
    GG.callerIsAdmin = (ctrl ~= nil) and (pcs(function() return ctrl:IsUserAdmin() end, false) == true)
    GG.handleCommand((#msg <= #trig) and "" or msg:sub(#trig + 2))
end

-- ---- category rules: loaded from categories.yaml (data, not Lua) ----------
-- Minimal YAML reader for the merged-run flat-list subset we ship/emit:
--   default: [A, B]            -- a flow seq (or nil/~/none/empty => no default)
--   rules:
--     - path: [A, B]           -- flow seq
--       match: [tok, tok, ...] -- flow seq; MAY wrap across lines
-- Not a general YAML parser — just enough for this file. Returns (rules,
-- defaultPath): rules is the FLAT, expanded shape the matcher already uses
-- (array of { match = token, path = {...} }), one entry per token, in order.
local function parseCategoriesYaml(text)
    -- 1. split into physical lines; drop CRs, full-line comments, blanks, and
    --    trailing inline comments (no rule token ever contains '#').
    local raw = {}
    for line in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("\r$", "")
        local fns = line:match("^%s*(%S)")
        if fns ~= nil and fns ~= "#" then
            raw[#raw + 1] = line:gsub("%s+#.*$", "")
        end
    end
    -- 2. merge continuation lines so each logical line has balanced [] brackets
    --    (a flow seq may wrap over several physical lines).
    local logical, buf = {}, nil
    for _, line in ipairs(raw) do
        buf = buf and (buf .. " " .. line:gsub("^%s+", "")) or line
        local _, o = buf:gsub("%[", "")
        local _, c = buf:gsub("%]", "")
        if o <= c then logical[#logical + 1] = buf; buf = nil end
    end
    if buf then logical[#logical + 1] = buf end
    -- 3. helpers
    local function splitFlow(inside)
        local out = {}
        for tok in (inside .. ","):gmatch("(.-),") do
            tok = tok:gsub("^%s+", ""):gsub("%s+$", "")
            tok = tok:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
            if tok ~= "" then out[#out + 1] = tok end
        end
        return out
    end
    -- value after `<key>:` on a (possibly dash-led) line -> (list, "list") or
    -- (scalar, "scalar"); nil if the key isn't on this line.
    local function valueAfter(line, key)
        local v = line:match("^%s*%-?%s*" .. key .. "%s*:%s*(.*)$")
        if not v then return nil end
        local inside = v:match("^%[(.*)%]%s*$")
        if inside then return splitFlow(inside), "list" end
        return (v:gsub("%s+$", "")), "scalar"
    end
    -- 4. walk logical lines
    local rules, defaultPath, curPath = {}, nil, nil
    for _, line in ipairs(logical) do
        local t = line:gsub("^%s+", "")
        if t:match("^default%s*:") then
            local v, kind = valueAfter(line, "default")
            if kind == "list" and v and #v > 0 then defaultPath = v else defaultPath = nil end
        elseif t:match("^rules%s*:") then
            -- section header; nothing to capture
        elseif t:match("^%-?%s*path%s*:") then
            curPath = (valueAfter(line, "path"))
        elseif t:match("^match%s*:") then
            local toks = valueAfter(line, "match")
            if curPath and toks then
                for _, tok in ipairs(toks) do rules[#rules + 1] = { match = tok, path = curPath } end
            end
        end
    end
    return rules, defaultPath
end

-- Fetch a URL to a string via curl (the Lua VM has no HTTP, so we shell out the
-- same way the DB reader calls sqlite3). Best-effort: returns (body) or
-- (nil, err). Appends a cache-buster because gist/raw CDN caches a few minutes.
function GG.fetchUrl(url)
    local exe = (GG.config and GG.config.curlExe) or "curl"
    local bust = (url:find("?", 1, true) and "&" or "?") .. "cb=" .. tostring(os.time())
    local inner = string.format("%s -fsSL --max-time 15 %s", dq(exe), dq(url .. bust))
    local h = io.popen('"' .. inner .. '"', "r")
    if not h then return nil, "io.popen failed" end
    local body = h:read("*a")
    h:close()
    if not body or body == "" then return nil, "empty response (offline / 404 / no curl?)" end
    return body
end

-- Load category rules into GG.config.rules / GG.config.defaultPath.
--   remote=true  (only 'goober reload'): fetch config.remoteCategoriesUrl first;
--                on success cache it to <modDir>\categories.cache.yaml.
--   remote=false (boot / engine load): never touch the network — use the cache
--                from the last successful pull, then embedded, then bundled.
-- Full source order: [remote if asked] -> disk cache -> embedded GG.categoriesYaml
-- (eval build) -> bundled <modDir>\Scripts\categories.yaml (dev). A parse that
-- yields zero rules is rejected (keeps current rules) so a bad/truncated fetch
-- never wipes sorting. Boot stays offline-safe and instant; 'goober reload' is
-- the explicit "pull the latest rules" action.
function GG.loadCategories(remote)
    GG.config = GG.config or {}
    local cacheFile = GG.modDir and (GG.modDir .. [[\categories.cache.yaml]]) or nil
    local text, src

    local url = GG.config.remoteCategoriesUrl
    if remote and type(url) == "string" and url ~= "" then
        local body, err = GG.fetchUrl(url)
        if body then
            text, src = body, "remote " .. url
            if cacheFile then
                local f = io.open(cacheFile, "w")
                if f then f:write(body); f:close() end
            end
        else
            GG.log("categories: remote fetch failed (" .. tostring(err) .. ") — trying cache/local")
        end
    end

    if not text and cacheFile then
        local f = io.open(cacheFile, "r")
        if f then local c = f:read("*a"); f:close(); if c and c ~= "" then text, src = c, "cache " .. cacheFile end end
    end

    if not text and GG.categoriesYaml then text, src = GG.categoriesYaml, "embedded" end

    if not text then
        local p = GG.modDir and (GG.modDir .. [[\Scripts\categories.yaml]]) or nil
        local f = p and io.open(p, "r") or nil
        if f then text = f:read("*a"); f:close(); src = p end
    end

    if not text then GG.log("categories: no source available — keeping existing rules"); return false end

    local ok, rules, defaultPath = pcall(parseCategoriesYaml, text)
    if not ok or type(rules) ~= "table" or #rules == 0 then
        GG.log("categories: parse failed/empty from " .. tostring(src) .. " (" .. tostring(rules) .. ") — keeping existing rules")
        return false
    end
    GG.config.rules = rules
    GG.config.defaultPath = defaultPath
    GG.categoriesSource = src
    GG.log(string.format("categories loaded from %s: %d rule(s), default=%s", src, #rules,
        defaultPath and table.concat(defaultPath, ">") or "nil (leave unmatched in place)"))
    return true
end

GG.loadCategories(false)   -- boot/reload load: local/cache only; 'goober reload' pulls remote

GG.log("sorter.lua loaded (sweep engine ready).")
