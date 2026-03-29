if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end

local L = DamageMeterTools_L or function(s) return s end

local MATERIALS_TEXTURE = "Interface\\AddOns\\DamageMeterTools\\Materials.tga"
local FALLBACK_BLIZZARD = "Interface\\TargetingFrame\\UI-StatusBar"

local LSM = nil
if LibStub then
    LSM = LibStub("LibSharedMedia-3.0", true)
end

local borderCache = setmetatable({}, { __mode = "k" })
local styledBars = setmetatable({}, { __mode = "k" })
local hookedWindows = setmetatable({}, { __mode = "k" })
local hookedEntries = setmetatable({}, { __mode = "k" })
local hookedScrollBoxes = setmetatable({}, { __mode = "k" })
local knownWindows = setmetatable({}, { __mode = "k" })
local knownBars = setmetatable({}, { __mode = "k" })
local rowFontCache = setmetatable({}, { __mode = "k" })
local scrollBarState = setmetatable({}, { __mode = "k" })
local scrollBoxState = setmetatable({}, { __mode = "k" })
local scrollBoxHooked = setmetatable({}, { __mode = "k" })
local coreHooked = false
local delayedApplyToken = 0

local function GetDB()
    return DamageMeterToolsDB
end

local function NormalizeDB()
    local db = GetDB()
    db.texture = db.texture or {}

    if db.texture.source == nil then db.texture.source = "MATERIALS" end
    if db.texture.lsmName == nil then db.texture.lsmName = "Blizzard" end
    if db.texture.customTexturePath == nil then db.texture.customTexturePath = "" end
    if db.texture.restorePendingReload == nil then db.texture.restorePendingReload = false end
    if db.texture.hardDisabled == nil then db.texture.hardDisabled = false end

    if db.texture.showBorder == nil then db.texture.showBorder = false end
    if db.texture.backgroundMode == nil then
        db.texture.backgroundMode = "TRANSPARENT_BORDER"
    end
    if db.texture.backgroundAlpha == nil then
        db.texture.backgroundAlpha = 35
    end
    if db.texture.compatMode == nil then
        db.texture.compatMode = false
    end
    if db.rowFontSize == nil then
        db.rowFontSize = 12
    end
end

local function IsTextureEnabled()
    NormalizeDB()
    local db = GetDB()

    if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
        if not DamageMeterTools:IsModuleEnabled("Texture", true) then
            return false
        end
    else
        return false
    end

    if db.texture.hardDisabled or db.texture.restorePendingReload then
        return false
    end

    if DamageMeterTools_IsRestrictedPVPZone and DamageMeterTools_IsRestrictedPVPZone() then
        return false
    end

    return true
end

local function GetBackgroundMode()
    local db = GetDB()
    db.texture = db.texture or {}

    local mode = tostring(db.texture.backgroundMode or "TRANSPARENT_BORDER"):upper()
    if mode ~= "TRANSPARENT_BORDER" and mode ~= "TRANSPARENT_BORDERLESS" then
        mode = "TRANSPARENT_BORDER"
    end
    return mode
end

local function GetBackgroundAlpha()
    local db = GetDB()
    db.texture = db.texture or {}

local alpha = tonumber(db.texture.backgroundAlpha) or 35
if alpha < 0 then alpha = 0 end
if alpha > 100 then alpha = 100 end

    return alpha / 100
end

local function IsCompatModeEnabled()
    local db = GetDB()
    db.texture = db.texture or {}

    return db.texture.compatMode == true
end

local function IsEdgeMode()
    local db = GetDB()
    db.texture = db.texture or {}
    return tostring(db.texture.displayMode or "DEFAULT"):upper() == "EDGE"
end

local function SaveScrollBarState(sb)
    if not sb or scrollBarState[sb] then return end
    scrollBarState[sb] = {
        alpha = sb.GetAlpha and sb:GetAlpha() or 1,
        width = sb.GetWidth and sb:GetWidth() or 12,
        shown = sb.IsShown and sb:IsShown() or true,
    }
end

local function RestoreScrollBar(sb)
    if not sb then return end
    local st = scrollBarState[sb]
    if not st then return end

    if sb.SetAlpha then sb:SetAlpha(st.alpha or 1) end
    if sb.SetWidth then sb:SetWidth(st.width or 12) end
    if sb.EnableMouse then sb:EnableMouse(true) end
    if st.shown and sb.Show then sb:Show() end

    if sb.Track then
        sb.Track:SetAlpha(1)
        sb.Track:EnableMouse(true)
        if sb.Track.Thumb then
            sb.Track.Thumb:SetAlpha(1)
            sb.Track.Thumb:EnableMouse(true)
        end
    end
    if sb.Back then sb.Back:SetAlpha(1) end
    if sb.Forward then sb.Forward:SetAlpha(1) end
