local _, ns = ...

-- Recent players: everyone you've grouped with, newest first, so a griefer
-- can still be marked after they've left the group.

local MAX = 50
local inGroup = {}  -- keys seen in the current group, so each join records once

local function where()
    local ok, name, kind = pcall(GetInstanceInfo)
    if ok and kind and kind ~= "none" and type(name) == "string" and name ~= "" and not ns.IsSecret(name) then return name end
    local ok2, zone = pcall(GetRealZoneText)
    if ok2 and type(zone) == "string" and zone ~= "" and not ns.IsSecret(zone) then return zone end
end

local function record(unit, key)
    local ok, name, realm = pcall(UnitName, unit)
    if not ok then return end
    local _, n, r = ns.Key(name, realm)
    if not n then return end
    local list = ns.db.recent
    for i = #list, 1, -1 do
        if list[i].key == key then table.remove(list, i) end
    end
    table.insert(list, 1, { key = key, name = n, realm = r, class = ns.UnitClassToken(unit), faction = ns.UnitFaction(unit), zone = where(), t = time() })
    for i = #list, MAX + 1, -1 do list[i] = nil end
end

local function scan()
    if not ns.db.settings.recent then return end
    local n = GetNumGroupMembers()
    if n == 0 then wipe(inGroup) return end
    local raid = IsInRaid()
    local prefix = raid and "raid" or "party"
    local count = raid and n or (n - 1)
    local me, changed = ns.PlayerKey(), false
    for i = 1, count do
        local unit = prefix .. i
        local key = ns.UnitKey(unit)
        if key and key ~= me and not inGroup[key] then
            inGroup[key] = true
            record(unit, key)
            changed = true
        end
    end
    if changed then ns.RefreshUI() end
end

function ns.ClearRecent()
    wipe(ns.db.recent)
    ns.RefreshUI()
end

ns.On("GROUP_ROSTER_UPDATE", scan)
-- Names can be unavailable on the roster event (loading screens, Midnight
-- instance restrictions), so look again after zoning.
ns.On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, scan) end)
ns.OnLogin(function() C_Timer.After(5, scan) end)
