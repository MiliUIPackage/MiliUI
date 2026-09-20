do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.productEnabled then
        return
    end
end
local _, ns = ...
if not ns.IsRetail then return end

local GUI2 = ns.GUI2
local L = ns.Locale:Get("AuctionHelper")
local Tracker = {}
ns.AuctionHelperRecipeTracker = Tracker
local UNKNOWN_ICON = 134400
local CONTENT_TOP = 6

local function CompactQuantity(value, decimals)
    local divisor, suffix = 1, ""
    if value >= 1000000000 then divisor, suffix = 1000000000, "b"
    elseif value >= 1000000 then divisor, suffix = 1000000, "m"
    elseif value >= 1000 then divisor, suffix = 1000, "k" end
    if divisor == 1 then return tostring(value) end
    local result = string.format(decimals and "%.1f" or "%.0f", value / divisor)
    return (result:gsub("%.0$", "")) .. suffix
end

function Tracker:PaintQuantity(button)
    local text = button.quantityText
    self.config.applyQuantityFont(text)
    text:SetTextColor(button.complete and 0.2 or 1, 1, button.complete and 0.2 or 1)
    local brightness = button.complete and 1 or 0.3
    button.icon:SetVertexColor(brightness, brightness, brightness)
    text:SetScale(1)
    if not button.quantity then return end
    local available = self.config.itemSize - 2
    text:SetText(button.quantity)
    if text:GetStringWidth() <= available then return end
    local owned, required
    for precision = 1, 0, -1 do
        local decimals = precision == 1
        owned = CompactQuantity(button.owned, decimals)
        required = button.required:gsub("%d+", function(value) return CompactQuantity(tonumber(value), decimals) end)
        text:SetText(owned .. "/" .. required)
        if text:GetStringWidth() <= available then return end
    end
    -- 极端字号/范围仍放不下一行时分行，保持用户选择的字号。
    text:SetText(owned .. "\n/" .. required)
end

local function StyleRecipeText(text)
    local font, size = text:GetFont()
    text:SetFont(font or GUI2.Fonts.normal, size or 12, "OUTLINE")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    local color = text.recipeQuality and ITEM_QUALITY_COLORS[text.recipeQuality]
    text:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
end

local function BindRecipeText(text)
    text.RefreshTheme = StyleRecipeText
    -- 主面板应用外观字体后，重新应用业务文字样式。
    text.yuiAuctionAfterFont = StyleRecipeText
    StyleRecipeText(text)
end

function Tracker:UpdateRecipeText(text, recipe)
    local quality
    if recipe.itemID then
        local name, _, itemQuality = C_Item.GetItemInfo(recipe.itemID)
        quality = itemQuality
        if not name then self:RequestItem(recipe.itemID) end
    end
    if text.recipeQuality ~= quality then
        text.recipeQuality = quality
        text:RefreshTheme()
    end
end

function Tracker:ShowRecipeTooltip(owner, recipe)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if recipe.itemID and C_Item.GetItemInfo(recipe.itemID) then
        GameTooltip:SetItemByID(recipe.itemID)
    else
        local link = not recipe.itemID and C_TradeSkillUI.GetRecipeLink(recipe.id)
        if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(recipe.name) end
    end
    GameTooltip:Show()
end