end

local function HideScrollBar(sb)
    if not sb then return end
    SaveScrollBarState(sb)

    if sb.SetAlpha then sb:SetAlpha(0) end
    if sb.SetWidth then sb:SetWidth(1) end
    if sb.EnableMouse then sb:EnableMouse(false) end

    if sb.Track then
        sb.Track:SetAlpha(0)
        sb.Track:EnableMouse(false)
        if sb.Track.Thumb then
            sb.Track.Thumb:SetAlpha(0)
            sb.Track.Thumb:EnableMouse(false)
        end
    end
    if sb.Back then sb.Back:SetAlpha(0) end
    if sb.Forward then sb.Forward:SetAlpha(0) end
end

local function SaveScrollBoxPoints(scrollBox)
    if not scrollBox or scrollBoxState[scrollBox] then return end
    local num = scrollBox:GetNumPoints()
    local t = { count = num }
    for i = 1, num do
        local p, rel, rp, x, y = scrollBox:GetPoint(i)
        t[i] = { p, rel, rp, x, y }
    end
    scrollBoxState[scrollBox] = t
end

local function RestoreScrollBoxPoints(scrollBox)
    if not scrollBox then return end
    local t = scrollBoxState[scrollBox]
    if not t then return end

    scrollBox:ClearAllPoints()
    for i = 1, t.count do
        local p = t[i][1]
        local rel = t[i][2]
        local rp = t[i][3]
        local x = t[i][4]
        local y = t[i][5]
        scrollBox:SetPoint(p, rel, rp, x, y)
    end
end

local function ForceScrollBoxAnchors(window)
    if not window then return end
    local scrollBox = window.ScrollBox or (window.GetScrollBox and window:GetScrollBox())
    if not scrollBox then return end

    SaveScrollBoxPoints(scrollBox)

    -- ✅ 這裡就是貼邊模式的「上下左右間距」
    local LEFT_INSET  = 4
    local RIGHT_INSET = 2
    local TOP_INSET   = 34   -- 原本 28 太近，改 34（你可改成 36/40）
    local BOTTOM_INSET = 6   -- 原本 4，稍微放大

    scrollBox:ClearAllPoints()
    scrollBox:SetPoint("TOPLEFT", window, "TOPLEFT", LEFT_INSET, -TOP_INSET)
    scrollBox:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -RIGHT_INSET, BOTTOM_INSET)
end

local function HookScrollBoxAnchors(scrollBox, window)
    if not scrollBox or scrollBoxHooked[scrollBox] then return end
    scrollBoxHooked[scrollBox] = true

    local updating = false
    hooksecurefunc(scrollBox, "SetPoint", function(self, point)
        if not IsEdgeMode() then return end
        if updating then return end
        if point == "TOPLEFT" or point == "BOTTOMRIGHT" then
            updating = true
            ForceScrollBoxAnchors(window)
            updating = false
        end
    end)
end

local function ApplyEdgeMode(window)
    if not window then return end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local scrollBar = window.ScrollBar or (window.GetScrollBar and window:GetScrollBar())
    local scrollBox = window.ScrollBox or (window.GetScrollBox and window:GetScrollBox())

    if IsEdgeMode() then
        HideScrollBar(scrollBar)
        ForceScrollBoxAnchors(window)
        HookScrollBoxAnchors(scrollBox, window)
    else
        RestoreScrollBar(scrollBar)
        RestoreScrollBoxPoints(scrollBox)
    end
end

local function GetActiveTexturePath()
    if not IsTextureEnabled() then
        return nil
    end

    local db = GetDB()
    local source = tostring(db.texture.source or "MATERIALS"):upper()

    if source == "DEFAULT" then
        return nil
    elseif source == "MATERIALS" then
        return MATERIALS_TEXTURE
    elseif source == "CUSTOM" then
        local p = db.texture.customTexturePath
        if type(p) == "string" and p ~= "" then
            return p
        end
        return MATERIALS_TEXTURE
    elseif source == "LSM" then
        if LSM then
            local fetched = LSM:Fetch("statusbar", db.texture.lsmName or "Blizzard", true)
            if fetched and fetched ~= "" then
                return fetched
            end
        end
        return FALLBACK_BLIZZARD
    end

    return MATERIALS_TEXTURE
end

