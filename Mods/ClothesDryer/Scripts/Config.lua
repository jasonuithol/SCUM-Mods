-- Config.lua — ClothesDryer operator config. Edit, then 'dryer reload' in chat
-- (or restart). Returns one table.

local function defaultDbPath()
    local d = ClothesDryer and ClothesDryer.modDir
    if not d then return [[C:\scumserver\SCUM\Saved\SaveFiles\SCUM.db]] end
    for _ = 1, 5 do d = d:gsub("[\\/][^\\/]+$", "") end
    return d .. [[\Saved\SaveFiles\SCUM.db]]
end

return {
    -- ---- the dryer ------------------------------------------------------
    -- A dryer is an ACTIVATED deployable of this class. Improvised Wardrobe =
    -- Wardrobe_Improvised_Wood_C (confirmed live 2026-06-03). A real container,
    -- so the client renders it + it has inventory natively (no visual hacks).
    dryerClass = "Wardrobe_Improvised_Wood_C",

    -- ---- drying ---------------------------------------------------------
    -- How often (ms) the dry cycle runs. Clothes dry within ~one interval of
    -- being placed, so keep this short for "close to instant". 4s default.
    dryIntervalMs = 4000,
    -- Clothing wetness == its water weight (IWettable). We dry by SetWaterWeight(0).
    -- Only items wetter than this (water weight) are touched (skip already-dry).
    dryThreshold = 1.0,
    -- A SetWaterWeight only lands + is worth doing when a player is loaded near the
    -- wardrobe (else contents virtualize). Same proximity gate as FlagUpkeep.
    -- 20000cm (~200m) ≈ SCUM stream range. Drying pauses when nobody's around.
    dryLoadedRangeCm = 20000,

    -- ---- activation recipe ----------------------------------------------
    -- 'dryer activate' (standing in your flag) consumes these from a wardrobe in
    -- your flag, then marks it an active dryer. Each ingredient: a count (TOTAL
    -- stack quantity) + the acceptable leaf class name(s) (multiple = "any of
    -- these", e.g. any alternator).
    --
    -- Class names VERIFIED live via 'dryer scan' 2026-06-04. `count` is total stack
    -- quantity (a stack of 5 bolts = 5, read via _repQuantity through GetOwner).
    -- Consumption removes WHOLE entries smallest-stack-first (no partial-stack RPC),
    -- so exact provided amounts consume exactly what you put in; an oversized stack
    -- gets eaten whole. Metal_Scrap_02/04 not seen in scan but included for safety.
    recipe = {
        { name = "Metal Scraps", count = 5, classes = {
            "Metal_Scrap_01_C", "Metal_Scrap_02_C", "Metal_Scrap_03_C", "Metal_Scrap_04_C", "Metal_Scrap_05_C" } },
        { name = "Alternator",   count = 1, classes = {
            "Laika_Engine_Alternator_Item_C", "WW_Engine_Alternator_Item_C",
            "Rager_Engine_Alternator_Item_C", "Tractor_Engine_Alternator_Item_C" } },
        { name = "Wire",         count = 1, classes = { "Wire_C" } },
        { name = "Bolts",        count = 5, classes = { "Bolts_C" } },
    },

    -- ---- chat + access --------------------------------------------------
    chatTrigger = "dryer",
    -- When true, admin-only for the non-user commands (reload, pause-all, access
    -- control). User commands (help/check/scan/activate/now/pause/resume) stay open
    -- but are still entitlement-gated per flag. false = no admin gate (test servers).
    requireAdmin = true,

    -- ---- per-player / per-flag entitlement gate (same model as FlagUpkeep) ---
    -- true  = the gate is active. Default-on (out of the box) + per-flag overrides
    --         need NO DB. Granting a specific player (dryer add <player>) reads
    --         SCUM.db via a user-supplied sqlite3.exe — that's the donation model.
    -- false = drying works in ANY flag (entitlement layer off).
    entitlementsEnabled = true,
    dbPath = defaultDbPath(),
    -- sqlite3.exe — ONLY needed to grant PER-PLAYER entitlements (dryer add
    -- <player>). nil = DISABLED (default): no DB read; default-on + per-flag still
    -- work. To enable, set an absolute path (keep ONE copy on the server, e.g.
    -- ...\ue4ss\Mods\shared\sqlite3.exe) or "sqlite3.exe" to use one on PATH.
    -- (CLI tools: https://sqlite.org/download.html.)
    -- Or set it live in chat (no file edit): dryer set-sqlite <path to sqlite3.exe>
    sqliteExe = nil,
    resyncIntervalMs = 300000,  -- 5 min owner-map refresh

    -- What a non-entitled player sees on a gated command: "default" | nil | string | list.
    notEnabledMessage = "default",
}
