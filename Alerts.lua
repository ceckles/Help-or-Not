local _, ns = ...

local alertedGroup = {}
local lastTarget = {}

local function sound()
    if ns.db.settings.sound then
        PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    end
end

function ns.Alert(entry, reason)
    local msg = ("|c%s%s|r  %s (%s) %s"):format(ns.ColorHex(entry.cat), ns.StampText(entry.cat), ns.DisplayName(entry), ns.CatLabel(entry.cat), reason)
    if ns.IsGood(entry.cat) then
        -- Helpful players get a quiet chat line, no raid warning or sound.
        ns.Print(msg)
        return
    end
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    end
    ns.Print(msg .. ((entry.note and entry.note ~= "") and (": " .. entry.note) or ""))
    sound()
end

local function checkGroup()
    if not ns.db.settings.groupAlert then return end
    local n = GetNumGroupMembers()
    if n == 0 then wipe(alertedGroup) return end
    local raid = IsInRaid()
    local prefix = raid and "raid" or "party"
    local count = raid and n or (n - 1)
    for i = 1, count do
        local entry, key = ns.GetUnit(prefix .. i)
        if entry and entry ~= ns.TEST_ENTRY and key and not alertedGroup[key] then
            alertedGroup[key] = true
            ns.Alert(entry, "is in your group.")
        end
    end
end

ns.On("GROUP_ROSTER_UPDATE", checkGroup)
ns.OnLogin(function() C_Timer.After(5, checkGroup) end)

ns.On("PLAYER_TARGET_CHANGED", function()
    if not ns.db.settings.targetAlert then return end
    local entry, key = ns.GetUnit("target")
    if not entry or ns.IsGood(entry.cat) then return end
    local now = GetTime()
    if lastTarget[key] and now - lastTarget[key] < 10 then return end
    lastTarget[key] = now
    ns.ShowBanner(entry)
    sound()
end)
