local filters = {}
local EasyScrap = EasyScrap
local NOT = '|cFFFF0000not|r'
local IS = '|cFF00FF00is|r'
local f


local invTypes = {}
invTypes['INVTYPE_RANGED'] = INVTYPE_RANGED
invTypes['INVTYPE_THROWN'] = INVTYPE_THROWN
invTypes['INVTYPE_ROBE'] = INVTYPE_ROBE
invTypes['INVTYPE_CHEST'] = INVTYPE_CHEST
invTypes['INVTYPE_WEAPONMAINHAND'] = INVTYPE_WEAPONMAINHAND
invTypes['INVTYPE_NECK'] = INVTYPE_NECK
invTypes['INVTYPE_QUIVER'] = INVTYPE_QUIVER
invTypes['INVTYPE_WEAPONMAINHAND_PET'] = INVTYPE_WEAPONMAINHAND_PET
invTypes['INVTYPE_RANGEDRIGHT'] = INVTYPE_RANGEDRIGHT
invTypes['INVTYPE_2HWEAPON'] = INVTYPE_2HWEAPON
invTypes['INVTYPE_HOLDABLE'] = INVTYPE_HOLDABLE
invTypes['INVTYPE_WEAPONOFFHAND'] = INVTYPE_WEAPONOFFHAND
invTypes['INVTYPE_SHIELD'] = INVTYPE_SHIELD
invTypes['INVTYPE_BAG'] = INVTYPE_BAG
invTypes['INVTYPE_TRINKET'] = INVTYPE_TRINKET
invTypes['INVTYPE_WAIST'] = INVTYPE_WAIST
invTypes['INVTYPE_HEAD'] = INVTYPE_HEAD
invTypes['INVTYPE_WEAPON'] = INVTYPE_WEAPON
invTypes['INVTYPE_NON_EQUIP'] = INVTYPE_NON_EQUIP
invTypes['INVTYPE_LEGS'] = INVTYPE_LEGS
invTypes['INVTYPE_RELIC'] = INVTYPE_RELIC
invTypes['INVTYPE_TABARD'] = INVTYPE_TABARD
invTypes['INVTYPE_FEET'] = INVTYPE_FEET
invTypes['INVTYPE_SHOULDER'] = INVTYPE_SHOULDER
invTypes['INVTYPE_CLOAK'] = INVTYPE_CLOAK
invTypes['INVTYPE_WRIST'] = INVTYPE_WRIST
invTypes['INVTYPE_HAND'] = INVTYPE_HAND
invTypes['INVTYPE_FINGER'] = INVTYPE_FINGER
invTypes['INVTYPE_BODY'] = INVTYPE_BODY


local function createFilterFrame(filterName, height)
    local f = CreateFrame('Frame', nil, EasyScrapEditFilterContentFrame)
    f:SetSize(f:GetParent():GetWidth()-14, height)
    
    f.deleteButton = CreateFrame('Button', nil, f, 'UIPanelCloseButton')
    f.deleteButton:SetPoint('TOPRIGHT', 2, 4)
    f.deleteButton:SetScale(0.7, 0.7)  
    f.deleteButton:SetScript('OnClick', function(self) EasyScrap.editFilterFrame.deleteRuleEntry(self.ruleID) end)   
    
    local header = CreateFrame('Frame', nil, f)
    header:SetSize(f:GetWidth(), 18)
    header:SetPoint('TOP')

    header.text = header:CreateFontString()
    header.text:SetFontObject("GameFontNormal")
    header.text:SetText(filterName)
    header.text:SetPoint('CENTER', f, 'TOP', 0, 0)
    local r,g,b = header.text:GetTextColor()
    
    f.bodyText = f:CreateFontString()
    f.bodyText:SetFontObject("GameFontNormalSmall")
    f.bodyText:SetPoint('TOPLEFT', 8, -12)
    f.bodyText:SetTextColor(1, 1, 1)
    f.bodyText:SetJustifyH("LEFT")
    
    local lines = {}  
    lines.tl = f:CreateTexture(nil, 'BACKGROUND')
    lines.tl:SetColorTexture(r,g,b, 0.8)
    lines.tl:SetPoint('TOPLEFT', f, 'TOPLEFT', 2, 1)
    lines.tl:SetPoint('BOTTOMRIGHT', header.text, 'LEFT', -2, 0)

    lines.tr = f:CreateTexture(nil, 'BACKGROUND')
    lines.tr:SetColorTexture(r,g,b, 0.8)
    lines.tr:SetPoint('TOPRIGHT', f, 'TOPRIGHT', -2, 1)
    lines.tr:SetPoint('BOTTOMLEFT', header.text, 'RIGHT', 2, 0)
    
    lines.l = f:CreateTexture(nil, 'BACKGROUND')
    lines.l:SetColorTexture(r,g,b, 0.8)
    lines.l:SetPoint('TOPLEFT', lines.tl, 'TOPLEFT', 0, 0) 
    lines.l:SetPoint('BOTTOMRIGHT', f, 'BOTTOMLEFT', 1, 0) 
 
    lines.r = f:CreateTexture(nil, 'BACKGROUND')
    lines.r:SetColorTexture(r,g,b, 0.8)
    lines.r:SetPoint('TOPRIGHT', lines.tr, 'TOPRIGHT', 0, 0) 
    lines.r:SetPoint('BOTTOMLEFT', f, 'BOTTOMRIGHT', -1, 0) 
    
    lines.b = f:CreateTexture(nil, 'BACKGROUND')
    lines.b:SetColorTexture(r,g,b, 0.8)
    lines.b:SetPoint('TOPLEFT', lines.l, 'BOTTOMLEFT', 0, 1) 
    lines.b:SetPoint('BOTTOMRIGHT', lines.r, 'BOTTOMRIGHT', 0, 0) 

    return f
