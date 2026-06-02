-- Config.lua — FlagUpkeep operator config (behaviour settings only). Edit this
-- file, then run  upkeep reload  in chat (or restart the server) to apply.
-- Returns one table.

-- Default save-DB path, derived from this mod's folder so it's portable across
-- machines: from <root>\SCUM\Binaries\Win64\ue4ss\Mods\<mod>, strip 5 trailing
-- segments to reach <root>\SCUM, then append the standard save-DB path. Falls
-- back to a literal if modDir is unknown. dbPath below uses this; override it
-- with a literal path only if your server layout is non-standard.
local function defaultDbPath()
    local d = FlagUpkeep and FlagUpkeep.modDir
    if not d then return [[C:\scumserver\SCUM\Saved\SaveFiles\SCUM.db]] end
    for _ = 1, 5 do d = d:gsub("[\\/][^\\/]+$", "") end
    return d .. [[\Saved\SaveFiles\SCUM.db]]
end

return {
    -- ---- behaviour -------------------------------------------------------
    upkeepIntervalMs = 3600000, -- upkeep period (ms); 1h. restart to change; "upkeep now" = on demand
    flagRadiusOverride = nil,   -- nil = live ConZBaseManager._flagInfluenceRadius (5000cm)

    -- The container that holds the toolkits FlagUpkeep draws from: a chest or
    -- wardrobe in the flag whose custom name matches this. Same naming model as
    -- GarbageGoober's category chests. nameContains=false => exact match.
    containerName = "FlagUpkeep",
    nameContains = false,

    -- Which item classes can be deposited for REPAIR POINTS (EXACT leaf class
    -- names). On 'upkeep deposit' (chest OPEN) each toolbox's live charge count
    -- (its UDiscreteUsageItemComponent._repQuantity) is banked as that many repair
    -- points and the box is consumed. Full-charge values: Tool_Box_C=100,
    -- Tool_Box_Small_C=50, Improvised_Tool_Box_C=20. 1 point repairs 1 element.
    toolkitClasses = { "Tool_Box_C", "Tool_Box_Small_C", "Improvised_Tool_Box_C" },

    -- ---- repair behaviour ------------------------------------------------
    -- Repair is driven by the game's own NetMulticast_InteractWithElement(170)
    -- per element, with element ids read from SCUM.db (RE'd + verified 2026-05-30;
    -- see memory reference-scum-base-building-architecture). It clamps to full HP.
    --   true  = repair damaged elements in enabled flags
    --   false = report-only: log what WOULD be repaired, touch nothing
    repairEnabled = true,
    -- DEFAULT repair trigger: repair an element once its health fraction drops
    -- BELOW this (0..1). Elements decay slowly all the time, so a threshold avoids
    -- spending charges to top off near-full pieces. Each player can override this
    -- for their own flag with 'upkeep trigger <percent>' (lower = repair later,
    -- saves charges but more raid-risk; higher = repair sooner). 0.90 = under 90%.
    repairBelowFraction = 0.90,
    -- Require (and spend) repair points.
    --   true  = each repair spends 1 repair point; a flag with 0 points is skipped
    --           (deposit toolboxes to top up). The intended cost model.
    --   false = repair for FREE — no points needed/spent. Handy to test the repair
    --           half alone, or for a no-economy upkeep server.
    requireRepairPoints = true,
    -- After repairing an element, don't repair it again for this many seconds. The
    -- element_health we read comes from SCUM.db, which only updates on the server's
    -- periodic save — so a just-repaired element still reads as damaged for a while.
    -- This stops a second cycle (or a quick repeat 'upkeep now') from spending a
    -- second charge on it. Set a little above your server's save interval.
    repairCooldownSec = 300,
    -- Cap how many repair points one cycle may spend per flag (nil = no cap; limited
    -- only by points banked and elements damaged). A cap smooths consumption so a
    -- big raid doesn't drain the balance in a single cycle.
    maxPointsPerCycle = nil,
    -- A repair only takes effect when the base's elements are LOADED, which in SCUM
    -- needs a player within streaming range (~200m). With nobody nearby the repair
    -- multicast silently no-ops — so the cycle SKIPS a flag (and spends NO points)
    -- unless a player pawn is within this many cm of the flag. This is what stops an
    -- unattended base from burning points on repairs that never land. Default 20000
    -- (200m) ≈ SCUM's base-stream range; lower it to be stricter (e.g. 5000 = only
    -- when someone's inside the flag). 'upkeep now' from inside your flag is always
    -- well within range, so the manual command is unaffected.
    repairLoadedRangeCm = 20000,

    -- Admin TEST tool: enable the 'upkeep damage [amount]' command, which damages
    -- every base element in your flag by <amount> HP (default 200) so there's
    -- something for upkeep to repair. KEEP FALSE on a real server — it's purely for
    -- testing the repair flow. ApplyDamage is unclamped, so a high amount can
    -- destroy low-HP elements.
    allowTestDamage = false,

    -- Commands are typed in NORMAL chat starting with this word, e.g. "upkeep now".
    chatTrigger = "upkeep",
    -- Access control. The user commands (bare 'upkeep' help, 'upkeep check') are
    -- always open to any player. Everything else — now, reload, pause, resume,
    -- and all access-control commands — is admin-only when this is true (checks
    -- IsUserAdmin). Set false to drop the gate (e.g. private/test servers).
    requireAdmin = true,

    -- ---- per-player / per-flag entitlement gate --------------------------
    -- Identical model to GarbageGoober. When ON, upkeep only runs inside a flag
    -- whose owner has been entitled by an admin (the donation/premium model),
    -- with a per-flag override as the fallback. A flag's owner is NOT readable
    -- from the live actor, so the mod reads SCUM.db read-only via the bundled
    -- sqlite3.exe to map baseId -> owner Steam64 -> entitled?. Control it in-game:
    -- upkeep add/remove <player> , upkeep list , upkeep status ,
    -- upkeep flag on|off|clear [baseId] , upkeep default on|off .
    --   true  = gate upkeep by entitlement (per-player primary, per-flag fallback)
    --   false = upkeep EVERY flag (the entitlement layer is disabled)
    entitlementsEnabled = true,
    -- Path to the server's save DB (read-only). owner_user_profile_id lives here.
    dbPath = defaultDbPath(),
    -- sqlite3.exe used to read the DB. nil = use the copy in this mod's folder
    -- (run install-libraries.ps1 to fetch it). Set a path to use a different one.
    sqliteExe = nil,
    -- How often (ms) the cycle re-reads the DB to refresh the owner map. Cheap
    -- (one read-only query). add/remove/flag/default always force a refresh.
    resyncIntervalMs = 300000, -- 5 min

    -- What a player whose base isn't enabled sees when they try a user command:
    --   "default" = the built-in "ask an admin to enable it" message
    --   nil       = print NOTHING (pretend the feature isn't there)
    --   a string  = that exact message (great for a donation/VIP/Discord link)
    --   a list    = those lines, one chat message each
    -- This is the SEED/default; admins can override it live (persisted) with
    -- 'upkeep set-access-msg <text|default|off|reset>' — no Config edit needed.
    notEnabledMessage = "default",
}
