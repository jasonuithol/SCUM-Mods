-- Config.lua — GarbageGoober operator config. Edit this file, then run  goober reload
-- in chat (or restart the server) to apply. Returns one table.
--
-- HOW MATCHING WORKS
--   For each loose item the sorter builds a category PATH from `rules` below,
--   ordered general -> specific (e.g. { Trader, Category } or, for guns,
--   { Trader, Category, Sub-type }). It then looks for a chest IN THE SAME FLAG
--   whose custom name matches a path node, trying the MOST-SPECIFIC node first
--   and falling back toward the general end. First hit wins. No match =>
--   defaultPath (or left). Paths may be any depth.
--
--   Example: a 12ga slug is { "Armorer", "Ammo" } -> tries "Ammo" then "Armorer".
--   An AK-47 is { "Armorer", "RangedWeapon", "AutomaticRifles" } -> tries
--   "AutomaticRifles", then "RangedWeapon", then "Armorer".
--
-- THE TREE = SCUM's vendor structure: TRADER TYPE > TRADE CATEGORY.
--   Trader types (ETraderType) used as the coarse/fallback level:
--     Armorer  Bartender  Doctor  Mechanic  Harbourmaster  GeneralGoods
--   Trade categories (ETradeCategory) are the leaves — these are FLAT in SCUM
--   (Drink, Food, Feet, Ammo... are all peers; there is no "Clothing" or
--   "Consumables" category):
--     Armorer       -> Ammo RangedWeapon RangedWeaponAccessories MeleeWeapon Explosives
--     Bartender     -> Food Drink Alcohol
--     Doctor        -> FirstAid
--     Mechanic      -> Vehicles Crafting
--     Harbourmaster -> WaterVehicles Fishing
--     GeneralGoods  -> Helmets Jackets Pants Tops Headwear Hands Face Feet
--                      Backpacks Armour Neckwaist Underwear Cosmetics Misc
--   Name a chest after a leaf (e.g. "Drink", "Feet", "Ammo") for fine sorting,
--   or after a trader (e.g. "Bartender", "GeneralGoods") to catch a whole group.
--
-- COMPLETING THE TREE: the `match` tokens are a starting point; not every SCUM
-- item is guessed correctly here. Run  goober classes  to dump the real class
-- names in the world and how each maps, and watch the sweep log's "unmapped"
-- line — then add/fix rules below.

