local _, ns = ...

-- ChatFrame_AddMessageEventFilter moved to ChatFrameUtil in 11.2.7 and the
-- global was removed in 12.0. Classic clients still have the global.
local AddChatFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
    and function(e, f) ChatFrameUtil.AddMessageEventFilter(e, f) end
    or ChatFrame_AddMessageEventFilter

local MUTE_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
}

local function entryFor(author)
    if type(author) ~= "string" or ns.IsSecret(author) then return nil end
    return ns.GetName(author)
end

local function muteFilter(_, _, _, author)
    local e = entryFor(author)
    if e and e.flags.mute then return true end
    return false
end

local function whisperFilter(_, _, _, author)
    local e, key = entryFor(author)
    if e and e.flags.whisper then
        ns.Notice(key, "whisper", ("Hid a whisper from %s."):format(ns.DisplayName(e)))
        return true
    end
    return false
end

local function hidePopup(which)
    if StaticPopup_Hide then StaticPopup_Hide(which) end
end

ns.OnLogin(function()
    if AddChatFilter then
        for _, ev in ipairs(MUTE_EVENTS) do AddChatFilter(ev, muteFilter) end
        AddChatFilter("CHAT_MSG_WHISPER", whisperFilter)
    end
end)

-- Trades open straight to the window, so cancel on show. Trade partner is unit "NPC".
ns.On("TRADE_SHOW", function()
    local e, key = ns.GetUnit("NPC")
    if e and e ~= ns.TEST_ENTRY and e.flags.trade then
        CancelTrade()
        ns.Notice(key, "trade", ("Blocked trade from %s."):format(ns.DisplayName(e)))
    end
end)

ns.On("PARTY_INVITE_REQUEST", function(_, name)
    local e, key = entryFor(name)
    if e and e.flags.invite then
        DeclineGroup()
        hidePopup("PARTY_INVITE")
        ns.Notice(key, "invite", ("Declined group invite from %s."):format(ns.DisplayName(e)))
    end
end)

ns.On("GUILD_INVITE_REQUEST", function(_, inviter)
    local e, key = entryFor(inviter)
    if e and e.flags.invite then
        DeclineGuild()
        hidePopup("GUILD_INVITE")
        ns.Notice(key, "guild", ("Declined guild invite from %s."):format(ns.DisplayName(e)))
    end
end)

ns.On("DUEL_REQUESTED", function(_, name)
    local e, key = entryFor(name)
    if e and e.flags.duel then
        CancelDuel()
        hidePopup("DUEL_REQUESTED")
        ns.Notice(key, "duel", ("Declined duel from %s."):format(ns.DisplayName(e)))
    end
end)
