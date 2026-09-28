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

-- A full walk is ~10k frames on Retail and costs a couple hundred ms, so it
-- runs in slices of BUDGET ms per rendered frame instead of all at once.
-- Frames are never destroyed, so the cursor stays valid between slices.
local BUDGET = 2
local runner = CreateFrame("Frame")
local cursor, scanning, again, count, spent, slices

local function step()
    if InCombatLockdown() then
        runner:SetScript("OnUpdate", nil)
        scanning, pending = false, true
        return
    end
    local start = debugprofilestop()
    local f = cursor or EnumerateFrames()
    while f do
        count = count + 1
        local ok, yes = pcall(candidate, f)
        if ok and yes then tracked[f] = ns.CreateFrameStamp(f) end
        f = EnumerateFrames(f)
        if debugprofilestop() - start > BUDGET then break end
    end
    cursor = f
    spent, slices = spent + (debugprofilestop() - start), slices + 1
    if f then return end

    runner:SetScript("OnUpdate", nil)
    scanning = false
    ns.PerfLog("frame scan", spent, (" (%d frames over %d slices)"):format(count, slices))
    if ns.scanReport then ns.scanReport = false; ns.ReportFrames() end
    ns.RefreshFrames()
    if again then again = false; ns.ScheduleScan(1) end
end

local function scan()
    scheduled = false
    if InCombatLockdown() then pending = true return end
    if scanning then return end
    pending, scanning = false, true
    cursor, count, spent, slices = nil, 0, 0, 0
    runner:SetScript("OnUpdate", step)
end

-- /hon scan: lists the unit frames we know about, grouped by unit.
function ns.ReportFrames()
    local total, byUnit = 0, {}
    for btn in pairs(tracked) do
        total = total + 1
        local u = btn:GetAttribute("unit")
        if u == "target" or u == "focus" or u == "player" then
            byUnit[u] = byUnit[u] or {}
            local name = btn:GetName() or "unnamed"
            table.insert(byUnit[u], name .. (btn:IsVisible() and "" or " (hidden)"))
        end
    end
    ns.Print(("Tracking %d unit frames."):format(total))
    for _, u in ipairs({ "player", "target", "focus" }) do
        ns.Print(("  %s: %s"):format(u, byUnit[u] and table.concat(byUnit[u], ", ") or "none"))
    end
end

function ns.ScheduleScan(delay)
    if scanning then again = true return end
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
-- Marking someone doesn't create frames, so just restyle the known ones.
ns.OnChange(ns.RefreshFrames, "unit frames")
