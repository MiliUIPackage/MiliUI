if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end
DamageMeterTools = DamageMeterTools or {}
local L = DamageMeterTools_L or function(s) return s end
local T = DamageMeterToolsTheme

if not T then
    return
end

local console = nil
local currentPageKey = nil
local sidebarButtons = {}
local pages = {}
local refreshLock = false

local PAGE_ORDER = {
    { key = "Appearance", text = L("外觀") or "外觀" },
    { key = "Interaction", text = L("互動") or "互動" },
    { key = "Reset", text = L("重置數據") or "重置數據" },
    { key = "Layout", text = L("佈局") or "佈局" },
    { key = "Export", text = L("匯出") or "匯出" },
    { key = "Errors", text = L("錯誤記錄") or "錯誤記錄" },
    { key = "Addon", text = L("插件") or "插件" },
}

local function GetDB()
    return DamageMeterToolsDB
end

local function EnsureDB()
    local db = GetDB()

    db.texture = db.texture or {}
    if db.texture.source == nil then db.texture.source = "MATERIALS" end
    if db.texture.lsmName == nil then db.texture.lsmName = "Blizzard" end
    if db.texture.customTexturePath == nil then db.texture.customTexturePath = "" end
    if db.texture.hardDisabled == nil then db.texture.hardDisabled = false end
    if db.texture.restorePendingReload == nil then db.texture.restorePendingReload = false end
    if db.texture.backgroundMode == nil then db.texture.backgroundMode = "TRANSPARENT_BORDER" end
    if db.texture.backgroundAlpha == nil then db.texture.backgroundAlpha = 35 end
    if db.texture.compatMode == nil then db.texture.compatMode = false end
    if db.texture.showBorder == nil then db.texture.showBorder = false end
    if db.texture.displayMode == nil then db.texture.displayMode = "DEFAULT" end
    db.headerSkin = db.headerSkin or {}
    if db.headerSkin.style == nil then db.headerSkin.style = "GLASS" end
    if db.headerSkin.mode == nil then db.headerSkin.mode = "STYLE" end
    if db.headerSkin.lsmName == nil then db.headerSkin.lsmName = "Blizzard" end
    if db.headerSkin.showLines == nil then db.headerSkin.showLines = false end
    if db.headerSkin.titleFontSize == nil then db.headerSkin.titleFontSize = 14 end
    db.headerSkin.titleTextColor = db.headerSkin.titleTextColor or {}
    if db.headerSkin.titleTextColor.r == nil then db.headerSkin.titleTextColor.r = 1.00 end
    if db.headerSkin.titleTextColor.g == nil then db.headerSkin.titleTextColor.g = 0.82 end
    if db.headerSkin.titleTextColor.b == nil then db.headerSkin.titleTextColor.b = 0.20 end
    if db.headerSkin.titleTextColor.a == nil then db.headerSkin.titleTextColor.a = 1.00 end
    if db.headerSkin.titleFontName == nil then db.headerSkin.titleFontName = "GAME_DEFAULT" end
    if db.headerSkin.showModeSuffix == nil then db.headerSkin.showModeSuffix = false end
    db.headerSkin.suffixTextColor = db.headerSkin.suffixTextColor or {}
    if db.headerSkin.suffixTextColor.r == nil then db.headerSkin.suffixTextColor.r = 1.00 end
    if db.headerSkin.suffixTextColor.g == nil then db.headerSkin.suffixTextColor.g = 1.00 end
    if db.headerSkin.suffixTextColor.b == nil then db.headerSkin.suffixTextColor.b = 1.00 end
    if db.headerSkin.suffixTextColor.a == nil then db.headerSkin.suffixTextColor.a = 1.00 end
    if db.headerSkin.backgroundAlpha == nil then db.headerSkin.backgroundAlpha = 16 end
    db.headerSkin.backgroundColor = db.headerSkin.backgroundColor or {}
    if db.headerSkin.backgroundColor.r == nil then db.headerSkin.backgroundColor.r = 0.02 end
    if db.headerSkin.backgroundColor.g == nil then db.headerSkin.backgroundColor.g = 0.04 end
    if db.headerSkin.backgroundColor.b == nil then db.headerSkin.backgroundColor.b = 0.06 end
    if db.headerSkin.backgroundColor.a == nil then db.headerSkin.backgroundColor.a = 1.00 end
    if db.headerSkin.titleTextMode == nil then db.headerSkin.titleTextMode = "ALWAYS" end

    db.hover = db.hover or {}
    if db.hover.hideDelay == nil then db.hover.hideDelay = 2 end

    db.visibility = db.visibility or {}
    if db.visibility.mode == nil then
        db.visibility.mode = "HEADER_FADE"
    end

    db.combatHide = db.combatHide or {}
    if db.combatHide.fadeOutDelay == nil then db.combatHide.fadeOutDelay = 2 end
    if db.combatHide.fadeInTime == nil then db.combatHide.fadeInTime = 0.2 end
    if db.combatHide.fadeOutTime == nil then db.combatHide.fadeOutTime = 0.2 end
    if db.combatHide.hiddenAlpha == nil then db.combatHide.hiddenAlpha = 0 end
    if db.combatHide.enableFade == nil then db.combatHide.enableFade = true end
    db.combatHide.zoneFilter = db.combatHide.zoneFilter or {}
    if db.combatHide.zoneFilter.world == nil then db.combatHide.zoneFilter.world = true end
    if db.combatHide.zoneFilter.party == nil then db.combatHide.zoneFilter.party = false end
    if db.combatHide.zoneFilter.raid == nil then db.combatHide.zoneFilter.raid = false end
    if db.combatHide.zoneFilter.pvp == nil then db.combatHide.zoneFilter.pvp = false end
    if db.combatHide.zoneFilter.arena == nil then db.combatHide.zoneFilter.arena = false end

    db.autoreset = db.autoreset or {}
    if db.autoreset.combatStart == nil then db.autoreset.combatStart = false end
    if db.autoreset.bossStart == nil then db.autoreset.bossStart = false end
    if db.autoreset.mythicStart == nil then db.autoreset.mythicStart = false end
    if db.autoreset.mythicEnter == nil then db.autoreset.mythicEnter = false end
    if db.autoreset.instanceEnter == nil then db.autoreset.instanceEnter = false end
    if db.autoreset.notify == nil then db.autoreset.notify = true end
    if db.autoreset.confirmReset == nil then db.autoreset.confirmReset = true end

    -- ✅ 每條觸發的「彈窗確認」設定
    if db.autoreset.confirmCombatStart == nil then db.autoreset.confirmCombatStart = false end
    if db.autoreset.confirmBossStart == nil then db.autoreset.confirmBossStart = false end
    if db.autoreset.confirmMythicStart == nil then db.autoreset.confirmMythicStart = false end
    if db.autoreset.confirmMythicEnter == nil then db.autoreset.confirmMythicEnter = false end
    if db.autoreset.confirmInstanceEnter == nil then db.autoreset.confirmInstanceEnter = true end

    db.frameBind = db.frameBind or {}
    if db.frameBind.enableSnap == nil then db.frameBind.enableSnap = true end

    local snapGroupMode = tostring(db.frameBind.snapGroupMode or "123"):upper()
    if snapGroupMode == "ALL" then
        snapGroupMode = "123"
    end
    if snapGroupMode ~= "123" and snapGroupMode ~= "12" and snapGroupMode ~= "23" then
        snapGroupMode = "123"
    end
    db.frameBind.snapGroupMode = snapGroupMode

    if db.frameBind.win2Position == nil then db.frameBind.win2Position = "DOWN" end
    if db.frameBind.win3Position == nil then db.frameBind.win3Position = "RIGHT" end
    if db.frameBind.spacing == nil then db.frameBind.spacing = 0 end
    if db.frameBind.matchSize == nil then db.frameBind.matchSize = true end

    local sizeMode = tostring(db.frameBind.sizeSyncMode or "123"):upper()
    if sizeMode == "ALL" then
        sizeMode = "123"
    end
    if sizeMode ~= "123" and sizeMode ~= "12" and sizeMode ~= "23" then
        sizeMode = "123"
    end
    db.frameBind.sizeSyncMode = sizeMode

    if db.frameBind.freePositions == nil then db.frameBind.freePositions = {} end

    db.export = db.export or {}
    if db.export.topN == nil then db.export.topN = 5 end
    if db.export.cooldown == nil then db.export.cooldown = 1.5 end
    if db.export.hideRealm == nil then db.export.hideRealm = true end

    db.launcher = db.launcher or {}
    if db.launcher.minimap == nil then
        db.launcher.minimap = { hide = false }
    end

    db.contextMenu = db.contextMenu or {}
    if db.contextMenu.requireShift == nil then db.contextMenu.requireShift = false end

    db.theme = db.theme or {}
    if db.theme.style == nil then
        db.theme.style = "OCEAN"
    end

    db.locale = db.locale or {}
    if db.locale.override == nil then
        db.locale.override = "AUTO"
    end
        db.errors = db.errors or {}
    if db.errors.notify == nil then db.errors.notify = true end
    if db.errors.consoleOnly == nil then db.errors.consoleOnly = true end
    if db.errors.notifyInterval == nil then db.errors.notifyInterval = 5 end
    if db.errors.logMax == nil then db.errors.logMax = 60 end
    if db.errors.log == nil then db.errors.log = {} end
        if db.errors.showBlizzardDialog == nil then db.errors.showBlizzardDialog = false end

    db.restrictedPVP = db.restrictedPVP or {}
    if db.restrictedPVP.notify == nil then db.restrictedPVP.notify = true end

    db.modules = db.modules or {}
    if db.modules.Texture == nil then db.modules.Texture = true end
    if db.modules.Hover == nil then db.modules.Hover = true end
    if db.modules.FrameBind == nil then db.modules.FrameBind = true end
    if db.modules.Export == nil then db.modules.Export = true end
    if db.modules.ContextMenu == nil then db.modules.ContextMenu = true end
    if db.modules.HeaderSkin == nil then db.modules.HeaderSkin = true end
    if db.modules.CombatHide == nil then db.modules.CombatHide = false end
    if db.modules.AutoReset == nil then db.modules.AutoReset = false end

end

local function Notify(key)
    if DamageMeterTools and DamageMeterTools.NotifySettingsChanged then
        DamageMeterTools:NotifySettingsChanged(key)
    end
end

local function NormalizeVisibilityMode(mode)
    mode = tostring(mode or ""):upper()
    if mode ~= "ALWAYS" and mode ~= "HEADER_FADE" and mode ~= "COMBAT_HIDE" then
        return nil
    end
    return mode
end

local function GetVisibilityMode()
    local db = GetDB()
    db.visibility = db.visibility or {}

    local mode = NormalizeVisibilityMode(db.visibility.mode)
    if mode then
        return mode
    end

    -- 舊版設定自動遷移
    local inferred = "ALWAYS"
    if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
        if DamageMeterTools:IsModuleEnabled("CombatHide", false) then
            inferred = "COMBAT_HIDE"
        elseif DamageMeterTools:IsModuleEnabled("Hover", true) then
            inferred = "HEADER_FADE"
        else
            inferred = "ALWAYS"
        end
    end

    db.visibility.mode = inferred
    return inferred
end

local function SetVisibilityMode(mode)
    mode = NormalizeVisibilityMode(mode) or "ALWAYS"

    local db = GetDB()
    db.visibility = db.visibility or {}
    db.visibility.mode = mode

    if mode == "ALWAYS" then
        DamageMeterTools:SetModuleEnabled("Hover", false)
        DamageMeterTools:SetModuleEnabled("CombatHide", false)

    elseif mode == "HEADER_FADE" then
        DamageMeterTools:SetModuleEnabled("Hover", true)
        DamageMeterTools:SetModuleEnabled("CombatHide", false)

    elseif mode == "COMBAT_HIDE" then
        DamageMeterTools:SetModuleEnabled("Hover", false)
        DamageMeterTools:SetModuleEnabled("CombatHide", true)
    end
end

local function GetVisibilityModeDisplayText(mode)
    mode = NormalizeVisibilityMode(mode) or "ALWAYS"

    if mode == "HEADER_FADE" then
        return L("標題列漸隱") or "標題列漸隱"
    elseif mode == "COMBAT_HIDE" then
        return L("脫戰整窗隱藏") or "脫戰整窗隱藏"
    end

    return L("永遠顯示") or "永遠顯示"
end

local function GetThemeDisplayText(key)
    key = tostring(key or "OCEAN"):upper()
    if key == "DARK" then
        return L("深色") or "深色"
    elseif key == "GOLD" then
        return L("金色") or "金色"
    else
        return L("海洋") or "海洋"
    end
end

local function GetLocaleDisplayText(value)
    value = tostring(value or "AUTO"):upper()

    if value == "ZHTW" then
        return L("繁體中文") or "繁體中文"
    elseif value == "ZHCN" then
        return L("簡體中文") or "简体中文"
    elseif value == "ENUS" or value == "ENGB" or value == "ZHEN" then
        return L("英文") or "English"
    else
        return L("自動（跟隨遊戲客戶端）") or "自動（跟隨遊戲客戶端）"
    end
end

local function GetStoredLocaleOverride()
    if DamageMeterTools_GetLocaleOverride then
        return DamageMeterTools_GetLocaleOverride()
    end

    local db = GetDB()
    db.locale = db.locale or {}
    return tostring(db.locale.override or "AUTO")
end

local function SetStoredLocaleOverride(value)
    if DamageMeterTools_SetLocaleOverride then
        DamageMeterTools_SetLocaleOverride(value)
        return
    end

    local db = GetDB()
    db.locale = db.locale or {}
    db.locale.override = tostring(value or "AUTO")
end

local function GetGameLocaleDisplayText()
    local gameLocale = nil

    if DamageMeterTools_Locale and DamageMeterTools_Locale.GetGameLocale then
        gameLocale = DamageMeterTools_Locale:GetGameLocale()
    else
        gameLocale = GetLocale() or "enUS"
    end

    return GetLocaleDisplayText(gameLocale)
end

local function GetRestrictedPVPNotifySettingText()
    return L("進入戰場/競技場時顯示提示") or "Show notice when entering Battleground/Arena"
end

local function GetRestrictedPVPSectionTitleText()
    return L("戰場 / 競技場保護") or "Battleground / Arena Protection"
end

local function GetRestrictedPVPInfoText()
    return L("進入戰場或競技場時，DMT 會暫停部分美化，以降低暴雪介面警告機率。")
        or "When entering Battlegrounds or Arenas, DMT temporarily pauses some visual enhancements to reduce Blizzard UI warnings."
end

local function DMT_DoManualReset()
    if InCombatLockdown and InCombatLockdown() then
        print("|cffff4040[DMT]|r " .. (L("戰鬥中不可清空統計。") or "戰鬥中不可清空統計。"))
        return
    end
    if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
        C_DamageMeter.ResetAllCombatSessions()
        print("|cff00ff00[DMT]|r " .. (L("已清空傷害統計。") or "已清空傷害統計。"))
    else
        print("|cffff4040[DMT]|r " .. (L("找不到 C_DamageMeter.ResetAllCombatSessions（可能內建統計未啟用）") or "找不到 C_DamageMeter.ResetAllCombatSessions（可能內建統計未啟用）"))
    end
end

if StaticPopupDialogs and not StaticPopupDialogs["DMT_CONFIRM_RESET_METER"] then
    StaticPopupDialogs["DMT_CONFIRM_RESET_METER"] = {
        text = L("確定要清空傷害統計？") or "確定要清空傷害統計？",
        button1 = L("清空") or "清空",
        button2 = L("取消") or "取消",
        OnAccept = function()
            DMT_DoManualReset()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
end

local function ApplyConsoleTheme()
    if not console then
        return
    end

    T:ApplyStyle(T:GetStyleKey())
    T:ApplyBackdrop(console, "bg", "borderStrong")

    if console.header then
        T:ApplyBackdrop(console.header, "header", "border")
    end
    if console.sidebar then
        T:ApplyBackdrop(console.sidebar, "panel", "border")
    end
    if console.contentWrap then
        T:ApplyBackdrop(console.contentWrap, "panel", "border")
    end
    if console.footer then
        T:ApplyBackdrop(console.footer, "header", "border")
    end

    if console.title then
        console.title:SetTextColor(T:GetColor("text"))
    end
    if console.version then
        console.version:SetTextColor(T:GetColor("textDim"))
    end
    if console.themeBtn and console.themeBtn.Text then
        console.themeBtn.Text:SetText(GetThemeDisplayText(T:GetStyleKey()))
    end

    for _, btn in pairs(sidebarButtons) do
        if btn and btn.ApplyVisual then
            btn:ApplyVisual()
        end
    end

    for _, page in pairs(pages) do
        if page and page.scroll then
            T:StyleScrollBar(page.scroll)
        end
    end
end

local function CreateSidebarButton(parent, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(164, 38)
    btn._selected = false
    btn._textValue = text or ""

    T:ApplyBackdrop(btn, "darkButton", "border")

    btn.leftAccent = btn:CreateTexture(nil, "OVERLAY")
    btn.leftAccent:SetPoint("TOPLEFT", 0, 0)
    btn.leftAccent:SetPoint("BOTTOMLEFT", 0, 0)
    btn.leftAccent:SetWidth(3)
    btn.leftAccent:SetColorTexture(0.30, 0.72, 1.00, 0.18)

    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.Text:SetPoint("LEFT", 14, 0)
    btn.Text:SetText(btn._textValue)

    btn.indicator = btn:CreateTexture(nil, "OVERLAY")
    btn.indicator:SetPoint("TOPRIGHT", -8, -8)
    btn.indicator:SetPoint("BOTTOMRIGHT", -8, 8)
    btn.indicator:SetWidth(2)
    btn.indicator:SetColorTexture(T:GetColor("accentBlue"))
    btn.indicator:Hide()

    function btn:ApplyVisual()
        if self._selected then
            self:SetBackdropColor(T:GetColor("accentSoft"))
            self:SetBackdropBorderColor(T:GetColor("borderStrong"))
            self.leftAccent:SetColorTexture(T:GetColor("accentBlue"))
            self.Text:SetTextColor(T:GetColor("accent"))
            self.indicator:Show()
        else
            self:SetBackdropColor(T:GetColor("darkButton"))
            self:SetBackdropBorderColor(T:GetColor("border"))
            self.leftAccent:SetColorTexture(0.30, 0.72, 1.00, 0.18)
            self.Text:SetTextColor(T:GetColor("text"))
            self.indicator:Hide()
        end
    end

    btn:SetScript("OnEnter", function(self)
        if not self._selected then
            self:SetBackdropColor(T:GetColor("darkButtonHover"))
            self:SetBackdropBorderColor(T:GetColor("borderStrong"))
            self.leftAccent:SetColorTexture(T:GetColor("accentBlue"))
            self.Text:SetTextColor(1, 1, 1, 1)
        end
    end)

    btn:SetScript("OnLeave", function(self)
        self:ApplyVisual()
    end)

    btn:ApplyVisual()
    return btn
end

local function CreateContentScroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -12)
    scroll:SetPoint("BOTTOMRIGHT", -40, 12)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(740, 1)
    scroll:SetScrollChild(content)

    if scroll.ScrollBar then
        scroll.ScrollBar:ClearAllPoints()
        scroll.ScrollBar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -4, -16)
        scroll.ScrollBar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -4, 16)
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local sb = self.ScrollBar
        if not sb then return end
        local current = self:GetVerticalScroll()
        local minVal, maxVal = sb:GetMinMaxValues()
        local step = 36
        local newVal = current - delta * step
        if newVal < minVal then newVal = minVal end
        if newVal > maxVal then newVal = maxVal end
        self:SetVerticalScroll(newVal)
    end)

    T:StyleScrollBar(scroll)
    return scroll, content
