local myname, ns = ...

local function checkboxGetValue(self) return ns.db[self.key] end
local function checkboxSetChecked(self) self:SetChecked(self:GetValue()) end
local function checkboxSetValue(self, checked) ns.db[self.key] = checked end
local function checkboxOnClick(self)
    local checked = self:GetChecked()
    PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    self:SetValue(checked)
end
local function checkboxOnEnter(self)
    if ( self.tooltipText ) then
        GameTooltip:SetOwner(self, self.tooltipOwnerPoint or "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true)
    end
    if ( self.tooltipRequirement ) then
        GameTooltip:AddLine(self.tooltipRequirement, 1.0, 1.0, 1.0, true)
        GameTooltip:Show()
    end
end

local function newCheckbox(parent, key, label, description, getValue, setValue)
    local check = CreateFrame("CheckButton", "AppearanceTooltipOptionsCheck" .. key, parent, "InterfaceOptionsCheckButtonTemplate")

    check.key = key
    check.GetValue = getValue or checkboxGetValue
    check.SetValue = setValue or checkboxSetValue
    check:SetScript('OnShow', checkboxSetChecked)
    check:SetScript("OnClick", checkboxOnClick)
    check:SetScript("OnEnter", checkboxOnEnter)
    check:SetScript("OnLeave", GameTooltip_Hide)
    check.label = _G[check:GetName() .. "Text"]
    check.label:SetText(label)
    check.tooltipText = label
    check.tooltipRequirement = description
    return check
end

local function newDropdown(parent, key, description, values)
    local dropdown = CreateFrame("Frame", "AppearanceTooltipOptions" .. key .. "Dropdown", parent, "UIDropDownMenuTemplate")
    dropdown.key = key
    dropdown:HookScript("OnShow", function()
        if not dropdown.initialize then
            UIDropDownMenu_Initialize(dropdown, function(frame)
                for k, v in pairs(values) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = v
                    info.value = k
                    info.func = function(self)
                        ns.db[key] = self.value
                        UIDropDownMenu_SetSelectedValue(dropdown, self.value)
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)
            UIDropDownMenu_SetSelectedValue(dropdown, ns.db[key])
        end
    end)
    dropdown:HookScript("OnEnter", function(self)
        if not self.isDisabled then
            GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(description, nil, nil, nil, nil, true)
        end
    end)
    dropdown:HookScript("OnLeave", GameTooltip_Hide)
    return dropdown
end

local function newFontString(parent, text, template,  ...)
    local label = parent:CreateFontString(nil, nil, template or 'GameFontHighlight')
    label:SetPoint(...)
    label:SetText(text)

    return label
end

local function newBox(parent, title, height)
    local boxBackdrop = {
        bgFile = [[Interface\ChatFrame\ChatFrameBackground]], tile = true, tileSize = 16,
        edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    }

    local box = CreateFrame('Frame', nil, parent, "BackdropTemplate")
    box:SetBackdrop(boxBackdrop)
    box:SetBackdropBorderColor(.3, .3, .3)
    box:SetBackdropColor(.1, .1, .1, .5)

    box:SetHeight(height)
    box:SetPoint('LEFT', 12, 0)
    box:SetPoint('RIGHT', -12, 0)

    if title then
        box.Title = newFontString(box, title, nil, 'BOTTOMLEFT', box, 'TOPLEFT', 6, 0)
    end

    return box
end

-- and the actual config now

do
    local panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
    panel:Hide()
    panel:SetAllPoints()
    panel.name = "塑形預覽"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("塑形外觀預覽")

    local subText = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
    subText:SetMaxLines(3)
    subText:SetNonSpaceWrap(true)
    subText:SetJustifyV('TOP')
    subText:SetJustifyH('LEFT')
    subText:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
    subText:SetPoint('RIGHT', -32, 0)
    subText:SetText("這些選項可以調整如何顯示滑鼠提示的外觀預覽")

    local dressed = newCheckbox(panel, 'dressed', '穿上所有衣服 (不要脫光)', "同時顯示要預覽的物品，以及目前身上所穿的裝備。")
    local uncover = newCheckbox(panel, 'uncover', '不要遮住預覽的物品', "移除會遮住的衣物，讓目前正要預覽的物品可以完整呈現。")
    local mousescroll = newCheckbox(panel, 'mousescroll', '使用滑鼠滾輪旋轉', "使用滑鼠滾輪旋轉預覽模特兒。")
    local spin = newCheckbox(panel, 'spin', '自動旋轉', "預覽模型顯示時會持續旋轉。")
    local notifyKnown = newCheckbox(panel, 'notifyKnown', '顯示是否已收藏', "顯示你是否已經收集到這個外觀。")
    local currentClass = newCheckbox(panel, 'currentClass', '只預覽當前角色可用的物品', "只有當前角色可以收集外觀的物品才顯示預覽。")
    local byComparison = newCheckbox(panel, 'byComparison', '在裝備比較旁邊顯示', "有裝備比較的滑鼠提示說明時，在旁邊顯示預覽 (比較不容易重疊)。")
    local tokens = newCheckbox(panel, 'tokens', '預覽套裝兌換物品', "滑鼠指向可以用來兌換套裝的物品時顯示裝備預覽。")
    local alerts = newCheckbox(panel, 'alerts', '收藏新外觀時要通知', "每次學習到新外觀時要彈出通知 (例如只能在貿易站買到的外觀)")


    local zoomWorn = newCheckbox(panel, 'zoomWorn', '放大穿著部位', "放大預覽模特兒穿著這個物品的部位。")
    local zoomHeld = newCheckbox(panel, 'zoomHeld', '放大手持物品', "放大預覽手持的物品，不顯示你的角色。")
    local zoomMasked = newCheckbox(panel, 'zoomMasked', '放大時淡化模特兒', "放大時不要顯示模特兒的細節 (和塑形時的衣櫃相同)。")

    local modifier = newDropdown(panel, 'modifier', "按下組合按鍵時才顯示預覽。", {
        Alt = "Alt",
        Ctrl = "Ctrl",
        Shift = "Shift",
        None = "無",
    })
    UIDropDownMenu_SetWidth(modifier, 100)

    local anchor = newDropdown(panel, 'anchor', "對齊滑鼠提示的哪個方向，會依據畫面調整顯示位置。", {
    vertical = "上 / 下",
    horizontal = "左 / 右",
})
    UIDropDownMenu_SetWidth(anchor, 100)

    -- local modelBox = newBox(panel, "Custom player model", 48)
    -- local customModel = newCheckbox(modelBox, 'customModel', 'Use a different model', "Instead of your current character, use a specific race/gender")
    -- local customRaceDropdown = newDropdown(modelBox, 'modelRace', "Choose your custom race", {
    --     [1] = "Human",
    --     [3] = "Dwarf",
    --     [4] = "Night Elf",
    --     [11] = "Draenei",
    --     [22] = "Worgen",
    --     [7] = "Gnome",
    --     [24] = "Pandaren",
    --     [2] = "Orc",
    --     [5] = "Undead",
    --     [10] = "Blood Elf",
    --     [8] = "Troll",
    --     [6] = "Tauren",
    --     [9] = "Goblin",
    --     -- Allied!
    --     [27] = "Nightborne Elf",
    --     [28] = "Highmountain Tauren",
    --     [29] = "Void Elf",
    --     [30] = "Lightforged Draenei",
    --     [34] = "Dark Iron Dwarf",
    --     [35] = "Vulpera",
    --     [36] = "Mag'har Orc",
    --     [37] = "Mechagnome",

    -- })
    -- UIDropDownMenu_SetWidth(customRaceDropdown, 100)
    -- local customGenderDropdown = newDropdown(modelBox, 'modelGender', "Choose your custom gender", {
    --     [0] = "Male",
    --     [1] = "Female",
    -- })
    -- UIDropDownMenu_SetWidth(customGenderDropdown, 100)

    -- And put them together:

    zoomWorn:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -8)
    zoomHeld:SetPoint("TOPLEFT", zoomWorn, "BOTTOMLEFT", 0, -4)
    zoomMasked:SetPoint("TOPLEFT", zoomHeld, "BOTTOMLEFT", 0, -4)

    dressed:SetPoint("TOPLEFT", zoomMasked, "BOTTOMLEFT", 0, -4)
    uncover:SetPoint("TOPLEFT", dressed, "BOTTOMLEFT", 0, -4)
    tokens:SetPoint("TOPLEFT", uncover, "BOTTOMLEFT", 0, -4)
    notifyKnown:SetPoint("TOPLEFT", tokens, "BOTTOMLEFT", 0, -4)
    alerts:SetPoint("TOPLEFT", notifyKnown, "BOTTOMLEFT", 0, -4)
    currentClass:SetPoint("TOPLEFT", alerts, "BOTTOMLEFT", 0, -4)
    mousescroll:SetPoint("TOPLEFT", currentClass, "BOTTOMLEFT", 0, -4)
    spin:SetPoint("TOPLEFT", mousescroll, "BOTTOMLEFT", 0, -4)

    local modifierLabel = newFontString(panel, "預覽的輔助鍵:", nil, 'TOPLEFT', spin, 'BOTTOMLEFT', 0, -10)
    modifier:SetPoint("LEFT", modifierLabel, "RIGHT", 4, -2)

    local anchorLabel = newFontString(panel, "位置:", nil, 'TOPLEFT', modifierLabel, 'BOTTOMLEFT', 0, -16)
    anchor:SetPoint("LEFT", anchorLabel, "RIGHT", 4, -2)

    byComparison:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -10)

    -- modelBox:SetPoint("TOP", byComparison, "BOTTOM", 0, -20)
    -- customModel:SetPoint("LEFT", modelBox, 12, 0)
    -- customRaceDropdown:SetPoint("LEFT", customModel.Text, "RIGHT", 12, -2)
    -- customGenderDropdown:SetPoint("TOPLEFT", customRaceDropdown, "TOPRIGHT", 4, 0)

    -- InterfaceOptions_AddCategory(panel)
    local category, layout = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
    category.ID = panel.name
    Settings.RegisterAddOnCategory(category)
