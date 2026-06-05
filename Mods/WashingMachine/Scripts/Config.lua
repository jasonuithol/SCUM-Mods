-- Config.lua — WashingMachine operator config. Edit, then 'washer reload' in chat
-- (or restart). Returns one table.

local function defaultDbPath()
    local d = WashingMachine and WashingMachine.modDir
    if not d then return [[C:\scumserver\SCUM\Saved\SaveFiles\SCUM.db]] end
    for _ = 1, 5 do d = d:gsub("[\\/][^\\/]+$", "") end
    return d .. [[\Saved\SaveFiles\SCUM.db]]
end

return {
    -- ---- the washer -----------------------------------------------------
    -- A washer is an ACTIVATED deployable of this class. Improvised Wardrobe =
    -- Wardrobe_Improvised_Wood_C (same base as the dryer). A real container, so
    -- the client renders it + it has inventory natively (no visual hacks).
    washerClass = "Wardrobe_Improvised_Wood_C",

    -- ---- washing --------------------------------------------------------
    -- Clothing dirtiness is a 0..1 field (_dirtiness); 1=filthy, 0=clean. We
    -- wash by SetDirtiness(0). Only clothing dirtier than this is washed (skip
    -- already-clean). Range 0..1.
    dirtThreshold = 0.05,
    -- After washing, clothes are left DAMP: water weight set to this fraction of
    -- the garment's max possible water weight (5% by spec).
    dampFraction = 0.05,
    -- Soap: a "full bar" is a usage quantity (~100) read via DiscreteUsageItemComponent.
    -- Require at least this much usage on a soap bar to wash. The whole bar is consumed.
    soapClass = "Soap_C",
    soapFullUsage = 90,           -- >=90 of 100 counts as a "full bar"
    -- The held water bucket. Its water lives in a UBasicGameResourceContainerComponent
    -- (_repResourceAmount; ~9.99 = full ~10). Require at least this much to wash; the
    -- bucket is emptied (amount=0 + OnRep_ResourceAmount) on a successful wash.
    bucketClass = "Water_Bucket_C",
    bucketFullAmount = 9.0,        -- >=9 (of ~10) counts as a "full bucket"
    -- Washing only lands when a player is loaded near the washer (else contents
    -- virtualize). 20000cm (~200m) ≈ SCUM stream range.
    washLoadedRangeCm = 20000,

    -- ---- activation recipe ----------------------------------------------
    -- 'washer activate' (standing in your flag) consumes these from a wardrobe in
    -- your flag, then marks it an active washer. Same as the ClothesDryer recipe
    -- PLUS 2 hoses. Each ingredient: a count (TOTAL stack quantity) + the
    -- acceptable leaf class name(s) (multiple = "any of these").
    --
    -- Class names VERIFIED live via 'washer scan' 2026-06-05 (incl. Hose_C).
    recipe = {
        { name = "Metal Scraps", count = 5, classes = {
            "Metal_Scrap_01_C", "Metal_Scrap_02_C", "Metal_Scrap_03_C", "Metal_Scrap_04_C", "Metal_Scrap_05_C" } },
        { name = "Alternator",   count = 1, classes = {
            "Laika_Engine_Alternator_Item_C", "WW_Engine_Alternator_Item_C",
            "Rager_Engine_Alternator_Item_C", "Tractor_Engine_Alternator_Item_C" } },
        { name = "Wire",         count = 1, classes = { "Wire_C" } },
        { name = "Bolts",        count = 5, classes = { "Bolts_C" } },
        { name = "Hoses",        count = 2, classes = { "Hose_C" } },
    },

    -- ---- chat + access --------------------------------------------------
    chatTrigger = "washer",
    -- When true, admin-only for the non-user commands (reload, access control).
    -- User commands (help/check/scan/activate/wash/deactivate) stay open but are
    -- still entitlement-gated per flag. false = no admin gate (test servers).
    requireAdmin = true,

    -- ---- per-player / per-flag entitlement gate (same model as ClothesDryer) ---
    -- true  = a wardrobe only washes inside a flag whose owner is entitled (needs
    --         SCUM.db read via sqlite3.exe + an owner map). The donation model.
    -- false = washing works in ANY flag (entitlement layer off). Good for first test.
    entitlementsEnabled = true,
    dbPath = defaultDbPath(),
    sqliteExe = nil,            -- nil = the sqlite3.exe in this mod's folder
    resyncIntervalMs = 300000,  -- 5 min owner-map refresh

    -- What a non-entitled player sees on a gated command: "default" | nil | string | list.
    notEnabledMessage = "default",
}
