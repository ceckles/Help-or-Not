local _, ns = ...

local function addLines(tt, unit)
    if not ns.db or not ns.db.settings.tooltip then return end
    if type(unit) ~= "string" or ns.IsSecret(unit) then return end
    local entry = ns.GetUnit(unit)
    if not entry then return end
    local r, g, b = ns.Color(entry.cat)
    tt:AddLine(ns.IsGood(entry.cat) and "Helpful player" or ("DO NOT HELP: " .. ns.CatLabel(entry.cat)), r, g, b)
    if entry.note and entry.note ~= "" then tt:AddLine(entry.note, 1, 1, 1, true) end
end

ns.OnLogin(function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
            if tt ~= GameTooltip then return end
            local ok, _, unit = pcall(tt.GetUnit, tt)
            if ok then addLines(tt, unit) end
        end)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", function(tt)
            local _, unit = tt:GetUnit()
            addLines(tt, unit)
        end)
    end
end)
