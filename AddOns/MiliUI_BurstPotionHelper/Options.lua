local addonName, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Copyable command popup (the "copy URL"-style box)
----------------------------------------------------------------------
local function CreateCopyPopup()
    if ns.copyPopup then return ns.copyPopup end

    local f = CreateFrame("Frame", "MiliUI_BurstPotionHelperCopyPopup", UIParent, "BackdropTemplate")
    f:SetSize(440, 140)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    -- MiliUI borderless look: 1px pixel border + dark fill.
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.06, 0.06, 0.10, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:Hide()

    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -16)
    f.title:SetText(L.COPY_TITLE)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    -- Bordered box around the edit field
    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 20, -48)
    box:SetPoint("TOPRIGHT", -20, -48)
    box:SetHeight(30)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local eb = CreateFrame("EditBox", nil, box)
    eb:SetPoint("TOPLEFT", 8, -1)
    eb:SetPoint("BOTTOMRIGHT", -8, 1)
    eb:SetFontObject(ChatFontNormal)
    eb:SetAutoFocus(false)
    eb:SetTextInsets(0, 0, 0, 0)
    f.editBox = eb

    -- Make it effectively read-only: any edit snaps back to the command.
    eb:SetScript("OnTextChanged", function(self)
        if self.lockText and self:GetText() ~= self.lockText then
            self:SetText(self.lockText)
            self:HighlightText()
        end
    end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); f:Hide() end)

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -12)
    hint:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.COPY_HINT)
    hint:SetTextColor(1, 0.82, 0)

    tinsert(UISpecialFrames, f:GetName())
    ns.copyPopup = f
    return f
end

function ns.ShowCopyPopup(text)
    local f = CreateCopyPopup()
    f.editBox.lockText = text
    f.editBox:SetText(text)
    f:Show()
    f:Raise()
    f.editBox:SetFocus()
    f.editBox:HighlightText()
end

----------------------------------------------------------------------
-- Settings canvas panel (MiliUI style — Esc > Options > AddOns)
----------------------------------------------------------------------
local settingsCategory

local function CreateCheckbox(parent, label, anchor, dx, dy, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", dx, dy)
    cb:SetSize(26, 26)
    cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.Text:SetText(label)
    cb:SetScript("OnShow", function(self) self:SetChecked(get()) end)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    return cb
end

local function BuildPanel()
    local panel = CreateFrame("Frame", "MiliUI_BurstPotionHelperOptions", UIParent)
    panel.name = L.SETTINGS_TITLE
    panel.OnCommit, panel.OnDefault, panel.OnRefresh = function() end, function() end, function() end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.SETTINGS_TITLE)

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(540)
    desc:SetJustifyH("LEFT")
    desc:SetText(L.SETTINGS_DESC)

    -- Section: Options
    local sec1 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    sec1:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
    sec1:SetText("|cffffd100" .. L.SECTION_GENERAL .. "|r")

    local cbPrint = CreateCheckbox(panel, L.OPT_PRINT, sec1, 0, -8,
        function() return ns.GetDB().printOnSwitch end,
        function(v) ns.GetDB().printOnSwitch = v end)

    local cbShow = CreateCheckbox(panel, L.OPT_SHOW_BAR, cbPrint, 0, -2,
        function() return ns.GetDB().showBar end,
        function(v) ns.Bar_SetShown(v) end)

    local cbLock = CreateCheckbox(panel, L.OPT_LOCK_BAR, cbShow, 0, -2,
        function() return ns.GetDB().lockBar end,
        function(v) ns.GetDB().lockBar = v end)

    local cbRight = CreateCheckbox(panel, L.OPT_RIGHTCLICK, cbLock, 0, -2,
        function() return ns.GetDB().rightClickUse end,
        function(v) ns.SetRightClickUse(v) end)

    local cbCD = CreateCheckbox(panel, L.OPT_SHOW_CD, cbRight, 0, -2,
        function() return ns.GetDB().showCooldown end,
        function(v) ns.GetDB().showCooldown = v; ns.Bar_UpdateCooldowns() end)

    local cbTip = CreateCheckbox(panel, L.OPT_ITEM_TOOLTIP, cbCD, 0, -2,
        function() return ns.GetDB().showItemTooltip end,
        function(v) ns.GetDB().showItemTooltip = v end)

    -- Section: Macro
    local sec2 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    sec2:SetPoint("TOPLEFT", cbTip, "BOTTOMLEFT", 0, -16)
    sec2:SetText("|cffffd100" .. L.SECTION_MACRO .. "|r")

    local macroHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    macroHelp:SetPoint("TOPLEFT", sec2, "BOTTOMLEFT", 4, -8)
    macroHelp:SetWidth(540)
    macroHelp:SetJustifyH("LEFT")
    macroHelp:SetText(L.MACRO_HELP)

    local macroLine = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    macroLine:SetPoint("TOPLEFT", macroHelp, "BOTTOMLEFT", 0, -8)
    macroLine:SetText("|cff33ff33" .. ns.MACRO_LINE .. "|r")

    local copyBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copyBtn:SetSize(180, 24)
    copyBtn:SetPoint("TOPLEFT", macroLine, "BOTTOMLEFT", 0, -12)
    copyBtn:SetText(L.BTN_COPY_MACRO)
    copyBtn:SetScript("OnClick", function() ns.ShowCopyPopup(ns.MACRO_LINE) end)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(180, 24)
    resetBtn:SetPoint("LEFT", copyBtn, "RIGHT", 12, 0)
    resetBtn:SetText(L.BTN_RESET_POS)
    resetBtn:SetScript("OnClick", function() ns.Bar_ResetPosition() end)

    return panel