end


--[[---------------------------------------------------------------------------------------------------------------------------------------
ITEMLEVEL
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['itemLevel'] = {}
filters['itemLevel'].menuText = '物品等級'
filters['itemLevel'].data = {0, 999}
filters['itemLevel'].filterMessage = '物品等級不在0到999的範圍內'

f = createFilterFrame('Item Level', 54)
f.bodyText:SetText('最低物品等級:')
f.bodyText:SetPoint('TOPLEFT', 8, -14)
f.bodyText2 = f:CreateFontString()
f.bodyText2:SetFontObject("GameFontNormalSmall")
f.bodyText2:SetPoint('TOPLEFT', 8, -36)
f.bodyText2:SetTextColor(1, 1, 1)
f.bodyText2:SetText("最高物品等級: ")
f.bodyText2:SetJustifyH("LEFT")

f.customData = {}
f.customData[1] = CreateFrame('EditBox', 'ar2', f, 'EasyScrapEditBoxTemplate')
f.customData[1]:SetPoint('LEFT', f.bodyText, 'LEFT', 120, 0)
f.customData[1]:SetMaxLetters(3)
f.customData[1]:SetNumeric(true)

f.customData[2] = CreateFrame('EditBox', 'ar1', f, 'EasyScrapEditBoxTemplate')
f.customData[2]:SetPoint('LEFT', f.bodyText2, 'LEFT', 120, 0)
f.customData[2]:SetMaxLetters(3)
f.customData[2]:SetNumeric(true)

function f:populateData(data)
    self.customData[1]:SetText(tostring(data[1]))
    self.customData[2]:SetText(tostring(data[2]))
end

function f:saveData(customFilterIndex)
    local minLevel = tonumber(self.customData[1]:GetText())
    if not minLevel then minLevel = 0 DEFAULT_CHAT_FRAME:AddMessage('快易銷毀: 沒找到最低等級物品，預設為0。') end
    local maxLevel = tonumber(self.customData[2]:GetText())
    if not maxLevel then maxLevel = 999 DEFAULT_CHAT_FRAME:AddMessage('快易銷毀: 沒找到最高等級物品，預設為999。') end
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[1] = minLevel
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[2] = maxLevel
end

filters['itemLevel'].frame = f

filters['itemLevel'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data

    local isMatch = (item.itemLevel >= filterData[1] and item.itemLevel <= filterData[2])
    if not isMatch then filters['itemLevel'].filterMessage = 'Item level is not in range of '..filterData[1]..' to '..filterData[2]..'.' end
    return isMatch
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
ITEMNAME
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['itemName'] = {}
filters['itemName'].menuText = '物品名稱'
filters['itemName'].data = {'?'}
filters['itemName'].filterMessage = '物品名稱不包含文字。'

f = createFilterFrame('Item Name', 32)
f.bodyText:SetText('物品名稱包含文字:')
f.bodyText:SetPoint('TOPLEFT', 8, -14)

f.customData = {}
f.customData[1] = CreateFrame('EditBox', 'ar2', f, 'EasyScrapEditBoxTemplate')
f.customData[1]:SetPoint('LEFT', f.bodyText, 'RIGHT', 8, 0)
f.customData[1]:SetMaxLetters(22)
f.customData[1]:SetWidth(96)

function f:populateData(data)
    self.customData[1]:SetText(data[1])
end

function f:saveData(customFilterIndex)
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[1] = self.customData[1]:GetText()
end

filters['itemName'].frame = f

filters['itemName'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data

    local matchResult = string.find(string.lower(item.itemName), string.lower(filterData[1]))
    if not matchResult then filters['itemName'].filterMessage = '物品名稱不包含文字 "'..filterData[1]..'".' end
    return matchResult
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
AZERITE GEAR
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['azeriteArmor'] = {}
filters['azeriteArmor'].menuText = '艾澤萊護甲'
filters['azeriteArmor'].data = {[1] = true, [2] = false}
filters['azeriteArmor'].filterMessage = '物品為???艾澤萊護甲'

f = createFilterFrame('Azerite Armor', 50)
f.checkButtons = {}
f.checkButtons[1] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[1]:SetPoint('TOPLEFT', 8, -8)
f.checkButtons[1].text:SetText('只顯示艾澤萊護甲物品。')
f.checkButtons[2] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[2]:SetPoint('TOPLEFT', 8, -28)
f.checkButtons[2].text:SetText('隱藏所有艾澤萊護甲物品。')

f.checkButtons[1]:HookScript('OnClick', function(self) filters['azeriteArmor'].frame.checkButtons[2]:SetChecked(not self:GetChecked()) end)
f.checkButtons[2]:HookScript('OnClick', function(self) filters['azeriteArmor'].frame.checkButtons[1]:SetChecked(not self:GetChecked()) end)

function f:populateData(data)
    self.checkButtons[1]:SetChecked(data[1])
    self.checkButtons[2]:SetChecked(data[2])
end

function f:saveData(customFilterIndex)
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[1] = self.checkButtons[1]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[2] = self.checkButtons[2]:GetChecked()
end

filters['azeriteArmor'].frame = f

filters['azeriteArmor'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data

    if filterData[1] then       
        local isMatch = C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItemByID(item.itemLink)
        if not isMatch then filters['azeriteArmor'].filterMessage = '物品非艾澤萊護甲。' end
        return isMatch
    else
        local isMatch = not C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItemByID(item.itemLink)
        if not isMatch then filters['azeriteArmor'].filterMessage = '物品是艾澤萊護甲。' end
        return isMatch
    end
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
ITEM QUALITY
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['itemQuality'] = {}
filters['itemQuality'].menuText = '物品品質'
filters['itemQuality'].data = {[1] = true, [2] = true, [3] = true, [4] = true}
filters['itemQuality'].filterMessage = '物品品質未選擇。'

f = createFilterFrame('Item Quality', 50)
f.checkButtons = {}
f.checkButtons[1] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[1]:SetPoint('TOPLEFT', 8, -8)
f.checkButtons[1].text:SetText(ITEM_QUALITY_COLORS[1].hex..'['..ITEM_QUALITY1_DESC..']|r')
f.checkButtons[2] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[2]:SetPoint('TOPLEFT', 128, -8)
f.checkButtons[2].text:SetText(ITEM_QUALITY_COLORS[2].hex..'['..ITEM_QUALITY2_DESC..']|r')
f.checkButtons[3] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[3]:SetPoint('TOPLEFT', 8, -28)
f.checkButtons[3].text:SetText(ITEM_QUALITY_COLORS[3].hex..'['..ITEM_QUALITY3_DESC..']|r')
f.checkButtons[4] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[4]:SetPoint('TOPLEFT', 128, -28)
f.checkButtons[4].text:SetText(ITEM_QUALITY_COLORS[4].hex..'['..ITEM_QUALITY4_DESC..']|r')

function f:populateData(data)
    self.checkButtons[1]:SetChecked(data[1])
    self.checkButtons[2]:SetChecked(data[2])
    self.checkButtons[3]:SetChecked(data[3])
    self.checkButtons[4]:SetChecked(data[4])
end

function f:saveData(customFilterIndex)
    for k, v in pairs(self.checkButtons) do
        EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[k] = v:GetChecked()
    end
end

filters['itemQuality'].frame = f

filters['itemQuality'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data

    local isMatch = filterData[item.itemQuality]
    if not isMatch then filters['itemQuality'].filterMessage = '物品品質非過濾器所選其中之一。' end
    return isMatch
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
ITEM BIND TYPE
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['bindType'] = {}
filters['bindType'].menuText = '綁定類型'
filters['bindType'].data = {[1] = true, [2] = true, [4] = true}
filters['bindType'].filterMessage = '物品綁定類型非所選類型之一。'

f = createFilterFrame('Bind Type', 70)
f.checkButtons = {}
f.checkButtons[1] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[1]:SetPoint('TOPLEFT', 8, -8)
f.checkButtons[1].text:SetText(ITEM_BIND_ON_EQUIP)
f.checkButtons[2] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[2]:SetPoint('TOPLEFT', 8, -28)
f.checkButtons[2].text:SetText(ITEM_SOULBOUND)
f.checkButtons[3] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[3]:SetPoint('TOPLEFT', 8, -48)
f.checkButtons[3].text:SetText(ITEM_BIND_QUEST)

function f:populateData(data)
    self.checkButtons[1]:SetChecked(data[2]) --bop
    self.checkButtons[2]:SetChecked(data[1]) --boe
    self.checkButtons[3]:SetChecked(data[4]) --quest
end

function f:saveData(customFilterIndex)
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[2] = self.checkButtons[1]:GetChecked() --bop
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[1] = self.checkButtons[2]:GetChecked() --boe
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[4] = self.checkButtons[3]:GetChecked() --quest
end

filters['bindType'].frame = f

--1 = BOP/SOULBOUND
--2 = BOE
--4 = QUESTITEM
local btT = {ITEM_SOULBOUND, ITEM_BIND_ON_EQUIP, ITEM_BIND_ON_USE, ITEM_BIND_QUEST}

filters['bindType'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data
    local isMatch
    if item.bindType == 2 then
        --Silly that you can't find soulbound state without reading tooltip
        EasyScrap.tooltipReader:ClearLines()      
        EasyScrap.tooltipReader:SetBagItem(item.bag, item.slot)
        local lines = EasyScrap.tooltipReader:NumLines()
        if lines > 5 then lines = 5 end
        local isBoE = true
        for i = 1, lines do
           local text = _G["EasyScrapTooltipReaderTextLeft"..i]:GetText()                  
           if text == ITEM_SOULBOUND then
              isBoE = false
           end
        end
        
        if isBoE then
            isMatch = filterData[2]
            if not isMatch then filters['bindType'].filterMessage = '物品綁定類型是 '..ITEM_BIND_ON_EQUIP end
            return isMatch
        else
            isMatch = filterData[1]
            if not isMatch then filters['bindType'].filterMessage = '物品綁定類型是 '..ITEM_SOULBOUND end
            return isMatch           
        end
    else
        isMatch = filterData[item.bindType]
        if not isMatch then filters['bindType'].filterMessage = '物品綁定類型是 '..btT[item.bindType] end
        return isMatch       
    end
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
ARMOR TYPE
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['armorType'] = {}
filters['armorType'].menuText = '護甲類型'
filters['armorType'].data = {[LE_ITEM_ARMOR_CLOTH] = true, [LE_ITEM_ARMOR_LEATHER] = true, [LE_ITEM_ARMOR_MAIL] = true, [LE_ITEM_ARMOR_PLATE] = true, [LE_ITEM_ARMOR_SHIELD] = true, [LE_ITEM_ARMOR_GENERIC] = true}
filters['armorType'].filterMessage = '物品非所選類型其中之一。'

f = createFilterFrame('Armor Type', 72)
f.checkButtons = {}
f.checkButtons[1] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[1]:SetPoint('TOPLEFT', 8, -8)
f.checkButtons[1].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_CLOTH))
f.checkButtons[2] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[2]:SetPoint('TOPLEFT', 128, -8)
f.checkButtons[2].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_LEATHER))
f.checkButtons[3] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[3]:SetPoint('TOPLEFT', 8, -28)
f.checkButtons[3].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_MAIL))
f.checkButtons[4] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[4]:SetPoint('TOPLEFT', 128, -28)
f.checkButtons[4].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_PLATE))
f.checkButtons[5] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[5]:SetPoint('TOPLEFT', 8, -48)
f.checkButtons[5].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_SHIELD))
f.checkButtons[6] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[6]:SetPoint('TOPLEFT', 128, -48)
f.checkButtons[6].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC))

