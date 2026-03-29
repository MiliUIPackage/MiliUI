if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end

local L = DamageMeterTools_L or function(s) return s end

local LSM = nil
if LibStub then
    LSM = LibStub("LibSharedMedia-3.0", true)
end

local containers = setmetatable({}, { __mode = "k" })
local fadeTargets = setmetatable({}, { __mode = "k" })
local hookedWindows = setmetatable({}, { __mode = "k" })
local hookedRegions = setmetatable({}, { __mode = "k" })
local suppressorInstalled = setmetatable({}, { __mode = "k" })
local originalHeaderAlpha = setmetatable({}, { __mode = "k" })
local originalTextColor = setmetatable({}, { __mode = "k" })
local cachedBaseTitleText = setmetatable({}, { __mode = "k" })
local dropdownClickHooked = setmetatable({}, { __mode = "k" })
local hideTimer = nil
local fallbackTicker = nil
local watchdogTicker = nil
local refreshPending = false
local isShowing = false
local watchdogUntil = nil

local STYLES = {
    GLASS = {
        top = {0.65, 0.86, 1.00, 0.18},
        bottom = {0.65, 0.86, 1.00, 0.45},
        leftGlow = {0.50, 0.75, 1.00, 0.00},
        bg = {0.10, 0.20, 0.30},
    },
    GOLD = {
        top = {1.00, 0.86, 0.25, 0.20},
        bottom = {1.00, 0.82, 0.18, 0.50},
        leftGlow = {1.00, 0.85, 0.25, 0.00},
        bg = {0.30, 0.22, 0.10},
    },
    STEEL = {
        top = {0.80, 0.84, 0.90, 0.18},
        bottom = {0.74, 0.78, 0.85, 0.45},
        leftGlow = {0.70, 0.74, 0.82, 0.00},
        bg = {0.16, 0.18, 0.22},
    },
    NEON = {
        top = {0.82, 0.52, 1.00, 0.20},
        bottom = {0.74, 0.42, 1.00, 0.50},
        leftGlow = {0.72, 0.38, 1.00, 0.00},
        bg = {0.22, 0.10, 0.28},
    },
}

local function GetDB()
    if DamageMeterTools and DamageMeterTools.GetDB then
        return DamageMeterTools:GetDB()
    end
    return DamageMeterToolsDB
end

local function EnsureDB()
    local db = GetDB()

    db.headerSkin = db.headerSkin or {}
    if db.headerSkin.style == nil then db.headerSkin.style = "GLASS" end
    if db.headerSkin.mode == nil then db.headerSkin.mode = "STYLE" end
    if db.headerSkin.lsmName == nil then db.headerSkin.lsmName = "Blizzard" end
    if db.headerSkin.showLines == nil then db.headerSkin.showLines = false end
    if db.headerSkin.titleFontSize == nil then db.headerSkin.titleFontSize = 14 end
    if db.headerSkin.titleFontName == nil then db.headerSkin.titleFontName = "GAME_DEFAULT" end
    if db.headerSkin.showModeSuffix == nil then db.headerSkin.showModeSuffix = true end
    if db.headerSkin.backgroundAlpha == nil then db.headerSkin.backgroundAlpha = 16 end
    if db.headerSkin.titleTextMode == nil then db.headerSkin.titleTextMode = "ALWAYS" end

    db.headerSkin.titleTextColor = db.headerSkin.titleTextColor or {}
    if db.headerSkin.titleTextColor.r == nil then db.headerSkin.titleTextColor.r = 1.00 end
    if db.headerSkin.titleTextColor.g == nil then db.headerSkin.titleTextColor.g = 0.82 end
    if db.headerSkin.titleTextColor.b == nil then db.headerSkin.titleTextColor.b = 0.20 end
    if db.headerSkin.titleTextColor.a == nil then db.headerSkin.titleTextColor.a = 1.00 end

    db.headerSkin.suffixTextColor = db.headerSkin.suffixTextColor or {}
    if db.headerSkin.suffixTextColor.r == nil then db.headerSkin.suffixTextColor.r = 1.00 end
    if db.headerSkin.suffixTextColor.g == nil then db.headerSkin.suffixTextColor.g = 1.00 end
    if db.headerSkin.suffixTextColor.b == nil then db.headerSkin.suffixTextColor.b = 1.00 end
    if db.headerSkin.suffixTextColor.a == nil then db.headerSkin.suffixTextColor.a = 1.00 end

    db.headerSkin.backgroundColor = db.headerSkin.backgroundColor or {}
    if db.headerSkin.backgroundColor.r == nil then db.headerSkin.backgroundColor.r = 0.02 end
    if db.headerSkin.backgroundColor.g == nil then db.headerSkin.backgroundColor.g = 0.04 end
    if db.headerSkin.backgroundColor.b == nil then db.headerSkin.backgroundColor.b = 0.06 end
    if db.headerSkin.backgroundColor.a == nil then db.headerSkin.backgroundColor.a = 1.00 end

    db.hover = db.hover or {}
    if db.hover.hideDelay == nil then db.hover.hideDelay = 2 end
