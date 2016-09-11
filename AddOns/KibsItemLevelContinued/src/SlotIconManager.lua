local _, addonNamespace = ...

local L = addonNamespace.L

local SlotIconManager = {
    STYLE = {
        UPGRADES = 1,
        UPGRADES_SUMMARY = 2,
        ENABLED = 4,
        SMALL = 8,
        COLOR = 16,
    }
}
local SlotIconManagerMetaTable = { __index = SlotIconManager }

addonNamespace.SlotIconManager = SlotIconManager

function SlotIconManager:new(adapter)
    local instance = {
        adapter = adapter,
        slotIcons = {},
        slotText = {},
        hostVisible = false,
        style = nil,
        slotNames = {
            'HeadSlot',
            'NeckSlot',
            'ShoulderSlot',
            'BackSlot',
            'ChestSlot',
            --'ShirtSlot',
            --'TabardSlot',
            'WristSlot',
            'HandsSlot',
            'WaistSlot',
            'LegsSlot',
            'FeetSlot',
            'Finger0Slot',
            'Finger1Slot',
            'Trinket0Slot',
            'Trinket1Slot',
            'MainHandSlot',
            'SecondaryHandSlot',
        },
        rightAlignedSlots = {
            HeadSlot = true,
            NeckSlot = true,
            ShoulderSlot = true,
            BackSlot = true,
            ChestSlot = true,
            ShirtSlot = true,
            TabardSlot = true,
            WristSlot = true,
            SecondaryHandSlot = true,
        },
        slotsWithRequiredEnchants = {
            NeckSlot = true,
            BackSlot = true,
            Finger0Slot = true,
            Finger1Slot = true,
        },
        itemInfos = nil,
        parentVisible = false,
        hasSomethingRendered = false,
        lastRefreshTime = nil,
        refreshTimer = nil,
    }

    setmetatable(instance, SlotIconManagerMetaTable)

    instance:Init()

    return instance
end

function SlotIconManager:Debug(...)
    addonNamespace.Debug('SlotIconManager(' .. self.adapter:GetType() .. '):', ...)
end

function SlotIconManager:Init()
    self:Debug('Init')

    self.averageItemLevelFontString = self.adapter:GetFrame():CreateFontString(nil, "OVERLAY", "NewSubSpellFont")
    self.averageItemLevelFontString:SetPoint("CENTER", self.adapter:GetFrame(), "BOTTOM", 0, 51)

    self.adapter:OnShow(function()
        self:Debug('OnShow')
        self.parentVisible = true
        self:Refresh()
    end)

    self.adapter:OnHide(function()
        self:Debug('OnHide')
        self.parentVisible = false
        self:Refresh()
    end)

    self.adapter:OnContentChanged(function ()
        self:Debug('OnContentChanged')
        self:Refresh()
    end)
end

function SlotIconManager:Refresh()
    self:Debug('Refresh')

    if self.refreshTimer ~= nil then
        self.refreshTimer:Cancel()
        self.refreshTimer = nil
    end

    if self.lastRefreshTime == nil or GetTime() - self.lastRefreshTime > 1 then
        self.lastRefreshTime = GetTime()
        self:_Refresh()
    else
        self.refreshTimer = C_Timer.NewTimer(1, function ()
            self.lastRefreshTime = GetTime()
            self:_Refresh()
        end)
    end
end

function SlotIconManager:_Refresh()
    self:Debug('_Refresh')

    if self.parentVisible then
        local hasSomethingToRender = self:HasStyleFlag(self.STYLE.ENABLED) and self.adapter:GetUnit() and self.parentVisible

        if hasSomethingToRender then
            self:RefreshItemInfoForAllSlots()
        end

        if self.hasSomethingRendered then
            self:_Erase()
        end

        if hasSomethingToRender then
            self:_Render()
        end
    end
end

function SlotIconManager:_Render()
    self:Debug('_Render')
    self:_ShowAllLabels()
    self:_AddEnchants()
    self:_AddGems()
    self:_ShowSummary()
    self.hasSomethingRendered = true
end

function SlotIconManager:_Erase()
    self:Debug('_Erase')
    self:_HideEnchantsAndGems()
    self:_HideAllLabels()
    self:_HideSummary()
    self.hasSomethingRendered = false
end

function SlotIconManager:_GetSlotNames()
    return self.slotNames
end

function SlotIconManager:HasStyleFlag(styleFlag)
    return bit.band(self.style, styleFlag) == styleFlag
end

function SlotIconManager:SetStyle(value)
    self:Debug('SetStyle')
    if self.style ~= value then
        self.style = value
        self:Refresh()
    end
end