end

local panel = BuildPanel()
settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(settingsCategory)

----------------------------------------------------------------------
-- Potion list subcategory (editable list, modeled on BloodlustMusic's tracks)
----------------------------------------------------------------------
local LIST_WIDTH, LIST_HEIGHT, ROW_H = 560, 440, 28

local listPanel = CreateFrame("Frame", "MiliUI_BurstPotionHelperListPanel", UIParent)
listPanel.name = L.SECTION_LIST
listPanel.OnCommit, listPanel.OnDefault, listPanel.OnRefresh = function() end, function() end, function() end

local lTitle = listPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
lTitle:SetPoint("TOPLEFT", 16, -16)
lTitle:SetText(L.SECTION_LIST)

local lDesc = listPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
lDesc:SetPoint("TOPLEFT", lTitle, "BOTTOMLEFT", 0, -8)
lDesc:SetWidth(LIST_WIDTH); lDesc:SetJustifyH("LEFT")
lDesc:SetText(L.LIST_DESC)

local addBtn = CreateFrame("Button", nil, listPanel, "UIPanelButtonTemplate")
addBtn:SetSize(120, 24)
addBtn:SetPoint("TOPLEFT", lDesc, "BOTTOMLEFT", 0, -10)
addBtn:SetText(L.BTN_ADD_ITEM)
addBtn:SetScript("OnClick", function() ns.ShowAddItemDialog() end)

local restoreBtn = CreateFrame("Button", nil, listPanel, "UIPanelButtonTemplate")
restoreBtn:SetSize(120, 24)
restoreBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
restoreBtn:SetText(L.BTN_RESTORE_DEFAULTS)
restoreBtn:SetScript("OnClick", function() ns.RestoreDefaults() end)

local scrollArea = CreateFrame("Frame", nil, listPanel)
-- Fixed width (scrollbar stays right next to the list). Height is fitted to the
-- visible Settings window at show time (the canvas frame itself is taller than
-- what's actually on screen, so we can't anchor to its bottom).
scrollArea:SetPoint("TOPLEFT", addBtn, "BOTTOMLEFT", 0, -10)
scrollArea:SetWidth(LIST_WIDTH)
scrollArea:SetHeight(LIST_HEIGHT)
scrollArea:SetClipsChildren(true)

-- Size the list to fill from below the buttons down to just above the Settings
-- window's footer. Falls back to LIST_HEIGHT until geometry has resolved.
local function FitScrollArea()
    local top = scrollArea:GetTop()
    local sp = SettingsPanel
    local spBottom = sp and sp.IsShown and sp:IsShown() and sp:GetBottom()
    if top and spBottom then
        local h = top - spBottom - 44   -- keep clear of the footer / close button
        if h >= 140 then
            scrollArea:SetHeight(math.min(h, 1000))
            return
        end
    end
    scrollArea:SetHeight(LIST_HEIGHT)
end

local scrollChild = CreateFrame("Frame", nil, scrollArea)
scrollChild:SetPoint("TOPLEFT")
scrollChild:SetWidth(LIST_WIDTH)
scrollChild:SetHeight(1)

local scrollBar = CreateFrame("Slider", nil, listPanel)
scrollBar:SetPoint("TOPLEFT", scrollArea, "TOPRIGHT", 8, 0)
scrollBar:SetPoint("BOTTOMLEFT", scrollArea, "BOTTOMRIGHT", 8, 0)
scrollBar:SetWidth(16)
scrollBar:SetObeyStepOnDrag(true)
local sbBg = scrollBar:CreateTexture(nil, "BACKGROUND"); sbBg:SetAllPoints(); sbBg:SetColorTexture(0, 0, 0, 0.3)
local sbThumb = scrollBar:CreateTexture(nil, "OVERLAY"); sbThumb:SetSize(16, 40); sbThumb:SetColorTexture(0.6, 0.6, 0.6, 0.6)
scrollBar:SetThumbTexture(sbThumb)
scrollBar:SetMinMaxValues(0, 1); scrollBar:SetValueStep(1); scrollBar:SetValue(0)
scrollBar:SetScript("OnValueChanged", function(_, value)
    scrollChild:ClearAllPoints()
    scrollChild:SetPoint("TOPLEFT", 0, value)
end)
scrollBar:Hide()

scrollArea:EnableMouseWheel(true)
scrollArea:SetScript("OnMouseWheel", function(_, delta)
    local mn, mx = scrollBar:GetMinMaxValues()
    scrollBar:SetValue(math.max(mn, math.min(mx, scrollBar:GetValue() - delta * ROW_H)))
end)

local rows = {}

local function RowName(entry)
    local name = C_Item.GetItemNameByID(entry.id) or ("item:" .. entry.id)
    local q = ns.GetQualityLabel(entry.id)   -- from the item's real quality
    if q ~= "" then name = name .. " |cff888888(" .. q .. ")|r" end
    if entry.isCustom then name = name .. " |cff66aaff[" .. L.LABEL_CUSTOM .. "]|r" end
    return name
end

-- Set a row's icon + name. If the item's data isn't cached yet (first open),
-- the name falls back to "item:ID"; load it asynchronously and re-apply this row
-- the moment it arrives (the quality label loads separately and is already there).
local function ApplyRowItem(row, entry)
    row.icon:SetTexture((C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id)) or ns.FALLBACK_ICON)
    row.name:SetText(RowName(entry))
    if not C_Item.GetItemNameByID(entry.id) and Item and Item.CreateFromItemID then
        local id = entry.id
        Item:CreateFromItemID(id):ContinueOnItemLoad(function()
            if row.itemID == id then ApplyRowItem(row, entry) end  -- skip if row recycled
        end)
    end