function f:populateData(data)
    self.checkButtons[1]:SetChecked(data[LE_ITEM_ARMOR_CLOTH])
    self.checkButtons[2]:SetChecked(data[LE_ITEM_ARMOR_LEATHER])
    self.checkButtons[3]:SetChecked(data[LE_ITEM_ARMOR_MAIL])
    self.checkButtons[4]:SetChecked(data[LE_ITEM_ARMOR_PLATE])
    self.checkButtons[5]:SetChecked(data[LE_ITEM_ARMOR_SHIELD])
    self.checkButtons[6]:SetChecked(data[LE_ITEM_ARMOR_GENERIC])
end

function f:saveData(customFilterIndex)
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[LE_ITEM_ARMOR_CLOTH] = self.checkButtons[1]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[LE_ITEM_ARMOR_LEATHER] = self.checkButtons[2]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[LE_ITEM_ARMOR_MAIL] = self.checkButtons[3]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[LE_ITEM_ARMOR_PLATE] = self.checkButtons[4]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[LE_ITEM_ARMOR_SHIELD] = self.checkButtons[5]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[LE_ITEM_ARMOR_GENERIC] = self.checkButtons[6]:GetChecked()
end

filters['armorType'].frame = f

filters['armorType'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data
    
    if item.itemClassID == LE_ITEM_CLASS_ARMOR then
        local isMatch = filterData[item.itemSubClassID]
        if isMatch then
            return true
        else
            filters['armorType'].filterMessage = 'armor type is '..GetItemSubClassInfo(LE_ITEM_CLASS_ARMOR, item.itemSubClassID)       
        end
    else
        return true
    end
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
WEAPON TYPE
[LE_ITEM_CLASS_WEAPON]
[LE_ITEM_WEAPON_AXE1H]
[LE_ITEM_WEAPON_AXE2H]
[LE_ITEM_WEAPON_BOWS]
[LE_ITEM_WEAPON_GUNS]
[LE_ITEM_WEAPON_MACE1H]
[LE_ITEM_WEAPON_MACE2H]
[LE_ITEM_WEAPON_POLEARM]
[LE_ITEM_WEAPON_SWORD1H]
[LE_ITEM_WEAPON_SWORD2H]
[LE_ITEM_WEAPON_WARGLAIVE]
[LE_ITEM_WEAPON_STAFF]
[LE_ITEM_WEAPON_BEARCLAW]
[LE_ITEM_WEAPON_CATCLAW]
[LE_ITEM_WEAPON_UNARMED]
[LE_ITEM_WEAPON_GENERIC]
[LE_ITEM_WEAPON_DAGGER]
[LE_ITEM_WEAPON_THROWN]
[LE_ITEM_WEAPON_CROSSBOW]
[LE_ITEM_WEAPON_WAND]
[LE_ITEM_WEAPON_FISHINGPOLE]
NUM_LE_ITEM_WEAPONS
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['weaponType'] = {}
filters['weaponType'].menuText = '武器類型'
filters['weaponType'].data = {
[LE_ITEM_WEAPON_AXE1H] = true, --
[LE_ITEM_WEAPON_AXE2H] = true,--
[LE_ITEM_WEAPON_BOWS] = true, --
[LE_ITEM_WEAPON_GUNS] = true, --
[LE_ITEM_WEAPON_MACE1H] = true, --
[LE_ITEM_WEAPON_MACE2H] = true, --
[LE_ITEM_WEAPON_POLEARM] = true, --
[LE_ITEM_WEAPON_SWORD1H] = true, --
[LE_ITEM_WEAPON_SWORD2H] = true, --
[LE_ITEM_WEAPON_WARGLAIVE] = true,
[LE_ITEM_WEAPON_STAFF] = true, --
--[LE_ITEM_WEAPON_BEARCLAW] = true,
--[LE_ITEM_WEAPON_CATCLAW] = true,
[LE_ITEM_WEAPON_UNARMED] = true, --
--[LE_ITEM_WEAPON_GENERIC] = true,
[LE_ITEM_WEAPON_DAGGER] = true, --
--[LE_ITEM_WEAPON_THROWN] = true,
[LE_ITEM_WEAPON_CROSSBOW] = true, --
[LE_ITEM_WEAPON_WAND] = true, --
--[LE_ITEM_WEAPON_FISHINGPOLE] = true,
}
filters['weaponType'].filterMessage = '物品非所選武器類型其中之一。'

f = createFilterFrame('Weapon Type', 308)
f.checkButtons = {}
f.checkButtons[LE_ITEM_WEAPON_AXE1H] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_AXE1H]:SetPoint('TOPLEFT', 8, -8)
f.checkButtons[LE_ITEM_WEAPON_AXE1H].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_AXE1H))
f.checkButtons[LE_ITEM_WEAPON_AXE2H] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_AXE2H]:SetPoint('TOPLEFT', 8, -28)
f.checkButtons[LE_ITEM_WEAPON_AXE2H].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_AXE2H))