return {
    -- ---- behaviour -------------------------------------------------------
    sweepIntervalMs = 60000,  -- sweep period (ms); restart to change; "goober now" = on demand
    flagRadiusOverride = nil, -- nil = live ConZBaseManager._flagInfluenceRadius (5000cm)
    nameContains = false,     -- false = exact chest-name match; true = substring

    -- Commands are typed in NORMAL chat starting with this word, e.g. "goober now".
    -- (No "#" — that goes through SCUM's admin processor and replies "Unrecognized
    -- command".) The trigger word still appears in chat to whoever shares the channel.
    chatTrigger = "goober",
    -- Only let SCUM admins drive the mod via chat (normal chat has no privilege gate).
    -- true = require IsUserAdmin; false = anyone can type the command.
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
    dbPath = [[C:\scumserver\SCUM\Saved\SaveFiles\SCUM.db]],
    -- sqlite3.exe used to read the DB. nil = use the copy in this mod's folder
    -- (run install-libraries.ps1 to fetch it). Set a path to use a different one.
    sqliteExe = nil,
    -- How often (ms) the sweep re-reads the DB to refresh the owner map. Cheap
    -- (one read-only query). Lower = a donor's freshly built/rebuilt base starts
    -- being sorted sooner; higher = fewer sqlite spawns. add/remove/flag/default
    -- commands always force an immediate refresh regardless of this.
    resyncIntervalMs = 300000, -- 5 min

    -- ---- category rules (path = { Trader, Category }) --------------------
    -- First rule whose `match` substring (case-insensitive) is found in the
    -- item's class name wins. Order: specific/risky tokens BEFORE general ones.
    rules = {
        -- ===== ARMORER =====
        -- ammo first (so e.g. "rifle_ammo" matches Ammo, not RangedWeapon)
        { match = "_slug",       path = { "Armorer", "Ammo" } },
        { match = "birdshot",    path = { "Armorer", "Ammo" } },
        { match = "buckshot",    path = { "Armorer", "Ammo" } },
        { match = "_ammo",       path = { "Armorer", "Ammo" } },
        { match = "cartridge",   path = { "Armorer", "Ammo" } },
        { match = "_rounds",     path = { "Armorer", "Ammo" } },
        { match = "magazine",    path = { "Armorer", "Ammo" } },
        { match = "_mag_",       path = { "Armorer", "Ammo" } },
        { match = "_arrow",      path = { "Armorer", "Ammo" } },
        { match = "_bolt",       path = { "Armorer", "Ammo" } },
        -- weapon accessories before weapons
        { match = "scope",       path = { "Armorer", "RangedWeaponAccessories" } },
        { match = "silencer",    path = { "Armorer", "RangedWeaponAccessories" } },
        { match = "suppressor",  path = { "Armorer", "RangedWeaponAccessories" } },
        { match = "_sight",      path = { "Armorer", "RangedWeaponAccessories" } },
        { match = "foregrip",    path = { "Armorer", "RangedWeaponAccessories" } },
        -- explosives
        { match = "grenade",     path = { "Armorer", "Explosives" } },
        { match = "explosive",   path = { "Armorer", "Explosives" } },
        { match = "_c4",         path = { "Armorer", "Explosives" } },
        { match = "claymore",    path = { "Armorer", "Explosives" } },
        { match = "molotov",     path = { "Armorer", "Explosives" } },
        -- melee
        { match = "machete",     path = { "Armorer", "MeleeWeapon" } },
        { match = "knife",       path = { "Armorer", "MeleeWeapon" } },
        { match = "_axe",        path = { "Armorer", "MeleeWeapon" } },
        { match = "hatchet",     path = { "Armorer", "MeleeWeapon" } },
        { match = "cleaver",     path = { "Armorer", "MeleeWeapon" } },
        { match = "crowbar",     path = { "Armorer", "MeleeWeapon" } },
        { match = "sledgehammer",path = { "Armorer", "MeleeWeapon" } },
        { match = "_bat",        path = { "Armorer", "MeleeWeapon" } },
        { match = "spear",       path = { "Armorer", "MeleeWeapon" } },
        { match = "shovel",      path = { "Armorer", "MeleeWeapon" } },
        { match = "pickaxe",     path = { "Armorer", "MeleeWeapon" } },
        { match = "pitchfork",   path = { "Armorer", "MeleeWeapon" } },
        { match = "scythe",      path = { "Armorer", "MeleeWeapon" } },
        { match = "sickle",      path = { "Armorer", "MeleeWeapon" } },
        { match = "kukri",       path = { "Armorer", "MeleeWeapon" } },
        { match = "baton",       path = { "Armorer", "MeleeWeapon" } },
        -- ranged weapons -> sub-typed by EWeaponCategory where the class name
        -- reveals it; specific tokens first, generic 'rifle' then 'weapon_' last.
        -- handguns
        { match = "pistol",      path = { "Armorer", "RangedWeapon", "Handguns" } },
        { match = "revolver",    path = { "Armorer", "RangedWeapon", "Handguns" } },
        { match = "glock",       path = { "Armorer", "RangedWeapon", "Handguns" } },
        { match = "makarov",     path = { "Armorer", "RangedWeapon", "Handguns" } },
        { match = "deagle",      path = { "Armorer", "RangedWeapon", "Handguns" } },
        { match = "_m1911",      path = { "Armorer", "RangedWeapon", "Handguns" } },
        { match = "_m9",         path = { "Armorer", "RangedWeapon", "Handguns" } },
        -- submachine guns
        { match = "submachine",  path = { "Armorer", "RangedWeapon", "SubmachineGuns" } },
        { match = "_smg",        path = { "Armorer", "RangedWeapon", "SubmachineGuns" } },
        { match = "mp5",         path = { "Armorer", "RangedWeapon", "SubmachineGuns" } },
        { match = "mp7",         path = { "Armorer", "RangedWeapon", "SubmachineGuns" } },
        { match = "mp40",        path = { "Armorer", "RangedWeapon", "SubmachineGuns" } },
        { match = "_uzi",        path = { "Armorer", "RangedWeapon", "SubmachineGuns" } },
        { match = "thompson",    path = { "Armorer", "RangedWeapon", "SubmachineGuns" } },
        { match = "korpion",     path = { "Armorer", "RangedWeapon", "SubmachineGuns" } },
        { match = "kriss",       path = { "Armorer", "RangedWeapon", "SubmachineGuns" } },
        -- shotguns
        { match = "shotgun",     path = { "Armorer", "RangedWeapon", "Shotguns" } },
        { match = "spas",        path = { "Armorer", "RangedWeapon", "Shotguns" } },
        { match = "mossberg",    path = { "Armorer", "RangedWeapon", "Shotguns" } },
        { match = "sawed_off",   path = { "Armorer", "RangedWeapon", "Shotguns" } },
        { match = "saiga",       path = { "Armorer", "RangedWeapon", "Shotguns" } },
        -- sniper rifles
        { match = "sniper",      path = { "Armorer", "RangedWeapon", "SniperRifles" } },
        { match = "_svd",        path = { "Armorer", "RangedWeapon", "SniperRifles" } },
        { match = "dragunov",    path = { "Armorer", "RangedWeapon", "SniperRifles" } },
        { match = "kar98",       path = { "Armorer", "RangedWeapon", "SniperRifles" } },
        { match = "_m24",        path = { "Armorer", "RangedWeapon", "SniperRifles" } },
        { match = "barrett",     path = { "Armorer", "RangedWeapon", "SniperRifles" } },
        -- automatic rifles
        { match = "ak47",        path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "ak74",        path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "_akm",        path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "_m16",        path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "_m4a1",       path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "_m4_",        path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "_scar",       path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "_aug",        path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "_fal",        path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "_g36",        path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "famas",       path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "hk416",       path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "automatic_rifle", path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        { match = "assault_rifle",   path = { "Armorer", "RangedWeapon", "AutomaticRifles" } },
        -- bows
        { match = "crossbow",    path = { "Armorer", "RangedWeapon", "Bow" } },
        { match = "longbow",     path = { "Armorer", "RangedWeapon", "Bow" } },
        { match = "recurve",     path = { "Armorer", "RangedWeapon", "Bow" } },
        { match = "compound_bow",path = { "Armorer", "RangedWeapon", "Bow" } },
        { match = "bow_",        path = { "Armorer", "RangedWeapon", "Bow" } },
        -- throwing
        { match = "throwing",    path = { "Armorer", "RangedWeapon", "ThrowingWeapons" } },
        -- generic rifles (after the specific rifle types above)
        { match = "_sks",        path = { "Armorer", "RangedWeapon", "Rifles" } },
        { match = "mosin",       path = { "Armorer", "RangedWeapon", "Rifles" } },
        { match = "_m14",        path = { "Armorer", "RangedWeapon", "Rifles" } },
        { match = "lever_action",path = { "Armorer", "RangedWeapon", "Rifles" } },
        { match = "rifle",       path = { "Armorer", "RangedWeapon", "Rifles" } },
        -- any other gun -> generic RangedWeapon
        { match = "weapon_",     path = { "Armorer", "RangedWeapon" } },

        -- ===== DOCTOR =====
        { match = "bandage",     path = { "Doctor", "FirstAid" } },
        { match = "antibiotic",  path = { "Doctor", "FirstAid" } },
        { match = "painkiller",  path = { "Doctor", "FirstAid" } },
        { match = "antiseptic",  path = { "Doctor", "FirstAid" } },
        { match = "suture",      path = { "Doctor", "FirstAid" } },
        { match = "vitamin",     path = { "Doctor", "FirstAid" } },
        { match = "morphine",    path = { "Doctor", "FirstAid" } },
        { match = "_pills",      path = { "Doctor", "FirstAid" } },
        { match = "syringe",     path = { "Doctor", "FirstAid" } },
        { match = "medkit",      path = { "Doctor", "FirstAid" } },
        { match = "first_aid",   path = { "Doctor", "FirstAid" } },
        { match = "gauze",       path = { "Doctor", "FirstAid" } },
        { match = "splint",      path = { "Doctor", "FirstAid" } },
        { match = "disinfect",   path = { "Doctor", "FirstAid" } },
        { match = "epinephrine", path = { "Doctor", "FirstAid" } },
        { match = "tourniquet",  path = { "Doctor", "FirstAid" } },
        { match = "ointment",    path = { "Doctor", "FirstAid" } },
        { match = "tetracycline",path = { "Doctor", "FirstAid" } },

        -- ===== BARTENDER =====
        -- alcohol (before drink)
        { match = "beer",        path = { "Bartender", "Alcohol" } },
        { match = "whiskey",     path = { "Bartender", "Alcohol" } },
        { match = "wine",        path = { "Bartender", "Alcohol" } },
        { match = "vodka",       path = { "Bartender", "Alcohol" } },
        { match = "_rum",        path = { "Bartender", "Alcohol" } },
        { match = "moonshine",   path = { "Bartender", "Alcohol" } },
        -- drink
        { match = "water",       path = { "Bartender", "Drink" } },
        { match = "cola",        path = { "Bartender", "Drink" } },
        { match = "juice",       path = { "Bartender", "Drink" } },
        { match = "milk",        path = { "Bartender", "Drink" } },
        { match = "soda",        path = { "Bartender", "Drink" } },
        { match = "coffee",      path = { "Bartender", "Drink" } },
        { match = "_tea",        path = { "Bartender", "Drink" } },
        { match = "lemonade",    path = { "Bartender", "Drink" } },
        -- food
        { match = "canned",      path = { "Bartender", "Food" } },
        { match = "meat",        path = { "Bartender", "Food" } },
        { match = "_egg",        path = { "Bartender", "Food" } },
        { match = "bread",       path = { "Bartender", "Food" } },
        { match = "cheese",      path = { "Bartender", "Food" } },
        { match = "apple",       path = { "Bartender", "Food" } },
        { match = "_pear",       path = { "Bartender", "Food" } },
        { match = "banana",      path = { "Bartender", "Food" } },
        { match = "corn",        path = { "Bartender", "Food" } },
        { match = "bean",        path = { "Bartender", "Food" } },
        { match = "chocolate",   path = { "Bartender", "Food" } },
        { match = "cereal",      path = { "Bartender", "Food" } },
        { match = "_rice",       path = { "Bartender", "Food" } },
        { match = "carrot",      path = { "Bartender", "Food" } },
        { match = "potato",      path = { "Bartender", "Food" } },
        { match = "tomato",      path = { "Bartender", "Food" } },
        { match = "cabbage",     path = { "Bartender", "Food" } },
        { match = "mushroom",    path = { "Bartender", "Food" } },
        { match = "onion",       path = { "Bartender", "Food" } },
        { match = "garlic",      path = { "Bartender", "Food" } },
        { match = "lettuce",     path = { "Bartender", "Food" } },
        { match = "pumpkin",     path = { "Bartender", "Food" } },
        { match = "cucumber",    path = { "Bartender", "Food" } },
        { match = "radish",      path = { "Bartender", "Food" } },
        { match = "zucchini",    path = { "Bartender", "Food" } },
        { match = "sausage",     path = { "Bartender", "Food" } },
        { match = "bacon",       path = { "Bartender", "Food" } },
        { match = "steak",       path = { "Bartender", "Food" } },
        { match = "sardine",     path = { "Bartender", "Food" } },
        { match = "tuna",        path = { "Bartender", "Food" } },
        { match = "peach",       path = { "Bartender", "Food" } },
        { match = "plum",        path = { "Bartender", "Food" } },
        { match = "grape",       path = { "Bartender", "Food" } },
        { match = "melon",       path = { "Bartender", "Food" } },
        { match = "berry",       path = { "Bartender", "Food" } },
        { match = "pickle",      path = { "Bartender", "Food" } },
        { match = "honey",       path = { "Bartender", "Food" } },
        { match = "peanut",      path = { "Bartender", "Food" } },
        { match = "walnut",      path = { "Bartender", "Food" } },

        -- ===== GENERALGOODS (clothing & wearables) =====
        { match = "backpack",    path = { "GeneralGoods", "Backpacks" } },
        { match = "rucksack",    path = { "GeneralGoods", "Backpacks" } },
        { match = "helmet",      path = { "GeneralGoods", "Helmets" } },
        { match = "jacket",      path = { "GeneralGoods", "Jackets" } },
        { match = "coat",        path = { "GeneralGoods", "Jackets" } },
        { match = "hoodie",      path = { "GeneralGoods", "Jackets" } },
        { match = "jeans",       path = { "GeneralGoods", "Pants" } },
        { match = "pants",       path = { "GeneralGoods", "Pants" } },
        { match = "trousers",    path = { "GeneralGoods", "Pants" } },
        { match = "shorts",      path = { "GeneralGoods", "Pants" } },
        { match = "shirt",       path = { "GeneralGoods", "Tops" } },
        { match = "sweater",     path = { "GeneralGoods", "Tops" } },
        { match = "_top",        path = { "GeneralGoods", "Tops" } },
        { match = "boots",       path = { "GeneralGoods", "Feet" } },
        { match = "shoes",       path = { "GeneralGoods", "Feet" } },
        { match = "sneakers",    path = { "GeneralGoods", "Feet" } },
        { match = "_socks",      path = { "GeneralGoods", "Feet" } },
        { match = "gloves",      path = { "GeneralGoods", "Hands" } },
        { match = "mask",        path = { "GeneralGoods", "Face" } },
        { match = "glasses",     path = { "GeneralGoods", "Face" } },
        { match = "goggles",     path = { "GeneralGoods", "Face" } },
        { match = "_hat",        path = { "GeneralGoods", "Headwear" } },
        { match = "_cap",        path = { "GeneralGoods", "Headwear" } },
        { match = "beanie",      path = { "GeneralGoods", "Headwear" } },
        { match = "bandana",     path = { "GeneralGoods", "Headwear" } },
        { match = "vest",        path = { "GeneralGoods", "Armour" } },
        { match = "armor",       path = { "GeneralGoods", "Armour" } },
        { match = "armour",      path = { "GeneralGoods", "Armour" } },

        -- ===== HARBOURMASTER =====
        { match = "fishing",     path = { "Harbourmaster", "Fishing" } },
        { match = "_lure",       path = { "Harbourmaster", "Fishing" } },
        { match = "_bait",       path = { "Harbourmaster", "Fishing" } },
        { match = "boat",        path = { "Harbourmaster", "WaterVehicles" } },
        { match = "kayak",       path = { "Harbourmaster", "WaterVehicles" } },
        { match = "_paddle",     path = { "Harbourmaster", "WaterVehicles" } },

        -- ===== MECHANIC =====
        { match = "_wheel",      path = { "Mechanic", "Vehicles" } },
        { match = "_tire",       path = { "Mechanic", "Vehicles" } },
        { match = "jerry_can",   path = { "Mechanic", "Vehicles" } },
        { match = "nail",        path = { "Mechanic", "Crafting" } },
        { match = "plank",       path = { "Mechanic", "Crafting" } },
        { match = "rope",        path = { "Mechanic", "Crafting" } },
        { match = "duct_tape",   path = { "Mechanic", "Crafting" } },
        { match = "scrap",       path = { "Mechanic", "Crafting" } },
        { match = "_wire",       path = { "Mechanic", "Crafting" } },
        { match = "gunpowder",   path = { "Mechanic", "Crafting" } },
        { match = "_rag",        path = { "Mechanic", "Crafting" } },
        { match = "hammer",      path = { "Mechanic", "Crafting" } },
        { match = "wrench",      path = { "Mechanic", "Crafting" } },
        { match = "screwdriver", path = { "Mechanic", "Crafting" } },
        { match = "screw",       path = { "Mechanic", "Crafting" } },
        { match = "pliers",      path = { "Mechanic", "Crafting" } },
        { match = "drill",       path = { "Mechanic", "Crafting" } },
        { match = "glue",        path = { "Mechanic", "Crafting" } },
        { match = "_log",        path = { "Mechanic", "Crafting" } },
        { match = "charcoal",    path = { "Mechanic", "Crafting" } },
        { match = "cement",      path = { "Mechanic", "Crafting" } },
        { match = "plastic",     path = { "Mechanic", "Crafting" } },
        { match = "fertilizer",  path = { "Mechanic", "Crafting" } },
    },

    -- Path for items no rule matched. Tries a "Misc" chest, then "GeneralGoods".
    -- Set to nil to leave unmatched items in place instead. Either way, unmatched
    -- classes are listed in the sweep log under "unmapped" so you know what still
    -- needs a rule.
    defaultPath = { "GeneralGoods", "Misc" },
}
