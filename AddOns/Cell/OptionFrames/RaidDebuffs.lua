local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local LCG = LibStub("LibCustomGlow-1.0")

local debuffsTab = Cell:CreateFrame("CellOptionsFrame_RaidDebuffsTab", Cell.frames.optionsFrame, nil, nil, true)
Cell.frames.raidDebuffsTab = debuffsTab
debuffsTab:SetAllPoints(Cell.frames.optionsFrame)
debuffsTab:Hide()

-- vars
local newestExpansion, loadedExpansion, loadedInstance, loadedBoss, isGeneral
local currentBossTable, selectedButtonIndex, selectedSpellId, selectedSpellName, selectedSpellIcon
-- functions
local LoadExpansion, ShowInstances, ShowBosses, ShowDebuffs, ShowDetails, ShowImage, HideImage, OpenEncounterJournal
-- buttons
local instanceButtons, bossButtons, debuffButtons = {}, {}, {}
-------------------------------------------------
-- prepare debuff list
-------------------------------------------------
-- NOTE: instanceId is instanceEncounterJournalId
-- mapId = C_Map.GetBestMapForUnit("player")
-- instanceId = EJ_GetInstanceForMap(mapId)
-- instanceName, ... = EJ_GetInstanceInfo(instanceId)

-- used for sort list buttons
local encounterJournalList = {
    -- ["expansionName"] = {
    --     {
    --         ["name"] = instanceName,
    --         ["id"] = instanceId,
    --         ["bosses"] = {
    --             {["name"]=name, ["id"]=id, ["image"]=image},
    --         },
    --     },
    -- },
}

local instanceIds = { -- used for GetInstanceInfo/GetRealZoneText --> instanceId
    -- [instanceName] = expansionName:instanceIndex:instanceId,
}

local function LoadBossList(instanceId, list)
    EJ_SelectInstance(instanceId)
    for index = 1, 77 do
		local name, _, id = EJ_GetEncounterInfoByIndex(index)
		if not name or not id then
			break
        end
        
        -- id, name, description, displayInfo, iconImage, uiModelSceneID = EJ_GetCreatureInfo(index [, encounterID])
        local image = select(5, EJ_GetCreatureInfo(1, id))
        tinsert(list, {["name"]=name, ["id"]=id, ["image"]=image})
	end
end

local function LoadInstanceList(tier, instanceType, list)
    local isRaid = instanceType == "raid"
    for index = 1, 77 do
        EJ_SelectTier(tier)
        local id, name = EJ_GetInstanceByIndex(index, isRaid)
        if not id or not name then
            break
        end

        local eName = EJ_GetTierInfo(tier)
        local instanceTable = {["name"]=name, ["id"]=id, ["bosses"]={}}
        tinsert(list, instanceTable)
        instanceIds[name] = eName..":"..#list..":"..id -- NOTE: used for searching current zone debuffs & switch to current instance

        LoadBossList(id, instanceTable["bosses"])
    end
end

local function LoadList()
    for tier = 1, EJ_GetNumTiers() do
        local name = EJ_GetTierInfo(tier)
        encounterJournalList[name] = {}

        LoadInstanceList(tier, "raid", encounterJournalList[name])
        LoadInstanceList(tier, "party", encounterJournalList[name])

        newestExpansion = name
    end
end

LoadExpansion = function(eName)
    if loadedExpansion == eName then return end
    loadedExpansion = eName
    -- show then first boss of the first instance of the expansion
    ShowInstances(eName)

end

local unsortedDebuffs = {}
function F:LoadBuiltInDebuffs(debuffs)
    for instanceId, iTable in pairs(debuffs) do
        unsortedDebuffs[instanceId] = iTable
    end
end

local loadedDebuffs = {
    -- [instanceId] = {
    --     ["general"] = {
    --         ["enabled"]= {
    --             {["id"]=spellId, ["order"]=order, ["trackByID"]=trackByID, ["glowType"]=glowType, ["glowOptions"]={...}, ["glowCondition"]={...}}
    --         },
    --         ["disabled"] = {},
    --     },
    --     [bossId] = {
    --         ["enabled"]= {
    --             {["id"]=spellId, ["order"]=order, ["trackByID"]=trackByID, ["glowType"]=glowType, ["glowOptions"]={...}, ["glowCondition"]={...}}
    --         },
    --         ["disabled"] = {},
    --     },
    -- },
}

