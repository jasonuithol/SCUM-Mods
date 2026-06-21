-- sorter.lua — GarbageGoober sweep engine. Defines GarbageGoober.sweep() plus the
-- goober-specific helpers (loose-loot scan, category matching, YAML rules). The
-- shared gating layer (safe-reflection helpers, world enumeration, SCUM.db reader,
-- entitlement store/resolution, access-control commands, chat reply/onChatMessage)
-- is installed onto GG by the shared library (main.lua -> ..\shared\Scripts\
-- gating.lua) BEFORE this file loads. Hot-reloadable by main.lua. Pure logic: no
-- timers or hooks here.

GarbageGoober = GarbageGoober or {}
local GG = GarbageGoober

local AUTOPLACE = 1073741824 -- FInventoryEntryLocation.Value: auto-place in first free slot

-- shared helpers installed by gating.attach
local pcs, isValid, classOf, fullName, presClass = GG.pcs, GG.isValid, GG.classOf, GG.fullName, GG.presClass
local xyz, presLoc, actorLoc, hdist = GG.xyz, GG.presLoc, GG.actorLoc, GG.hdist
local findAllAny, trim, fstr, nameMatches = GG.findAllAny, GG.trim, GG.fstr, GG.nameMatches
local collectFlags, collectChests, collectContainerContents = GG.collectFlags, GG.collectChests, GG.collectContainerContents
local findIUC, flagFor, currentFlagBaseId, inFlag = GG.findIUC, GG.flagFor, GG.currentFlagBaseId, GG.inFlag
local flagEnabled, flagEnabledForIssuer, replyNotEnabled = GG.flagEnabled, GG.flagEnabledForIssuer, GG.replyNotEnabled

-- double-quote a shell arg (used by GG.fetchUrl). The shared lib has its own copy
-- for dbRows; fetchUrl lives here, so keep a local one.
local function dq(s) return '"' .. tostring(s) .. '"' end

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

-- Locate a loose item in the SAME coordinate space as flags and chests (both of
-- which use the actor world location). A dedicated server populates the
-- on-the-floor PRESENCE location (_serverPresence.Data.Location) and leaves the
-- actor transform at/near origin; single-player is the reverse — the presence
-- location reads as origin and only the actor transform is real. So take the
-- actor location when it's a genuine (non-origin) point, else the presence
-- location, else whatever we have. Returns (x, y, source).
-- returns the chosen (x, y, source) AND the two raw candidates (ax,ay = actor,
-- px,py = presence) so the caller can probe-log how the two agree per host.
local function looseLoc(it)
    local ax, ay = xyz(pcs(function() return it:K2_GetActorLocation() end, nil))
    local px, py = presLoc(it)
    local x, y, src
    if ax and (ax * ax + ay * ay) > 1.0 then x, y, src = ax, ay, "actor"
    elseif px and (px * px + py * py) > 1.0 then x, y, src = px, py, "pres"
    else x, y, src = ax or px, ay or py, "weak" end
    return x, y, src, ax, ay, px, py
end

-- Passive verifier: log K2 vs presence for the first few loose items after each
-- (re)load, then go quiet. On a dedicated server this proves which source is
-- real (and whether the two agree) without spamming the log. Reset on reload.
GG._locProbe = 12
local function fmtn(n) return n and string.format("%.0f", n) or "nil" end

