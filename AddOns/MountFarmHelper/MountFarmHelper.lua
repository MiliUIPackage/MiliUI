local addonName, addon = ...

LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0', 'AceTimer-3.0')

local L = LibStub('AceLocale-3.0'):GetLocale(addonName)
local LBB = LibStub('LibBabble-Boss-3.0'):GetUnstrictLookupTable()
local LBZ = LibStub('LibBabble-SubZone-3.0'):GetUnstrictLookupTable()

local qtip = LibStub('LibQTip-1.0')

local TOOLTIP_SEPARATOR     = { 1, 1, 1, 1, 0.5 }

local COLOR_DUNGEON         = { 1, 1, 0, 1 }
local COLOR_CURRENT_ZONE    = { 0, 1, 0, 1 }
local COLOR_COMMENT         = { 0, 1, 0, 1 }

local COLOR_ITEM_TOOLTIP            = { 1, 1, 1 }
local COLOR_ITEM_TOOLTIP_SOURCE     = { 1, 1, 0 }
local COLOR_ITEM_TOOLTIP_SOURCE_2L  = { 1, 1, 0, 0, 1, 0 }

function addon:OnInitialize()
    self.db = LibStub('AceDB-3.0'):New(addonName .. 'DB', {
        profile = {
            hide_normal = false,
            hide_raid = false,
            hide_world = false,
            hide_quest = false,

            minimap = {
                hide = false,
            },
        },
    }, true)

    self.ldb = LibStub('LibDataBroker-1.1'):NewDataObject(addonName, {
        type = 'launcher',
        icon = 'Interface\\ICONS\\ABILITY_MOUNT_GOLDENGRYPHON',
        label = "Mount Farm Helper",
        OnEnter = function(...)
            self:ShowTooltip(...)
        end,
        OnLeave = function()
        end,
        OnClick = function(obj, button)
            if button == 'RightButton' then
                InterfaceOptionsFrame_OpenToCategory(addonName)
            elseif self.ac then
                if AltCraftFrame:IsShown() and AltCraftMFHTabFrame:IsShown() then
                    AltCraftFrame:Hide()
                else
                    AltCraftFrame:Show()
                    AltCraftFrame:OnSelectTab(self.acTabNum)
                end
            end
        end,
    })

    self.icon = LibStub('LibDBIcon-1.0')
    self.icon:Register(addonName, self.ldb, self.db.profile.minimap)

    self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED', function(...)
        addon:OnCombatEvent(...)
    end)

    self:RegisterEvent('PLAYER_LOGIN', function(...)
        if not MountJournal_OnLoad then
            UIParentLoadAddOn('Blizzard_Collections')
        end
    end)

    GameTooltip:HookScript('OnTooltipCleared', function(self)
        addon:OnGameTooltipCleared(self)
    end)

    GameTooltip:HookScript('OnTooltipSetItem', function(self)
        addon:OnGameTooltipSetItem(self)
    end)

    LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName, self:GetOptions())
    LibStub('AceConfigDialog-3.0'):AddToBlizOptions(addonName, addonName, nil)

    self.trackNpc = {}

    local itemId, itemData
    for itemId, itemData in pairs(MFH_DB_MOUNTS) do
        GetItemInfo(itemId)

        local itemSource
        for _, itemSource in pairs(itemData.from) do
            if itemSource.npc_id then
                self:GetNpcName(itemSource.npc_id)

                if itemSource.type == 'raid' or (itemSource.type == 'dungeon' and itemSource.subtype) and not itemSource.dont_autoupdate then
                    self.trackNpc[itemSource.npc_id] = 1
                end
            end
        end
    end

    self:ScheduleTimer(function()
        self.ac = LibStub('AceAddon-3.0'):GetAddon('AltCraft', true)
        if self.ac then
            self.acTabNum = AltCraftFrame:AddTab(AltCraftMFHTabFrame, 'Mount Farm Helper')
        end
    end, 0.5)
end

function addon:GetNpcName(npcId)
    local tooltip = self.scanTooltip

    if not tooltip then
        tooltip = CreateFrame('GameTooltip', 'MFH_SCAN_TOOLTIP', UIParent, 'GameTooltipTemplate')
        self.scanTooltip = tooltip
    end

    tooltip:SetOwner(UIParent, 'ANCHOR_NONE')
    tooltip:SetHyperlink(string.format('unit:Creature-0-0-0-0-%d:0000000000', npcId))

    local npcName = _G[tooltip:GetName() .. 'TextLeft1']:GetText()

    if not npcName then
        if MFH_DB_BOSSES[npcId] and MFH_DB_BOSSES[npcId].name then
            npcName = LBB[MFH_DB_BOSSES[npcId].name] or MFH_DB_BOSSES[npcId].name
        else
            npcName = string.format('npc#%d', npcId)
        end
    end

    return npcName
