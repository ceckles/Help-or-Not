local _, ns = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"
local ROW_H, ROW_W = 26, 640
local COL = { name = 8, cat = 160, flags = 246, flagStep = 44, note = 514, del = 612 }
local frame, scrollChild, emptyText
local rows = {}

local function getEditBox(popup)
    return (popup.GetEditBox and popup:GetEditBox()) or popup.editBox or popup.EditBox
end

---------------------------------------------------------------------------
-- Export / import popups
---------------------------------------------------------------------------
StaticPopupDialogs["HELPORNOT_EXPORT"] = {
    text = "Copy this string (Ctrl+A, Ctrl+C) and import it on your other clients:",
    button1 = CLOSE or OKAY,
    hasEditBox = 1, editBoxWidth = 360, maxLetters = 0,
    OnShow = function(self)
        local eb = getEditBox(self)
        if eb then eb:SetMaxLetters(0); eb:SetText(ns.Export()); eb:HighlightText(); eb:SetFocus() end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

StaticPopupDialogs["HELPORNOT_IMPORT"] = {
    text = "Paste a Help or Not export string. Existing entries are kept.",
    button1 = "Import", button2 = CANCEL,
    hasEditBox = 1, editBoxWidth = 360, maxLetters = 0,
    OnShow = function(self)
        local eb = getEditBox(self)
        if eb then eb:SetMaxLetters(0); eb:SetText(""); eb:SetFocus() end
    end,
    OnAccept = function(self)
        local eb = getEditBox(self)
        if eb then ns.Import(eb:GetText()) end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------
local function tip(owner, title, body)
    owner:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(title) == "function" and title(self) or title, 1, 1, 1)
        local b = type(body) == "function" and body(self) or body
        if b and b ~= "" then GameTooltip:AddLine(b, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function createRow(i)
    local r = CreateFrame("Frame", nil, scrollChild)
    r:SetSize(ROW_W, ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetTexture(FLAT)

    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.name:SetPoint("LEFT", COL.name, 0)
    r.name:SetWidth(COL.cat - COL.name - 6)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)

    r.cat = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
    r.cat:SetSize(78, 20)
    r.cat:SetPoint("LEFT", COL.cat, 0)
    r.cat:SetScript("OnClick", function()
        local e = ns.db.players[r.key]
        if not e then return end
        local idx = 1
        for j, c in ipairs(ns.CATEGORY_ORDER) do if c == e.cat then idx = j end end
        ns.SetCategory(r.key, ns.CATEGORY_ORDER[idx % #ns.CATEGORY_ORDER + 1])
    end)
    tip(r.cat, "Category", "Click to cycle Griefer, Rude, Annoying, Helpful.")

    r.checks = {}
    for j, flag in ipairs(ns.FLAG_ORDER) do
        local cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("LEFT", COL.flags + (j - 1) * COL.flagStep + 6, 0)
        cb:SetScript("OnClick", function(self) ns.SetFlag(r.key, flag, self:GetChecked()) end)
        tip(cb, ns.FLAG_LABELS[flag], ns.FLAG_TIPS[flag])
        r.checks[flag] = cb
    end

    r.noteHit = CreateFrame("Frame", nil, r)
    r.noteHit:SetPoint("LEFT", COL.note, 0)
    r.noteHit:SetSize(COL.del - COL.note - 4, ROW_H)
    r.noteHit:EnableMouse(true)
    r.note = r.noteHit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.note:SetAllPoints()
    r.note:SetJustifyH("LEFT")
    r.note:SetWordWrap(false)
    tip(r.noteHit, function() return "Note" end, function()
        local e = ns.db.players[r.key]
        if not e then return "" end
        local added = e.added and date("%Y-%m-%d", e.added) or "?"
        return ((e.note ~= "" and e.note) or "(none)") .. "\n|cff888888Added " .. added .. "|r"
    end)

    r.del = CreateFrame("Button", nil, r, "UIPanelCloseButton")
    r.del:SetSize(24, 24)
    r.del:SetPoint("LEFT", COL.del, 0)
    r.del:SetScript("OnClick", function() ns.Remove(r.key) end)
    tip(r.del, "Remove", "Unflag this player.")

    rows[i] = r
    return r
end

local function sortedKeys()
    local keys, p = {}, ns.db.players
    for k in pairs(p) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ca, cb = ns.CATEGORIES[p[a].cat], ns.CATEGORIES[p[b].cat]
        local oa, ob = ca and ca.order or 9, cb and cb.order or 9
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return keys
end

function ns.RefreshUI()
    if not frame or not frame:IsShown() then return end
    local keys = sortedKeys()
    for i, key in ipairs(keys) do
        local r = rows[i] or createRow(i)
        local e = ns.db.players[key]
        r.key = key
        local cr, cg, cb = ns.Color(e.cat)
        r.bg:SetVertexColor(cr, cg, cb, (i % 2 == 0) and 0.10 or 0.05)
        local cc = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
        r.name:SetText(ns.DisplayName(e))
        if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) else r.name:SetTextColor(1, 1, 1) end
        r.cat:SetText(ns.CatLabel(e.cat, true))
        for flag, cbx in pairs(r.checks) do cbx:SetChecked(e.flags[flag] and true or false) end
        r.note:SetText(e.note or "")
        r:Show()
    end
    for i = #keys + 1, #rows do rows[i]:Hide() end
    scrollChild:SetHeight(math.max(1, #keys * ROW_H))
    emptyText:SetShown(#keys == 0)
    frame.count:SetText(("%d flagged"):format(#keys))
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function settingCheck(parent, key, label, tipText)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    fs:SetText(label)
    cb.label = fs
    cb:SetScript("OnShow", function(self) self:SetChecked(ns.db.settings[key]) end)
    cb:SetScript("OnClick", function(self)
        ns.db.settings[key] = self:GetChecked() and true or false
        ns.Fire()
    end)
    tip(cb, label, tipText)
    return cb
end

local function build()
    frame = CreateFrame("Frame", "HelpOrNotFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(ROW_W + 50, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "HelpOrNotFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -5)
    title:SetText("|cff40ff59Help|r or |cffff3333Not|r")

    local by = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    by:SetPoint("LEFT", title, "RIGHT", 6, 0)
    by:SetText("by Monger")

    frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.count:SetPoint("TOPLEFT", 14, -32)

    local headers = { { "Player", COL.name }, { "Category", COL.cat + 8 }, { "Note", COL.note } }
    for j, flag in ipairs(ns.FLAG_ORDER) do headers[#headers + 1] = { ns.FLAG_LABELS[flag], COL.flags + (j - 1) * COL.flagStep } end
    for _, h in ipairs(headers) do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 14 + h[2], -58)
        fs:SetText(h[1])
    end

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -74)
    scroll:SetPoint("BOTTOMRIGHT", -32, 114)
    scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(ROW_W, 1)
    scroll:SetScrollChild(scrollChild)

    emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", scroll, "TOP", 0, -40)
    emptyText:SetText("Nobody flagged yet. Right-click a player, or target one and use the buttons below.")

    -- Row 1: flag target
    local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("BOTTOMLEFT", 16, 90)
    lbl:SetText("Mark target as:")
    local prev = lbl
    for _, c in ipairs(ns.CATEGORY_ORDER) do
        local b = button(frame, ns.CatLabel(c, true), 80, function() ns.PromptAddUnit("target", c) end)
        b:SetPoint("LEFT", prev, "RIGHT", 8, 0)
        prev = b
    end
    local test = button(frame, "Test Mode", 90, function()
        ns.testMode = not ns.testMode
        ns.Print("Test mode " .. (ns.testMode and "on: you now show as a Griefer on your own frames." or "off."))
        ns.Fire()
    end)
    test:SetPoint("TOPRIGHT", -194, -28)
    local imp = button(frame, "Import", 80, function() StaticPopup_Show("HELPORNOT_IMPORT") end)
    imp:SetPoint("TOPRIGHT", -104, -28)
    local exp = button(frame, "Export", 80, function() StaticPopup_Show("HELPORNOT_EXPORT") end)
    exp:SetPoint("TOPRIGHT", -14, -28)

    -- Rows 2-3: settings
    local settings = {
        { "plates", "Nameplates", "Stamp DO NOT HELP or HELPFUL above marked players' nameplates." },
        { "markedOnly", "Marked only", "Turns friendly player nameplates on for you, then hides every one except the players you've marked. No more Shift+V. Inside dungeons and raids your own nameplate setting is put back, since addons can't touch friendly plates there." },
        { "frames", "Unit frames", "Tint and border flagged players on party, raid, target and focus frames (EllesmereUI or Blizzard)." },
        { "tooltip", "Tooltip", "Add a DO NOT HELP or HELPFUL line to their tooltip." },
        { "lfg", "Group Finder", "Tag flagged leaders and applicants. Takes effect after /reload if turned on." },
        { "groupAlert", "Group alert", "Raid warning when a flagged player is in your group." },
        { "targetAlert", "Target banner", "Big banner when you target a flagged player." },
        { "sound", "Sound", "Play the raid warning sound with alerts." },
        { "notices", "Block notices", "Print a chat line when a trade, invite, duel or whisper is blocked." },
    }
    for i, s in ipairs(settings) do
        local cb = settingCheck(frame, s[1], s[2], s[3])
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        cb:SetPoint("BOTTOMLEFT", 14 + col * 165, 60 - row * 23)
    end

    frame:SetScript("OnShow", ns.RefreshUI)
    frame:Hide()
end

function ns.ToggleUI()
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
end

ns.OnChange(ns.RefreshUI, "manager window")

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local HELP = {
    "/hon  open the list",
    "/hon add griefer/rude/annoying/helpful [Name-Realm] [note]  (no name = your target)",
    "/hon remove [Name-Realm]  (no name = your target)",
    "/hon list   /hon test   /hon export   /hon import",
}

SLASH_HELPORNOT1 = "/hon"
SLASH_HELPORNOT2 = "/helpornot"
SlashCmdList.HELPORNOT = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()

    if cmd == "" then
        ns.ToggleUI()
    elseif cmd == "add" then
        local cat, target, note = rest:match("^(%S+)%s*(%S*)%s*(.*)$")
        cat = cat and cat:lower()
        if not cat or not ns.CATEGORIES[cat] then ns.Print("Usage: " .. HELP[2]) return end
        if target == "" then
            if not ns.UnitKey("target") then ns.Print("Target a player or give a name.") return end
            local n, r = UnitName("target")
            ns.Add(n, r, cat, note, ns.UnitClassToken("target"))
        else
            ns.Add(target, nil, cat, note)
        end
    elseif cmd == "remove" or cmd == "rm" then
        local key = (rest ~= "" and ns.Key(rest)) or ns.UnitKey("target")
        if key and ns.db.players[key] then ns.Remove(key) else ns.Print("Not on your list.") end
    elseif cmd == "list" then
        local n = 0
        for _, e in pairs(ns.db.players) do
            n = n + 1
            ns.Print(("%s  %s  %s"):format(ns.DisplayName(e), ns.CatLabel(e.cat, true), e.note or ""))
        end
        if n == 0 then ns.Print("List is empty.") end
    elseif cmd == "test" then
        ns.testMode = not ns.testMode
        ns.Print("Test mode " .. (ns.testMode and "on." or "off."))
        ns.Fire()
    elseif cmd == "perf" then
        ns.perf = not ns.perf
        ns.Print("Perf timing " .. (ns.perf and "on. Mark someone and read the chat." or "off."))
    elseif cmd == "export" then
        StaticPopup_Show("HELPORNOT_EXPORT")
    elseif cmd == "import" then
        StaticPopup_Show("HELPORNOT_IMPORT")
    else
        for _, line in ipairs(HELP) do ns.Print(line) end
    end
end

ns.OnLogin(function()
    if not ns.hasMenu then
        ns.Print("Right-click menus aren't available on this client. Use /hon add.")
    end
end)

---------------------------------------------------------------------------
-- Addon compartment (minimap addon menu on Retail and Forever)
---------------------------------------------------------------------------
function HelpOrNot_OnAddonCompartmentClick() ns.ToggleUI() end
function HelpOrNot_OnAddonCompartmentEnter(_, button)
    GameTooltip:SetOwner(button or UIParent, "ANCHOR_LEFT")
    GameTooltip:SetText("|cff40ff59Help|r or |cffff3333Not|r")
    GameTooltip:AddLine("Click to open your list.", 1, 1, 1)
    GameTooltip:AddLine("by Monger", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end
function HelpOrNot_OnAddonCompartmentLeave() GameTooltip:Hide() end
