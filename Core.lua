local ADDON, ns = ...
_G.HelpOrNot = ns

---------------------------------------------------------------------------
-- Secret value guard (Midnight 12.x). No-op on clients without secrets.
---------------------------------------------------------------------------
local issecretvalue = _G.issecretvalue
function ns.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

---------------------------------------------------------------------------
-- Categories and per-player block flags
---------------------------------------------------------------------------
ns.CATEGORIES = {
    griefer  = { label = "Griefer",  color = { 1.00, 0.15, 0.15 }, order = 1 },
    rude     = { label = "Rude",     color = { 1.00, 0.50, 0.10 }, order = 2 },
    annoying = { label = "Annoying", color = { 1.00, 0.85, 0.10 }, order = 3 },
    helpful  = { label = "Helpful",  color = { 0.25, 1.00, 0.35 }, order = 4, good = true },
}
ns.CATEGORY_ORDER = { "griefer", "rude", "annoying", "helpful" }

ns.FLAG_ORDER  = { "mute", "whisper", "trade", "invite", "duel", "ignore" }
ns.FLAG_LABELS = { mute = "Mute", whisper = "Whisp", trade = "Trade", invite = "Inv", duel = "Duel", ignore = "Ignore" }
ns.FLAG_TIPS = {
    mute    = "Hide their say, yell, emote, channel, party, raid and guild chat.\nMidnight hides chat authors inside instances, so use Ignore for a hard block there.",
    whisper = "Hide whispers from them.",
    trade   = "Auto-cancel any trade window they open.",
    invite  = "Auto-decline their group and guild invites.",
    duel    = "Auto-decline their duel requests.",
    ignore  = "Also add them to Blizzard's ignore list. Server-side, works everywhere including instances.",
}

ns.DEFAULT_FLAGS = {
    griefer  = { mute = true, whisper = true,  trade = true, invite = true, duel = true, ignore = false },
    rude     = { mute = true, whisper = true,  trade = true, invite = true, duel = true, ignore = false },
    annoying = { mute = true, whisper = false, trade = true, invite = true, duel = true, ignore = false },
    helpful  = { mute = false, whisper = false, trade = false, invite = false, duel = false, ignore = false },
}

local SETTINGS_DEFAULTS = {
    plates = true, markedOnly = true, frames = true, tooltip = true, lfg = true,
    groupAlert = true, targetAlert = true, sound = true, notices = true,
}

ns.TEST_ENTRY = { name = "You", realm = "", cat = "griefer", note = "Test mode", flags = {} }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff40ff59Help|r or |cffff3333Not|r: " .. tostring(msg))
end

function ns.Color(cat)
    local c = ns.CATEGORIES[cat] or ns.CATEGORIES.annoying
    return c.color[1], c.color[2], c.color[3]
end