end

local function CreateSection(parent, titleText, width)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width or 720, 30)

    s.accent = s:CreateTexture(nil, "ARTWORK")
    s.accent:SetPoint("LEFT", 0, 0)
    s.accent:SetSize(3, 18)
    s.accent:SetColorTexture(T:GetColor("accentBlue"))

    s.title = T:CreateText(s, titleText or "", "GameFontNormalLarge", "accent")
    s.title:SetPoint("LEFT", s.accent, "RIGHT", 8, 0)

    s.line = s:CreateTexture(nil, "ARTWORK")
    s.line:SetHeight(1)
    s.line:SetPoint("LEFT", s.title, "RIGHT", 10, 0)
    s.line:SetPoint("RIGHT", 0, 0)
    local r, g, b = T:GetColor("accentBlue")
    s.line:SetColorTexture(r, g, b, 0.22)

    return s
end

local function CreateCheck(parent, labelText, getFunc, setFunc)
    local cb = T:CreateCheckButton(parent, labelText)
    cb:SetSize(420, 24)

    cb:SetScript("OnClick", function(self)
        if refreshLock then return end
        if setFunc then
            setFunc(self:GetChecked() and true or false)
        end
        if self.RefreshVisual then
            self:RefreshVisual()
        end
    end)

    cb.RefreshValue = function(self)
        if getFunc then
            self:SetChecked(getFunc() and true or false)
        end
        if self.RefreshVisual then
            self:RefreshVisual()
        end
    end

    return cb
end

local function CreateSlider(parent, labelText, minVal, maxVal, step, fmt, getFunc, setFunc)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetSize(360, 52)

    wrap.label = T:CreateText(wrap, labelText, "GameFontHighlight", "text")
    wrap.label:SetPoint("TOPLEFT", 0, -2)

    wrap.slider = CreateFrame("Slider", nil, wrap, "OptionsSliderTemplate")
    wrap.slider:SetPoint("TOPLEFT", 0, -18)
    wrap.slider:SetWidth(220)
    wrap.slider:SetMinMaxValues(minVal, maxVal)
    wrap.slider:SetValueStep(step)
    wrap.slider:SetObeyStepOnDrag(true)

    if wrap.slider.Low then wrap.slider.Low:SetText(tostring(minVal)) end
    if wrap.slider.High then wrap.slider.High:SetText(tostring(maxVal)) end
    if wrap.slider.Text then wrap.slider.Text:SetText("") end

    wrap.value = T:CreateText(wrap, "", "GameFontHighlightSmall", "accent")
    wrap.value:SetPoint("LEFT", wrap.slider, "RIGHT", 10, 0)

    wrap.slider:SetScript("OnValueChanged", function(_, value)
        if refreshLock then return end

        local v
        if step >= 1 then
            v = math.floor(value + 0.5)
        else
            local base = 1 / step
            v = math.floor(value * base + 0.5) / base
        end

        if setFunc then
            setFunc(v)
        end

        if fmt then
            wrap.value:SetText(string.format(fmt, v))
        else
            wrap.value:SetText(tostring(v))
        end
    end)

    wrap.RefreshValue = function(self)
        if getFunc then
            local v = getFunc()
            self.slider:SetValue(v)
            if fmt then
                self.value:SetText(string.format(fmt, v))
            else
                self.value:SetText(tostring(v))
            end
        end
    end

    return wrap
end

local function CreateActionButton(parent, text, width, onClick, style)
    return T:CreateButton(parent, text, width or 130, 24, onClick, style or "DARK")
end

local function CreateChoiceButton(parent, text, width, onClick)
    local b = T:CreateButton(parent, text, width or 110, 24, onClick, "DARK")
    b._selectedStyle = false

    function b:SetSelectedVisual(selected)
        self._selectedStyle = selected and true or false
        self._style = self._selectedStyle and "BLUE" or "DARK"
        local leave = self:GetScript("OnLeave")
        if leave then
            leave(self)
        end
    end

    return b
end

local function CreateInfoText(parent, width)
    local fs = T:CreateText(parent, "", "GameFontHighlightSmall", "text2")
    fs:SetWidth(width or 680)
    fs:SetJustifyH("LEFT")
    return fs
end

local function CreateColorSwatch(parent, labelText)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetSize(220, 20)

    wrap.label = T:CreateText(wrap, labelText or "", "GameFontHighlightSmall", "text2")
    wrap.label:SetPoint("LEFT", 0, 0)

    wrap.box = CreateFrame("Frame", nil, wrap, "BackdropTemplate")
    wrap.box:SetSize(16, 16)
    wrap.box:SetPoint("LEFT", wrap.label, "RIGHT", 8, 0)
    T:ApplyBackdrop(wrap.box, "panel2", "border")

    wrap.color = wrap.box:CreateTexture(nil, "ARTWORK")
    wrap.color:SetPoint("TOPLEFT", 1, -1)
    wrap.color:SetPoint("BOTTOMRIGHT", -1, 1)
    wrap.color:SetColorTexture(1, 1, 1, 1)

    function wrap:SetSwatchColor(r, g, b, a)
        self.color:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
    end

    return wrap
end

local function OpenColorPicker(initialColor, onChanged)
    if not ColorPickerFrame then
        return
    end

    local color = initialColor or { r = 1, g = 1, b = 1, a = 1 }

    local function Callback(restore)
        local newR, newG, newB, newA

        if restore then
            newR = restore.r
            newG = restore.g
            newB = restore.b
            newA = restore.a
        else
            if ColorPickerFrame.GetColorRGB then
                newR, newG, newB = ColorPickerFrame:GetColorRGB()
            else
                newR, newG, newB = 1, 1, 1
            end

            if OpacitySliderFrame and OpacitySliderFrame.GetValue then
                newA = 1 - OpacitySliderFrame:GetValue()
            else
                newA = color.a or 1
            end
        end

        if onChanged then
            onChanged(newR, newG, newB, newA)
        end
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        local info = {}
        info.r = color.r or 1
        info.g = color.g or 1
        info.b = color.b or 1
        info.opacity = 1 - (color.a or 1)
        info.hasOpacity = true
        info.swatchFunc = Callback
        info.opacityFunc = Callback
        info.cancelFunc = Callback
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - (color.a or 1)
        ColorPickerFrame.previousValues = {
            r = color.r or 1,
            g = color.g or 1,
            b = color.b or 1,
            a = color.a or 1,
        }
        ColorPickerFrame.func = function() Callback(nil) end
        ColorPickerFrame.opacityFunc = function() Callback(nil) end
        ColorPickerFrame.cancelFunc = function(prev)
            Callback(prev or ColorPickerFrame.previousValues)
        end
        ColorPickerFrame:SetColorRGB(color.r or 1, color.g or 1, color.b or 1)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

local function RefreshPage(page)
    if not page then return end
    if page.RefreshValue then
        page:RefreshValue()
    end
end

local function RefreshAllPages()
    for _, page in pairs(pages) do
        RefreshPage(page)
    end
end

local function SelectPage(pageKey)
    currentPageKey = pageKey

    for key, btn in pairs(sidebarButtons) do
        btn._selected = (key == pageKey)
        btn:ApplyVisual()
    end

    for key, page in pairs(pages) do
        if key == pageKey then
            page:Show()
            RefreshPage(page)
        else
            page:Hide()
        end
    end
end

local function BuildAppearancePage(parent)
    local scroll, content = CreateContentScroll(parent)
    parent.scroll = scroll
    parent.content = content

    local y = -10
    local function Place(widget, h, gap)
        widget:SetPoint("TOPLEFT", 10, y)
        y = y - (h or widget:GetHeight() or 24) - (gap or 10)
    end

    local function CreateOptionCard(parentFrame, titleText, width, height)
        local card = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        card:SetSize(width or 720, height or 120)
        T:ApplyBackdrop(card, "panel2", "border")

        card.title = T:CreateText(card, titleText or "", "GameFontHighlight", "accent")
        card.title:SetPoint("TOPLEFT", 12, -10)

        card.sep = card:CreateTexture(nil, "ARTWORK")
        card.sep:SetPoint("TOPLEFT", 10, -30)
        card.sep:SetPoint("TOPRIGHT", -10, -30)
        card.sep:SetHeight(1)
        local r, g, b = T:GetColor("accentBlue")
        card.sep:SetColorTexture(r, g, b, 0.20)

        return card
    end

    local function CreateMiniButton(parentFrame, text, width, onClick, style)
        return T:CreateButton(parentFrame, text or "↺", width or 54, 22, onClick, style or "DARK")
    end

        local function BuildPreviewTitleText()
        local base = L("傷害量") or "傷害量"

        if not GetDB().headerSkin.showModeSuffix then
            return base
        end

        local c = GetDB().headerSkin.suffixTextColor or {}
        local r = tonumber(c.r) or 1
        local g = tonumber(c.g) or 1
        local b = tonumber(c.b) or 1

        local hex = string.format(
            "%02x%02x%02x",
            math.floor(r * 255 + 0.5),
            math.floor(g * 255 + 0.5),
            math.floor(b * 255 + 0.5)
        )

        return base .. " |cff" .. hex .. (L("總體") or "Overall") .. "|r"
    end
        ----------------------------------------------------------------
    -- 顯示模式（外觀）
    ----------------------------------------------------------------
    local secDisplay = CreateSection(content, L("顯示模式（外觀）") or "顯示模式", 720)
    Place(secDisplay, 30)

    local displayInfo = CreateInfoText(content, 700)
    displayInfo:SetText(L("貼邊模式說明") or "貼邊模式會隱藏捲動條，數據列延伸到視窗邊緣。")
    Place(displayInfo, 18, 10)

    local displayRow = CreateFrame("Frame", nil, content)
    displayRow:SetSize(720, 28)

    local btnDisplayDefault = CreateChoiceButton(displayRow, L("預設模式") or "預設模式", 120, function()
        GetDB().texture.displayMode = "DEFAULT"
        Notify("Texture")
        RefreshPage(parent)
    end)
    btnDisplayDefault:SetPoint("LEFT", 0, 0)

    local btnDisplayEdge = CreateChoiceButton(displayRow, L("貼邊模式") or "貼邊模式", 120, function()
        GetDB().texture.displayMode = "EDGE"
        Notify("Texture")
        RefreshPage(parent)
    end)
    btnDisplayEdge:SetPoint("LEFT", btnDisplayDefault, "RIGHT", 8, 0)

    Place(displayRow, 28, 10)
    ----------------------------------------------------------------
    -- 數據列材質
    ----------------------------------------------------------------
    local secTexture = CreateSection(content, L("數據列材質") or "數據列材質", 720)
    Place(secTexture, 30)

local cbTexture = CreateCheck(content, L("啟用數據列材質美化"), function()
    return DamageMeterTools:IsModuleEnabled("Texture", true)
end, function(v)
    local db = GetDB()
    DamageMeterTools:SetModuleEnabled("Texture", v)
    if v then
        db.texture.hardDisabled = false
        db.texture.restorePendingReload = false
    end
    Notify("Texture")
    RefreshPage(parent)
end)

    Place(cbTexture, 24)

    local bgModeTitle = T:CreateText(content, L("數據列背景模式") or "數據列背景模式", "GameFontHighlight", "accent")
    bgModeTitle:SetWidth(700)
    bgModeTitle:SetJustifyH("LEFT")
    Place(bgModeTitle, 20)

    local bgModeRow = CreateFrame("Frame", nil, content)
    bgModeRow:SetSize(720, 28)

    local btnTexTransparentBorder = CreateChoiceButton(bgModeRow, L("顯示外框線") or "顯示外框線", 120, function()
        GetDB().texture.backgroundMode = "TRANSPARENT_BORDER"
        Notify("Texture")
        RefreshPage(parent)
    end)
    btnTexTransparentBorder:SetPoint("LEFT", 0, 0)

    local btnTexTransparentBorderless = CreateChoiceButton(bgModeRow, L("移除外框線") or "移除外框線", 120, function()
        GetDB().texture.backgroundMode = "TRANSPARENT_BORDERLESS"
        Notify("Texture")
        RefreshPage(parent)
    end)
    btnTexTransparentBorderless:SetPoint("LEFT", btnTexTransparentBorder, "RIGHT", 8, 0)

    Place(bgModeRow, 28)

    local btnPickTexture = CreateActionButton(content, L("選擇數據列材質"), 160, function(selfBtn)
        if not DamageMeterTools_OpenTexturePicker then
            return
        end

        local currentSelection
        if tostring(GetDB().texture.source or "MATERIALS"):upper() == "MATERIALS" then
            currentSelection = "__DMT_BUILTIN_MATERIALS__"
        else
            currentSelection = GetDB().texture.lsmName or "Blizzard"
        end

        DamageMeterTools_OpenTexturePicker(selfBtn, currentSelection, function(name)
        local db = GetDB()
        DamageMeterTools:SetModuleEnabled("Texture", true)
        db.texture.hardDisabled = false
        db.texture.restorePendingReload = false

            if name == "__DMT_BUILTIN_MATERIALS__" then
                db.texture.source = "MATERIALS"
                db.texture.lsmName = "Blizzard"
            elseif name == "__DMT_BUILTIN_NONE__" then
                db.texture.source = "DEFAULT"
                db.texture.lsmName = "Blizzard"
            else
                db.texture.source = "LSM"
                db.texture.lsmName = name
            end

            Notify("Texture")
            RefreshPage(parent)
        end, {
            includeBuiltIn = true,
            title = L("選擇數據列材質") or "選擇數據列材質",
        })
    end, "BLUE")
    Place(btnPickTexture, 24)

    local sliderBgAlpha = CreateSlider(content, L("數據列背景透明度（0-100）") or "數據列背景透明度（0-100）", 0, 100, 1, "%d%%", function()
        local db = GetDB()
        db.texture = db.texture or {}
        return tonumber(db.texture.backgroundAlpha) or 35
    end, function(v)
        local db = GetDB()
        db.texture = db.texture or {}
        db.texture.backgroundAlpha = v
        Notify("Texture")
    end)
    Place(sliderBgAlpha, 52)

    local cbCompatMode = CreateCheck(content, L("相容模式（延後刷新，建議 ElvUI 使用者開啟）") or "相容模式（延後刷新，建議 ElvUI 使用者開啟）", function()
        local db = GetDB()
        db.texture = db.texture or {}
        return db.texture.compatMode == true
    end, function(v)
        local db = GetDB()
        db.texture = db.texture or {}
        db.texture.compatMode = v and true or false
        Notify("Texture")
        RefreshPage(parent)
    end)
    Place(cbCompatMode, 24)

    local textureInfo = CreateInfoText(content, 700)
    Place(textureInfo, 18, 16)

    ----------------------------------------------------------------
    -- 標題列總區
    ----------------------------------------------------------------
    local secHeader = CreateSection(content, L("標題列") or "標題列", 720)
    Place(secHeader, 30)

local cbHeader = CreateCheck(content, L("啟用標題列美化"), function()
    return DamageMeterTools:IsModuleEnabled("HeaderSkin", true)
end, function(v)
    DamageMeterTools:SetModuleEnabled("HeaderSkin", v)
    Notify("HeaderSkin")
    RefreshPage(parent)
end)
    Place(cbHeader, 24)

    ----------------------------------------------------------------
    -- 卡片1：文字
    ----------------------------------------------------------------
    local cardText = CreateOptionCard(content, L("標題文字") or "標題文字", 720, 142)

    local sliderHeaderFontSize = CreateSlider(cardText, L("標題文字大小"), 10, 24, 1, "%d", function()
        return tonumber(GetDB().headerSkin.titleFontSize) or 14
    end, function(v)
        GetDB().headerSkin.titleFontSize = v
        GetDB().headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
    end)
    sliderHeaderFontSize:SetPoint("TOPLEFT", 12, -38)

    local headerFontRow = CreateFrame("Frame", nil, cardText)
    headerFontRow:SetSize(690, 26)
    headerFontRow:SetPoint("TOPLEFT", sliderHeaderFontSize, "BOTTOMLEFT", 0, -10)

    local btnPickHeaderFont = CreateActionButton(headerFontRow, L("選擇標題字型") or "選擇標題字型", 170, function(selfBtn)
        if not DamageMeterTools_OpenFontPicker then
            return
        end

        local currentSelection = GetDB().headerSkin.titleFontName or "GAME_DEFAULT"

        DamageMeterTools_OpenFontPicker(selfBtn, currentSelection, function(name)
            local db = GetDB()
            db.headerSkin = db.headerSkin or {}
            db.headerSkin.titleFontName = name or "GAME_DEFAULT"
            db.headerSkin.titleTextMode = "ALWAYS"
            Notify("HeaderSkin")
            RefreshPage(parent)
        end)
    end, "BLUE")
    btnPickHeaderFont:SetPoint("LEFT", 0, 0)

