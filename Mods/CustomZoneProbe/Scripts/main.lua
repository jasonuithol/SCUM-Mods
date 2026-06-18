-- CustomZoneProbe — READ-ONLY recon for SCUM's custom-zone (map markup) system.
--
-- Purpose: de-risk the "Discord -> server -> all clients see a map marker" feature
-- before writing any of it. It answers two questions:
--   1. Can a server-side mod READ the custom-zone registry, and in what format?
--   2. What COORDINATE SPACE are zone Location/Size in (world cm? normalized?
--      map-texture px?) — so we know how to place a ping at a target.
--
-- It does NOT write or broadcast anything. Three sources of truth:
--   A. Hook CustomZones_Server_UpdateCustomZoneData  (admin client -> server):
--      fires when an admin draws/edits zones and hits Apply. Logs the EXACT
--      Regions/configs the game sends up — this is ground truth for the
--      coordinate space and the replay payload (Option B).
--   B. Hook CustomZones_Client_ReceiveCustomZoneData (server -> client):
--      fires when the server pushes the current set down. Logs the full set.
--   C. 'zonedump' chat command: walk GameState._customZoneRegistry on demand and
--      report the caller's current WORLD position, so you can stand at a spot,
--      draw a zone there, and compare world XY <-> zone Location.
--
-- HOW TO USE (the calibration play):
--   1. Install (see README), start server, join as an ADMIN.
--   2. Stand somewhere you can pinpoint on the map. Type 'zonedump' -> note your
--      world X/Y from the log.
--   3. Open the in-game Custom Zones map editor, draw a CIRCLE centred on where
--      you're standing, set a color, hit Apply.
--   4. Read CustomZoneProbe.log: the Update hook logged the region's Location/Size.
--      Compare that Location to your world X/Y from step 2 -> that's the mapping.
--   5. Type 'zonedump' again -> confirm the mod can read back the same region.
--
-- Server-side only; no client files (BattlEye-safe). Same UE4SS hook flags as
-- MapPing: HookProcessInternal=1 & HookProcessLocalScriptFunction=1
-- (use MapPing's bundled UE4SS-settings-SCUM.ini).

-- >>> set this to the mod's folder on your server <<<
local MOD_DIR = [[C:\Program Files (x86)\Steam\steamapps\common\SCUM Server\SCUM\Binaries\Win64\ue4ss\Mods\CustomZoneProbe]]
local LOGFILE = MOD_DIR .. [[\CustomZoneProbe.log]]

local DUMP_TRIGGER = "zonedump"   -- chat command (exact, case-insensitive)

-- ---- logging -------------------------------------------------------------
local function ts() return os.date("%Y-%m-%d %H:%M:%S") end
local function log(m)
    local line = "[ZoneProbe] " .. ts() .. " " .. tostring(m)
    print(line .. "\n")
    local f = io.open(LOGFILE, "a"); if f then f:write(line .. "\n"); f:close() end
end

-- ---- safe accessors ------------------------------------------------------
-- Every UObject/struct touch goes through pcs so a malformed read never crashes
-- the server. Game accessors throw or return nil constantly mid-spawn.
local function pcs(fn, fallback)
    local ok, v = pcall(fn)
    if ok then return v end
    return fallback
end

-- FString/FName/FText fields come back as objects or plain strings depending on
-- the property — normalise to a Lua string.
local function tostr(v)
    if v == nil then return "nil" end
    if type(v) == "string" then return v end
    local ok, s = pcall(function() return v:ToString() end)
    if ok and s ~= nil then return tostring(s) end
    return tostring(v)
end

local function num(v) return pcs(function() return tonumber(v) end, nil) end

local function vec2(v)
    if v == nil then return "nil" end
    local x = pcs(function() return v.X end, nil)
    local y = pcs(function() return v.Y end, nil)
    return string.format("(X=%s, Y=%s)", tostring(x), tostring(y))
end

local function color(v)
    if v == nil then return "nil" end
    return string.format("(R=%s G=%s B=%s A=%s)",
        tostring(pcs(function() return v.R end)), tostring(pcs(function() return v.G end)),
        tostring(pcs(function() return v.B end)), tostring(pcs(function() return v.A end)))
end

-- enum -> readable (best-effort; falls back to the raw number)
local SHAPE = { [0] = "Circle", [1] = "Rectangle" }
local function shapeName(n) n = num(n); return (n ~= nil and (SHAPE[n] or ("?" .. n))) or "nil" end

-- ---- struct dumpers ------------------------------------------------------
-- r/c are ALREADY-resolved struct userdata (caller did :get() if needed).
local function dumpRegion(tag, i, r)
    log(string.format("  %s region[%s]: Name=%q Location=%s Size=%s Shape=%s cfgIndex=%s defaultZoneName=%q defaultState=%s",
        tag, tostring(i),
        tostr(pcs(function() return r.Name end)),
        vec2(pcs(function() return r.Location end)),
        vec2(pcs(function() return r.Size end)),
        shapeName(pcs(function() return r.Shape end)),
        tostring(num(pcs(function() return r.ConfigurationIndex end))),
        tostr(pcs(function() return r.UniqueDefaultZoneName end)),
        tostring(num(pcs(function() return r.DefaultZoneState end)))))
end

local function dumpConfig(tag, i, c)
    -- DamageEventHandlingMethod is FCustomZoneDamageEventDamageChannelList ->
    -- .DamageChannelsVsHandlingMethod (TArray). This nested TArray is what crashed
    -- the write test; log its element count to confirm it's real engine data here.
    local dmgN = pcs(function()
        return c.DamageEventHandlingMethod.DamageChannelsVsHandlingMethod:GetArrayNum()
    end, "?")
    log(string.format("  %s config[%s]: Name=%q Settings=%s Color=%s EventHandling=%s DamageChannels=%s defaultZoneName=%q",
        tag, tostring(i),
        tostr(pcs(function() return c.Name end)),
        tostring(num(pcs(function() return c.Settings end))),
        color(pcs(function() return c.Color end)),
        tostring(num(pcs(function() return c.EventHandlingMethod end))),
        tostring(dmgN),
        tostr(pcs(function() return c.UniqueDefaultZoneName end))))
end

-- Walk a TArray of structs via ForEach (element comes as a RemoteUnrealParam ->
-- :get()). pcall the whole thing; arrays can be empty/nil/odd shapes.
local function dumpArray(tag, label, arr, perElem)
    if arr == nil then log(string.format("  %s %s: <nil>", tag, label)); return end
    local n = pcs(function() return arr:GetArrayNum() end, nil)
    log(string.format("  %s %s: count=%s", tag, label, tostring(n)))
    pcall(function()
        arr:ForEach(function(index, elem)
            local v = pcs(function() return elem:get() end, nil)
            perElem(tag, index, v)
        end)
    end)
end

-- ---- caller resolution (same pattern as MapPing) -------------------------
local function xyz(v)
    if not v then return nil end
    local x = pcs(function() return v.X end, nil)
    if not x then return nil end
    return x, pcs(function() return v.Y end, nil) or 0, pcs(function() return v.Z end, nil) or 0
end

local function resolveCaller(self)
    local chan = pcs(function() return self:get() end, nil)
    local ctrl = chan and pcs(function() return chan:GetOuter() end, nil) or nil
    if not ctrl then return nil end
    local name = pcs(function() return ctrl:GetUserName2():ToString() end, nil)
        or pcs(function() return ctrl:GetUserProfileName():ToString() end, "Unknown")
    local pris = pcs(function() return ctrl:GetPrisoner() end, nil)
    local x, y, z = xyz(pcs(function() return pris:K2_GetActorLocation() end, nil))
    return {
        chan = chan, ctrl = ctrl,
        ps = pcs(function() return ctrl.PlayerState end, nil),
        name = name, x = x, y = y, z = z,
        admin = (pcs(function() return ctrl:IsUserAdmin() end, false) == true),
    }
end

local CHAT_SERVERMESSAGE = 6
local function reply(caller, text)
    if not (caller and caller.chan) then return end
    local send = function()
        pcall(function()
            caller.chan:Chat_Client_SendMessageToChat(
                "[ZoneProbe] " .. tostring(text), caller.ps, {}, CHAT_SERVERMESSAGE, false)
        end)
    end
    if type(ExecuteWithDelay) == "function" then ExecuteWithDelay(120, send) else send() end
end

-- ---- find the registry ---------------------------------------------------
-- Prefer FindFirstOf("ConZGameState"); fall back to walking from the caller's
-- controller -> world -> GameState. Returns (gameState, registry) or nils.
local function findRegistry(caller)
    local gs = pcs(function() return FindFirstOf("ConZGameState") end, nil)
    if not gs or not pcs(function() return gs:IsValid() end, false) then
        gs = caller and pcs(function() return caller.ctrl:GetWorld().GameState end, nil) or nil
    end
    if not gs then return nil, nil end
    local reg = pcs(function() return gs._customZoneRegistry end, nil)
    return gs, reg
end

-- ---- the on-demand dump --------------------------------------------------
local function doDump(caller)
    log("======== zonedump ========")
    if caller then
        log(string.format("caller=%s admin=%s world X=%s Y=%s Z=%s",
            tostring(caller.name), tostring(caller.admin),
            tostring(caller.x), tostring(caller.y), tostring(caller.z)))
    end

    local gs, reg = findRegistry(caller)
    if not gs then log("could NOT find ConZGameState"); reply(caller, "no GameState — see log"); return end
    log("GameState found: " .. tostr(pcs(function() return gs:GetFullName() end)))
    if not reg or not pcs(function() return reg:IsValid() end, false) then
        log("_customZoneRegistry is nil/invalid"); reply(caller, "registry nil — see log"); return
    end
    log("registry found: " .. tostr(pcs(function() return reg:GetFullName() end)))

    -- Known fields from the SDK dump. The DEFAULT_* fields may or may not be the
    -- live/active set — that's part of what we're confirming.
    local gcfg = pcs(function() return reg._defaultGlobalConfiguration end, nil)
    if gcfg then dumpConfig("[reg]", "globalDefault", gcfg) else log("  [reg] _defaultGlobalConfiguration: <nil>") end

    local cfg = pcs(function() return reg._defaultConfiguration end, nil)
    if cfg then dumpConfig("[reg]", "default", cfg) else log("  [reg] _defaultConfiguration: <nil>") end

    -- _defaultRegions is a TMap<FName, FCustomZoneRegion>; iterate best-effort.
    local regions = pcs(function() return reg._defaultRegions end, nil)
    if regions == nil then
        log("  [reg] _defaultRegions: <nil>")
    else
        local mapn = pcs(function() return regions:GetMapNum() end, nil)
        log(string.format("  [reg] _defaultRegions: mapNum=%s", tostring(mapn)))
        pcall(function()
            regions:ForEach(function(key, value)
                local k = pcs(function() return key:get() end, nil)
                local v = pcs(function() return value:get() end, nil)
                dumpRegion("[reg]", tostr(k), v)
            end)
        end)
    end
    log("==========================")
    reply(caller, "dumped registry to CustomZoneProbe.log")
end

-- ---- RPC hooks: capture ground-truth payloads ----------------------------
-- These fire on their own whenever zones are edited/pushed; no command needed.
local function dumpRpcPayload(tag, self, gcfg, cfgs, regions)
    log("======== " .. tag .. " ========")
    local chan = pcs(function() return self:get() end, nil)
    local ctrl = chan and pcs(function() return chan:GetOuter() end, nil) or nil
    local who = ctrl and (pcs(function() return ctrl:GetUserName2():ToString() end, nil)
        or pcs(function() return ctrl:GetUserProfileName():ToString() end, "?")) or "?"
    log("via channel of: " .. tostring(who))
    local g = pcs(function() return gcfg:get() end, nil)
    if g then dumpConfig("[rpc]", "global", g) end
    dumpArray("[rpc]", "configurations", pcs(function() return cfgs:get() end, nil), dumpConfig)
    dumpArray("[rpc]", "Regions", pcs(function() return regions:get() end, nil), dumpRegion)
    log(string.rep("=", 26))
end

-- ---- INJECTION TEST (the only thing here that WRITES) ---------------------
-- 'zonetest' (admin): broadcast a bright circle at the caller's feet to ALL
-- clients via the registry's NetMulticast. This is TRANSIENT (display only):
-- it does NOT persist, and the server's real zone set (the Outposts) returns on
-- reconnect / next server push. We pass Lua tables; UE4SS marshals them into the
-- FCustomZoneConfiguration / FCustomZoneRegion structs + TArrays.
--
-- 'zoneclear' (admin): multicast an EMPTY region set to wipe the test marker off
-- clients (also transient).
--
-- Confirmed values (1st probe + enums): Location/Size are WORLD CM; Size.X =
-- circle radius cm; Settings 1=VisibleOnMap; EventHandlingMethod 0=Ignore (no
-- gameplay effect); Shape 0=Circle.
local PING_RADIUS_CM = 50000  -- 500 m test circle (match the outposts so it's obvious)
local PING_EXPIRE_SEC = 20     -- auto-remove the ping after this many seconds

-- v2 strategy: v1 crashed because it hand-built FCustomZoneConfiguration from Lua
-- tables, and that struct holds a nested TArray (DamageEventHandlingMethod) that
-- ended up a garbage pointer -> replication-serializer access violation. The
-- REGION struct (FCustomZoneRegion) has only simple fields, so it's safe to build.
-- So v2 REUSES the registry's own engine-formed config structs
-- (_defaultGlobalConfiguration + _defaultConfiguration, which have valid inner
-- TArrays) for the two config params, and hand-builds ONLY the region.
local WRITE_TEST_ENABLED = true

-- global + configs MUST be real engine structs (see WRITE_TEST_ENABLED note).
local function broadcastZones(reg, global, configs, regions)
    return pcall(function()
        reg:NetMulticast_ReceiveCustomZoneData(global, configs, regions)
    end)
end

-- Collect the registry's existing regions as REAL structs (copies from ForEach
-- :get()) so we can re-send them alongside our ping instead of wiping them.
local function collectRealRegions(reg)
    local arr = {}
    local regions = pcs(function() return reg._defaultRegions end, nil)
    if regions ~= nil then
        pcall(function()
            regions:ForEach(function(key, value)
                local v = pcs(function() return value:get() end, nil)
                if v ~= nil then arr[#arr + 1] = v end
            end)
        end)
    end
    return arr
end

-- Re-broadcast just the existing zones (ping never enters _defaultRegions, so this
-- drops it). Re-reads everything fresh so it's safe to run later from a timer.
local function rebroadcastExisting(reg, tag)
    local g = pcs(function() return reg._defaultGlobalConfiguration end, nil)
    local c = pcs(function() return reg._defaultConfiguration end, nil)
    if g == nil or c == nil then log(tag .. ": configs nil, skip"); return end
    local r = collectRealRegions(reg)
    local ok = broadcastZones(reg, g, { c }, r)
    log(string.format("%s: rebroadcast %d zones (ping removed) %s", tag, #r, ok and "OK" or "FAILED"))
end

local function doZoneTest(caller)
    if not WRITE_TEST_ENABLED then
        log("zonetest: DISABLED (table->struct build crashes the server). Using capture-and-mutate instead.")
        reply(caller, "zonetest is disabled — it crashes the server. See log.")
        return
    end
    if not (caller and caller.admin) then reply(caller, "zonetest is admin-only"); return end
    if not caller.x then reply(caller, "couldn't read your position"); return end
    local gs, reg = findRegistry(caller)
    if not reg or not pcs(function() return reg:IsValid() end, false) then
        log("zonetest: registry nil"); reply(caller, "registry nil — see log"); return
    end

    -- Reuse the registry's REAL config structs (engine-formed, valid inner
    -- TArrays) so we never hand-build the struct that crashed v1. The region
    -- references configs[0] -> inherits that config's color/visibility for now
    -- (we'll refine color once the mechanism is proven).
    local global = pcs(function() return reg._defaultGlobalConfiguration end, nil)
    local cfg0   = pcs(function() return reg._defaultConfiguration end, nil)
    if global == nil or cfg0 == nil then
        log("zonetest: real config structs unavailable (global=" .. tostring(global)
            .. " cfg0=" .. tostring(cfg0) .. ")")
        reply(caller, "can't read base configs — see log"); return
    end
    -- Red config for the ping, HAND-BUILT so it's independent of the registry
    -- (the outposts' real cfg0 is untouched and stays green). The only field that
    -- crashes table->struct marshalling is the FName (UniqueDefaultZoneName), so we
    -- OMIT it (and DamageEventHandlingMethod, which zero-inits to an empty list).
    -- Name/Settings/EventHandlingMethod/Color all marshal cleanly.
    local pingCfg = {
        Name = "Discord Ping",
        Settings = 1,             -- VisibleOnMap
        EventHandlingMethod = 0,  -- Ignore => no gameplay effect
        Color = { R = 1.0, G = 0.05, B = 0.05, A = 0.6 },  -- red
    }
    local configs = { cfg0, pingCfg }  -- index 0 = real (outposts), index 1 = ping
    local pingIdx = 1

    -- v3: PRESERVE the existing zones (real structs) so the trader/outpost circles
    -- don't blink out, then append our ping (proven-safe shape: OMIT the FName
    -- UniqueDefaultZoneName and DefaultZoneState — they default correctly).
    local regions = collectRealRegions(reg)
    local nKept = #regions
    regions[#regions + 1] = {
        Name = "PING " .. tostring(caller.name or ""),
        Location = { X = caller.x, Y = caller.y },
        Size = { X = PING_RADIUS_CM, Y = 0.0 },
        Shape = 0,                       -- Circle
        ConfigurationIndex = pingIdx,    -- -> red cfg1 (or cfg0 fallback)
    }

    log(string.format("zonetest v4: %d kept zones + 1 ping (cfgIdx=%d, r=%d) @ (%.1f, %.1f) by %s; expire %ds",
        nKept, pingIdx, PING_RADIUS_CM, caller.x, caller.y, tostring(caller.name), PING_EXPIRE_SEC))
    local ok, err = broadcastZones(reg, global, configs, regions)
    if not ok then
        log("zonetest: multicast FAILED: " .. tostring(err))
        reply(caller, "broadcast FAILED — see log"); return
    end
    log("zonetest: broadcast OK")
    reply(caller, string.format("red ping broadcast — open map (M); auto-clears in %ds", PING_EXPIRE_SEC))

    -- Auto-expire: re-broadcast existing-only after the delay (drops the ping).
    if type(ExecuteWithDelay) == "function" then
        ExecuteWithDelay(PING_EXPIRE_SEC * 1000, function()
            pcall(rebroadcastExisting, reg, "ping expire")
        end)
    else
        log("zonetest: ExecuteWithDelay unavailable — ping will NOT auto-expire (use zoneclear)")
    end
end

local function doZoneClear(caller)
    if not (caller and caller.admin) then reply(caller, "zoneclear is admin-only"); return end
    local gs, reg = findRegistry(caller)
    if not reg then reply(caller, "registry nil"); return end
    local global = pcs(function() return reg._defaultGlobalConfiguration end, nil)
    if global == nil then reply(caller, "can't read base config — see log"); return end
    local ok, err = broadcastZones(reg, global, {}, {})  -- empty configs + regions
    log(ok and "zoneclear: multicast empty set OK" or ("zoneclear FAILED: " .. tostring(err)))
    reply(caller, ok and "cleared (transient) — outposts return on reconnect" or "clear FAILED — see log")
end

-- 'zonebisect' (admin): make the multicast in escalating micro-steps, logging
-- BEFORE each call (log() flushes immediately). A native crash stops at the
-- failing step, so the LAST "BISECT ... calling" line names the exact culprit.
local function mc(reg, global, configs, regions, tag)
    log("BISECT " .. tag .. ": calling multicast...")
    local ok, err = pcall(function()
        reg:NetMulticast_ReceiveCustomZoneData(global, configs, regions)
    end)
    log("BISECT " .. tag .. (ok and ": SURVIVED" or (": lua-error " .. tostring(err))))
    return ok
end

local function doZoneBisect(caller)
    if not (caller and caller.admin) then reply(caller, "zonebisect is admin-only"); return end
    local gs, reg = findRegistry(caller)
    if not reg or not pcs(function() return reg:IsValid() end, false) then
        log("zonebisect: registry nil"); reply(caller, "registry nil — see log"); return
    end
    local global = pcs(function() return reg._defaultGlobalConfiguration end, nil)
    local cfg0   = pcs(function() return reg._defaultConfiguration end, nil)
    log(string.format("BISECT start: global=%s cfg0=%s pos=(%s,%s)",
        tostring(global ~= nil), tostring(cfg0 ~= nil), tostring(caller.x), tostring(caller.y)))
    if global == nil then reply(caller, "no global cfg — see log"); return end

    local region = {
        Name = "PINGBISECT",
        Location = { X = caller.x or 0.0, Y = caller.y or 0.0 },
        Size = { X = PING_RADIUS_CM, Y = 0.0 },
        Shape = 0, ConfigurationIndex = 0,
        UniqueDefaultZoneName = "None", DefaultZoneState = 0,
    }
    reply(caller, "running bisect — server may crash; the LAST 'BISECT' log line is the culprit")

    if not mc(reg, global, {}, {}, "A empty") then return end                 -- call itself + real global
    if cfg0 ~= nil and not mc(reg, global, { cfg0 }, {}, "B realcfg") then return end  -- real-struct-in-array
    if not mc(reg, global, {}, { region }, "C region") then return end        -- region marshalling
    if cfg0 ~= nil and not mc(reg, global, { cfg0 }, { region }, "D full") then return end
    log("BISECT: ALL STEPS SURVIVED")
    reply(caller, "bisect survived all steps — see log")
end

-- 'zonebisect2' (admin): the call + real structs are proven safe; this isolates
-- WHICH region-table field crashes marshalling, by building the region up one
-- field at a time (configs held constant at the real {cfg0}). Last "calling"
-- line = the field that killed it.
local function doZoneBisect2(caller)
    if not (caller and caller.admin) then reply(caller, "admin-only"); return end
    local gs, reg = findRegistry(caller)
    if not reg or not pcs(function() return reg:IsValid() end, false) then
        log("zonebisect2: registry nil"); reply(caller, "registry nil — see log"); return
    end
    local global = pcs(function() return reg._defaultGlobalConfiguration end, nil)
    local cfg0   = pcs(function() return reg._defaultConfiguration end, nil)
    if global == nil or cfg0 == nil then reply(caller, "no base configs — see log"); return end
    local X, Y = caller.x or 0.0, caller.y or 0.0

    -- C1: nested FVector2D + scalars only (no FString/FName/extra enum).
    local c1 = { Location = { X = X, Y = Y }, Size = { X = PING_RADIUS_CM, Y = 0.0 },
                 Shape = 0, ConfigurationIndex = 0 }
    -- C2: + Name (FString)
    local c2 = { Location = { X = X, Y = Y }, Size = { X = PING_RADIUS_CM, Y = 0.0 },
                 Shape = 0, ConfigurationIndex = 0, Name = "PINGBISECT" }
    -- C3: + UniqueDefaultZoneName (FName)  <-- prime suspect
    local c3 = { Location = { X = X, Y = Y }, Size = { X = PING_RADIUS_CM, Y = 0.0 },
                 Shape = 0, ConfigurationIndex = 0, Name = "PINGBISECT",
                 UniqueDefaultZoneName = "None" }
    -- C4: + DefaultZoneState (enum) = the full region
    local c4 = { Location = { X = X, Y = Y }, Size = { X = PING_RADIUS_CM, Y = 0.0 },
                 Shape = 0, ConfigurationIndex = 0, Name = "PINGBISECT",
                 UniqueDefaultZoneName = "None", DefaultZoneState = 0 }

    log("BISECT2 start: pos=(" .. tostring(X) .. "," .. tostring(Y) .. ")")
    reply(caller, "running zonebisect2 — LAST 'BISECT2' log line names the bad field")
    if not mc(reg, global, { cfg0 }, { c1 }, "C1 vec+scalars") then return end
    if not mc(reg, global, { cfg0 }, { c2 }, "C2 +Name(FString)") then return end
    if not mc(reg, global, { cfg0 }, { c3 }, "C3 +UniqueName(FName)") then return end
    if not mc(reg, global, { cfg0 }, { c4 }, "C4 +State(full)") then return end
    log("BISECT2: ALL REGION VARIANTS SURVIVED")
    reply(caller, "all region variants survived — open map (M)")
end

-- ---- chat dispatch -------------------------------------------------------
local function onChat(self, message, channel)
    local msg = ""
    pcall(function() msg = message:get():ToString() end)
    if type(msg) ~= "string" or msg == "" then return end
    local low = msg:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    local cmds = { [DUMP_TRIGGER]=true, zonetest=true, zoneclear=true, zonebisect=true, zonebisect2=true }
    if not cmds[low] then return end
    local caller = resolveCaller(self)
    if low == "zonetest" then pcall(doZoneTest, caller)
    elseif low == "zoneclear" then pcall(doZoneClear, caller)
    elseif low == "zonebisect" then pcall(doZoneBisect, caller)
    elseif low == "zonebisect2" then pcall(doZoneBisect2, caller)
    else pcall(doDump, caller) end
end

-- ---- bootstrap -----------------------------------------------------------
do local f = io.open(LOGFILE, "w"); if f then f:write("===== CustomZoneProbe started :: " .. ts() .. " =====\n"); f:close() end end

local function hook(target, cb, label)
    local ok, err = pcall(function() RegisterHook(target, cb) end)
    log(ok and (label .. ": hooked") or (label .. " FAILED: " .. tostring(err)))
end

hook("/Script/SCUM.PlayerRpcChannel:Chat_Server_BroadcastChatMessage",
    function(self, message, channel) pcall(onChat, self, message, channel) end,
    "chat ('" .. DUMP_TRIGGER .. "')")

hook("/Script/SCUM.PlayerRpcChannel:CustomZones_Server_UpdateCustomZoneData",
    function(self, gcfg, cfgs, regions)
        pcall(dumpRpcPayload, "Server_UpdateCustomZoneData (admin -> server)", self, gcfg, cfgs, regions)
    end,
    "CustomZones_Server_UpdateCustomZoneData")

hook("/Script/SCUM.PlayerRpcChannel:CustomZones_Client_ReceiveCustomZoneData",
    function(self, gcfg, cfgs, regions)
        pcall(dumpRpcPayload, "Client_ReceiveCustomZoneData (server -> client)", self, gcfg, cfgs, regions)
    end,
    "CustomZones_Client_ReceiveCustomZoneData")

log("=====================================================")
log("CustomZoneProbe ready. Type '" .. DUMP_TRIGGER .. "' in chat to dump the registry.")
log("Then draw a custom zone in-game (admin) and re-read this log.")
log("=====================================================")