f.checkButtons[LE_ITEM_WEAPON_SWORD1H] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_SWORD1H]:SetPoint('TOPLEFT', 8, -48)
f.checkButtons[LE_ITEM_WEAPON_SWORD1H].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_SWORD1H))
f.checkButtons[LE_ITEM_WEAPON_SWORD2H] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_SWORD2H]:SetPoint('TOPLEFT', 8, -68)
f.checkButtons[LE_ITEM_WEAPON_SWORD2H].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_SWORD2H))

f.checkButtons[LE_ITEM_WEAPON_MACE1H] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_MACE1H]:SetPoint('TOPLEFT', 8, -88)
f.checkButtons[LE_ITEM_WEAPON_MACE1H].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_MACE1H))
f.checkButtons[LE_ITEM_WEAPON_MACE2H] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_MACE2H]:SetPoint('TOPLEFT', 8, -108)
f.checkButtons[LE_ITEM_WEAPON_MACE2H].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_MACE2H))

f.checkButtons[LE_ITEM_WEAPON_DAGGER] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_DAGGER]:SetPoint('TOPLEFT', 8, -128)
f.checkButtons[LE_ITEM_WEAPON_DAGGER].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_DAGGER))
f.checkButtons[LE_ITEM_WEAPON_UNARMED] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_UNARMED]:SetPoint('TOPLEFT', 8, -148)
f.checkButtons[LE_ITEM_WEAPON_UNARMED].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_UNARMED))

