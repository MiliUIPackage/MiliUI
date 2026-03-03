
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local AFK = AFK
local DND = DND
local PVP = PVP
local LEVEL = LEVEL
local OFFLINE = FRIENDS_LIST_OFFLINE
local FACTION_HORDE = FACTION_HORDE
local FACTION_ALLIANCE = FACTION_ALLIANCE

local addon = TinyTooltip

local function SafeBool(fn, ...)
    local ok, value = pcall(fn, ...)
    if (not ok) then
        return false
    end
    local okEval, result = pcall(function()
        return value == true
    end)
    if (okEval) then
        return result
    end
    return false
end

local function strip(text)
    return (text:gsub("%s+([|%x%s]+)<trim>", "%1"))
end

local function SafeStripText(text)
    if not text then return end
    local ok, stripped = pcall(function()
        if (type(text) ~= "string") then return end
        local s = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        s = strtrim(s or "")
        if (s == "") then return end
        return s
    end)
    if ok then
        return stripped
    end
end

local function FindMountAura(unit)
    if (not C_MountJournal or not C_MountJournal.GetMountFromSpell) then return end
    if (AuraUtil and AuraUtil.ForEachAura) then
        local auraName, auraSpellID, mountID
        local ok = pcall(AuraUtil.ForEachAura, unit, "HELPFUL", nil, function(aura)
            if (type(aura) ~= "table" or not aura.spellId) then return end
            local mount = C_MountJournal.GetMountFromSpell(aura.spellId)
            if (mount) then
                auraName = aura.name
                auraSpellID = aura.spellId
                mountID = mount
                return true
            end
        end)
        if (not ok) then
            auraName, auraSpellID, mountID = nil, nil, nil
        end
        if (auraSpellID) then
            return auraName, auraSpellID, mountID
        end
    end
    if (UnitAura) then
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, spellID = UnitAura(unit, i, "HELPFUL")
            if (not name) then break end
            local mountID = C_MountJournal.GetMountFromSpell(spellID)
            if (mountID) then
                return name, spellID, mountID
            end
        end
        return
    end
    if (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if (not aura) then break end
            local mountID = C_MountJournal.GetMountFromSpell(aura.spellId)
            if (mountID) then
                return aura.name, aura.spellId, mountID
            end
        end
    end
end

local function GetMountInfo(unit)
    if (not C_MountJournal or not C_MountJournal.GetMountInfoByID) then return end
    if (not SafeBool(UnitIsPlayer, unit)) then return end
    local auraName, _, mountID = FindMountAura(unit)
    if (not auraName) then return end
    local name, isCollected
    if (mountID) then
        local ok, mountName, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, mountID)
        if (ok) then
            name = mountName
            isCollected = collected
        end
    end
    return name or auraName, isCollected
end

