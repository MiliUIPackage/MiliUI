--------------- Configuration -----------------

--higher value => longer processing =>  higher FPS
local CALCULATIONS_TIME_FOR_EMPTY_CACHE = 5  --Used in case new character was crated ot the player level has changed

--higher value => longer processing =>  higher FPS
local CALCULATIONS_TIME_FOR_FILLED_CACHE = 1  --For the same player level

--To check the performance on level change you can  run: /run DugisCharacterCache.CalculateScore_cache_v11 = {}    and then   /reload

local gearFinderDebug = false
local listItemsLimit = 6
-----------------------------

if not DugisGearFinder then
    DugisGearFinder = {}
end

local DGF = DugisGearFinder

--Variables for CacheItemsForGearFinder
DGF.retryQueue = {}
DGF.retryCounter = {}


--{slot1 = {itemId1 = item1, itemId2 =item2,}, slot2 = {itemId1 = item1, itemId2 =item2,}}
DGF.itemsBySlot = {}


local DGV = DugisGuideViewer
if not DGV then return end

local GA = DugisGuideViewer.Modules.GearAdvisor

--{{control, iteratedItemLink}, {control, iteratedItemLink}, ...}
DGF.GeadAdvisorItemIterator_cache = {}
DGF.IsQuestCompleted_cache = GetQuestsCompleted()

----------------------------
local DGV = DugisGuideViewer

local GearFinderModule = DGV:RegisterModule("GearFinder")
local DebugPrint = DGV.DebugPrint

function GearFinderModule:ShouldLoad()
	return DugisGuideViewer.chardb.EssentialsMode < 1 and DugisGuideViewer:GuideOn()
end

function GearFinderModule:Initialize()
    if DGF.allGearIds then
        InitializeGearFinder()
    end
    GearFinderModule.loaded = true
end

function GearFinderModule:Load()
    if DGF.allGearIds and DugisGuideViewer:UserSetting(DGV_ENABLEDGEARFINDER) then
        GearFinderModule.loaded = true
    end
end

function GetAuctionHouseCategoryName(classID, subClassID, inventoryType)
	local name = "";
	if inventoryType then
		name = GetItemInventorySlotInfo(inventoryType);
	elseif classID and subClassID then
		name = GetItemSubClassInfo(classID, subClassID);
	elseif classID then
		name = GetItemClassInfo(classID);
	end
	return name
end

function GetAuctionItemSubClasses_dugis(classIndex)
    if classIndex == 1 then
        return {
            [0] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_AXE1H      ) ,
            [1] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_AXE2H      ) ,
            [2] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_BOWS       ) ,
            [3] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_GUNS       ) ,
            [4] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_MACE1H     ) ,
            [5] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_MACE2H     ) ,
            [6] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_POLEARM    ) ,
            [7] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_SWORD1H    ) ,
            [8] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_SWORD2H    ) ,
            [9] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_WARGLAIVE    ) ,
            [10] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_STAFF      ) ,
            [13] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_UNARMED    ) ,
            --[14] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_GENERIC    ) ,
            [14] = AUCTION_SUBCATEGORY_MISCELLANEOUS                                             ,
            [15] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_DAGGER     ) ,
            [16] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_THROWN     ) ,
            [18] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_CROSSBOW   ) ,
            [19] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_WAND       ) ,
           -- [0] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_FISHINGPOLE)
            
            }
        
    end
    
    --AUCTION_CATEGORY_ARMOR
    if classIndex == 2 then
        return {
            [0] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC  ) ,
            [1] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_CLOTH    ) ,
            [2] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_LEATHER  ) ,
            [3] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_MAIL     ) ,
            [4] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_PLATE    ) ,
            [5] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_COSMETIC ) ,
            [6] = GetAuctionHouseCategoryName(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_SHIELD ) 
        }
    end
end


local allOwnedItems = {}
local numericItemId2IsOwned = {}

function GearFinderModule:Unload()
    HideUIPanel(CharacterFrame)
    if DGV:UserSetting(DGV_UNLOADMODULES) then
        wipe(DGF.gearId2GearInfos_map)
        wipe(DGF.guideTitle2GearIds_map)
        wipe(DGF.allGearGuides)
        wipe(DGF.gearId2DroppedByBoss_map)
        wipe(DGF.gearId2Quests_map)
        wipe(DGF.gearId2PossibleDifficulties_map)
        wipe(DGF.allGearIds)
        wipe(DGF.itemsBySlot)
        wipe(DGF.retryQueue)
        wipe(DGF.retryCounter)
        wipe(DGF.GeadAdvisorItemIterator_cache)
        wipe(DugisCharacterCache.CalculateScore_cache_v11)
        wipe(DGF.IsQuestCompleted_cache)

        DGF.gearId2GearInfos_map = {}
        DGF.guideTitle2GearIds_map = {}
        DGF.allGearGuides = {}
        DGF.gearId2DroppedByBoss_map = {}
        DGF.gearId2Quests_map = {}
        DGF.gearId2PossibleDifficulties_map = {}
        DGF.allGearIds = {}
        DGF.itemsBySlot = {}
        DGF.retryQueue = {}
        DGF.retryCounter = {}
        DGF.GeadAdvisorItemIterator_cache = {}
        DGF.IsQuestCompleted_cache = {}
        DugisCharacterCache.CalculateScore_cache_v11 = {}
        CacheItemsForGearFinder_invoked = false

        collectgarbage("step", 100000)

        GearFinderModule.loaded = false

        DGF:UpdateTabsForGearFinder()
    end
end
---------------------------

local equipementSlots = {
    "INVTYPE_HEAD",
    "INVTYPE_NECK",
    "INVTYPE_HAND",
    --INVTYPE_WEAPON_MERGED  Always displayed - except Hunters
    --INVTYPE_OFFHAND_MERGED  Always Displayed, except Hunters
    --INVTYPE_2HWEAPON  Displayed if ITEM_CLASS_WEAPON,2,6,7,9,10
    --INVTYPE_RANGED_MERGED   Displayed if ITEM_CLASS_WEAPON,3,4,15
    "INVTYPE_SHOULDER",
    "INVTYPE_CLOAK",
    "INVTYPE_CHEST_MERGED",
    "INVTYPE_WRIST",
    "INVTYPE_WAIST",
    "INVTYPE_LEGS",
   "INVTYPE_FEET",
   "INVTYPE_FINGER",
   "INVTYPE_TRINKET",
}


local localizedClass, englishClass, classIndex = UnitClass("Player");

function DGF:Slot2VirtualSlot(slot)
    if slot == "INVTYPE_ROBE" or slot == "INVTYPE_CHEST" then
        return "INVTYPE_CHEST_MERGED"
    end

    if slot == "INVTYPE_RANGED" or slot == "INVTYPE_RANGEDRIGHT" then
        return "INVTYPE_RANGED_MERGED"
    end

     if slot == "INVTYPE_WEAPONOFFHAND" or slot == "INVTYPE_HOLDABLE" or slot == "INVTYPE_SHIELD" then
        return "INVTYPE_OFFHAND_MERGED"
    end

    if slot == "INVTYPE_WEAPON" or slot == "INVTYPE_WEAPONMAINHAND" then
        return "INVTYPE_WEAPON_MERGED"
    end

    return slot
end

--slot - virtual slot
local function IsArmorSpecSlot(slot)
    return
        slot=="INVTYPE_CHEST_MERGED" or
        slot=="INVTYPE_FEET" or
        slot=="INVTYPE_HAND" or
        slot=="INVTYPE_HEAD" or
        slot=="INVTYPE_LEGS" or
        slot=="INVTYPE_SHOULDER" or
        slot=="INVTYPE_WAIST" or
        slot=="INVTYPE_WRIST"
end

function DGF:LocalizeSlot(slot)
   local map = {
        ["INVTYPE_2HWEAPON"] = "Two Hand" ,
        ["INVTYPE_CHEST_MERGED"] = "Chest",
        ["INVTYPE_HAND"] = "Hand",
        ["INVTYPE_RANGED_MERGED"] = "Ranged",
        ["INVTYPE_WEAPON_MERGED"] = "Weapon",
        ["INVTYPE_OFFHAND_MERGED"] = "Off-hand"
    }

    slot = DGF:Slot2VirtualSlot(slot)

    if map[slot] then
        return map[slot]
    end

    return _G[slot]
end

local itemButtons = {}
local extraButtons = {}
local tooltipItems = {}

function DGF:Print(...)
    if gearFinderDebug then
        print(...)
    end
end

--{[difficultyId] => shouldInclude:true/false}
function DGF:GetDifficultyFilters()
    local filers = {}

    LuaUtils:loop(100, function(diffId)
        filers[diffId] = true
    end)

    filers[1] =  DGV:UserSetting(DGV_INCLUDE_DUNG_NORMAL)
    filers[2] =  DGV:UserSetting(DGV_INCLUDE_DUNG_HEROIC)

    filers[7] =  DGV:UserSetting(DGV_INCLUDE_RAIDS_RAIDFINDER)

    filers[23] = DGV:UserSetting(DGV_INCLUDE_DUNG_MYTHIC)
    filers[24] = DGV:UserSetting(DGV_INCLUDE_DUNG_TIMEWALKING)

    filers[17] = DGV:UserSetting(DGV_INCLUDE_RAIDS_RAIDFINDER)
    filers[14] = DGV:UserSetting(DGV_INCLUDE_RAIDS_NORMAL)
    filers[15] = DGV:UserSetting(DGV_INCLUDE_RAIDS_HEROIC)
    filers[16] = DGV:UserSetting(DGV_INCLUDE_RAIDS_MYTHIC)

    return filers
