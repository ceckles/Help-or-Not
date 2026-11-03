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

---------------------------------------------------------------------------
-- KOS sightings: a KOS player's nameplate showing up (or targeting them)
-- records when and where, and plates raise an alert once a minute.
---------------------------------------------------------------------------
local lastSighting = {}

local function recordSeen(entry)
    entry.seen = time()
    local ok, zone = pcall(GetRealZoneText)
    if ok and type(zone) == "string" and zone ~= "" and not ns.IsSecret(zone) then entry.seenZone = zone end
end

ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit)
    if type(unit) ~= "string" or ns.IsSecret(unit) then return end
    local entry, key = ns.GetUnit(unit)
    if not entry or entry == ns.TEST_ENTRY or not ns.IsKOS(entry.cat) then return end
    recordSeen(entry)
    if not ns.db.settings.kosAlert then return end
    local now = GetTime()
    if lastSighting[key] and now - lastSighting[key] < 60 then return end
    lastSighting[key] = now
    ns.Alert(entry, "spotted nearby.")
end)

ns.On("PLAYER_TARGET_CHANGED", function()
    local entry, key = ns.GetUnit("target")
    if entry and entry ~= ns.TEST_ENTRY and ns.IsKOS(entry.cat) then recordSeen(entry) end
    if not ns.db.settings.targetAlert then return end
    if not entry or ns.IsGood(entry.cat) then return end
    local now = GetTime()
    if lastTarget[key] and now - lastTarget[key] < 10 then return end
    lastTarget[key] = now
    ns.ShowBanner(entry)
    sound()
end)

---------------------------------------------------------------------------
-- KOS kills: a killing blow on a KOS player by you or your group counts.
-- Needs the combat log. Where a client hides it from addons, nothing counts.
---------------------------------------------------------------------------
local CLEU = CombatLogGetCurrentEventInfo
local PLAYER_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400

if CLEU then
    ns.On("COMBAT_LOG_EVENT_UNFILTERED", function()
        if not ns.db.settings.kosKills then return end
        local _, sub, _, _, _, _, _, _, destName, destFlags = CLEU()
        if ns.IsSecret(sub) or sub ~= "PARTY_KILL" or type(destName) ~= "string" or ns.IsSecret(destName) then return end
        if type(destFlags) ~= "number" or ns.IsSecret(destFlags) or bit.band(destFlags, PLAYER_FLAG) == 0 then return end
        local entry = ns.GetName(destName)
        if not entry or not ns.IsKOS(entry.cat) then return end
        entry.kills = (entry.kills or 0) + 1
        entry.lastKill = time()
        recordSeen(entry)
        ns.Print(("|c%sKILLED|r %s (%d %s)"):format(ns.ColorHex(entry.cat), ns.DisplayName(entry), entry.kills, entry.kills == 1 and "kill" or "kills"))
    end)
end