end

function addon:OnCombatEvent(event, timeStamp, logEvent, hideCaster,
    sourceGuid, sourceName, sourceFlags, sourceFlags2,
    destGuid, destName, destFlags, destFlags2, ...
)
    if destGuid then
        local type, id = UnitInfoFromGuid(destGuid)

        if type == 'Creature' or type == 'Vehicle' then
            if (logEvent == 'UNIT_DIED' or logEvent == 'PARTY_KILL') and self.trackNpc[id] then
                RequestRaidInfo()

                self:ScheduleTimer(function()
                    RequestRaidInfo()
                end, 5)
            end
        end
    end
end

function addon:ShowTooltip(anchor)
    if not (InCombatLockdown() or (self.tooltip and self.tooltip:IsShown())) then
        if not (qtip:IsAcquired(addonName) and self.tooltip) then
            self.tooltip = qtip:Acquire(addonName, 5, 'LEFT', 'LEFT', 'LEFT', 'RIGHT')

            self.tooltip.OnRelease = function()
                self.tooltip = nil
            end
        end

        if anchor then
            self.tooltip:SmartAnchorTo(anchor)
            self.tooltip:SetAutoHideDelay(0.05, anchor)
        end

        self:UpdateTooltip(self.tooltip)
    end
end

function addon:GetItemSourceInfo(itemSource)
    local zoneName = GetMapNameByID(itemSource.zone_id)

    local npcName
    if itemSource.type == 'special' then
        npcName = L['special_' .. itemSource.subtype]
    else
        npcName = self:GetNpcName(itemSource.npc_id)
    end

    local comment
    if itemSource.subtype and itemSource.type ~= 'special' then
        comment = L['type_' .. itemSource.subtype]
    end
    if itemSource.cond then
        comment = (comment and (comment .. ' + ') or '') .. L['cond_' .. itemSource.cond]
    end

    local raidSaveZone = MFH_DB_ZONES[itemSource.zone_id] and MFH_DB_ZONES[itemSource.zone_id].raid and LBZ[MFH_DB_ZONES[itemSource.zone_id].raid] or zoneName
    local raidSaveBoss = MFH_DB_BOSSES[itemSource.npc_id] and MFH_DB_BOSSES[itemSource.npc_id].raid and LBB[MFH_DB_BOSSES[itemSource.npc_id].raid] or npcName

    return zoneName, npcName, comment, raidSaveZone, raidSaveBoss
end

function addon:GetPlayerItems()
    local playerItems, mountIds = {}, {}

    local allMounts = C_MountJournal.GetMountIDs()

    local mountId
    for _, mountId in pairs(allMounts) do
        local _, spellId, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountId)

        mountIds[spellId] = mountId

        if isCollected then
            playerItems[spellId] = 1
        end
    end

    return playerItems, mountIds
end

