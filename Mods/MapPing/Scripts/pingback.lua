-- MapPing reverse path (reloadable): Discord "Ping Green"/"Ping Red" buttons ->
-- a colored circle on every connected client's in-game map.
--
-- Flow: a Discord button enqueues a {"action":"map_ping",x,y,color} command in the
-- sidecar. This file POLLS the sidecar's GET /commands, and for each map_ping it
-- adds an entry to an active-pings list and broadcasts the whole set to all clients
-- via the custom-zone registry. Pings auto-expire.
--
-- The broadcast recipe (proven in Mods/CustomZoneProbe): reuse the registry's REAL
-- config structs, re-send the existing zones (the multicast REPLACES the client's
-- whole set), and append our hand-built ping regions. NEVER hand-build a struct
-- with an FName field — marshalling an FName from a Lua string crashes the server,
-- so region/config OMIT UniqueDefaultZoneName.

local MP = MapPing
local C  = MP.config

MP.activePings = MP.activePings or {}   -- {x,y,color,label,expireAt}; survives reloads

-- ---- tiny JSON decoder (objects/arrays/strings/numbers/bool/null) ---------
local function jsonDecode(str)
    local pos = 1
    local parseValue
    local function skipws()
        local _, e = str:find("^[ \t\r\n]*", pos); if e then pos = e + 1 end
    end
    local function parseString()
        pos = pos + 1  -- skip opening quote
        local buf = {}
        while true do
            local c = str:sub(pos, pos)
            if c == "" then error("unterminated string") end
            if c == '"' then pos = pos + 1; break end
            if c == "\\" then
                local n = str:sub(pos + 1, pos + 1)
                local map = { ['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t' }
                if map[n] then buf[#buf+1] = map[n]; pos = pos + 2
                elseif n == 'u' then
                    local code = tonumber(str:sub(pos + 2, pos + 5), 16) or 0
                    pos = pos + 6
                    if code < 0x80 then buf[#buf+1] = string.char(code)
                    elseif code < 0x800 then
                        buf[#buf+1] = string.char(0xC0 + math.floor(code/0x40), 0x80 + (code%0x40))
                    else
                        buf[#buf+1] = string.char(0xE0 + math.floor(code/0x1000),
                            0x80 + (math.floor(code/0x40) % 0x40), 0x80 + (code % 0x40))
                    end
                else buf[#buf+1] = n; pos = pos + 2 end
            else
                buf[#buf+1] = c; pos = pos + 1
            end
        end
        return table.concat(buf)
    end
    parseValue = function()
        skipws()
        local c = str:sub(pos, pos)
        if c == '{' then
            pos = pos + 1; local obj = {}; skipws()
            if str:sub(pos, pos) == '}' then pos = pos + 1; return obj end
            while true do
                skipws()
                if str:sub(pos, pos) ~= '"' then error("expected key") end
                local k = parseString(); skipws()
                if str:sub(pos, pos) ~= ':' then error("expected :") end
                pos = pos + 1; obj[k] = parseValue(); skipws()
                local ch = str:sub(pos, pos)
                if ch == ',' then pos = pos + 1
                elseif ch == '}' then pos = pos + 1; break
                else error("expected , or }") end
            end
            return obj
        elseif c == '[' then
            pos = pos + 1; local arr = {}; skipws()
            if str:sub(pos, pos) == ']' then pos = pos + 1; return arr end
            while true do
                arr[#arr+1] = parseValue(); skipws()
                local ch = str:sub(pos, pos)
                if ch == ',' then pos = pos + 1
                elseif ch == ']' then pos = pos + 1; break
                else error("expected , or ]") end
            end
            return arr
        elseif c == '"' then return parseString()
        elseif c == 't' then pos = pos + 4; return true
        elseif c == 'f' then pos = pos + 5; return false
        elseif c == 'n' then pos = pos + 4; return nil
        else
            local s, e = str:find("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
            if not s then error("unexpected char '" .. c .. "'") end
            local num = tonumber(str:sub(s, e)); pos = e + 1; return num
        end
    end
    local ok, res = pcall(parseValue)
    if not ok then return nil, res end
    return res
end
MP._jsonDecode = jsonDecode  -- exposed for offline tests

-- ---- custom-zone broadcast (the proven recipe) ---------------------------
local function findRegistry()
    local gs
    pcall(function() gs = FindFirstOf("ConZGameState") end)
    if not gs then return nil end
    local valid = false; pcall(function() valid = gs:IsValid() end)
    if not valid then return nil end
    local reg; pcall(function() reg = gs._customZoneRegistry end)
    return reg
end

-- Existing regions as REAL structs (so trader/outpost circles aren't wiped).
local function collectRealRegions(reg)
    local arr = {}
    local regions; pcall(function() regions = reg._defaultRegions end)
    if regions ~= nil then
        pcall(function()
            regions:ForEach(function(key, value)
                local v; pcall(function() v = value:get() end)
                if v ~= nil then arr[#arr+1] = v end
            end)
        end)
    end
    return arr
end

-- Broadcast existing zones + all active pings to every client.
function MP.applyPings()
    local reg = findRegistry()
    if not reg then MP.log("applyPings: no registry (no world yet?)"); return end
    local global, cfg0
    pcall(function() global = reg._defaultGlobalConfiguration end)
    pcall(function() cfg0 = reg._defaultConfiguration end)
    if global == nil or cfg0 == nil then MP.log("applyPings: base configs nil"); return end

    -- Hand-built ping configs (safe: no FName). Index 0 stays the REAL config so
    -- existing regions (ConfigurationIndex 0) keep their color; 1=green, 2=red.
    local green = { Name = "Ping Green", Settings = 1, EventHandlingMethod = 0,
                    Color = { R = 0.10, G = 0.90, B = 0.20, A = 0.55 } }
    local red   = { Name = "Ping Red",   Settings = 1, EventHandlingMethod = 0,
                    Color = { R = 0.95, G = 0.08, B = 0.08, A = 0.55 } }
    local configs = { cfg0, green, red }

    local regions = collectRealRegions(reg)
    local nBase = #regions
    local radius = C.pingRadiusCm or 30000
    for _, p in ipairs(MP.activePings) do
        regions[#regions+1] = {
            Name = p.label or "PING",
            Location = { X = p.x, Y = p.y },
            Size = { X = p.radius or radius, Y = 0.0 },
            Shape = 0,                                       -- Circle
            ConfigurationIndex = (p.color == "red") and 2 or 1,
        }
    end

    local ok, err = pcall(function()
        reg:NetMulticast_ReceiveCustomZoneData(global, configs, regions)
    end)
    if ok then MP.log(string.format("applyPings: %d kept zones + %d pings", nBase, #MP.activePings))
    else MP.log("applyPings FAILED: " .. tostring(err)) end
end

-- ---- active-ping bookkeeping ---------------------------------------------
local function purgeExpired()
    local now, kept, removed = os.time(), {}, 0
    for _, p in ipairs(MP.activePings) do
        if p.expireAt and p.expireAt > now then kept[#kept+1] = p else removed = removed + 1 end
    end
    MP.activePings = kept
    return removed
end

local function handleCommand(cmd)
    if type(cmd) ~= "table" or cmd.action ~= "map_ping" then return false end
    local x, y = tonumber(cmd.x), tonumber(cmd.y)
    if not x or not y then MP.log("map_ping: bad coords, ignored"); return false end
    local color = (cmd.color == "red") and "red" or "green"
    local label = cmd.player and ("PING " .. tostring(cmd.player)) or "PING"
    MP.activePings[#MP.activePings+1] = {
        x = x, y = y, color = color, label = label,
        expireAt = os.time() + (C.pingExpireSec or 30),
    }
    MP.log(string.format("map_ping: %s @ (%.0f, %.0f) by %s", color, x, y, tostring(cmd.by)))
    return true
end

-- ---- non-blocking poll loop ----------------------------------------------
-- Decoupled so the game thread never blocks on the network: each tick reads the
-- PREVIOUS tick's response file, then launches a fresh DETACHED curl GET whose
-- output lands by the next tick.
local RESP = (MP.modDir or ".") .. [[\.commands.json]]

function MP.pollOnce()
    -- 1) consume the previous response, if curl has written it
    local f = io.open(RESP, "r")
    if f then
        local body = f:read("*a"); f:close(); os.remove(RESP)
        if body and #body > 0 then
            local data, derr = jsonDecode(body)
            if not data then
                MP.log("poll: JSON decode failed (" .. tostring(derr) .. ")")
            elseif type(data.commands) == "table" then
                local changed = false
                for _, c in ipairs(data.commands) do
                    if handleCommand(c) then changed = true end
                end
                if changed then MP.applyPings() end
            end
        end
    end

    -- 2) drop expired pings (re-broadcast so they disappear)
    if purgeExpired() > 0 then MP.applyPings() end

    -- 3) launch the next detached GET
    local curl    = C.curlExe or "curl"
    local url     = (C.sidecarUrl or "http://127.0.0.1:8765") .. "/commands"
    local key     = C.apiKey or "change-me"
    local timeout = tostring(C.httpTimeoutSec or 5)
    os.execute(string.format(
        'start "" /B %s -s -m %s "%s" -H "X-API-Key: %s" -o "%s" >nul 2>&1',
        curl, timeout, url, key, RESP))
end

-- Self-rescheduling timer. Guarded so reloads don't spawn duplicate loops; the
-- tick reads MP.pollOnce by name each fire, so hot-reloads take effect live.
function MP.startPolling()
    if not (C and C.pollEnabled) then MP.log("reverse-ping polling disabled in config"); return end
    if MP._pollingStarted then return end
    if type(ExecuteWithDelay) ~= "function" then MP.log("ExecuteWithDelay missing — polling NOT started"); return end
    MP._pollingStarted = true
    local interval = (C.pollIntervalSec or 5) * 1000
    local function tick()
        pcall(MP.pollOnce)
        ExecuteWithDelay(interval, tick)
    end
    ExecuteWithDelay(2000, tick)
    MP.log("reverse-ping polling started (every " .. (C.pollIntervalSec or 5) .. "s)")
end