local function LoadDebuffs()
    -- check db
    for instanceId, iTable in pairs(CellDB["raidDebuffs"]) do
        if not loadedDebuffs[instanceId] then loadedDebuffs[instanceId] = {} end

        for bossId, bTable in pairs(iTable) do
            if not loadedDebuffs[instanceId][bossId] then loadedDebuffs[instanceId][bossId] = {["enabled"]={}, ["disabled"]={}} end
            -- load from db and set its order
            for spellId, sTable in pairs(bTable) do
                local t = {["id"]=spellId, ["order"]=sTable[1], ["trackByID"]=sTable[2], ["glowType"]=sTable[3], ["glowOptions"]=sTable[4], ["glowCondition"]=sTable[5]}
                if sTable[1] == 0 then
                    tinsert(loadedDebuffs[instanceId][bossId]["disabled"], t)
                else
                    loadedDebuffs[instanceId][bossId]["enabled"][sTable[1]] = t
                end
            end
        end
    end

    -- check built-in
    for instanceId, iTable in pairs(unsortedDebuffs) do
        if not loadedDebuffs[instanceId] then loadedDebuffs[instanceId] = {} end

        for bossId, bTable in pairs(iTable) do
            if not loadedDebuffs[instanceId][bossId] then loadedDebuffs[instanceId][bossId] = {["enabled"]={}, ["disabled"]={}} end
            -- load
            for i, spellId in pairs(bTable) do
                if not (CellDB["raidDebuffs"][instanceId] and CellDB["raidDebuffs"][instanceId][bossId] and CellDB["raidDebuffs"][instanceId][bossId][tonumber(spellId)]) then
                    if type(spellId) == "string" then -- track by id
                        F:TInsert(loadedDebuffs[instanceId][bossId]["enabled"], {["id"]=tonumber(spellId), ["order"]=#loadedDebuffs[instanceId][bossId]["enabled"]+1, ["trackByID"]=true, ["built-in"]=true})
                    else
                        F:TInsert(loadedDebuffs[instanceId][bossId]["enabled"], {["id"]=spellId, ["order"]=#loadedDebuffs[instanceId][bossId]["enabled"]+1, ["built-in"]=true})
                    end
                else -- exists in both CellDB and built-in
                    local found
                    -- find in loadedDebuffs and mark it as built-in
                    for _, sTable in pairs(loadedDebuffs[instanceId][bossId]["enabled"]) do
                        if sTable["id"] == tonumber(spellId) then
                            found = true
                            sTable["built-in"] = true
                            break
                        end
                    end
                    -- check disabled if not found
                    if not found then
                        for _, sTable in pairs(loadedDebuffs[instanceId][bossId]["disabled"]) do
                            if sTable["id"] == tonumber(spellId) then
                                sTable["built-in"] = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    -- check orders
    for iId, iTable in pairs(loadedDebuffs) do
        for bId, bTable in pairs(iTable) do
            local currentN, correctN = #bTable["enabled"], F:Getn(bTable["enabled"])
            if currentN ~= correctN then -- missing some debuffs, maybe deleted from .lua
                -- texplore(bTable)
                F:Debug("|cffff2222FIX MISSING DEBUFFS|r", iId, bId)
                local temp = {}
                for _, sTable in pairs(bTable["enabled"]) do
                    tinsert(temp, sTable)
                end
                for k, sTable in ipairs(temp) do
                    if sTable["order"] ~= k then
                        -- fix loadedDebuffs
                        sTable["order"] = k
                        -- fix db
                        if CellDB["raidDebuffs"][iId] and CellDB["raidDebuffs"][iId][bId] and CellDB["raidDebuffs"][iId][bId][sTable["id"]] then
                            CellDB["raidDebuffs"][iId][bId][sTable["id"]][1] = k
                        end
                    end
                end
                bTable["enabled"] = temp
            end
        end
    end
    -- texplore(loadedDebuffs[226])
end

local function UpdateRaidDebuffs()
    LoadList()
    -- DevInstanceList = F:Copy(encounterJournalList["暗影国度"])
    LoadDebuffs()
end
Cell:RegisterCallback("UpdateRaidDebuffs", "RaidDebuffsTab_UpdateRaidDebuffs", UpdateRaidDebuffs)

-------------------------------------------------
-- expansion dropdown
-------------------------------------------------
local expansionDropdown = Cell:CreateDropdown(debuffsTab, 120)
expansionDropdown:SetPoint("TOPLEFT", 5, -5)

local expansionItems = {}
for i = EJ_GetNumTiers(), 1, -1 do
    local eName = EJ_GetTierInfo(i)
    tinsert(expansionItems, {
        ["text"] = eName,
        ["onClick"] = function()
            LoadExpansion(eName)
        end,
    })
end
expansionDropdown:SetItems(expansionItems)

-------------------------------------------------
-- current instance button
-------------------------------------------------
local showCurrentBtn = Cell:CreateButton(debuffsTab, "", "class-hover", {20, 20}, nil, nil, nil, nil, nil, L["Show Current Instance"])
showCurrentBtn:SetPoint("LEFT", expansionDropdown, "RIGHT", 5, 0)
showCurrentBtn.tex = showCurrentBtn:CreateTexture(nil, "ARTWORK")
showCurrentBtn.tex:SetPoint("TOPLEFT", 1, -1)
showCurrentBtn.tex:SetPoint("BOTTOMRIGHT", -1, 1)
showCurrentBtn.tex:SetAtlas("DungeonSkull")

showCurrentBtn:SetScript("OnClick", function()
    if IsInInstance() then
        local name = GetInstanceInfo()
        if not name or not instanceIds[name] then return end

        local eName, index, id = F:SplitToNumber(":", instanceIds[name])
        if loadedInstance == id then return end
        expansionDropdown:SetSelected(eName)
        LoadExpansion(eName)
        instanceButtons[index]:Click()
        -- scroll
        if index > 9 then
            RaidDebuffsTab_Instances.scrollFrame:SetVerticalScroll((index-9)*19)
        end
    end
end)

-------------------------------------------------
-- tips
-------------------------------------------------
local tips = Cell:CreateScrollTextFrame(debuffsTab, "|cffb7b7b7"..L["Tips: Drag and drop to change debuff order. Double-click on instance name to open Encounter Journal. The priority of General Debuffs is higher than Boss Debuffs."], 0.02)
tips:SetPoint("TOPLEFT", showCurrentBtn, "TOPRIGHT", 5, 0)
tips:SetPoint("RIGHT", -5, 0)

-------------------------------------------------
-- list button onEnter, onLeave
-------------------------------------------------
local function SetOnEnterLeave(frame)
    frame:SetScript("OnEnter", function()
        frame:SetBackdropBorderColor(unpack(Cell:GetPlayerClassColorTable()))
        frame.scrollFrame.scrollbar:SetBackdropBorderColor(unpack(Cell:GetPlayerClassColorTable()))
        -- frame.scrollFrame.scrollThumb:SetBackdropBorderColor(0, 0, 0, .5)
    end)
    frame:SetScript("OnLeave", function()
        frame:SetBackdropBorderColor(0, 0, 0, 1)
        frame.scrollFrame.scrollbar:SetBackdropBorderColor(0, 0, 0, 1)
        frame.scrollFrame.scrollThumb:SetBackdropBorderColor(0, 0, 0, 1)
    end)
end

-------------------------------------------------
-- instances frame
-------------------------------------------------
local instancesFrame = Cell:CreateFrame("RaidDebuffsTab_Instances", debuffsTab, 120, 172)
instancesFrame:SetPoint("TOPLEFT", expansionDropdown, "BOTTOMLEFT", 0, -5)
-- instancesFrame:SetPoint("BOTTOMLEFT", 5, 5)
instancesFrame:Show()
Cell:CreateScrollFrame(instancesFrame)
instancesFrame.scrollFrame:SetScrollStep(19)
SetOnEnterLeave(instancesFrame)

ShowInstances = function(eName)
    instancesFrame.scrollFrame:ResetScroll()

    for i, iTable in pairs(encounterJournalList[eName]) do
        if not instanceButtons[i] then
            instanceButtons[i] = Cell:CreateButton(instancesFrame.scrollFrame.content, iTable["name"], "transparent-class", {20, 20})
        else
            instanceButtons[i]:SetText(iTable["name"])
            instanceButtons[i]:Show()
        end

        instanceButtons[i].id = iTable["id"].."-"..i -- send instanceId-instanceIndex to ShowBosses
        
        -- open encounter journal
        instanceButtons[i]:SetScript("OnDoubleClick", function()
            OpenEncounterJournal(iTable["id"])
        end)

        if i == 1 then
            instanceButtons[i]:SetPoint("TOPLEFT")
        else
            instanceButtons[i]:SetPoint("TOPLEFT", instanceButtons[i-1], "BOTTOMLEFT", 0, 1)
        end
        instanceButtons[i]:SetPoint("RIGHT")
    end

    local n = #encounterJournalList[eName]

    -- update scrollFrame content height
    instancesFrame.scrollFrame:SetContentHeight(20, n, -1)

    -- hide unused instance buttons
    for i = n+1, #instanceButtons do
        instanceButtons[i]:Hide()
        instanceButtons[i]:ClearAllPoints()
    end

    -- set onclick
    Cell:CreateButtonGroup(instanceButtons, ShowBosses, nil, nil, instancesFrame:GetScript("OnEnter"), instancesFrame:GetScript("OnLeave"))
    instanceButtons[1]:Click()
end

-------------------------------------------------
-- bosses frame
-------------------------------------------------
local bossesFrame = Cell:CreateFrame("RaidDebuffsTab_Bosses", debuffsTab, 120, 191)
-- bossesFrame:SetPoint("TOPLEFT", instancesFrame, "BOTTOMLEFT", 0, -5)
bossesFrame:SetPoint("BOTTOMLEFT", 5, 5)
bossesFrame:Show()
Cell:CreateScrollFrame(bossesFrame)
bossesFrame.scrollFrame:SetScrollStep(19)
SetOnEnterLeave(bossesFrame)

ShowBosses = function(instanceId)
    local iId, iIndex = F:SplitToNumber("-", instanceId)

    if loadedInstance == iId then return end
    loadedInstance = iId

    bossesFrame.scrollFrame:ResetScroll()

    -- instance general debuff
    if not bossButtons[0] then
        bossButtons[0] = Cell:CreateButton(bossesFrame.scrollFrame.content, L["General"], "transparent-class", {20, 20})
        bossButtons[0]:SetPoint("TOPLEFT")
        bossButtons[0]:SetPoint("RIGHT")
    end
    bossButtons[0].id = iId
    
    -- bosses
    for i, bTable in pairs(encounterJournalList[loadedExpansion][iIndex]["bosses"]) do
        if not bossButtons[i] then
            bossButtons[i] = Cell:CreateButton(bossesFrame.scrollFrame.content, bTable["name"], "transparent-class", {20, 20})
        else
            bossButtons[i]:SetText(bTable["name"])
            bossButtons[i]:Show()
        end

        bossButtons[i].id = bTable["id"].."-"..i -- send bossId-bossIndex to ShowDebuffs TODO: just pass bossId

        bossButtons[i]:SetPoint("TOPLEFT", bossButtons[i-1], "BOTTOMLEFT", 0, 1)
        bossButtons[i]:SetPoint("RIGHT")
    end

    local n = #encounterJournalList[loadedExpansion][iIndex]["bosses"]

    -- update scrollFrame content height
    bossesFrame.scrollFrame:SetContentHeight(20, n+1, -1)

    -- hide unused instance buttons
    for i = n+1, #bossButtons do
        bossButtons[i]:Hide()
        bossButtons[i]:ClearAllPoints()
    end

    -- set onclick/onenter
    Cell:CreateButtonGroup(bossButtons, ShowDebuffs, nil, nil, function(b)
        if b.id ~= iId then -- not General
            local _, bIndex = F:SplitToNumber("-", b.id)
            ShowImage(encounterJournalList[loadedExpansion][iIndex]["bosses"][bIndex]["image"], b)
        end
        bossesFrame:GetScript("OnEnter")()
    end, function(b)
        HideImage()
        bossesFrame:GetScript("OnLeave")()
    end)

    -- show General by default
    bossButtons[0]:Click()
end

-------------------------------------------------
-- boss image frame
-------------------------------------------------
local imageFrame = Cell:CreateFrame("RaidDebuffsTab_Image", debuffsTab, 128, 64, true)
imageFrame.bg = imageFrame:CreateTexture(nil, "BACKGROUND")
imageFrame.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
imageFrame.bg:SetGradientAlpha("HORIZONTAL", .1, .1, .1, 0, .1, .1, .1, 1)
imageFrame.bg:SetAllPoints(imageFrame)

imageFrame.tex = imageFrame:CreateTexture(nil, "ARTWORK")
imageFrame.tex:SetSize(128, 64)
imageFrame.tex:SetPoint("TOPRIGHT")

ShowImage = function(image, b)
    imageFrame.tex:SetTexture(image)
    imageFrame:ClearAllPoints()
    imageFrame:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", -5, 0)
    imageFrame:Show()
end

HideImage = function()
    imageFrame:Hide()
end

-------------------------------------------------
-- debuff list frame
-------------------------------------------------
local debuffListFrame = Cell:CreateFrame("RaidDebuffsTab_Debuffs", debuffsTab, 120, 343)
debuffListFrame:SetPoint("TOPLEFT", instancesFrame, "TOPRIGHT", 5, 0)
debuffListFrame:Show()
Cell:CreateScrollFrame(debuffListFrame)
debuffListFrame.scrollFrame:SetScrollStep(19)
SetOnEnterLeave(debuffListFrame)

local create = Cell:CreateButton(debuffsTab, L["Create"], "class-hover", {58, 20})
create:SetPoint("TOPLEFT", debuffListFrame, "BOTTOMLEFT", 0, -3)
create:SetScript("OnClick", function()
    local popup = Cell:CreateConfirmPopup(debuffsTab, 200, L["Create new debuff (id)"], function(self)
        local id = tonumber(self.editBox:GetText()) or 0
        local name = GetSpellInfo(id)
        if not name then
            F:Print(L["Invalid spell id."])
            return
        end
        -- check whether already exists
        if currentBossTable then
            for _, sTable in pairs(currentBossTable["enabled"]) do
                if sTable["id"] == id then
                    F:Print(L["Debuff already exists."])
                    return
                end
            end
            for _, sTable in pairs(currentBossTable["disabled"]) do
                if sTable["id"] == id then
                    F:Print(L["Debuff already exists."])
                    return
                end
            end
        end

        -- update db
        if not CellDB["raidDebuffs"][loadedInstance] then CellDB["raidDebuffs"][loadedInstance] = {} end
        if isGeneral then
            if not CellDB["raidDebuffs"][loadedInstance]["general"] then CellDB["raidDebuffs"][loadedInstance]["general"] = {} end
            CellDB["raidDebuffs"][loadedInstance]["general"][id] = {currentBossTable and #currentBossTable["enabled"]+1 or 1, false}
        else
            if not CellDB["raidDebuffs"][loadedInstance][loadedBoss] then CellDB["raidDebuffs"][loadedInstance][loadedBoss] = {} end
            CellDB["raidDebuffs"][loadedInstance][loadedBoss][id] = {currentBossTable and #currentBossTable["enabled"]+1 or 1, false}
        end
        -- update loadedDebuffs
        if currentBossTable then
            tinsert(currentBossTable["enabled"], {["id"]=id, ["order"]=#currentBossTable["enabled"]+1})
            ShowDebuffs(isGeneral and loadedInstance or loadedBoss, #currentBossTable["enabled"])
        else -- no boss table
            if not loadedDebuffs[loadedInstance] then loadedDebuffs[loadedInstance] = {} end
            loadedDebuffs[loadedInstance][isGeneral and "general" or loadedBoss] = {["enabled"]={{["id"]=id, ["order"]=1}}, ["disabled"]={}}
            ShowDebuffs(isGeneral and loadedInstance or loadedBoss, 1)
        end
        -- notify debuff list changed
        Cell:Fire("RaidDebuffsChanged")
    end, nil, true, true)
    popup.editBox:SetNumeric(true)
    popup:SetPoint("TOPLEFT", 100, -170)
end)

local delete = Cell:CreateButton(debuffsTab, L["Delete"], "class-hover", {57, 20})
delete:SetPoint("LEFT", create, "RIGHT", 5, 0)
delete:SetEnabled(false)
delete:SetScript("OnClick", function()
    local text = selectedSpellName.." ["..selectedSpellId.."]".."\n".."|T"..selectedSpellIcon..":12:12:0:0:12:12:1:11:1:11|t"
    local popup = Cell:CreateConfirmPopup(debuffsTab, 200, L["Delete debuff?"].."\n"..text, function()
        -- update db
        local index = isGeneral and "general" or loadedBoss
        local order = CellDB["raidDebuffs"][loadedInstance][index][selectedSpellId][1]
        CellDB["raidDebuffs"][loadedInstance][index][selectedSpellId] = nil
        for sId, sTable in pairs(CellDB["raidDebuffs"][loadedInstance][index]) do
            if sTable[1] > order then
                sTable[1] = sTable[1] - 1 -- update orders
            end
        end
        -- update loadedDebuffs
        local found
        for k, sTable in ipairs(currentBossTable["enabled"]) do
            if sTable["id"] == selectedSpellId then
                found = true
                tremove(currentBossTable["enabled"], k)
                break
            end
        end
        if found then -- is enabled, update orders
            for i = selectedButtonIndex, #currentBossTable["enabled"] do
                currentBossTable["enabled"][i]["order"] = currentBossTable["enabled"][i]["order"] - 1 -- update orders
            end
        end
        -- check disabled if not found
        if not found then
            for k, sTable in pairs(currentBossTable["disabled"]) do
                if sTable["id"] == selectedSpellId then
                    tremove(currentBossTable["disabled"], k)
                    break
                end
            end
        end
        -- reload
        if isGeneral then -- general
            ShowDebuffs(loadedInstance, 1)
        else
            ShowDebuffs(loadedBoss, 1)
        end
        -- notify debuff list changed
        Cell:Fire("RaidDebuffsChanged")
    end, nil, true)
    popup:SetPoint("TOPLEFT", 100, -170)
end)

-- local enableAll = Cell:CreateButton(debuffsTab, L["Enable All"], "class-hover", {66, 20})
-- enableAll:SetPoint("LEFT", delete, "RIGHT", 5, 0)

-- local disableAll = Cell:CreateButton(debuffsTab, L["Disable All"], "class-hover", {66, 20})
-- disableAll:SetPoint("LEFT", enableAll, "RIGHT", 5, 0)

local dragged = Cell:CreateFrame("RaidDebuffsTab_Dragged", debuffsTab, 20, 20)
Cell:StylizeFrame(dragged, nil, Cell:GetPlayerClassColorTable())
dragged:SetFrameStrata("HIGH")
dragged:EnableMouse(false)
dragged:SetMovable(true)
dragged:SetToplevel(true)
-- stick dragged to mouse
dragged:SetScript("OnUpdate", function()
    local scale, x, y = dragged:GetEffectiveScale(), GetCursorPosition()
    dragged:ClearAllPoints()
    dragged:SetPoint("LEFT", nil, "BOTTOMLEFT", 5+x/scale, y/scale)
end)
-- icon
dragged.icon = dragged:CreateTexture(nil, "ARTWORK")
dragged.icon:SetSize(16, 16)
dragged.icon:SetPoint("LEFT", 2, 0)
dragged.icon:SetTexCoord(.08, .92, .08, .92)
-- text
dragged.text = dragged:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
dragged.text:SetPoint("LEFT", dragged.icon, "RIGHT", 2, 0)
dragged.text:SetPoint("RIGHT", -2, 0)
dragged.text:SetJustifyH("LEFT")
dragged.text:SetWordWrap(false)

local function RegisterForDrag(b)
    -- dragging
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        self:SetAlpha(.5)
        dragged:SetWidth(self:GetWidth())
        dragged.icon:SetTexture(self.spellIcon)
        dragged.text:SetText(self:GetText())
        dragged:Show()
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetAlpha(1)
        dragged:Hide()
        local newB = GetMouseFocus()
        -- move on a debuff button & not on currently moving button & not disabled
        if newB:GetParent() == debuffListFrame.scrollFrame.content and newB ~= self and newB.enabled then
            local temp, from, to = self, self.index, newB.index
            local moved = currentBossTable["enabled"][from]

            if self.index > newB.index then
                -- move up -> before newB
                -- update old next button's position
                if debuffButtons[self.index+1] and debuffButtons[self.index+1]:IsShown() then
                    debuffButtons[self.index+1]:ClearAllPoints()
                    debuffButtons[self.index+1]:SetPoint(unpack(self.point1))
                    debuffButtons[self.index+1]:SetPoint("RIGHT")
                    debuffButtons[self.index+1].point1 = F:Copy(self.point1)
                end
                -- update new self position
                self:ClearAllPoints()
                self:SetPoint(unpack(newB.point1))
                self:SetPoint("RIGHT")
                self.point1 = F:Copy(newB.point1)
                -- update new next's position
                newB:ClearAllPoints()
                newB:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 1)
                newB:SetPoint("RIGHT")
                newB.point1 = {"TOPLEFT", self, "BOTTOMLEFT", 0, 1}
                -- update list & db
                if not CellDB["raidDebuffs"][loadedInstance] then CellDB["raidDebuffs"][loadedInstance] = {} end
                if not CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss] then CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss] = {} end
                for j = from, to, -1 do
                    if j == to then
                        debuffButtons[j] = temp
                        currentBossTable["enabled"][j] = moved
                        -- update db
                        if not CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss][debuffButtons[j].spellId] then
                            CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss][debuffButtons[j].spellId] = {j, false}
                        else
                            CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss][debuffButtons[j].spellId][1] = j
                        end
                    else
                        debuffButtons[j] = debuffButtons[j-1]
                        currentBossTable["enabled"][j] = currentBossTable["enabled"][j-1]
                        -- update db
                        if CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss][debuffButtons[j].spellId] then
                            CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss][debuffButtons[j].spellId][1] = j
                        end
                    end
                    debuffButtons[j].index = j
                    currentBossTable["enabled"][j]["order"] = j
                    debuffButtons[j].id = debuffButtons[j].spellId.."-"..j
                    -- update selectedButtonIndex
                    if debuffButtons[j].spellId == selectedSpellId then
                        selectedButtonIndex = j
                    end
                end
            else
                -- move down (after newB)
                -- update old next button's position
                if debuffButtons[self.index+1] and debuffButtons[self.index+1]:IsShown() then
                    debuffButtons[self.index+1]:ClearAllPoints()
                    debuffButtons[self.index+1]:SetPoint(unpack(self.point1))
                    debuffButtons[self.index+1]:SetPoint("RIGHT")
                    debuffButtons[self.index+1].point1 = F:Copy(self.point1)
                end
                -- update new self position
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", newB, "BOTTOMLEFT", 0, 1)
                self:SetPoint("RIGHT")
                self.point1 = {"TOPLEFT", newB, "BOTTOMLEFT", 0, 1}
                -- update new next button's position
                if debuffButtons[newB.index+1] and debuffButtons[newB.index+1]:IsShown() then
                    debuffButtons[newB.index+1]:ClearAllPoints()
                    debuffButtons[newB.index+1]:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 1)
                    debuffButtons[newB.index+1]:SetPoint("RIGHT")
                    debuffButtons[newB.index+1].point1 = {"TOPLEFT", self, "BOTTOMLEFT", 0, 1}
                end
                -- update list & db
                if not CellDB["raidDebuffs"][loadedInstance] then CellDB["raidDebuffs"][loadedInstance] = {} end
                if not CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss] then CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss] = {} end
                for j = from, to do
                    if j == to then
                        debuffButtons[j] = temp
                        currentBossTable["enabled"][j] = moved
                        -- update db
                        if not CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss][debuffButtons[j].spellId] then
                            CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss][debuffButtons[j].spellId] = {j, false}
                        else
                            CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss][debuffButtons[j].spellId][1] = j
                        end
                    else
                        debuffButtons[j] = debuffButtons[j+1]
                        currentBossTable["enabled"][j] = currentBossTable["enabled"][j+1]
                        -- update db
                        if CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss][debuffButtons[j].spellId] then
                            CellDB["raidDebuffs"][loadedInstance][isGeneral and "general" or loadedBoss][debuffButtons[j].spellId][1] = j
                        end
                    end
                    debuffButtons[j].index = j
                    currentBossTable["enabled"][j]["order"] = j
                    debuffButtons[j].id = debuffButtons[j].spellId.."-"..j
                    -- update selectedButtonIndex
                    if debuffButtons[j].spellId == selectedSpellId then
                        selectedButtonIndex = j
                    end
                end
            end
            -- notify debuff list changed
            Cell:Fire("RaidDebuffsChanged")
        end
    end)