local function SafeConcat(list, sep)
    if (type(list) ~= "table") then return "" end
    local out = {}
    for i = 1, #list do
        local v = list[i]
        if (v ~= nil) then
            local ok, s = pcall(function()
                if (type(v) == "string") then return v end
                if (type(v) == "number") then return tostring(v) end
            end)
            if (ok and type(s) == "string") then
                out[#out + 1] = s
            end
        end
    end
    local ok, res = pcall(table.concat, out, sep or " ")
    if (ok and type(res) == "string") then
        return res
    end
    return ""
end

local function HideOriginalSpecLine(tip, target)
    if (not target or target == "") then return end
    for i = 2, tip:NumLines() do
        local line = _G[tip:GetName() .. "TextLeft" .. i]
        local text = line and line:GetText()
        local stripped = SafeStripText(text)
        if (stripped and stripped == target) then
                line:SetText(nil)
                line:Show()
        end
    end
end

local function GetOriginalSpecLine(tip, className)
    if (not className or className == "") then return end
    local best, bestLen
    for i = 2, tip:NumLines() do
        local line = _G[tip:GetName() .. "TextLeft" .. i]
        local text = line and line:GetText()
        local stripped = SafeStripText(text)
        if (stripped) then
            local ok, match = pcall(function()
                if (stripped:find("^%d")) then return false end
                if (stripped:find("^<")) then return false end
                return stripped:find(className, 1, true) ~= nil
            end)
            if (ok and match) then
                local len = #stripped
                if (not bestLen or len < bestLen) then
                    best = stripped
                    bestLen = len
                end
            end
        end
    end
    return best
end

local function ColorBorder(tip, config, raw)
    if (config.coloredBorder and addon.colorfunc[config.coloredBorder]) then
        local r, g, b = addon.colorfunc[config.coloredBorder](raw)
        LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
    elseif (type(config.coloredBorder) == "string" and config.coloredBorder ~= "default") then
        local r, g, b = addon:GetRGBColor(config.coloredBorder)
        if (r and g and b) then
            LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
        end
    else
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
    end
end

local function ColorBackground(tip, config, raw)
    local bg = config.background
    if not bg then return end
    if (bg.colorfunc == "default" or bg.colorfunc == "" or bg.colorfunc == "inherit") then
        local r, g, b, a = unpack(addon.db.general.background)
        a = bg.alpha or a
        LibEvent:trigger("tooltip.style.background", tip, r, g, b, a)
        return
    end
    if (addon.colorfunc[bg.colorfunc]) then
        local r, g, b = addon.colorfunc[bg.colorfunc](raw)
        local a = bg.alpha or 0.8
        LibEvent:trigger("tooltip.style.background", tip, r, g, b, a)
    end
end

local function GrayForDead(tip, config, unit)
    if (config.grayForDead and SafeBool(UnitIsDeadOrGhost, unit)) then
        local line, text
        LibEvent:trigger("tooltip.style.border.color", tip, 0.6, 0.6, 0.6)
        LibEvent:trigger("tooltip.style.background", tip, 0.1, 0.1, 0.1)
        for i = 1, tip:NumLines() do
            line = _G[tip:GetName() .. "TextLeft" .. i]
            text = (line:GetText() or ""):gsub("|cff%x%x%x%x%x%x", "|cffaaaaaa")
            line:SetTextColor(0.7, 0.7, 0.7)
            line:SetText(text)
        end
    end
end

local function ShowBigFactionIcon(tip, config, raw)
    if (config.elements.factionBig and config.elements.factionBig.enable and tip.BigFactionIcon and (raw.factionGroup=="Alliance" or raw.factionGroup == "Horde")) then
        tip.BigFactionIcon:Show()
        tip.BigFactionIcon:SetTexture("Interface\\Timer\\".. raw.factionGroup .."-Logo")
        tip:Show()
        local okWidth, width = pcall(tip.GetWidth, tip)
        if (okWidth and type(width) == "number" and not (issecretvalue and issecretvalue(width))) then
            tip:SetMinimumWidth(width + 30)
        end
    end
end



local function PlayerCharacter(tip, unit, config, raw)
    local unitGuid = UnitGUID and UnitGUID(unit)
    local specLine = GetOriginalSpecLine(tip, raw and raw.className)
    if (specLine) then
        raw.className = specLine
        HideOriginalSpecLine(tip, specLine)
        if (tip and unitGuid) then
            tip._tinySpecGUID = unitGuid
            tip._tinySpecLine = specLine
        end
    elseif (tip and raw and unitGuid and tip._tinySpecGUID == unitGuid and type(tip._tinySpecLine) == "string" and tip._tinySpecLine ~= "") then
        -- Keep specialization text during async inspect refresh.
        raw.className = tip._tinySpecLine
    end
    raw.mountName = nil
    raw.mountCollected = nil
    if (config and config.elements and config.elements.mount and config.elements.mount.enable) then
        raw.mountName, raw.mountCollected = GetMountInfo(unit)
    end
    if (config and config.elements and addon.RequestInspectItemLevel) then
        local showItemLevel = (config.elements.itemLevel and config.elements.itemLevel.enable)
        if (showItemLevel and raw and raw.itemLevel == "??") then
            addon:RequestInspectItemLevel(unit)
        end
    end
    if (config and config.elements and addon.RequestInspectAchievementPoints) then
        local showAchievementPoints = (config.elements.achievementPoints and config.elements.achievementPoints.enable)
        if (showAchievementPoints and raw and raw.achievementPoints == "??") then
            addon:RequestInspectAchievementPoints(unit)
        end
    end
    local data = addon:GetUnitData(unit, config.elements, raw)
    addon:HideLines(tip, 2, 3)
    addon:HideLine(tip, "^"..LEVEL)
    addon:HideLine(tip, "^"..FACTION_ALLIANCE)
    addon:HideLine(tip, "^"..FACTION_HORDE)
    addon:HideLine(tip, "^"..PVP)
    for i, v in ipairs(data) do
        addon:GetLine(tip,i):SetText(strip(SafeConcat(v, " ")))
    end
    ColorBorder(tip, config, raw)
    ColorBackground(tip, config, raw)
    GrayForDead(tip, config, unit)
    if (addon.AutoSetTooltipWidth) then
        addon:AutoSetTooltipWidth(tip)
    end
    ShowBigFactionIcon(tip, config, raw)
end

local function NonPlayerCharacter(tip, unit, config, raw)
    local levelLine = addon:FindLine(tip, "^"..LEVEL)
    if (levelLine or tip:NumLines() > 1) then
        local data = addon:GetUnitData(unit, config.elements, raw)
        local titleLine = addon:GetNpcTitle(tip)
        local increase = 0
        for i, v in ipairs(data) do
            if (i == 1) then
                addon:GetLine(tip,i):SetText(SafeConcat(v, " "))
            end
            if (i == 2) then
                if (config.elements.npcTitle.enable and titleLine) then
                    local npcTitleText = titleLine:GetText()
                    if (npcTitleText and npcTitleText ~= "") then
                        titleLine:SetText(addon:FormatData(npcTitleText, config.elements.npcTitle, raw))
                        increase = 1
                    end
                end
                i = i + increase
                addon:GetLine(tip,i):SetText(SafeConcat(v, " "))
            elseif ( i > 2) then
                i = i + increase
                addon:GetLine(tip,i):SetText(SafeConcat(v, " "))
            end
        end
    end
    addon:HideLine(tip, "^"..LEVEL)
    addon:HideLine(tip, "^"..PVP)
    ColorBorder(tip, config, raw)
    ColorBackground(tip, config, raw)
    GrayForDead(tip, config, unit)
    ShowBigFactionIcon(tip, config, raw)
    addon:AutoSetTooltipWidth(tip)
end

local function IsUnitTooltip(tt)
    local owner = tt and tt:GetOwner()
    if not owner then return false end
    
    -- 安全访问 owner.unit
    local ok, unit = pcall(function() return owner.unit end)
    if (ok and unit) then return true end
    
    -- 安全访问 GetAttribute
    if (owner.GetAttribute) then
        local okAttr, attrUnit = pcall(owner.GetAttribute, owner, "unit")
        if (okAttr and attrUnit) then return true end
    end
    
    return false
end

LibEvent:attachTrigger("tooltip:unit", function(self, tip, unit)
    if (not unit or not SafeBool(UnitExists, unit)) then return end
    if (tip and UnitGUID) then
        local previousGuid = tip._tinyUnitGUID
        local okGuid, guid = pcall(UnitGUID, unit)
        tip._tinyUnitGUID = okGuid and guid or nil
        if (previousGuid and tip._tinyUnitGUID and previousGuid ~= tip._tinyUnitGUID) then
            tip._tinySpecGUID = nil
            tip._tinySpecLine = nil
        end
    end
    local raw = addon:GetUnitInfo(unit)
    if (SafeBool(UnitIsPlayer, unit)) then
        PlayerCharacter(tip, unit, addon.db.unit.player, raw)
    else
        NonPlayerCharacter(tip, unit, addon.db.unit.npc, raw)
    end
end)

LibEvent:attachTrigger("tooltip:item, tooltip:spell, tooltip:aura, tooltip:hide, tooltip:cleared", function(self, tip)
    if (tip) then
        tip._tinyUnitGUID = nil
        tip._tinySpecGUID = nil
        tip._tinySpecLine = nil
    end
end)

LibEvent:attachTrigger("tooltip:show", function(self, tip)
    if (tip ~= GameTooltip) then return end
    if (FACTION_ALLIANCE) then addon:HideLine(tip, "^" .. FACTION_ALLIANCE) end
    if (FACTION_HORDE) then addon:HideLine(tip, "^" .. FACTION_HORDE) end
end)

local function RemoveFactionLinesPost(tip)
    if (not tip or not tip.GetName) then return end
    for i = 2, tip:NumLines() do
        local line = _G[tip:GetName() .. "TextLeft" .. i]
        local text = line and line:GetText()
        local stripped = SafeStripText(text)
        if (stripped and (stripped == FACTION_ALLIANCE or stripped == FACTION_HORDE)) then
            line:SetText("")
            --line:Hide() -- somehow not working but I will keep it in  here
        end
    end
end

if (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip)
        RemoveFactionLinesPost(tip)
    end)
