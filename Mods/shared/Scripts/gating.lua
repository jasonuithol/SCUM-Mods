-- gating.lua — shared "gating" library for SCUM server-side UE4SS mods
-- (GarbageGoober, FlagUpkeep, ...). NOT a mod itself (this folder is not in
-- mods.txt, so UE4SS never auto-loads it); each mod's main.lua reads + runs this
-- file and calls Gating.attach(M, opts).
--
-- It provides the parts every flag-scoped, entitlement-gated, chat-driven mod
-- needs, installed onto the mod's namespace table M:
--   * safe-reflection helpers (M.pcs/isValid/classOf/fullName/xyz/.../nameMatches)
--   * world enumeration (M.collectFlags/collectChests/collectContainerContents/
--     findIUC/flagFor)
--   * a read-only SCUM.db reader (M.dbRows) — all SQL constant, zero injection
--   * the per-player + per-flag + default entitlement store, resolution, and the
--     common access-control chat commands (add/remove/list/status/flag/default/
--     pause/resume/get-set-access-msg) + the chat reply + onChatMessage hook entry
--
-- The mod keeps its OWN: action (sweep/upkeep), help text, handleCommand dispatch
-- (which calls these M.cmd* plus the mod's own commands), config, and any extra
-- store fields (declared via opts.storeExtra so this lib (de)serialises them).
--
-- Requires on M before attach: M.log(msg), M.modDir, M.sqliteExe, M.storeFile,
-- and M.config (the loaded Config table). opts (all optional):
--   storeExtra      = { fieldName = "floatmap"|"intmap", ... } extra store maps
--                     (id -> number); core fields are always handled.
--   defaultNotEnabled = string shown for the "not enabled" default message.
--   statusExtra     = function(M) -> nil; emits extra 'status' lines via M.reply.

local Gating = {}

function Gating.attach(M, opts)
    opts = opts or {}
    local cfg = function() return M.config or {} end

    -- ===== safe-reflection helpers =====================================
    local function pcs(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end; return d end
    local function isValid(o) return o ~= nil and pcs(function() return o:IsValid() end, false) end
    local function classOf(o) return pcs(function() return o:GetClass():GetFName():ToString() end, "?") end
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
    -- substring/exact name match against config.nameContains
    local function nameMatches(a, chestName)
        if not chestName then return false end
        local la, lb = a:lower(), chestName:lower()
        if cfg().nameContains then return lb:find(la, 1, true) ~= nil end
        return la == lb
    end

    M.pcs, M.isValid, M.classOf, M.fullName, M.presClass = pcs, isValid, classOf, fullName, presClass
    M.xyz, M.presLoc, M.actorLoc, M.hdist = xyz, presLoc, actorLoc, hdist
    M.findAllAny, M.trim, M.fstr, M.nameMatches = findAllAny, trim, fstr, nameMatches

    -- ===== world enumeration ===========================================
    -- All flags: { {actor=, x=, y=, radius=, baseId=} }. baseId from
    -- ConZBaseManager._bases (== SCUM.db base.id), the only live owner-lookup key.
    local function collectFlags()
        local mgr
        local mgrs = findAllAny("BP_ConZBaseManager_C", "ConZBaseManager")
        if mgrs then for i = 1, #mgrs do if isValid(mgrs[i]) then mgr = mgrs[i]; break end end end
        local radius = cfg().flagRadiusOverride
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

    -- { [ownerFullName] = {ocls=, items={...}} } — container contents, keyed by the
    -- owner's GetFullName (userdata identity isn't stable across FindAllOf passes).
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

    local function findIUC()
        local l = FindAllOf("InventoryUserComponent")
        if l then for i = 1, #l do if isValid(l[i]) then return l[i] end end end
        return nil
    end

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

    M.collectFlags, M.collectChests = collectFlags, collectChests
    M.collectContainerContents, M.findIUC, M.flagFor = collectContainerContents, findIUC, flagFor

    -- ===== read-only SCUM.db reader (constant SQL only) ================
    local OWNER_SQL = "SELECT b.id, up.user_id FROM base b JOIN user_profile up ON up.id=b.owner_user_profile_id WHERE b.is_owned_by_player=1;"
    local USERS_SQL = "SELECT u.id, COALESCE(up.name,''), COALESCE(u.name,'') FROM user u LEFT JOIN user_profile up ON up.user_id=u.id;"
    local STEAM64_PAT = "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$"
    local function dq(s) return '"' .. tostring(s) .. '"' end

    function M.dbRows(sql)
        local exe = cfg().sqliteExe or M.sqliteExe
        local db = cfg().dbPath
        if not exe or not db then return nil, "sqlite/db path not configured" end
        local inner = string.format('%s -readonly -batch -noheader -separator "|" %s %s 2>&1', dq(exe), dq(db), dq(sql))
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

    -- ===== entitlement store (core fields + opts.storeExtra) ===========
    local extra = opts.storeExtra or {}
    local function defaultStore()
        -- defaultEnabled = true: a FRESH install (no entitlements.lua yet) is ON
        -- for every flag, so the mod works out of the box. Shared by all gatable
        -- mods, so they all default the same way. Admins can still restrict via
        -- '<trigger> default off' + per-player/per-flag grants (the donation model),
        -- and an existing server's saved store keeps whatever it had.
        local s = { defaultEnabled = true, players = {}, flagOverrides = {}, pausedFlags = {} }
        for name in pairs(extra) do s[name] = {} end
        return s
    end

    function M.loadStore()
        M.store = defaultStore()
        local f = M.storeFile and io.open(M.storeFile, "r") or nil
        if not f then return end
        local src = f:read("*a"); f:close()
        local chunk = load(src, "@store")
        local ok, t = false, nil
        if chunk then ok, t = pcall(chunk) end
        if ok and type(t) == "table" then
            M.store.defaultEnabled = (t.defaultEnabled == true)
            if type(t.players) == "table" then
                for _, s in ipairs(t.players) do M.store.players[#M.store.players + 1] = tostring(s) end
            end
            if type(t.flagOverrides) == "table" then
                for k, v in pairs(t.flagOverrides) do
                    local id = math.tointeger(tonumber(k))
                    if id ~= nil then M.store.flagOverrides[id] = (v == true) end
                end
            end
            if type(t.pausedFlags) == "table" then
                for _, b in ipairs(t.pausedFlags) do
                    local id = math.tointeger(tonumber(b))
                    if id ~= nil then M.store.pausedFlags[id] = true end
                end
            end
            for name, kind in pairs(extra) do
                if type(t[name]) == "table" then
                    for k, v in pairs(t[name]) do
                        local id = math.tointeger(tonumber(k))
                        local n = tonumber(v)
                        if id ~= nil and n ~= nil then
                            if kind == "intmap" then
                                local i = math.tointeger(n); if i and i > 0 then M.store[name][id] = i end
                            else -- floatmap
                                if n > 0 and n <= 1 then M.store[name][id] = n end
                            end
                        end
                    end
                end
            end
            if type(t.accessMessage) == "string" then M.store.accessMessage = t.accessMessage end
        end
    end

    local function serializeStore(s)
        local out = {
            "-- entitlement store. Written by the mod's chat commands; hand-edits are",
            "-- fine (then reload). players = Steam64 IDs.",
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
        for _, k in ipairs(keys) do out[#out + 1] = string.format("    [%d] = %s,", k, s.flagOverrides[k] and "true" or "false") end
        out[#out + 1] = "  },"
        out[#out + 1] = "  pausedFlags = {"
        local pk = {}
        for k in pairs(s.pausedFlags or {}) do pk[#pk + 1] = k end
        table.sort(pk)
        out[#out + 1] = "    " .. table.concat(pk, ", ")
        out[#out + 1] = "  },"
        -- extra maps (sorted field names, sorted ids)
        local enames = {}
        for name in pairs(extra) do enames[#enames + 1] = name end
        table.sort(enames)
        for _, name in ipairs(enames) do
            out[#out + 1] = "  " .. name .. " = {"
            local mk = {}
            for k in pairs(s[name] or {}) do mk[#mk + 1] = k end
            table.sort(mk)
            for _, k in ipairs(mk) do
                local v = s[name][k]
                out[#out + 1] = string.format("    [%d] = %s,", k, (extra[name] == "intmap") and string.format("%d", v) or tostring(v))
            end
            out[#out + 1] = "  },"
        end
        if s.accessMessage ~= nil then out[#out + 1] = string.format("  accessMessage = %q,", tostring(s.accessMessage)) end
        out[#out + 1] = "}"
        return table.concat(out, "\n") .. "\n"
    end

    function M.saveStore()
        if not M.store then return false end
        local f = M.storeFile and io.open(M.storeFile, "w") or nil
        if not f then M.log("could not write store: " .. tostring(M.storeFile)); return false end
        f:write(serializeStore(M.store)); f:close()
        return true
    end

    local function tcount(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end

    -- ===== entitlement resolution ======================================
    local function recomputeEnabled()
        local s = M.store or defaultStore()
        local owners = M.ownerMap or {}
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
        M.resolved = {
            enabled = enabled, enabledBases = enabledBases, defaultEnabled = s.defaultEnabled,
            overrides = s.flagOverrides, paused = paused,   -- for the default-fallback below
            counts = { enabled = n, bases = tcount(owners), players = #s.players,
                       overrides = tcount(s.flagOverrides), paused = tcount(paused) },
        }
    end

    function M.ensureResolved(force)
        local c = cfg()
        if not c.entitlementsEnabled then M.resolved = nil; return true end
        if not M.store then M.loadStore() end
        -- The SCUM.db owner map is needed ONLY to resolve per-player entitlements
        -- (the donation model). With none granted, skip the DB entirely — so no
        -- sqlite3.exe is required for default/per-flag operation. Read it (and only
        -- then) when at least one player has been granted.
        if #M.store.players > 0 then
            local intervalSec = (c.resyncIntervalMs or 300000) / 1000
            local fresh = M.ownerMap and M.ownerMapAt and (os.time() - M.ownerMapAt) < intervalSec
            if force or not fresh then
                local rows, err = M.dbRows(OWNER_SQL)
                if rows then
                    local m = {}
                    for _, r in ipairs(rows) do
                        local id = math.tointeger(tonumber(r[1]))
                        if id ~= nil then m[id] = r[2] end
                    end
                    M.ownerMap = m; M.ownerMapAt = os.time()
                else
                    M.log("entitlement DB read failed (per-player grants need sqlite3.exe): " .. tostring(err))
                end
            end
        end
        recomputeEnabled()   -- always resolve; owner map may be empty (default still applies)
        return true
    end

    function M.resolvePlayer(arg)
        arg = trim(arg or "")
        if arg == "" then return { status = "notfound" } end
        local rows, err = M.dbRows(USERS_SQL)
        if not rows then M.log("resolvePlayer DB read failed: " .. tostring(err)); return { status = "dberror" } end
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

    function M.flagEnabled(flag)
        if not cfg().entitlementsEnabled then return true end
        local r = M.resolved
        if not r then return false end
        local bid = flag.baseId
        if bid == nil then return false end
        if r.enabled[bid] then return true end            -- explicitly on (override-on / player-entitled)
        if r.overrides[bid] ~= nil then return false end  -- an override exists (it was off)
        if r.paused[bid] then return false end            -- paused beats the global default
        return r.defaultEnabled == true                   -- fall back to the global default
    end

    function M.flagEnabledForIssuer(baseId)
        if not cfg().entitlementsEnabled then return true end
        local r = M.resolved
        if not r or baseId == nil then return false end
        if r.enabledBases[baseId] then return true end    -- access ignores pause
        if r.overrides[baseId] ~= nil then return false end
        return r.defaultEnabled == true
    end

    function M.currentFlagBaseId()
        local ctrl = M.controller
        if not ctrl then return nil end
        local pawn = pcs(function() return ctrl:K2_GetPawn() end, nil)
        if not isValid(pawn) then pawn = pcs(function() return ctrl.Pawn end, nil) end
        if not isValid(pawn) then return nil end
        local ax, ay = actorLoc(pawn)
        if not ax then return nil end
        local flag = flagFor(ax, ay, collectFlags())
        return flag and flag.baseId or nil
    end

    -- ===== access-control chat commands (verb-neutral wording) =========
    function M.handleFlagCmd(rest)
        local mode, idtok = (rest or ""):match("^(%S*)%s*(%S*)$")
        mode = (mode or ""):lower()
        if mode ~= "on" and mode ~= "off" and mode ~= "clear" then
            M.reply("usage: " .. M.trigger .. " flag on|off|clear [baseId]  (no id = your current flag)")
            return
        end
        local baseId
        if idtok and idtok ~= "" then
            local n = tonumber(idtok)
            baseId = n and math.tointeger(n) or nil
            if not baseId then M.reply("baseId must be a whole number"); return end
        else
            baseId = M.currentFlagBaseId()
            if not baseId then M.reply("stand in the flag you mean, or give its id"); return end
        end
        if not M.store then M.loadStore() end
        if mode == "clear" then
            if M.store.flagOverrides[baseId] ~= nil then
                M.store.flagOverrides[baseId] = nil
                M.reply("cleared override on base " .. baseId .. " (back to player/default)")
            else
                M.reply("base " .. baseId .. " had no override")
            end
        else
            M.store.flagOverrides[baseId] = (mode == "on")
            M.reply("base " .. baseId .. " override set to " .. mode:upper())
        end
        M.saveStore(); M.ensureResolved(true)
    end

    function M.cmdList()
        if not M.store then M.loadStore() end
        M.ensureResolved(true)
        local s = M.store
        M.reply("access (default: " .. (s.defaultEnabled and "ON" or "OFF") .. ")", true)
        local users = M.dbRows(USERS_SQL) or {}
        local nameOf = {}
        for _, u in ipairs(users) do nameOf[u[1]] = (u[2] ~= "" and u[2] or u[3]) end
        M.reply("enabled players (" .. #s.players .. "):", true)
        if #s.players == 0 then M.reply("  (none)", true) end
        for _, sid in ipairs(s.players) do
            local bids = {}
            for baseId, owner in pairs(M.ownerMap or {}) do if owner == sid then bids[#bids + 1] = baseId end end
            table.sort(bids)
            local where = #bids > 0 and ("base " .. table.concat(bids, ", ")) or "no base yet"
            M.reply(string.format("  %s  %s  -> %s", sid, nameOf[sid] or "?", where), true)
        end
        local ovk = {}
        for k in pairs(s.flagOverrides) do ovk[#ovk + 1] = k end
        table.sort(ovk)
        M.reply("flag overrides (" .. #ovk .. "):", true)
        if #ovk == 0 then M.reply("  (none)", true) end
        for _, k in ipairs(ovk) do M.reply("  base " .. k .. " -> " .. (s.flagOverrides[k] and "ON" or "OFF"), true) end
        local c = (M.resolved and M.resolved.counts) or {}
        M.reply(string.format("result: %d of %d player-owned base(s) enabled", c.enabled or 0, c.bases or 0), true)
    end

    function M.cmdStatus()
        if not M.store then M.loadStore() end
        M.ensureResolved(true)
        local s = M.store
        local c = (M.resolved and M.resolved.counts) or {}
        M.reply(string.format("default=%s  players=%d  flag overrides=%d  paused=%d  -> %d/%d base(s) enabled",
            s.defaultEnabled and "ON" or "OFF", #s.players, tcount(s.flagOverrides), tcount(s.pausedFlags),
            c.enabled or 0, c.bases or 0), true)
        if type(opts.statusExtra) == "function" then pcall(opts.statusExtra, M) end
        if M.enabled == false then M.reply("auto-run is PAUSED server-wide (pause-all active)", true) end
    end

    function M.cmdAdd(who)
        if not M.store then M.loadStore() end
        local r = M.resolvePlayer(who)
        if r.status == "dberror" then M.reply("DB read failed (see log)"); return end
        if r.status == "notfound" then M.reply("no player matched '" .. who .. "' (try their Steam64 ID)"); return end
        if r.status == "ambiguous" then
            M.reply("'" .. who .. "' matches several players - add by Steam64:", true)
            for sid, nm in pairs(r.matches) do M.reply("  " .. sid .. "  " .. tostring(nm), true) end
            return
        end
        local sid, nm = r.id, r.name
        for _, p in ipairs(M.store.players) do if p == sid then M.reply((nm or sid) .. " is already enabled"); return end end
        M.store.players[#M.store.players + 1] = sid
        M.saveStore(); M.ensureResolved(true)
        local bids = {}
        for baseId, owner in pairs(M.ownerMap or {}) do if owner == sid then bids[#bids + 1] = baseId end end
        table.sort(bids)
        local tail
        if #bids > 0 then tail = "now enabled for base " .. table.concat(bids, ", ")
        elseif r.status == "pregrant" then tail = "not seen on this server yet - applies when they build"
        else tail = "no base owned yet" end
        M.reply("enabled " .. (nm or sid) .. " (" .. sid .. ") - " .. tail)
    end

    function M.cmdRemove(who)
        if not M.store then M.loadStore() end
        who = trim(who)
        local target
        for _, p in ipairs(M.store.players) do if p == who then target = who; break end end
        if not target then
            local r = M.resolvePlayer(who)
            if r.status == "ambiguous" then
                M.reply("'" .. who .. "' matches several players - remove by Steam64:", true)
                for sid, nm in pairs(r.matches) do M.reply("  " .. sid .. "  " .. tostring(nm), true) end
                return
            end
            if r.id then for _, p in ipairs(M.store.players) do if p == r.id then target = r.id; break end end end
        end
        if not target then M.reply("'" .. who .. "' is not in the enabled list"); return end
        local kept = {}
        for _, p in ipairs(M.store.players) do if p ~= target then kept[#kept + 1] = p end end
        M.store.players = kept
        M.saveStore(); M.ensureResolved(true)
        M.reply("removed " .. target .. " from enabled players")
    end

    function M.cmdDefault(mode)
        if not M.store then M.loadStore() end
        M.store.defaultEnabled = (mode == "on")
        M.saveStore(); M.ensureResolved(true)
        local c = (M.resolved and M.resolved.counts) or {}
        M.reply(string.format("global default set to %s - %d/%d base(s) now enabled", mode:upper(), c.enabled or 0, c.bases or 0))
    end

    -- the "not enabled" message: store override > config.notEnabledMessage
    local DEFAULT_NOT_ENABLED = opts.defaultNotEnabled or "this feature isn't enabled for your base — ask an admin"
    local SILENT_TOKENS = { off = true, none = true, silent = true, ["nil"] = true, [""] = true }
    local function accessSetting()
        if M.store and M.store.accessMessage ~= nil then return M.store.accessMessage, "command" end
        return cfg().notEnabledMessage, "config"
    end
    function M.replyNotEnabled()
        local m = accessSetting()
        if m == nil then return end
        if type(m) == "string" then
            local low = m:lower()
            if SILENT_TOKENS[low] then return end
            if low == "default" then M.reply(DEFAULT_NOT_ENABLED, true); return end
            M.reply(m, true)
        elseif type(m) == "table" then
            for _, l in ipairs(m) do M.reply(tostring(l), true) end
        end
    end

    function M.cmdPauseFlag(pause)
        if not M.store then M.loadStore() end
        M.store.pausedFlags = M.store.pausedFlags or {}
        local baseId = M.currentFlagBaseId()
        if not baseId then M.reply("stand in the flag you want to " .. (pause and "pause" or "resume")); return end
        M.ensureResolved(false)
        if not M.flagEnabledForIssuer(baseId) then M.replyNotEnabled(); return end
        if pause then
            M.store.pausedFlags[baseId] = true
            M.reply("PAUSED for your flag (base " .. baseId .. ") — '" .. M.trigger .. " resume' to undo")
        elseif M.store.pausedFlags[baseId] then
            M.store.pausedFlags[baseId] = nil
            M.reply("RESUMED for your flag (base " .. baseId .. ")")
        else
            M.reply("your flag (base " .. baseId .. ") was not paused")
        end
        M.saveStore(); M.ensureResolved(true)
    end

    function M.cmdGetAccessMsg()
        if not M.store then M.loadStore() end
        local m, src = accessSetting()
        if m == nil then M.reply("access-msg [" .. src .. "]: SILENT (non-enabled players see nothing)"); return end
        if type(m) == "table" then
            M.reply("access-msg [" .. src .. "] (" .. #m .. " lines):")
            for _, l in ipairs(m) do M.reply("  " .. tostring(l), true) end
            return
        end
        local low = tostring(m):lower()
        if SILENT_TOKENS[low] then M.reply("access-msg [" .. src .. "]: SILENT (non-enabled players see nothing)")
        elseif low == "default" then M.reply("access-msg [" .. src .. "]: default => " .. DEFAULT_NOT_ENABLED)
        else M.reply("access-msg [" .. src .. "]: " .. tostring(m)) end
    end

    function M.cmdSetAccessMsg(text)
        if not M.store then M.loadStore() end
        text = trim(text or "")
        if text == "" then M.reply("usage: " .. M.trigger .. " set-access-msg <text> | default | off | reset"); return end
        local low = text:lower()
        if low == "reset" then
            M.store.accessMessage = nil; M.saveStore()
            M.reply("access-msg reset — now using Config's notEnabledMessage"); return
        end
        M.store.accessMessage = text; M.saveStore()
        if SILENT_TOKENS[low] then M.reply("access-msg set to SILENT — non-enabled players will see nothing")
        elseif low == "default" then M.reply("access-msg set to the built-in default")
        else M.reply("access-msg set to: " .. text) end
    end

    -- ===== chat reply + onChatMessage entry ============================
    local CHAT_SERVERMESSAGE = 6
    function M.reply(text, raw)
        local chan, ctrl = M.channel, M.controller
        if chan == nil then return false end
        local ps = nil
        if ctrl ~= nil then ps = pcs(function() return ctrl.PlayerState end, nil) end
        local msg = raw and tostring(text) or ("[" .. (M.tag or "mod") .. "] " .. tostring(text))
        return pcall(function() chan:Chat_Client_SendMessageToChat(msg, ps, {}, CHAT_SERVERMESSAGE, false) end)
    end

    -- Called from main.lua's chat hook. Resolves caller context, then delegates to
    -- the mod's M.handleCommand (which uses these M.cmd* plus its own commands).
    function M.onChatMessage(self, messageParam)
        local msg = ""
        pcall(function() msg = messageParam:get():ToString() end)
        if type(msg) ~= "string" or msg == "" then return end
        local trig = (M.trigger or "mod"):lower()
        local low = msg:lower()
        if low ~= trig and low:sub(1, #trig + 1) ~= (trig .. " ") then return end
        local chan = pcs(function() return self:get() end, nil)
        local ctrl = chan and pcs(function() return chan:GetOuter() end, nil) or nil
        M.channel = chan
        M.controller = ctrl
        M.callerIsAdmin = (ctrl ~= nil) and (pcs(function() return ctrl:IsUserAdmin() end, false) == true)
        if type(M.handleCommand) == "function" then
            M.handleCommand((#msg <= #trig) and "" or msg:sub(#trig + 2))
        end
    end
end

return Gating