end

local function UnregisterForDrag(b)
    b:SetMovable(false)
    b:SetScript("OnDragStart", nil)
    b:SetScript("OnDragStop", nil)
end

local last
local function CreateDebuffButton(i, sTable)
    if not debuffButtons[i] then
        debuffButtons[i] = Cell:CreateButton(debuffListFrame.scrollFrame.content, " ", "transparent-class", {20, 20})
        debuffButtons[i].index = i
        -- icon
        debuffButtons[i].icon = debuffButtons[i]:CreateTexture(nil, "ARTWORK")
        debuffButtons[i].icon:SetSize(16, 16)
        debuffButtons[i].icon:SetPoint("LEFT", 2, 0)
        debuffButtons[i].icon:SetTexCoord(.08, .92, .08, .92)
        -- update text position
        debuffButtons[i]:GetFontString():ClearAllPoints()
        debuffButtons[i]:GetFontString():SetPoint("LEFT", debuffButtons[i].icon, "RIGHT", 2, 0)
        debuffButtons[i]:GetFontString():SetPoint("RIGHT", -2, 0)
    end
    
    debuffButtons[i]:Show()

    local name, _, icon = GetSpellInfo(sTable["id"])
    if name then
        debuffButtons[i].icon:SetTexture(icon)
        debuffButtons[i].spellIcon = icon
        debuffButtons[i]:SetText(name)
    else
        debuffButtons[i].icon:SetTexture(134400)
        debuffButtons[i].spellIcon = 134400
        debuffButtons[i]:SetText(sTable["id"])
    end

    debuffButtons[i].spellId = sTable["id"]
    if sTable["order"] == 0 then
        debuffButtons[i]:SetTextColor(.4, .4, .4)
        UnregisterForDrag(debuffButtons[i])
        debuffButtons[i].enabled = nil
    else
        debuffButtons[i]:SetTextColor(1, 1, 1)
        RegisterForDrag(debuffButtons[i])
        debuffButtons[i].enabled = true
    end

    debuffButtons[i].id = sTable["id"].."-"..i -- send spellId-buttonIndex to ShowDetails

    debuffButtons[i]:ClearAllPoints()
    if last then
        debuffButtons[i]:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, 1)
        debuffButtons[i].point1 = {"TOPLEFT", last, "BOTTOMLEFT", 0, 1}
    else
        debuffButtons[i]:SetPoint("TOPLEFT")
        debuffButtons[i].point1 = {"TOPLEFT"}
    end
    debuffButtons[i]:SetPoint("RIGHT")
    debuffButtons[i].point2 = "RIGHT"

    last =  debuffButtons[i]