end

local function IsHeaderSkinBlockedByZone()
    return DamageMeterTools_IsRestrictedPVPZone and DamageMeterTools_IsRestrictedPVPZone()
end

local function IsHeaderSkinModuleEnabled()
    EnsureDB()

    if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
        if not DamageMeterTools:IsModuleEnabled("HeaderSkin", true) then
            return false
        end
    else
        return true
    end

    if IsHeaderSkinBlockedByZone() then
        return false
    end

    return true
end

local function IsHoverModuleEnabled()
    EnsureDB()
    if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
        if not DamageMeterTools:IsModuleEnabled("Hover", true) then
            return false
        end
    else
        return true
    end

    if IsHeaderSkinBlockedByZone() then
        return false
    end

    return true
end

local function IsSafeToTouchProtectedHeader()
    return not (InCombatLockdown and InCombatLockdown())
end

local function IsEditModeActive()
    if C_EditMode and C_EditMode.IsEditModeActive then
        return C_EditMode.IsEditModeActive()
    end
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

local function GetHideDelay()
    EnsureDB()
    return tonumber(GetDB().hover.hideDelay) or 2
end

local function GetStyle()
    EnsureDB()
    local key = tostring(GetDB().headerSkin.style or "GLASS"):upper()
    return STYLES[key] or STYLES.GLASS
end

local function GetTitleFontSize()
    EnsureDB()
    local size = tonumber(GetDB().headerSkin.titleFontSize) or 14
    if size < 10 then size = 10 end
    if size > 24 then size = 24 end
    return size
end

local function GetTitleFontPath()
    EnsureDB()
    local name = tostring(GetDB().headerSkin.titleFontName or "GAME_DEFAULT")

    if name == "GAME_DEFAULT" then
        return STANDARD_TEXT_FONT
    end

    if LSM then
        local path = LSM:Fetch("font", name, true)
        if path and path ~= "" then
            return path
        end
    end

    return STANDARD_TEXT_FONT
end

local function GetHeaderTexturePath()
    EnsureDB()
    local db = GetDB()
    local mode = tostring(db.headerSkin.mode or "STYLE"):upper()
    if mode ~= "LSM" then
        return nil
    end

    local name = tostring(db.headerSkin.lsmName or "Blizzard")
    if name == "NONE" then
        return "" -- 透明（無材質）
    end

    if LSM then
        local path = LSM:Fetch("statusbar", name, true)
        if path and path ~= "" then
            return path
        end
    end

    return nil
end

local function GetTitleTextColor()
    local c = GetDB().headerSkin.titleTextColor or {}
    return tonumber(c.r) or 1.00, tonumber(c.g) or 0.82, tonumber(c.b) or 0.20, tonumber(c.a) or 1.00
end