function ns.ColorHex(cat)
    local r, g, b = ns.Color(cat)
    return string.format("ff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function ns.IsGood(cat)
    local c = ns.CATEGORIES[cat]
    return c and c.good or false
end

function ns.StampText(cat)
    return ns.IsGood(cat) and "HELPFUL" or "DO NOT HELP"
end

function ns.CatLabel(cat, colored)
    local c = ns.CATEGORIES[cat]
    local label = c and c.label or tostring(cat)
    if colored then return "|c" .. ns.ColorHex(cat) .. label .. "|r" end
    return label
end

---------------------------------------------------------------------------
-- Name keys: "name-realm" lowercased, realm normalized
---------------------------------------------------------------------------
local myRealm
function ns.MyRealm()
    if not myRealm or myRealm == "" then
        myRealm = (GetNormalizedRealmName and GetNormalizedRealmName())
            or ((GetRealmName() or ""):gsub("[%s%-]", ""))
    end
    return myRealm
end

function ns.Key(name, realm)
    if type(name) ~= "string" or ns.IsSecret(name) or name == "" then return nil end
    if realm ~= nil and (ns.IsSecret(realm) or type(realm) ~= "string") then realm = nil end
    local n, r = strsplit("-", name, 2)
    if not r or r == "" then r = realm end
    if not r or r == "" then r = ns.MyRealm() end
    if not n or n == "" or not r or r == "" then return nil end
    r = r:gsub("[%s%-]", "")
    return (n:lower() .. "-" .. r:lower()), n, r
end

local playerKey
function ns.PlayerKey()
    if not playerKey then playerKey = ns.Key(UnitName("player")) end
    return playerKey
end

local function safe(fn, ...)
    local ok, v = pcall(fn, ...)
    if not ok or ns.IsSecret(v) then return nil end
    return v
end

function ns.UnitKey(unit)
    if type(unit) ~= "string" or ns.IsSecret(unit) then return nil end
    if not safe(UnitExists, unit) or not safe(UnitIsPlayer, unit) then return nil end
    local ok, name, realm = pcall(UnitName, unit)
    if not ok then return nil end
    return ns.Key(name, realm)
end

function ns.UnitClassToken(unit)
    local ok, _, token = pcall(UnitClass, unit)
    if ok and type(token) == "string" and not ns.IsSecret(token) then return token end
end

function ns.Get(key)
    return key and ns.db.players[key] or nil
end

function ns.GetUnit(unit)
    local key = ns.UnitKey(unit)
    if not key then return nil end
    if ns.testMode and key == ns.PlayerKey() then return ns.TEST_ENTRY, key end
    return ns.db.players[key], key
end

function ns.GetName(fullName)
    local key = ns.Key(fullName)
    return ns.Get(key), key
end

function ns.DisplayName(e)
    if not e.realm or e.realm == "" or e.realm:lower() == (ns.MyRealm() or ""):lower() then
        return e.name
    end
    return e.name .. "-" .. e.realm
end

---------------------------------------------------------------------------
-- Blizzard ignore list (server-side hard block)
---------------------------------------------------------------------------
local FL = C_FriendList
local function IsIgnoredName(n) if FL and FL.IsIgnored then return FL.IsIgnored(n) elseif IsIgnored then return IsIgnored(n) end end
local function AddIgnoreName(n) if FL and FL.AddIgnore then return FL.AddIgnore(n) elseif AddIgnore then return AddIgnore(n) end end
local function DelIgnoreName(n) if FL and FL.DelIgnore then return FL.DelIgnore(n) elseif DelIgnore then return DelIgnore(n) end end

function ns.SyncIgnore(e)
    if not e or e == ns.TEST_ENTRY then return end
    local n = ns.DisplayName(e)
    if e.flags.ignore then
        if not IsIgnoredName(n) then
            AddIgnoreName(n)
            e.ignoredByUs = true
        end
    elseif e.ignoredByUs then
        if IsIgnoredName(n) then DelIgnoreName(n) end
        e.ignoredByUs = nil
    end
end

---------------------------------------------------------------------------
-- Change notification
---------------------------------------------------------------------------
local listeners, labels = {}, {}
function ns.OnChange(fn, label)
    listeners[#listeners + 1] = fn
    labels[#listeners] = label or ("listener " .. #listeners)
end

-- /hon perf: prints how long each piece of a change takes.
function ns.PerfLog(label, ms, extra)
    if ns.perf then ns.Print(("perf %s: %.1f ms%s"):format(label, ms, extra or "")) end
end

function ns.Fire()
    for i = 1, #listeners do
        local t = ns.perf and debugprofilestop()
        local ok, err = pcall(listeners[i])
        if t then ns.PerfLog(labels[i], debugprofilestop() - t) end
        if not ok then geterrorhandler()(err) end
    end
end

---------------------------------------------------------------------------
-- List operations
---------------------------------------------------------------------------
function ns.Add(name, realm, cat, note, class)
    local key, n, r = ns.Key(name, realm)
    if not key then ns.Print("Couldn't resolve that player's name.") return end
    if key == ns.PlayerKey() then ns.Print("You can't flag yourself.") return end
    if not ns.CATEGORIES[cat] then cat = "annoying" end

    local e = ns.db.players[key]
    if e then
        e.cat = cat
        if note and note ~= "" then e.note = note end
    else
        local flags = {}
        for k, v in pairs(ns.DEFAULT_FLAGS[cat]) do flags[k] = v end
        e = { name = n, realm = r, cat = cat, note = note or "", added = time(), flags = flags }
        ns.db.players[key] = e
    end
    if class then e.class = class end

    local t = ns.perf and debugprofilestop()
    ns.SyncIgnore(e)
    if t then ns.PerfLog("SyncIgnore", debugprofilestop() - t) end
    ns.Print(("Marked %s as %s."):format(ns.DisplayName(e), ns.CatLabel(cat, true)))
    ns.Fire()
    return key, e
end

function ns.Remove(key)
    local e = ns.db.players[key]
    if not e then return end
    if e.flags.ignore or e.ignoredByUs then
        e.flags.ignore = false
        ns.SyncIgnore(e)
    end
    ns.db.players[key] = nil
    ns.Print(("Removed %s."):format(ns.DisplayName(e)))
    ns.Fire()
end

function ns.SetCategory(key, cat)
    local e = ns.db.players[key]
    if not e or not ns.CATEGORIES[cat] then return end
    e.cat = cat
    ns.Fire()
end

function ns.SetFlag(key, flag, value)
    local e = ns.db.players[key]
    if not e then return end
    e.flags[flag] = value and true or false
    if flag == "ignore" then ns.SyncIgnore(e) end
    ns.Fire()
end

---------------------------------------------------------------------------
-- Export / import (SavedVariables are per client, so this moves lists
-- between Retail, Classic and Forever)
---------------------------------------------------------------------------
local function esc(s)
    local r = tostring(s or ""):gsub("[%^;|]", "")
    return r
end

function ns.Export()
    local out = { "HON1" }
    for _, e in pairs(ns.db.players) do
        local bits = ""
        for _, f in ipairs(ns.FLAG_ORDER) do bits = bits .. (e.flags[f] and "1" or "0") end
        out[#out + 1] = table.concat({ esc(e.name), esc(e.realm), e.cat, bits, tostring(e.added or 0), esc(e.class), esc(e.note) }, "^")
    end
    return table.concat(out, ";")
end

function ns.Import(str)
    if type(str) ~= "string" then return 0 end
    str = str:match("^%s*(.-)%s*$")
    local head = str:sub(1, 4)
    if (head ~= "HON1" and head ~= "DNH1") or (#str > 4 and str:sub(5, 5) ~= ";") then
        ns.Print("That isn't a Help or Not export string.")
        return 0
    end
    local added = 0
    for rec in str:sub(6):gmatch("[^;]+") do
        local name, realm, cat, bits, ts, class, note = strsplit("^", rec)
        local key = ns.Key(name, realm)
        if key and ns.CATEGORIES[cat] and not ns.db.players[key] then
            local flags = {}
            for i, f in ipairs(ns.FLAG_ORDER) do flags[f] = (bits or ""):sub(i, i) == "1" end
            local e = { name = name, realm = realm, cat = cat, note = note or "", added = tonumber(ts) or time(), flags = flags }
            if class and class ~= "" then e.class = class end
            ns.db.players[key] = e
            ns.SyncIgnore(e)
            added = added + 1
        end
    end
    ns.Print(("Imported %d player(s)."):format(added))
    ns.Fire()
    return added
end

---------------------------------------------------------------------------
-- Throttled notices ("Blocked trade from X")
---------------------------------------------------------------------------
local lastNotice = {}
function ns.Notice(key, kind, msg)
    if not ns.db.settings.notices then return end
    local id = key .. ":" .. kind
    local now = GetTime()
    if lastNotice[id] and now - lastNotice[id] < 30 then return end
    lastNotice[id] = now
    ns.Print(msg)
end

---------------------------------------------------------------------------
-- Events. RegisterEvent errors on events a flavor lacks, so it's pcall'd.
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local handlers = {}
function ns.On(event, fn)
    if not handlers[event] then
        if not pcall(ev.RegisterEvent, ev, event) then return false end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
    return true
end
ev:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then geterrorhandler()(err) end
    end
end)

local loginFns = {}
function ns.OnLogin(fn) loginFns[#loginFns + 1] = fn end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    HelpOrNotDB = HelpOrNotDB or {}
    local db = HelpOrNotDB
    db.version = db.version or 1
    db.players = db.players or {}
    db.settings = db.settings or {}
    for k, v in pairs(SETTINGS_DEFAULTS) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    for _, e in pairs(db.players) do
        e.flags = e.flags or {}
        e.note = e.note or ""
    end
    ns.db = db
end)

ns.On("PLAYER_LOGIN", function()
    for i = 1, #loginFns do
        local ok, err = pcall(loginFns[i])
        if not ok then geterrorhandler()(err) end
    end
end)
