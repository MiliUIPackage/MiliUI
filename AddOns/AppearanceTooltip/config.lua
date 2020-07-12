local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local function checkboxGetValue(self) return ns.db[self.key] end
local function checkboxSetChecked(self) self:SetChecked(self:GetValue()) end
local function checkboxSetValue(self, checked) ns.db[self.key] = checked end
local function checkboxOnClick(self)
    local checked = self:GetChecked()
    PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    self:SetValue(checked)
end

local function newCheckbox(parent, key, label, description, getValue, setValue)
    local check = CreateFrame("CheckButton", "AppearanceTooltipOptionsCheck" .. key, parent, "InterfaceOptionsCheckButtonTemplate")

    check.key = key
    check.GetValue = getValue or checkboxGetValue
    check.SetValue = setValue or checkboxSetValue
    check:SetScript('OnShow', checkboxSetChecked)
    check:SetScript("OnClick", checkboxOnClick)
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

    local box = CreateFrame('Frame', nil, parent)
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

local panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
panel:Hide()
panel:SetAllPoints()
panel.name = "塑形"

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
local notifyKnown = newCheckbox(panel, 'notifyKnown', '顯示是否已收集', "顯示你是否已經收集到這個外觀。")
local currentClass = newCheckbox(panel, 'currentClass', '只預覽當前角色可用的物品', "只有當前角色可以收集外觀的物品才顯示預覽。")
local byComparison = newCheckbox(panel, 'byComparison', '在裝備比較旁邊顯示', "有裝備比較的滑鼠提示說明時，在旁邊顯示預覽 (比較不容易重疊)。")
local tokens = newCheckbox(panel, 'tokens', '預覽套裝兌換物品', "滑鼠指向可以用來兌換套裝的物品時顯示裝備預覽。")

local zoomWorn = newCheckbox(panel, 'zoomWorn', '放大穿著部位', "放大預覽模特兒穿著這個物品的部位。")
local zoomHeld = newCheckbox(panel, 'zoomHeld', '放大手持物品', "放大預覽手持的物品，不顯示你的角色。")
local zoomMasked = newCheckbox(panel, 'zoomMasked', '放大時淡化模特兒', "放大時不要顯示模特兒的細節 (和塑形時的衣櫃相同)。")

local modifier = newDropdown(panel, 'modifier', "按下特別按鍵時才顯示預覽。", {
    Alt = "Alt",
    Ctrl = "Ctrl",
    Shift = "Shift",
    None = "無",
})
UIDropDownMenu_SetWidth(modifier, 100)

local anchor = newDropdown(panel, 'anchor', "對齊滑鼠提示的哪個方向，會依據畫面顯示位置調整。", {
    vertical = "上 / 下",
    horizontal = "左 / 右",
})
UIDropDownMenu_SetWidth(anchor, 100)

local modelBox = newBox(panel, "自訂預覽模特兒", 48)
local customModel = newCheckbox(modelBox, 'customModel', '使用其他模特兒', "使用指定的種族/性別，而不是當前的角色。")
local customRaceDropdown = newDropdown(modelBox, 'modelRace', "選擇自訂種族", {
    [1] = "人類",
    [3] = "矮人",
    [4] = "夜精靈",
    [11] = "德萊尼",
    [22] = "狼人",
    [7] = "地精",
    [24] = "熊貓人",
    [2] = "獸人",
    [5] = "不死族",
    [10] = "血精靈",
    [8] = "食人妖",
    [6] = "牛頭人",
    [9] = "哥布林",
    -- Allied!
    [27] = "夜裔精靈",
    [28] = "高嶺牛頭人",
    [29] = "虛無精靈",
    [30] = "光鑄德萊尼",
	[34] = "黑鐵矮人",
    [36] = "瑪格哈獸人",
})
UIDropDownMenu_SetWidth(customRaceDropdown, 100)
local customGenderDropdown = newDropdown(modelBox, 'modelGender', "選擇自訂性別", {
    [0] = "男性",
    [1] = "女性",
})
UIDropDownMenu_SetWidth(customGenderDropdown, 100)

-- And put them together:

zoomWorn:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -8)
zoomHeld:SetPoint("TOPLEFT", zoomWorn, "BOTTOMLEFT", 0, -4)
zoomMasked:SetPoint("TOPLEFT", zoomHeld, "BOTTOMLEFT", 0, -4)

dressed:SetPoint("TOPLEFT", zoomMasked, "BOTTOMLEFT", 0, -4)
uncover:SetPoint("TOPLEFT", dressed, "BOTTOMLEFT", 0, -4)
tokens:SetPoint("TOPLEFT", uncover, "BOTTOMLEFT", 0, -4)
notifyKnown:SetPoint("TOPLEFT", tokens, "BOTTOMLEFT", 0, -4)
currentClass:SetPoint("TOPLEFT", notifyKnown, "BOTTOMLEFT", 0, -4)
mousescroll:SetPoint("TOPLEFT", currentClass, "BOTTOMLEFT", 0, -4)
spin:SetPoint("TOPLEFT", mousescroll, "BOTTOMLEFT", 0, -4)

local modifierLabel = newFontString(panel, "按下按鍵預覽:", nil, 'TOPLEFT', spin, 'BOTTOMLEFT', 0, -10)
modifier:SetPoint("LEFT", modifierLabel, "RIGHT", 4, -2)

local anchorLabel = newFontString(panel, "對齊:", nil, 'TOPLEFT', modifierLabel, 'BOTTOMLEFT', 0, -16)
anchor:SetPoint("LEFT", anchorLabel, "RIGHT", 4, -2)

byComparison:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -10)

modelBox:SetPoint("TOP", byComparison, "BOTTOM", 0, -20)
customModel:SetPoint("LEFT", modelBox, 12, 0)
customRaceDropdown:SetPoint("LEFT", customModel.Text, "RIGHT", 12, -2)
customGenderDropdown:SetPoint("TOPLEFT", customRaceDropdown, "TOPRIGHT", 4, 0)

InterfaceOptions_AddCategory(panel)

-- Slash handler
SlashCmdList.APPEARANCETOOLTIP = function(msg)
    InterfaceOptionsFrame_OpenToCategory("塑形")
    InterfaceOptionsFrame_OpenToCategory("塑形")
end
SLASH_APPEARANCETOOLTIP1 = "/appearancetooltip"
SLASH_APPEARANCETOOLTIP2 = "/aptip"
