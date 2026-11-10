local _, ns = ...

-- Minimap button. Named and parented to Minimap so minimap addons that
-- gather buttons (EllesmereUI Minimap, button bags) pick it up.

local btn

local function place()
    local angle = math.rad(ns.db.settings.minimapAngle or 225)
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape ~= "ROUND" then
        -- Square minimaps: push the button out to the edge instead of a circle.
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
    end
    local r = Minimap:GetWidth() / 2 + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

local function onDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    ns.db.settings.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    place()
end

local function build()
    btn = CreateFrame("Button", "HelpOrNotMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then ns.ShowOptions() else ns.ToggleUI() end
    end)
    btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDragUpdate) end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cff40ff59Help|r or |cffff3333Not|r")
        GameTooltip:AddLine("Left-click: open your list", 1, 1, 1)
        GameTooltip:AddLine("Right-click: options", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    place()
end

local function refresh()
    if not Minimap then return end
    if ns.db.settings.minimap then
        if not btn then build() end
        btn:Show()
    elseif btn then
        btn:Hide()
    end
end

ns.OnLogin(refresh)
ns.OnChange(refresh, "minimap button")