f.checkButtons[LE_ITEM_WEAPON_POLEARM] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_POLEARM]:SetPoint('TOPLEFT', 8, -168)
f.checkButtons[LE_ITEM_WEAPON_POLEARM].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_POLEARM))
f.checkButtons[LE_ITEM_WEAPON_STAFF] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_STAFF]:SetPoint('TOPLEFT', 8, -188)
f.checkButtons[LE_ITEM_WEAPON_STAFF].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_STAFF))

f.checkButtons[LE_ITEM_WEAPON_BOWS] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_BOWS]:SetPoint('TOPLEFT', 8, -208)
f.checkButtons[LE_ITEM_WEAPON_BOWS].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_BOWS))
f.checkButtons[LE_ITEM_WEAPON_CROSSBOW] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_CROSSBOW]:SetPoint('TOPLEFT', 8, -228)
f.checkButtons[LE_ITEM_WEAPON_CROSSBOW].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_CROSSBOW))

f.checkButtons[LE_ITEM_WEAPON_GUNS] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_GUNS]:SetPoint('TOPLEFT', 8, -248)
f.checkButtons[LE_ITEM_WEAPON_GUNS].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_GUNS))
f.checkButtons[LE_ITEM_WEAPON_WAND] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_WAND]:SetPoint('TOPLEFT', 8, -268)
f.checkButtons[LE_ITEM_WEAPON_WAND].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_WAND))