local function GetSuffixTextColor()
    local c = GetDB().headerSkin.suffixTextColor or {}
    return tonumber(c.r) or 1.00, tonumber(c.g) or 1.00, tonumber(c.b) or 1.00, tonumber(c.a) or 1.00
end

local function GetBackgroundColor()
    local c = GetDB().headerSkin.backgroundColor or {}
    return tonumber(c.r) or 0.02, tonumber(c.g) or 0.04, tonumber(c.b) or 0.06, tonumber(c.a) or 1.00
end

local function GetBackgroundAlpha()
    local alpha = tonumber(GetDB().headerSkin.backgroundAlpha) or 16
    if alpha < 0 then alpha = 0 end
    if alpha > 100 then alpha = 100 end
    return alpha / 100
end

local function IsShowLines()
    return GetDB().headerSkin.showLines == true
end

local function IsShowModeSuffixEnabled()
    return GetDB().headerSkin.showModeSuffix == true
end


local function RemoveColorCodes(text)
    local s = tostring(text or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    return s
end

local function StripHeaderModeSuffix(text)
    local s = RemoveColorCodes(text)

    local changed = true
    while changed do
        local before = s
        s = s:gsub("%s*（總體）$", "")
        s = s:gsub("%s*（當前）$", "")
        s = s:gsub("%s*（总体）$", "")
        s = s:gsub("%s*（当前）$", "")
        s = s:gsub("%s*%(Overall%)$", "")
        s = s:gsub("%s*%(Current%)$", "")
        s = s:gsub("%s+Overall$", "")
        s = s:gsub("%s+總體$", "")
        s = s:gsub("%s+总体$", "")
        s = s:gsub("%s+$", "")
        changed = (s ~= before)
    end

    return s
end

local function ColorizeSuffix(text)
    local suffix = tostring(text or "")
    if suffix == "" then
        return ""
    end

    local r, g, b = GetSuffixTextColor()
    local hex = string.format(
        "%02x%02x%02x",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )

    return "|cff" .. hex .. suffix .. "|r"
end

local function SaveOriginalTextColor(fs)
    if not fs or originalTextColor[fs] or not fs.GetTextColor then
        return
    end
    local r, g, b, a = fs:GetTextColor()
    originalTextColor[fs] = { r or 1, g or 1, b or 1, a or 1 }
end

local function RestoreOriginalTextColor(fs)
    if not fs or not fs.SetTextColor then
        return
    end
    local c = originalTextColor[fs]
    if c then
        fs:SetTextColor(c[1], c[2], c[3], c[4])
    end
end

local function IsOverallMode(window)
    -- ✅ 優先用快取的 SessionType（即時）
    if window and window._DMT_SessionType and Enum and Enum.DamageMeterSessionType then
        return window._DMT_SessionType == Enum.DamageMeterSessionType.Overall
    end

    -- ✅ 再嘗試直接取 GetSessionType
    if window and window.GetSessionType and Enum and Enum.DamageMeterSessionType then
        local ok, sessionType = pcall(window.GetSessionType, window)
        if ok and sessionType ~= nil then
            return sessionType == Enum.DamageMeterSessionType.Overall
        end
    end

    -- ✅ 最後才用文字判斷（最慢）
    local sessionText = nil
    if window and window.SessionDropdown then
        sessionText =
            (window.SessionDropdown.SessionName and window.SessionDropdown.SessionName.GetText and window.SessionDropdown.SessionName:GetText())
            or (window.SessionDropdown.Text and window.SessionDropdown.Text.GetText and window.SessionDropdown.Text:GetText())
    end

    sessionText = tostring(sessionText or "")
    local lower = sessionText:lower()

    return lower:find("overall", 1, true) ~= nil
        or sessionText:find("總體", 1, true) ~= nil
        or sessionText:find("总体", 1, true) ~= nil
end

local function GetHeaderModeSuffix(window)
    if not IsShowModeSuffixEnabled() then
        return ""
    end

    if IsOverallMode(window) then
        return L("總體") or "Overall"
    end

    return ""
end

local function GetBaseHeaderTitle(window)
    if not window then
        return ""
    end

    local typeName = window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.TypeName
    if not typeName or not typeName.GetText then
        return cachedBaseTitleText[window] or ""
    end

    local currentText = tostring(typeName:GetText() or "")
    local cleanText = StripHeaderModeSuffix(currentText)

    if cleanText ~= "" then
        cachedBaseTitleText[window] = cleanText
        return cleanText
    end

    return cachedBaseTitleText[window] or ""
end

local function ApplyTitleStyle(fontString)
    if not fontString or not fontString.SetFont then
        return
    end

    local fontPath = GetTitleFontPath()
    local fontSize = GetTitleFontSize()
    local r, g, b, a = GetTitleTextColor()

    local ok = pcall(fontString.SetFont, fontString, fontPath, fontSize, "OUTLINE")
    if not ok then
        pcall(fontString.SetFont, fontString, STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    end

    if fontString.SetWordWrap then fontString:SetWordWrap(false) end
    if fontString.SetNonSpaceWrap then fontString:SetNonSpaceWrap(false) end
    if fontString.SetMaxLines then fontString:SetMaxLines(1) end
    if fontString.SetTextColor then fontString:SetTextColor(r, g, b, a) end
    if fontString.SetShadowOffset then fontString:SetShadowOffset(1, -1) end
    if fontString.SetShadowColor then fontString:SetShadowColor(0, 0, 0, 0.85) end
end

local function InstallHeaderSuppressor(window)
    if not window or suppressorInstalled[window] then
        return
    end

    local header = window.Header
    if not header then
        return
    end

    suppressorInstalled[window] = true

    if originalHeaderAlpha[window] == nil and header.GetAlpha then
        originalHeaderAlpha[window] = header:GetAlpha()
    end
end

local function ForceHideOriginalHeader(window)
    if not window or not window.Header or not window.Header.SetAlpha then
        return
    end

    local header = window.Header
    if originalHeaderAlpha[window] == nil and header.GetAlpha then
        originalHeaderAlpha[window] = header:GetAlpha()
    end

    if IsSafeToTouchProtectedHeader() then
        header:SetAlpha(0)
    end
end

local function RestoreOriginalHeader(window)
    if not window or not window.Header or not window.Header.SetAlpha then
        return
    end

    if not IsSafeToTouchProtectedHeader() then
        return
    end

    local alpha = originalHeaderAlpha[window]
    if alpha == nil then
        alpha = 1
    end
    window.Header:SetAlpha(alpha)
end

local function EnsureContainer(window)
    if not window or not window.Header then
        return nil
    end

    InstallHeaderSuppressor(window)

    if containers[window] then
        return containers[window]
    end

    local c = CreateFrame("Frame", nil, window)

    local header = window.Header
    local baseLevel = (header and header.GetFrameLevel and header:GetFrameLevel())
        or (window.GetFrameLevel and window:GetFrameLevel())
        or 1

    local baseStrata = (header and header.GetFrameStrata and header:GetFrameStrata())
        or (window.GetFrameStrata and window:GetFrameStrata())
        or "MEDIUM"

    c:SetFrameStrata(baseStrata)

    local lvl = baseLevel - 2
    if lvl < 0 then lvl = 0 end
    c:SetFrameLevel(lvl)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", window.Header, "TOPLEFT", 10, 0)
    c:SetPoint("BOTTOMRIGHT", window.Header, "BOTTOMRIGHT", -10, 0)
    c:EnableMouse(false)
    c:Hide()

    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()

    c.top = c:CreateTexture(nil, "OVERLAY")
    c.top:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    c.top:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
    c.top:SetHeight(1)

    c.bottom = c:CreateTexture(nil, "OVERLAY")
    c.bottom:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
    c.bottom:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
    c.bottom:SetHeight(1)

    c.leftGlow = c:CreateTexture(nil, "ARTWORK")
    c.leftGlow:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    c.leftGlow:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
    c.leftGlow:SetWidth(42)

    containers[window] = c
    return c
end

local function AddUnique(list, obj)
    if not obj then
        return
    end
    for _, v in ipairs(list) do
        if v == obj then
            return
        end
    end
    table.insert(list, obj)
end

local function BuildFadeTargetList(window)
    local list = {}

    if IsHeaderSkinModuleEnabled() then
        AddUnique(list, containers[window])
    else
        AddUnique(list, window and window.Header)
    end

    AddUnique(list, window and window.SettingsDropdown)
    AddUnique(list, window and window.SettingsDropdown and window.SettingsDropdown.Icon)
    AddUnique(list, window and window.DamageMeterTypeDropdown)
    AddUnique(list, window and window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.Arrow)
    AddUnique(list, window and window.SessionDropdown)
    AddUnique(list, window and window.SessionDropdown and window.SessionDropdown.Background)

    fadeTargets[window] = list
end

local function GetAllFadeTargets(window)
    return fadeTargets[window] or {}
end

function DamageMeterTools_GetHeaderSkinContainer(window)
    return containers[window]
end

function DamageMeterTools_GetHeaderFadeParts(window)
    return {
        all = GetAllFadeTargets(window),
    }
end

local function ApplyObjectAlpha(obj, alpha, animate)
    if not obj or not obj.SetAlpha or not obj.GetAlpha then
        return
    end

    local current = obj:GetAlpha() or 1

    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(obj)
    end

    if not animate or math.abs(current - alpha) < 0.01 then
        obj:SetAlpha(alpha)
        return
    end

    if alpha > current and UIFrameFadeIn then
        UIFrameFadeIn(obj, 0.2, current, alpha)
    elseif alpha < current and UIFrameFadeOut then
        UIFrameFadeOut(obj, 0.2, current, alpha)
    else
        obj:SetAlpha(alpha)
    end
end

local function IsMouseOverAnyWindow()
    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w and w:IsShown() and w.IsMouseOver and w:IsMouseOver() then
            return true
        end
    end
    return false
end

local function SetWindowFadeAlpha(window, alpha, animate)
    for _, obj in ipairs(GetAllFadeTargets(window)) do
        ApplyObjectAlpha(obj, alpha, animate)
    end
end

local function SetAllFadeAlpha(alpha, animate)
    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w and w:IsShown() then
            SetWindowFadeAlpha(w, alpha, animate)
        end
    end
end

local function ApplyHeaderTitle(window)
    if not window then
        return
    end

    local typeName = window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.TypeName
    if not typeName then
        return
    end

    SaveOriginalTextColor(typeName)
    ApplyTitleStyle(typeName)

    local base = GetBaseHeaderTitle(window)
    local suffix = GetHeaderModeSuffix(window)
    local finalText = base

    if suffix ~= "" then
        finalText = base .. " " .. ColorizeSuffix(suffix)
    end

    if typeName.SetText then
        typeName:SetText(finalText)
    end
end

local function ApplyHeaderSession(window)
    if not window then
        return
    end

    local sessionName = window.SessionDropdown and (window.SessionDropdown.SessionName or window.SessionDropdown.Text)
    if sessionName then
        SaveOriginalTextColor(sessionName)
    end
end

local ApplyOneWindow

-- ✅ 防錯安全刷新（避免報錯 + 交給全域錯誤提示）
local function SafeApply(w)
    if not w or not w.IsShown or not w:IsShown() then return end

    local ok, err = xpcall(function()
        ApplyOneWindow(w)
    end, debugstack)

    if not ok then
        if DamageMeterTools and DamageMeterTools.ReportError then
            DamageMeterTools:ReportError(err)
        else
            print("|cffff0000[DMT Error][HeaderSkin]|r " .. tostring(err))
        end
    end
end

local function RefreshWindowLater(w)
    if not w or not w.IsShown or not w:IsShown() then return end

    SafeApply(w)

    -- ✅ 只補一次 0秒（讓UI完成切換）
    C_Timer.After(0, function()
        if w and w:IsShown() then SafeApply(w) end
    end)
end

ApplyOneWindow = function(window)
    if not window then
        return
    end

    if IsHeaderSkinBlockedByZone() then
        local typeName = window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.TypeName
        local sessionName = window.SessionDropdown and (window.SessionDropdown.SessionName or window.SessionDropdown.Text)
        local container = containers[window]

        cachedBaseTitleText[window] = nil

        if container then
            container:Hide()
        end

        RestoreOriginalHeader(window)
        RestoreOriginalTextColor(typeName)
        RestoreOriginalTextColor(sessionName)

        return
    end

    local combatLocked = InCombatLockdown and InCombatLockdown()

    -- ✅ 每次刷新都補一次 SessionType 快取
    if window.GetSessionType and Enum and Enum.DamageMeterSessionType then
        local ok, sessionType = pcall(window.GetSessionType, window)
        if ok and sessionType ~= nil then
            window._DMT_SessionType = sessionType
        end
    end

    local container = EnsureContainer(window)
    BuildFadeTargetList(window)

    if IsHeaderSkinModuleEnabled() then
        local style = GetStyle()
        local bgR, bgG, bgB = GetBackgroundColor()
        local bgA = GetBackgroundAlpha()

        -- ✅ 如果是內建風格（STYLE），就用風格自帶背景色
        if tostring(GetDB().headerSkin.mode or "STYLE"):upper() == "STYLE" then
            if style.bg then
                bgR, bgG, bgB = style.bg[1], style.bg[2], style.bg[3]
            end
        end

        -- ✅ 戰鬥中只跳過框體變更，但文字照常更新
        if not combatLocked then
            ForceHideOriginalHeader(window)

            if container then
                container:Show()

                local headerTex = GetHeaderTexturePath()
                if headerTex == "" then
                    -- 透明（無材質）
                    container.bg:SetTexture(nil)
                    container.bg:SetColorTexture(0, 0, 0, 0)
                    container.bg:SetAlpha(0)

                elseif headerTex then
                    -- LSM 材質（強制重複顯示）
                    container.bg:SetTexture(headerTex, "REPEAT", "REPEAT")
                    if container.bg.SetHorizTile then container.bg:SetHorizTile(true) end
                    if container.bg.SetVertTile then container.bg:SetVertTile(false) end
                    container.bg:SetTexCoord(0, 1, 0, 1)
                    container.bg:SetVertexColor(1, 1, 1, 1)
                    container.bg:SetAlpha(bgA)

                else
                    -- 內建風格/純色
                    container.bg:SetTexture(nil)
                    container.bg:SetColorTexture(bgR, bgG, bgB, bgA)
                    container.bg:SetAlpha(1)
                end

                if IsShowLines() then
                    container.top:SetColorTexture(style.top[1], style.top[2], style.top[3], style.top[4])
                    container.bottom:SetColorTexture(style.bottom[1], style.bottom[2], style.bottom[3], style.bottom[4])
                    container.leftGlow:SetColorTexture(style.leftGlow[1], style.leftGlow[2], style.leftGlow[3], style.leftGlow[4])
                else
                    container.top:SetColorTexture(0, 0, 0, 0)
                    container.bottom:SetColorTexture(0, 0, 0, 0)
                    container.leftGlow:SetColorTexture(0, 0, 0, 0)
                end
            end
        end

        -- ✅ 文字仍然即時更新（戰鬥中也會跑）
        ApplyHeaderTitle(window)
        ApplyHeaderSession(window)

    else
        if not combatLocked then
            if container then
                container:Hide()
            end
            RestoreOriginalHeader(window)
        end

        local typeName = window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.TypeName
        local sessionName = window.SessionDropdown and (window.SessionDropdown.SessionName or window.SessionDropdown.Text)

        cachedBaseTitleText[window] = nil
        RestoreOriginalTextColor(typeName)
        RestoreOriginalTextColor(sessionName)
    end
end

local function CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

local function StopFallbackTicker()
    if fallbackTicker then
        fallbackTicker:Cancel()
        fallbackTicker = nil
    end
end

local function StopWatchdog()
    if watchdogTicker then
        watchdogTicker:Cancel()
        watchdogTicker = nil
    end
    watchdogUntil = nil
end

local function ShowFadeElements()
    if DamageMeterTools_CombatHide_IsSuppressed and DamageMeterTools_CombatHide_IsSuppressed() then
        return
    end

    CancelHideTimer()
    isShowing = true
    SetAllFadeAlpha(1, true)
end

local function HideFadeElementsNow()
    if DamageMeterTools_CombatHide_IsSuppressed and DamageMeterTools_CombatHide_IsSuppressed() then
        isShowing = false
        return
    end

    isShowing = false
    SetAllFadeAlpha(0, true)
end

local function DelayHideFadeElements()
    CancelHideTimer()

    hideTimer = C_Timer.NewTimer(GetHideDelay(), function()
        hideTimer = nil

        if IsMouseOverAnyWindow() then
            ShowFadeElements()
        else
            HideFadeElementsNow()
        end
    end)
end

local function StartFallbackWatch(duration)
    StopFallbackTicker()

    local elapsed = 0
    local interval = 0.2
    local total = tonumber(duration) or 1.5

    fallbackTicker = C_Timer.NewTicker(interval, function()
        elapsed = elapsed + interval

        if not IsHoverModuleEnabled() then
            StopFallbackTicker()
            return
        end

        if IsMouseOverAnyWindow() then
            ShowFadeElements()
        elseif isShowing and not hideTimer then
            DelayHideFadeElements()
        end

        if elapsed >= total then
            StopFallbackTicker()
        end
    end)
end

local function ApplyFadeState()
    if DamageMeterTools_CombatHide_IsSuppressed and DamageMeterTools_CombatHide_IsSuppressed() then
        CancelHideTimer()
        StopFallbackTicker()
        isShowing = false
        SetAllFadeAlpha(0, false)
        return
    end

    if IsHoverModuleEnabled() then
        if IsMouseOverAnyWindow() then
            ShowFadeElements()
        else
            HideFadeElementsNow()
        end
    else
        CancelHideTimer()
        StopFallbackTicker()
        isShowing = true
        SetAllFadeAlpha(1, false)
    end
end

local function TryHookAllWindows()
    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w then
            BuildFadeTargetList(w)
        end
    end

    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w and not hookedWindows[w] then
            hookedWindows[w] = true

            if w.EnableMouse then
                w:EnableMouse(true)
            end

            w:HookScript("OnEnter", function()
                if not IsHoverModuleEnabled() then
                    return
                end
                ShowFadeElements()
            end)

            w:HookScript("OnLeave", function()
                if not IsHoverModuleEnabled() then
                    return
                end
                DelayHideFadeElements()
                StartFallbackWatch(1.5)
            end)

            w:HookScript("OnShow", function()
                if IsEditModeActive() then
                    return
                end
                C_Timer.After(0, function()
                    if not w or not w:IsShown() then return end
                    SafeApply(w)
                end)
            end)

            local function HookRegion(region)
                if not region or hookedRegions[region] then
                    return
                end

                hookedRegions[region] = true

                if region.EnableMouse then
                    region:EnableMouse(true)
                end

                region:HookScript("OnEnter", function()
                    if not IsHoverModuleEnabled() then
                        return
                    end
                    ShowFadeElements()
                end)

                region:HookScript("OnLeave", function()
                    if not IsHoverModuleEnabled() then
                        return
                    end
                    DelayHideFadeElements()
                    StartFallbackWatch(1.5)
                end)
            end

            HookRegion(w.Header)
            HookRegion(w.DamageMeterTypeDropdown)
            HookRegion(w.SessionDropdown)
            HookRegion(w.SettingsDropdown)

            local function HookDropdownClick(dd)
                if not dd or dropdownClickHooked[dd] then
                    return
                end

                dropdownClickHooked[dd] = true

                dd:HookScript("OnClick", function()
                    if IsEditModeActive() then return end
                    if not w or not w:IsShown() then return end
                    C_Timer.After(0, function()
                        if w and w:IsShown() then SafeApply(w) end
                    end)
                end)
            end

            HookDropdownClick(w.SessionDropdown)
            HookDropdownClick(w.DamageMeterTypeDropdown)
            HookDropdownClick(w.SettingsDropdown)
        end
    end
end

local _hookSessionDone = false
local function HookSessionChange()
    if _hookSessionDone then return end
    _hookSessionDone = true

    if DamageMeterSessionWindowMixin then
        if type(DamageMeterSessionWindowMixin.SetSessionID) == "function" then
            hooksecurefunc(DamageMeterSessionWindowMixin, "SetSessionID", function(self)
                if IsEditModeActive() then return end
                if not self or not self.IsShown or not self:IsShown() then return end
                SafeApply(self)
            end)
        end

        if type(DamageMeterSessionWindowMixin.SetSessionType) == "function" then
            hooksecurefunc(DamageMeterSessionWindowMixin, "SetSessionType", function(self, sessionType)
                if sessionType ~= nil then
                    self._DMT_SessionType = sessionType
                end
                if IsEditModeActive() then return end
                if not self or not self.IsShown or not self:IsShown() then return end
                SafeApply(self)
            end)
        end
    end
end

local function ApplyAll()
    HookSessionChange()
    TryHookAllWindows()

    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w then
            SafeApply(w)
        end
    end

    ApplyFadeState()
end

local function RequestRefresh()
    if refreshPending then
        return
    end

    refreshPending = true

    C_Timer.After(0, function()
        refreshPending = false

        if IsEditModeActive() then
            return
        end

        ApplyAll()
    end)
end

local function ApplyLate()
    C_Timer.After(0, function()
        RequestRefresh()
    end)

    C_Timer.After(0.05, function()
        RequestRefresh()
    end)

    C_Timer.After(0.15, function()
        RequestRefresh()
    end)
end

local function KickWatchdog(seconds)
    watchdogUntil = GetTime() + (seconds or 6)

    if watchdogTicker then
        return
    end

    watchdogTicker = C_Timer.NewTicker(0.75, function()
        if IsEditModeActive() then
            return
        end

        if not watchdogUntil or GetTime() > watchdogUntil then
            StopWatchdog()
            return
        end

        RequestRefresh()
    end)
end

function DamageMeterTools_HeaderSkinApplyNow()
    ApplyAll()
    ApplyLate()
    KickWatchdog(6)
end

function DamageMeterTools_HoverApplyNow()
    ApplyFadeState()
end

function DamageMeterTools_HoverRefreshFadeTargets()
    TryHookAllWindows()
    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w then
            BuildFadeTargetList(w)
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")

ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.8, function()
            RequestRefresh()
            ApplyLate()
            KickWatchdog(8)
        end)

        C_Timer.After(2.0, function()
            RequestRefresh()
        end)

    elseif event == "PLAYER_REGEN_DISABLED" then
        CancelHideTimer()
        StopFallbackTicker()
        ShowFadeElements()

    elseif event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0.2, function()
            RequestRefresh()
            ApplyLate()
            KickWatchdog(6)
        end)

    else
        C_Timer.After(0.2, function()
            RequestRefresh()
            KickWatchdog(4)
        end)
    end
end)

if DamageMeterTools then
    DamageMeterTools:RegisterSettingsCallback("HeaderSkin", function()
        RequestRefresh()
        ApplyLate()
        KickWatchdog(6)
    end)

    DamageMeterTools:RegisterSettingsCallback("Hover", function()
        ApplyFadeState()
    end)
end