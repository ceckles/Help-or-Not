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
    local cycle = {}
    for j, c in ipairs(ns.CATEGORY_ORDER) do cycle[j] = ns.CatLabel(c) end
    tip(r.cat, "Category", "Click to cycle " .. table.concat(cycle, ", ") .. ".")

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
        local text = ((e.note ~= "" and e.note) or "(none)") .. "\n|cff888888Added " .. added .. "|r"
        if e.seen then
            text = text .. "\n|cff888888Last seen " .. date("%Y-%m-%d %H:%M", e.seen) .. (e.seenZone and (" in " .. e.seenZone) or "") .. "|r"
        end
        return text
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

local optionChecks = {}

local function settingCheck(parent, key, label, tipText)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    fs:SetText(label)
    cb.label = fs
    cb.key = key
    cb:SetScript("OnShow", function(self) self:SetChecked(ns.db.settings[key]) end)
    cb:SetScript("OnClick", function(self)
        ns.db.settings[key] = self:GetChecked() and true or false
        ns.Fire()
    end)
    tip(cb, label, tipText)
    optionChecks[#optionChecks + 1] = cb
    return cb
end

local OPTIONS = {
    { "Display", {
        { "plates", "Nameplates", "Stamp marked players above their nameplates." },
        { "markedOnly", "Marked only", "Turns friendly player nameplates on for you, then hides every one except the players you've marked. No more Shift+V. Inside dungeons and raids your own nameplate setting is put back, since addons can't touch friendly plates there." },
        { "frames", "Unit frames", "Tint and border marked players on party, raid, target and focus frames (EllesmereUI or Blizzard)." },
        { "tooltip", "Tooltip", "Add a DO NOT HELP, KILL ON SIGHT or Helpful line to their tooltip." },
        { "lfg", "Group Finder", "Tag marked leaders and applicants. Takes effect after /reload if turned on." },
        { "showHelpful", "Helpful stamps", "Stamp Helpful players on nameplates and unit frames. Off means only bad and KOS players get stamped." },
        { "pulse", "Pulse", "Griefer and KOS stamps pulse so they stand out." },
    } },
    { "Alerts", {
        { "groupAlert", "Group alert", "Raid warning when a marked player is in your group." },
        { "targetAlert", "Target banner", "Big banner when you target a marked player." },
        { "kosAlert", "KOS sightings", "Raid warning when a KOS player's nameplate shows up near you, once a minute per player. When and where you last saw them is recorded either way." },
        { "sound", "Sound", "Play the raid warning sound with alerts." },
        { "notices", "Block notices", "Print a chat line when a trade, invite, duel or whisper is blocked." },
    } },
    { "Blocking", {
        { "blockChat", "Chat mute", "Hide chat from players with Mute checked." },
        { "blockWhispers", "Whispers", "Hide whispers from players with Whisp checked." },
        { "blockTrades", "Trades", "Cancel trades from players with Trade checked." },
        { "blockInvites", "Invites", "Decline group and guild invites from players with Inv checked." },
        { "blockDuels", "Duels", "Decline duels from players with Duel checked." },
    } },
    { "Other", {
        { "menu", "Right-click menu", "Add Help or Not to player right-click menus." },
    } },
}

local function setView(view)
    frame.listView:SetShown(view == "list")
    frame.optionsView:SetShown(view == "options")
    frame.viewBtn:SetText(view == "list" and "Options" or "List")
    if view == "options" then
        for _, cb in ipairs(optionChecks) do cb:SetChecked(ns.db.settings[cb.key]) end
    else
        ns.RefreshUI()
    end
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

    local list = CreateFrame("Frame", nil, frame)
    list:SetAllPoints()
    frame.listView = list

    local headers = { { "Player", COL.name }, { "Category", COL.cat + 8 }, { "Note", COL.note } }
    for j, flag in ipairs(ns.FLAG_ORDER) do headers[#headers + 1] = { ns.FLAG_LABELS[flag], COL.flags + (j - 1) * COL.flagStep } end
    for _, h in ipairs(headers) do
        local fs = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 14 + h[2], -58)
        fs:SetText(h[1])
    end

    local scroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -74)
    scroll:SetPoint("BOTTOMRIGHT", -32, 56)
    scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(ROW_W, 1)
    scroll:SetScrollChild(scrollChild)

    emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", scroll, "TOP", 0, -40)
    emptyText:SetText("Nobody flagged yet. Right-click a player, or target one and use the buttons below.")

    local lbl = list:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("BOTTOMLEFT", 16, 26)
    lbl:SetText("Mark target as:")
    local prev = lbl
    for _, c in ipairs(ns.CATEGORY_ORDER) do
        local b = button(list, ns.CatLabel(c, true), 80, function() ns.PromptAddUnit("target", c) end)
        b:SetPoint("LEFT", prev, "RIGHT", 8, 0)
        prev = b
    end

    -- Options view: one column per section.
    local opts = CreateFrame("Frame", nil, frame)
    opts:SetAllPoints()
    opts:Hide()
    frame.optionsView = opts
    for i, section in ipairs(OPTIONS) do
        local x = 18 + (i - 1) * 168
        local head = opts:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        head:SetPoint("TOPLEFT", x, -62)
        head:SetText(section[1])
        for j, s in ipairs(section[2]) do
            local cb = settingCheck(opts, s[1], s[2], s[3])
            cb:SetPoint("TOPLEFT", x - 4, -80 - (j - 1) * 24)
        end
    end
    local foot = opts:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 18, 24)
    foot:SetPoint("BOTTOMRIGHT", -18, 24)
    foot:SetJustifyH("LEFT")
    foot:SetText("Blocking switches turn a kind of block off for everyone. The checkboxes on each player still decide who gets blocked while it's on.")

    frame.viewBtn = button(frame, "Options", 80, function()
        setView(frame.optionsView:IsShown() and "list" or "options")
    end)
    frame.viewBtn:SetPoint("TOPRIGHT", -290, -28)
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

    frame:SetScript("OnShow", ns.RefreshUI)
    frame:Hide()
end

function ns.ToggleUI()
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
end

function ns.ShowOptions()
    if not frame then build() end
    frame:Show()
    setView("options")
end

---------------------------------------------------------------------------
-- Entry in Blizzard's AddOns options (Settings on Retail and Forever,
-- Interface Options on older Classic builds). It just opens our window.
---------------------------------------------------------------------------
ns.OnLogin(function()
    local panel = CreateFrame("Frame")
    panel.name = "Help or Not"
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff40ff59Help|r or |cffff3333Not|r")
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Options live in the Help or Not window. You can also type /hon options.")
    local open = button(panel, "Open options", 140, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
        ns.ShowOptions()
    end)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end)

ns.OnChange(ns.RefreshUI, "manager window")

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local HELP = {
    "/hon  open the list",
    "/hon add griefer/rude/annoying/kos/helpful [Name-Realm] [note]  (no name = your target)",
    "/hon remove [Name-Realm]  (no name = your target)",
    "/hon options   /hon list   /hon test   /hon export   /hon import",
    "/hon perf (timing)   /hon scan (list tracked unit frames)",
}

SLASH_HELPORNOT1 = "/hon"
SLASH_HELPORNOT2 = "/helpornot"
SlashCmdList.HELPORNOT = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()

    if cmd == "" then
        ns.ToggleUI()
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        ns.ShowOptions()
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
    elseif cmd == "scan" then
        ns.Print("Tracked before scan:")
        ns.ReportFrames()
        ns.scanReport = true
        ns.ScheduleScan(0)
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
