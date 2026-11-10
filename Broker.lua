local _, ns = ...

-- LibDataBroker data source, for info bars that show broker plugins
-- (EllesmereUI DataBars' Broker Plugin block, Titan Panel, ChocolateBar...).
-- We don't ship the library: EllesmereUI and most bar addons do, and with
-- none of them loaded there's nothing to show it on anyway.

local obj

local function groupEntries()
    local found = {}
    local n = GetNumGroupMembers()
    if n == 0 then return found end
    local raid = IsInRaid()
    local prefix = raid and "raid" or "party"
    local count = raid and n or (n - 1)
    for i = 1, count do
        local entry = ns.GetUnit(prefix .. i)
        if entry and entry ~= ns.TEST_ENTRY then found[#found + 1] = entry end
    end
    return found
end

local function update()
    if not obj then return end
    local byCat = {}
    for _, e in ipairs(groupEntries()) do byCat[e.cat] = (byCat[e.cat] or 0) + 1 end
    local parts = {}
    for _, c in ipairs(ns.CATEGORY_ORDER) do
        if byCat[c] then parts[#parts + 1] = ("|c%s%d %s|r"):format(ns.ColorHex(c), byCat[c], ns.CatLabel(c)) end
    end
    if #parts > 0 then
        obj.text = table.concat(parts, ", ") .. " in group"
    else
        local total = 0
        for _ in pairs(ns.db.players) do total = total + 1 end
        obj.text = ("%d marked"):format(total)
    end
end

local function tooltip(tt)
    tt:AddLine("|cff40ff59Help|r or |cffff3333Not|r")
    local inGroup = groupEntries()
    if #inGroup > 0 then
        tt:AddLine(" ")
        tt:AddLine("In your group", 1, 0.82, 0)
        for _, e in ipairs(inGroup) do
            local r, g, b = ns.Color(e.cat)
            tt:AddDoubleLine(ns.DisplayName(e), ns.CatLabel(e.cat), 1, 1, 1, r, g, b)
        end
    end
    local byCat = {}
    for _, e in pairs(ns.db.players) do byCat[e.cat] = (byCat[e.cat] or 0) + 1 end
    tt:AddLine(" ")
    tt:AddLine("Your list", 1, 0.82, 0)
    for _, c in ipairs(ns.CATEGORY_ORDER) do
        local r, g, b = ns.Color(c)
        tt:AddDoubleLine(ns.CatLabel(c), tostring(byCat[c] or 0), r, g, b, 1, 1, 1)
    end
    tt:AddLine(" ")
    tt:AddLine("Left-click: open your list", 0.6, 0.6, 0.6)
    tt:AddLine("Right-click: recent players", 0.6, 0.6, 0.6)
end

ns.OnLogin(function()
    local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not LDB then return end
    obj = LDB:NewDataObject("Help or Not", {
        type = "data source",
        label = "Help or Not",
        text = "",
        icon = "Interface\\RaidFrame\\ReadyCheck-NotReady",
        OnClick = function(_, button)
            if button == "RightButton" then ns.ShowRecent() else ns.ToggleUI() end
        end,
        OnTooltipShow = tooltip,
    })
    update()
end)

ns.OnChange(update, "broker")
ns.On("GROUP_ROSTER_UPDATE", update)