end

ShowDebuffs = function(bossId, buttonIndex)
    local bId, _ = F:SplitToNumber("-", bossId)
    
    if loadedBoss == bId and not buttonIndex then return end
    loadedBoss = bId

    last = nil
    -- hide debuffDetails
    selectedSpellId = nil
    selectedButtonIndex = nil
    RaidDebuffsTab_DebuffDetails.scrollFrame:Hide()
    delete:SetEnabled(false)

    debuffListFrame.scrollFrame:ResetScroll()
    
    isGeneral = bId == loadedInstance

    currentBossTable = nil
    if loadedDebuffs[loadedInstance] then
        if bId == loadedInstance then -- General
            currentBossTable = loadedDebuffs[loadedInstance]["general"]
        else
            currentBossTable = loadedDebuffs[loadedInstance][bId]
        end
    end

    local n = 0
    if currentBossTable then
        -- texplore(currentBossTable)
        n = 0
        for i, sTable in ipairs(currentBossTable["enabled"]) do
            n = n + 1
            CreateDebuffButton(i, sTable)
        end
        for _, sTable in pairs(currentBossTable["disabled"]) do
            n = n + 1
            CreateDebuffButton(n, sTable)
        end
    end
    
    -- update scrollFrame content height
    debuffListFrame.scrollFrame:SetContentHeight(20, n, -1)

    -- hide unused instance buttons
    for i = n+1, #debuffButtons do
        debuffButtons[i]:Hide()
        debuffButtons[i]:ClearAllPoints()
    end

    -- set onclick
    Cell:CreateButtonGroup(debuffButtons, ShowDetails, nil, nil, function(b)
        debuffListFrame:GetScript("OnEnter")()
        CellTooltip:SetOwner(b, "ANCHOR_NONE")
        CellTooltip:SetPoint("TOPRIGHT", b, "TOPLEFT", -1, 0)
        CellTooltip:SetHyperlink("spell:"..b.spellId)
        CellTooltip:Show()
    end, function(b)
        debuffListFrame:GetScript("OnLeave")()
        CellTooltip:Hide()
    end)

    if debuffButtons[buttonIndex or 1] and debuffButtons[buttonIndex or 1]:IsShown() then
        debuffButtons[buttonIndex or 1]:Click()
    else
        if RaidDebuffsPreviewButton:IsShown() then RaidDebuffsPreviewButton.fadeOut:Play() end
    end
end

-------------------------------------------------
-- debuff details frame
-------------------------------------------------
local detailsFrame = Cell:CreateFrame("RaidDebuffsTab_DebuffDetails", debuffsTab)
detailsFrame:SetPoint("TOPLEFT", debuffListFrame, "TOPRIGHT", 5, 0)
detailsFrame:SetPoint("BOTTOMRIGHT", -5, 5)
detailsFrame:Show()

