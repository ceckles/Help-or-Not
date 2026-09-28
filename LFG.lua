local _, ns = ...

-- Overlays a tag on Group Finder rows instead of rewriting Blizzard's text,
-- which keeps taint away from the protected sign-up path.

local FLAT = "Interface\\Buttons\\WHITE8X8"
local hookedSearch, hookedApps = false, false

local function tag(frame, entry)
    local t = frame.HONTag
    if not entry then
        if t then t:Hide() end
        return
    end
    if not t then
        t = CreateFrame("Frame", nil, frame)
        t.HONSkip = true
        t:SetAllPoints(frame)
        t:SetFrameLevel(frame:GetFrameLevel() + 5)
        t:EnableMouse(false)
        t.bg = t:CreateTexture(nil, "ARTWORK")
        t.bg:SetAllPoints()
        t.bg:SetTexture(FLAT)
        t.text = t:CreateFontString(nil, "OVERLAY")
        t.text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        t.text:SetPoint("TOPRIGHT", -6, -3)
        frame.HONTag = t
    end
    local r, g, b = ns.Color(entry.cat)
    t.bg:SetVertexColor(r, g, b, ns.IsGood(entry.cat) and 0.14 or 0.22)
    t.text:SetTextColor(r, g, b)
    t.text:SetText(ns.IsGood(entry.cat) and "HELPFUL" or ("DO NOT HELP: " .. ns.CatLabel(entry.cat):upper()))
    t:Show()
end

local function install()
    if not ns.db.settings.lfg or not C_LFGList then return end

    if not hookedSearch and LFGListSearchEntry_Update then
        hooksecurefunc("LFGListSearchEntry_Update", function(self)
            local entry
            if self.resultID and C_LFGList.GetSearchResultInfo then
                local info = C_LFGList.GetSearchResultInfo(self.resultID)
                local leader = info and info.leaderName
                if leader and not ns.IsSecret(leader) then entry = ns.GetName(leader) end
            end
            tag(self, entry)
        end)
        hookedSearch = true
    end

    if not hookedApps and LFGListApplicationViewer_UpdateApplicantMember then
        hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", function(member, appID, memberIdx)
            local entry
            if C_LFGList.GetApplicantMemberInfo then
                local name = C_LFGList.GetApplicantMemberInfo(appID, memberIdx)
                if type(name) == "string" and not ns.IsSecret(name) then entry = ns.GetName(name) end
            end
            tag(member, entry)
        end)
        hookedApps = true
    end
end

ns.OnLogin(install)
ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_GroupFinder" or name == "Blizzard_LookingForGroupUI" then install() end
end)