end

-- Overlay config

do
    local panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
    panel:Hide()
    panel:SetAllPoints()
    panel.name = "未收藏圖示"
    panel.parent = "塑形預覽"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(panel.name)

    local subText = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
    subText:SetMaxLines(3)
    subText:SetNonSpaceWrap(true)
    subText:SetJustifyV('TOP')
    subText:SetJustifyH('LEFT')
    subText:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
    subText:SetPoint('RIGHT', -32, 0)
    subText:SetText("這些選項可以控制要在哪些地方顯示尚未收藏的圖示。")

    local bagicon = CreateAtlasMarkup("transmog-icon-hidden")
	local othercharicon = CreateAtlasMarkup("mailbox")

    local show = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    show:SetText(("顯示未收藏物品圖示 %s 和此角色無法使用的未收藏物品圖示 %s"):format(bagicon, othercharicon))

    local bags = newCheckbox(panel, 'bags', '背包', ("在背包中尚未收藏外觀的物品上面顯示 %s 圖示。支援遊戲內建的背包、Baggins、Bagnon 和 Inventorian 背包插件。"):format(bagicon))
    local bags_unbound = newCheckbox(panel, 'bags_unbound', '...只有不是靈魂綁定的物品', "靈魂綁定的物品通常不是已經收藏外觀，就是無法寄給其他角色。")
    local merchant = newCheckbox(panel, 'merchant', '商人', ("在商人視窗中尚未收藏外觀的物品上面顯示 %s 圖示。"):format(bagicon))
    local loot = newCheckbox(panel, 'loot', '拾取', ("在拾取視窗中尚未收藏外觀的物品上面顯示 %s 圖示。"):format(bagicon))
    local encounterjournal = newCheckbox(panel, 'encounterjournal', '冒險指南', ("在冒險指南中尚未收藏外觀的物品上面顯示 %s 圖示。"):format(bagicon))
	local setjournal = newCheckbox(panel, 'setjournal', '外觀套裝', ("在套裝列表中顯示已收藏/未收藏的套裝物品"))

    show:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -8)
    bags:SetPoint("TOPLEFT", show, "BOTTOMLEFT", 0, -8)
    bags_unbound:SetPoint("TOPLEFT", bags, "BOTTOMLEFT", 8, -4)
    merchant:SetPoint("TOPLEFT", bags_unbound, "BOTTOMLEFT", -8, -4)
    loot:SetPoint("TOPLEFT", merchant, "BOTTOMLEFT", 0, -4)
    encounterjournal:SetPoint("TOPLEFT", loot, "BOTTOMLEFT", 0, -4)
	setjournal:SetPoint("TOPLEFT", encounterjournal, "BOTTOMLEFT", 0, -4)

    local category = Settings.GetCategory(panel.parent)
    local subcategory, layout = Settings.RegisterCanvasLayoutSubcategory(category, panel, panel.name, panel.name)
    subcategory.ID = panel.name
end

-- Slash handler
SlashCmdList.APPEARANCETOOLTIP = function(msg)
    Settings.OpenToCategory("塑形預覽")
end
SLASH_APPEARANCETOOLTIP1 = "/appearancetooltip"
SLASH_APPEARANCETOOLTIP2 = "/aptip"
