local _, ns = ...

local ICON = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local ICON_GOOD = "Interface\\RaidFrame\\ReadyCheck-Ready"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT

local function addBorder(f, t)
    f.edges = {}
    local specs = {
        { "TOPLEFT", "TOPRIGHT", nil, t },
        { "BOTTOMLEFT", "BOTTOMRIGHT", nil, t },
        { "TOPLEFT", "BOTTOMLEFT", t, nil },
        { "TOPRIGHT", "BOTTOMRIGHT", t, nil },
    }
    for i, s in ipairs(specs) do
        local tex = f:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(FLAT)
        tex:SetPoint(s[1])
        tex:SetPoint(s[2])
        if s[3] then tex:SetWidth(s[3]) else tex:SetHeight(s[4]) end
        f.edges[i] = tex
    end
end

local function addPulse(f)
    local ag = f:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.45)
    a:SetDuration(0.6)
    ag:SetLooping("BOUNCE")
    f.pulse = ag
end

local function setPulse(f, on)
    if not f.pulse then return end
    if on and not f.pulse:IsPlaying() then f.pulse:Play()
    elseif not on and f.pulse:IsPlaying() then f.pulse:Stop(); f:SetAlpha(1) end
end

---------------------------------------------------------------------------
-- Unit frame stamp (EllesmereUI, Blizzard, or anything with a unit attribute)
---------------------------------------------------------------------------
-- Blizzard's Retail player/target/focus buttons are far bigger than their
-- art (they cover the name row, portrait and buffs), so box the bars instead.
local function barsOf(button)
    local content = button.TargetFrameContent or button.PlayerFrameContent
    local main = content and (content.TargetFrameContentMain or content.PlayerFrameContentMain)
    local health = main and main.HealthBarsContainer
    if not health then return nil end
    return health, main.ManaBar or (main.ManaBarArea and main.ManaBarArea.ManaBar)
end

function ns.CreateFrameStamp(button)
    local s = CreateFrame("Frame", nil, button)
    s.HONSkip = true
    local health, mana = barsOf(button)
    if health then
        s:SetPoint("TOPLEFT", health, "TOPLEFT", -2, 2)
        s:SetPoint("BOTTOMRIGHT", mana or health, "BOTTOMRIGHT", 2, -2)
    else
        s:SetAllPoints(button)
    end
    s:SetFrameLevel(button:GetFrameLevel() + 25)
    s:EnableMouse(false)

    s.tint = s:CreateTexture(nil, "ARTWORK")
    s.tint:SetAllPoints()
    s.tint:SetTexture(FLAT)
    addBorder(s, 2)

    s.icon = s:CreateTexture(nil, "OVERLAY")
    s.icon:SetTexture(ICON)
    s.icon:SetSize(14, 14)
    s.icon:SetPoint("TOPLEFT", 3, -3)

    s.text = s:CreateFontString(nil, "OVERLAY")
    s.text:SetFont(FONT, 9, "OUTLINE")
    s.text:SetPoint("TOP", 0, -3)
    s.text:SetText("DO NOT HELP")

    addPulse(s)
    s:Hide()
    return s
end

function ns.StyleStamp(s, entry)
    local r, g, b = ns.Color(entry.cat)
    local good = ns.IsGood(entry.cat)
    s.tint:SetVertexColor(r, g, b, good and 0.12 or 0.28)
    for i = 1, #s.edges do s.edges[i]:SetVertexColor(r, g, b, 1) end
    s.icon:SetTexture(good and ICON_GOOD or ICON)
    s.text:SetText(ns.StampText(entry.cat))
    s.text:SetTextColor(r, g, b)
    setPulse(s, entry.cat == "griefer")
end