local isMouseOver
detailsFrame:SetScript("OnUpdate", function()
    if detailsFrame:IsMouseOver() then
        if not isMouseOver or isMouseOver ~= 1 then
            detailsFrame:SetBackdropBorderColor(unpack(Cell:GetPlayerClassColorTable()))
            isMouseOver = 1
        end
    else
        if not isMouseOver or isMouseOver ~= 2 then
            detailsFrame:SetBackdropBorderColor(0, 0, 0, 1)
            isMouseOver = 2
        end
    end
end)

Cell:CreateScrollFrame(detailsFrame)

local detailsContentFrame = detailsFrame.scrollFrame.content
-- local detailsContentFrame = CreateFrame("Frame", "RaidDebuffsTab_DebuffDetailsContent", detailsFrame)
-- detailsContentFrame:SetAllPoints(detailsFrame)

-- spell icon
local spellIconBG = detailsContentFrame:CreateTexture(nil, "ARTWORK")
spellIconBG:SetSize(27, 27)
spellIconBG:SetDrawLayer("ARTWORK", 6)
spellIconBG:SetPoint("TOPLEFT", 5, -5)
spellIconBG:SetColorTexture(0, 0, 0, 1)

local spellIcon = detailsContentFrame:CreateTexture(nil, "ARTWORK")
spellIcon:SetDrawLayer("ARTWORK", 7)
spellIcon:SetTexCoord(.08, .92, .08, .92)
spellIcon:SetPoint("TOPLEFT", spellIconBG, 1, -1)
spellIcon:SetPoint("BOTTOMRIGHT", spellIconBG, -1, 1)

-- spell name & id
local spellNameText = detailsContentFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
spellNameText:SetPoint("TOPLEFT", spellIconBG, "TOPRIGHT", 2, 0)
spellNameText:SetPoint("RIGHT", -1, 0)
spellNameText:SetJustifyH("LEFT")
spellNameText:SetWordWrap(false)

local spellIdText = detailsContentFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
spellIdText:SetPoint("BOTTOMLEFT", spellIconBG, "BOTTOMRIGHT", 2, 0)
spellIdText:SetPoint("RIGHT")
spellIdText:SetJustifyH("LEFT")

-- enable
local enabledCB = Cell:CreateCheckButton(detailsContentFrame, L["Enabled"], function(checked)
    local newOrder = checked and #currentBossTable["enabled"]+1 or 0
    -- update db, on re-enabled set its order to the last
    if not CellDB["raidDebuffs"][loadedInstance] then CellDB["raidDebuffs"][loadedInstance] = {} end
    local tIndex = isGeneral and "general" or loadedBoss
    if not CellDB["raidDebuffs"][loadedInstance][tIndex] then CellDB["raidDebuffs"][loadedInstance][tIndex] = {} end
    if not CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId] then
        CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId] = {newOrder, false}
    else
        CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][1] = newOrder
    end
    if not checked then -- enabled -> disabled
        for i = selectedButtonIndex+1, #currentBossTable["enabled"] do
            local id = currentBossTable["enabled"][i]["id"]
            -- print("update db order: ", id)
            if CellDB["raidDebuffs"][loadedInstance][tIndex][id] then
                -- update db order
                CellDB["raidDebuffs"][loadedInstance][tIndex][id][1] = CellDB["raidDebuffs"][loadedInstance][tIndex][id][1] - 1
            end
        end
    end
    
    -- update loadedDebuffs
    local buttonIndex
    if checked then -- disabled -> enabled
        local disabledIndex = selectedButtonIndex-#currentBossTable["enabled"] -- index in ["disabled"]
        currentBossTable["enabled"][newOrder] = currentBossTable["disabled"][disabledIndex]
        currentBossTable["enabled"][newOrder]["order"] = newOrder
        tremove(currentBossTable["disabled"], disabledIndex) -- remove from ["disabled"]
        -- button to click
        buttonIndex = newOrder
    else -- enabled -> disabled
        for i = selectedButtonIndex+1, #currentBossTable["enabled"] do
            currentBossTable["enabled"][i]["order"] = currentBossTable["enabled"][i]["order"] - 1 -- update orders
        end
        currentBossTable["enabled"][selectedButtonIndex]["order"] = 0
        tinsert(currentBossTable["disabled"], currentBossTable["enabled"][selectedButtonIndex])
        tremove(currentBossTable["enabled"], selectedButtonIndex)
        -- button to click
        buttonIndex = #currentBossTable["enabled"] + #currentBossTable["disabled"]
    end
    
    -- update selectedButtonIndex
    -- selectedButtonIndex = buttonIndex
    -- reload
    if isGeneral then -- general
        ShowDebuffs(loadedInstance, buttonIndex)
    else
        ShowDebuffs(loadedBoss, buttonIndex)
    end
    -- notify debuff list changed
    Cell:Fire("RaidDebuffsChanged")
end)
enabledCB:SetPoint("TOPLEFT", spellIconBG, "BOTTOMLEFT", 0, -10)

-- track by id
local trackByIdCB = Cell:CreateCheckButton(detailsContentFrame, L["Track by ID"], function(checked)
    -- update db
    if not CellDB["raidDebuffs"][loadedInstance] then CellDB["raidDebuffs"][loadedInstance] = {} end
    local tIndex = isGeneral and "general" or loadedBoss
    if not CellDB["raidDebuffs"][loadedInstance][tIndex] then CellDB["raidDebuffs"][loadedInstance][tIndex] = {} end
    if not CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId] then
        CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId] = {selectedButtonIndex <= #currentBossTable["enabled"] and selectedButtonIndex or 0, checked}
    else
        CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][2] = checked
    end

    -- update loadedDebuffs
    local t = selectedButtonIndex <= #currentBossTable["enabled"] and currentBossTable["enabled"][selectedButtonIndex] or currentBossTable["disabled"][selectedButtonIndex-#currentBossTable["enabled"]]
    t["trackByID"] = checked

    -- notify debuff list changed
    Cell:Fire("RaidDebuffsChanged")
end)
trackByIdCB:SetPoint("TOPLEFT", enabledCB, "BOTTOMLEFT", 0, -10)

-- glow type
local glowTypeText = detailsContentFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
glowTypeText:SetText(L["Glow Type"])
glowTypeText:SetPoint("TOPLEFT", trackByIdCB, "BOTTOMLEFT", 0, -10)

-- glow
local LoadGlowOptions, LoadGlowCondition, ShowGlowPreview
local function UpdateGlowType(newType)
    local t = selectedButtonIndex <= #currentBossTable["enabled"] and currentBossTable["enabled"][selectedButtonIndex] or currentBossTable["disabled"][selectedButtonIndex-#currentBossTable["enabled"]]
    if t["glowType"] ~= newType then
        -- update db
        if not CellDB["raidDebuffs"][loadedInstance] then CellDB["raidDebuffs"][loadedInstance] = {} end
        local tIndex = isGeneral and "general" or loadedBoss
        if not CellDB["raidDebuffs"][loadedInstance][tIndex] then CellDB["raidDebuffs"][loadedInstance][tIndex] = {} end
        if not CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId] then
            if newType == "Normal" then
                CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId] = {t["order"], false, newType, {{0.95,0.95,0.32,1}}}
            elseif newType == "Pixel" then
                CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId] = {t["order"], false, newType, {{0.95,0.95,0.32,1}, 9, .25, 8, 2}}
            elseif newType == "Shine" then
                CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId] = {t["order"], false, newType, {{0.95,0.95,0.32,1}, 9, 0.5, 1}}
            end
        else
            CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][3] = newType
            if newType == "Normal" then
                if CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4] then
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][2] = nil
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][3] = nil
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][4] = nil
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][5] = nil
                else
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4] = {{0.95,0.95,0.32,1}}
                end
            elseif newType == "Pixel" then
                if CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4] then
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][2] = 9
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][3] = .25
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][4] = 8
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][5] = 2
                else
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4] = {{0.95,0.95,0.32,1}, 9, .25, 8, 2}
                end
            elseif newType == "Shine" then
                if CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4] then
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][2] = 9
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][3] = .5
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][4] = 1
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][5] = nil
                else
                    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4] = {{0.95,0.95,0.32,1}, 9, 0.5, 1}
                end
            end
        end
        -- update loadedDebuffs
        t["glowType"] = newType
        if newType == "Normal" then
            if t["glowOptions"] then
                t["glowOptions"][2] = nil
                t["glowOptions"][3] = nil
                t["glowOptions"][4] = nil
                t["glowOptions"][5] = nil
            else
                t["glowOptions"] = {{0.95,0.95,0.32,1}}
            end
        elseif newType == "Pixel" then
            if t["glowOptions"] then
                t["glowOptions"][2] = 9
                t["glowOptions"][3] = .25
                t["glowOptions"][4] = 8
                t["glowOptions"][5] = 2
            else
                t["glowOptions"] = {{0.95,0.95,0.32,1}, 9, .25, 8, 2}
            end
        elseif newType == "Shine" then
            if t["glowOptions"] then
                t["glowOptions"][2] = 9
                t["glowOptions"][3] = .5
                t["glowOptions"][4] = 1
                t["glowOptions"][5] = nil
            else
                t["glowOptions"] = {{0.95,0.95,0.32,1}, 9, 0.5, 1}
            end
        end
        LoadGlowOptions(newType, t["glowOptions"])
        -- notify debuff list changed
        Cell:Fire("RaidDebuffsChanged")
    end