end

local function CreateRow()
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetSize(LIST_WIDTH - 4, ROW_H)
    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(24, 24); row.check:SetPoint("LEFT", 0, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22); row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -30, 0)
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    row.del = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.del:SetSize(26, 26); row.del:SetPoint("RIGHT", 2, 0)
    row.hit = CreateFrame("Frame", nil, row)
    row.hit:SetPoint("TOPLEFT", row.icon, "TOPLEFT", 0, 0)
    row.hit:SetPoint("BOTTOMRIGHT", row.name, "BOTTOMRIGHT", 0, 0)
    row.hit:EnableMouse(true)
    row.hit:SetScript("OnEnter", function()
        if row.itemID then
            GameTooltip:SetOwner(row.hit, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(row.itemID)
            GameTooltip:Show()
        end
    end)
    row.hit:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

-- Fit the height to the window + recompute the scrollbar from the cached content
-- height. Cheap (no row rebuild / no closures), so OnSizeChanged can call it freely.
local listContentH = 1
local function UpdateListScroll()
    FitScrollArea()
    local viewH = scrollArea:GetHeight()
    if not viewH or viewH < 1 then viewH = LIST_HEIGHT end
    local maxScroll = math.max(0, listContentH - viewH)
    scrollBar:SetMinMaxValues(0, maxScroll)
    if maxScroll <= 0 then scrollBar:Hide(); scrollBar:SetValue(0) else scrollBar:Show() end
end

function ns.RefreshSettingsList()
    -- Build unconditionally (no IsShown guard): a Settings canvas reports
    -- IsShown()=false during its own OnShow, which would wrongly skip the build.
    local list = ns.RebuildItemList()  -- pure DB read → reflects toggles even in combat
    local y = 0
    for i, entry in ipairs(list) do
        local row = rows[i]
        if not row then row = CreateRow(); rows[i] = row end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row.itemID = entry.id
        ApplyRowItem(row, entry)   -- icon + name, with async load if not cached yet
        row.check:SetChecked(entry.enabled)
        row.check:SetScript("OnClick", function(self)
            ns.SetItemEnabled(entry.id, self:GetChecked() and true or false)
        end)
        row.del:SetScript("OnClick", function() ns.RemoveItem(entry.id) end)
        row:Show()
        row.check:Show(); row.icon:Show(); row.name:Show(); row.del:Show()  -- force-show children (canvas render quirk)
        y = y + ROW_H
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    scrollChild:SetHeight(math.max(y, 1))
    listContentH = y
    UpdateListScroll()  -- fit height + scrollbar (the cheap OnSizeChanged path reuses this)
end

-- Item names/icons stream in via ITEM_DATA_LOAD_RESULT. That's a global,
-- high-frequency event, so we only listen to it while this panel is on screen.
listPanel:SetScript("OnEvent", function(_, event)
    if event == "ITEM_DATA_LOAD_RESULT" then ns.RefreshSettingsList() end
end)
listPanel:SetScript("OnShow", function(self)
    self:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    ns.RefreshSettingsList()
end)
listPanel:SetScript("OnHide", function(self)
    self:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
end)
-- FitScrollArea needs the panel's on-screen geometry, which the Settings frame
-- resolves AFTER OnShow (when it sizes the canvas). Refit then — and only the
-- height/scrollbar, NOT a full row rebuild — so this stays cheap if it fires
-- repeatedly. Fires exactly when the real size is known, so no timer guesswork.
listPanel:SetScript("OnSizeChanged", function() UpdateListScroll() end)

----------------------------------------------------------------------
-- Add-potion dialog (type an item ID, or Shift-click an item to fill it)
----------------------------------------------------------------------
local function EnsureAddDialog()
    if ns.itemAddDialog then return ns.itemAddDialog end
    local f = CreateFrame("Frame", "MiliUI_BurstPotionHelperAddDialog", UIParent, "BackdropTemplate")
    f:SetSize(420, 150); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetToplevel(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.06, 0.10, 0.95); f:SetBackdropBorderColor(0, 0, 0, 1)
    f:Hide()

    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -14); f.title:SetText(L.ADD_TITLE)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 20, -44); hint:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    hint:SetJustifyH("LEFT"); hint:SetSpacing(2); hint:SetText(L.ADD_HINT); hint:SetTextColor(1, 0.82, 0)

    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 20, -82); box:SetPoint("TOPRIGHT", -20, -82); box:SetHeight(28)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    box:SetBackdropColor(0, 0, 0, 0.6); box:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local input = CreateFrame("EditBox", nil, box)
    input:SetPoint("TOPLEFT", 8, -1); input:SetPoint("BOTTOMRIGHT", -8, 1)
    input:SetFontObject(ChatFontNormal); input:SetAutoFocus(true)
    f.input = input

    local function submit()
        local text = strtrim(input:GetText() or "")
        local id = tonumber(text)
        if not id then
            local m = text:match("item:(%d+)")
            id = m and tonumber(m)
        end
        if not id then ns.Print(L.ADD_INVALID); return end
        local ok, reason = ns.AddItem(id)
        if ok or reason == "exists" then
            if reason == "exists" then ns.Print(L.ADD_EXISTS) end
            f:Hide()
        else
            ns.Print(L.ADD_INVALID)
        end
    end

    local okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okBtn:SetSize(90, 24); okBtn:SetPoint("BOTTOMRIGHT", -110, 14); okBtn:SetText(OKAY)
    okBtn:SetScript("OnClick", submit)
    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(90, 24); cancelBtn:SetPoint("BOTTOMRIGHT", -14, 14); cancelBtn:SetText(CANCEL)
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    input:SetScript("OnEnterPressed", submit)
    input:SetScript("OnEscapePressed", function() f:Hide() end)
    f:SetScript("OnHide", function() input:ClearFocus() end)
    tinsert(UISpecialFrames, f:GetName())

    ns.itemAddDialog = f
    return f
