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
-- The flag owner isn't readable from the live actor, so an external Python
-- resolver reads SCUM.db and writes goober_resolved.lua (an enabled-baseId set)
-- + goober_reply.txt. We shell out to it (os.execute confirmed available).
-- Untrusted text (a player name) is handed over via a file, never the command
-- line, so there's no shell-injection surface; fixed verbs/numeric ids only.

-- load goober_resolved.lua -> GG.resolved (table with .enabled[baseId]=true)
function GG.loadResolvedFile()
    local path = GG.resolvedFile
    local f = path and io.open(path, "r") or nil
    if not f then GG.resolved = nil; return false end
    local src = f:read("*a"); f:close()
    local chunk = load(src, "@goober_resolved.lua")
    if not chunk then GG.resolved = nil; return false end
    local ok, res = pcall(chunk)
    if ok and type(res) == "table" then GG.resolved = res; GG.resolvedAt = os.time(); return true end
    GG.resolved = nil; return false
end

-- run the resolver with a FIXED token string (validated by the caller); pass any
-- untrusted free text via the arg file. Reloads resolved.lua + returns reply lines.
function GG.runResolver(tokens, untrusted)
    local cfg = GG.config or {}
    if not (GG.resolverScript and GG.modDir and cfg.dbPath) then
        GG.log("resolver paths not set — cannot run entitlement resolver")
        return {}
    end
    local argPart = ""
    if untrusted ~= nil then
        local af = io.open(GG.argFile, "w")
        if af then af:write(tostring(untrusted)); af:close() end
        argPart = string.format(' --argfile "%s"', GG.argFile)
    end
    local cmd = string.format('cmd /c %s "%s" --db "%s" --dir "%s" %s%s',
        cfg.pythonExe or "python", GG.resolverScript, cfg.dbPath, GG.modDir, tokens, argPart)
    GG.log("resolver: " .. tokens)
    pcall(os.execute, cmd)
    GG.loadResolvedFile()
    local lines = {}
    local rf = io.open(GG.replyFile, "r")
    if rf then for l in rf:lines() do lines[#lines + 1] = l end; rf:close() end
    return lines
end

-- ensure GG.resolved is loaded & fresh. force=true re-syncs now; otherwise only
-- if older than resyncIntervalMs. No-op (and clears) when the gate is disabled.
function GG.ensureResolved(force)
    local cfg = GG.config or {}
    if not cfg.entitlementsEnabled then GG.resolved = nil; return true end
    local intervalSec = (cfg.resyncIntervalMs or 300000) / 1000
    if not force and GG.resolved and GG.resolvedAt and (os.time() - GG.resolvedAt) < intervalSec then
        return true
    end
    GG.runResolver("sync", nil)
    return GG.resolved ~= nil
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
-- the admin is standing in). Verb + numeric id validated here before shelling
-- out, so only fixed/numeric tokens ever reach the command line.
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
    for _, l in ipairs(GG.runResolver(string.format("flag %s %d", mode, baseId), nil)) do
        GG.reply(l, true)
    end
end