local function EnsureBorder(statusBar)
    if not statusBar then
        return nil
    end

    if borderCache[statusBar] then
        return borderCache[statusBar]
    end

    local border = CreateFrame("Frame", nil, statusBar)
    border:SetAllPoints(statusBar)
    border:SetFrameStrata(statusBar:GetFrameStrata() or "MEDIUM")
    border:SetFrameLevel((statusBar:GetFrameLevel() or 1) + 6)
    border:EnableMouse(false)

    border.top = border:CreateTexture(nil, "OVERLAY")
    border.top:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
    border.top:SetHeight(1)

    border.bottom = border:CreateTexture(nil, "OVERLAY")
    border.bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(1)

    border.left = border:CreateTexture(nil, "OVERLAY")
    border.left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    border.left:SetWidth(1)

    border.right = border:CreateTexture(nil, "OVERLAY")
    border.right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    border.right:SetWidth(1)

    borderCache[statusBar] = border
    return border
end

local function SetBorderVisible(statusBar, shown)
    local border = EnsureBorder(statusBar)
    if not border then return end

    if shown then
        border.top:SetColorTexture(0, 0, 0, 0.95)
        border.bottom:SetColorTexture(0, 0, 0, 0.95)
        border.left:SetColorTexture(0, 0, 0, 0.95)
        border.right:SetColorTexture(0, 0, 0, 0.95)
        border:Show()
    else
        border:Hide()
    end
end

local function ApplyBackgroundMode(statusBar)
    if not statusBar then return end

    local mode = GetBackgroundMode()
    local showBorder = (mode == "TRANSPARENT_BORDER")
    local bgAlpha = GetBackgroundAlpha()

    if statusBar.Background then
        if statusBar.Background.ClearAllPoints then
            statusBar.Background:ClearAllPoints()
            statusBar.Background:SetAllPoints(statusBar)
        end

        if statusBar.Background.SetColorTexture then
            statusBar.Background:SetColorTexture(0, 0, 0, bgAlpha)
        end

        statusBar.Background:SetAlpha(1)
        statusBar.Background:Show()
    end

    if statusBar.BackgroundEdge then
        statusBar.BackgroundEdge:Hide()
    end

    SetBorderVisible(statusBar, showBorder)
end

local function GetBarCurrentTexture(statusBar)
    local tex = statusBar and statusBar.GetStatusBarTexture and statusBar:GetStatusBarTexture()
    if tex and tex.GetTexture then
        return tex:GetTexture()
    end
    return nil
end

local function NeedsRestyle(statusBar, texturePath, backgroundMode)
    local state = styledBars[statusBar]
    if not state then
        return true
    end

    if state.texture ~= texturePath then
        return true
    end

    if state.backgroundMode ~= backgroundMode then
        return true
    end

    local currentTex = GetBarCurrentTexture(statusBar)
    if currentTex ~= texturePath then
        return true
    end

    return false
end

local function StyleStatusBar(statusBar)
    if not statusBar then return end

    local texturePath = GetActiveTexturePath()
    if not texturePath then return end

    local backgroundMode = GetBackgroundMode()
    if not NeedsRestyle(statusBar, texturePath, backgroundMode) then
        knownBars[statusBar] = true
        return
    end

    if statusBar.SetStatusBarTexture then
        statusBar:SetStatusBarTexture(texturePath)
    end

    ApplyBackgroundMode(statusBar)

    styledBars[statusBar] = {
        texture = texturePath,
        backgroundMode = backgroundMode,
    }

    knownBars[statusBar] = true
end

local function RestoreDefaultStatusBar(statusBar)
    if not statusBar then return end

    if statusBar.SetStatusBarTexture then
        statusBar:SetStatusBarTexture(FALLBACK_BLIZZARD)
    end

    if statusBar.Background then
        statusBar.Background:Show()
        statusBar.Background:SetAlpha(1)
    end

    if statusBar.BackgroundEdge then
        statusBar.BackgroundEdge:Show()
        statusBar.BackgroundEdge:SetAlpha(1)
    end

    SetBorderVisible(statusBar, false)
    styledBars[statusBar] = nil
    knownBars[statusBar] = true
end

local function SkinEntry(entry)
    if not entry then return end
    if entry.StatusBar then
        if IsTextureEnabled() then
            StyleStatusBar(entry.StatusBar)
        else
            RestoreDefaultStatusBar(entry.StatusBar)
        end
    end
end

local function DelayedSkinEntry(entry, delay)
    if not entry then
        return
    end

    C_Timer.After(delay or 0.01, function()
        if not entry then
            return
        end

        if entry.IsForbidden and entry:IsForbidden() then
            return
        end

        SkinEntry(entry)
    end)
end