end

local glowTypeDropdown = Cell:CreateDropdown(detailsContentFrame, 100)
glowTypeDropdown:SetPoint("TOPLEFT", glowTypeText, "BOTTOMLEFT", 0, -1)
glowTypeDropdown:SetItems({
    {
        ["text"] = L["None"],
        ["value"] = "None",
        ["onClick"] = function()
            local t = selectedButtonIndex <= #currentBossTable["enabled"] and currentBossTable["enabled"][selectedButtonIndex] or currentBossTable["disabled"][selectedButtonIndex-#currentBossTable["enabled"]]
            if t["glowType"] and t["glowType"] ~= "None" then -- exists in db
                -- update db
                local tIndex = isGeneral and "general" or loadedBoss
                CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][3] = "None"
                -- update loadedDebuffs
                t["glowType"] = "None"
                -- notify debuff list changed
                Cell:Fire("RaidDebuffsChanged")
                LoadGlowOptions()
            end
        end,
    },
    {
        ["text"] = L["Normal"],
        ["value"] = "Normal",
        ["onClick"] = function()
            UpdateGlowType("Normal")
        end,
    },
    {
        ["text"] = L["Pixel"],
        ["value"] = "Pixel",
        ["onClick"] = function()
            UpdateGlowType("Pixel")
        end,
    },
    {
        ["text"] = L["Shine"],
        ["value"] = "Shine",
        ["onClick"] = function()
            UpdateGlowType("Shine")
        end,
    },
})

-- preview
local previewButton = CreateFrame("Button", "RaidDebuffsPreviewButton", debuffsTab, "CellUnitButtonTemplate")
previewButton:SetPoint("TOPLEFT", debuffsTab, "TOPRIGHT", 5, -137)
previewButton:UnregisterAllEvents()
previewButton:SetScript("OnEnter", nil)
previewButton:SetScript("OnLeave", nil)
previewButton:SetScript("OnShow", nil)
previewButton:SetScript("OnHide", nil)
previewButton:SetScript("OnUpdate", nil)
previewButton:Hide()

local previewButtonBG = Cell:CreateFrame("RaidDebuffsPreviewButtonBG", previewButton)
previewButtonBG:SetPoint("TOPLEFT", previewButton, 0, 20)
previewButtonBG:SetPoint("BOTTOMRIGHT", previewButton, "TOPRIGHT")
previewButtonBG:SetFrameStrata("BACKGROUND")
Cell:StylizeFrame(previewButtonBG, {.1, .1, .1, .77}, {0, 0, 0, 0})
previewButtonBG:Show()

local previewText = previewButtonBG:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET_TITLE")
previewText:SetPoint("TOP", 0, -3)
previewText:SetText(Cell:GetPlayerClassColorString()..L["Preview"])

local function UpdatePreviewButton()
    if not previewButton.loaded then
        previewButton.loaded = true
    end

    local iTable = Cell.vars.currentLayoutTable["indicators"][1]
    if iTable["enabled"] then
        previewButton.indicators.nameText:Show()
        previewButton.state.name = UnitName("player")
        previewButton.indicators.nameText:UpdateName()
        previewButton.indicators.nameText:UpdatePreviewColor(iTable["nameColor"])
        previewButton.indicators.nameText:UpdateTextWidth(iTable["textWidth"])
        previewButton.indicators.nameText:SetFont(unpack(iTable["font"]))
        previewButton.indicators.nameText:ClearAllPoints()
        previewButton.indicators.nameText:SetPoint(unpack(iTable["position"]))
    else
        previewButton.indicators.nameText:Hide()
    end

    previewButton:SetSize(unpack(Cell.vars.currentLayoutTable["size"]))
    previewButton.func.SetPowerHeight(Cell.vars.currentLayoutTable["powerHeight"])

    previewButton.widget.healthBar:SetStatusBarTexture(Cell.vars.texture)
    previewButton.widget.powerBar:SetStatusBarTexture(Cell.vars.texture)

    local r, g, b
    -- health color
    if CellDB["appearance"]["barColor"][1] == "Class Color" then
        r, g, b = F:GetClassColor(Cell.vars.playerClass)
    elseif CellDB["appearance"]["barColor"][1] == "Class Color (dark)" then
        r, g, b = F:GetClassColor(Cell.vars.playerClass)
        r, g, b = r*.2, g*.2, b*.2
    else
        r, g, b = unpack(CellDB["appearance"]["barColor"][2])
    end
    previewButton.widget.healthBar:SetStatusBarColor(r, g, b)
    
    -- power color
    if CellDB["appearance"]["powerColor"][1] == "Class Color" then
        r, g, b = F:GetClassColor(Cell.vars.playerClass)
    elseif CellDB["appearance"]["powerColor"][1] == "Custom Color" then
        r, g, b = unpack(CellDB["appearance"]["powerColor"][2])
    else
        r, g, b = F:GetPowerColor("player")
    end
    previewButton.widget.powerBar:SetStatusBarColor(r, g, b)
end

previewButton.fadeIn = previewButton:CreateAnimationGroup()
local fadeIn = previewButton.fadeIn:CreateAnimation("alpha")
fadeIn:SetFromAlpha(0)
fadeIn:SetToAlpha(1)
fadeIn:SetDuration(.25)
fadeIn:SetSmoothing("OUT")

previewButton.fadeOut = previewButton:CreateAnimationGroup()
local fadeOut = previewButton.fadeOut:CreateAnimation("alpha")
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0)
fadeOut:SetDuration(0.25)
fadeOut:SetSmoothing("IN")
fadeOut:SetScript("OnPlay", function()
    if previewButton.fadeIn:IsPlaying() then
        previewButton.fadeIn:Stop()
    end        
end)
previewButton.fadeOut:SetScript("OnFinished", function()
    previewButton:Hide()
end)

ShowGlowPreview = function(glowType, glowOptions, refresh)
    if not glowType or glowType == "None" then
        LCG.ButtonGlow_Stop(previewButton)
        LCG.PixelGlow_Stop(previewButton)
        LCG.AutoCastGlow_Stop(previewButton)
        if previewButton:IsShown() then previewButton.fadeOut:Play() end
        return
    end

    if previewButton.fadeOut:IsPlaying() then
        previewButton.fadeOut:Stop()
    end
    if previewButton:IsShown() then
        if glowType == "Normal" then
            LCG.PixelGlow_Stop(previewButton)
            LCG.AutoCastGlow_Stop(previewButton)
            LCG.ButtonGlow_Start(previewButton, glowOptions[1])
        elseif glowType == "Pixel" then
            LCG.ButtonGlow_Stop(previewButton)
            LCG.AutoCastGlow_Stop(previewButton)
            -- color, N, frequency, length, thickness
            LCG.PixelGlow_Start(previewButton, glowOptions[1], glowOptions[2], glowOptions[3], glowOptions[4], glowOptions[5])
        elseif glowType == "Shine" then
            LCG.ButtonGlow_Stop(previewButton)
            LCG.PixelGlow_Stop(previewButton)
            if refresh then LCG.AutoCastGlow_Stop(previewButton) end
            -- color, N, frequency, scale
            LCG.AutoCastGlow_Start(previewButton, glowOptions[1], glowOptions[2], glowOptions[3], glowOptions[4])
        end
    else
        previewButton.fadeIn:SetScript("OnFinished", function()
            if glowType == "Normal" then
                LCG.PixelGlow_Stop(previewButton)
                LCG.AutoCastGlow_Stop(previewButton)
                LCG.ButtonGlow_Start(previewButton, glowOptions[1])
            elseif glowType == "Pixel" then
                LCG.ButtonGlow_Stop(previewButton)
                LCG.AutoCastGlow_Stop(previewButton)
                -- color, N, frequency, length, thickness
                LCG.PixelGlow_Start(previewButton, glowOptions[1], glowOptions[2], glowOptions[3], glowOptions[4], glowOptions[5])
            elseif glowType == "Shine" then
                LCG.ButtonGlow_Stop(previewButton)
                LCG.PixelGlow_Stop(previewButton)
                -- color, N, frequency, scale
                LCG.AutoCastGlow_Start(previewButton, glowOptions[1], glowOptions[2], glowOptions[3], glowOptions[4])
            end
        end)
        previewButton:Show()
        previewButton.fadeIn:Play()
    end