local cbShowSuffix = CreateCheck(cardText, L("總體時在標題後加上「總體」") or "總體時在標題後加上「總體」", function()
    return GetDB().headerSkin.showModeSuffix == true
end, function(v)
    GetDB().headerSkin.showModeSuffix = v and true or false
    GetDB().headerSkin.titleTextMode = "ALWAYS"
    Notify("HeaderSkin")

    if DamageMeterTools_HeaderSkinApplyNow then
        DamageMeterTools_HeaderSkinApplyNow()
    end

    RefreshPage(parent)
end)

    cbShowSuffix:SetPoint("TOPLEFT", headerFontRow, "BOTTOMLEFT", 0, -8)
    local headerFontInfo = CreateInfoText(headerFontRow, 460)
    headerFontInfo:SetPoint("LEFT", btnPickHeaderFont, "RIGHT", 12, 0)


    Place(cardText, 142, 12)

    ----------------------------------------------------------------
    -- 卡片2：顏色與標記
    ----------------------------------------------------------------
    local cardColor = CreateOptionCard(content, L("標題文字") or "標題文字", 720, 160)
    local rowTitleColor = CreateFrame("Frame", nil, cardColor)
    rowTitleColor:SetSize(690, 24)
    rowTitleColor:SetPoint("TOPLEFT", 12, -38)

    local LABEL_WIDTH = 180
    local SWATCH_X = LABEL_WIDTH + 8
    local PICK_X = 250
    local RESET_X = 348

    local titleColorLabel = T:CreateText(rowTitleColor, L("目前標題文字顏色") or "目前標題文字顏色", "GameFontHighlightSmall", "text2")
    titleColorLabel:SetPoint("LEFT", 0, 0)
    titleColorLabel:SetWidth(LABEL_WIDTH)
    titleColorLabel:SetJustifyH("LEFT")

    local titleColorSwatch = CreateColorSwatch(rowTitleColor, "")
    titleColorSwatch:ClearAllPoints()
    titleColorSwatch:SetPoint("LEFT", rowTitleColor, "LEFT", SWATCH_X, 0)

    local btnPickHeaderColor = CreateActionButton(rowTitleColor, L("選擇") or "選擇", 92, function()
        local db = GetDB()
        db.headerSkin = db.headerSkin or {}
        db.headerSkin.titleTextColor = db.headerSkin.titleTextColor or {
            r = 1.00, g = 0.82, b = 0.20, a = 1.00
        }

        OpenColorPicker(db.headerSkin.titleTextColor, function(r, g, b, a)
            db.headerSkin.titleTextColor.r = r
            db.headerSkin.titleTextColor.g = g
            db.headerSkin.titleTextColor.b = b
            db.headerSkin.titleTextColor.a = a
            db.headerSkin.titleTextMode = "ALWAYS"
            Notify("HeaderSkin")
            RefreshPage(parent)
        end)
    end, "BLUE")
    btnPickHeaderColor:ClearAllPoints()
    btnPickHeaderColor:SetPoint("LEFT", rowTitleColor, "LEFT", PICK_X, 0)

    local btnResetHeaderColor = CreateMiniButton(rowTitleColor, "↺", 38, function()
        local db = GetDB()
        db.headerSkin.titleTextColor = {
            r = 1.00, g = 0.82, b = 0.20, a = 1.00,
        }
        db.headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
        RefreshPage(parent)
    end, "DARK")
    btnResetHeaderColor:ClearAllPoints()
    btnResetHeaderColor:SetPoint("LEFT", rowTitleColor, "LEFT", RESET_X, 0)

-- 總體後綴顏色
local suffixColorLabel = T:CreateText(rowTitleColor, L("總體後綴顏色") or "總體後綴顏色", "GameFontHighlightSmall", "text2")
suffixColorLabel:SetPoint("LEFT", 0, -28)
suffixColorLabel:SetWidth(LABEL_WIDTH)
suffixColorLabel:SetJustifyH("LEFT")

local suffixColorSwatch = CreateColorSwatch(rowTitleColor, "")
suffixColorSwatch:ClearAllPoints()
suffixColorSwatch:SetPoint("LEFT", rowTitleColor, "LEFT", SWATCH_X, -28)

local btnPickSuffixColor = CreateActionButton(rowTitleColor, L("選擇") or "選擇", 92, function()
    local db = GetDB()
    db.headerSkin = db.headerSkin or {}
    db.headerSkin.suffixTextColor = db.headerSkin.suffixTextColor or { r=1, g=1, b=1, a=1 }

    OpenColorPicker(db.headerSkin.suffixTextColor, function(r, g, b, a)
        db.headerSkin.suffixTextColor.r = r
        db.headerSkin.suffixTextColor.g = g
        db.headerSkin.suffixTextColor.b = b
        db.headerSkin.suffixTextColor.a = a
        db.headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
        if DamageMeterTools_HeaderSkinApplyNow then
            DamageMeterTools_HeaderSkinApplyNow()
        end
        RefreshPage(parent)
    end)
end, "BLUE")
btnPickSuffixColor:ClearAllPoints()
btnPickSuffixColor:SetPoint("LEFT", rowTitleColor, "LEFT", PICK_X, -28)

local btnResetSuffixColor = CreateMiniButton(rowTitleColor, "↺", 38, function()
    local db = GetDB()
    db.headerSkin.suffixTextColor = { r=1, g=1, b=1, a=1 }
    db.headerSkin.titleTextMode = "ALWAYS"
    Notify("HeaderSkin")
    if DamageMeterTools_HeaderSkinApplyNow then
        DamageMeterTools_HeaderSkinApplyNow()
    end
    RefreshPage(parent)
end, "DARK")
btnResetSuffixColor:ClearAllPoints()
btnResetSuffixColor:SetPoint("LEFT", rowTitleColor, "LEFT", RESET_X, -28)

    local headerModeInfo = CreateInfoText(cardColor, 680)
    headerModeInfo:SetPoint("TOPLEFT", rowTitleColor, "BOTTOMLEFT", 0, -10)

    local headerPreviewBox = CreateFrame("Frame", nil, cardColor, "BackdropTemplate")
    headerPreviewBox:SetSize(690, 60)
    T:ApplyBackdrop(headerPreviewBox, "panel", "border")
    headerPreviewBox:SetPoint("TOPLEFT", headerModeInfo, "BOTTOMLEFT", 0, -10)

    headerPreviewBox.label = T:CreateText(headerPreviewBox, L("即時預覽") or "即時預覽", "GameFontHighlightSmall", "text2")
    headerPreviewBox.label:SetPoint("TOPLEFT", 10, -8)

    headerPreviewBox.previewText = headerPreviewBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerPreviewBox.previewText:SetPoint("LEFT", 12, -8)
    headerPreviewBox.previewText:SetPoint("RIGHT", -12, -8)
    headerPreviewBox.previewText:SetJustifyH("LEFT")
    headerPreviewBox.previewText:SetText(L("傷害量") or "傷害量")

    Place(cardColor, 160, 12)
    ----------------------------------------------------------------
    -- 卡片3：背景
    ----------------------------------------------------------------
    local cardBackground = CreateOptionCard(content, L("背景與外框") or "背景與外框", 720, 160)

    local cbHeaderLines = CreateCheck(cardBackground, L("顯示標題列外框線"), function()
        return GetDB().headerSkin.showLines
    end, function(v)
        GetDB().headerSkin.showLines = v
        GetDB().headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
        RefreshPage(parent)
    end)
    cbHeaderLines:SetPoint("TOPLEFT", 12, -38)

    local headerBgAlpha = CreateSlider(cardBackground, L("標題背景透明度（0-100）") or "標題背景透明度（0-100）", 0, 100, 1, "%d%%", function()
        return tonumber(GetDB().headerSkin.backgroundAlpha) or 16
    end, function(v)
        GetDB().headerSkin.backgroundAlpha = v
        GetDB().headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
    end)
    headerBgAlpha:SetPoint("TOPLEFT", cbHeaderLines, "BOTTOMLEFT", 0, -8)

    local rowBgColor = CreateFrame("Frame", nil, cardBackground)
    rowBgColor:SetSize(690, 24)
    rowBgColor:SetPoint("TOPLEFT", headerBgAlpha, "BOTTOMLEFT", 0, -8)

    local bgColorLabel = T:CreateText(rowBgColor, L("目前背景顏色") or "目前背景顏色", "GameFontHighlightSmall", "text2")
    bgColorLabel:SetPoint("LEFT", 0, 0)

    local bgColorSwatch = CreateColorSwatch(rowBgColor, "")
    bgColorSwatch:SetPoint("LEFT", bgColorLabel, "RIGHT", 8, 0)

    local btnPickHeaderBgColor = CreateActionButton(rowBgColor, L("選擇") or "選擇", 92, function()
        local db = GetDB()
        db.headerSkin = db.headerSkin or {}
        db.headerSkin.backgroundColor = db.headerSkin.backgroundColor or {
            r = 0.02, g = 0.04, b = 0.06, a = 1.00
        }

        OpenColorPicker(db.headerSkin.backgroundColor, function(r, g, b, a)
            db.headerSkin.backgroundColor.r = r
            db.headerSkin.backgroundColor.g = g
            db.headerSkin.backgroundColor.b = b
            db.headerSkin.backgroundColor.a = a
            db.headerSkin.titleTextMode = "ALWAYS"
            Notify("HeaderSkin")
            RefreshPage(parent)
        end)
    end, "BLUE")
    btnPickHeaderBgColor:SetPoint("LEFT", bgColorSwatch, "RIGHT", 10, 0)

    local btnResetHeaderBgColor = CreateMiniButton(rowBgColor, "↺", 38, function()
        local db = GetDB()
        db.headerSkin.backgroundColor = {
            r = 0.02, g = 0.04, b = 0.06, a = 1.00,
        }
        db.headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
        RefreshPage(parent)
    end, "DARK")
    btnResetHeaderBgColor:SetPoint("LEFT", btnPickHeaderBgColor, "RIGHT", 6, 0)

    Place(cardBackground, 160, 12)

    ----------------------------------------------------------------
    -- 卡片4：風格與材質
    ----------------------------------------------------------------
    local cardStyle = CreateOptionCard(content, L("風格與材質") or "風格與材質", 720, 154)

    local styleRow = CreateFrame("Frame", nil, cardStyle)
    styleRow:SetSize(690, 28)
    styleRow:SetPoint("TOPLEFT", 12, -40)

    local btnGlass = CreateChoiceButton(styleRow, L("玻璃") or "玻璃", 96, function()
        GetDB().headerSkin.style = "GLASS"
        GetDB().headerSkin.mode = "STYLE"
        GetDB().headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
        RefreshPage(parent)
    end)
    btnGlass:SetPoint("LEFT", 0, 0)

    local btnGold = CreateChoiceButton(styleRow, L("金色") or "金色", 96, function()
        GetDB().headerSkin.style = "GOLD"
        GetDB().headerSkin.mode = "STYLE"
        GetDB().headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
        RefreshPage(parent)
    end)
    btnGold:SetPoint("LEFT", btnGlass, "RIGHT", 8, 0)

    local btnSteel = CreateChoiceButton(styleRow, L("鋼鐵") or "鋼鐵", 96, function()
        GetDB().headerSkin.style = "STEEL"
        GetDB().headerSkin.mode = "STYLE"
        GetDB().headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
        RefreshPage(parent)
    end)
    btnSteel:SetPoint("LEFT", btnGold, "RIGHT", 8, 0)

    local btnNeon = CreateChoiceButton(styleRow, L("霓光") or "霓光", 96, function()
        GetDB().headerSkin.style = "NEON"
        GetDB().headerSkin.mode = "STYLE"
        GetDB().headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
        RefreshPage(parent)
    end)
    btnNeon:SetPoint("LEFT", btnSteel, "RIGHT", 8, 0)

    local modeRow = CreateFrame("Frame", nil, cardStyle)
    modeRow:SetSize(690, 28)
    modeRow:SetPoint("TOPLEFT", styleRow, "BOTTOMLEFT", 0, -10)

    local btnHeaderStyle = CreateChoiceButton(modeRow, L("內建風格") or "內建風格", 116, function()
        GetDB().headerSkin.mode = "STYLE"
        GetDB().headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
        RefreshPage(parent)
    end)
    btnHeaderStyle:SetPoint("LEFT", 0, 0)

    local btnHeaderLSM = CreateChoiceButton(modeRow, "SharedMedia", 116, function()
        GetDB().headerSkin.mode = "LSM"
        GetDB().headerSkin.titleTextMode = "ALWAYS"
        Notify("HeaderSkin")
        RefreshPage(parent)
    end)
    btnHeaderLSM:SetPoint("LEFT", btnHeaderStyle, "RIGHT", 8, 0)

    local btnPickHeader = CreateActionButton(cardStyle, L("選擇標題列材質"), 170, function(selfBtn)
        if not DamageMeterTools_OpenTexturePicker then
            return
        end

        local currentSelection = GetDB().headerSkin.lsmName or "Blizzard"
        if tostring(currentSelection):upper() == "NONE" then
            currentSelection = "__DMT_BUILTIN_NONE__"
        end

        DamageMeterTools_OpenTexturePicker(selfBtn, currentSelection, function(name)
            if name == "__DMT_BUILTIN_NONE__" then
                GetDB().headerSkin.lsmName = "NONE"
            else
                GetDB().headerSkin.lsmName = name
            end

            GetDB().headerSkin.mode = "LSM"
            GetDB().headerSkin.titleTextMode = "ALWAYS"
            Notify("HeaderSkin")

            if DamageMeterTools_HeaderSkinApplyNow then
                DamageMeterTools_HeaderSkinApplyNow()
            end

            RefreshPage(parent)
        end, {
            includeBuiltIn = true,
            title = L("選擇標題列材質") or "選擇標題列材質",
        })
    end, "BLUE")
    btnPickHeader:SetPoint("TOPLEFT", modeRow, "BOTTOMLEFT", 0, -10)

    local headerInfo = CreateInfoText(cardStyle, 490)
    headerInfo:SetPoint("LEFT", btnPickHeader, "RIGHT", 12, 0)

    Place(cardStyle, 154, 12)

    ----------------------------------------------------------------
    -- 更新
    ----------------------------------------------------------------
    local secUpdate = CreateSection(content, L("更新") or "更新", 720)
    Place(secUpdate, 30)

    local actionRow = CreateFrame("Frame", nil, content)
    actionRow:SetSize(720, 28)

    local btnApply = CreateActionButton(actionRow, L("立即更新材質"), 140, function()
        if DamageMeterTools_TextureForceRebuild then
            DamageMeterTools_TextureForceRebuild()
        end
    end, "ACCENT")
    btnApply:SetPoint("LEFT", 0, 0)

    local btnRestore = CreateActionButton(actionRow, L("還原 DMT 預設外觀"), 150, function()
        if DamageMeterTools_TextureRestoreDefault then
            DamageMeterTools_TextureRestoreDefault()
        end
    end, "DANGER")
    btnRestore:SetPoint("LEFT", btnApply, "RIGHT", 8, 0)

    Place(actionRow, 28)

    content:SetHeight(math.abs(y) + 40)

    parent.RefreshValue = function(self)
        refreshLock = true
        local displayMode = tostring(GetDB().texture.displayMode or "DEFAULT"):upper()
        btnDisplayDefault:SetSelectedVisual(displayMode == "DEFAULT")
        btnDisplayEdge:SetSelectedVisual(displayMode == "EDGE")
        cbTexture:RefreshValue()
        cbHeader:RefreshValue()
        cbHeaderLines:RefreshValue()
        sliderBgAlpha:RefreshValue()
        cbCompatMode:RefreshValue()
        sliderHeaderFontSize:RefreshValue()
        headerBgAlpha:RefreshValue()
        cbShowSuffix:RefreshValue()
        local headerEnabled = DamageMeterTools:IsModuleEnabled("HeaderSkin", true)
        local textureEnabled = DamageMeterTools:IsModuleEnabled("Texture", true) and (not GetDB().texture.hardDisabled)
        local headerStyle = tostring(GetDB().headerSkin.style or "GLASS"):upper()
        local headerMode = tostring(GetDB().headerSkin.mode or "STYLE"):upper()
        local isLSM = (headerMode == "LSM")

        if isLSM then
            rowBgColor:Hide()
        else
            rowBgColor:Show()
        end

        T:SetEnabled(btnPickHeaderBgColor, not isLSM)
        T:SetEnabled(btnResetHeaderBgColor, not isLSM)

        bgColorLabel:SetAlpha(not isLSM and 1 or 0.45)
        bgColorSwatch:SetAlpha(not isLSM and 1 or 0.45)
        btnGlass:SetSelectedVisual(headerStyle == "GLASS" and headerMode == "STYLE")
        btnGold:SetSelectedVisual(headerStyle == "GOLD" and headerMode == "STYLE")
        btnSteel:SetSelectedVisual(headerStyle == "STEEL" and headerMode == "STYLE")
        btnNeon:SetSelectedVisual(headerStyle == "NEON" and headerMode == "STYLE")

        btnHeaderStyle:SetSelectedVisual(headerMode == "STYLE")
        btnHeaderLSM:SetSelectedVisual(headerMode == "LSM")

        T:SetEnabled(btnPickTexture, textureEnabled)
        T:SetEnabled(bgModeTitle, textureEnabled)
        T:SetEnabled(btnTexTransparentBorder, textureEnabled)
        T:SetEnabled(btnTexTransparentBorderless, textureEnabled)
        T:SetEnabled(sliderBgAlpha.slider, textureEnabled)
        T:SetEnabled(cbCompatMode, textureEnabled)

        T:SetEnabled(cardText, headerEnabled)
        T:SetEnabled(cardColor, headerEnabled)
        T:SetEnabled(cardBackground, headerEnabled)
        T:SetEnabled(cardStyle, headerEnabled)
        T:SetEnabled(headerPreviewBox, headerEnabled)

        T:SetEnabled(cbHeaderLines, headerEnabled)
        T:SetEnabled(sliderHeaderFontSize.slider, headerEnabled)
        T:SetEnabled(btnPickHeaderFont, headerEnabled)
        T:SetEnabled(btnPickHeaderColor, headerEnabled)
        T:SetEnabled(btnResetHeaderColor, headerEnabled)
        T:SetEnabled(cbShowSuffix, headerEnabled)
        T:SetEnabled(btnPickSuffixColor, headerEnabled)
        T:SetEnabled(btnResetSuffixColor, headerEnabled)
        suffixColorSwatch:SetAlpha(headerEnabled and 1 or 0.45)
        T:SetEnabled(headerBgAlpha.slider, headerEnabled)
        T:SetEnabled(btnPickHeaderBgColor, headerEnabled)
        T:SetEnabled(btnResetHeaderBgColor, headerEnabled)
        T:SetEnabled(btnPickHeader, headerEnabled and headerMode == "LSM")
        T:SetEnabled(btnGlass, headerEnabled)
        T:SetEnabled(btnGold, headerEnabled)
        T:SetEnabled(btnSteel, headerEnabled)
        T:SetEnabled(btnNeon, headerEnabled)
        T:SetEnabled(btnHeaderStyle, headerEnabled)
        T:SetEnabled(btnHeaderLSM, headerEnabled)

        local bgMode = tostring(GetDB().texture.backgroundMode or "TRANSPARENT_BORDER"):upper()
        btnTexTransparentBorder:SetSelectedVisual(bgMode == "TRANSPARENT_BORDER")
        btnTexTransparentBorderless:SetSelectedVisual(bgMode == "TRANSPARENT_BORDERLESS")

        local texMode = tostring(GetDB().texture.source or "MATERIALS"):upper()
        local modeText = L("顯示外框線") or "顯示外框線"
        if bgMode == "TRANSPARENT_BORDERLESS" then
            modeText = L("移除外框線") or "移除外框線"
        end

        local bgAlphaText = tostring(math.floor((tonumber(GetDB().texture.backgroundAlpha) or 35) + 0.5)) .. "%"
        local compatText = (GetDB().texture.compatMode == true) and (L("已開啟") or "已開啟") or (L("已關閉") or "已關閉")

        if texMode == "MATERIALS" then
            textureInfo:SetText((L("目前材質") or "目前材質") .. "：" .. (L("內建材質") or "內建材質") .. " / " .. modeText .. " / " .. (L("背景透明度") or "背景透明度") .. "：" .. bgAlphaText .. " / " .. (L("相容模式") or "相容模式") .. "：" .. compatText)
        elseif texMode == "LSM" then
            textureInfo:SetText((L("目前材質") or "目前材質") .. "：SharedMedia / " .. tostring(GetDB().texture.lsmName or "Blizzard") .. " / " .. modeText .. " / " .. (L("背景透明度") or "背景透明度") .. "：" .. bgAlphaText .. " / " .. (L("相容模式") or "相容模式") .. "：" .. compatText)
        elseif texMode == "CUSTOM" then
            textureInfo:SetText((L("目前材質") or "目前材質") .. "：Custom / " .. modeText .. " / " .. (L("背景透明度") or "背景透明度") .. "：" .. bgAlphaText .. " / " .. (L("相容模式") or "相容模式") .. "：" .. compatText)
        else
            textureInfo:SetText((L("目前材質") or "目前材質") .. "：Default / " .. modeText .. " / " .. (L("背景透明度") or "背景透明度") .. "：" .. bgAlphaText .. " / " .. (L("相容模式") or "相容模式") .. "：" .. compatText)
        end
        textureInfo:SetAlpha(textureEnabled and 1 or 0.45)

        if headerMode == "LSM" then
            local currentHeaderName = tostring(GetDB().headerSkin.lsmName or "Blizzard")
            if currentHeaderName:upper() == "NONE" then
                headerInfo:SetText((L("目前標題列") or "目前標題列") .. "：" .. (L("透明（無材質）") or "透明（無材質）"))
            else
                headerInfo:SetText((L("目前標題列") or "目前標題列") .. "：SharedMedia / " .. currentHeaderName)
            end
        else
            headerInfo:SetText((L("目前標題列") or "目前標題列") .. "：" .. tostring(GetDB().headerSkin.style or "GLASS"))
        end
        headerInfo:SetAlpha(headerEnabled and 1 or 0.45)

        local headerFontName = tostring(GetDB().headerSkin.titleFontName or "GAME_DEFAULT")
        local headerFontDisplay = headerFontName
        if headerFontName == "GAME_DEFAULT" then
            headerFontDisplay = "Game Default"
        end
        headerFontInfo:SetText((L("目前標題字型") or "目前標題字型") .. "：" .. headerFontDisplay)
        headerFontInfo:SetAlpha(headerEnabled and 1 or 0.45)

        local color = GetDB().headerSkin.titleTextColor or {}
        local bgColor = GetDB().headerSkin.backgroundColor or {}

        titleColorSwatch:SetSwatchColor(
            tonumber(color.r) or 1.00,
            tonumber(color.g) or 0.82,
            tonumber(color.b) or 0.20,
            tonumber(color.a) or 1.00
        )

        local sfx = GetDB().headerSkin.suffixTextColor or {}
        suffixColorSwatch:SetSwatchColor(
        tonumber(sfx.r) or 1,
        tonumber(sfx.g) or 1,
        tonumber(sfx.b) or 1,
        tonumber(sfx.a) or 1
        )

        bgColorSwatch:SetSwatchColor(
            tonumber(bgColor.r) or 0.02,
            tonumber(bgColor.g) or 0.04,
            tonumber(bgColor.b) or 0.06,
            1.00
        )

        titleColorSwatch:SetAlpha(headerEnabled and 1 or 0.45)
        bgColorSwatch:SetAlpha(headerEnabled and 1 or 0.45)

        headerModeInfo:SetAlpha(headerEnabled and 1 or 0.45)

        do
            local db = GetDB()
            local fontName = tostring(db.headerSkin.titleFontName or "GAME_DEFAULT")
            local fontPath = STANDARD_TEXT_FONT

            if fontName ~= "GAME_DEFAULT" and LibStub then
                local LSM = LibStub("LibSharedMedia-3.0", true)
                if LSM then
                    local fetched = LSM:Fetch("font", fontName, true)
                    if fetched and fetched ~= "" then
                        fontPath = fetched
                    end
                end
            end

            local fontSize = tonumber(db.headerSkin.titleFontSize) or 14
            local ok = pcall(headerPreviewBox.previewText.SetFont, headerPreviewBox.previewText, fontPath, fontSize, "OUTLINE")
            if not ok then
                pcall(headerPreviewBox.previewText.SetFont, headerPreviewBox.previewText, STANDARD_TEXT_FONT, fontSize, "OUTLINE")
            end

            local tr = tonumber(color.r) or 1.00
            local tg = tonumber(color.g) or 0.82
            local tb = tonumber(color.b) or 0.20
            local ta = tonumber(color.a) or 1.00

            local br = tonumber(bgColor.r) or 0.02
            local bgg = tonumber(bgColor.g) or 0.04
            local bb = tonumber(bgColor.b) or 0.06
            local ba = (tonumber(db.headerSkin.backgroundAlpha) or 16) / 100

            headerPreviewBox:SetBackdropColor(br, bgg, bb, ba)
            headerPreviewBox:SetBackdropBorderColor(T:GetColor("border"))

            headerPreviewBox.previewText:SetText(BuildPreviewTitleText())
            headerPreviewBox.previewText:SetTextColor(tr, tg, tb, ta)
            headerPreviewBox.previewText:SetAlpha(headerEnabled and 1 or 0.45)
            headerPreviewBox:SetAlpha(headerEnabled and 1 or 0.45)
        end

        refreshLock = false
    end
