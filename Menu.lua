local _, ns = ...

local function getEditBox(popup)
    return (popup.GetEditBox and popup:GetEditBox()) or popup.editBox or popup.EditBox
end

StaticPopupDialogs["HELPORNOT_ADD"] = {
    text = "Mark %s as %s.\nOptional note:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 120,
    OnShow = function(self)
        local eb = getEditBox(self)
        if eb then eb:SetText(""); eb:SetFocus() end
    end,
    OnAccept = function(self, data)
        local eb = getEditBox(self)
        ns.Add(data.name, data.realm, data.cat, eb and eb:GetText() or "", data.class)
    end,
    EditBoxOnEnterPressed = function(self, data)
        local p = self:GetParent()
        data = data or p.data
        if data then ns.Add(data.name, data.realm, data.cat, self:GetText(), data.class) end
        p:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

function ns.PromptAdd(name, realm, cat, class)
    local shown = realm and realm ~= "" and (name .. "-" .. realm) or name
    StaticPopup_Show("HELPORNOT_ADD", shown, ns.CatLabel(cat, true), { name = name, realm = realm, cat = cat, class = class })
end

function ns.PromptAddUnit(unit, cat)
    local key = ns.UnitKey(unit)
    if not key then ns.Print("Target a player first.") return end
    local name, realm = UnitName(unit)
    ns.PromptAdd(name, realm, cat, ns.UnitClassToken(unit))
end

---------------------------------------------------------------------------
-- Right-click menus (Menu API: Retail, Forever, and Classic builds on the
-- modern menu system). Covers unit frames, chat names, friends, guild.
---------------------------------------------------------------------------
local TAGS = {
    "MENU_UNIT_PLAYER", "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_TARGET",
    "MENU_UNIT_FOCUS", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID",
    "MENU_UNIT_FRIEND", "MENU_UNIT_FRIEND_OFFLINE", "MENU_UNIT_CHAT_ROSTER",
    "MENU_UNIT_GUILD", "MENU_UNIT_GUILD_OFFLINE", "MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
    "MENU_UNIT_COMMUNITIES_MEMBER", "MENU_UNIT_ARENAENEMY",
}

local function build(_, root, ctx)
    if not ctx then return end
    local name, realm, class = ctx.name, ctx.server, nil
    if ctx.unit and not ns.IsSecret(ctx.unit) then
        if not ns.UnitKey(ctx.unit) then return end
        name, realm = UnitName(ctx.unit)
        class = ns.UnitClassToken(ctx.unit)
    end
    local key = ns.Key(name, realm)
    if not key or key == ns.PlayerKey() then return end

    root:CreateDivider()
    root:CreateTitle("|cff40ff59Help|r or |cffff3333Not|r")
    local entry = ns.Get(key)
    if entry then
        local sub = root:CreateButton("Change category (" .. ns.CatLabel(entry.cat, true) .. ")")
        for _, c in ipairs(ns.CATEGORY_ORDER) do
            sub:CreateButton(ns.CatLabel(c, true), function() ns.SetCategory(key, c) end)
        end
        root:CreateButton("Remove flag", function() ns.Remove(key) end)
    else
        local sub = root:CreateButton("Mark player")
        for _, c in ipairs(ns.CATEGORY_ORDER) do
            sub:CreateButton(ns.CatLabel(c, true), function() ns.PromptAdd(name, realm, c, class) end)
        end
    end
end

ns.OnLogin(function()
    if Menu and Menu.ModifyMenu then
        for _, tag in ipairs(TAGS) do Menu.ModifyMenu(tag, build) end
        ns.hasMenu = true
    end
end)