f.checkButtons[LE_ITEM_WEAPON_WARGLAIVE] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[LE_ITEM_WEAPON_WARGLAIVE]:SetPoint('TOPLEFT', 8, -288)
f.checkButtons[LE_ITEM_WEAPON_WARGLAIVE].text:SetText(GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_WARGLAIVE))


function f:populateData(fData)
    for k,v in pairs(filters['weaponType'].data) do
        self.checkButtons[k]:SetChecked(fData[k])
    end
end

function f:saveData(customFilterIndex)
    for k,v in pairs(filters['weaponType'].data) do
        EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[k] = self.checkButtons[k]:GetChecked()
    end
end

filters['weaponType'].frame = f

filters['weaponType'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data
    
    if item.itemClassID == LE_ITEM_CLASS_WEAPON then
        local isMatch = filterData[item.itemSubClassID]
        if isMatch then
            return true
        else
            filters['weaponType'].filterMessage = '武器類型是 '..GetItemSubClassInfo(LE_ITEM_CLASS_WEAPON, item.itemSubClassID)       
        end
    else
        return true
    end
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
ITEM TYPE
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['itemType'] = {}
filters['itemType'].menuText = '物品類型'
filters['itemType'].data = {[LE_ITEM_CLASS_ARMOR] = true, [LE_ITEM_CLASS_WEAPON] = true}
filters['itemType'].filterMessage = '物品類型非所選物品類型其中之一。'

f = createFilterFrame('Item Type', 30)
f.checkButtons = {}
f.checkButtons[1] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[1]:SetPoint('TOPLEFT', 8, -8)
f.checkButtons[1].text:SetText('Armor')
f.checkButtons[2] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[2]:SetPoint('TOPLEFT', 128, -8)
f.checkButtons[2].text:SetText('Weapon')

function f:populateData(data)
    self.checkButtons[1]:SetChecked(data[LE_ITEM_CLASS_ARMOR])
    self.checkButtons[2]:SetChecked(data[LE_ITEM_CLASS_WEAPON])
end

function f:saveData(customFilterIndex)
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[LE_ITEM_CLASS_ARMOR] = self.checkButtons[1]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[LE_ITEM_CLASS_WEAPON] = self.checkButtons[2]:GetChecked()
end

filters['itemType'].frame = f

filters['itemType'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data
    
    return filterData[item.itemClassID]
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
BONUS STATS
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['bonusStats'] = {}
filters['bonusStats'].menuText = '額外屬性'
filters['bonusStats'].data = {
['40'] = true, --Avoidance 
['43'] = true, --Indestructible
--['1808'] = true, --Socket 
['42'] = true, --Speed
['41'] = true --Leech
}
filters['bonusStats'].filterMessage = '物品沒有所選額外屬性其中之一。'

f = createFilterFrame('Bonus Stats', 92)
f.checkButtons = {}
f.checkButtons['40'] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons['40']:SetPoint('TOPLEFT', 8, -8)
f.checkButtons['40'].text:SetText('Avoidance')
f.checkButtons['43'] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons['43']:SetPoint('TOPLEFT', 8, -28)
f.checkButtons['43'].text:SetText('Indestructible')
f.checkButtons['41'] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons['41']:SetPoint('TOPLEFT', 8, -48)
f.checkButtons['41'].text:SetText('Leech')
--f.checkButtons['1808'] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
--f.checkButtons['1808']:SetPoint('TOPLEFT', 8, -68)
--f.checkButtons['1808'].text:SetText('Socket')
f.checkButtons['42'] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons['42']:SetPoint('TOPLEFT', 8, -68)
f.checkButtons['42'].text:SetText('Speed')


function f:populateData(data)
    for k,v in pairs(filters['bonusStats'].data) do
        self.checkButtons[k]:SetChecked(data[k])
    end
end

function f:saveData(customFilterIndex)
    for k,v in pairs(filters['bonusStats'].data) do
        EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[k] = self.checkButtons[k]:GetChecked()
    end
end

filters['bonusStats'].frame = f

filters['bonusStats'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data
    
    local tempString, unknown1, unknown2, unknown3 = strmatch(item.itemLink, "item:[-%d]-:[-%d]-:[-%d]-:[-%d]-:[-%d]-:[-%d]-:[-%d]-:[-%d]-:[-%d]-:[-%d]-:[-%d]-:[-%d]-:[-%d]-:([-:%d]+):([-%d]-):([-%d]-):([-%d]-)|")
    local bonusIDs = {}
    local upgradeValue
    if tempString then
        if upgradeTypeID and upgradeTypeID ~= "" then
           upgradeValue = tempString:match("[-:%d]+:([-%d]+)")
           bonusIDs = {strsplit(":", tempString:match("([-:%d]+):"))}
        else
           bonusIDs = {strsplit(":", tempString)}
        end
        --4775 bonus ID = azerite power ID 13 active
        for k,v in pairs(bonusIDs) do if v == '4775' or v == '' then table.remove(bonusIDs, k) break end end
    end
    
    local enabledCount = 0
    for k,v in pairs(filterData) do
        if v then enabledCount = enabledCount + 1 end
    end
    
    if enabledCount >= 1 then
        for k,v in pairs(bonusIDs) do
            if filterData[v] then return true end
        end   
        filters['bonusStats'].filterMessage = 'item does not have one of selected bonus stats.'
        return false
    else
        for k,v in pairs(bonusIDs) do
            if filterData[v] ~= nil then return false end
        end
        filters['bonusStats'].filterMessage = 'item has a bonus stat.'
        return true
    end
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
ITEM SLOT
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['itemSlot'] = {}
filters['itemSlot'].menuText = '物品部位'
filters['itemSlot'].data = {
    ['INVTYPE_HEAD'] = true, 
    ['INVTYPE_NECK'] = true, 
    ['INVTYPE_SHOULDER'] = true, 
    ['INVTYPE_CLOAK'] = true, 
    ['INVTYPE_CHEST'] = true, 
    ['INVTYPE_WRIST'] = true, 
    ['INVTYPE_HAND'] = true, 
    ['INVTYPE_WAIST'] = true, 
    ['INVTYPE_LEGS'] = true, 
    ['INVTYPE_FEET'] = true, 
    ['INVTYPE_FINGER'] = true, 
    ['INVTYPE_TRINKET'] = true,
}
filters['itemSlot'].filterMessage = '物品部位非所選部位其中之一。'

local itt = {
    'INVTYPE_HEAD', 
    'INVTYPE_NECK', 
    'INVTYPE_SHOULDER', 
    'INVTYPE_CLOAK', 
    'INVTYPE_CHEST', 
    'INVTYPE_WRIST',
    'INVTYPE_HAND', 
    'INVTYPE_WAIST',
    'INVTYPE_LEGS',
    'INVTYPE_FEET',
    'INVTYPE_FINGER',
    'INVTYPE_TRINKET'
}

f = createFilterFrame('Item Slot', 132)
f.checkButtons = {}
for i = 1, #itt do
    f.checkButtons[itt[i]] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
    f.checkButtons[itt[i]].text:SetText(invTypes[itt[i]]) 
    if i < 7 then
        f.checkButtons[itt[i]]:SetPoint('TOPLEFT', 8, -8-((i-1)*20))
    else
        f.checkButtons[itt[i]]:SetPoint('TOPLEFT', 118, -8-((i-7)*20))
    end
end

function f:populateData(data)
    for k,v in pairs(filters['itemSlot'].data) do
        self.checkButtons[k]:SetChecked(data[k])
    end
end

function f:saveData(customFilterIndex)
    for k,v in pairs(filters['itemSlot'].data) do
        EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[k] = self.checkButtons[k]:GetChecked()
    end
end

filters['itemSlot'].frame = f

filters['itemSlot'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data
    
    if filterData[item.itemEquipLoc] or (item.itemEquipLoc == 'INVTYPE_ROBE' and filterData['INVTYPE_CHEST']) then 
        return true
    else
        filters['itemSlot'].filterMessage = 'item slot is '..invTypes[item.itemEquipLoc]
        return false
    end
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
ITEM IN WARDROBE
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['equipmentSet'] = {}
filters['equipmentSet'].menuText = '套裝設置'
filters['equipmentSet'].filterMessage = '物品被使用在一個或多個套裝設置中。'


f = createFilterFrame('Equipment Set', 32)
f.bodyText:SetText('Item is not used in an equipment set.')
filters['equipmentSet'].frame = f

filters['equipmentSet'].filterFunction = function(itemIndex)
    return not EasyScrap:itemInWardrobeSet(EasyScrap.scrappableItems[itemIndex].itemID, EasyScrap.scrappableItems[itemIndex].bag, EasyScrap.scrappableItems[itemIndex].slot)
end


--[[---------------------------------------------------------------------------------------------------------------------------------------
DUPLICATES
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['duplicates'] = {}
filters['duplicates'].menuText = '重複'
filters['duplicates'].filterMessage = '物品沒有重複。'


f = createFilterFrame('Duplicates', 32)
f.bodyText:SetText('Only show duplicate items.')
filters['duplicates'].frame = f

filters['duplicates'].filterFunction = function(itemIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    
    local i = 0
    for k,v in pairs(EasyScrap.scrappableItems) do
        if v.itemID == item.itemID then i = i + 1 end
        if i > 1 then return true end
    end
    return false
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
TRANSMOG NOT KNOWN
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['transmogKnown'] = {}
filters['transmogKnown'].menuText = '塑形'
filters['transmogKnown'].filterMessage = '在您的收藏中尚未收集此外觀。'

f = createFilterFrame('Transmog', 32)
f.bodyText:SetText('物品外觀在您的收藏中。')
filters['transmogKnown'].frame = f

filters['transmogKnown'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data
 
    local z = C_TransmogCollection.GetItemInfo(item.itemLink)
    if not z then
        if item.itemClassID == LE_ITEM_CLASS_WEAPON or (item.itemClassID == LE_ITEM_CLASS_ARMOR and (item.itemSubClassID == LE_ITEM_ARMOR_CLOTH or item.itemSubClassID == LE_ITEM_ARMOR_LEATHER or item.itemSubClassID == LE_ITEM_ARMOR_MAIL or item.itemSubClassID == LE_ITEM_ARMOR_PLATE or item.itemSubClassID == LE_ITEM_ARMOR_SHIELD)) then 
            --DEFAULT_CHAT_FRAME:AddMessage('Easy Scrap: Failed to obtain transmog information for item '..item.itemLink..'. Item will be ignored, please check it manually.')
            filters['transmogKnown'].filterMessage = '無法確定外觀是否已收集。\n對於某些物品會發生這種情況，請手動檢查。'
            return false
        else
            return true 
        end
    end
    local sources = C_TransmogCollection.GetAppearanceSources(z)
    if sources then
        for k,v in pairs(sources) do
           if v.isCollected then return true end
        end
    end
    filters['transmogKnown'].filterMessage = '在您的收藏中尚未收集此外觀。'
    return false
end

--[[---------------------------------------------------------------------------------------------------------------------------------------
BAGS FILTER
--]]---------------------------------------------------------------------------------------------------------------------------------------
filters['bags'] = {}
filters['bags'].menuText = '背包'
filters['bags'].data = {[0] = true, [1] = true, [2] = true, [3] = true, [4] = true} --bag 0, 1, 2, 3, 4
filters['bags'].filterMessage = '物品未在所選的背包中找到。'

f = createFilterFrame(filters['bags'].menuText, 70)
f.checkButtons = {}
f.checkButtons[0] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[0]:SetPoint('TOPLEFT', 8, -8)
--f.checkButtons[0].text:SetText(GetBagName(0))
f.checkButtons[0].text:SetText('Backpack')
f.checkButtons[1] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[1]:SetPoint('TOPLEFT', 128, -8)
f.checkButtons[1].text:SetText('Bag #1')
f.checkButtons[2] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[2]:SetPoint('TOPLEFT', 8, -28)
f.checkButtons[2].text:SetText('Bag #2')
f.checkButtons[3] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[3]:SetPoint('TOPLEFT', 128, -28)
f.checkButtons[3].text:SetText('Bag #3')
f.checkButtons[4] = CreateFrame('CheckButton', nil, f, 'EasyScrapCheckButtonTemplate')
f.checkButtons[4]:SetPoint('TOPLEFT', 8, -48)
f.checkButtons[4].text:SetText('Bag #4')
function f:populateData(data)
    self.checkButtons[0]:SetChecked(data[0])
    self.checkButtons[1]:SetChecked(data[1])
    self.checkButtons[2]:SetChecked(data[2])
    self.checkButtons[3]:SetChecked(data[3])
    self.checkButtons[4]:SetChecked(data[4])
end

function f:saveData(customFilterIndex)
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[0] = self.checkButtons[0]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[1] = self.checkButtons[1]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[2] = self.checkButtons[2]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[3] = self.checkButtons[3]:GetChecked()
    EasyScrap.saveData.customFilters[customFilterIndex].rules[self.ruleIndex].data[4] = self.checkButtons[4]:GetChecked()
end

filters['bags'].frame = f

filters['bags'].filterFunction = function(itemIndex, filterIndex)
    local item = EasyScrap.scrappableItems[itemIndex]
    local filterData = EasyScrap.saveData.customFilters[EasyScrap.activeFilterID].rules[filterIndex].data
    
    local filterMatch = filterData[item.bag]
    if not filterMatch then filters['bags'].filterMessage = '物品在背包#'..item.bag end
    return filterMatch
end

------------------------------------------------------------------------------------------------------------------------------
filters['azeriteArmor'].order = 1
filters['armorType'].order = 2
filters['bags'].order = 3
filters['bindType'].order = 4
filters['bonusStats'].order = 5
filters['duplicates'].order = 6
filters['equipmentSet'].order = 7
filters['itemLevel'].order = 8
filters['itemName'].order = 9
filters['itemQuality'].order = 10
filters['itemSlot'].order = 11
filters['itemType'].order = 12
filters['transmogKnown'].order = 13
filters['weaponType'].order = 14





EasyScrap.filterTypes = filters