end

function DGF:IsQuestCompleted(questId)
    return DGF.IsQuestCompleted_cache[questId] ~= nil
end

function DGF:PlayerHasEnoughLevel(suggestion)
    local currenLevel = UnitLevel("player")

    if suggestion.item.info.reqlevelByQuest ~= nil then
        return currenLevel >= suggestion.item.info.reqlevelByQuest
    end

    if suggestion.item.info.reqlevel ~= 0 and suggestion.item.info.reqlevel ~= nil then
        return currenLevel >= suggestion.item.info.reqlevel
    end

    return true
end

function DGF:StartGuide(guide)
    if DGV.DisplayViewTab and DugisGuideViewer.chardb.EssentialsMode ~= 1 and DugisGuideViewer:GuideOn() then
        DGV:DisplayViewTab(guide)
    end
end

function DGF:LoadGuideButtonOnClick(self)
    local suggestion = self.suggestion

    if suggestion then
        local theBestGuide = DGF:GetTheBestGuideForGearId(self.suggestion.item.info.itemid, true)
        DGF:StartGuide(theBestGuide)
		print("|cff11ff11Dugi Guides: |r"..DGV:GetFormattedTitle(theBestGuide).."|cff11ff11 selected.|r")
		PlaySoundFile("Sound\\Interface\\AlarmClockWarning3.ogg")
        --Print("Guide Loaded: ", self.suggestion.item.info.equipslot, self.suggestion.item.info.name, self.suggestion.item.info.itemid, " Used guide:", DugisGuideViewer:GetFormattedTitle(theBestGuide))
    else
        DGF:Print("Guide Loaded: ", self.slot)
    end
end

function DGF:HideAllMoreButtons()
    LuaUtils:foreach(itemButtons, function(item)
        item.loadGuideButton:Hide()
    end)
    LuaUtils:foreach(extraButtons, function(item)
        item.loadGuideButton:Hide()
    end)
end

function DGF:SetToNormalAllMoreButtons()
    LuaUtils:foreach(itemButtons, function(item)
        EquipmentFlyoutPopoutButton_SetReversed(item.moreButton, false)
        item.moreButton.reversed = false
        item.SelectedBar:Hide()
    end)
    LuaUtils:foreach(extraButtons, function(item)
        EquipmentFlyoutPopoutButton_SetReversed(item.moreButton, false)
        item.moreButton.reversed = false
        item.SelectedBar:Hide()
    end)
end

local boxSize = 49
local boxSizeTwoLabels = 36


local function ItemTexture(suggestion)
    return suggestion.item.info.texture
end

local function ItemName(suggestion)
    return suggestion.item.info.name
end

function ItemQuality(suggestion)
    return suggestion.item.info.quality
end

--The layout can be: "two-labels", "three-labels"
function DGF:GetCreateGuideBox(parent, x, y, layout, index, reuseItems)
    local slotButtonName = nil
    
    if reuseItems then
        slotButtonName = "GearFinderSlotButton"..index 
    end

    local box 
    
    if _G[slotButtonName] and reuseItems then
        box = _G[slotButtonName]
    else
        box = CreateFrame("Button", slotButtonName ,parent, "GearSetButtonTemplate")
        
        local topLabel = box:CreateFontString(nil,nil,"SystemFont_Med1")
        topLabel:ClearAllPoints()
        topLabel:SetPoint("TOPLEFT",box,"TOPLEFT",5, -3)
        topLabel:SetTextColor(1, 1, 1)
        topLabel:SetNonSpaceWrap(true)

        local bottomLabel = box:CreateFontString(nil,nil,"SystemFont_Shadow_Small")
        bottomLabel:ClearAllPoints()
        bottomLabel:SetPoint("BOTTOMLEFT",box,"BOTTOMLEFT",36, 4)
        bottomLabel:SetText("")
        bottomLabel:SetTextColor(1, 1, 1)
        bottomLabel:SetNonSpaceWrap(true)

        local middleLabel = box:CreateFontString(nil,nil,"SystemFont_Shadow_Small")
        middleLabel:ClearAllPoints()
        middleLabel:SetPoint("BOTTOMLEFT",box,"BOTTOMLEFT",36, 18)
        middleLabel:SetTextColor(1, 1, 1)
        middleLabel:SetNonSpaceWrap(true)
        middleLabel:SetText("Loading..")

        topLabel:SetJustifyH("LEFT")
        middleLabel:SetWordWrap(false)
        middleLabel:SetJustifyH("LEFT")

        topLabel:SetWordWrap(false)
        bottomLabel:SetWordWrap(false)
        bottomLabel:SetJustifyH("LEFT")

        if layout == "two-labels" then
            bottomLabel:SetPoint("BOTTOMLEFT",box,"BOTTOMLEFT", 38, 4)
            topLabel:SetPoint("TOPLEFT",box,"TOPLEFT", 38, -7)
            middleLabel:Hide()
        end

        local iconFrame = CreateFrame("Frame", nil, box)
        iconFrame:SetSize(28, 28)

        iconFrame:SetPoint("BOTTOMLEFT",box,"BOTTOMLEFT", 5, 3)

        local itemTexture = iconFrame:CreateTexture()
        itemTexture:SetAllPoints(iconFrame)
        iconFrame:Show()

        local moreButton = CreateFrame("Button", nil, box, "GearFinderMoreTemplate")
        moreButton:SetScript("OnLoad", nil)
        moreButton.slotItem = box
        moreButton:Show()

        moreButton:SetHeight(32);
        moreButton:SetWidth(16);
        moreButton:GetNormalTexture():SetTexCoord(0.15625, 0.5, 0.84375, 0.5, 0.15625, 0, 0.84375, 0);
        moreButton:GetHighlightTexture():SetTexCoord(0.15625, 1, 0.84375, 1, 0.15625, 0.5, 0.84375, 0.5);
        moreButton:ClearAllPoints();
        moreButton:SetPoint("LEFT", box, "RIGHT", -9, -7);
        moreButton:Hide()
    
        if box.SpecRing then
            box.SpecRing:Hide()
        end

        moreButton:SetScript("OnClick", function(self)
            if LuaUtils:ThreadInProgress("MoreButtonClicked") then
                return
            end

            LuaUtils:CreateThread("MoreButtonClicked", function()
                        local wasReverser = self.reversed
                        DGF:SetToNormalAllMoreButtons()
                        self.reversed = not wasReverser

                        EquipmentFlyoutPopoutButton_SetReversed(self, self.reversed)

                        self.slotItem.SelectedBar:Show()

                        if not self.reversed then
                            GearFinderExtraItemsFrame:Hide()
                            self.slotItem.SelectedBar:Hide()
                            return
                        end

                        GearFinderExtraItemsFrame:Show()

                        local localizedSlotName = DGF:LocalizeSlot(self.slotItem.suggestion.item.info.equipslot)
                        GearFinderExtraItemsFrame.headerLabel:SetText(localizedSlotName)

                        LuaUtils:loop(5, function(index)
                            extraButtons[index]:Hide()
                        end)

                        local deltaY = 0

                        if self.slotItem.top5suggestions then
                            LuaUtils:foreach(self.slotItem.top5suggestions, function(suggestion, index)
                                if extraButtons[index] then
                                    extraButtons[index].topLabel:SetText("X")

                                    local shortName = ItemName(suggestion)
                                    local requiredLevelInfo = ""

                                    extraButtons[index].itemTexture:SetTexture(ItemTexture(suggestion))

                                    local r, g, b, hex = GetItemQualityColor(ItemQuality(suggestion))

                                    local requiredLevelInfo = ""
                                    local requiredLevelInfoBefore = ""
                                    if not DGF:PlayerHasEnoughLevel(suggestion) then
                                        local lvl = suggestion.item.info.reqlevel

                                        if suggestion.item.info.reqlevelByQuest ~= nil then
                                            lvl = suggestion.item.info.reqlevelByQuest
                                        end

                                        if string.len(shortName) > 18 then
                                            requiredLevelInfoBefore = "|c00FF0000@L"..lvl.."|r "
                                        else
                                            requiredLevelInfoBefore = "|c00FF0000@ Level "..lvl.."|r "
                                        end
                                    end

                                    extraButtons[index].topLabel:SetText(requiredLevelInfoBefore.."|c"..hex..shortName.."|r")
                                    local guide = DGF:GetTheBestGuideForGearId(suggestion.item.info.itemid, true)

                                    if DugisGuideViewer.GetFormattedTitle then
                                        guide = DugisGuideViewer:GetFormattedTitle(guide)
                                    end

                                    extraButtons[index].bottomLabel:SetText("|cFFFFFFFF"..guide.."|r" )
                                    extraButtons[index].bottomLabel:SetWidth(210)
                                    extraButtons[index].topLabel:SetWidth(195)

                                    extraButtons[index].suggestion = suggestion
                                    extraButtons[index]:Show()

                                    deltaY = deltaY + boxSizeTwoLabels

                                    GearFinderExtraItemsFrame:SetHeight(deltaY + 65)
                                end

                                GearFinderExtraItemsFrame.headerLabel:SetText(localizedSlotName .." " .. index.."/"..#self.slotItem.top5suggestions.."..")
                            end)

                            GearFinderExtraItemsFrame.headerLabel:SetText(localizedSlotName)
                        end
                end
            )
        end)

        moreButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(moreButton, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Load more suggestions", 1, 1, 1)
            GameTooltip:Show()
        end)

        moreButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -------------Info button---------------------------
        local loadGuideButton = CreateFrame("Button", nil, box)
        loadGuideButton:SetSize(28, 28)
        loadGuideButton.slotItem = box
        loadGuideButton:SetPoint("TOPRIGHT",box,"TOPRIGHT",5, 5)
        loadGuideButton:SetNormalTexture("Interface\\MINIMAP\\UI-Minimap-MinimizeButtonUp-Up.blp")
        loadGuideButton:SetHighlightTexture("Interface\\MINIMAP\\UI-Minimap-MinimizeButtonUp-Highlight.blp")
        loadGuideButton:SetPushedTexture("Interface\\MINIMAP\\UI-Minimap-MinimizeButtonUp-Down.blp")
        loadGuideButton:Hide()
        loadGuideButton:SetScript("OnClick", function(self)
            LuaUtils:CreateThread("LoadGuideButtonOnClick", function()
                DGF:LoadGuideButtonOnClick(box)
            end)
        end)

        loadGuideButton.box = box

        loadGuideButton:SetScript("OnEnter", function(self)
            LuaUtils:CreateThread("LoadGuideButtonOnEnter", function()
            
                local gearId = box.suggestion.item.info.itemid

                local guideTitle, gearInfo = DGF:GetTheBestGuideForGearId(gearId, true)

                if not gearInfo then
                    return
                end

                local questName = ""

                if gearInfo.questIds then
                    LuaUtils:foreach(gearInfo.questIds, function(questId)
                        if not DGF:IsQuestCompleted(questId) then
                            if DugisGuideViewer.NPCJournalFrame.GetQuestInfo then
                                local questInfo = DugisGuideViewer.NPCJournalFrame:GetQuestInfo(tonumber(questId))
                                if questInfo then
                                    questName = questInfo.name
                                end
                            end
                        end
                    end)
                end

                GameTooltip:SetOwner(moreButton, "ANCHOR_RIGHT")

                local guideTitleFormatted = guideTitle
                local guideExists = true

                if not DugisGuideViewer:isValidGuide(guideTitle) then
                    guideExists = false
                end

                if  DugisGuideViewer.GetFormattedTitle then
                    guideTitleFormatted = DugisGuideViewer:GetFormattedTitle(guideTitle)
                end

                if guideTitleFormatted then
                    if gearInfo.reputationId then
                        GameTooltip:AddLine("Reputation With: |cFFFFFFFF"..guideTitleFormatted.."|r" , 1, 0.8, 0.0)
                    else
                        GameTooltip:AddLine("Found In: |cFFFFFFFF"..guideTitleFormatted.."|r" , 1, 0.8, 0.0)
                    end
                end

                if gearInfo.bossId then
                    local numericBossId = tonumber(gearInfo.bossId)
                    local droppedBy
                    local bossName

                    if numericBossId > 0 then
                        bossName =  DugisGuideViewer:GetLocalizedNPC(numericBossId)
                    else
                        if gearInfo.encounterId then
                            bossName = EJ_GetEncounterInfo(gearInfo.encounterId)
                        end
                    end

                    if not bossName then
                        droppedBy = "Boss "..gearInfo.bossId
                    else
                        droppedBy = bossName
                    end
                    GameTooltip:AddLine("Dropped by: |cFFFFFFFF"..droppedBy.."|r" , 1, 0.8, 0.0)
                end

                if questName ~= "" then
                    GameTooltip:AddLine("Reward From: |cFFFFFFFF"..questName.."|r" , 1, 0.8, 0.0)
                end

                if guideExists then
                    GameTooltip:AddLine("Click to load the guide", 0, 1, 0)
                else
                    GameTooltip:AddLine("Guide not available", 1, 0, 0)
                end
                GameTooltip:Show()

                if self.box.top5suggestions == nil or #self.box.top5suggestions < 2 then
                    self.box.moreButton:Hide()
                else
                    self.box.moreButton:Show()
                end
            
            
            end)
        end)

        loadGuideButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        
       box:SetScript("OnEnter", function(self)
            if self.suggestion and self.suggestion.item.info.itemid then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                GameTooltip:SetHyperlink(self.suggestion.item.info.itemlink);
            end

            DGF:HideAllMoreButtons()

            if self.suggestion then
                self.loadGuideButton:Show()
            end

            if self.suggestion then
                self.HighlightBar:Show()
            end
        end)

        box:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            self.HighlightBar:Hide();
        end)

        box:SetScript("OnClick", nil)
        

        box.topLabel = topLabel
        box.middleLabel = middleLabel
        box.bottomLabel = bottomLabel
        box.moreButton = moreButton
        box.loadGuideButton = loadGuideButton
        box.itemTexture = itemTexture
        
    end

    box:SetSize(168, boxSize)

    if layout == "two-labels" then
        box:SetSize(257, boxSizeTwoLabels)
    end

    box:SetPoint("TOPLEFT",x, y)
    box.texture = box:CreateTexture()
    box.texture:SetAllPoints(box)
    --box.texture:SetTexture("Interface\\CHARACTERFRAME\\BarHighlight.blp")
  
    return box