end

-- glow options
local glowOptionsFrame = CreateFrame("Frame", nil, detailsContentFrame)
glowOptionsFrame:SetPoint("TOPLEFT", glowTypeDropdown, "BOTTOMLEFT", -5, -10)
glowOptionsFrame:SetPoint("BOTTOMRIGHT")

-- glowCondition
local glowConditionText = glowOptionsFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
glowConditionText:SetText(L["Glow Condition"])
glowConditionText:SetPoint("TOPLEFT", glowOptionsFrame, 5, 0)

local glowConditionType = Cell:CreateDropdown(glowOptionsFrame, 100)
glowConditionType:SetPoint("TOPLEFT", glowConditionText, "BOTTOMLEFT", 0, -1)
glowConditionType:SetItems({
    {
        ["text"] = L["None"],
        ["value"] = "None",
        ["onClick"] = function()
            LoadGlowCondition()
            -- update db
            local tIndex = isGeneral and "general" or loadedBoss
            CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][5] = nil
            -- update loadedDebuffs
            local t = selectedButtonIndex <= #currentBossTable["enabled"] and currentBossTable["enabled"][selectedButtonIndex] or currentBossTable["disabled"][selectedButtonIndex-#currentBossTable["enabled"]]
            t["glowCondition"] = nil
            -- notify debuff list changed
            Cell:Fire("RaidDebuffsChanged")
        end,
    },
    {
        ["text"] = L["Stack"],
        ["value"] = "Stack",
        ["onClick"] = function()
            LoadGlowCondition({"Stack", ">=", 0})
            -- update db
            local tIndex = isGeneral and "general" or loadedBoss
            CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][5] = {"Stack", ">=", 0}
            -- update loadedDebuffs
            local t = selectedButtonIndex <= #currentBossTable["enabled"] and currentBossTable["enabled"][selectedButtonIndex] or currentBossTable["disabled"][selectedButtonIndex-#currentBossTable["enabled"]]
            t["glowCondition"] = {"Stack", ">=", 0}
            -- notify debuff list changed
            Cell:Fire("RaidDebuffsChanged")
        end,
    },
})

local glowConditionOperator = Cell:CreateDropdown(glowOptionsFrame, 50)
glowConditionOperator:SetPoint("TOPLEFT", glowConditionType, "BOTTOMLEFT", 0, -5)

do
    local operators = {"=", ">", ">=", "<", "<=", "!="}
    local items = {}
    for _, opr in pairs(operators) do
        tinsert(items, {
            ["text"] = opr,
            ["onClick"] = function()
                -- update db
                local tIndex = isGeneral and "general" or loadedBoss
                CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][5][2] = opr
                -- update loadedDebuffs
                local t = selectedButtonIndex <= #currentBossTable["enabled"] and currentBossTable["enabled"][selectedButtonIndex] or currentBossTable["disabled"][selectedButtonIndex-#currentBossTable["enabled"]]
                t["glowCondition"][2] = opr
                -- notify debuff list changed
                Cell:Fire("RaidDebuffsChanged")
            end,
        })
    end
    glowConditionOperator:SetItems(items)
end

local glowConditionValue = Cell:CreateEditBox(glowOptionsFrame, 45, 20, nil, nil, true)
glowConditionValue:SetPoint("LEFT", glowConditionOperator, "RIGHT", 5, 0)
glowConditionValue:SetMaxLetters(3)
glowConditionValue:SetJustifyH("RIGHT")
glowConditionValue:SetScript("OnTextChanged", function(self, userChanged)
    if userChanged then
        local value = tonumber(self:GetText()) or 0
        -- update db
        local tIndex = isGeneral and "general" or loadedBoss
        CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][5][3] = value
        -- update loadedDebuffs
        local t = selectedButtonIndex <= #currentBossTable["enabled"] and currentBossTable["enabled"][selectedButtonIndex] or currentBossTable["disabled"][selectedButtonIndex-#currentBossTable["enabled"]]
        t["glowCondition"][3] = value
        -- notify debuff list changed
        Cell:Fire("RaidDebuffsChanged")
    end
end)

-- glowColor
local glowColor = Cell:CreateColorPicker(glowOptionsFrame, L["Glow Color"], false, function(r, g, b)
    local t = selectedButtonIndex <= #currentBossTable["enabled"] and currentBossTable["enabled"][selectedButtonIndex] or currentBossTable["disabled"][selectedButtonIndex-#currentBossTable["enabled"]]
    -- update db
    local tIndex = isGeneral and "general" or loadedBoss
    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][1][1] = r
    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][1][2] = g
    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][1][3] = b
    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][1][4] = 1
    -- update loadedDebuffs
    t["glowOptions"][1][1] = r
    t["glowOptions"][1][2] = g
    t["glowOptions"][1][3] = b
    t["glowOptions"][1][4] = 1
    -- notify debuff list changed
    Cell:Fire("RaidDebuffsChanged")
    -- update preview
    ShowGlowPreview(t["glowType"], t["glowOptions"])
end)
-- glowColor:SetPoint("TOPLEFT", glowOptionsFrame, 5, 0)
glowColor:SetPoint("TOPLEFT", glowConditionOperator, "BOTTOMLEFT", 0, -10)

local function SliderValueChanged(index, value, refresh)
    local t = selectedButtonIndex <= #currentBossTable["enabled"] and currentBossTable["enabled"][selectedButtonIndex] or currentBossTable["disabled"][selectedButtonIndex-#currentBossTable["enabled"]]
    -- update db
    local tIndex = isGeneral and "general" or loadedBoss
    CellDB["raidDebuffs"][loadedInstance][tIndex][selectedSpellId][4][index] = value
    -- update loadedDebuffs
    t["glowOptions"][index] = value
    -- notify debuff list changed
    Cell:Fire("RaidDebuffsChanged")
    -- update preview
    ShowGlowPreview(t["glowType"], t["glowOptions"], refresh)
end

-- glowNumber
local glowLines = Cell:CreateSlider(L["Lines"], glowOptionsFrame, 1, 30, 100, 1, function(value)
    SliderValueChanged(2, value)
end)
glowLines:SetPoint("TOPLEFT", glowColor, "BOTTOMLEFT", 0, -25)

local glowParticles = Cell:CreateSlider(L["Particles"], glowOptionsFrame, 1, 30, 100, 1, function(value)
    SliderValueChanged(2, value, true)
end)
glowParticles:SetPoint("TOPLEFT", glowColor, "BOTTOMLEFT", 0, -25)

-- glowFrequency
local glowFrequency = Cell:CreateSlider(L["Frequency"], glowOptionsFrame, -2, 2, 100, .05, function(value)
    SliderValueChanged(3, value)
end)
glowFrequency:SetPoint("TOPLEFT", glowLines, "BOTTOMLEFT", 0, -40)

-- glowLength
local glowLength = Cell:CreateSlider(L["Length"], glowOptionsFrame, 1, 20, 100, 1, function(value)
    SliderValueChanged(4, value)
end)
glowLength:SetPoint("TOPLEFT", glowFrequency, "BOTTOMLEFT", 0, -40)

-- glowThickness
local glowThickness = Cell:CreateSlider(L["Thickness"], glowOptionsFrame, 1, 20, 100, 1, function(value)
    SliderValueChanged(5, value)
end)
glowThickness:SetPoint("TOPLEFT", glowLength, "BOTTOMLEFT", 0, -40)

-- glowScale
local glowScale = Cell:CreateSlider(L["Scale"], glowOptionsFrame, 50, 500, 100, 1, function(value)
    SliderValueChanged(4, value/100)
end, nil, true)
glowScale:SetPoint("TOPLEFT", glowFrequency, "BOTTOMLEFT", 0, -40)

