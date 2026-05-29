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
    -- actor, so the mod reads SCUM.db read-only via the bundled sqlite3.exe to
    -- map baseId -> owner Steam64 -> entitled?. Control it in-game with:
    -- goober add/remove <player> , goober list , goober status ,
    -- goober flag on|off|clear [baseId] , goober default on|off .
    --   true  = gate sorting by entitlement (per-player primary, per-flag fallback)
    --   false = sort EVERY flag (the entitlement layer is disabled)
    entitlementsEnabled = true,
    -- Path to the server's save DB (read-only). owner_user_profile_id lives here.
    -- Defaults to defaultDbPath() above (portable). Set a literal path to override.
    dbPath = defaultDbPath(),
    -- sqlite3.exe used to read the DB. nil = use the copy in this mod's folder
    -- (run install-libraries.ps1 to fetch it). Set a path to use a different one.
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