end


local function BuildInteractionPage(parent)
    local scroll, content = CreateContentScroll(parent)
    parent.scroll = scroll
    parent.content = content

    local y = -10
    local function Place(widget, h, gap)
        widget:SetPoint("TOPLEFT", 10, y)
        y = y - (h or widget:GetHeight() or 24) - (gap or 10)
    end

    local function CreateOptionCard(parentFrame, titleText, width, height)
        local card = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        card:SetSize(width or 720, height or 120)
        T:ApplyBackdrop(card, "panel2", "border")

        card.title = T:CreateText(card, titleText or "", "GameFontHighlight", "accent")
        card.title:SetPoint("TOPLEFT", 12, -10)

        card.sep = card:CreateTexture(nil, "ARTWORK")
        card.sep:SetPoint("TOPLEFT", 10, -30)
        card.sep:SetPoint("TOPRIGHT", -10, -30)
        card.sep:SetHeight(1)
        local r, g, b = T:GetColor("accentBlue")
        card.sep:SetColorTexture(r, g, b, 0.20)

        return card
    end

    ----------------------------------------------------------------
    -- 右鍵選單
    ----------------------------------------------------------------
    local secContext = CreateSection(content, L("右鍵選單") or "右鍵選單", 720)
    Place(secContext, 30)

    local cbShift = CreateCheck(content, L("右鍵選單需按住 Shift"), function()
        return GetDB().contextMenu.requireShift
    end, function(v)
        GetDB().contextMenu.requireShift = v
        Notify("ContextMenu")
    end)
    Place(cbShift, 24, 18)

    ----------------------------------------------------------------
    -- 顯示模式
    ----------------------------------------------------------------
    local secVisibility = CreateSection(content, L("顯示模式") or "顯示模式", 720)
    Place(secVisibility, 30)

    local modeInfo = CreateInfoText(content, 700)
    modeInfo:SetText(
        L("選擇 DamageMeter 平常的顯示方式：永遠顯示、只淡出標題列，或脫戰時隱藏整個視窗。")
        or "選擇 DamageMeter 平常的顯示方式：永遠顯示、只淡出標題列，或脫戰時隱藏整個視窗。"
    )
    Place(modeInfo, 32, 12)

    local modeRow = CreateFrame("Frame", nil, content)
    modeRow:SetSize(720, 28)

    local btnAlways = CreateChoiceButton(modeRow, L("永遠顯示") or "永遠顯示", 120, function()
        SetVisibilityMode("ALWAYS")
        RefreshPage(parent)
    end)
    btnAlways:SetPoint("LEFT", 0, 0)

    local btnHeaderFade = CreateChoiceButton(modeRow, L("標題列漸隱") or "標題列漸隱", 120, function()
        SetVisibilityMode("HEADER_FADE")
        RefreshPage(parent)
    end)
    btnHeaderFade:SetPoint("LEFT", btnAlways, "RIGHT", 8, 0)

    local btnCombatHide = CreateChoiceButton(modeRow, L("脫戰整窗隱藏") or "脫戰整窗隱藏", 140, function()
        SetVisibilityMode("COMBAT_HIDE")
        RefreshPage(parent)
    end)
    btnCombatHide:SetPoint("LEFT", btnHeaderFade, "RIGHT", 8, 0)

    Place(modeRow, 28, 10)

    local currentModeInfo = CreateInfoText(content, 700)
    Place(currentModeInfo, 18, 14)

    ----------------------------------------------------------------
    -- 模式卡：標題列漸隱
    ----------------------------------------------------------------
    local cardHover = CreateOptionCard(content, L("標題列漸隱設定") or "標題列漸隱設定", 720, 116)

    local sliderHover = CreateSlider(cardHover, L("隱藏延遲（秒）"), 0, 8, 0.5, "%.1f", function()
        return GetDB().hover.hideDelay or 2
    end, function(v)
        GetDB().hover.hideDelay = v
        Notify("Hover")
    end)
    sliderHover:SetPoint("TOPLEFT", 12, -40)

    local hoverInfo = CreateInfoText(cardHover, 680)
    hoverInfo:SetPoint("TOPLEFT", sliderHover, "BOTTOMLEFT", 0, -8)
    hoverInfo:SetText(
        L("只影響標題背景、按鈕與文字，不會隱藏整個 DamageMeter 視窗。")
        or "只影響標題背景、按鈕與文字，不會隱藏整個 DamageMeter 視窗。"
    )

    Place(cardHover, 116, 12)

    ----------------------------------------------------------------
    -- 模式卡：脫戰整窗隱藏
    ----------------------------------------------------------------
    local cardCombat = CreateOptionCard(content, L("脫戰整窗隱藏設定") or "脫戰整窗隱藏設定", 720, 282)

    local zoneTitle = T:CreateText(cardCombat, L("生效區域") or "生效區域", "GameFontHighlight", "accent")
    zoneTitle:SetWidth(680)
    zoneTitle:SetJustifyH("LEFT")
    zoneTitle:SetPoint("TOPLEFT", 12, -40)

    local zoneRow1 = CreateFrame("Frame", nil, cardCombat)
    zoneRow1:SetSize(680, 28)
    zoneRow1:SetPoint("TOPLEFT", zoneTitle, "BOTTOMLEFT", 0, -6)

    local cbWorld = CreateCheck(zoneRow1, L("野外"), function()
        return GetDB().combatHide.zoneFilter.world
    end, function(v)
        GetDB().combatHide.zoneFilter.world = v
        Notify("CombatHide")
    end)
    cbWorld:SetSize(120, 24)
    cbWorld:SetPoint("LEFT", 0, 0)

    local cbParty = CreateCheck(zoneRow1, L("副本 / 情境"), function()
        return GetDB().combatHide.zoneFilter.party
    end, function(v)
        GetDB().combatHide.zoneFilter.party = v
        Notify("CombatHide")
    end)
    cbParty:SetSize(150, 24)
    cbParty:SetPoint("LEFT", 150, 0)

    local cbRaid = CreateCheck(zoneRow1, L("團隊"), function()
        return GetDB().combatHide.zoneFilter.raid
    end, function(v)
        GetDB().combatHide.zoneFilter.raid = v
        Notify("CombatHide")
    end)
    cbRaid:SetSize(120, 24)
    cbRaid:SetPoint("LEFT", 330, 0)

    local zoneRow2 = CreateFrame("Frame", nil, cardCombat)
    zoneRow2:SetSize(680, 28)
    zoneRow2:SetPoint("TOPLEFT", zoneRow1, "BOTTOMLEFT", 0, -2)

    local cbPvp = CreateCheck(zoneRow2, L("戰場"), function()
        return GetDB().combatHide.zoneFilter.pvp
    end, function(v)
        GetDB().combatHide.zoneFilter.pvp = v
        Notify("CombatHide")
    end)
    cbPvp:SetSize(120, 24)
    cbPvp:SetPoint("LEFT", 0, 0)

    local cbArena = CreateCheck(zoneRow2, L("競技場"), function()
        return GetDB().combatHide.zoneFilter.arena
    end, function(v)
        GetDB().combatHide.zoneFilter.arena = v
        Notify("CombatHide")
    end)
    cbArena:SetSize(120, 24)
    cbArena:SetPoint("LEFT", 150, 0)

local cbFadeEnable = CreateCheck(cardCombat, L("啟用淡入淡出動畫") or "啟用淡入淡出動畫", function()
    return GetDB().combatHide.enableFade ~= false
end, function(v)
    GetDB().combatHide.enableFade = v and true or false
    Notify("CombatHide")
end)
cbFadeEnable:SetPoint("TOPLEFT", zoneRow2, "BOTTOMLEFT", 0, -10)

local sliderOutDelay = CreateSlider(cardCombat, L("滑鼠離開延遲（秒）"), 0, 5, 0.1, "%.1f", function()
    return GetDB().combatHide.fadeOutDelay or 2
end, function(v)
    GetDB().combatHide.fadeOutDelay = v
    Notify("CombatHide")
end)
sliderOutDelay:SetPoint("TOPLEFT", cbFadeEnable, "BOTTOMLEFT", 0, -8)
    local sliderFadeIn = CreateSlider(cardCombat, L("淡入速度（秒）"), 0.05, 1, 0.05, "%.2f", function()
        return GetDB().combatHide.fadeInTime or 0.2
    end, function(v)
        GetDB().combatHide.fadeInTime = v
        Notify("CombatHide")
    end)
    sliderFadeIn:SetPoint("TOPLEFT", sliderOutDelay, "BOTTOMLEFT", 0, -8)

    local sliderFadeOut = CreateSlider(cardCombat, L("淡出速度（秒）"), 0.05, 1, 0.05, "%.2f", function()
        return GetDB().combatHide.fadeOutTime or 0.2
    end, function(v)
        GetDB().combatHide.fadeOutTime = v
        Notify("CombatHide")
    end)
    sliderFadeOut:SetPoint("TOPLEFT", sliderFadeIn, "BOTTOMLEFT", 0, -8)

    local sliderAlpha = CreateSlider(cardCombat, L("隱藏透明度（0 = 完全隱藏）"), 0, 1, 0.05, "%.2f", function()
        return GetDB().combatHide.hiddenAlpha or 0
    end, function(v)
        GetDB().combatHide.hiddenAlpha = v
        Notify("CombatHide")
    end)
    sliderAlpha:SetPoint("TOPLEFT", sliderFadeOut, "BOTTOMLEFT", 0, -8)

    local combatInfo = CreateInfoText(cardCombat, 680)
    combatInfo:SetPoint("TOPLEFT", sliderAlpha, "BOTTOMLEFT", 0, -8)
    combatInfo:SetText(
        L("此模式會影響整個 DamageMeter 視窗；進戰時自動顯示，脫戰時依區域與滑鼠狀態隱藏。")
        or "此模式會影響整個 DamageMeter 視窗；進戰時自動顯示，脫戰時依區域與滑鼠狀態隱藏。"
    )

    Place(cardCombat, 282, 12)

    ----------------------------------------------------------------
    -- 永遠顯示說明
    ----------------------------------------------------------------
    local alwaysInfo = CreateInfoText(content, 700)
    alwaysInfo:SetText(
        L("目前模式為永遠顯示：不啟用標題列漸隱，也不啟用脫戰整窗隱藏。")
        or "目前模式為永遠顯示：不啟用標題列漸隱，也不啟用脫戰整窗隱藏。"
    )
    Place(alwaysInfo, 18, 12)

    local function RelayoutVisibilityModeArea(mode)
        local isAlways = (mode == "ALWAYS")
        local isHover = (mode == "HEADER_FADE")
        local isCombat = (mode == "COMBAT_HIDE")

        cardHover:Hide()
        cardCombat:Hide()
        alwaysInfo:Hide()

        cardHover:ClearAllPoints()
        cardCombat:ClearAllPoints()
        alwaysInfo:ClearAllPoints()

        if isHover then
            cardHover:SetPoint("TOPLEFT", currentModeInfo, "BOTTOMLEFT", 0, -10)
            cardHover:Show()

            content:SetHeight(math.abs(cardHover:GetBottom() - content:GetTop()) + 80)

        elseif isCombat then
            cardCombat:SetPoint("TOPLEFT", currentModeInfo, "BOTTOMLEFT", 0, -10)
            cardCombat:Show()

            content:SetHeight(math.abs(cardCombat:GetBottom() - content:GetTop()) + 80)

        else
            alwaysInfo:SetPoint("TOPLEFT", currentModeInfo, "BOTTOMLEFT", 0, -10)
            alwaysInfo:Show()

            content:SetHeight(math.abs(alwaysInfo:GetBottom() - content:GetTop()) + 80)
        end
    end

    parent.RefreshValue = function(self)
        refreshLock = true

        cbShift:RefreshValue()

        local mode = GetVisibilityMode()

        btnAlways:SetSelectedVisual(mode == "ALWAYS")
        btnHeaderFade:SetSelectedVisual(mode == "HEADER_FADE")
        btnCombatHide:SetSelectedVisual(mode == "COMBAT_HIDE")

        currentModeInfo:SetText(
            string.format(
                L("目前模式：%s") or "目前模式：%s",
                GetVisibilityModeDisplayText(mode)
            )
        )

        sliderHover:RefreshValue()

        cbWorld:RefreshValue()
        cbParty:RefreshValue()
        cbRaid:RefreshValue()
        cbPvp:RefreshValue()
        cbArena:RefreshValue()
        cbFadeEnable:RefreshValue()
        sliderOutDelay:RefreshValue()
        sliderFadeIn:RefreshValue()
        sliderFadeOut:RefreshValue()
        sliderAlpha:RefreshValue()

        RelayoutVisibilityModeArea(mode)

        refreshLock = false
    end