function addon:BuildTooltipData()
    local i, j

    local playerItems, mountIds = self:GetPlayerItems()

    local savedRaids = {}
    for i = 1, GetNumSavedInstances() do
        local raidName, _, _, _, locked, extended, _, _, _, _, numBosses = GetSavedInstanceInfo(i)
        if locked and not extended then
            savedRaids[raidName] = {}

            local numRemains = 0

            for j = 1, numBosses do
                local bossName, _, killed = GetSavedInstanceEncounterInfo(i, j)
                if killed then
                    savedRaids[raidName][bossName] = 1
                else
                    numRemains = numRemains + 1
                end
            end

            if numRemains < 1 then
                savedRaids[raidName] = 1
            end
        end
    end

    local playerFaction = string.lower(UnitFactionGroup('player'))
    local playerLevel = UnitLevel('player')
    local playerZoneName = GetRealZoneText()

    local normalItems, raidItems, worldItems, questItems = {}, {}, {}, {}

    local itemId, itemData
    for itemId, itemData in pairs(MFH_DB_MOUNTS) do
        if not playerItems[itemData.spell_id] and (not itemData.faction or itemData.faction == playerFaction) then
            local itemName, itemLink = GetItemInfo(itemId)
            local dispName = (itemLink and itemLink:gsub('%[', ''):gsub('%]', ''):sub(1)) or itemName or string.format('item#%d', itemId)

            local itemSource
            for _, itemSource in pairs(itemData.from) do
                if not itemSource.faction or itemSource.faction == playerFaction then
                    if itemSource.level <= playerLevel then
                        local zoneName, npcName, comment, raidSaveZone, raidSaveBoss = self:GetItemSourceInfo(itemSource)

                        local add
                        if itemSource.type == 'dungeon' and not itemSource.subtype then
                            add = 1
                        elseif itemSource.type == 'dungeon' or itemSource.type == 'raid' then
                            add = not(savedRaids[raidSaveZone] and (type(savedRaids[raidSaveZone]) ~= 'table' or savedRaids[raidSaveZone][raidSaveBoss]))
                        elseif itemSource.quest_id then
                            add = not IsQuestFlaggedCompleted(itemSource.quest_id)
                        end

                        if add then
                            local zoneData = {
                                items = {}, sort = itemSource.for_sort,
                                isCurrent = playerZoneName == (MFH_DB_ZONES[itemSource.zone_id] and MFH_DB_ZONES[itemSource.zone_id].map and LBZ[MFH_DB_ZONES[itemSource.zone_id].map] or zoneName),
                            }

                            if itemSource.type == 'dungeon' and not itemSource.subtype then
                                if normalItems[zoneName] then
                                    zoneData = normalItems[zoneName]
                                else
                                    normalItems[zoneName] = zoneData
                                end
                            elseif itemSource.type == 'dungeon' or itemSource.type == 'raid' then
                                if raidItems[zoneName] then
                                    zoneData = raidItems[zoneName]
                                else
                                    raidItems[zoneName] = zoneData
                                end
                            elseif itemSource.type == 'world' then
                                if worldItems[zoneName] then
                                    zoneData = worldItems[zoneName]
                                else
                                    worldItems[zoneName] = zoneData
                                end
                            else
                                if questItems[zoneName] then
                                    zoneData = questItems[zoneName]
                                else
                                    questItems[zoneName] = zoneData
                                end
                            end

                            zoneData.sort = min(zoneData.sort, itemSource.for_sort)

                            local npcData = zoneData.items[npcName] or { items = {}, sort = itemSource.for_sort }
                            zoneData.items[npcName] = npcData

                            npcData.sort = min(zoneData.sort, itemSource.for_sort)

                            table.insert(npcData.items, { name = dispName, spellId = itemData.spell_id, mountId = mountIds[itemData.spell_id], comment = comment })
                        end
                    end
                end
            end
        end
    end

    return {
        { items = normalItems, title = 'normal' },
        { items = raidItems  , title = 'raid'   },
        { items = worldItems , title = 'world'  },
        { items = questItems , title = 'quest'  },
    }
end

function addon:BuildAltCraftList()
    local list, added = {}, {}

    local playerItems, mountIds = self:GetPlayerItems()
    local playerFaction = string.lower(UnitFactionGroup('player'))

    local itemId, itemData
    for itemId, itemData in pairs(MFH_DB_MOUNTS) do
        if not playerItems[itemData.spell_id] and (not itemData.faction or itemData.faction == playerFaction) then
            local name, link, icon = table.s2k_select({ GetItemInfo(itemId) }, 1, 2, 10 )

            local itemSource
            for _, itemSource in pairs(itemData.from) do
                if not itemSource.faction or itemSource.faction == playerFaction then
                    local zoneName, npcName, comment = self:GetItemSourceInfo(itemSource)

                    if added[itemId] then
                        table.insert(added[itemId].sources, {
                            zone    = zoneName,
                            source  = npcName,
                            comment = comment,
                            sort    = itemSource.for_sort,
                        })

                        table.sort(added[itemId].sources, function(a, b) return a.sort < b.sort end)

                        added[itemId].sort = added[itemId].sources[1].sort
                    else
                        added[itemId] = {
                            itemId      = itemId,
                            name        = name,
                            link        = link,
                            icon        = icon,
                            sort        = itemSource.for_sort,
                            sources     = {{
                                zone        = zoneName,
                                source      = npcName,
                                comment     = comment,
                                sort        = itemSource.for_sort,
                            }},
                        }

                        table.insert(list, added[itemId])
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.sort < b.sort end)

    return list
end