local glowOptionsHeight, glowConditionHeight = 0, 0
LoadGlowOptions = function(glowType, glowOptions)
    if not glowType or glowType == "None" or not glowOptions then
        glowOptionsFrame:Hide()
        ShowGlowPreview("None")
        detailsFrame.scrollFrame:SetContentHeight(133)
        detailsFrame.scrollFrame:ResetScroll()
        return
    end

    ShowGlowPreview(glowType, glowOptions)
    glowColor:SetColor(glowOptions[1])

    if glowType == "Normal" then
        glowLines:Hide()
        glowParticles:Hide()
        glowFrequency:Hide()
        glowLength:Hide()
        glowThickness:Hide()
        glowScale:Hide()
        glowOptionsHeight = 30
    elseif glowType == "Pixel" then
        glowLines:Show()
        glowFrequency:Show()
        glowLength:Show()
        glowThickness:Show()
        glowParticles:Hide()
        glowScale:Hide()
        glowLines:SetValue(glowOptions[2])
        glowFrequency:SetValue(glowOptions[3])
        glowLength:SetValue(glowOptions[4])
        glowThickness:SetValue(glowOptions[5])
        glowOptionsHeight = 235
    elseif glowType == "Shine" then
        glowParticles:Show()
        glowFrequency:Show()
        glowScale:Show()
        glowLines:Hide()
        glowLength:Hide()
        glowThickness:Hide()
        glowParticles:SetValue(glowOptions[2])
        glowFrequency:SetValue(glowOptions[3])
        glowScale:SetValue(glowOptions[4]*100)
        glowOptionsHeight = 175
    end

    glowOptionsFrame:Show()

    detailsFrame.scrollFrame:SetContentHeight(133+glowOptionsHeight+glowConditionHeight)
    detailsFrame.scrollFrame:ResetScroll()
end

LoadGlowCondition = function(glowCondition)
    if type(glowCondition) == "table" then
        glowConditionOperator:Show()
        glowConditionValue:Show()
        glowConditionType:SetSelected(L[glowCondition[1]])
        glowConditionOperator:SetSelected(glowCondition[2])
        glowConditionValue:SetText(glowCondition[3])
        glowColor:ClearAllPoints()
        glowColor:SetPoint("TOPLEFT", glowConditionOperator, "BOTTOMLEFT", 0, -10)
        glowConditionHeight = 65
    else
        glowConditionType:SetSelected(L["None"])
        glowConditionOperator:Hide()
        glowConditionValue:Hide()
        glowColor:ClearAllPoints()
        glowColor:SetPoint("TOPLEFT", glowConditionType, "BOTTOMLEFT", 0, -10)
        glowConditionHeight = 40
    end
    detailsFrame.scrollFrame:SetContentHeight(133+glowOptionsHeight+glowConditionHeight)
    detailsFrame.scrollFrame:ResetScroll()
end

-- spell description
-- Cell:CreateScrollFrame(detailsContentFrame, -270, 0) -- spell description
-- local descText = detailsContentFrame.scrollFrame.content:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
-- descText:SetPoint("TOPLEFT", 5, -1)
-- descText:SetPoint("RIGHT", -5, 0)
-- descText:SetJustifyH("LEFT")
-- descText:SetSpacing(2)

-- local function SetSpellDesc(desc)
--     descText:SetText(desc)
--     detailsContentFrame.scrollFrame:SetContentHeight(descText:GetStringHeight()+2)
-- end

local timer
ShowDetails = function(spell)
    local spellId, buttonIndex = F:SplitToNumber("-", spell)
    
    if selectedSpellId == spellId then return end
    selectedSpellId, selectedButtonIndex = spellId, buttonIndex
    
    -- local name, icon, desc = F:GetSpellInfo(spellId)
    local name, _, icon = GetSpellInfo(spellId)
    if not name then return end

    detailsFrame.scrollFrame:ResetScroll()
    detailsFrame.scrollFrame:Show()
    
    selectedSpellIcon = icon
    selectedSpellName = name

    spellIcon:SetTexture(icon)
    spellNameText:SetText(name)
    spellIdText:SetText(spellId)
    -- SetSpellDesc(desc)
    -- -- to ensure desc
    -- if timer then timer:Cancel() end
    -- timer = C_Timer.NewTimer(.7, function()
    --     SetSpellDesc(select(3, F:GetSpellInfo(spellId)))
    -- end)
    
    local isEnabled = selectedButtonIndex <= #currentBossTable["enabled"]
    enabledCB:SetChecked(isEnabled)
    
    local spellTable
    if isEnabled then
        spellTable = currentBossTable["enabled"][buttonIndex]
    else
        spellTable = currentBossTable["disabled"][buttonIndex-#currentBossTable["enabled"]]
    end
    trackByIdCB:SetChecked(spellTable["trackByID"])
    
    local glowType = spellTable["glowType"] or "None"
    glowTypeDropdown:SetSelected(L[glowType])

    if glowType == "None" then
        LoadGlowOptions()
        LoadGlowCondition()
    else
        LoadGlowOptions(glowType, spellTable["glowOptions"])
        LoadGlowCondition(spellTable["glowCondition"])
    end

    -- check deletion
    if isEnabled then
        delete:SetEnabled(not currentBossTable["enabled"][buttonIndex]["built-in"])
    else -- disabled
        delete:SetEnabled(not currentBossTable["disabled"][buttonIndex-#currentBossTable["enabled"]]["built-in"])
    end
end

-------------------------------------------------
-- open encounter journal -- from grid2
-------------------------------------------------
OpenEncounterJournal = function(instanceId)
    if not IsAddOnLoaded("Blizzard_EncounterJournal") then LoadAddOn("Blizzard_EncounterJournal") end
    
	local difficulty
	if IsInInstance() then
		difficulty = select(3,GetInstanceInfo())
	else
		difficulty = 14
    end

	ShowUIPanel(EncounterJournal)
	EJ_ContentTab_Select(EncounterJournal.instanceSelect.dungeonsTab.id)
	EncounterJournal_DisplayInstance(instanceId)
    EncounterJournal.lastInstance = instanceId
    
	if not EJ_IsValidInstanceDifficulty(difficulty) then
		difficulty = (difficulty==14 and 1) or (difficulty==15 and 2) or (difficulty==16 and 23) or (difficulty==17 and 7) or 0
		if not EJ_IsValidInstanceDifficulty(difficulty) then
			return
		end
	end
	EJ_SetDifficulty(difficulty)
	EncounterJournal.lastDifficulty = difficulty
end


-------------------------------------------------
-- functions
-------------------------------------------------
function F:GetDebuffList(instanceName)
    local list = {}
    local eName, iIndex, iId = F:SplitToNumber(":", instanceIds[instanceName])
    
    if iId and loadedDebuffs[iId] then
        local n = 0
        -- check general
        if loadedDebuffs[iId]["general"] then
            n = #loadedDebuffs[iId]["general"]["enabled"]
            for _, t in ipairs(loadedDebuffs[iId]["general"]["enabled"]) do
                local spellName = GetSpellInfo(t["id"])
                if spellName then
                    -- list[spellName/spellId] = {order, glowType, glowOptions}
                    if t["trackByID"] then
                        list[t["id"]] = {["order"]=t["order"], ["glowType"]=t["glowType"], ["glowOptions"]=t["glowOptions"], ["glowCondition"]=t["glowCondition"]}
                    else
                        list[spellName] = {["order"]=t["order"], ["glowType"]=t["glowType"], ["glowOptions"]=t["glowOptions"], ["glowCondition"]=t["glowCondition"]}
                    end
                end
            end
        end
        -- check boss
        for bId, bTable in pairs(loadedDebuffs[iId]) do
            if bId ~= "general" then
                for _, st in pairs(bTable["enabled"]) do
                    local spellName = GetSpellInfo(st["id"])
                    if spellName then -- check again
                        if st["trackByID"] then
                            list[st["id"]] = {["order"]=st["order"], ["glowType"]=st["glowType"], ["glowOptions"]=st["glowOptions"], ["glowCondition"]=st["glowCondition"]}
                        else
                            list[spellName] = {["order"]=st["order"]+n, ["glowType"]=st["glowType"], ["glowOptions"]=st["glowOptions"], ["glowCondition"]=st["glowCondition"]}
                        end
                    end
                end
            end
        end
    end
    -- texplore(list)

    return list
end

-------------------------------------------------
-- show
-------------------------------------------------
local function ShowTab(tab)
    if tab == "debuffs" then
        debuffsTab:Show()
        UpdatePreviewButton()
        
        if not loadedExpansion then
            expansionDropdown:SetSelectedItem(1)
            LoadExpansion(newestExpansion)
        end
    else
        debuffsTab:Hide()
    end
end
Cell:RegisterCallback("ShowOptionsTab", "RaidDebuffsTab_ShowTab", ShowTab)

local function UpdateLayout()
    if previewButton.loaded then
        UpdatePreviewButton()
    end
end
Cell:RegisterCallback("UpdateLayout", "RaidDebuffsTab_UpdateLayout", UpdateLayout)

local function UpdateAppearance()
    if previewButton.loaded then
        UpdatePreviewButton()
    end
end
Cell:RegisterCallback("UpdateAppearance", "RaidDebuffsTab_UpdateAppearance", UpdateAppearance)

local function UpdateIndicators(layout, indicatorName, setting, value)
    if previewButton.loaded then
        if not layout or indicatorName == "nameText" then
            UpdatePreviewButton()
        end
    end
end
Cell:RegisterCallback("UpdateIndicators", "RaidDebuffsTab_UpdateIndicators", UpdateIndicators)