function SlotIconManager:_GetLabelText(slotName)
    local itemInfo = self:GetItemInfoForAllSlots()[slotName]
    local ilvlString

    if itemInfo then
        ilvlString = "" .. (itemInfo:getItemLevel() or 0)

        if self:HasStyleFlag(SlotIconManager.STYLE.UPGRADES) then
            local current, max = itemInfo:GetUpgrades()
            if current and max then
                ilvlString = ilvlString .. " (" .. current .. "/" .. max .. ")"
            end
        end

        if self:HasStyleFlag(self.STYLE.COLOR) then
            local color = itemInfo:getQualityColor()
            if color then
                ilvlString = "|c" .. color .. ilvlString .. "|r"
            end
        end
    end

    return ilvlString
end

function SlotIconManager:_GetAverageItemLevel()
    local sum = 0
    local itemInfos = self:GetItemInfoForAllSlots()

    for _, itemInfo in pairs(itemInfos) do
        if itemInfo then
            sum = sum + (itemInfo:getItemLevel() or 0)
        end
    end

    if not itemInfos.SecondaryHandSlot and itemInfos.MainHandSlot and itemInfos.MainHandSlot:isTwoHandedWeapon() then
        sum = sum + (itemInfos.MainHandSlot:getItemLevel() or 0)
    end

    return sum / table.getn(self:_GetSlotNames())
end

function SlotIconManager:_ShowLabel(slotName)
    local value = self:_GetLabelText(slotName)

    if value then
        local key = slotName .. "-" .. self.style

        if not self.slotText[key] then
            local parent = self.adapter:GetSlotFrame(slotName)
            local alignment = self:GetSlotAlignment(slotName)
            self.slotText[key] = parent:CreateFontString(nil, "OVERLAY", self:_GetSlotTextFontStyle())
            local dx = 10
            local dy = -4
            if alignment == "LEFT" then
                self.slotText[key]:SetPoint("TOPRIGHT", parent, "TOPLEFT", -dx, dy)
            elseif alignment == "RIGHT" then
                self.slotText[key]:SetPoint("TOPLEFT", parent, "TOPRIGHT", dx, dy)
            end
        end

        self.slotText[key]:Show()
        self.slotText[key]:SetText(value)
    end
end

function SlotIconManager:_ShowAllLabels()
    for _, slotName in pairs(self:_GetSlotNames()) do
        self:_ShowLabel(slotName)
    end
end

function SlotIconManager:_HideAllLabels()
    for _, slotText in pairs(self.slotText) do
        slotText:Hide()
    end
end

function SlotIconManager:_AddIcon(slotName, textureName, tooltip)
    local previousSlotIcon, slotIcon
    local slotIconIndex = 1

    if self.slotIcons[slotName] then
        for _, item in pairs(self.slotIcons[slotName]) do
            if item:isHidden() then
                slotIcon = item
                break
            end

            slotIconIndex = slotIconIndex + 1
            previousSlotIcon = item
        end
    else
        self.slotIcons[slotName] = {}
    end

    if not slotIcon then
        local parent = previousSlotIcon and previousSlotIcon.frame or self.adapter:GetSlotFrame(slotName)
        local alignment = self:GetSlotAlignment(slotName)
        local iconScale = 1
        local iconSize = 16 / iconScale
        local iconSpacing = 1 / iconScale
        local dx = previousSlotIcon and iconSpacing or 10 / iconScale
        local dy = not previousSlotIcon and 4 or 0

        slotIcon = addonNamespace.AllocateSlotIcon(parent)

        if alignment == "LEFT" then
            slotIcon.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", -dx, dy)
        elseif alignment == "RIGHT" then
            slotIcon.frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", dx, dy)
        end

        slotIcon.frame:SetSize(iconSize, iconSize)
        slotIcon.frame:SetScale(iconScale)

        table.insert(self.slotIcons[slotName], slotIcon)
    end

    slotIcon:Render(textureName, tooltip)
end

function SlotIconManager:_AddEnchants()
    for slotName, itemInfo in pairs(self:GetItemInfoForAllSlots()) do
        if itemInfo then
            local tooltip = addonNamespace.Tooltip:new()
            local enchantInfo = itemInfo:getEnchantInfo()

            if enchantInfo then
                local consumable = enchantInfo:getConsumableItem()
                local formula = enchantInfo:getFormulaItem()
                local receipe = enchantInfo:getReceipeSpell()
                local texture =
                consumable and consumable:getTextureName()
                        or formula and formula:getTextureName()
                        or receipe and receipe:getTextureName()
                        or "INTERFACE/ICONS/INV_Misc_QuestionMark"

                if consumable then
                    tooltip:AddHyperlink(consumable:getLink())
                elseif formula then
                    tooltip:AddHyperlink(formula:getLink())
                elseif receipe then
                    tooltip:AddHyperlink(receipe:getLink())
                elseif KIBC_EnchantToSpellID[enchantInfo:getId()] then
                    local spellInfo = addonNamespace.SpellInfo:new("enchant:" .. KIBC_EnchantToSpellID[enchantInfo:getId()])
                    texture = spellInfo:getTextureName()
                    tooltip:AddHyperlink(spellInfo:getLink())
                else
                    tooltip:AddText(string.format(L["Unknown enchant #%d"], enchantInfo:getId()))
                end

                self:_AddIcon(slotName, texture, tooltip)
            elseif self:IsSlotEnchantRequired(slotName) then
                tooltip:AddText(L["Missing enchant"])
                self:_AddIcon(slotName, "INTERFACE/BUTTONS/UI-GROUPLOOT-PASS-UP", tooltip)
            end
        end
    end