end

function DGF:UpdateGearButtons(itemButtons, showShadows)
    local STRIPE_COLOR = {r=0.9, g=0.9, b=1}

	for i = 1, #itemButtons do
        local button = itemButtons[i];

        button.Check:Hide();
        button.icon:Hide()

        if i == 1 and showShadows then
            button.BgTop:Show();
            button.BgMiddle:SetPoint("TOP", itemButtons[i].BgTop, "BOTTOM");
        else
            button.BgTop:Hide();
            button.BgMiddle:SetPoint("TOP");
        end

        if i == numRows and showShadows then
            button.BgBottom:Show();
            button.BgMiddle:SetPoint("BOTTOM", itemButtons[i].BgBottom, "TOP");
        else
            button.BgBottom:Hide();
            button.BgMiddle:SetPoint("BOTTOM");
        end

        if i % 2 == 0 then
            button.Stripe:SetColorTexture(STRIPE_COLOR.r, STRIPE_COLOR.g, STRIPE_COLOR.b);
            button.Stripe:SetAlpha(0.1);
            button.Stripe:Show();
        else
            button.Stripe:Hide();
        end

        if not showShadows then
             button.BgMiddle:SetAlpha(0.01)
        else
         button.BgMiddle:SetAlpha(1)
        end
	end
end