-- ---- the sweep -----------------------------------------------------------
function GG.sweep()
    local iuc = findIUC()
    if not iuc then
        GG.log("sweep: no InventoryUserComponent (no player online / near) — nothing live to sort, skipping.")
        return "no player nearby — nothing to sort"
    end

    -- refresh the per-player/per-flag entitlement set (throttled; see Config)
    GG.ensureResolved(false)
    if GG.config.entitlementsEnabled and not GG.resolved then
        GG.log("sweep: entitlement gate ON but resolver gave no result — NOT sorting " ..
            "(fail-closed). Check pythonExe/dbPath; run 'goober status'.")
    end

    local flags, radius = collectFlags()
    if #flags == 0 then
        GG.log("sweep: no flags found in world — skipping.")
        return "no flags found"
    end
    local chests = collectChests()
    local items = collectLooseLoot()

    GG.log(string.format("sweep start: %d loose item(s), %d chest(s), %d flag(s), radius=%dcm%s",
        #items, #chests, #flags, radius,
        GG.config.entitlementsEnabled and (" | gate ON (" ..
            (GG.resolved and GG.resolved.counts and GG.resolved.counts.enabled or 0) .. " base(s) entitled)") or " | gate OFF"))

    local moved, noFlag, disabled, noChest, noMatch, errs = 0, 0, 0, 0, 0, 0
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

    GG.log(string.format("sweep done: moved=%d  disabled=%d  outside-flag=%d  no-chest-in-flag=%d  no-name-match=%d  errors=%d",
        moved, disabled, noFlag, noChest, noMatch, errs))
    local gaps = {}
    for cls in pairs(unmapped) do gaps[#gaps + 1] = cls end
    if #gaps > 0 then
        table.sort(gaps)
        GG.log("  unmapped (no rule -> default): " .. table.concat(gaps, ", "))
    end
    return string.format("moved %d  (%d disabled, %d no-chest, %d no-match)", moved, disabled, noChest, noMatch)
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
                rows[#rows + 1] = string.format("  %-44s -> %s%s", c,
                    p and table.concat(p, ">") or "<none>", isDef and "   [UNMAPPED]" or "")
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
local function helpLines()
    local sec = math.floor(((GG.config and GG.config.sweepIntervalMs) or 60000) / 1000)
    local h = {
        "GarbageGoober — auto-sorts loose ground loot inside a flag into chests",
        "named after each item's category (e.g. Ammo, Food, Feet, Armorer).",
        "Runs automatically every " .. sec .. "s. Commands (type in normal chat):",
        "  goober          — show this help",
        "  goober now      — sort the loose loot into chests right now",
        "  goober classes  — list every live item class + its category (to the log)",
        "  goober chests   — audit chests in your flag: each chest's category",
        "  goober types    — list categories ('goober types <name>' = its sub-types)",
        "  goober reload   — reload Config.lua (categories/settings), then sort once",
        "  goober pause    — pause the automatic sweep",
        "  goober resume   — resume the automatic sweep",
    }
    if GG.config and GG.config.entitlementsEnabled then
        h[#h + 1] = "  -- access control (per player; per flag = fallback) --"
        h[#h + 1] = "  goober list     — entitled players / flag overrides / result"
        h[#h + 1] = "  goober status   — one-line entitlement summary"
        h[#h + 1] = "  goober add <player>    — entitle a player (name or Steam64)"
        h[#h + 1] = "  goober remove <player> — un-entitle a player"
        h[#h + 1] = "  goober flag on|off|clear [baseId] — per-flag override (blank=your flag)"
        h[#h + 1] = "  goober default on|off  — sort every flag by default, or none"
    end
    return h
end
local function printHelp() for _, l in ipairs(helpLines()) do GG.log(l) end end

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

-- send the full multi-line help to the issuing admin's chat (one msg per line)
function GG.replyHelp() for _, l in ipairs(helpLines()) do GG.reply(l, true) end end

-- dispatch "goober <arg>" (arg = text after "goober", already prefix-stripped)
function GG.handleCommand(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "" then
        printHelp()
        GG.replyHelp()
    elseif arg == "now" then
        GG.log("manual sweep (goober now)")
        local ok, s = pcall(GG.sweep)
        GG.reply(ok and (s or "swept") or "sweep error (see log)")
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
            GG.log("reloaded; running one sweep")
            local ok, s = pcall(GG.sweep)
            GG.reply("reloaded — " .. (ok and (s or "swept") or "sweep error"))
        else
            GG.reply("reload FAILED (see log)")
        end
    elseif arg == "pause" then
        GG.enabled = false; GG.log("timer paused"); GG.reply("auto-sweep paused")
    elseif arg == "resume" then
        GG.enabled = true; GG.log("timer resumed"); GG.reply("auto-sweep resumed")
    elseif arg == "list" then
        GG.log("entitlement list (goober list)")
        local lines = GG.runResolver("list", nil)
        if #lines == 0 then GG.reply("list: resolver gave no output (see log)")
        else for _, l in ipairs(lines) do GG.reply(l, true) end end
    elseif arg == "status" then
        local lines = GG.runResolver("status", nil)
        if #lines == 0 then GG.reply("status: resolver gave no output (see log)")
        else for _, l in ipairs(lines) do GG.reply(l, true) end end
    elseif arg:sub(1, 4) == "add " then
        local who = trim(arg:sub(5))
        if who == "" then GG.reply("usage: goober add <player name or Steam64>")
        else for _, l in ipairs(GG.runResolver("add", who)) do GG.reply(l, true) end end
    elseif arg:sub(1, 7) == "remove " then
        local who = trim(arg:sub(8))
        if who == "" then GG.reply("usage: goober remove <player name or Steam64>")
        else for _, l in ipairs(GG.runResolver("remove", who)) do GG.reply(l, true) end end
    elseif arg == "flag" or arg:sub(1, 5) == "flag " then
        GG.handleFlagCmd(trim(arg:sub(5)))
    elseif arg:sub(1, 8) == "default " then
        local m = trim(arg:sub(9)):lower()
        if m ~= "on" and m ~= "off" then GG.reply("usage: goober default on|off")
        else for _, l in ipairs(GG.runResolver("default " .. m, nil)) do GG.reply(l, true) end end
    else
        GG.log("unknown command 'goober " .. arg .. "'")
        GG.reply("unknown command 'goober " .. arg .. "'")
        GG.replyHelp()
    end
end

-- Called from main.lua's chat hook with the live RemoteUnrealParams for
-- Chat_Server_BroadcastChatMessage(Message, Channel). If the message is one of
-- our commands ("goober ...") from an admin, handle it. We do NOT mutate the
-- message (live UFunction-arg mutation crashes — see gotchas), so it still shows
-- in chat. Normal chat has no privilege gate, so we require admin ourselves
-- (config.requireAdmin) — else any player could drive the sorter.
function GG.onChatMessage(self, messageParam)
    local msg = ""
    pcall(function() msg = messageParam:get():ToString() end)
    if type(msg) ~= "string" or msg == "" then return end
    local trig = ((GG.config and GG.config.chatTrigger) or "goober"):lower()
    local low = msg:lower()
    if low ~= trig and low:sub(1, #trig + 1) ~= (trig .. " ") then return end -- not ours
    local chan = pcs(function() return self:get() end, nil)
    local ctrl = chan and pcs(function() return chan:GetOuter() end, nil) or nil
    if not (GG.config and GG.config.requireAdmin == false) then
        local isAdmin = ctrl and pcs(function() return ctrl:IsUserAdmin() end, nil)
        if isAdmin ~= true then
            GG.log("ignored '" .. msg .. "' — sender not admin (or admin check unavailable)")
            return
        end
    end
    GG.channel = chan
    GG.controller = ctrl
    GG.handleCommand((#msg <= #trig) and "" or msg:sub(#trig + 2))
end

GG.log("sorter.lua loaded (sweep engine ready).")
