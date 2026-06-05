-- Config.lua — GarbageGoober operator config (behaviour settings only). Edit
-- this file, then run  goober reload  in chat (or restart the server) to apply.
-- Returns one table.
--
-- The CATEGORY RULES (item -> category path) live in  categories.yaml  next to
-- this file, not here — they're data, not code. Edit that file and 'goober
-- reload' to change how items are sorted. See its header for how matching works.

-- Default save-DB path, derived from this mod's folder so it's portable across
-- machines: from <root>\SCUM\Binaries\Win64\ue4ss\Mods\<mod>, strip 5 trailing
-- segments to reach <root>\SCUM, then append the standard save-DB path. Falls
-- back to a literal if modDir is unknown. dbPath below uses this; override it
-- with a literal path only if your server layout is non-standard.
local function defaultDbPath()
    local d = GarbageGoober and GarbageGoober.modDir
    if not d then return [[C:\scumserver\SCUM\Saved\SaveFiles\SCUM.db]] end
    for _ = 1, 5 do d = d:gsub("[\\/][^\\/]+$", "") end
    return d .. [[\Saved\SaveFiles\SCUM.db]]
end

return {
    -- ---- behaviour -------------------------------------------------------
    sweepIntervalMs = 60000,  -- sweep period (ms); restart to change; "goober now" = on demand
    flagRadiusOverride = nil, -- nil = live ConZBaseManager._flagInfluenceRadius (5000cm)
    nameContains = false,     -- false = exact chest-name match; true = substring

    -- Empty containers: when a swept loose item CONTAINS other items (backpack,
    -- clothing with pockets, etc.), first move its contents out into the matching
    -- category chests, then put the emptied container away. Nested containers are
    -- unpacked recursively in the same sweep. Contents with no matching chest stay
    -- inside. (Guns/magazines are NOT unpacked here — attachments/ammo aren't
    -- inventory items; that's a later phase.) false = sort containers whole.
    emptyContainers = true,

    -- Strip weapon attachments: when a swept loose weapon has socketed
    -- attachments (scope, suppressor, grip, MAGAZINE, etc.), move each into its
    -- matching category chest (scope -> RangedWeaponAccessories, magazine ->
    -- Ammo, ...), then put the stripped weapon away. The magazine goes to the
    -- Ammo chest still LOADED — its rounds are ammo-data, not items, and SCUM's
    -- unload doesn't yield sortable rounds, so we don't try to empty it.
    -- false = sort weapons whole, attachments left on.
    stripAttachments = true,

    -- ---- category rules source -------------------------------------------
    -- The rules live in categories.yaml. Optionally pull them from a remote URL
    -- so you can update sorting WITHOUT touching the server. Behaviour:
    --   * boot / server start: NEVER hits the network — uses the last good copy
    --     cached on disk (from a previous pull), else the bundled categories.yaml.
    --   * 'goober reload': fetches this URL (via curl), applies it, and caches it.
    --     This is the ONLY time the URL is fetched. On failure it falls back to
    --     cache -> bundled; a fetch that parses to zero rules is rejected (keeps
    --     the current rules), so a truncated download never wipes sorting.
    -- Set nil to disable remote entirely and always use the local categories.yaml.
    --   Use a Gist RAW url with NO commit hash (= always latest). It's CDN-cached
    --   ~5 min, so edits aren't instant; reload appends a cache-buster to help.
    remoteCategoriesUrl = "https://gist.githubusercontent.com/jasonuithol/c08848f5a4ef9cc07b8ac4596b24838f/raw/categories.yaml",
    -- curl for the fetch. nil = "curl" on PATH (built into Windows 10+ at
    -- System32\curl.exe). Set a path to override.
    curlExe = nil,

    -- Commands are typed in NORMAL chat starting with this word, e.g. "goober now".
    -- (No "#" — that goes through SCUM's admin processor and replies "Unrecognized
    -- command".) The trigger word still appears in chat to whoever shares the channel.
    chatTrigger = "goober",
    -- Access control. The user commands (bare 'goober' help, 'goober types',
    -- 'goober chests') are always open to any player. Everything else — now,
    -- classes, reload, pause, resume, and all access-control commands — is
    -- admin-only when this is true (checks IsUserAdmin). Set false to drop the
    -- gate entirely so anyone can run every command (e.g. private/test servers).
    requireAdmin = true,

    -- ---- per-player / per-flag entitlement gate --------------------------
    -- When ON, the sweep only sorts loot inside a flag whose owner has been
    -- entitled by an admin (the donation/premium model), with a per-flag
    -- override as the fallback. A flag's owner is NOT readable from the live
    -- actor, so for PER-PLAYER grants the mod reads SCUM.db read-only via a
    -- user-supplied sqlite3.exe to map baseId -> owner Steam64 -> entitled?.
    -- (Default-on and per-flag overrides need NO DB / sqlite3.exe — the DB is
    -- only read once at least one player has been granted.) Control it in-game:
    -- goober add/remove <player> , goober list , goober status ,
    -- goober flag on|off|clear [baseId] , goober default on|off .
    --   true  = gate sorting by entitlement (per-player primary, per-flag fallback)
    --   false = sort EVERY flag (the entitlement layer is disabled)
    entitlementsEnabled = true,
    -- Path to the server's save DB (read-only). owner_user_profile_id lives here.
    -- Defaults to defaultDbPath() above (portable). Set a literal path to override.
    dbPath = defaultDbPath(),
    -- sqlite3.exe — ONLY needed to grant PER-PLAYER entitlements (goober add
    -- <player>). nil = DISABLED (the default): no DB is read, so per-player grants
    -- are off; default-on + per-flag overrides still work with no sqlite at all.
    -- To enable, point this at a sqlite3.exe — an absolute path (keep ONE copy on
    -- the server, e.g. ...\ue4ss\Mods\shared\sqlite3.exe) or "sqlite3.exe" to use
    -- one on PATH. (CLI tools: https://sqlite.org/download.html.)
    sqliteExe = nil,
    -- How often (ms) the sweep re-reads the DB to refresh the owner map. Cheap
    -- (one read-only query). Lower = a donor's freshly built/rebuilt base starts
    -- being sorted sooner; higher = fewer sqlite spawns. add/remove/flag/default
    -- commands always force an immediate refresh regardless of this.
    resyncIntervalMs = 300000, -- 5 min

    -- What a player whose base isn't enabled for sorting sees when they try a
    -- user command (goober now/pause/resume):
    --   "default" = the built-in "ask an admin to enable it" message
    --   nil       = print NOTHING — stay silent so non-enabled players never see
    --               the feature respond (pretend it isn't there)
    --   a string  = that exact message (great for a donation/VIP/Discord link)
    --   a list    = those lines, one chat message each
    -- e.g.  notEnabledMessage = "Auto-sort is a VIP perk - unlock it at example.com/vip",
    --       notEnabledMessage = { "Auto-sort is a VIP perk!", "Unlock it: example.com/vip" },
    -- This is the SEED/default; admins can override it live (persisted) with
    -- 'goober set-access-msg <text|default|off|reset>' — no Config edit needed.
    notEnabledMessage = "default",
}