function DGF:CreateExtraItemsFrame()
    if _G["GearFinderExtraItemsFrame"] then
        return
    end

    local frame = CreateFrame("Frame", "GearFinderExtraItemsFrame", UIParent)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetWidth(285)
    frame:SetHeight(299)

    frame:Show()

    frame:SetBackdrop({
    bgFile = [[Interface\GLUES\Models\UI_MainMenu_Cataclysm\UI_BLACKCOLOR01.BLP]]
    ,edgeFile =  DugisGuideViewer:GetBorderPath(),
                                            tile = false, tileSize = 30, edgeSize = 32,
                                            insets = { left = 10, right = 5, top = 10, bottom = 5 }})

    frame:SetBackdropColor(1,1,1,1)

	DugisGuideViewer.ApplyElvUIColor(frame)
	
    GearFinderExtraItemsFrame:SetPoint("TOPRIGHT",CharacterFrame, 283, 5)

    frame:SetParent(CharacterFrame)
    frame:Hide()

    --Header
    local headerLabel = frame:CreateFontString(nil, nil, "SystemFont_Med3")
    headerLabel:ClearAllPoints()
    headerLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -25)
    headerLabel:SetText("Top gear guides")
    headerLabel:SetTextColor(1,0.8,0)
    headerLabel:SetNonSpaceWrap(true)
    GearFinderExtraItemsFrame.headerLabel = headerLabel

    --Close button
    LuaUtils:loop(5, function(index)
        local button = DGF:GetCreateGuideBox(frame, 15,  -index * (boxSizeTwoLabels) - 10, "two-labels")
        button.moreButton:Hide()
        extraButtons[#extraButtons + 1] = button
    end)

    DGF:UpdateGearButtons(extraButtons, false)
end

function DGF:GearFinderTooltipFrame()
    if _G["GearFinderTooltipFrame"] then
        return
    end

    local frame = CreateFrame("Frame", "GearFinderTooltipFrame", UIParent)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetWidth(285)
    frame:SetHeight(299)
    frame:SetClampedToScreen(true)

    frame:Show()

    frame:SetBackdrop({
    bgFile = [[Interface\GLUES\Models\UI_MainMenu_Cataclysm\UI_BLACKCOLOR01.BLP]]
    ,edgeFile =  DugisGuideViewer:GetBorderPath(),
                                            tile = false, tileSize = 30, edgeSize = 32,
                                            insets = { left = 10, right = 5, top = 10, bottom = 5 }})

    frame:SetBackdropColor(1,1,1,1)
	
	DugisGuideViewer.ApplyElvUIColor(frame)

    GearFinderTooltipFrame:SetPoint("TOPRIGHT",CharacterFrame, 283, 5)

    --Header
    local headerLabel = frame:CreateFontString(nil, nil, "SystemFont_Med3")
    headerLabel:ClearAllPoints()
    headerLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -25)
    headerLabel:SetText("Items found:")
    headerLabel:SetTextColor(1,0.8,0)
    headerLabel:SetNonSpaceWrap(true)
    GearFinderTooltipFrame.headerLabel = headerLabel

    --Close button
    LuaUtils:loop(18, function(index)
        local button = DGF:GetCreateGuideBox(frame, 15,  -index * (boxSizeTwoLabels) - 10, "two-labels")
         tooltipItems[#tooltipItems + 1] = button

         button.topLabel:SetNonSpaceWrap(true)
         button.topLabel:SetWidth(210)
    end)

    LuaUtils:foreach(tooltipItems, function(itemButton)
        itemButton:Hide()
    end)

    DGF:UpdateGearButtons(tooltipItems, false)
end

function DGF:HideExtraButtonsFrame()
    DGF:SetToNormalAllMoreButtons()
    if GearFinderExtraItemsFrame then
        GearFinderExtraItemsFrame:Hide()
    end
end

local function UpdateCurrentGuideTtile()
    --Updating the tooltip

    LuaUtils:foreach(tooltipItems, function(itemButton)
        itemButton:Hide()
    end)

    local yIndex = 1
    LuaUtils:foreach(itemButtons, function(itemButton)
        if itemButton.suggestion and itemButton.suggestedGuide == DugisGearFinderFrame.suggestedGuide.suggestedGuideTitle then
            tooltipItems[yIndex].bottomLabel:SetText(DGF:LocalizeSlot(itemButton.suggestion.item.info.equipslot))
            local itemName = ItemName(itemButton.suggestion)
            local r, g, b, hex = GetItemQualityColor(ItemQuality(itemButton.suggestion))
            tooltipItems[yIndex].topLabel:SetText("|c"..hex..itemName.."|r")
            tooltipItems[yIndex].itemTexture:SetTexture(ItemTexture(itemButton.suggestion))
            tooltipItems[yIndex]:Show()
            yIndex = yIndex + 1
        end
    end)

    GearFinderTooltipFrame:SetHeight(yIndex * boxSizeTwoLabels + 25)
end

function DGF:BuildSlots()

    local equipementSlotsCopy = LuaUtils:clone(equipementSlots)
    
    local allowedWeaponSubclassIndices = GA:GetGearAdvisorScoringValues("LE_ITEM_CLASS_WEAPON")
	local allowedArmorSubclassIndices = GA:GetGearAdvisorScoringValues("LE_ITEM_CLASS_ARMOR")

    --Adding extra slots to the table
    if
        LuaUtils:isInTable("2", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("3", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("18", allowedWeaponSubclassIndices)
    then
        table.insert(equipementSlotsCopy, 4, "INVTYPE_RANGED_MERGED")
    end

    if
        LuaUtils:isInTable("1", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("5", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("6", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("8", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("10", allowedWeaponSubclassIndices)
    then
        table.insert(equipementSlotsCopy, 4, "INVTYPE_2HWEAPON")
    end

    if
	    LuaUtils:isInTable("0", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("4", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("7", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("13", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("15", allowedWeaponSubclassIndices) or
        LuaUtils:isInTable("19", allowedWeaponSubclassIndices) or
		LuaUtils:isInTable("6", allowedArmorSubclassIndices)
	then
        table.insert(equipementSlotsCopy, 4, "INVTYPE_OFFHAND_MERGED")
        table.insert(equipementSlotsCopy, 4, "INVTYPE_WEAPON_MERGED")
    end


    --todo: hide all existing slots
    
    LuaUtils:foreach(itemButtons, function(item)
        item:Hide()
    end)
    
    itemButtons = {}
    
    LuaUtils:foreach(equipementSlotsCopy, function(value, index)
        local slotText = DGF:LocalizeSlot(value)

        local itemFrame = DGF:GetCreateGuideBox(DugisGearFinderFrame.ScrollChild, 0, -index * boxSize , "three-labels", index, true)
        itemFrame.topLabel:SetText(slotText)
        itemFrame.slot = value
        
        itemFrame:Show()

        itemButtons[#itemButtons + 1] = itemFrame
    end)

    DGF:UpdateGearButtons(itemButtons, true)
end

function DGF:InitializeGearFinderUI()
    if InitializeGearFinderUI_initialized then
        return
    end

    local GA = DGV.Modules.GearAdvisor
    if not GA then return end

    InitializeGearFinderUI_initialized = true

    --LuaUtils.Profiler:Start("InitializeGearFinderUI")

    CreateFrame("ScrollFrame", "DugisGearFinderFrame", PaperDollFrame, "UIPanelScrollFrameTemplate2")

    DugisGearFinderFrame:SetScript("OnEvent", ItemInfoEventHandler)
	DugisGearFinderFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	DugisGearFinderFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	DugisGearFinderFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")


    DugisGearFinderFrame:SetPoint("TOPLEFT", CharacterFrameInsetRight, "TOPLEFT", 5, -4)
    DugisGearFinderFrame:SetPoint("BOTTOMRIGHT",CharacterFrameInsetRight,"BOTTOMRIGHT",-27, 4)
    DugisGearFinderFrame:Hide()

    DugisGearFinderFrame.ScrollChild = CreateFrame("Frame", nil ,DugisGearFinderFrame)
    DugisGearFinderFrame.ScrollChild:SetSize(270, 950)
    DugisGearFinderFrame.ScrollChild:SetPoint("TOPLEFT")
    DugisGearFinderFrame:SetScrollChild(DugisGearFinderFrame.ScrollChild)

    CreateFrame("Frame", "SuggestedGearGuide", DugisGearFinderFrame.ScrollChild)
    SuggestedGearGuide:SetSize(270, 40)
    SuggestedGearGuide:SetPoint("TOPLEFT", 0, 0)
    SuggestedGearGuide:Show()

    -- Preloder
    CreateFrame("Frame", "GearFinderPreloader" , DugisGearFinderFrame, "DugisPreloader")
    GearFinderPreloader:SetSize(171, 40)
    GearFinderPreloader:SetParent(DugisGearFinderFrame)
    GearFinderPreloader:SetPoint("BOTTOMLEFT", 0, -2)
    GearFinderPreloader:Hide()

    local animationGroup = GearFinderPreloader.Icon:CreateAnimationGroup()
    animationGroup:SetLooping("REPEAT")
    local animation = animationGroup:CreateAnimation("Rotation")
    animation:SetDegrees(-360)
    animation:SetDuration(1)
    animation:SetOrder(1)
    DGF.preloaderAnimationGroup = animationGroup

    local suggestedGuide = SuggestedGearGuide:CreateFontString(nil, nil, "SystemFont_Med1")
    suggestedGuide:ClearAllPoints()
    suggestedGuide:SetPoint("TOPLEFT", SuggestedGearGuide, "TOPLEFT", 2, -2)
    suggestedGuide:SetText("Best Guide")
    suggestedGuide:SetTextColor(1,0.8,0)
    suggestedGuide:SetNonSpaceWrap(true)

    local suggestedGuideSubtitle = SuggestedGearGuide:CreateFontString(nil, nil, "SystemFont_Shadow_Small")
    suggestedGuideSubtitle:ClearAllPoints()
    suggestedGuideSubtitle:SetPoint("TOPLEFT", SuggestedGearGuide, "TOPLEFT", 7, -20)
    suggestedGuideSubtitle:SetText("-")
    suggestedGuideSubtitle:SetTextColor(1,0.8,0)
    suggestedGuideSubtitle:SetNonSpaceWrap(true)

    SuggestedGearGuide:SetScript("OnMouseDown", function()
        if suggestedGuide.suggestedGuideTitle then
            DGF:StartGuide(suggestedGuide.suggestedGuideTitle)
			print("|cff11ff11Dugi Guides: |r"..DGV:GetFormattedTitle(suggestedGuide.suggestedGuideTitle).."|cff11ff11 selected.|r")
			PlaySoundFile("Sound\\Interface\\AlarmClockWarning3.ogg")
            --DGF:Print("Guide Loaded: ", suggestedGuide.suggestedGuideTitle)
        end
    end)

    ---------------------------------
    CreateFrame("Button", "SuggestedGuideButtonDG", SuggestedGearGuide)
    SuggestedGuideButtonDG:SetSize(28, 28)
    SuggestedGuideButtonDG:SetPoint("TOPLEFT",SuggestedGearGuide,"TOPLEFT", 145, 2)
    SuggestedGuideButtonDG:SetNormalTexture("Interface\\MINIMAP\\UI-Minimap-MinimizeButtonUp-Up.blp")
    SuggestedGuideButtonDG:SetHighlightTexture("Interface\\MINIMAP\\UI-Minimap-MinimizeButtonUp-Highlight.blp")
    SuggestedGuideButtonDG:SetPushedTexture("Interface\\MINIMAP\\UI-Minimap-MinimizeButtonUp-Down.blp")
    SuggestedGuideButtonDG:Hide()
    SuggestedGuideButtonDG:SetScript("OnClick", function(self)
        if suggestedGuide.suggestedGuideTitle then
            DGF:StartGuide(suggestedGuide.suggestedGuideTitle)
			print("|cff11ff11Dugi Guides: |r"..DGV:GetFormattedTitle(suggestedGuide.suggestedGuideTitle).."|cff11ff11 selected.|r")
			PlaySoundFile("Sound\\Interface\\AlarmClockWarning3.ogg")
        end
    end)

    SuggestedGuideButtonDG:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(SuggestedGuideButtonDG, "ANCHOR_RIGHT")

        local guideExists = true
        if not DugisGuideViewer:isValidGuide(suggestedGuide.suggestedGuideTitle) then
            guideExists = false
        end

        if guideExists then
            GameTooltip:AddLine("Click to load the guide", 1, 1, 1)
        else
            GameTooltip:AddLine("Guide not available", 1, 0, 0)
        end

        GameTooltip:Show()
    end)

    SuggestedGuideButtonDG:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    SuggestedGearGuide:SetScript("OnLeave", function(self)
        if not SuggestedGuideButtonDG:IsMouseOver() then
            SuggestedGuideButtonDG:Hide()
        end

        GearFinderTooltipFrame:Hide()
    end)

    SuggestedGearGuide:SetScript("OnEnter", function(self)
        if suggestedGuideSubtitle:GetText() ~= "-" then
            SuggestedGuideButtonDG:Show()
        end

        UpdateCurrentGuideTtile()

        if tooltipItems[1]:IsShown() and not GearFinderExtraItemsFrame:IsShown() then
            GearFinderTooltipFrame:Show()
        end
    end)

    DugisGearFinderFrame.suggestedGuide = suggestedGuide
    DugisGearFinderFrame.suggestedGuideSubtitle = suggestedGuideSubtitle

    DGF:BuildSlots()

    hooksecurefunc("CharacterFrame_Collapse", function()
        DGF:HideExtraButtonsFrame()
    end)

    hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", function()
        if not DugisGearFinderFrame:IsShown() then
            DGF:SetToNormalAllMoreButtons()
            if GearFinderExtraItemsFrame then
                GearFinderExtraItemsFrame:Hide()
            end
        end
    end)

    --uaUtils.Profiler:Stop("InitializeGearFinderUI")
end

function DGF:GetItemInfoById(itemId, threading)
    local itemlink = ""
    local numericItemId = tonumber(itemId)
    if numericItemId == nil or numericItemId == 0 then
        itemlink = itemId
    else
        itemlink="item:"..itemId..":0:0:0:0:0:0:0:0:0:0:0"
    end

    local name,link,quality,ilevel, reqlevel, class, subclass, maxstack, equipslot, texture, vendorprice = GetItemInfo_dugi(itemlink, threading)

    --Min
    local reqlevelByQuest = nil

    if not name then
        return nil
    end

    -- Loads stats into item.stats
    local stats = GetItemStats(itemlink)
    if not stats then
        return nil
    end

    if reqlevel == nil or reqlevel == 0 or (reqlevel == 1 and ilevel > 10) then
       local relatedQuests = DGF.gearId2Quests_map[itemId]

       --This condition is needed because GetItemInfoById is used also to get information about possesed gears (not nesseserly avaliable in GearInfoData lua file)
       if relatedQuests then
           local requiredLevelbyQuestMin = 0
           LuaUtils:foreach(relatedQuests, function(_, questId)
               local levels = DGV.ReqLevel[questId]
               if levels then
                   if reqlevelByQuest == nil then
                        reqlevelByQuest = levels[2]
                   else
                        if levels[2] < reqlevelByQuest then
                            reqlevelByQuest = levels[2]
                        end
                   end
               end
           end)
       end
    end

   -- DGF:Print(reqlevelByQuest)
    local item

    if DugisGearFinder.optimized then
        item = {
                info = {
                itemid = itemId
                , name = name
                , reqlevel = reqlevel
                , reqlevelByQuest = reqlevelByQuest
                , class = class
                , quality = quality
                , subclass = subclass
                , texture = texture
                , equipslot = equipslot
                , itemlink = itemlink
                },
                tooltip={}
            }
    else
        item = {
            info = {
            itemid = itemId
            , name = name
            , itemlink = itemlink
            , prettylink = link
            , quality = quality
            , ilevel = ilevel
            , reqlevel = reqlevel
            , reqlevelByQuest = reqlevelByQuest
            , class = class
            , subclass = subclass
            , texture = texture
            , equipslot = equipslot
            , vendorprice = vendorprice
            },
            stats = stats,
            tooltip={}
        }
    end

    return item
end


function DGF:GetAllOwnedItems(onlyBelowPlayerLevel)
    local result = {}

    local itemInvariant = DugisGuideViewer:GetCreateTable()
    itemInvariant.first = itemMustWin
    itemInvariant.skip = skip

    for control, iteratedItemLink in GeadAdvisorItemIterator, itemInvariant do
        local itemInfo = DGF:GetItemInfoById(iteratedItemLink, true)

        if itemInfo == nil then
            return
        end
        
		LuaUtils:RestIfNeeded(true)
        
        --SCORE
        local level = UnitLevel("player")

        local uniqueInventorySlot = GetDefaultUniqueInventorySlot(itemInfo.info.equipslot)

        local score = CalculateScoreForGearFinder(itemInfo.info.itemid, GetSpecialization(), nil, level, uniqueInventorySlot)
        
        local lvl = itemInfo.info.reqlevel

        if itemInfo.info.reqlevelByQuest ~= nil then
            lvl = itemInfo.info.reqlevelByQuest
        end

        if (not onlyBelowPlayerLevel) or (level >= lvl ) then
            result[#result + 1] = {link=iteratedItemLink, itemId = itemInfo.info.itemid, item = itemInfo, score = score}
        end

       -- result[#result + 1] =  itemInfo
    end

    --LuaUtils.Profiler:Stop("GetAllOwnedItems")

    return result
end

--{itemId1 = true, itemid2 = true, ...}
function DGF:GetAllOwnedItemIds(noThread)
    local result = {}

    LuaUtils:foreach(allOwnedItems, function(value)
        result[value.itemId] = true
    end)

    return result
end

--/run GetTheBestOwnedItemBySlot("INVTYPE_WRIST")
function DGF:GetTheBestOwnedItemBySlot(slot, onlyBelowPlayerLevel)
    if #allOwnedItems == 0 then
        return nil
    end

    local theBest = nil
    DGF:Print("-------------------------")
    DGF:Print("POSSESSED items for ",slot," slot:")
    LuaUtils:foreach(allOwnedItems, function(item, index)
        if DGF:Slot2VirtualSlot(item.item.info.equipslot) == slot then
            DGF:Print("itemId:", item.item.info.itemid, " SCORE:", item.score)
        end

        if DGF:Slot2VirtualSlot(item.item.info.equipslot) == slot and (theBest == nil or item.score > theBest.score) then
            theBest = item
        end
    end)

    if not theBest then
        DGF:Print("-none")
    end

    if theBest then
        DGF:Print("AMONG POSSESSED THE BEST IS:"..theBest.link, " itemId:", theBest.item.info.itemid, " (SCORE: ", theBest.score, ")")
    else
        DGF:Print("THE BEST WAS NOT FOUND AMONG POSSESSED")
    end

    return theBest
end

function DGF:CanBeGearObtaind(gearId)
    if not DGF.gearId2DroppedByBoss_map[gearId] then
    
        if DugisGearFinder.gearId2LevelRange[gearId] then
            return true
        end
    
        --Checking if all quests are not completed
        local allRelatedQuests = DGF.gearId2Quests_map[gearId]
        local allQuestsCompleted = true

        if allRelatedQuests then
            LuaUtils:foreach(allRelatedQuests, function(_, questId)
                if not DGF:IsQuestCompleted(questId) then
                    allQuestsCompleted = false
                end
            end)
        end

        if allQuestsCompleted then
            return false
        end
    end

    return true
end

--Returns the score of the guide (takes into account only not owned items)
function DGF:ScoreGuide(guideTitle, noThread, yields)
    local guideScore = 0
	
	if DGV.GearFinderScoreGuide_cache_v1 == nil then
		DGV.GearFinderScoreGuide_cache_v1 = {}
	end

    local gearIds = DGF.guideTitle2GearIds_map[guideTitle] or {}
	
	local gearControlSum = 0;
	
	LuaUtils:foreach(gearIds, function(gearId)
		gearControlSum = gearControlSum + (tonumber(gearId) or 0)
	end)
	
	if DGV.GearFinderScoreGuide_cache_v1[guideTitle..gearControlSum] then
		return DGV.GearFinderScoreGuide_cache_v1[guideTitle..gearControlSum]
	end

    if not yields then
        yields = 0
    end

    local level = UnitLevel("player")

    local itemId2IsOwned = DGF:GetAllOwnedItemIds(noThread)

    LuaUtils:foreach(gearIds, function(gearId)


        local shouldBeConsidered = true

        if itemId2IsOwned[gearId] == true then
            shouldBeConsidered = false
        end

        if not DGF:CanBeGearObtaind(gearId) then
            shouldBeConsidered = false
        end

       if shouldBeConsidered then
           local item = DGF:GetItemInfoById(gearId, noThread ~= true)

            if item ~= nil then
                if not noThread then
					LuaUtils:RestIfNeeded(true)
                    LuaUtils:WaitForCombatEnd()
                end

               local uniqueInventorySlot = GetDefaultUniqueInventorySlot(item.info.equipslot)
               local score = CalculateScoreForGearFinder(gearId, GetSpecialization(), nil, level, uniqueInventorySlot)
               guideScore = guideScore + score
           else
           end
       end
    end)

	DGV.GearFinderScoreGuide_cache_v1[guideTitle..gearControlSum] = guideScore
    return guideScore
end

--gearGuidesSet - set of guides to analyse. If nil then = DGF.allGearGuides
function DGF:GetTheBestGuide(gearGuidesSet, noThread, yields)
    if not gearGuidesSet then
        gearGuidesSet = DGF.allGearGuides
    end

    local theBestTitle, theBestScore, theBestIndex = nil, nil, nil
    if gearGuidesSet then
        LuaUtils:foreach(gearGuidesSet, function(guideTitle, index)

            LuaUtils.Profiler:Start("ScoreGuide")
            local guideScore = DGF:ScoreGuide(guideTitle, noThread, yields)
            LuaUtils.Profiler:Stop("ScoreGuide")

            if theBestScore == nil or guideScore > theBestScore then
                theBestScore = guideScore
                theBestTitle = guideTitle
                theBestIndex = index
            end
        end)
    end

    return theBestTitle, theBestScore, theBestIndex
end

--Returns theBestTitle, related gearInfo
function DGF:GetTheBestGuideForGearId(gearId, noThread, yields)
    local gearInfos = DGF.gearId2GearInfos_map[gearId]
    local guidesList = {}

    local filters = DGF:GetDifficultyFilters()

    LuaUtils:foreach(gearInfos, function(gearInfo)
        --Filtering by difficulty:
        local passedByFilter = false
        local difficulty = gearInfo.dungeonDifficulty

        if difficulty == nil or filters[difficulty] then
            guidesList[#guidesList + 1] = gearInfo.guideTitle
        end
    end)
    local theBestTitle, theBestScore, theBestIndex = DGF:GetTheBestGuide(guidesList, noThread, yields)

    if theBestTitle then
        return theBestTitle, gearInfos[theBestIndex]
    end
end

local allowedWeaponClassNames = {}
local allowedArmoClassNames = {}


function addItem2itemsBySlot(item)

    local equipslot = item.info.equipslot

    if IsEquipment(equipslot) then
        local virtualSlot = DGF:Slot2VirtualSlot(equipslot)

        if not DGF.itemsBySlot[virtualSlot] then
            DGF.itemsBySlot[virtualSlot] = {}
        end

        --Filtering items by class and specialization
        local canBePassed = true

        if item.info.class == "Armor" then
            if not LuaUtils:isInTable(item.info.subclass, allowedArmoClassNames) then
                --TODO
                canBePassed = false
            else
            end
        end
        if item.info.class == "Weapon" then
            if not LuaUtils:isInTable(item.info.subclass, allowedWeaponClassNames) then
                --TODO
                canBePassed = false
            else
            end
        end

        if canBePassed then
            DGF.itemsBySlot[virtualSlot][item.info.itemid] = item
        else
        end
    else
    end

end

--Updating suggested gears in case settings were changed
function OnGearFinderSettingsChanged()
    DGF:CacheItemsForGearFinder()
end

--Updates data needed by GearFinder for calculations. It collects for example current owned gears.
function DGF:UpdateDynamicDataForGearFinder()
    if LuaUtils:ThreadInProgress("UpdateDynamicDataForGearFinder") or LuaUtils:ThreadInProgress("CacheItemsForGearFinder") or LuaUtils:ThreadInProgress("SetSuggestedItemGuides")  then
        return
    end

    LuaUtils:CreateThread("UpdateDynamicDataForGearFinder", function()
        --If it is before GearAdvisor initialization return
        while not GeadAdvisorItemIterator or UnitAffectingCombat("player") or 
        LuaUtils:ThreadInProgress("SetSuggestedItemGuides") or LuaUtils:ThreadInProgress("CacheItemsForGearFinder") do
            LuaUtils:RestIfNeeded(true)
        end
        
        numericItemId2IsOwned = {}
        
        for control, iteratedItemLink in GeadAdvisorItemIterator, itemInvariant do
            GetItemInfo_dugi(iteratedItemLink, true)
            
            local itemString = string.match(iteratedItemLink, "item[%-?%d:]+")
			
			if itemString ~= nil then
				local _, itemId = strsplit(":", itemString)
				itemId = tonumber(itemId)
				
				if itemId ~= nil then
					numericItemId2IsOwned[itemId] = true
				end
			end
        end
        
         
        local allOwnedItems_ = DGF:GetAllOwnedItems()

        if allOwnedItems_ then
            allOwnedItems = allOwnedItems_
        end
        
        
        --- Updating Allowed subclasses
        local GA = DGV.Modules.GearAdvisor
        
        if GA and DugisGuideViewer:IsModuleLoaded("GearAdvisor") then
            local allowedWeaponSubclassIndices = GA:GetGearAdvisorScoringValues("LE_ITEM_CLASS_WEAPON")
            local allowedArmorSubclassIndices = GA:GetGearAdvisorScoringValues("LE_ITEM_CLASS_ARMOR")

            local allWaponSubclasses = GetAuctionItemSubClasses_dugis(1)
            local allArmorSubclasses = GetAuctionItemSubClasses_dugis(2)

            allowedWeaponClassNames = {}
            allowedArmoClassNames = {}

            LuaUtils:foreach(allowedWeaponSubclassIndices, function(index)
                local index = tonumber(index)
                allowedWeaponClassNames[#allowedWeaponClassNames + 1] = allWaponSubclasses[index]
            end)

            LuaUtils:foreach(allowedArmorSubclassIndices, function(index)
                local index = tonumber(index)
                allowedArmoClassNames[#allowedArmoClassNames + 1] = allArmorSubclasses[index]
            end)
        end        
        
    end)
end

function ItemInfoEventHandler(self, event, ...)
    if event == "GET_ITEM_INFO_RECEIVED" then
        local itemId = ...

        --Protecting from adding not needed items
        if not DGF.gearId2GearInfos_map[itemId] and not numericItemId2IsOwned[itemId] then
            return
        end

        local item = DGF:GetItemInfoById(itemId, false)

        if item then
            addItem2itemsBySlot(item)
        end
    end
    
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        DugisGearFinder:UpdateDynamicDataForGearFinder()
    end 
    
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
		DGF:BuildSlots()
		if GetSpecialization() ~= DugisGuideViewer.specializaton then
			OnGearFinderSettingsChanged()
			DugisGuideViewer.specializaton = GetSpecialization()
		end
    end
end

function DGF:MakeSuggestions()
    if GearFinderPreloader then
      GearFinderPreloader:Hide()
      DGF.preloaderAnimationGroup:Stop()
    end

    LuaUtils:CreateThread("SetSuggestedItemGuides", function()
            if GearFinderPreloader then
                GearFinderPreloader:Show()
                DGF.preloaderAnimationGroup:Play()
            end
            DGF:SetSuggestedItemGuides()
        end,
        function()
            if GearFinderPreloader then
                GearFinderPreloader:Hide()
                DGF.preloaderAnimationGroup:Stop()
            end
        end
    )
end


local cacheIntensity = 50
local CacheItemsForGearFinder_invoked = false
local CacheItemsForGearFinderIsInQueue = false

function DGF:CacheItemsForGearFinder()
    --Preventing invoked caching many times on settings change
    if CacheItemsForGearFinderIsInQueue then
        return
    end
    
    LuaUtils:CreateThread("WaitForCacheItemsForGearFinderEnd", function()
    
        GearFinderPreloader:Show()
        DGF.preloaderAnimationGroup:Play()
    
        CacheItemsForGearFinderIsInQueue = true
        while LuaUtils:ThreadInProgress("CacheItemsForGearFinder") do
            coroutine.yield()
        end
		
		if allowedWeaponClassNames == nil or allowedArmoClassNames == nil or (#allowedWeaponClassNames == 0 and #allowedArmoClassNames == 0) then
			DugisGearFinder:UpdateDynamicDataForGearFinder()
		end	

		while LuaUtils:ThreadInProgress("UpdateDynamicDataForGearFinder") do
            coroutine.yield()
        end

        LuaUtils:CreateThread("CacheItemsForGearFinder", function()
            while  LuaUtils:ThreadInProgress("UpdateDynamicDataForGearFinder") or LuaUtils:ThreadInProgress("SetSuggestedItemGuides")  do
                coroutine.yield()
            end
            CacheItemsForGearFinderIsInQueue = false
        
            if CacheItemsForGearFinder_invoked then
                return
            end

            CacheItemsForGearFinder_invoked = true

            InitializeGearFinderData()



            local allGearsAmount = #DGF.allGearIds
            local i = 0;

            local allGearIds = LuaUtils:clone(DGF.allGearIds)
            
            --First gears with numeric gearId
            table.sort(allGearIds, function(a,b)
                if type(b) == "string" and type(a) == "number" then
                    return true
                end
                
                return false
            end) 
            
            while #allGearIds ~= 0 do
                i = i + 1
                
                LuaUtils:RestIfNeeded(true)

                local itemId = tremove(allGearIds, 1)

                if type(itemId) == "string" then
                    local item = DGF:GetItemInfoById(itemId, true)
                    
                    --Speeding upd the caching
                    for j = 1, 100 do
                        if allGearIds[j] then
                           GetItemInfo(allGearIds[j])
                        end
                    end
                    
                    if item then
                        addItem2itemsBySlot(item)
                    end
                else
                    local name = GetItemInfo(itemId)

                    --Available in game cache
                    if name then
                        local item = DGF:GetItemInfoById(itemId, true)
                        if item then
                            addItem2itemsBySlot(item)
                        end
                    end
                end

                local progress = (LuaUtils:Round(100 * i/allGearsAmount/3, 0) * 3)
                if progress == 0 then progress = 3 end
                GearFinderPreloader.TexWrapper.Text:SetText("Preparing "..progress.."%..")
            end

            return "success"

        end,
        --on end
        function()


            DGF:MakeSuggestions()
        end
        , 1, 0.01)
            
        
    end)

end

function DGF:GetSuggesedGearBySlot(invslot, yields, slotButton)

    if not yields then
        yields = 1
    end

    if not DGF.itemsBySlot[invslot] then
        return nil
    end

    local ownedItemsIds = {}

    LuaUtils:foreach(allOwnedItems, function(value, index)
       ownedItemsIds[value.item.info.itemid] = true
    end)

    local level = UnitLevel("player")
    local levelAbove49 = (level > 49)  --no longer needed with patch 7.0 but still handy for armor specilization bonus
    local _, characterClass = UnitClass("player")

    if not DGF.itemsBySlot[invslot] then
        return
    end
    local itemsBelowPlayerLevel = {}
    local itemsAbovePlayerLevel = {}	-- upgrades with restrictions

    local theBestForSlot = DGF:GetTheBestOwnedItemBySlot(invslot, true)

    local amount = 0

    LuaUtils:foreach(DGF.itemsBySlot[invslot], function(a, b)
        amount = amount + 1
    end)

    local filters = DGF:GetDifficultyFilters()

    slotButton.middleLabel:SetText("Loading...")
    slotButton.itemTexture:Hide()

    local i = 0
    LuaUtils:foreach(DGF.itemsBySlot[invslot], function(item, itemId)
            i = i + 1
            if amount > 0 then
                slotButton.bottomLabel:SetText("|cFF888888"..(LuaUtils:Round(100 * i/amount/5, 0) * 5).."%|r")
            end

            local uniqueInventorySlot = GetDefaultUniqueInventorySlot(item.info.equipslot)

            LuaUtils:RestIfNeeded(true)

            local tooLowPlayerLevel = ((item.info.reqlevel ~= nil and item.info.reqlevel ~= 0 and level < item.info.reqlevel)
            or (item.info.reqlevelByQuest ~= nil and item.info.reqlevelByQuest ~= 0 and level < item.info.reqlevelByQuest))

            --Filtering already owned:
            local itemAlreadyOwned = ownedItemsIds[item.info.itemid]
            --Filtering by difficulty:
            local passedByFilter = false
            local difficulties = DGF.gearId2PossibleDifficulties_map[item.info.itemid]
            if difficulties == nil then
                difficulties = {}
            end
            LuaUtils:foreach(difficulties, function(v, difficultyId)
                if difficultyId == "empty-difficulty" or filters[difficultyId] then
                    passedByFilter = true
                    return "break"
                end
            end)
            
            local passedByLevelRange = true
            
            if DugisGearFinder.gearId2LevelRange[itemId] then
                local levelMin = DugisGearFinder.gearId2LevelRange[itemId][1]
                local levelMax = DugisGearFinder.gearId2LevelRange[itemId][2]
                
                if levelMax and level > levelMax then
                    passedByLevelRange = false
                end
                
                if levelMin and level < levelMin then
                    passedByLevelRange = false
                end
            end            

            local passedByArmorSpecBonusExclusion = true
            local slot = DGF:Slot2VirtualSlot(item.info.equipslot)

            if levelAbove49 and IsArmorSpecSlot(slot) then --no longer needed with patch 7.0 but still handy for armor specilization bonus
                if (characterClass == "SHAMAN" or characterClass == "HUNTER") and item.info.subclass ~= "Mail" then
                    --score = score - 50
                    --Please comment out the line below in case the item should not be completely excluded but just positioned 50 scores below. The value 50 can be also adjusted.
                    passedByArmorSpecBonusExclusion = false
                end
                if (characterClass == "PALADIN" or characterClass == "WARRIOR") and item.info.subclass ~= "Plate" then
                    --score = score - 50
                    --Please comment out the line below in case the item should not be completely excluded but just positioned 50 scores below. The value 50 can be also adjusted.
                    passedByArmorSpecBonusExclusion = false
                end
                if (characterClass == "DRUID" or characterClass == "ROGUE" or characterClass == "MONK") and item.info.subclass ~= "Leather" then
                    --score = score - 50
                    --Please comment out the line below in case the item should not be completely excluded but just positioned 50 scores below. The value 50 can be also adjusted.
                    passedByArmorSpecBonusExclusion = false
                end			
            end

            --Filtering by option "Search for quest gears"
            local passedByQuestsGears = itemId ~= nil and ((DGF.gearId2Quests_map[itemId] and (DGF.gearId2Quests_map == nil or (
            DGV:UserSetting(DGV_GEARS_FROM_QUEST_GUIDES) == true
            or not DGF.gearId2Quests_map[itemId].amountMoreThan0)) ) or (DGF.gearId2isReputation and DGF.gearId2isReputation[itemId] == true) )  

            --Filtering by already existing the best score

            if not itemAlreadyOwned
            and DGF:CanBeGearObtaind(itemId)
            and passedByFilter
            and passedByQuestsGears
            and passedByArmorSpecBonusExclusion
            and passedByLevelRange
            then
				LuaUtils:RestIfNeeded(true)
				LuaUtils:WaitForCombatEnd()
            
                local score = CalculateScoreForGearFinder(itemId, GetSpecialization(), nil, level, uniqueInventorySlot)
                local rightScore = true
                if theBestForSlot and theBestForSlot.score >= score then
                  --todo test
                     rightScore = false
                end

                if rightScore then
                    if tooLowPlayerLevel then
                        tinsert (itemsAbovePlayerLevel,{item=item,score=score})
                    else
                        --if rightScore then
                        tinsert (itemsBelowPlayerLevel,{item=item,score=score})
                      --  end
                    end
                end
            else
        end
    end)

    --Sorting itemsBelowPlayerLevel by score (from hight to low)  {highest, ..., lowest}
    table.sort(itemsBelowPlayerLevel, function(a,b)
        return a.score > b.score
    end)

     --Sorting itemsAbovePlayerLevel by required level  Sorted from low to high
    table.sort(itemsAbovePlayerLevel, function(a,b)
        local lvla = a.item.info.reqlevel
        local lvlb = b.item.info.reqlevel

        if a.item.info.reqlevelByQuest ~= nil then
            lvla = a.item.info.reqlevelByQuest
        end

        if b.item.info.reqlevelByQuest ~= nil then
           lvlb = b.item.info.reqlevelByQuest
        end

        if lvla == lvlb then
            return a.score > b.score
        end

        return lvla < lvlb
    end)
    DGF:Print("-------------------------")
    DGF:Print("--SET  \"Below\" of items: ",invslot,"  (please see google doc, possessed are excluded, limit "..listItemsLimit.." items, so some may not be displayed)")
    for i=1, #itemsBelowPlayerLevel do
        if i < listItemsLimit then
            DGF:Print("#",i, invslot,  ItemName(itemsBelowPlayerLevel[i]), itemsBelowPlayerLevel[i].item.info.itemid, "SCORE: ", itemsBelowPlayerLevel[i].score, " Req lvl:", itemsBelowPlayerLevel[i].item.info.reqlevel, " Req lvl by guide:", itemsBelowPlayerLevel[i].item.info.reqlevelByQuest  )
        end
    end
    DGF:Print("--SET \"Above\" of items: ", invslot,"  (please see google doc, possessed are excluded, limit "..listItemsLimit.." items, so some may not be displayed)")
    for i=1, #itemsAbovePlayerLevel do
        if i < listItemsLimit then
            DGF:Print("#",i, invslot, ItemName(itemsAbovePlayerLevel[i]), itemsAbovePlayerLevel[i].item.info.itemid, "SCORE: ", itemsAbovePlayerLevel[i].score, " Req lvl:", itemsAbovePlayerLevel[i].item.info.reqlevel, " Req lvl by guide:", itemsAbovePlayerLevel[i].item.info.reqlevelByQuest   )
        end
    end

    -- STEP 1 (https://docs.google.com/document/d/1pPHzCCmkcLuFGGat8qZJTc54uPpldOFJWSlH8aoa610/edit)

    if #itemsBelowPlayerLevel > 0 then
        --todo descruption - log
        DGF:Print("STEP 1 (the best possessed for slot doesn't exist)...")
        DGF:Print("**** SUGGESTED GUIDE: ",invslot, ItemName(itemsBelowPlayerLevel[1]), itemsBelowPlayerLevel[1].item.info.itemid, "  Req lvl:", itemsBelowPlayerLevel[1].item.info.reqlevel, " Req lvl by guide:", itemsBelowPlayerLevel[1].item.info.reqlevelByQuest )

        local top5Suggestions = {}
        for i=1, 5 do
            if itemsBelowPlayerLevel[i] then
                top5Suggestions[#top5Suggestions + 1] = itemsBelowPlayerLevel[i]
            end
        end

        if #top5Suggestions < 5 and #itemsAbovePlayerLevel > 0 then
            for i = 1, 5 do
                if #top5Suggestions < 5 and itemsAbovePlayerLevel[i] then
                    top5Suggestions[#top5Suggestions + 1] = itemsAbovePlayerLevel[i]
                end
            end
        end

        return itemsBelowPlayerLevel[1], top5Suggestions
    end

    -- STEP 2
    if #itemsAbovePlayerLevel > 0 then
        DGF:Print("STEP 2")
        DGF:Print("**** SUGGESTED GUIDE: ", invslot,  ItemName(itemsAbovePlayerLevel[1])..(" Req lvl: "..itemsAbovePlayerLevel[1].item.info.reqlevel.." Req lvl by guide: ".. (itemsAbovePlayerLevel[1].item.info.reqlevelByQuest or "nil")), itemsAbovePlayerLevel[1].item.info.itemid)

        local top5Suggestions = {}
        for i=1, 5 do
            if itemsAbovePlayerLevel[i] then
                top5Suggestions[#top5Suggestions + 1] = itemsAbovePlayerLevel[i]
            end
        end
        return  itemsAbovePlayerLevel[1], top5Suggestions
    end
end

local inSetSuggestedItemGuides = false

function DGF:SetSuggestedItemGuides()

    if inSetSuggestedItemGuides then
        return
    end

    inSetSuggestedItemGuides = true
    DGF:HideExtraButtonsFrame()

    LuaUtils.Profiler:Start("SetSuggestedItemGuides")
    ----------------to be optimized

    GearFinderPreloader.TexWrapper.Text:SetText("Searching for gears")

    local yields = CALCULATIONS_TIME_FOR_FILLED_CACHE
    if not DugisCharacterCache.CalculateScore_cache_v11.hasItems then
        yields = CALCULATIONS_TIME_FOR_EMPTY_CACHE
    end

    LuaUtils.Profiler:Start("Searching for gears")
    LuaUtils:foreach(itemButtons, function(slotButton)

        local slot = slotButton.slot
        local suggestedItem, top5suggestions = DGF:GetSuggesedGearBySlot(slot, yields, slotButton)

        slotButton.suggestedGuide = nil

        if suggestedItem then
            local theBestGuide = DGF:GetTheBestGuideForGearId(suggestedItem.item.info.itemid, false, yields)
            local shortName = ItemName(suggestedItem)
            local slotText = DGF:LocalizeSlot(slotButton.slot)

            local requiredLevelInfo = ""

            if not DGF:PlayerHasEnoughLevel(suggestedItem) then

                local lvl = suggestedItem.item.info.reqlevel

                if suggestedItem.item.info.reqlevelByQuest ~= nil then
                    lvl = suggestedItem.item.info.reqlevelByQuest
                end

                if string.len(slotText) > 15 then
                    requiredLevelInfo = " |c00FF0000@L"..lvl.."|r"
                else
                    requiredLevelInfo = " |c00FF0000@ Level "..lvl.."|r"
                end
            end

            local r, g, b, hex = GetItemQualityColor(suggestedItem.item.info.quality)
            slotButton.middleLabel:SetText("|c"..hex..suggestedItem.item.info.name.."|r")
            local formattedTitle = theBestGuide
            if DugisGuideViewer.GetFormattedTitle then
               formattedTitle = DugisGuideViewer:GetFormattedTitle(theBestGuide)
            end

            slotButton.suggestedGuide = theBestGuide
            if formattedTitle then
                slotButton.bottomLabel:SetText("|cFFFFFFFF" .. formattedTitle .. "|r")
            end
            slotButton.bottomLabel:SetWidth(130)
            slotButton.middleLabel:SetWidth(130)

            slotButton.itemTexture:SetTexture( ItemTexture(suggestedItem))
            slotButton.itemTexture:Show()

            slotButton.topLabel:SetText(slotText..requiredLevelInfo)

            slotButton.suggestion = suggestedItem
            slotButton.top5suggestions = top5suggestions
            slotButton.middleLabel:Show()
        else
            local slotText = DGF:LocalizeSlot(slot)
            slotButton.topLabel:SetText(slotText)
            slotButton.bottomLabel:SetText("|cFF888888Cannot find better gear|r")
            slotButton.middleLabel:Hide()
            slotButton.top5suggestions = {}
            slotButton.suggestion = nil
            slotButton.itemTexture:Hide()
        end

        if slotButton.top5suggestions and #slotButton.top5suggestions >= 2 then
            slotButton.moreButton:Show()
        else
            slotButton.moreButton:Hide()
        end
    end)
    ----------------END to be optimized
    LuaUtils.Profiler:Stop("Searching for gears")

    --Updating the best
    LuaUtils.Profiler:Start("Updating the best")

    LuaUtils.Profiler:Start("Searching for guide")

    GearFinderPreloader.TexWrapper.Text:SetText("Searching for guide")


    local atLeastOneBelowPlayerLevel = false

    LuaUtils:foreach(itemButtons, function(itemButton)
        if itemButton.suggestedGuide and DGF:PlayerHasEnoughLevel(itemButton.suggestion) then
            atLeastOneBelowPlayerLevel = true
        end
    end)

    local scoreByGuide = {}
    local theBestGuideScore = nil
    local theBestGuide = nil
    ----------------------------------
    --Searching for suggested guide by the best score
--   LuaUtils:foreach(itemButtons, function(itemButton)
--       if itemButton.suggestedGuide and (DGF:PlayerHasEnoughLevel(itemButton.suggestion) or (atLeastOneBelowPlayerLevel == false)) then
--           local score = itemButton.suggestion.score
--           if theBestGuideScore == nil or theBestGuideScore < score then
--               theBestGuideScore = score
--               theBestGuide = itemButton.suggestedGuide
--           end
--       end
--   end)   
 
    --Searching for suggested guide by the highest score sum of suggested gears
    --{"guide title 1" => 30052, "guide title 2" => 3452}
    local guide2gearsScoreSum = {}
    LuaUtils:foreach(itemButtons, function(itemButton)
        if itemButton.suggestedGuide and (DGF:PlayerHasEnoughLevel(itemButton.suggestion) or (atLeastOneBelowPlayerLevel == false)) then
            if not guide2gearsScoreSum[itemButton.suggestedGuide] then
                guide2gearsScoreSum[itemButton.suggestedGuide] = itemButton.suggestion.score
            else
                guide2gearsScoreSum[itemButton.suggestedGuide] = guide2gearsScoreSum[itemButton.suggestedGuide] + itemButton.suggestion.score
            end
        end
    end)
    
    local theHighestSum = nil
    LuaUtils:foreach(guide2gearsScoreSum, function(sum, guide)
        if theHighestSum == nil or sum > theHighestSum then
            theHighestSum = sum
            theBestGuide = guide
        end
    end)
    
    -----------------------------------

    DugisGearFinderFrame.suggestedGuide.suggestedGuideTitle  = theBestGuide

    LuaUtils.Profiler:Stop("Searching for guide")
    if DugisGearFinderFrame.suggestedGuide.suggestedGuideTitle then
        local formattedTitle = DugisGearFinderFrame.suggestedGuide.suggestedGuideTitle
        if DugisGuideViewer.GetFormattedTitle then
           formattedTitle = DugisGuideViewer:GetFormattedTitle(DugisGearFinderFrame.suggestedGuide.suggestedGuideTitle)
        end

        DugisGearFinderFrame.suggestedGuideSubtitle:SetText("|cFFFFFFFF"..formattedTitle.."|r")
        DugisGearFinderFrame.suggestedGuideSubtitle:SetWordWrap(true)
        DugisGearFinderFrame.suggestedGuideSubtitle:SetWidth(150)
        DugisGearFinderFrame.suggestedGuideSubtitle:SetJustifyH("LEFT")
    else
        DugisGearFinderFrame.suggestedGuideSubtitle:SetText("-")
    end

    LuaUtils:foreach(itemButtons, function(box, index)
        box:SetPoint("TOPLEFT", 0, -index * boxSize - DugisGearFinderFrame.suggestedGuideSubtitle:GetHeight() + 20)
    end)

    LuaUtils.Profiler:Stop("Updating the best")


    LuaUtils.Profiler:Stop("SetSuggestedItemGuides")

    inSetSuggestedItemGuides = false
end


local InitializeGearFinderUI_initialized = false

function DGF:UpdatetabsPosition()
    local isZygorLoaded = DugisGuideViewer.zygorloaded

    local tabsShift = 0

    if isZygorLoaded then
        tabsShift = 24
    end

    PaperDollSidebarTab3:SetPoint("BOTTOMRIGHT",PaperDollSidebarTabs,"BOTTOMRIGHT",-60 - tabsShift, 0)
end


function DGF:CreateGearFinderTabButton()
    if DugisGearFinderButton then
        return
    end

    local isZygorLoaded = DugisGuideViewer.zygorloaded

    tinsert(PAPERDOLL_SIDEBARS,{name='Dugi Guides Gear Finder', frame = "DugisGearFinderFrame", icon="Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\UpgradeArrow", texCoords = {0, 1, 0,1} })

    local tabIndex = 4
    local buttonLeftShift = 4

    if isZygorLoaded then
        tabIndex = 5
        buttonLeftShift = 41
    end

    PaperDollSidebarTabs:SetWidth(168 + 30)
    DGF:UpdatetabsPosition()

    CreateFrame("Button", "DugisGearFinderButton", PaperDollSidebarTabs, "PaperDollSidebarTabTemplate", tabIndex);
    DugisGearFinderButton:SetPoint("LEFT", PaperDollSidebarTab3, "RIGHT", buttonLeftShift, 0)
    DugisGearFinderButton:SetScript("OnLoad", nil)
    DugisGearFinderButton:HookScript("OnClick", function()
        if LuaUtils:ThreadInProgress("SetSuggestedItemGuides") or LuaUtils:ThreadInProgress("CacheItemsForGearFinder") then
            return
        end

        DGF:CacheItemsForGearFinder()
    end)
    DugisGearFinderButton.Icon:SetSize(27, 27)
    DugisGearFinderButton.Icon:SetPoint("BOTTOM", DugisGearFinderButton, "BOTTOM", 1, 2)
end

local wasGearFinderInitialize = false


function DGF:UpdateTabsForGearFinder()
    if DugisGuideViewer.chardb.EssentialsMode == 1 or not DugisGuideViewer:GuideOn() or not DugisGuideViewer:UserSetting(DGV_ENABLEDGEARFINDER) then
        if DugisGearFinderButton ~= nil then
            DugisGearFinderButton:Hide()
        end
        PaperDollSidebarTab3:SetPoint("BOTTOMRIGHT",PaperDollSidebarTabs,"BOTTOMRIGHT",-60, 0)
        return
    end

    DGF:CreateGearFinderTabButton()
    DugisGearFinderButton:Show()
    DGF:UpdatetabsPosition()

    DGF:CreateExtraItemsFrame()
    DGF:GearFinderTooltipFrame()

end

function InitializeGearFinder(invokedByIUChange)
    if DugisGuideViewer.chardb.EssentialsMode ~= 1 and DugisGuideViewer:GuideOn() and DugisGuideViewer:UserSetting(DGV_ENABLEDGEARFINDER) then
        DGF:InitializeGearFinderUI()

        CharacterFrame:HookScript("OnShow", function()
            DGF:UpdateTabsForGearFinder()
            if GearFinderTooltipFrame then
                GearFinderTooltipFrame:Hide()
            end
        end)

        if invokedByIUChange then
            HideUIPanel(CharacterFrame)
        end
    end
end