end

local function BuildResetPage(parent)
    local scroll, content = CreateContentScroll(parent)
    parent.scroll = scroll
    parent.content = content

    local y = -10
    local function Place(widget, h, gap)
        widget:SetPoint("TOPLEFT", 10, y)
        y = y - (h or widget:GetHeight() or 24) - (gap or 10)
    end

    local function CreateOptionCard(parentFrame, titleText, width, height)
        local card = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        card:SetSize(width or 720, height or 120)
        T:ApplyBackdrop(card, "panel2", "border")

        card.title = T:CreateText(card, titleText or "", "GameFontHighlight", "accent")
        card.title:SetPoint("TOPLEFT", 12, -10)

        card.sep = card:CreateTexture(nil, "ARTWORK")
        card.sep:SetPoint("TOPLEFT", 10, -30)
        card.sep:SetPoint("TOPRIGHT", -10, -30)
        card.sep:SetHeight(1)
        local r, g, b = T:GetColor("accentBlue")
        card.sep:SetColorTexture(r, g, b, 0.20)

        return card
    end

    ----------------------------------------------------------------
    -- 自動重置
    ----------------------------------------------------------------
    local secAutoReset = CreateSection(content, L("自動重置傷害統計") or "自動重置傷害統計", 720)
    Place(secAutoReset, 30)

    local cbAutoResetModule = CreateCheck(content, L("啟用自動重置模組") or "啟用自動重置模組", function()
        return DamageMeterTools:IsModuleEnabled("AutoReset", false)
    end, function(v)
        DamageMeterTools:SetModuleEnabled("AutoReset", v)
        Notify("AutoReset")
        RefreshPage(parent)
    end)
    Place(cbAutoResetModule, 24)

    local cardAutoReset = CreateOptionCard(content, L("自動重置觸發條件") or "自動重置觸發條件", 720, 210)
    cardAutoReset:SetPoint("TOPLEFT", cbAutoResetModule, "BOTTOMLEFT", 0, -10)

    -- 欄位標題
    local colTitleLeft = T:CreateText(cardAutoReset, L("觸發條件") or "觸發條件", "GameFontHighlightSmall", "textDim")
    colTitleLeft:SetPoint("TOPLEFT", 12, -24)

    local colTitleRight = T:CreateText(cardAutoReset, L("彈窗確認") or "彈窗確認", "GameFontHighlightSmall", "textDim")
    colTitleRight:SetPoint("TOPLEFT", 360, -24)

    local COL_RIGHT_X = 360
    local ROW_Y = -44

    local cbCombatStart = CreateCheck(cardAutoReset, L("戰鬥開始時重置") or "戰鬥開始時重置", function()
        return GetDB().autoreset.combatStart
    end, function(v)
        GetDB().autoreset.combatStart = v
        Notify("AutoReset")
    end)
    cbCombatStart:SetPoint("TOPLEFT", 12, ROW_Y)
    cbCombatStart:SetSize(320, 24)

    local cbConfirmCombat = CreateCheck(cardAutoReset, L("需要彈窗") or "需要彈窗", function()
        return GetDB().autoreset.confirmCombatStart == true
    end, function(v)
        GetDB().autoreset.confirmCombatStart = v and true or false
        Notify("AutoReset")
    end)
    cbConfirmCombat:SetPoint("TOPLEFT", COL_RIGHT_X, ROW_Y)
    cbConfirmCombat:SetSize(280, 24)

    ROW_Y = ROW_Y - 28

    local cbBossStart = CreateCheck(cardAutoReset, L("BOSS 開始時重置") or "BOSS 開始時重置", function()
        return GetDB().autoreset.bossStart
    end, function(v)
        GetDB().autoreset.bossStart = v
        Notify("AutoReset")
    end)
    cbBossStart:SetPoint("TOPLEFT", 12, ROW_Y)
    cbBossStart:SetSize(320, 24)

    local cbConfirmBoss = CreateCheck(cardAutoReset, L("需要彈窗") or "需要彈窗", function()
        return GetDB().autoreset.confirmBossStart == true
    end, function(v)
        GetDB().autoreset.confirmBossStart = v and true or false
        Notify("AutoReset")
    end)
    cbConfirmBoss:SetPoint("TOPLEFT", COL_RIGHT_X, ROW_Y)
    cbConfirmBoss:SetSize(280, 24)

    ROW_Y = ROW_Y - 28

    local cbMythicStart = CreateCheck(cardAutoReset, L("M+ 開始時重置") or "M+ 開始時重置", function()
        return GetDB().autoreset.mythicStart
    end, function(v)
        GetDB().autoreset.mythicStart = v
        Notify("AutoReset")
    end)
    cbMythicStart:SetPoint("TOPLEFT", 12, ROW_Y)
    cbMythicStart:SetSize(320, 24)

    local cbConfirmMythic = CreateCheck(cardAutoReset, L("需要彈窗") or "需要彈窗", function()
        return GetDB().autoreset.confirmMythicStart == true
    end, function(v)
        GetDB().autoreset.confirmMythicStart = v and true or false
        Notify("AutoReset")
    end)
    cbConfirmMythic:SetPoint("TOPLEFT", COL_RIGHT_X, ROW_Y)
    cbConfirmMythic:SetSize(280, 24)

    ROW_Y = ROW_Y - 28

    local cbInstance = CreateCheck(cardAutoReset, L("新副本進入時重置") or "新副本進入時重置", function()
        return GetDB().autoreset.instanceEnter
    end, function(v)
        GetDB().autoreset.instanceEnter = v
        Notify("AutoReset")
    end)
    cbInstance:SetPoint("TOPLEFT", 12, ROW_Y)
    cbInstance:SetSize(320, 24)

    local cbConfirmInstance = CreateCheck(cardAutoReset, L("需要彈窗") or "需要彈窗", function()
        return GetDB().autoreset.confirmInstanceEnter == true
    end, function(v)
        GetDB().autoreset.confirmInstanceEnter = v and true or false
        Notify("AutoReset")
    end)
    cbConfirmInstance:SetPoint("TOPLEFT", COL_RIGHT_X, ROW_Y)
    cbConfirmInstance:SetSize(280, 24)

    ROW_Y = ROW_Y - 28

    local cbAutoResetNotify = CreateCheck(cardAutoReset, L("聊天提示重置訊息") or "聊天提示重置訊息", function()
        return GetDB().autoreset.notify ~= false
    end, function(v)
        GetDB().autoreset.notify = v and true or false
        Notify("AutoReset")
    end)
    cbAutoResetNotify:SetPoint("TOPLEFT", 12, ROW_Y)
    cbAutoResetNotify:SetSize(320, 24)

    Place(cardAutoReset, 210, 12)

    ----------------------------------------------------------------
    -- 手動重置
    ----------------------------------------------------------------
    local secManual = CreateSection(content, L("手動重置") or "手動重置", 720)
    Place(secManual, 30)

    local btnResetNow = CreateActionButton(content, L("立即清空統計") or "立即清空統計", 160, function()
        if GetDB().autoreset.confirmReset ~= false then
            if StaticPopup_Show then
                StaticPopup_Show("DMT_CONFIRM_RESET_METER")
            else
                DMT_DoManualReset()
            end
        else
            DMT_DoManualReset()
        end
    end, "DANGER")
    Place(btnResetNow, 24)

    local resetInfo = CreateInfoText(content, 700)
    resetInfo:SetText(
        L("說明：此按鈕會立即清空暴雪內建傷害統計。")
        or "說明：此按鈕會立即清空暴雪內建傷害統計。"
    )
    Place(resetInfo, 28, 8)

    local cbConfirmReset = CreateCheck(content, L("清空前顯示確認視窗") or "清空前顯示確認視窗", function()
        return GetDB().autoreset.confirmReset ~= false
    end, function(v)
        GetDB().autoreset.confirmReset = v and true or false
    end)
    Place(cbConfirmReset, 24, 8)
    local confirmResetNote = CreateInfoText(content, 700)
    confirmResetNote:SetText(L("此選項只影響「手動重置按鈕」。") or "此選項只影響「手動重置按鈕」。")
    Place(confirmResetNote, 18, 6)
    content:SetHeight(math.abs(y) + 40)

    parent.RefreshValue = function(self)
        refreshLock = true

        cbAutoResetModule:RefreshValue()
        cbCombatStart:RefreshValue()
        cbBossStart:RefreshValue()
        cbMythicStart:RefreshValue()
        cbInstance:RefreshValue()
        cbAutoResetNotify:RefreshValue()
        cbConfirmReset:RefreshValue()

        cbConfirmCombat:RefreshValue()
        cbConfirmBoss:RefreshValue()
        cbConfirmMythic:RefreshValue()
        cbConfirmInstance:RefreshValue()

        local enabled = DamageMeterTools:IsModuleEnabled("AutoReset", false)
        T:SetEnabled(cardAutoReset, enabled)
        T:SetEnabled(cbCombatStart, enabled)
        T:SetEnabled(cbBossStart, enabled)
        T:SetEnabled(cbMythicStart, enabled)
        T:SetEnabled(cbInstance, enabled)
        T:SetEnabled(cbAutoResetNotify, enabled)

        T:SetEnabled(cbConfirmCombat, enabled)
        T:SetEnabled(cbConfirmBoss, enabled)
        T:SetEnabled(cbConfirmMythic, enabled)
        T:SetEnabled(cbConfirmInstance, enabled)

        refreshLock = false
    end
end

