local _, ns = ...

-- Anchors to Blizzard's base nameplate, which EllesmereUI and other plate
-- addons build on. Friendly plates inside PvE instances are forbidden to
-- addons, so GetNamePlateForUnit returns nil there and raid frames carry
-- the marking instead.
--
-- "Marked only" mode: turns friendly player nameplates on outside PvE
-- instances, then fades every friendly player plate to invisible unless
-- that player is on your list. Result: you only see plates over people
-- you've marked.

local stamps = {}

local function cvarGet(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar(name)
end
local function cvarSet(name, value)
    if C_CVar and C_CVar.SetCVar then return C_CVar.SetCVar(name, value) end
    return SetCVar(name, value)
end

local function safeBool(fn, ...)
    local ok, v = pcall(fn, ...)
    if not ok or ns.IsSecret(v) then return nil end
    return v
end

local function plateFor(unit)
    if not C_NamePlate or type(unit) ~= "string" or ns.IsSecret(unit) then return nil end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return nil end
    return plate
end

local function isFriendlyPlayer(unit)
    return safeBool(UnitIsPlayer, unit) and safeBool(UnitIsFriend, "player", unit) and true or false
end

---------------------------------------------------------------------------
-- Fade a plate's visuals (Blizzard's or EllesmereUI's) without touching our stamp
---------------------------------------------------------------------------
local function keepHidden(self, a)
    if self.honHidden and type(a) == "number" and not ns.IsSecret(a) and a > 0 then
        self:SetAlpha(0)
    end
end

local function setHidden(plate, hide)
    local kids = { plate:GetChildren() }
    for i = 1, #kids do
        local child = kids[i]
        if not child.HONSkip and not (child.IsForbidden and child:IsForbidden()) then
            if hide then
                if not child.honHooked then
                    hooksecurefunc(child, "SetAlpha", keepHidden)
                    child.honHooked = true
                end
                child.honHidden = true
                pcall(child.SetAlpha, child, 0)
            elseif child.honHidden then
                child.honHidden = false
                pcall(child.SetAlpha, child, 1)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Per plate update
---------------------------------------------------------------------------
local function update(unit)
    local plate = plateFor(unit)
    if not plate then return end
    local settings = ns.db.settings
    local entry = ns.GetUnit(unit)
    local s = stamps[plate]

    if entry and settings.plates then
        if not s then s = ns.CreatePlateStamp(plate); stamps[plate] = s end
        ns.StylePlateStamp(s, entry)
        s:Show()
    elseif s then
        s:Hide()
    end

    setHidden(plate, settings.markedOnly and not entry and isFriendlyPlayer(unit))
end

function ns.RefreshPlates()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then
            update(unit)
        else
            if stamps[plate] then stamps[plate]:Hide() end
            setHidden(plate, false)
        end
    end
end

ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit)
    update(unit)
    -- Plate addons can build their frames after us; catch those next frame.
    C_Timer.After(0, function() update(unit) end)
end)

ns.On("NAME_PLATE_UNIT_REMOVED", function(_, unit)
    local plate = plateFor(unit)
    if not plate then return end
    if stamps[plate] then stamps[plate]:Hide() end
    -- Plates get recycled for enemies, so always restore on release.
    setHidden(plate, false)
end)

ns.On("UNIT_NAME_UPDATE", function(_, unit)
    if type(unit) == "string" and not ns.IsSecret(unit) and unit:find("^nameplate") then update(unit) end
end)

---------------------------------------------------------------------------
-- Friendly nameplate CVar handling for Marked only mode
---------------------------------------------------------------------------
local pendingCVar = false

local function inPvEInstance()
    local inside, kind = IsInInstance()
    return inside and (kind == "party" or kind == "raid" or kind == "scenario")
end

local function setClickThrough(on)
    if C_NamePlate and C_NamePlate.SetNamePlateFriendlyClickThrough then
        pcall(C_NamePlate.SetNamePlateFriendlyClickThrough, on)
    end
end

function ns.ApplyPlateMode()
    if InCombatLockdown() then pendingCVar = true return end
    pendingCVar = false
    local st = ns.db.settings

    if not st.markedOnly then
        if st.savedShowFriends ~= nil then
            cvarSet("nameplateShowFriends", st.savedShowFriends)
            st.savedShowFriends = nil
            setClickThrough(false)
        end
        return
    end

    if st.savedShowFriends == nil then st.savedShowFriends = cvarGet("nameplateShowFriends") or "0" end

    if inPvEInstance() then
        -- Addons can't touch friendly plates in here, so put your own setting back.
        cvarSet("nameplateShowFriends", st.savedShowFriends)
        setClickThrough(false)
    else
        cvarSet("nameplateShowFriends", "1")
        -- Invisible plates shouldn't steal your clicks.
        setClickThrough(true)
    end
end

ns.OnLogin(ns.ApplyPlateMode)
ns.On("PLAYER_ENTERING_WORLD", function() ns.ApplyPlateMode() end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.ApplyPlateMode() end)
ns.On("PLAYER_REGEN_ENABLED", function() if pendingCVar then ns.ApplyPlateMode() end end)
ns.OnChange(function() ns.ApplyPlateMode(); ns.RefreshPlates() end)
