-- live.lua -- upgrade experiment v3: fire UpgradeBaseElement(180) with REAL
-- BaseElementIds (from SCUM.db base_element table). Test on the 3 twig
-- foundations: element_ids 100, 101, 102. WATCH the twig foundations.

local UEHelpers = require("UEHelpers")
local Out = [[C:\Users\jason\Desktop\Projects\SCUM-Modding\.staging\recon_upgrade.txt]]
local f = io.open(Out, "w"); if not f then print("[live] cannot open"); return end
f:setvbuf("no")
local function wl(s) f:write(s); f:write("\n") end
wl("=== upgrade experiment v3 (REAL ids) :: " .. os.date("%Y-%m-%d %H:%M:%S") .. " ===\n")

local function find_first(c)
    local l = FindAllOf(c); if not l or #l==0 then return nil end
    for i=1,#l do if l[i] and l[i]:IsValid() then return l[i] end end
end
local function deref(raw)
    if raw == nil then return nil end
    local ok, v = pcall(function() return raw:get() end); if ok then return v end; return raw
end

local pc; pcall(function() pc = UEHelpers.GetPlayerController() end)
if not (pc and pc:IsValid()) then pc = find_first("BP_ConZPlayerController_C") end
local chan; if pc then pcall(function() chan = pc._playerRpcChannel end) end
local elem = find_first("BP_ConZBaseElement_C")
if not (pc and chan and elem) then wl("missing object"); f:close(); print("[live] missing"); return end

-- get a foundation-twig instance location (runtime, rebased) for the location field
local floc = { X=0, Y=0, Z=0 }
local ecm; pcall(function() ecm = elem._elementClassMap end)
if ecm then
    pcall(function()
        ecm:ForEach(function(k_raw, v_raw)
            local mesh = deref(k_raw); local h = deref(v_raw)
            local mn=""; pcall(function() mn = mesh:GetFName():ToString() end)
            if mn:lower():find("foundation_base_twig") then
                local out = {}; pcall(function() h:GetInstanceTransform(0, out, true) end)
                if out.Translation then floc = out.Translation end
            end
        end)
    end)
end
wl(string.format("foundation-twig sample loc = (%.0f,%.0f,%.0f)", floc.X or 0, floc.Y or 0, floc.Z or 0))

-- fire UpgradeBaseElement(180) for the 3 twig foundation ids via client->server
local FOUNDATION_TWIG_IDS = { 100, 101, 102 }
for _, id in ipairs(FOUNDATION_TWIG_IDS) do
    local data = {
        ModifierPressed=false, IntegerData=0, BoolData=false,
        BaseElementId = id,
        InteractionLocation = { X=floc.X or 0, Y=floc.Y or 0, Z=floc.Z or 0 },
        InteractionNormal   = { X=0, Y=0, Z=1 },
        VectorData          = { X=floc.X or 0, Y=floc.Y or 0, Z=floc.Z or 0 },
    }
    local ok, err = pcall(function() chan:InteractWithObjectOnServer(elem, pc, 180, data) end)
    wl(string.format("  InteractWithObjectOnServer id=%d ok=%s %s", id, tostring(ok), err and ("err="..tostring(err)) or ""))
end

f:close()
print("[live] upgrade experiment v3 done -> recon_upgrade.txt")
