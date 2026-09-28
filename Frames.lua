local _, ns = ...

-- Doesn't depend on any UI's internals. It finds every Button carrying a
-- secure "unit" attribute (EllesmereUI, Blizzard, or anything else) and lays
-- a non-secure overlay on top. Scans only run out of combat.

local tracked = {}
local PATTERNS = { "^player$", "^target$", "^focus$", "^party%d$", "^raid%d+$", "^arena%d$" }
local pending, scheduled = false, false

local function isUnitToken(u)
    if type(u) ~= "string" then return false end
    for i = 1, #PATTERNS do
        if u:find(PATTERNS[i]) then return true end
    end
    return false
end

local function candidate(f)
    if tracked[f] or f.HONSkip then return false end
    if f:IsForbidden() then return false end
    if not f:IsObjectType("Button") or not f.GetAttribute then return false end
    return isUnitToken(f:GetAttribute("unit"))
end

function ns.RefreshFrames()
    local enabled = ns.db and ns.db.settings.frames
    for btn, stamp in pairs(tracked) do
        local entry
        if enabled and btn:IsVisible() then
            local u = btn:GetAttribute("unit")
            if type(u) == "string" then entry = ns.GetUnit(u) end
        end
        if entry then
            ns.StyleStamp(stamp, entry)
            stamp:Show()
        else
            stamp:Hide()
        end
    end
end

local function scan()
    scheduled = false
    if InCombatLockdown() then pending = true return end
    pending = false
    local f = EnumerateFrames()
    while f do
        local ok, yes = pcall(candidate, f)
        if ok and yes then tracked[f] = ns.CreateFrameStamp(f) end
        f = EnumerateFrames(f)
    end
    ns.RefreshFrames()
end

function ns.ScheduleScan(delay)
    if scheduled then return end
    scheduled = true
    C_Timer.After(delay or 1, scan)
end

ns.OnLogin(function()
    ns.ScheduleScan(3)
    C_Timer.NewTicker(1, ns.RefreshFrames)
end)

ns.On("GROUP_ROSTER_UPDATE", function() ns.ScheduleScan(1); ns.RefreshFrames() end)
ns.On("PLAYER_ENTERING_WORLD", function() ns.ScheduleScan(2) end)
ns.On("PLAYER_REGEN_ENABLED", function() if pending then ns.ScheduleScan(0.5) end end)
ns.On("PLAYER_TARGET_CHANGED", function() ns.RefreshFrames() end)
ns.On("PLAYER_FOCUS_CHANGED", function() ns.RefreshFrames() end)
ns.OnChange(function() ns.ScheduleScan(0.2); ns.RefreshFrames() end)