end

function ns.ShowAddItemDialog()
    local f = EnsureAddDialog()
    f.input:SetText("")
    f:Show(); f:Raise(); f.input:SetFocus()
end

-- Shift-click an item anywhere while the add dialog is open → fill its item ID.
hooksecurefunc("HandleModifiedItemClick", function(link)
    local f = ns.itemAddDialog
    if f and f:IsShown() and type(link) == "string" then
        local id = link:match("item:(%d+)")
        if id then f.input:SetText(id) end
    end
end)

local listSubcategory = Settings.RegisterCanvasLayoutSubcategory(settingsCategory, listPanel, listPanel.name)
Settings.RegisterAddOnCategory(listSubcategory)

function ns.OpenSettings()
    if Settings and Settings.OpenToCategory and settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------
SLASH_MILIUIBURST1 = "/mbh"
SLASH_MILIUIBURST2 = "/bursthelper"
SlashCmdList["MILIUIBURST"] = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "macro" or msg == "copy" then
        ns.ShowCopyPopup(ns.MACRO_LINE)
    elseif msg == "show" then
        ns.Bar_SetShown(true)
    elseif msg == "hide" then
        ns.Bar_SetShown(false)
    elseif msg == "reset" then
        ns.Bar_ResetPosition()
    else
        ns.OpenSettings()
    end
end