local function BuildLayoutPage(parent)
    local scroll, content = CreateContentScroll(parent)
    parent.scroll = scroll
    parent.content = content

    local y = -10
    local function Place(widget, h, gap)
        widget:SetPoint("TOPLEFT", 10, y)
        y = y - (h or widget:GetHeight() or 24) - (gap or 10)
    end

    local function NormalizeGroupMode(mode)
        mode = tostring(mode or "123"):upper()
        if mode == "ALL" then mode = "123" end
        if mode ~= "123" and mode ~= "12" and mode ~= "23" then
            mode = "123"
        end
        return mode
    end

    local function NormalizeSizeMode(mode)
        mode = tostring(mode or "123"):upper()
        if mode == "ALL" then mode = "123" end
        if mode ~= "123" and mode ~= "12" and mode ~= "23" then
            mode = "123"
        end
        return mode
    end

    local function ApplyLayout()
        if DamageMeterTools_FrameBindApplyNow then
            DamageMeterTools_FrameBindApplyNow()
        end
        Notify("FrameBind")
        RefreshPage(parent)
    end

    local function CreateBadge(parentFrame, width, colorKey)
        local badge = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        badge:SetSize(width or 92, 22)
        T:ApplyBackdrop(badge, "panel2", "border")

        badge.Text = T:CreateText(badge, "", "GameFontHighlightSmall", "text")
        badge.Text:SetPoint("CENTER", 0, 0)

        function badge:SetBadgeText(text)
            self.Text:SetText(text or "")
        end

        if colorKey == "GREEN" then
            badge:SetBackdropColor(0.08, 0.20, 0.14, 0.90)
            badge:SetBackdropBorderColor(0.24, 0.95, 0.62, 0.95)
        elseif colorKey == "BLUE" then
            badge:SetBackdropColor(0.08, 0.14, 0.22, 0.90)
            badge:SetBackdropBorderColor(0.30, 0.72, 1.00, 0.95)
        elseif colorKey == "GOLD" then
            badge:SetBackdropColor(0.22, 0.17, 0.07, 0.90)
            badge:SetBackdropBorderColor(1.00, 0.82, 0.20, 0.95)
        else
            badge:SetBackdropColor(0.10, 0.12, 0.16, 0.90)
            badge:SetBackdropBorderColor(T:GetColor("borderStrong"))
        end

        return badge
    end

    ----------------------------------------------------------------
    -- 基本設定
    ----------------------------------------------------------------
    local secBasic = CreateSection(content, L("視窗佈局與跟隨") or "視窗佈局與跟隨", 720)
    Place(secBasic, 30)

    local cbModule = CreateCheck(content, L("啟用視窗佈局模組") or "啟用視窗佈局模組", function()
        return DamageMeterTools:IsModuleEnabled("FrameBind", true)
    end, function(v)
        DamageMeterTools:SetModuleEnabled("FrameBind", v)
        ApplyLayout()
    end)
    Place(cbModule, 24)

    local cbEnableSnap = CreateCheck(content, L("啟用位置吸附（Snap）") or "啟用位置吸附（Snap）", function()
        return GetDB().frameBind.enableSnap == true
    end, function(v)
        GetDB().frameBind.enableSnap = v and true or false
        ApplyLayout()
    end)
    Place(cbEnableSnap, 24)

    local cbMatchSize = CreateCheck(content, L("同步尺寸") or "同步尺寸", function()
        return GetDB().frameBind.matchSize == true
    end, function(v)
        GetDB().frameBind.matchSize = v and true or false
        ApplyLayout()
    end)
    Place(cbMatchSize, 24)

    local sizeModeTitle = T:CreateText(content, L("尺寸同步模式") or "尺寸同步模式", "GameFontHighlight", "accent")
    sizeModeTitle:SetWidth(700)
    sizeModeTitle:SetJustifyH("LEFT")
    Place(sizeModeTitle, 20)

    local sizeModeRow = CreateFrame("Frame", nil, content)
    sizeModeRow:SetSize(720, 28)

    local cbSize1, cbSize2, cbSize3, sizeSummary

    local function UpdateSizeSummary()
        local mode = NormalizeSizeMode(GetDB().frameBind.sizeSyncMode or "123")
        if mode == "123" then
            sizeSummary:SetText(L("目前同步：1+2+3 全部同步") or "目前同步：1+2+3 全部同步")
        elseif mode == "12" then
            sizeSummary:SetText(L("目前同步：1+2 同步，3 自由") or "目前同步：1+2 同步，3 自由")
        else
            sizeSummary:SetText(L("目前同步：2+3 同步，1 自由") or "目前同步：2+3 同步，1 自由")
        end
    end

    local function ApplySizeModeFromChecks()
        local c1 = cbSize1:GetChecked()
        local c2 = cbSize2:GetChecked()
        local c3 = cbSize3:GetChecked()

        -- 2 必須存在
        if not c2 then
            c2 = true
            cbSize2:SetChecked(true)
        end

        -- 全不勾 → 預設 1+2
        if not c1 and not c3 then
            c1 = true
            cbSize1:SetChecked(true)
        end

        if c1 and c3 then
            GetDB().frameBind.sizeSyncMode = "123"
        elseif c1 then
            GetDB().frameBind.sizeSyncMode = "12"
        else
            GetDB().frameBind.sizeSyncMode = "23"
        end

        ApplyLayout()
        UpdateSizeSummary()
    end

    cbSize1 = CreateCheck(sizeModeRow, "1", function()
        local mode = NormalizeSizeMode(GetDB().frameBind.sizeSyncMode or "123")
        return (mode == "123" or mode == "12")
    end, function()
        ApplySizeModeFromChecks()
    end)
    cbSize1:SetSize(60, 24)
    cbSize1:SetPoint("LEFT", 0, 0)

    cbSize2 = CreateCheck(sizeModeRow, "2", function()
        return true
    end, function()
        cbSize2:SetChecked(true)
        ApplySizeModeFromChecks()
    end)
    cbSize2:SetSize(60, 24)
    cbSize2:SetPoint("LEFT", cbSize1, "RIGHT", 10, 0)
    cbSize2:SetChecked(true)

    cbSize3 = CreateCheck(sizeModeRow, "3", function()
        local mode = NormalizeSizeMode(GetDB().frameBind.sizeSyncMode or "123")
        return (mode == "123" or mode == "23")
    end, function()
        ApplySizeModeFromChecks()
    end)
    cbSize3:SetSize(60, 24)
    cbSize3:SetPoint("LEFT", cbSize2, "RIGHT", 10, 0)

    Place(sizeModeRow, 28)

    sizeSummary = CreateInfoText(content, 700)
    sizeSummary:SetText("")
    Place(sizeSummary, 18, 6)

    local sliderSpacing = CreateSlider(content, L("視窗間距") or "視窗間距", -40, 40, 1, "%d", function()
        return tonumber(GetDB().frameBind.spacing) or 0
    end, function(v)
        GetDB().frameBind.spacing = v
        ApplyLayout()
    end)
    Place(sliderSpacing, 52)

    local basicInfo = CreateInfoText(content, 700)
    basicInfo:SetText(L("拖曳下方 2 / 3 預覽視窗，可快速設定群組與方向。") or "拖曳下方 2 / 3 預覽視窗，可快速設定群組與方向。")
    Place(basicInfo, 18, 14)

    ----------------------------------------------------------------
    -- 視覺化編輯器
    ----------------------------------------------------------------
    local secVisual = CreateSection(content, L("視覺化佈局編輯器") or "視覺化佈局編輯器", 720)
    Place(secVisual, 30)

    local editorCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
    editorCard:SetSize(720, 388)
    T:ApplyBackdrop(editorCard, "panel2", "border")

    local editorTitle = T:CreateText(editorCard, L("拖曳視窗 2 / 3") or "拖曳視窗 2 / 3", "GameFontHighlight", "accent")
    editorTitle:SetPoint("TOPLEFT", 12, -12)

    local btnEditorReset = CreateActionButton(editorCard, L("重設") or "重設", 84, function()
        local fb = GetDB().frameBind
        fb.snapGroupMode = "123"
        fb.win2Position = "DOWN"
        fb.win3Position = "RIGHT"
        ApplyLayout()
    end, "DARK")
    btnEditorReset:SetPoint("TOPRIGHT", -12, -8)

    local btnEditorRefresh = CreateActionButton(editorCard, L("同步") or "同步", 84, function()
        RefreshPage(parent)
    end, "BLUE")
    btnEditorRefresh:SetPoint("RIGHT", btnEditorReset, "LEFT", -8, 0)

    -- ✅ 勾選 1 / 2 / 3 群組
    local editorCheckRow = CreateFrame("Frame", nil, editorCard)
    editorCheckRow:SetSize(320, 24)
    editorCheckRow:SetPoint("TOPLEFT", 12, -36)

    local cbEditor1, cbEditor2, cbEditor3

    local function ApplyEditorGroupFromChecks()
        local c1 = cbEditor1:GetChecked()
        local c2 = cbEditor2:GetChecked()
        local c3 = cbEditor3:GetChecked()

        -- 不允許 1+3 而沒有 2
        if (c1 and c3 and not c2) then
            c2 = true
            cbEditor2:SetChecked(true)
        end

        -- 全不勾 → 預設 1+2
        if not c1 and not c2 and not c3 then
            c1 = true
            c2 = true
            cbEditor1:SetChecked(true)
            cbEditor2:SetChecked(true)
        end

        local mode
        if c1 and c2 and c3 then
            mode = "123"
        elseif c1 and c2 then
            mode = "12"
        elseif c2 and c3 then
            mode = "23"
        else
            mode = "12"
        end

        GetDB().frameBind.snapGroupMode = mode
        ApplyLayout()
    end

    cbEditor1 = CreateCheck(editorCheckRow, "1", function()
        local mode = NormalizeGroupMode(GetDB().frameBind.snapGroupMode or "123")
        return (mode == "123" or mode == "12")
    end, function()
        ApplyEditorGroupFromChecks()
    end)
    cbEditor1:SetSize(60, 24)
    cbEditor1:SetPoint("LEFT", 0, 0)

    cbEditor2 = CreateCheck(editorCheckRow, "2", function()
        local mode = NormalizeGroupMode(GetDB().frameBind.snapGroupMode or "123")
        return (mode == "123" or mode == "12" or mode == "23")
    end, function()
        ApplyEditorGroupFromChecks()
    end)
    cbEditor2:SetSize(60, 24)
    cbEditor2:SetPoint("LEFT", cbEditor1, "RIGHT", 10, 0)

    cbEditor3 = CreateCheck(editorCheckRow, "3", function()
        local mode = NormalizeGroupMode(GetDB().frameBind.snapGroupMode or "123")
        return (mode == "123" or mode == "23")
    end, function()
        ApplyEditorGroupFromChecks()
    end)
    cbEditor3:SetSize(60, 24)
    cbEditor3:SetPoint("LEFT", cbEditor2, "RIGHT", 10, 0)

    local editorDesc = T:CreateText(editorCard, L("放開後自動吸附到最近方向") or "放開後自動吸附到最近方向", "GameFontHighlightSmall", "textDim")
    editorDesc:SetPoint("TOPLEFT", 12, -86)

    local editorRule = T:CreateText(
        editorCard,
        L("") or "",
        "GameFontHighlightSmall",
        "textDim"
    )
    editorRule:SetPoint("TOPLEFT", 12, -102)

    local invalidHint = T:CreateText(
        editorCard,
        L("") or "",
        "GameFontHighlightSmall",
        "accent"
    )
    invalidHint:SetTextColor(1.00, 0.28, 0.28, 1.00)
    invalidHint:SetPoint("TOPRIGHT", -12, -102)
    invalidHint:Hide()

    local canvas = CreateFrame("Frame", nil, editorCard, "BackdropTemplate")
    canvas:SetSize(690, 236)
    canvas:SetPoint("TOPLEFT", 12, -120)
    T:ApplyBackdrop(canvas, "panel", "border")

    local badgeRow = CreateFrame("Frame", nil, editorCard)
    badgeRow:SetSize(690, 24)
    badgeRow:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -10)

    local badgeGroup = CreateBadge(badgeRow, 90, "GREEN")
    badgeGroup:SetPoint("LEFT", 0, 0)

    local badgeW2 = CreateBadge(badgeRow, 110, "BLUE")
    badgeW2:SetPoint("LEFT", badgeGroup, "RIGHT", 8, 0)

    local badgeW3 = CreateBadge(badgeRow, 110, "BLUE")
    badgeW3:SetPoint("LEFT", badgeW2, "RIGHT", 8, 0)

    local badgeSize = CreateBadge(badgeRow, 100, "GOLD")
    badgeSize:SetPoint("LEFT", badgeW3, "RIGHT", 8, 0)

    local line12 = canvas:CreateTexture(nil, "ARTWORK")
    line12:SetColorTexture(0.30, 0.72, 1.00, 0.95)
    line12:SetHeight(3)
    line12:Hide()

    local line23 = canvas:CreateTexture(nil, "ARTWORK")
    line23:SetColorTexture(0.24, 0.95, 0.62, 0.95)
    line23:SetHeight(4)
    line23:Hide()

    local group23Glow = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    T:ApplyBackdrop(group23Glow, "panel2", "borderStrong")
    group23Glow:SetBackdropColor(0.10, 0.85, 0.55, 0.08)
    group23Glow:SetBackdropBorderColor(0.24, 0.95, 0.62, 0.75)
    group23Glow:Hide()

    local group23Label = T:CreateText(group23Glow, L("23 群組") or "23 GROUP", "GameFontHighlightSmall", "accent")
    group23Label:SetTextColor(0.24, 0.95, 0.62, 1.00)
    group23Label:SetPoint("TOP", 0, -6)

    local function CreatePreviewWindow(parentFrame, titleText, r, g, b, draggable)
        local box = CreateFrame("Button", nil, parentFrame, "BackdropTemplate")
        box:SetSize(106, 54)
        box:EnableMouse(true)
        box._baseColor = { r = r, g = g, b = b }

        T:ApplyBackdrop(box, "darkButton", "borderStrong")
        box:SetBackdropColor(r, g, b, 0.18)

        box.label = T:CreateText(box, titleText or "", "GameFontHighlight", "text")
        box.label:SetPoint("CENTER", 0, 6)

        box.tag = T:CreateText(box, "", "GameFontHighlightSmall", "accent")
        box.tag:SetPoint("CENTER", 0, -10)

        box.badge = T:CreateText(box, draggable and (L("拖曳") or "拖曳") or (L("固定") or "固定"), "GameFontHighlightSmall", "textDim")
        box.badge:SetPoint("BOTTOM", 0, 6)

        if draggable then
            box:SetScript("OnEnter", function(self)
                if not self._dragging then
                    self:SetBackdropBorderColor(T:GetColor("accentBlue"))
                end
            end)
            box:SetScript("OnLeave", function(self)
                if not self._dragging then
                    self:SetBackdropBorderColor(T:GetColor("borderStrong"))
                end
            end)
        end

        return box
    end

    local previewWin1 = CreatePreviewWindow(canvas, "1", 0.25, 0.52, 0.95, false)
    previewWin1.tag:SetText(L("主視窗") or "主視窗")

    local previewWin2 = CreatePreviewWindow(canvas, "2", 0.18, 0.75, 0.45, true)
    local previewWin3 = CreatePreviewWindow(canvas, "3", 0.92, 0.63, 0.20, true)

    local PREVIEW_GAP = 12
    local ATTACH_THRESHOLD = 70
    local CANVAS_W = 690
    local CANVAS_H = 250

    local function SetPreviewHighlight(frame, enabled, r, g, b)
        local base = frame._baseColor or { r = 0.12, g = 0.12, b = 0.12 }
        if enabled then
            frame:SetBackdropBorderColor(r or 0.30, g or 0.72, b or 1.00, 1)
            frame:SetBackdropColor(base.r, base.g, base.b, 0.30)
        else
            frame:SetBackdropBorderColor(T:GetColor("borderStrong"))
            frame:SetBackdropColor(base.r, base.g, base.b, 0.18)
        end
    end

    local function SetRelativeCenter(frame, x, y)
        frame._DMTPreviewX = x
        frame._DMTPreviewY = y
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", canvas, "BOTTOMLEFT", x, y)
    end

    local function GetRelativeCenter(frame)
        if frame and frame._DMTPreviewX and frame._DMTPreviewY then
            return frame._DMTPreviewX, frame._DMTPreviewY
        end

        local cx, cy = frame:GetCenter()
        local left = canvas:GetLeft()
        local bottom = canvas:GetBottom()
        if not cx or not cy or not left or not bottom then
            return nil, nil
        end
        return cx - left, cy - bottom
    end

    local function ClampXYToCanvas(frame, x, y)
        local halfW = frame:GetWidth() / 2
        local halfH = frame:GetHeight() / 2

        if x < halfW then x = halfW end
        if x > (CANVAS_W - halfW) then x = (CANVAS_W - halfW) end
        if y < halfH then y = halfH end
        if y > (CANVAS_H - halfH) then y = (CANVAS_H - halfH) end

        return x, y
    end

    local function ClampFrameToCanvas(frame)
        local x, y = GetRelativeCenter(frame)
        if not x or not y then return end
        x, y = ClampXYToCanvas(frame, x, y)
        SetRelativeCenter(frame, x, y)
    end

    local function GetAnchorCenter(targetFrame, movingFrame, direction)
        local tx, ty = GetRelativeCenter(targetFrame)
        if not tx or not ty then
            return 100, 100
        end

        local offsetX = (targetFrame:GetWidth() + movingFrame:GetWidth()) / 2 + PREVIEW_GAP
        local offsetY = (targetFrame:GetHeight() + movingFrame:GetHeight()) / 2 + PREVIEW_GAP
        direction = tostring(direction or "DOWN"):upper()

        if direction == "UP" then
            return tx, ty + offsetY
        elseif direction == "DOWN" then
            return tx, ty - offsetY
        elseif direction == "LEFT" then
            return tx - offsetX, ty
        elseif direction == "RIGHT" then
            return tx + offsetX, ty
        end

        return tx, ty - offsetY
    end

    local function GetNearestAnchor(movingFrame, targetFrame)
        local mx, my = GetRelativeCenter(movingFrame)
        local tx, ty = GetRelativeCenter(targetFrame)
        if not mx or not my or not tx or not ty then
            return "DOWN", 9999, 0, 0
        end

        local bestDir = "DOWN"
        local bestDist = 9999
        local bestX, bestY = 0, 0

        for _, dir in ipairs({ "UP", "DOWN", "LEFT", "RIGHT" }) do
            local ax, ay = GetAnchorCenter(targetFrame, movingFrame, dir)
            local dx = mx - ax
            local dy = my - ay
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < bestDist then
                bestDist = dist
                bestDir = dir
                bestX = ax
                bestY = ay
            end
        end

        return bestDir, bestDist, bestX, bestY
    end

        local function IsPreview3NearWindow1()
        local dir, dist = GetNearestAnchor(previewWin3, previewWin1)
        if dir and dist and dist <= ATTACH_THRESHOLD then
            return true, dir, dist
        end
        return false, nil, nil
    end

        local function UpdateIllegalPreviewState()
        local nearWin1 = false
        local attach3To2 = false

        do
            local isNear = IsPreview3NearWindow1()
            nearWin1 = isNear == true
        end

        do
            local _, dist3to2 = GetNearestAnchor(previewWin3, previewWin2)
            attach3To2 = dist3to2 and dist3to2 <= ATTACH_THRESHOLD
        end

        local illegal = nearWin1 and not attach3To2

        if illegal then
            invalidHint:SetText(L("不支援 1 + 3 群組") or "不支援 1 + 3 群組")

            invalidHint:Show()
            previewWin3:SetBackdropBorderColor(1.00, 0.28, 0.28, 1.00)
            previewWin3:SetBackdropColor(0.35, 0.12, 0.12, 0.32)
        else
            invalidHint:Hide()
        end

        return illegal
    end

    local function DrawLine(lineTex, fromFrame, toFrame)
        local x1, y1 = GetRelativeCenter(fromFrame)
        local x2, y2 = GetRelativeCenter(toFrame)
        if not x1 or not x2 then
            lineTex:Hide()
            return
        end

        local dx = math.abs(x2 - x1)
        local dy = math.abs(y2 - y1)

        lineTex:ClearAllPoints()

        if dy > dx then
            -- 上下排列：畫垂直線
            local bottom = math.min(y1, y2)
            local top = math.max(y1, y2)
            lineTex:SetWidth(3)
            lineTex:SetHeight(math.max(top - bottom, 2))
            lineTex:SetPoint("BOTTOM", canvas, "BOTTOMLEFT", (x1 + x2) / 2, bottom)
        else
            -- 左右排列：畫水平線
            local left = math.min(x1, x2)
            local right = math.max(x1, x2)
            lineTex:SetHeight(3)
            lineTex:SetWidth(math.max(right - left, 2))
            lineTex:SetPoint("LEFT", canvas, "BOTTOMLEFT", left, (y1 + y2) / 2)
        end

        lineTex:Show()
    end

    local function UpdateGroupVisuals()
        local fb = GetDB().frameBind
        local groupMode = NormalizeGroupMode(fb.snapGroupMode or "123")

        line12:Hide()
        line23:Hide()
        group23Glow:Hide()
        invalidHint:Hide()

        SetPreviewHighlight(previewWin1, false)
        SetPreviewHighlight(previewWin2, false)
        SetPreviewHighlight(previewWin3, false)

        if groupMode == "123" or groupMode == "12" then
            DrawLine(line12, previewWin1, previewWin2)
            SetPreviewHighlight(previewWin1, true, 0.30, 0.72, 1.00)
            SetPreviewHighlight(previewWin2, true, 0.30, 0.72, 1.00)
        end

        if groupMode == "123" or groupMode == "23" then
            DrawLine(line23, previewWin2, previewWin3)
            SetPreviewHighlight(previewWin2, true, 0.24, 0.95, 0.62)
            SetPreviewHighlight(previewWin3, true, 0.24, 0.95, 0.62)
        end

        if groupMode == "23" then
            local x2, y2 = GetRelativeCenter(previewWin2)
            local x3, y3 = GetRelativeCenter(previewWin3)
            if x2 and x3 then
                local left = math.min(x2 - previewWin2:GetWidth() / 2, x3 - previewWin3:GetWidth() / 2) - 10
                local right = math.max(x2 + previewWin2:GetWidth() / 2, x3 + previewWin3:GetWidth() / 2) + 10
                local bottom = math.min(y2 - previewWin2:GetHeight() / 2, y3 - previewWin3:GetHeight() / 2) - 10
                local top = math.max(y2 + previewWin2:GetHeight() / 2, y3 + previewWin3:GetHeight() / 2) + 10

                left = math.max(6, left)
                right = math.min(CANVAS_W - 6, right)
                bottom = math.max(6, bottom)
                top = math.min(CANVAS_H - 6, top)

                group23Glow:ClearAllPoints()
                group23Glow:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", left, top)
                group23Glow:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT", right, bottom)
                group23Glow:Show()
                group23Glow:SetFrameLevel(previewWin2:GetFrameLevel() - 1)
            end
        end
    end

    local function RefreshPreviewFromDB()
        local fb = GetDB().frameBind
        local groupMode = NormalizeGroupMode(fb.snapGroupMode or "123")
        local sizeMode = NormalizeSizeMode(fb.sizeSyncMode or "123")
        local win2Pos = tostring(fb.win2Position or "DOWN"):upper()
        local win3Pos = tostring(fb.win3Position or "RIGHT"):upper()

        local rootX = 170
        local rootY = 125

        if groupMode == "123" then
            if win2Pos == "DOWN" and win3Pos == "DOWN" then
                rootY = 190
            elseif win2Pos == "UP" and win3Pos == "UP" then
                rootY = 60
            elseif win2Pos == "DOWN" then
                rootY = 155
            elseif win2Pos == "UP" then
                rootY = 95
            end
        elseif groupMode == "12" then
            if win2Pos == "DOWN" then
                rootY = 160
            elseif win2Pos == "UP" then
                rootY = 90
            end
        end

        SetRelativeCenter(previewWin1, rootX, rootY)
    
        if groupMode == "123" or groupMode == "12" then
            local x2, y2 = GetAnchorCenter(previewWin1, previewWin2, win2Pos)
            x2, y2 = ClampXYToCanvas(previewWin2, x2, y2)
            SetRelativeCenter(previewWin2, x2, y2)
        else
            SetRelativeCenter(previewWin2, 530, 72)
        end

        if groupMode == "123" or groupMode == "23" then
            local x3, y3 = GetAnchorCenter(previewWin2, previewWin3, win3Pos)
            x3, y3 = ClampXYToCanvas(previewWin3, x3, y3)

            -- 避免極端情況下與視窗2幾乎重疊
            local x2Now, y2Now = GetRelativeCenter(previewWin2)
            if x2Now and y2Now then
                local dx = math.abs(x3 - x2Now)
                local dy = math.abs(y3 - y2Now)
                if dx < 4 and dy < 4 then
                    x3, y3 = GetAnchorCenter(previewWin2, previewWin3, "DOWN")
                    x3, y3 = ClampXYToCanvas(previewWin3, x3, y3)
                end
            end

            SetRelativeCenter(previewWin3, x3, y3)
        else
            SetRelativeCenter(previewWin3, 530, 150)
        end

        previewWin2.tag:SetText(groupMode == "23" and (L("主體") or "主體") or "")
        previewWin3.tag:SetText((groupMode == "23" or groupMode == "123") and (L("跟隨2") or "跟隨2") or "")

        UpdateGroupVisuals()

        badgeGroup:SetBadgeText((L("群組") or "GROUP") .. " " .. groupMode)
        badgeW2:SetBadgeText("2:" .. win2Pos)
        badgeW3:SetBadgeText("3:" .. win3Pos)
        badgeSize:SetBadgeText((L("尺寸") or "SIZE") .. " " .. sizeMode)
        invalidHint:Hide()
    end

    local function ApplyPreviewGuess()
        if refreshLock then return end

        local fb = GetDB().frameBind
        fb = fb or {}
        GetDB().frameBind = fb

        ClampFrameToCanvas(previewWin2)
        ClampFrameToCanvas(previewWin3)

        local dir2, dist2, snap2x, snap2y = GetNearestAnchor(previewWin2, previewWin1)
        local dir3, dist3, snap3x, snap3y = GetNearestAnchor(previewWin3, previewWin2)

        local attach2 = dist2 <= ATTACH_THRESHOLD
        local attach3 = dist3 <= ATTACH_THRESHOLD
        local nearWin1By3 = UpdateIllegalPreviewState()

        if attach2 then
            fb.win2Position = dir2
            snap2x, snap2y = ClampXYToCanvas(previewWin2, snap2x, snap2y)
            SetRelativeCenter(previewWin2, snap2x, snap2y)
        end

        if attach3 then
            fb.win3Position = dir3
            snap3x, snap3y = ClampXYToCanvas(previewWin3, snap3x, snap3y)
            SetRelativeCenter(previewWin3, snap3x, snap3y)
        end

        -- 不支援 1 + 3 群組：如果 3 靠近 1，但沒有正確吸附到 2，直接視為無效並回復
        if nearWin1By3 then
            badgeGroup:SetBadgeText(L("無效") or "INVALID")
            badgeW2:SetBadgeText("1+3")
            badgeW3:SetBadgeText(L("不支援") or "UNSUPPORTED")
            badgeSize:SetBadgeText(L("已還原") or "REVERT")
            C_Timer.After(0.25, function()
                if parent and parent.RefreshValue then
                    RefreshPage(parent)
                end
            end)
            RefreshPreviewFromDB()
            return
        end

        if attach2 and attach3 then
            fb.snapGroupMode = "123"
        elseif attach2 then
            fb.snapGroupMode = "12"
        elseif attach3 then
            fb.snapGroupMode = "23"
        else
            RefreshPreviewFromDB()
            return
        end

        ApplyLayout()
    end

    local function SetupPreviewDrag(frame)
        frame:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            if not DamageMeterTools:IsModuleEnabled("FrameBind", true) then return end

            local cx, cy = self:GetCenter()
            local mx, my = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale() or 1
            mx = mx / scale
            my = my / scale

            self._dragging = true
            self._dragOffsetX = mx - cx
            self._dragOffsetY = my - cy
            self:SetBackdropBorderColor(T:GetColor("accentBlue"))
        end)

        frame:SetScript("OnMouseUp", function(self, button)
            if button ~= "LeftButton" then return end
            if not self._dragging then return end

            self._dragging = nil
            self._dragOffsetX = nil
            self._dragOffsetY = nil
            self:SetBackdropBorderColor(T:GetColor("borderStrong"))
            ClampFrameToCanvas(self)
            ApplyPreviewGuess()
        end)

        frame:SetScript("OnUpdate", function(self)
            if not self._dragging then return end

            local left = canvas:GetLeft()
            local bottom = canvas:GetBottom()
            if not left or not bottom then return end

            local mx, my = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale() or 1
            mx = mx / scale
            my = my / scale

            local newX = (mx - (self._dragOffsetX or 0)) - left
            local newY = (my - (self._dragOffsetY or 0)) - bottom

            newX, newY = ClampXYToCanvas(self, newX, newY)
            SetRelativeCenter(self, newX, newY)

            if self == previewWin3 then
                UpdateIllegalPreviewState()
            else
                invalidHint:Hide()
            end
        end)
    end

    SetupPreviewDrag(previewWin2)
    SetupPreviewDrag(previewWin3)

    Place(editorCard, 388, 16)

    ----------------------------------------------------------------
    -- 手動微調
    ----------------------------------------------------------------
    local secManual = CreateSection(content, L("手動微調") or "手動微調", 720)
    Place(secManual, 30)

    local groupModeTitle = T:CreateText(content, L("吸附群組模式") or "吸附群組模式", "GameFontHighlight", "accent")
    groupModeTitle:SetWidth(700)
    groupModeTitle:SetJustifyH("LEFT")
    Place(groupModeTitle, 20)