end

function SlotIconManager:_AddGems()
    for slotName, itemInfo in pairs(self:GetItemInfoForAllSlots()) do
        if itemInfo then
            for _, socketInfo in pairs(itemInfo:getSockets()) do
                local texture
                local tooltip = addonNamespace.Tooltip:new()

                if not socketInfo:isEmpty() then
                    texture = socketInfo:getGem():getTextureName()
                    tooltip:AddHyperlink(socketInfo:getGem():getLink())
                elseif self:IsSlotGemRequired(slotName) then
                    texture = socketInfo:getTextureName()
                    tooltip:AddText(L["Missing gem"])
                end

                if texture then
                    self:_AddIcon(slotName, texture, tooltip)
                end
            end
        end
    end
end

function SlotIconManager:_HideEnchantsAndGems()
    for _, slotIcons in pairs(self.slotIcons) do
        for _, slotIcon in pairs(slotIcons) do
            addonNamespace.ReleaseSlotIcon(slotIcon)
        end
    end

    self.slotIcons = {}
end

function SlotIconManager:_GetSlotTextFontStyle()
    if self:HasStyleFlag(SlotIconManager.STYLE.SMALL) then
        return "SystemFont_Small"
    else
        return "SystemFont_Med1"
    end
end

function SlotIconManager:RefreshItemInfoForAllSlots()
    self:Debug('RefreshItemInfoForAllSlots')

    self.itemInfos = {}

    for _, slotName in pairs(self:_GetSlotNames()) do
        local itemString = GetInventoryItemLink(self.adapter:GetUnit(), GetInventorySlotInfo(slotName))
        self.itemInfos[slotName] = itemString and addonNamespace.ItemStringInfo:new(itemString) or nil
    end

    if self.itemInfos.MainHandSlot and self.itemInfos.SecondaryHandSlot and self.itemInfos.MainHandSlot:IsArtifact() then
        self.itemInfos.SecondaryHandSlot.itemLevel = self.itemInfos.MainHandSlot:getItemLevel()
    end
end

function SlotIconManager:GetItemInfoForAllSlots()
    return self.itemInfos
end

function SlotIconManager:GetTotalUpgrades()
    local totalCurrent = 0
    local totalMax = 0

    for _, itemInfo in pairs(self:GetItemInfoForAllSlots()) do
        if itemInfo then
            local current, max = itemInfo:GetUpgrades()
            if current and max then
                totalCurrent = totalCurrent + current
                totalMax = totalMax + max
            end
        end
    end

    return totalCurrent, totalMax
end

function SlotIconManager:GetSummaryText()
    local averageItemLevel = self:_GetAverageItemLevel()
    local text

    if self:HasStyleFlag(self.STYLE.UPGRADES_SUMMARY) then
        local format = L["Avg. equipped item level: %.1f (%d/%d)"]
        local current, max = self:GetTotalUpgrades()
        text = string.format(format, averageItemLevel, current, max)
    else
        local format = L["Avg. equipped item level: %.1f"]
        text = string.format(format, averageItemLevel)
    end

    return NORMAL_FONT_COLOR_CODE .. text .. FONT_COLOR_CODE_CLOSE
end

function SlotIconManager:_ShowSummary()
    self.averageItemLevelFontString:Show()
    self.averageItemLevelFontString:SetText(self:GetSummaryText())
end

function SlotIconManager:_HideSummary()
    self.averageItemLevelFontString:Hide()
end

function SlotIconManager:GetSlotAlignment(slotName)
    if self.rightAlignedSlots[slotName] ~= nil then
        return 'RIGHT'
    else
        return 'LEFT'
    end
end

function SlotIconManager:IsAtMaxLevel()
    return UnitLevel(self.adapter:GetUnit()) == 110
end

function SlotIconManager:IsSlotEnchantRequired(slotName)
    return self.slotsWithRequiredEnchants[slotName] ~= nil and self:IsAtMaxLevel()
end

function SlotIconManager:IsSlotGemRequired(slotName)
    return self:IsAtMaxLevel()
end