end

local function RemoveRightClickHint(tt)
    local removed = false
    if (not tt or not tt.GetName) then return false end
    for i = 2, tt:NumLines() do
        local line = _G[tt:GetName() .. "TextLeft" .. i]
        local text
        if (line and line.GetText) then
            local ok, value = pcall(line.GetText, line)
            if (ok) then
                text = value
            end
        end
        if (type(text) == "string") then
            if (issecretvalue and issecretvalue(text)) then
                -- can't safely read/strip secret text
            else
                local ok, stripped = pcall(function()
                    local s = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    return s:gsub("^%s+", ""):gsub("%s+$", "")
                end)
                if (ok and type(stripped) == "string") then
                    if (UNIT_POPUP_RIGHT_CLICK and stripped == UNIT_POPUP_RIGHT_CLICK) then
                        line:SetText("")
                        --line:Hide()
                        removed = true
                    end
                end
            end
        end
    end
    return removed
end

if (GameTooltip_AddInstructionLine) then
    hooksecurefunc("GameTooltip_AddInstructionLine", function(tt, text)
        if (not addon.db.general.hideUnitFrameHint) then return end
        if (tt ~= GameTooltip) then return end
        if (not IsUnitTooltip(tt)) then return end
        -- debug output removed
        
        local removed = false
        if (UNIT_POPUP_RIGHT_CLICK and text == UNIT_POPUP_RIGHT_CLICK) then
            local i = tt:NumLines()
            local line = _G[tt:GetName() .. "TextLeft" .. i]
            if (line) then
                pcall(line.SetText, line, "")
                pcall(line.Hide, line)
                removed = true
            end
            local mLine = _G[tt:GetName() .. "TextLeft" .. (i - 1)]
            if (mLine and mLine.GetText) then
                local okPrev, prevText = pcall(mLine.GetText, mLine)
                if (okPrev and (not (issecretvalue and issecretvalue(prevText))) and prevText == " ") then
                    pcall(mLine.Hide, mLine)
                end
            end
        end
        if (not removed) then
            removed = RemoveRightClickHint(tt)
        end
    end)
end

addon.ColorUnitBorder = ColorBorder
addon.ColorUnitBackground = ColorBackground