local groupModeRow = CreateFrame("Frame", nil, content)
groupModeRow:SetSize(720, 28)

local cbGroup1, cbGroup2, cbGroup3, groupSummary

local function UpdateGroupSummary()
    local mode = NormalizeGroupMode(GetDB().frameBind.snapGroupMode or "123")
    if mode == "123" then
        groupSummary:SetText(L("目前群組：1+2+3 全部連動") or "目前群組：1+2+3 全部連動")
    elseif mode == "12" then
        groupSummary:SetText(L("目前群組：1+2 連動，3 自由") or "目前群組：1+2 連動，3 自由")
    else
        groupSummary:SetText(L("目前群組：2+3 連動，1 自由") or "目前群組：2+3 連動，1 自由")
    end
end

local function ApplyGroupModeFromChecks()
    local c1 = cbGroup1:GetChecked()
    local c2 = cbGroup2:GetChecked()
    local c3 = cbGroup3:GetChecked()

    -- 2 必須存在
    if not c2 then
        c2 = true
        cbGroup2:SetChecked(true)
    end

    -- 全不勾 → 預設 1+2
    if not c1 and not c3 then
        c1 = true
        cbGroup1:SetChecked(true)
    end

    if c1 and c3 then
        GetDB().frameBind.snapGroupMode = "123"
    elseif c1 then
        GetDB().frameBind.snapGroupMode = "12"
    else
        GetDB().frameBind.snapGroupMode = "23"
    end

    ApplyLayout()
    UpdateGroupSummary()
end

cbGroup1 = CreateCheck(groupModeRow, "1", function()
    local mode = NormalizeGroupMode(GetDB().frameBind.snapGroupMode or "123")
    return (mode == "123" or mode == "12")
end, function()
    ApplyGroupModeFromChecks()
end)
cbGroup1:SetSize(60, 24)
cbGroup1:SetPoint("LEFT", 0, 0)

cbGroup2 = CreateCheck(groupModeRow, "2", function()
    return true
end, function()
    cbGroup2:SetChecked(true)
    ApplyGroupModeFromChecks()
end)
cbGroup2:SetSize(60, 24)
cbGroup2:SetPoint("LEFT", cbGroup1, "RIGHT", 10, 0)
cbGroup2:SetChecked(true)

cbGroup3 = CreateCheck(groupModeRow, "3", function()
    local mode = NormalizeGroupMode(GetDB().frameBind.snapGroupMode or "123")
    return (mode == "123" or mode == "23")
end, function()
    ApplyGroupModeFromChecks()
end)
cbGroup3:SetSize(60, 24)
cbGroup3:SetPoint("LEFT", cbGroup2, "RIGHT", 10, 0)

Place(groupModeRow, 28)

groupSummary = CreateInfoText(content, 700)
groupSummary:SetText("")
Place(groupSummary, 18, 6)
    local secWin2 = CreateSection(content, L("視窗 2 吸附位置") or "視窗 2 吸附位置", 720)
    Place(secWin2, 30)

    local win2Row = CreateFrame("Frame", nil, content)
    win2Row:SetSize(720, 28)

    local btnWin2Up = CreateChoiceButton(win2Row, L("向上 (UP)") or "向上 (UP)", 100, function()
        GetDB().frameBind.win2Position = "UP"
        ApplyLayout()
    end)
    btnWin2Up:SetPoint("LEFT", 0, 0)

    local btnWin2Down = CreateChoiceButton(win2Row, L("向下 (DOWN)") or "向下 (DOWN)", 100, function()
        GetDB().frameBind.win2Position = "DOWN"
        ApplyLayout()
    end)
    btnWin2Down:SetPoint("LEFT", btnWin2Up, "RIGHT", 8, 0)

    local btnWin2Left = CreateChoiceButton(win2Row, L("向左 (LEFT)") or "向左 (LEFT)", 100, function()
        GetDB().frameBind.win2Position = "LEFT"
        ApplyLayout()
    end)
    btnWin2Left:SetPoint("LEFT", btnWin2Down, "RIGHT", 8, 0)

    local btnWin2Right = CreateChoiceButton(win2Row, L("向右 (RIGHT)") or "向右 (RIGHT)", 100, function()
        GetDB().frameBind.win2Position = "RIGHT"
        ApplyLayout()
    end)
    btnWin2Right:SetPoint("LEFT", btnWin2Left, "RIGHT", 8, 0)

    Place(win2Row, 28)

    local secWin3 = CreateSection(content, L("視窗 3 吸附位置") or "視窗 3 吸附位置", 720)
    Place(secWin3, 30)

    local win3Row = CreateFrame("Frame", nil, content)
    win3Row:SetSize(720, 28)

    local btnWin3Up = CreateChoiceButton(win3Row, L("向上 (UP)") or "向上 (UP)", 100, function()
        GetDB().frameBind.win3Position = "UP"
        ApplyLayout()
    end)
    btnWin3Up:SetPoint("LEFT", 0, 0)

    local btnWin3Down = CreateChoiceButton(win3Row, L("向下 (DOWN)") or "向下 (DOWN)", 100, function()
        GetDB().frameBind.win3Position = "DOWN"
        ApplyLayout()
    end)
    btnWin3Down:SetPoint("LEFT", btnWin3Up, "RIGHT", 8, 0)

    local btnWin3Left = CreateChoiceButton(win3Row, L("向左 (LEFT)") or "向左 (LEFT)", 100, function()
        GetDB().frameBind.win3Position = "LEFT"
        ApplyLayout()
    end)
    btnWin3Left:SetPoint("LEFT", btnWin3Down, "RIGHT", 8, 0)

    local btnWin3Right = CreateChoiceButton(win3Row, L("向右 (RIGHT)") or "向右 (RIGHT)", 100, function()
        GetDB().frameBind.win3Position = "RIGHT"
        ApplyLayout()
    end)
    btnWin3Right:SetPoint("LEFT", btnWin3Left, "RIGHT", 8, 0)

    Place(win3Row, 28)

    local manualInfo = CreateInfoText(content, 700)
    manualInfo:SetText(L("需要時再用下面按鈕微調。") or "需要時再用下面按鈕微調。")
    Place(manualInfo, 18, 16)

    content:SetHeight(math.abs(y) + 40)

    parent.RefreshValue = function(self)
        refreshLock = true

        cbModule:RefreshValue()
        cbEnableSnap:RefreshValue()
        cbMatchSize:RefreshValue()
        sliderSpacing:RefreshValue()

        local moduleEnabled = DamageMeterTools:IsModuleEnabled("FrameBind", true)
        local snapEnabled = moduleEnabled and (GetDB().frameBind.enableSnap == true)
        local matchSizeEnabled = moduleEnabled and (GetDB().frameBind.matchSize == true)

        local groupMode = NormalizeGroupMode(GetDB().frameBind.snapGroupMode or "123")
        local sizeMode = NormalizeSizeMode(GetDB().frameBind.sizeSyncMode or "123")
        local win2Pos = tostring(GetDB().frameBind.win2Position or "DOWN"):upper()
        local win3Pos = tostring(GetDB().frameBind.win3Position or "RIGHT"):upper()

        cbSize1:RefreshValue()
        cbSize2:RefreshValue()
        cbSize3:RefreshValue()
        UpdateSizeSummary()

        cbGroup1:RefreshValue()
        cbGroup2:RefreshValue()
        cbGroup3:RefreshValue()
        UpdateGroupSummary()

        btnWin2Up:SetSelectedVisual(win2Pos == "UP")
        btnWin2Down:SetSelectedVisual(win2Pos == "DOWN")
        btnWin2Left:SetSelectedVisual(win2Pos == "LEFT")
        btnWin2Right:SetSelectedVisual(win2Pos == "RIGHT")

        btnWin3Up:SetSelectedVisual(win3Pos == "UP")
        btnWin3Down:SetSelectedVisual(win3Pos == "DOWN")
        btnWin3Left:SetSelectedVisual(win3Pos == "LEFT")
        btnWin3Right:SetSelectedVisual(win3Pos == "RIGHT")

        T:SetEnabled(cbEnableSnap, moduleEnabled)
        T:SetEnabled(cbMatchSize, moduleEnabled)

        T:SetEnabled(sizeModeTitle, moduleEnabled)
        T:SetEnabled(cbSize1, matchSizeEnabled)
        T:SetEnabled(cbSize2, matchSizeEnabled)
        T:SetEnabled(cbSize3, matchSizeEnabled)
        T:SetEnabled(sizeSummary, matchSizeEnabled)

        T:SetEnabled(groupModeTitle, moduleEnabled)
        T:SetEnabled(cbGroup1, snapEnabled)
        T:SetEnabled(cbGroup2, snapEnabled)
        T:SetEnabled(cbGroup3, snapEnabled)
        T:SetEnabled(groupSummary, snapEnabled)

        local win2PositionEnabled = snapEnabled and (groupMode == "123" or groupMode == "12")
        local win3PositionEnabled = snapEnabled and (groupMode == "123" or groupMode == "23")

        T:SetEnabled(btnWin2Up, win2PositionEnabled)
        T:SetEnabled(btnWin2Down, win2PositionEnabled)
        T:SetEnabled(btnWin2Left, win2PositionEnabled)
        T:SetEnabled(btnWin2Right, win2PositionEnabled)

        T:SetEnabled(btnWin3Up, win3PositionEnabled)
        T:SetEnabled(btnWin3Down, win3PositionEnabled)
        T:SetEnabled(btnWin3Left, win3PositionEnabled)
        T:SetEnabled(btnWin3Right, win3PositionEnabled)

        T:SetEnabled(btnEditorRefresh, moduleEnabled)
        T:SetEnabled(btnEditorReset, moduleEnabled)
        T:SetEnabled(cbEditor1, moduleEnabled)
        T:SetEnabled(cbEditor2, moduleEnabled)
        T:SetEnabled(cbEditor3, moduleEnabled)

        editorCard:SetAlpha(moduleEnabled and 1 or 0.45)
        previewWin2:EnableMouse(moduleEnabled)
        previewWin3:EnableMouse(moduleEnabled)

        basicInfo:SetAlpha(moduleEnabled and 1 or 0.45)
        manualInfo:SetAlpha(moduleEnabled and 1 or 0.45)
        cbEditor1:RefreshValue()
        cbEditor2:RefreshValue()
        cbEditor3:RefreshValue()
        RefreshPreviewFromDB()

        refreshLock = false
    end
end

----------------------------------------------------------------
local function BuildExportPage(parent)
    local scroll, content = CreateContentScroll(parent)
    parent.scroll = scroll
    parent.content = content

    local y = -10
    local function Place(widget, h, gap)
        widget:SetPoint("TOPLEFT", 10, y)
        y = y - (h or widget:GetHeight() or 24) - (gap or 10)
    end

    local secTop = CreateSection(content, L("匯出名次") or "匯出名次", 720)
    Place(secTop, 30)

    local topRow = CreateFrame("Frame", nil, content)
    topRow:SetSize(720, 28)

    local btnTop3 = CreateChoiceButton(topRow, "Top 3", 90, function()
        GetDB().export.topN = 3
        RefreshPage(parent)
    end)
    btnTop3:SetPoint("LEFT", 0, 0)

    local btnTop5 = CreateChoiceButton(topRow, "Top 5", 90, function()
        GetDB().export.topN = 5
        RefreshPage(parent)
    end)
    btnTop5:SetPoint("LEFT", btnTop3, "RIGHT", 8, 0)

    local btnTop10 = CreateChoiceButton(topRow, "Top 10", 90, function()
        GetDB().export.topN = 10
        RefreshPage(parent)
    end)
    btnTop10:SetPoint("LEFT", btnTop5, "RIGHT", 8, 0)
    Place(topRow, 28)

    local secSend = CreateSection(content, L("快速發送") or "快速發送", 720)
    Place(secSend, 30)

    local sendRow = CreateFrame("Frame", nil, content)
    sendRow:SetSize(720, 28)

    local btnAuto = CreateActionButton(sendRow, L("自動"), 90, function()
        if DamageMeterTools_ExportTop5 then
            DamageMeterTools_ExportTop5("AUTO")
        end
    end, "BLUE")
    btnAuto:SetPoint("LEFT", 0, 0)

    local btnParty = CreateActionButton(sendRow, L("隊伍"), 90, function()
        if DamageMeterTools_ExportTop5 then
            DamageMeterTools_ExportTop5("PARTY")
        end
    end)
    btnParty:SetPoint("LEFT", btnAuto, "RIGHT", 8, 0)

    local btnRaid = CreateActionButton(sendRow, L("團隊"), 90, function()
        if DamageMeterTools_ExportTop5 then
            DamageMeterTools_ExportTop5("RAID")
        end
    end)
    btnRaid:SetPoint("LEFT", btnParty, "RIGHT", 8, 0)

    local btnInstance = CreateActionButton(sendRow, L("副本"), 90, function()
        if DamageMeterTools_ExportTop5 then
            DamageMeterTools_ExportTop5("INSTANCE_CHAT")
        end
    end)
    btnInstance:SetPoint("LEFT", btnRaid, "RIGHT", 8, 0)

    local btnSay = CreateActionButton(sendRow, L("說"), 90, function()
        if DamageMeterTools_ExportTop5 then
            DamageMeterTools_ExportTop5("SAY")
        end
    end)
    btnSay:SetPoint("LEFT", btnInstance, "RIGHT", 8, 0)

    Place(sendRow, 28)

    local btnPreview = CreateActionButton(content, L("預覽報告"), 140, function()
        if DamageMeterTools_PreviewTop5ToInput then
            DamageMeterTools_PreviewTop5ToInput("AUTO")
        end
    end, "ACCENT")
    Place(btnPreview, 24)

    local cbHideRealm = CreateCheck(content, L("名稱顯示時移除伺服器尾碼"), function()
        return GetDB().export.hideRealm
    end, function(v)
        GetDB().export.hideRealm = v
        Notify("Export")
    end)
    Place(cbHideRealm, 24)

    local cbShowPercent = CreateCheck(content, L("匯出顯示百分比 (%)"), function()
        return GetDB().export.showPercent ~= false
    end, function(v)
        GetDB().export.showPercent = v and true or false
        Notify("Export")
    end)
    Place(cbShowPercent, 24)

    content:SetHeight(math.abs(y) + 40)

    parent.RefreshValue = function(self)
        refreshLock = true

        cbHideRealm:RefreshValue()
        cbShowPercent:RefreshValue()


        local topN = tonumber(GetDB().export.topN) or 5
        btnTop3:SetSelectedVisual(topN == 3)
        btnTop5:SetSelectedVisual(topN == 5)
        btnTop10:SetSelectedVisual(topN == 10)

        refreshLock = false
    end
end