---------------------------------------------------------------------------
-- Nameplate stamp: big icon + DO NOT HELP above the plate
---------------------------------------------------------------------------
function ns.CreatePlateStamp(plate)
    local s = CreateFrame("Frame", nil, plate)
    s.HONSkip = true
    s:SetSize(150, 50)
    s:SetFrameLevel(plate:GetFrameLevel() + 50)
    s:EnableMouse(false)

    s.icon = s:CreateTexture(nil, "OVERLAY")
    s.icon:SetTexture(ICON)
    s.icon:SetSize(26, 26)
    s.icon:SetPoint("TOP")

    s.text = s:CreateFontString(nil, "OVERLAY")
    s.text:SetFont(FONT, 13, "OUTLINE")
    s.text:SetPoint("TOP", s.icon, "BOTTOM", 0, -1)
    s.text:SetText("DO NOT HELP")

    s.sub = s:CreateFontString(nil, "OVERLAY")
    s.sub:SetFont(FONT, 9, "OUTLINE")
    s.sub:SetPoint("TOP", s.text, "BOTTOM", 0, -1)

    addPulse(s)
    s:Hide()
    return s
end

-- The plate frame is much taller than what's drawn (friendly players are
-- often just a name), so sit on the visible name, then the health bar,
-- then the plate itself (EllesmereUI and other plate addons).
function ns.AnchorPlateStamp(s, plate)
    local uf, target = plate.UnitFrame, plate
    if uf then
        local health = uf.HealthBarsContainer or uf.healthBar
        if uf.name and uf.name:IsVisible() then target = uf.name
        elseif health and health:IsVisible() then target = health end
    end
    if s.anchor ~= target then
        s:ClearAllPoints()
        s:SetPoint("BOTTOM", target, "TOP", 0, 2)
        s.anchor = target
    end
end

function ns.StylePlateStamp(s, entry)
    local r, g, b = ns.Color(entry.cat)
    local good = ns.IsGood(entry.cat)
    s.icon:SetTexture(good and ICON_GOOD or ICON)
    s.text:SetText(ns.StampText(entry.cat))
    s.text:SetTextColor(r, g, b)
    s.sub:SetTextColor(r, g, b)
    s.sub:SetText(good and "" or ns.CatLabel(entry.cat):upper())
    setPulse(s, entry.cat == "griefer")
end

---------------------------------------------------------------------------
-- Center screen banner (on target)
---------------------------------------------------------------------------
local banner
local function getBanner()
    if banner then return banner end
    banner = CreateFrame("Frame", "HelpOrNotBanner", UIParent)
    banner:SetSize(500, 70)
    banner:SetPoint("TOP", UIParent, "TOP", 0, -170)
    banner:SetFrameStrata("HIGH")
    banner:EnableMouse(false)

    banner.icon = banner:CreateTexture(nil, "OVERLAY")
    banner.icon:SetTexture(ICON)
    banner.icon:SetSize(36, 36)
    banner.icon:SetPoint("TOP")

    banner.title = banner:CreateFontString(nil, "OVERLAY")
    banner.title:SetFont(FONT, 26, "THICKOUTLINE")
    banner.title:SetPoint("TOP", banner.icon, "BOTTOM", 0, -2)
    banner.title:SetText("DO NOT HELP")

    banner.sub = banner:CreateFontString(nil, "OVERLAY")
    banner.sub:SetFont(FONT, 13, "OUTLINE")
    banner.sub:SetPoint("TOP", banner.title, "BOTTOM", 0, -3)
    banner.sub:SetWidth(600)

    local ag = banner:CreateAnimationGroup()
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(2.5)
    fade:SetDuration(0.8)
    ag:SetScript("OnFinished", function() banner:Hide() end)
    banner.fade = ag
    banner:Hide()
    return banner
end

function ns.ShowBanner(entry)
    local b = getBanner()
    local r, g, b2 = ns.Color(entry.cat)
    b.title:SetTextColor(r, g, b2)
    b.title:SetText(ns.StampText(entry.cat))
    b.icon:SetTexture(ns.IsGood(entry.cat) and ICON_GOOD or ICON)
    local sub = ns.DisplayName(entry) .. " (" .. ns.CatLabel(entry.cat) .. ")"
    if entry.note and entry.note ~= "" then sub = sub .. ": " .. entry.note end
    b.sub:SetText(sub)
    b.sub:SetTextColor(1, 1, 1)
    b.fade:Stop()
    b:SetAlpha(1)
    b:Show()
    b.fade:Play()
end