local function IterateWindowRows(window, callback)
    if not window or not callback then return end

    if window.LocalPlayerEntry then
        callback(window.LocalPlayerEntry)
    end

    if window.ScrollBox and window.ScrollBox.ForEachFrame then
        window.ScrollBox:ForEachFrame(function(row)
            callback(row)
        end)
    elseif window.ScrollBox and window.ScrollBox.ScrollTarget then
        for _, child in ipairs({ window.ScrollBox.ScrollTarget:GetChildren() }) do
            callback(child)
        end
    end
end

local function ApplyWindow(window)
    if not window then return end
    knownWindows[window] = true

    IterateWindowRows(window, function(row)
        SkinEntry(row)
    end)

    ApplyEdgeMode(window)
end

local function RestoreWindow(window)
    if not window then return end
    knownWindows[window] = true

    IterateWindowRows(window, function(row)
        if row and row.StatusBar then
            RestoreDefaultStatusBar(row.StatusBar)
        end
    end)

    ApplyEdgeMode(window)
end

local function GetNamedWindows()
    local out = {}
    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w then
            out[#out + 1] = w
        end
    end
    return out
end

local function ForEachKnownWindow(func)
    for window in pairs(knownWindows) do
        if window then
            func(window)
        end
    end

    for _, window in ipairs(GetNamedWindows()) do
        func(window)
    end
end

local function FullEnumerateWindows(func)
    local seen = setmetatable({}, { __mode = "k" })

    local function SafeRun(window)
        if window and not seen[window] then
            seen[window] = true
            func(window)
        end
    end

    for _, window in ipairs(GetNamedWindows()) do
        SafeRun(window)
    end

    local f = EnumerateFrames()
    while f do
        if not f:IsForbidden() then
            local name = f.GetName and f:GetName()
            if type(name) == "string" and name:match("^DamageMeterSessionWindow%d+$") then
                SafeRun(f)
            end
        end
        f = EnumerateFrames(f)
    end
end

local function ApplyAllKnown()
    ForEachKnownWindow(function(window)
        if IsTextureEnabled() then
            ApplyWindow(window)
        else
            RestoreWindow(window)
        end
    end)
end

local function ApplyAllFull()
    local seen = setmetatable({}, { __mode = "k" })

    local function ApplyOnce(window)
        if not window or seen[window] then
            return
        end

        seen[window] = true

        if IsTextureEnabled() then
            ApplyWindow(window)
        else
            RestoreWindow(window)
        end
    end

    for _, window in ipairs(GetNamedWindows()) do
        ApplyOnce(window)
    end

    FullEnumerateWindows(function(window)
        ApplyOnce(window)
    end)
end

local function HookEntry(entry)
    if not entry or hookedEntries[entry] then
        return
    end
    hookedEntries[entry] = true

    if entry.HookScript then
        entry:HookScript("OnShow", function(self)
            SkinEntry(self)
        end)
    end

    SkinEntry(entry)
end

local function HookScrollBox(scrollBox)
    if not scrollBox or hookedScrollBoxes[scrollBox] then
        return
    end
    hookedScrollBoxes[scrollBox] = true

    if scrollBox.ForEachFrame then
        hooksecurefunc(scrollBox, "Update", function(self)
            if IsCompatModeEnabled() then
                C_Timer.After(0.01, function()
                    if not self or (self.IsForbidden and self:IsForbidden()) then
                        return
                    end

                    if self.ForEachFrame then
                        self:ForEachFrame(function(row)
                            HookEntry(row)
                            DelayedSkinEntry(row, 0.01)
                        end)
                    end
                end)
            else
                if self.ForEachFrame then
                    self:ForEachFrame(function(row)
                        HookEntry(row)
                        SkinEntry(row)
                    end)
                end
            end
        end)
    end
end

local function HookWindow(window)
    if not window or hookedWindows[window] then
        return
    end
    hookedWindows[window] = true
    knownWindows[window] = true

    if window.ScrollBox then
        HookScrollBox(window.ScrollBox)
    end

    if window.SetupEntry then
        hooksecurefunc(window, "SetupEntry", function(_, row)
            if IsCompatModeEnabled() then
                C_Timer.After(0.01, function()
                    if not row or (row.IsForbidden and row:IsForbidden()) then
                        return
                    end

                    HookEntry(row)
                    DelayedSkinEntry(row, 0.01)
                end)
            else
                HookEntry(row)
                SkinEntry(row)
            end
        end)
    end

    if window.HookScript then
        window:HookScript("OnShow", function(self)
            if IsCompatModeEnabled() then
                C_Timer.After(0.05, function()
                    if not self or (self.IsForbidden and self:IsForbidden()) then
                        return
                    end
                    ApplyWindow(self)
                end)
            else
                ApplyWindow(self)
            end
        end)
    end

    if window.LocalPlayerEntry then
        HookEntry(window.LocalPlayerEntry)
        if IsCompatModeEnabled() then
            DelayedSkinEntry(window.LocalPlayerEntry, 0.01)
        end
    end

    if IsCompatModeEnabled() then
        C_Timer.After(0.05, function()
            if not window or (window.IsForbidden and window:IsForbidden()) then
                return
            end
            ApplyWindow(window)
        end)
    else
        ApplyWindow(window)
    end
end

local function TryHookNamedWindows()
    for _, window in ipairs(GetNamedWindows()) do
        HookWindow(window)
    end
end

local function HookBlizzardDamageMeterCore()
    if coreHooked then return end
    coreHooked = true

    if _G.DamageMeter and _G.DamageMeter.SetupSessionWindow then
        hooksecurefunc(_G.DamageMeter, "SetupSessionWindow", function(_, window)
            C_Timer.After(0, function()
                HookWindow(window)
                ApplyWindow(window)
            end)
        end)
    end
end

local function ScheduleApplyPasses(full)
    delayedApplyToken = delayedApplyToken + 1
    local token = delayedApplyToken

    local function Pass(delay)
        C_Timer.After(delay, function()
            if token ~= delayedApplyToken then
                return
            end

            HookBlizzardDamageMeterCore()
            TryHookNamedWindows()

            if full then
                ApplyAllFull()
            else
                ApplyAllKnown()
            end
        end)
    end

    Pass(0)
    Pass(0.15)
    Pass(0.60)
end

function DamageMeterTools_GetLSMStatusbarList()
    local list = {}
    if LSM then
        local hash = LSM:HashTable("statusbar")
        for name in pairs(hash) do
            table.insert(list, name)
        end
        table.sort(list)
    end
    return list
end

function DamageMeterTools_TextureForceRebuild()
    NormalizeDB()

    if IsCompatModeEnabled() and InCombatLockdown and InCombatLockdown() then
        C_Timer.After(0.20, function()
            if InCombatLockdown and InCombatLockdown() then
                return
            end

            HookBlizzardDamageMeterCore()
            TryHookNamedWindows()

            if IsTextureEnabled() then
                ApplyAllFull()
                ScheduleApplyPasses(true)
            else
                ApplyAllFull()
            end
        end)
        return
    end

    HookBlizzardDamageMeterCore()
    TryHookNamedWindows()

    if IsTextureEnabled() then
        ApplyAllFull()
        ScheduleApplyPasses(true)
    else
        ApplyAllFull()
    end
end

function DamageMeterTools_TextureRestoreDefault()
    NormalizeDB()
    local db = GetDB()

    if DamageMeterTools and DamageMeterTools.SetModuleEnabled then
        DamageMeterTools:SetModuleEnabled("Texture", true)
    end

    db.texture.source = "MATERIALS"
    db.texture.lsmName = "Blizzard"
    db.texture.customTexturePath = ""
    db.texture.hardDisabled = false
    db.texture.restorePendingReload = false
    db.texture.backgroundMode = "TRANSPARENT_BORDER"
    db.texture.backgroundAlpha = 35

    ApplyAllFull()
    ScheduleApplyPasses(true)

    print("|cff00ff00[DMT]|r " .. (L("已恢復 DMT 預設材質外觀。") or "已恢復 DMT 預設材質外觀。"))
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(_, event)
    NormalizeDB()
    HookBlizzardDamageMeterCore()
    TryHookNamedWindows()

    local db = GetDB()
    if db.texture.restorePendingReload or db.texture.hardDisabled then
        ApplyAllFull()
        return
    end

    if event == "PLAYER_LOGIN" then
        ScheduleApplyPasses(true)

    elseif event == "PLAYER_ENTERING_WORLD" then
        ScheduleApplyPasses(true)

    elseif event == "GROUP_ROSTER_UPDATE" then
        ScheduleApplyPasses(false)

    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "ZONE_CHANGED_NEW_AREA" then
        ScheduleApplyPasses(true)
    end
end)

if DamageMeterTools then
    DamageMeterTools:RegisterSettingsCallback("Texture", function()
        NormalizeDB()

        local db = GetDB()
        if DamageMeterTools:IsModuleEnabled("Texture", true) then
            db.texture.restorePendingReload = false
            db.texture.hardDisabled = false
        end

        HookBlizzardDamageMeterCore()
        TryHookNamedWindows()

        if IsTextureEnabled() then
            ApplyAllFull()
            ScheduleApplyPasses(true)
        else
            ApplyAllFull()
        end
    end)
end