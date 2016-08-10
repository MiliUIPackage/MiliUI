local addonName, addon = ...

local L = LibStub('AceLocale-3.0'):GetLocale(addonName)

local LIST_SCROLL_ITEM_HEIGHT = 60

local frame = AltCraftMFHTabFrame

function frame:OnInitialize()
    self.Title:SetText("Mount Farm Helper")

    self.RestoreButton:SetText(L.btn_restore_all)

    self.ListScroll:OnInitialize()
end

function frame:OnShow()
    local parent = self:GetParent()

    parent.TopLeft:SetTexture('Interface\\Addons\\AltCraft\\assets\\frame\\tl')
    parent.Top:SetTexture('Interface\\Addons\\AltCraft\\assets\\frame\\t')
    parent.TopRight:SetTexture('Interface\\Addons\\AltCraft\\assets\\frame\\tr')

    parent.BottomLeft:SetTexture('Interface\\Addons\\AltCraft\\assets\\frame\\bl')

    parent.Portrait:SetTexture('Interface\\ICONS\\ABILITY_MOUNT_GOLDENGRYPHON')

    self:Update()
end

function frame:OnSelectItem(button)
    if self.selectedItem and self.selectedItem == button.data.itemId then
        self.selectedItem = nil
    else
        self.selectedItem = button.data.itemId
    end
    self:Update()
end

function frame:OnDeleteClick()
end

function frame:OnRestoreClick()
end

function frame:Update(what)
    if what then
        return
    end

    self.ListScroll:Update()
end

function frame.ListScroll:OnInitialize()
    self.scrollBar.doNotHide = 1

    HybridScrollFrame_OnLoad(self)
    self.update = function() self:Update() end

    HybridScrollFrame_CreateButtons(self, 'AltCraftMFHButtonTemplate', 0, 0)
    self:Update()
end

function frame.ListScroll:OnUpdate()
    local button
    for button in table.s2k_values(self.buttons) do
        if button:IsMouseOver() then
            button.Highlight:Show()

            if GameTooltip:IsOwned(button.Icon) then
                GameTooltip:SetOwner(button.Icon, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(button.data.itemId)
            end

        elseif self:GetParent().selectedItem == button.data.itemId then
            button.Highlight:Show()
        else
            button.Highlight:Hide()
        end
    end
end

function frame.ListScroll:Update()
    local list = addon:BuildAltCraftList()
    local numRows = #list

    HybridScrollFrame_Update(self, numRows * LIST_SCROLL_ITEM_HEIGHT, self:GetHeight())

    local scrollOffset = HybridScrollFrame_GetOffset(self)

    local i
    for i = 1, #self.buttons do
        local button = self.buttons[i]
        local item = list[i + scrollOffset]

        if scrollOffset + i <= numRows then
            button.data = item

            button:Show()

            button.Icon.Texture:SetTexture(item.icon)
            button.Item:SetText(item.link:gsub('[%[%]]', ''))

            if item.sources[1].comment then
                button.Zone:SetText(string.format('%s (%s)', item.sources[1].zone, item.sources[1].comment))
            else
                button.Zone:SetText(item.sources[1].zone)
            end

            local numSources = table.s2k_len(item.sources)
            if numSources > 1 then
                button.Source:SetText(string.format("%s (+%d)", item.sources[1].source, numSources - 1))
            else
                button.Source:SetText(item.sources[1].source)
            end
        else
            button:Hide()
        end
    end
end