local function BuildErrorPage(parent)
    local scroll, content = CreateContentScroll(parent)
    parent.scroll = scroll
    parent.content = content

    local y = -10
    local function Place(widget, h, gap)
        widget:SetPoint("TOPLEFT", 10, y)
        y = y - (h or widget:GetHeight() or 24) - (gap or 10)
    end

    ----------------------------------------------------------------
    -- 錯誤提示 / 錯誤記錄
    ----------------------------------------------------------------
    local secErrors = CreateSection(content, L("錯誤記錄") or "錯誤記錄", 720)
    Place(secErrors, 30)

    local cbErrNotify = CreateCheck(content, L("啟用錯誤提示"), function()
        return GetDB().errors and (GetDB().errors.notify ~= false)
    end, function(v)
        local db = GetDB()
        db.errors = db.errors or {}
        db.errors.notify = v and true or false
    end)
    Place(cbErrNotify, 24)

    local errBtnRow = CreateFrame("Frame", nil, content)
    errBtnRow:SetSize(720, 28)

    local errListFrame = nil
    local errDetailEdit = nil

    local btnErrRefresh = CreateActionButton(errBtnRow, L("重新整理") or "重新整理", 120, function()
        if errListFrame and errListFrame.Refresh then
            errListFrame:Refresh()
        end
    end, "BLUE")
    btnErrRefresh:SetPoint("LEFT", 0, 0)

    local btnErrClear = CreateActionButton(errBtnRow, L("清除記錄") or "清除記錄", 120, function()
        if DamageMeterTools and DamageMeterTools.ClearErrorLog then
            DamageMeterTools:ClearErrorLog()
        end
        if errListFrame and errListFrame.Refresh then
            errListFrame:Refresh()
        end
    end, "DANGER")
    btnErrClear:SetPoint("LEFT", btnErrRefresh, "RIGHT", 8, 0)

    local btnErrCopy = CreateActionButton(errBtnRow, L("一鍵複製") or "Copy", 120, function()
        if errDetailEdit then
            errDetailEdit:SetFocus()
            errDetailEdit:HighlightText()
        end
    end, "ACCENT")
    btnErrCopy:SetPoint("LEFT", btnErrClear, "RIGHT", 8, 0)

    Place(errBtnRow, 28)

    errListFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    errListFrame:SetSize(720, 200)
    T:ApplyBackdrop(errListFrame, "panel2", "border")
    Place(errListFrame, 200, 10)

    local errScroll = CreateFrame("ScrollFrame", nil, errListFrame, "UIPanelScrollFrameTemplate")
    errScroll:SetPoint("TOPLEFT", 6, -6)
    errScroll:SetPoint("BOTTOMRIGHT", -26, 6)
    T:StyleScrollBar(errScroll)

    local errContent = CreateFrame("Frame", nil, errScroll)
    errContent:SetSize(660, 1)
    errScroll:SetScrollChild(errContent)

    local errRows = {}
    local function EnsureErrRow(i)
        if errRows[i] then return errRows[i] end
        local row = CreateFrame("Button", nil, errContent)
        row:SetHeight(22)
        row:SetWidth(640)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetTextColor(1, 1, 1, 1)
        errRows[i] = row
        return row
    end

    local errDetailBox = CreateFrame("Frame", nil, content, "BackdropTemplate")
    errDetailBox:SetSize(720, 90)
    T:ApplyBackdrop(errDetailBox, "panel", "border")
    Place(errDetailBox, 90, 6)

    local errDetailScroll = CreateFrame("ScrollFrame", nil, errDetailBox, "UIPanelScrollFrameTemplate")
    errDetailScroll:SetPoint("TOPLEFT", 6, -6)
    errDetailScroll:SetPoint("BOTTOMRIGHT", -26, 6)
    T:StyleScrollBar(errDetailScroll)

    errDetailEdit = CreateFrame("EditBox", nil, errDetailScroll)
    errDetailEdit:SetMultiLine(true)
    errDetailEdit:SetAutoFocus(false)
    errDetailEdit:SetFontObject(GameFontHighlightSmall)
    errDetailEdit:SetWidth(660)
    errDetailEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    errDetailEdit:SetScript("OnTextChanged", function(self)
        self:GetParent():UpdateScrollChildRect()
    end)

    errDetailScroll:SetScrollChild(errDetailEdit)

    function errListFrame:Refresh()
        local log = {}
        if DamageMeterTools and DamageMeterTools.GetErrorLog then
            log = DamageMeterTools:GetErrorLog() or {}
        end

        for i = 1, #log do
            local item = log[i]
            local row = EnsureErrRow(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -((i - 1) * 22))
            local summary = item.summary or item.raw or ""
            local count = item.count or 1
            row.text:SetText(string.format("(%d) %s", count, summary))
            row._item = item
            row:SetScript("OnClick", function(self)
                local it = self._item
                if not it then return end
                local header = string.format(L("錯誤次數：%d") or "Count: %d", it.count or 1)
                if errDetailEdit then
                    errDetailEdit:SetText(header .. "\n" .. tostring(it.raw or ""))
                    errDetailEdit:SetCursorPosition(0)
                end
            end)
            row:Show()
        end

        for i = (#log + 1), #errRows do
            errRows[i]:Hide()
        end

        errContent:SetHeight(math.max(1, #log * 22))

        if #log == 0 then
            if errDetailEdit then
                errDetailEdit:SetText(L("目前沒有錯誤記錄。") or "No errors logged.")
                errDetailEdit:SetCursorPosition(0)
            end
        end
    end

    content:SetHeight(math.abs(y) + 40)

    parent.RefreshValue = function(self)
        refreshLock = true

        cbErrNotify:RefreshValue()
        if errListFrame and errListFrame.Refresh then
            errListFrame:Refresh()
        end

        refreshLock = false
    end
end

local function BuildAddonPage(parent)
    local scroll, content = CreateContentScroll(parent)
    parent.scroll = scroll
    parent.content = content

    local y = -10
    local function Place(widget, h, gap)
        widget:SetPoint("TOPLEFT", 10, y)
        y = y - (h or widget:GetHeight() or 24) - (gap or 10)
    end

    local secConsole = CreateSection(content, L("控制台") or "控制台", 720)
    Place(secConsole, 30)

    local row1 = CreateFrame("Frame", nil, content)
    row1:SetSize(720, 28)

    local btnReload = CreateActionButton(row1, L("套用並重載"), 140, function()
        ReloadUI()
    end, "ACCENT")
    btnReload:SetPoint("LEFT", 0, 0)

    local btnClose = CreateActionButton(row1, L("關閉控制台"), 140, function()
        if console then
            console:Hide()
        end
    end)
    btnClose:SetPoint("LEFT", btnReload, "RIGHT", 8, 0)

    Place(row1, 28)

    local secLauncher = CreateSection(content, "Minimap / Broker", 720)
    Place(secLauncher, 30)

    local cbMinimap = CreateCheck(content, L("顯示小地圖按鈕"), function()
        return DamageMeterTools_IsMinimapButtonShown and DamageMeterTools_IsMinimapButtonShown()
    end, function(v)
        if DamageMeterTools_SetMinimapButtonShown then
            DamageMeterTools_SetMinimapButtonShown(v)
        end
        RefreshPage(parent)
    end)
    Place(cbMinimap, 24)

    local minimapInfo = CreateInfoText(content, 700)
    Place(minimapInfo, 18, 16)

    local secRestrictedPVP = CreateSection(content, GetRestrictedPVPSectionTitleText(), 720)
    Place(secRestrictedPVP, 30)

    local cbRestrictedPVPNotify = CreateCheck(content, GetRestrictedPVPNotifySettingText(), function()
        local db = GetDB()
        db.restrictedPVP = db.restrictedPVP or {}
        return db.restrictedPVP.notify ~= false
    end, function(v)
        local db = GetDB()
        db.restrictedPVP = db.restrictedPVP or {}
        db.restrictedPVP.notify = v and true or false
        RefreshPage(parent)
    end)
    Place(cbRestrictedPVPNotify, 24)

    local restrictedPVPInfo = CreateInfoText(content, 700)
    restrictedPVPInfo:SetText(GetRestrictedPVPInfoText())
    Place(restrictedPVPInfo, 32, 16)

    local secTheme = CreateSection(content, L("面板配色") or "面板配色", 720)
    Place(secTheme, 30)

    local themeRow = CreateFrame("Frame", nil, content)
    themeRow:SetSize(720, 28)

    local btnDark = CreateChoiceButton(themeRow, L("深色") or "深色", 90, function()
        T:SetStyleKey("DARK")
        ApplyConsoleTheme()
        RefreshAllPages()
    end)
    btnDark:SetPoint("LEFT", 0, 0)

    local btnGold = CreateChoiceButton(themeRow, L("金色") or "金色", 90, function()
        T:SetStyleKey("GOLD")
        ApplyConsoleTheme()
        RefreshAllPages()
    end)
    btnGold:SetPoint("LEFT", btnDark, "RIGHT", 8, 0)

    local btnOcean = CreateChoiceButton(themeRow, L("海洋") or "海洋", 90, function()
        T:SetStyleKey("OCEAN")
        ApplyConsoleTheme()
        RefreshAllPages()
    end)
    btnOcean:SetPoint("LEFT", btnGold, "RIGHT", 8, 0)

    Place(themeRow, 28)

    local secLocale = CreateSection(content, L("語系設定") or "語系設定", 720)
    Place(secLocale, 30)

    local localeRow = CreateFrame("Frame", nil, content)
    localeRow:SetSize(720, 28)

    local btnLocaleAuto = CreateChoiceButton(localeRow, L("Auto") or "Auto", 88, function()
        SetStoredLocaleOverride("AUTO")
        print("|cff00ff00[DMT]|r " .. string.format(L("已儲存語系設定：%s") or "已儲存語系設定：%s", GetLocaleDisplayText("AUTO")))
        RefreshPage(parent)
    end)
    btnLocaleAuto:SetPoint("LEFT", 0, 0)

    local btnLocaleTW = CreateChoiceButton(localeRow, L("繁中") or "繁中", 88, function()
        SetStoredLocaleOverride("zhTW")
        print("|cff00ff00[DMT]|r " .. string.format(L("已儲存語系設定：%s") or "已儲存語系設定：%s", GetLocaleDisplayText("zhTW")))
        RefreshPage(parent)
    end)
    btnLocaleTW:SetPoint("LEFT", btnLocaleAuto, "RIGHT", 8, 0)

    local btnLocaleCN = CreateChoiceButton(localeRow, L("简中") or "简中", 88, function()
        SetStoredLocaleOverride("zhCN")
        print("|cff00ff00[DMT]|r " .. string.format(L("已儲存語系設定：%s") or "已儲存語系設定：%s", GetLocaleDisplayText("zhCN")))
        RefreshPage(parent)
    end)
    btnLocaleCN:SetPoint("LEFT", btnLocaleTW, "RIGHT", 8, 0)

    local btnLocaleEN = CreateChoiceButton(localeRow, L("English") or "English", 100, function()
        SetStoredLocaleOverride("enUS")
        print("|cff00ff00[DMT]|r " .. string.format(
            L("已儲存語系設定：%s") or "已儲存語系設定：%s",
            GetLocaleDisplayText("enUS")
        ))
        RefreshPage(parent)
    end)
    btnLocaleEN:SetPoint("LEFT", btnLocaleCN, "RIGHT", 8, 0)

    Place(localeRow, 28)

    local localeInfo = CreateInfoText(content, 700)
    Place(localeInfo, 18, 6)

    local localeGameInfo = CreateInfoText(content, 700)
    Place(localeGameInfo, 18, 6)

    local localeTip = CreateInfoText(content, 700)
    Place(localeTip, 18, 16)

    local secSlash = CreateSection(content, L("指令") or "指令", 720)
    Place(secSlash, 30)

    local cmd1 = T:CreateText(content, "/dmt  /dmtc", "GameFontHighlightSmall", "text")
    cmd1:SetWidth(700)
    cmd1:SetJustifyH("LEFT")
    Place(cmd1, 18)

    local cmd2 = T:CreateText(content, "/dmtop5", "GameFontHighlightSmall", "text")
    cmd2:SetWidth(700)
    cmd2:SetJustifyH("LEFT")
    Place(cmd2, 18)

    local cmd3 = T:CreateText(content, "/dmtpreview", "GameFontHighlightSmall", "text")
    cmd3:SetWidth(700)
    cmd3:SetJustifyH("LEFT")
    Place(cmd3, 18)

    content:SetHeight(math.abs(y) + 40)

    parent.RefreshValue = function(self)
        refreshLock = true

        cbMinimap:RefreshValue()
        cbRestrictedPVPNotify:RefreshValue()

        if DamageMeterTools_IsMinimapButtonShown and DamageMeterTools_IsMinimapButtonShown() then
            minimapInfo:SetText((L("目前：") or "目前：") .. (L("已顯示") or "已顯示"))
        else
            minimapInfo:SetText((L("目前：") or "目前：") .. (L("已隱藏") or "已隱藏"))
        end

        local themeKey = T:GetStyleKey()
        btnDark:SetSelectedVisual(themeKey == "DARK")
        btnGold:SetSelectedVisual(themeKey == "GOLD")
        btnOcean:SetSelectedVisual(themeKey == "OCEAN")

        btnDark.Text:SetText(L("深色") or "深色")
        btnGold.Text:SetText(L("金色") or "金色")
        btnOcean.Text:SetText(L("海洋") or "海洋")

        local localeOverride = tostring(GetStoredLocaleOverride() or "AUTO")
        local localeUpper = localeOverride:upper()

        btnLocaleAuto.Text:SetText("Auto")
        btnLocaleTW.Text:SetText("繁中")
        btnLocaleCN.Text:SetText("简中")
        btnLocaleEN.Text:SetText("English")

        btnLocaleAuto:SetSelectedVisual(localeUpper == "AUTO")
        btnLocaleTW:SetSelectedVisual(localeUpper == "ZHTW")
        btnLocaleCN:SetSelectedVisual(localeUpper == "ZHCN")
        btnLocaleEN:SetSelectedVisual(localeUpper == "ZHEN" or localeUpper == "ENUS" or localeUpper == "ENGB")

        localeInfo:SetText(string.format(L("目前語系：%s") or "目前語系：%s", GetLocaleDisplayText(localeOverride)))
        localeGameInfo:SetText(string.format(L("遊戲語系：%s") or "遊戲語系：%s", GetGameLocaleDisplayText()))
        localeTip:SetText(L("切換語系後，請按「套用並重載」完整套用。") or "切換語系後，請按「套用並重載」完整套用。")

        refreshLock = false
    end
end

local function BuildConsole()
    if console then
        return console
    end

    EnsureDB()

    local f = CreateFrame("Frame", "DamageMeterToolsConsoleFrame", UIParent, "BackdropTemplate")
    f:SetSize(1100, 720)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    T:ApplyBackdrop(f, "bg", "borderStrong")
    f:Hide()

    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(56)
    T:ApplyBackdrop(header, "header", "border")

    local logo = header:CreateTexture(nil, "OVERLAY")
    logo:SetSize(22, 22)
    logo:SetPoint("LEFT", 16, 0)
    logo:SetTexture("Interface\\AddOns\\DamageMeterTools\\dmt.tga")

    local title = T:CreateTitle(header, "DamageMeterTools", "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)

    local version = T:CreateText(header, "Console", "GameFontHighlightSmall", "textDim")
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)

    local closeBtn = T:CreateButton(header, "×", 34, 26, function()
        f:Hide()
    end, "DANGER")
    closeBtn:SetPoint("RIGHT", -10, 0)

    local reloadBtn = T:CreateButton(header, L("套用並重載"), 120, 24, function()
        ReloadUI()
    end, "ACCENT")
    reloadBtn:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)

    local themeBtn = T:CreateButton(header, GetThemeDisplayText(T:GetStyleKey()), 90, 24, function(selfBtn)
        local order = { "DARK", "GOLD", "OCEAN" }
        local cur = T:GetStyleKey()
        local nextKey = "DARK"
        for i, k in ipairs(order) do
            if k == cur then
                nextKey = order[i + 1] or order[1]
                break
            end
        end
        T:SetStyleKey(nextKey)
        if selfBtn and selfBtn.Text then
            selfBtn.Text:SetText(GetThemeDisplayText(nextKey))
        end
        ApplyConsoleTheme()
        RefreshAllPages()
    end, "BLUE")
    themeBtn:SetPoint("RIGHT", reloadBtn, "LEFT", -8, 0)

    local sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 12, -12)
    sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 50)
    sidebar:SetWidth(180)
    T:ApplyBackdrop(sidebar, "panel", "border")

    local sidebarTitle = T:CreateText(sidebar, L("設定分類") or "設定分類", "GameFontHighlight", "accent")
    sidebarTitle:SetPoint("TOPLEFT", 14, -14)

    local contentWrap = CreateFrame("Frame", nil, f, "BackdropTemplate")
    contentWrap:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 12, 0)
    contentWrap:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 50)
    T:ApplyBackdrop(contentWrap, "panel", "border")

    local footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", 0, 0)
    footer:SetHeight(38)
    T:ApplyBackdrop(footer, "header", "border")

    f.header = header
    f.sidebar = sidebar
    f.contentWrap = contentWrap
    f.footer = footer
    f.title = title
    f.version = version
    f.themeBtn = themeBtn

    local lastBtn = nil
    for i, info in ipairs(PAGE_ORDER) do
        local btn = CreateSidebarButton(sidebar, info.text)
        if i == 1 then
            btn:SetPoint("TOPLEFT", 8, -42)
        else
            btn:SetPoint("TOPLEFT", lastBtn, "BOTTOMLEFT", 0, -6)
        end
        btn:SetScript("OnClick", function()
            SelectPage(info.key)
        end)
        sidebarButtons[info.key] = btn
        lastBtn = btn

        local page = CreateFrame("Frame", nil, contentWrap)
        page:SetAllPoints(contentWrap)
        page:Hide()
        pages[info.key] = page
    end

    BuildAppearancePage(pages.Appearance)
    BuildInteractionPage(pages.Interaction)
    BuildResetPage(pages.Reset)
    BuildLayoutPage(pages.Layout)
    BuildExportPage(pages.Export)
    BuildErrorPage(pages.Errors)
    BuildAddonPage(pages.Addon)

    f:SetScript("OnShow", function()
        EnsureDB()
        ApplyConsoleTheme()
        if not currentPageKey then
            SelectPage("Appearance")
        else
            SelectPage(currentPageKey)
        end
    end)

    console = f

    if UISpecialFrames then
        local exists = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "DamageMeterToolsConsoleFrame" then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(UISpecialFrames, "DamageMeterToolsConsoleFrame")
        end
    end

    ApplyConsoleTheme()
    return console
end

function DamageMeterTools_OpenConsole()
    local f = BuildConsole()
    if not f:IsShown() then
        f:Show()
    end
end

function DamageMeterTools_ToggleConsole()
    local f = BuildConsole()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end