-- All loose (non-deployable, on-the-floor) items: { {item=, class=, x=, y=, locSrc=} }
local function collectLooseLoot()
    local out = {}
    local items = FindAllOf("Item")
    if items then for i = 1, #items do
        local it = items[i]
        if isValid(it) then
            local pc = presClass(it)
            if pc and pc:find("OnTheFloor", 1, true) and not isDeployable(it) then
                local cls = classOf(it)
                local x, y, src, ax, ay, px, py = looseLoc(it)
                if GG.config.debugLocProbe and (GG._locProbe or 0) > 0 then
                    GG._locProbe = GG._locProbe - 1
                    GG.log(string.format("  loc-probe: %-26s K2=(%s,%s) pres=(%s,%s) -> used %s",
                        cls, fmtn(ax), fmtn(ay), fmtn(px), fmtn(py), src))
                end
                out[#out + 1] = { item = it, class = cls, x = x, y = y, locSrc = src }
            end
        end
    end end
    return out
end

-- ---- scoping + matching --------------------------------------------------
-- category path (general..specific) for an item class, from config rules.
-- returns (path, isDefault) — isDefault true when no rule matched (fell to defaultPath).
local function categoryPath(cls)
    local low = cls:lower()
    for _, rule in ipairs(GG.config.rules or {}) do
        if rule.match and low:find(rule.match:lower(), 1, true) then return rule.path, false end
    end
    return GG.config.defaultPath, true
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

-- VERIFY a move actually landed: true iff `item` now sits in `chest`'s inventory
-- (compare the item's live inventory owner to the chest actor). Presence ==
-- "InTheInventory" alone is AMBIGUOUS for an item that STARTED in another container
-- (a backpack's contents read InTheInventory whether or not the move took), so we
-- compare the actual owning chest — this is what catches a silent no-op.
local function inChest(item, chest)
    local p = pcs(function() return item._serverPresence end, nil)
    local inv = p and pcs(function() return p._inventory end, nil) or nil
    local owner = inv and pcs(function() return inv:GetOwner() end, nil) or nil
    return (isValid(owner) and chest and chest.owner
        and fullName(owner) == fullName(chest.owner)) or false
end

-- GATHER then ABSORB one LOOSE FLOOR item into `chest`: re-drop it ONTO the chest
-- with the game's native AItem:DropAround (keeps it a REAL, registered item and
-- works at ANY range — AddOrMoveEntry alone only commits within a player's ~2m
-- vicinity), then open the chest + AddOrMoveEntry to absorb it inside, VERIFYING it
-- actually landed in THIS chest (never trust the RPC's quiet OK). Returns "moved"
-- (inside the chest now), "gathered" (a real item on the chest; absorbs when a
-- player visits), or "error". NOTE: DropAround only works on loose floor items —
-- it can't reach into a container or off a weapon socket, so emptyContainers /
-- stripAttachments do a plain (range-gated) move instead, not gatherAbsorb.
local function gatherAbsorb(iuc, item, chest, dropper)
    if GG.config.relocateToChest ~= false then
        -- skip the re-drop if the item is ALREADY gathered at this chest (within
        -- ~2.5m) — otherwise, on short sweep intervals, an item waiting to be
        -- absorbed gets re-scattered every sweep and visibly bounces around.
        local ix, iy = actorLoc(item)
        local cx, cy = actorLoc(chest.owner)
        local already = ix and cx and hdist(ix, iy, cx, cy) <= 250
        if not already then
            local okD, resD = pcall(function() return item:DropAround(chest.owner, dropper, 50.0) end)
            if not okD then GG.log("  DropAround ERR: " .. tostring(resD)) end
        end
    end
    local openH = (GG._openHandle or 1000) + 1
    GG._openHandle = openH
    if GG.config.absorbIntoChest ~= false then
        pcall(function() iuc:Server_OpenInventory(chest.inv, openH) end)
    end
    local ok, e = pcall(function()
        iuc:Server_InventoryComponent_AddOrMoveEntry(chest.inv, item, { Value = AUTOPLACE })
    end)
    if not ok then GG.log("  AddOrMoveEntry ERR: " .. tostring(e)); return "error" end
    return inChest(item, chest) and "moved" or "gathered"
end


-- Recursively move a loose container's contents into matching category chests
-- (candidates = chests in the same flag). Nested containers are unpacked first,
-- then sorted themselves. Returns (moved, remaining): remaining = contents that
-- matched no chest (left inside). Uses the same AddOrMoveEntry move as the sort.
-- SPILL a container's contents onto the floor (next to the container, where the
-- player is when a bag is dropped) via native DropAround, so the next sweep's
-- loose-loot gather-absorb carries each to its category chest base-wide. We only
-- spill contents that HAVE a destination chest (don't litter unmatched items), and
-- VERIFY each actually left the container (presence == OnTheFloor) — DropAround on
-- an item still locked inside reports nothing useful, so we check.
local function emptyContainerInto(iuc, container, contentsMap, candidates, depth, dropper)
    local key = fullName(container)
    local rec = key and contentsMap[key]
    if not rec then return 0, 0 end
    local moved, remaining = 0, 0
    for _, child in ipairs(rec.items) do
        if depth < 6 then
            local m = emptyContainerInto(iuc, child, contentsMap, candidates, depth + 1, dropper)
            moved = moved + m
        end
        local cls = classOf(child)
        if matchChest(categoryPath(cls), candidates) then
            pcall(function() child:DropAround(container, dropper, 50.0) end)
            local pc = pcs(function() return presClass(child) end, nil)
            if type(pc) == "string" and pc:find("OnTheFloor", 1, true) then
                moved = moved + 1
                GG.log(string.format("  spilled %s out of %s (next sweep sorts it)", cls, classOf(container)))
            else
                remaining = remaining + 1
                GG.log(string.format("  could not extract %s from %s (presence %s)", cls, classOf(container), tostring(pc)))
            end
        else
            remaining = remaining + 1
        end
    end
    return moved, remaining
end

-- Collect a weapon's socketed attachments (scope/suppressor/grip/magazine/...).
-- These live in _attachmentSockets[].Items[].MountedItem, NOT in an inventory, so
-- they don't appear in the InTheInventory scan. Only valid actors are returned —
-- a gun's integral (non-removable) mounts read back as invalid and are skipped.
local function collectMounts(item)
    local out = {}
    local socks = pcs(function() return item._attachmentSockets end, nil)
    local ns = socks and pcs(function() return #socks end, nil) or 0
    for s = 1, ns do
        local sock = pcs(function() return socks[s] end, nil)
        local sitems = sock and pcs(function() return sock.Items end, nil) or nil
        local ni = sitems and pcs(function() return #sitems end, nil) or 0
        for j = 1, ni do
            local di = pcs(function() return sitems[j] end, nil)
            local m = di and pcs(function() return di.MountedItem end, nil) or nil
            if isValid(m) then out[#out + 1] = m end
        end
    end
    return out
end

-- SPILL a weapon's removable attachments onto the floor (next to the weapon, where
-- the player is when a gun is dropped) via native DropAround, so the next sweep's
-- loose-loot gather-absorb carries each to its category chest. Only spill ones with
-- a destination chest, and VERIFY each detached (presence == OnTheFloor). Magazines
-- spill loaded. (DropAround off a weapon socket works the same as out of a bag.)
local function stripMountsInto(iuc, item, candidates, dropper)
    local moved = 0
    for _, m in ipairs(collectMounts(item)) do
        local cls = classOf(m)
        if matchChest(categoryPath(cls), candidates) then
            pcall(function() m:DropAround(item, dropper, 50.0) end)
            local pc = pcs(function() return presClass(m) end, nil)
            if type(pc) == "string" and pc:find("OnTheFloor", 1, true) then
                moved = moved + 1
                GG.log(string.format("  stripped %s off weapon (next sweep sorts it)", cls))
            else
                GG.log(string.format("  could not detach %s (presence %s)", cls, tostring(pc)))
            end
        end
    end
    return moved
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

    -- live player pawns: used as the AItem:DropAround dropper AND to tell whether
    -- anyone is "home" at a flag, so we don't pile loot onto an abandoned base.
    local pawns = {}
    do
        local ps = findAllAny("Prisoner", "BP_Prisoner_C")
        if ps then for i = 1, #ps do local pw = ps[i]
            if isValid(pw) then
                local px, py = actorLoc(pw)
                if px then pawns[#pawns + 1] = { pawn = pw, x = px, y = py } end
            end
        end end
    end
    local dropper = pawns[1] and pawns[1].pawn or nil
    local function flagHasVisitor(flag)
        for _, p in ipairs(pawns) do
            if inFlag(p.x, p.y, flag) then return true end
        end
        return false
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
    local stripped = 0 -- attachments pulled off weapons into chests
    local gathered = 0 -- items re-dropped onto a chest, awaiting a player to absorb
    local noVisitor = 0 -- items in a flag with nobody home (skipped, not gathered)
    local unmapped = {} -- distinct item classes that hit no rule (tree gaps)
    for _, it in ipairs(items) do
        local flag = flagFor(it.x, it.y, flags)
        if not flag then
            noFlag = noFlag + 1 -- POI / outside any flag — not ours to touch
            if noFlag <= 6 then -- capped diagnostic: why did this item miss every flag?
                local f1 = flags[1]
                local d = (it.x and f1 and f1.x) and string.format("%.0f", hdist(it.x, it.y, f1.x, f1.y)) or "?"
                GG.log(string.format("  outside-flag: %s at (%s,%s)[%s]  nearest-flag(%s,%s) d=%s r=%d",
                    it.class, tostring(it.x), tostring(it.y), tostring(it.locSrc),
                    f1 and tostring(f1.x) or "?", f1 and tostring(f1.y) or "?", d, f1 and f1.radius or 0))
            end
        elseif not flagEnabled(flag) then
            disabled = disabled + 1 -- flag's owner not entitled (or per-flag override OFF)
        elseif GG.config.onlySortWithVisitor ~= false and not flagHasVisitor(flag) then
            noVisitor = noVisitor + 1 -- nobody home; don't pile loot on an abandoned base
        else
            -- candidate chests = those inside the SAME flag's influence
            local candidates = {}
            for _, c in ipairs(chests) do
                if c.name and inFlag(c.x, c.y, flag) then
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
                        emptied = emptied + emptyContainerInto(iuc, it.item, contentsMap, candidates, 0, dropper)
                    end
                end
                -- if it's a weapon with attachments, strip them into chests first
                if GG.config.stripAttachments then
                    stripped = stripped + stripMountsInto(iuc, it.item, candidates, dropper)
                end
                local path, isDefault = categoryPath(it.class)
                if isDefault then unmapped[it.class] = true end
                local chest, node = matchChest(path, candidates)
                if not chest then
                    noMatch = noMatch + 1
                    GG.log(string.format("  no chest for %s (path=%s)", it.class,
                        path and ("{" .. table.concat(path, ">") .. "}") or "<none>"))
                else
                    -- gather onto the matched chest, then absorb when a player's near
                    local st = gatherAbsorb(iuc, it.item, chest, dropper)
                    if st == "moved" then
                        moved = moved + 1
                        GG.log(string.format("  moved %s -> chest '%s'", it.class, chest.name))
                    elseif st == "gathered" then
                        gathered = gathered + 1 -- piled onto the chest, awaiting a visitor
                        GG.log(string.format("  gathered %s onto '%s' (awaiting player to absorb)", it.class, chest.name))
                    else
                        errs = errs + 1
                        GG.log(string.format("  ERROR moving %s -> '%s'", it.class, chest.name))
                    end
                end
            end
        end
    end

    GG.log(string.format("sweep done: moved=%d  gathered=%d  emptied=%d  stripped=%d  disabled=%d  no-visitor=%d  outside-flag=%d  no-chest-in-flag=%d  no-name-match=%d  errors=%d",
        moved, gathered, emptied, stripped, disabled, noVisitor, noFlag, noChest, noMatch, errs))
    local gaps = {}
    for cls in pairs(unmapped) do gaps[#gaps + 1] = cls end
    if #gaps > 0 then
        table.sort(gaps)
        GG.log("  unmapped (no rule -> default): " .. table.concat(gaps, ", "))
    end
    return string.format("moved %d  gathered %d  emptied %d  stripped %d  (%d disabled, %d no-chest, %d no-match)", moved, gathered, emptied, stripped, disabled, noChest, noMatch)
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
        if inFlag(c.x, c.y, flag) then
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
            h[#h + 1] = "  goober set-sqlite <path to sqlite3.exe | sqlite3.exe | off> — location of sqlite3.exe (for add/remove)"
        end
    end
    return h
end
local function printHelp() for _, l in ipairs(helpLines(true)) do GG.log(l) end end


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
            local gateOn = GG.config.entitlementsEnabled
            -- access via the gate function (honours override > player > GLOBAL DEFAULT),
            -- NOT the resolved owner set directly — default-on bases aren't in that set
            -- when sqlite is off (empty owner map). Same decision the auto-sweep uses.
            local access = (not gateOn) or flagEnabledForIssuer(baseId)
            local paused = GG.resolved and GG.resolved.paused and GG.resolved.paused[baseId]
            if access and not paused then
                GG.log("manual sweep of base " .. baseId .. " (goober now)")
                local ok, s = pcall(GG.sweep, baseId)
                GG.reply(ok and (s or "swept") or "sweep error (see log)")
            elseif access and paused then
                -- enabled, but the owner paused it
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
    elseif arg == "get-sqlite" then
        GG.cmdGetSqlite()
    elseif arg == "set-sqlite" or arg:sub(1, 11) == "set-sqlite " then
        GG.cmdSetSqlite(arg:sub(12))
    else
        GG.log("unrecognised command 'goober " .. arg .. "'")
        GG.reply("Command unrecognised: '" .. arg .. "'")
        GG.reply("Type 'goober' for a list of valid commands")
    end
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