function addon:UpdateTooltip(tooltip)
    tooltip:Clear()

    local lineNo, itemTable

    for _, itemTable in pairs(self:BuildTooltipData()) do
        if not table.s2k_is_empty(itemTable.items) then
            if lineNo then
                tooltip:AddSeparator(unpack(TOOLTIP_SEPARATOR))
            end

            if self.db.profile['hide_' .. itemTable.title] then
                lineNo = tooltip:AddLine()
                tooltip:SetCell(lineNo, 1, '|TInterface\\Buttons\\UI-PlusButton-Up:16|t' .. L['title_' .. itemTable.title], nil, nil, 4)

                tooltip:SetLineScript(lineNo, 'OnMouseUp', function()
                    self.db.profile['hide_' .. itemTable.title] = false
                    self:UpdateTooltip(tooltip)
                end)
            else
                lineNo = tooltip:AddLine()
                tooltip:SetCell(lineNo, 1, '|TInterface\\Buttons\\UI-MinusButton-Up:16|t' .. L['title_' .. itemTable.title], nil, nil, 4)

                tooltip:SetLineScript(lineNo, 'OnMouseUp', function()
                    self.db.profile['hide_' .. itemTable.title] = true
                    self:UpdateTooltip(tooltip)
                end)

                local firstSorted, firstName = {}

                for firstName in pairs(itemTable.items) do
                    table.insert(firstSorted, firstName)
                end

                table.sort(firstSorted, function(a, b)
                    if itemTable.items[a].isCurrent then
                        if itemTable.items[b].isCurrent then
                            return itemTable.items[a].sort < itemTable.items[b].sort
                        end
                        return true
                    end
                    if itemTable.items[b].isCurrent then
                        return false
                    end
                    return itemTable.items[a].sort < itemTable.items[b].sort
                end)

                for _, firstName in pairs(firstSorted) do
                    local firstData = itemTable.items[firstName]
                    local zoneColor = firstData.isCurrent and COLOR_CURRENT_ZONE or COLOR_DUNGEON

                    local secondSorted, secondName, titlePrinted = {}

                    for secondName in pairs(firstData.items) do
                        table.insert(secondSorted, secondName)
                    end

                    table.sort(secondSorted, function(a, b)
                        return firstData.items[a].sort < firstData.items[b].sort
                    end)

                    for _, secondName in pairs(secondSorted) do
                        local secondData = firstData.items[secondName]

                        if table.s2k_len(firstData.items) == 1 then
                            lineNo = tooltip:AddLine()

                            tooltip:SetCell(lineNo, 1, string.format('%s / %s', firstName, secondName), nil, nil, 4)
                            tooltip:SetCellTextColor(lineNo, 1, unpack(zoneColor))
                        else
                            if not titlePrinted then
                                lineNo = tooltip:AddLine()

                                tooltip:SetCell(lineNo, 1, firstName, nil, nil, 4)
                                tooltip:SetCellTextColor(lineNo, 1, unpack(zoneColor))

                                titlePrinted = 1
                            end

                            lineNo = tooltip:AddLine()

                            tooltip:SetCell(lineNo, 2, secondName, nil, nil, 3)
                            tooltip:SetCellTextColor(lineNo, 2, unpack(zoneColor))
                        end

                        local itemData
                        for _, itemData in pairs(secondData.items) do
                            lineNo = tooltip:AddLine()

                            if itemData.comment then
                                tooltip:SetCell(lineNo, 3, string.format("%-40s", itemData.name))

                                tooltip:SetCell(lineNo, 4, itemData.comment)
                                tooltip:SetCellTextColor(lineNo, 4, unpack(COLOR_COMMENT))
                            else
                                tooltip:SetCell(lineNo, 3, string.format("%-40s", itemData.name), nil, nil, 2)
                            end

                            if itemData.mountId then
                                tooltip:SetLineScript(lineNo, 'OnMouseUp', function()
                                    self:OpenMountJournal(itemData.mountId, itemData.spellId)
                                end)
                            end
                        end
                    end
                end
            end
        end
    end

    tooltip:AddLine("")

    tooltip:UpdateScrolling()
    tooltip:Show()
end

function addon:OpenMountJournal(mountId, spellId)
    if not CollectionsJournal:IsShown() then
        ToggleCollectionsJournal()
    end

    CollectionsJournal_SetTab(CollectionsJournal, 1)

    if mountId then
        MountJournal.selectedMountID = mountId
        MountJournal.selectedSpellID = spellId

        MountJournal_HideMountDropdown()
        MountJournal_UpdateMountList()
        MountJournal_UpdateMountDisplay()
    else
        MountJournal_Select(1)
    end
end

function addon:OnGameTooltipCleared(tooltip)
end

function addon:OnGameTooltipSetItem(tooltip)
    local link = select(2, tooltip:GetItem())

    if link then
        local itemId = 0 + (link:match('|Hitem:(%d+):') or 0)

        if MFH_DB_MOUNTS[itemId] then
            tooltip:AddLine(' ')
            tooltip:AddLine(string.format('%s:', L.tooltip_source), unpack(COLOR_ITEM_TOOLTIP))

            local itemSource
            for _, itemSource in pairs(MFH_DB_MOUNTS[itemId].from) do
                local zoneName, npcName, comment = self:GetItemSourceInfo(itemSource)

                if comment then
                    tooltip:AddDoubleLine(string.format('%s / %s', zoneName, npcName), comment, unpack(COLOR_ITEM_TOOLTIP_SOURCE_2L))
                else
                    tooltip:AddLine(string.format('%s / %s', zoneName, npcName, unpack(COLOR_ITEM_TOOLTIP_SOURCE)))
                end
            end
        end
    end
end