-- 只在追踪列表变化或重新打开时读取结构；背包事件只更新数量。
function Tracker:ReadRecipes()
    self.layoutDirty = true
    self.totalsDirty = true
    local recipes = {}
    local present = {}
    for _, isRecraft in ipairs({ true, false }) do
        for _, recipeID in ipairs(C_TradeSkillUI.GetRecipesTracked(isRecraft) or {}) do
            local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)
            local recipe = {
                id = recipeID, isRecraft = isRecraft,
                key = tostring(recipeID) .. (isRecraft and ":recraft" or ":craft"),
                name = schematic and schematic.name or L["tracker.loading"],
                icon = schematic and schematic.icon or UNKNOWN_ICON,
                itemID = schematic and schematic.outputItemID,
                slots = {},
            }
            if isRecraft then recipe.name = L["tracker.recraft"]:format(recipe.name) end
            for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
                if ProfessionsUtil.IsReagentSlotRequired(slot) then
                    if ProfessionsUtil.IsReagentSlotModifyingRequired(slot) then
                        table.insert(recipe.slots, 1, slot)
                    else
                        recipe.slots[#recipe.slots + 1] = slot
                    end
                end
            end
            recipes[#recipes + 1] = recipe
            present[recipe.key] = true
        end
    end
    for key in pairs(self.excluded) do
        if not present[key] then self.excluded[key] = nil end
    end
    return recipes
end

local function RequiredRange(slot)
    local quantities = slot.variableQuantities
    if quantities and #quantities > 0 then
        local minimum, maximum = math.huge, 0
        for _, entry in ipairs(quantities) do
            minimum = math.min(minimum, entry.quantity)
            maximum = math.max(maximum, entry.quantity)
        end
        return minimum, maximum, true
    end
    local quantity = slot.quantityRequired or 0
    return quantity, quantity, false
end

-- 以可替代材料的完整 ID 集合为单位合并，不按可能重名的本地化名称合并。
function Tracker:BuildTotals()
    local slots, byKey = {}, {}
    for _, recipe in ipairs(self.recipes) do
        if not self.excluded[recipe.key] then
            for slotIndex, slot in ipairs(recipe.slots) do
                local identities, seen, reagents = {}, {}, {}
                for _, reagent in ipairs(slot.reagents) do
                    local identity = reagent.itemID and ("item:" .. reagent.itemID)
                        or reagent.currencyID and ("currency:" .. reagent.currencyID)
                    if identity and not seen[identity] then
                        seen[identity] = true
                        identities[#identities + 1] = identity
                        reagents[#reagents + 1] = reagent
                    end
                end
                table.sort(identities)
                local key = #identities > 0 and table.concat(identities, ";") or recipe.key .. ":" .. slotIndex
                local total = byKey[key]
                if not total then
                    total = { reagents = reagents, slotInfo = slot.slotInfo, aggregateMin = 0, aggregateMax = 0 }
                    byKey[key] = total
                    slots[#slots + 1] = total
                end
                local minimum, maximum, variable = RequiredRange(slot)
                total.aggregateMin = total.aggregateMin + minimum
                total.aggregateMax = total.aggregateMax + maximum
                total.aggregateVariable = total.aggregateVariable or variable
            end
        end
    end
    self.totalSlots, self.totalsDirty = slots, false
end

function Tracker:SetIncluded(key, included)
    self.excluded[key] = not included or nil
    self.totalsDirty, self.layoutDirty = true, true
    self:Schedule()
end

function Tracker:SetMode(mode)
    if self.mode == mode then return end
    self.mode = mode
    self.pendingSearch = nil
    self.layoutDirty = true
    self.scroll:SetVerticalScroll(0)
    ns.HideGameTooltip()
    self:Schedule()
end

function Tracker:GetSlotCount(slot)
    local owned = ProfessionsUtil.AccumulateReagentsInPossession(slot.reagents)
    local minimum, maximum, variable
    if slot.aggregateMin then
        minimum, maximum, variable = slot.aggregateMin, slot.aggregateMax, slot.aggregateVariable
    else
        minimum, maximum, variable = RequiredRange(slot)
    end
    if variable then
        return owned, tostring(minimum) .. "–" .. tostring(maximum), false
    end
    local required = minimum
    return owned, tostring(required), owned >= required
end

function Tracker:Create(config)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetRecipesTracked or not ProfessionsUtil then return end
    local self = setmetatable({
        config = config, recipes = {}, blocks = {}, awaiting = {},
        structureDirty = true, dirty = true, active = false, dismissed = false,
        mode = "individual", excluded = {}, totalsDirty = true, totalSlots = {},
    }, { __index = Tracker })
    local helper, settings = config.helper, config.settings
    local appearance = ns.AuctionHelperAppearance
    local panel = GUI2:CreateFrame(helper)
    panel:Hide()
    panel:SetWidth(260)
    panel:SetPoint("TOPLEFT", helper, "TOPRIGHT", 2, 0)
    panel:SetPoint("BOTTOMLEFT", helper, "BOTTOMRIGHT", 2, 0)
    panel:SetFrameLevel(helper:GetFrameLevel() + 5)
    self.panel = panel
    local title = config.createText(panel, L["tracker.title"], 14)
    title:SetPoint("TOP", 0, -5)
    appearance:Register(panel, {
        themeProvider = config.themeProvider, heading = title,
        headingColorKey = "color.text.accent", role = "settings",
    })

    local function SmallButton(parent, text, tooltip, onClick)
        local button = GUI2:CreateButtonFrame(parent)
        button:SetSize(16, 16)
        button.text = config.createText(button, text, 14)
        button.text:SetPoint("CENTER")
        button.ResetColor = function()
            button.text:SetTextColor(0.7, 0.7, 0.7)
        end
        button.text.RefreshTheme = button.ResetColor
        button.ResetColor()
        button:HookScript("OnShow", button.ResetColor)
        button:SetScript("OnClick", function()
            ns.HideGameTooltip()
            onClick(button)
        end)
        button:SetScript("OnEnter", function()
            button.text:SetTextColor(1, 1, 1)
            GameTooltip:SetOwner(button, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            button.ResetColor()
            ns.HideGameTooltip()
        end)
        return button
    end
    local close = SmallButton(panel, "×", L["tracker.close"], function()
        self.dismissed = true
        self:SyncVisibility()
    end)
    close:SetPoint("TOPRIGHT", -4, -4)
    self.toggle = SmallButton(helper, "", L["tracker.title"], function()
        if self.panel:IsShown() then
            self.dismissed = true
            self:SyncVisibility()
            return
        end
        self.dismissed = false
        settings:Hide()
        self:SyncVisibility()
    end)
    self.toggle:SetPoint("RIGHT", config.settingsButton, "LEFT", -4, 0)
    local toggleIcon = GUI2:CreateTexture(self.toggle, { layer = "ARTWORK" })
    toggleIcon:SetAllPoints()
    toggleIcon:SetAtlas("poi-workorders")
    self.toggle:Hide()

    local scroll = GUI2:CreateScrollFrame(panel, { child = false })
    scroll:SetPoint("TOPLEFT", 18, -65)
    scroll:SetPoint("BOTTOMRIGHT", -32, 8)
    local content = GUI2:CreateFrame(scroll)
    content:SetSize(210, 1)
    scroll:SetScrollChild(content)
    self.scroll, self.content = scroll, content

    local tabContext = appearance:Resolve(config.themeProvider())
    local accent = tabContext.accent
    self.tabs = GUI2.Form:CreateUnderlineTabs(panel, {
        width = 210, height = 24,
        items = {
            { text = L["tracker.tab_individual"], value = "individual" },
            { text = L["tracker.tab_total"], value = "total" },
        },
        value = self.mode, overflow = "scroll", contentAlignment = "CENTER", gap = 4,
        itemPaddingX = 8, minItemWidth = 54, indicatorOffsetY = -2, indicatorHeight = 3,
        indicatorColor = accent, selectedColor = accent, hoverColor = accent,
        onChange = function(_, value) self:SetMode(value) end,
    })
    self.tabs:SetPoint("TOP", panel, "TOP", 0, -30)
    for _, button in ipairs(self.tabs.buttons) do appearance:ApplyFont(button.text, tabContext) end
    self.tabs:Relayout()

    function self:NewBlock()
        local block = GUI2:CreateFrame(content)
        block:SetWidth(210)
        block.buttons = {}
        block.header = GUI2:CreateFrame(block)
        block.header:SetSize(190, 20)
        block.header:SetPoint("TOPLEFT")
        block.iconSlot = GUI2:CreateIconSlot(block.header, { size = 20, shape = "square", animate = false })
        block.iconSlot:SetPoint("LEFT", block.header, "LEFT", 0, 0)
        block.icon = block.iconSlot.icon
        block.name = config.createText(block.header, "", 14)
        block.name:SetPoint("LEFT", block.header, "LEFT", 24, 0)
        block.name:SetHeight(20)
        block.name:SetJustifyV("MIDDLE")
        block.name:SetWidth(166)
        block.name:SetWordWrap(false)
        block.name:SetJustifyH("LEFT")
        BindRecipeText(block.name)
        block.header:EnableMouse(true)
        block.header:SetScript("OnEnter", function()
            self:ShowRecipeTooltip(block.header, block.recipe)
        end)
        block.header:SetScript("OnLeave", ns.HideGameTooltip)
        block.close = SmallButton(block, "×", L["tracker.untrack"], function()
            local recipe = block.recipe
            C_TradeSkillUI.SetRecipeTracked(recipe.id, false, recipe.isRecraft)
            self.structureDirty = true
            self:Schedule()
        end)
        block.close:SetPoint("LEFT", block.header, "RIGHT", 4, 0)
        return block
    end

    function self:NewMaterial(block)
        local button = GUI2:CreateIconSlot(block, {
            size = config.itemSize, shape = "square", animate = false,
            onClick = function(slot) if slot.itemID then self:Search(slot.itemID) end end,
        })
        -- IconSlot.count 属于 GUI2 状态着色；需求数量独立管理，避免 hover 覆盖。
        button.quantityText = config.createText(button, "", 11)
        button.quantityText:SetPoint("BOTTOMRIGHT", -1, 1)
        button.quantityText:SetJustifyH("RIGHT")
        button.quantityText.RefreshTheme = function(text)
            self:PaintQuantity(button)
        end
        button.quantityText.yuiAuctionAfterFont = button.quantityText.RefreshTheme
        local refresh = button.RefreshTheme
        if refresh then
            button.RefreshTheme = function(widget, ...)
                refresh(widget, ...)
                self:PaintQuantity(widget)
            end
        end
        button:HookScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            if button.itemID then
                GameTooltip:SetItemByID(button.itemID)
            elseif button.currencyID then
                GameTooltip:SetCurrencyByID(button.currencyID)
            else
                GameTooltip:SetText(button.label or L["tracker.loading"])
            end
            GameTooltip:AddLine(L["tracker.quantity"]:format(button.quantity), 1, 1, 1)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function()
            ns.HideGameTooltip()
        end)
        button:SetScript("OnClick", function()
            if button.itemID then self:Search(button.itemID) end
        end)
        return button
    end

    self.flush = function()
        self.timer = nil
        if not self.active then return end
        if self.structureDirty then
            self.recipes = self:ReadRecipes()
            self.structureDirty = false
        end
        self:SyncVisibility()
    end
    self.onEvent = function(event, itemID, success)
        if event == "ITEM_DATA_LOAD_RESULT" then
            if not self.awaiting[itemID] then return end
            -- 完成或失败均保留标记，避免失败物品触发请求/刷新循环。
            self.awaiting[itemID] = false
            if self.pendingSearch == itemID then
                self.pendingSearch = nil
                if success and self.panel:IsShown() then self:Search(itemID, true) end
            end
        elseif event == "TRACKED_RECIPE_UPDATE" or event == "TRADE_SKILL_LIST_UPDATE" then
            self.structureDirty = true
        end
        self:Schedule()
    end
    panel:HookScript("OnHide", function()
        self.pendingSearch = nil
        ns.HideGameTooltip()
    end)
    settings:HookScript("OnShow", function() self:SyncVisibility() end)
    settings:HookScript("OnHide", function()
        if helper:IsVisible() and config.isEnabled() then
            self.dismissed = false
            self:SyncVisibility()
        end
    end)
    helper:HookScript("OnShow", function() self:Start() end)
    helper:HookScript("OnHide", function() self:Stop() end)
    config.auctionHouse:HookScript("OnShow", function()
        self.dismissed = false
        self:Start()
        self:SyncVisibility()
    end)
    config.auctionHouse:HookScript("OnHide", function() self:Stop() end)
    self:Start()
    return self
end

function Tracker:Schedule()
    self.dirty = true
    if not self.active or self.timer then return end
    -- 手动关闭和设置期间只处理追踪结构，不刷新隐藏图标。
    if not self.structureDirty and not self.panel:IsShown() then return end
    self.timer = C_Timer.NewTimer(0, self.flush)
end

function Tracker:Start()
    if self.active or not self.config.isEnabled() or not self.config.helper:IsVisible() then return end
    self.active = true
    self.structureDirty, self.dirty = true, true
    ns.Event:On("TRACKED_RECIPE_UPDATE", self.onEvent, self)
    ns.Event:On("TRADE_SKILL_LIST_UPDATE", self.onEvent, self)
    ns.Event:On("BAG_UPDATE_DELAYED", self.onEvent, self)
    ns.Event:On("CURRENCY_DISPLAY_UPDATE", self.onEvent, self)
    ns.Event:On("ITEM_DATA_LOAD_RESULT", self.onEvent, self)
    self.flush()
end

function Tracker:RefreshEnabled()
    if not self.config.isEnabled() then
        self:Stop()
        return
    end
    self.dismissed = false
    self:Start()
    self:SyncVisibility()
end

function Tracker:Stop()
    self.active = false
    ns.Event:OffOwner(self)
    if self.timer then self.timer:Cancel(); self.timer = nil end
    self.pendingSearch = nil
    wipe(self.awaiting)
    self.panel:Hide()
    self.toggle:Hide()
end

function Tracker:SyncVisibility()
    if self.active and self.structureDirty and not self.config.settings:IsShown() and not self.dismissed then
        self.recipes = self:ReadRecipes()
        self.structureDirty = false
    end
    local hasRecipes = self.active and #self.recipes > 0
    self.toggle:SetShown(hasRecipes)
    local visible = hasRecipes and not self.dismissed and not self.config.settings:IsShown()
    self.panel:SetShown(visible)
    if visible then
        if self.dirty then self:Render() end
    else
        if self.timer then self.timer:Cancel(); self.timer = nil end
        self.pendingSearch = nil
    end
end

function Tracker:RequestItem(itemID)
    if self.awaiting[itemID] == nil then
        self.awaiting[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

function Tracker:Search(itemID, loaded)
    if not self.active or not self.panel:IsShown() then return end
    local house = self.config.auctionHouse
    local bar = house.SearchBar
    if not house:IsVisible() or not bar or not bar.SearchBox or not bar.SearchButton then return end
    local name = C_Item.GetItemInfo(itemID)
    if not name then
        if not loaded then
            self.pendingSearch = itemID
            self:RequestItem(itemID)
        end
        return
    end
    self.pendingSearch = nil
    if house.SetDisplayMode then house:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy) end
    bar.SearchBox:SetText(name)
    bar.SearchButton:Click()
end

function Tracker:UpdateMaterial(button, slot, slotIndex, layout, startY)
    local reagent = slot.reagents[1] or {}
    button.itemID, button.currencyID = reagent.itemID, reagent.currencyID
    button.label = slot.slotInfo and slot.slotInfo.slotText or nil
    local texture
    if reagent.itemID then
        texture = C_Item.GetItemIconByID(reagent.itemID)
        if not C_Item.GetItemInfo(reagent.itemID) then self:RequestItem(reagent.itemID) end
    elseif reagent.currencyID then
        local currency = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
        texture = currency and currency.iconFileID
    end
    texture = texture or UNKNOWN_ICON
    if button.texture ~= texture then
        button.texture = texture
        button.icon:SetTexture(texture)
    end
    local owned, required, complete = self:GetSlotCount(slot)
    local quantity = tostring(owned) .. "/" .. required
    local fontChanged = self.config.applyQuantityFont(button.quantityText)
    if button.quantity ~= quantity or button.complete ~= complete or fontChanged then
        button.quantity, button.complete = quantity, complete
        button.owned, button.required = owned, required
        self:PaintQuantity(button)
    end
    if layout then
        button:ClearAllPoints()
        local stride = self.config.itemSize + self.config.itemSpacing
        button:SetPoint("TOPLEFT", ((slotIndex - 1) % 5) * stride, -startY - math.floor((slotIndex - 1) / 5) * stride)
        button:Show()
    end
end

function Tracker:Render()
    self.dirty = false
    local layout = self.layoutDirty
    self.layoutDirty = false
    if self.mode == "total" then
        self:RenderTotal(layout)
        return
    end
    if self.totalBlock then self.totalBlock:Hide() end
    local y = CONTENT_TOP
    for index, recipe in ipairs(self.recipes) do
        local block = self.blocks[index]
        if not block then block = self:NewBlock(); self.blocks[index] = block end
        if layout then
            block.recipe = recipe
            block:ClearAllPoints()
            block:SetPoint("TOPLEFT", 0, -y)
            block.name:SetText(recipe.name)
            block.close.ResetColor()
            block:Show()
        end
        self:UpdateRecipeText(block.name, recipe)
        local outputIcon = recipe.itemID and C_Item.GetItemIconByID(recipe.itemID) or recipe.icon
        if block.outputIcon ~= outputIcon then
            block.outputIcon = outputIcon
            block.iconSlot:SetIcon(outputIcon)
        end
        for slotIndex, slot in ipairs(recipe.slots) do
            local button = block.buttons[slotIndex]
            if not button then button = self:NewMaterial(block); block.buttons[slotIndex] = button end
            self:UpdateMaterial(button, slot, slotIndex, layout, 26)
        end
        local height = 26 + math.ceil(#recipe.slots / 5) * (self.config.itemSize + self.config.itemSpacing) + 12
        if layout then
            for i = #recipe.slots + 1, #block.buttons do block.buttons[i]:Hide() end
            block:SetHeight(height)
        end
        y = y + height
    end
    if layout then
        for i = #self.recipes + 1, #self.blocks do self.blocks[i]:Hide() end
        self.content:SetHeight(math.max(1, y))
    end
    local maximum = math.max(0, y - self.scroll:GetHeight())
    if self.scroll:GetVerticalScroll() > maximum then self.scroll:SetVerticalScroll(maximum) end
end

function Tracker:RenderTotal(layout)
    for _, block in ipairs(self.blocks) do block:Hide() end
    if self.totalsDirty then self:BuildTotals(); layout = true end
    local block = self.totalBlock
    if not block then
        block = GUI2:CreateFrame(self.content)
        block:SetWidth(210)
        block:SetPoint("TOPLEFT", 0, -CONTENT_TOP)
        block.buttons, block.checks = {}, {}
        block.title = self.config.createText(block, L["tracker.total_materials"], 12)
        block.title:SetPoint("TOPLEFT")
        block.title:SetHeight(20)
        block.title:SetJustifyV("MIDDLE")
        BindRecipeText(block.title)
        block.sources = self.config.createText(block, L["tracker.sources"], 12)
        block.sources:SetHeight(20)
        block.sources:SetJustifyV("MIDDLE")
        BindRecipeText(block.sources)
        block.empty = self.config.createText(block, L["tracker.none_selected"], 12)
        block.empty:SetPoint("TOPLEFT", 0, -26)
        self.totalBlock = block
    end
    block:Show()
    for index, slot in ipairs(self.totalSlots) do
        local button = block.buttons[index]
        if not button then button = self:NewMaterial(block); block.buttons[index] = button end
        self:UpdateMaterial(button, slot, index, layout, 26)
    end
    if not layout then
        for index, recipe in ipairs(self.recipes) do self:UpdateRecipeText(block.checks[index].text, recipe) end
        return
    end
    for i = #self.totalSlots + 1, #block.buttons do block.buttons[i]:Hide() end
    block.empty:SetShown(#self.totalSlots == 0)
    local rows = math.max(1, math.ceil(#self.totalSlots / 5))
    local y = 26 + rows * (self.config.itemSize + self.config.itemSpacing) + 12
    block.sources:ClearAllPoints()
    block.sources:SetPoint("TOPLEFT", 0, -y)
    y = y + 24
    for index, recipe in ipairs(self.recipes) do
        local checkbox = block.checks[index]
        if not checkbox then
            checkbox = GUI2.Form:CreateCheckbox(block, {
                width = 210, height = 26, text = "", checked = true,
                onChange = function(widget, checked) self:SetIncluded(widget.recipeKey, checked) end,
            })
            checkbox:HookScript("OnEnter", ns.HideGameTooltip)
            checkbox:HookScript("OnLeave", ns.HideGameTooltip)
            -- 名称单独承接提示，复选框区域只负责勾选。
            local nameHit = GUI2:CreateButtonFrame(checkbox)
            nameHit:SetAllPoints(checkbox.text)
            nameHit:SetScript("OnEnter", function()
                self:ShowRecipeTooltip(nameHit, checkbox.recipe)
            end)
            nameHit:SetScript("OnLeave", ns.HideGameTooltip)
            nameHit:SetScript("OnClick", function() checkbox:Click() end)
            checkbox.nameHit = nameHit
            BindRecipeText(checkbox.text)
            local refresh = checkbox.RefreshTheme
            if refresh then
                checkbox.RefreshTheme = function(widget, ...)
                    refresh(widget, ...)
                    widget.text:RefreshTheme()
                end
            end
            block.checks[index] = checkbox
        end
        checkbox.recipeKey, checkbox.recipeName = recipe.key, recipe.name
        checkbox.recipe = recipe
        checkbox.text:SetText(recipe.name)
        checkbox:SetChecked(not self.excluded[recipe.key], true)
        self:UpdateRecipeText(checkbox.text, recipe)
        checkbox.text:RefreshTheme()
        checkbox:ClearAllPoints()
        checkbox:SetPoint("TOPLEFT", 0, -y)
        checkbox:Show()
        y = y + 26
    end
    for i = #self.recipes + 1, #block.checks do block.checks[i]:Hide() end
    block:SetHeight(y + 8)
    self.content:SetHeight(y + 8 + CONTENT_TOP)
    local maximum = math.max(0, y + 8 + CONTENT_TOP - self.scroll:GetHeight())
    if self.scroll:GetVerticalScroll() > maximum then self.scroll:SetVerticalScroll(maximum) end
end
