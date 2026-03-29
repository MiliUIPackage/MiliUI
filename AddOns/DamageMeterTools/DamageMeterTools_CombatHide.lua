if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end
local L = DamageMeterTools_L or function(s) return s end

local hideTimer = nil
local editModeHooked = false
local monitorTicker = nil
local windowsHooked = setmetatable({}, { __mode = "k" })

local combatHideSuppressed = false

local function GetDB()
    if DamageMeterTools and DamageMeterTools.db then
        return DamageMeterTools.db
    end
    return DamageMeterToolsDB
end

local function IsEditModeActive()
    if C_EditMode and C_EditMode.IsEditModeActive then
        return C_EditMode.IsEditModeActive()
    end
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

local function IsEnabled()
    local db = GetDB()
    db.combatHide = db.combatHide or {}

    if db.combatHide.zoneFilter == nil then
        db.combatHide.zoneFilter = {
            world = true,
            party = false,
            raid = false,
            pvp = false,
            arena = false,
        }
    end

    if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
        return DamageMeterTools:IsModuleEnabled("CombatHide", false)
    end

    return false
end
local function GetWindows()
    local list = {}
    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w then
            table.insert(list, w)
        end
    end
    return list
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

local function ShouldHideByZone()
    local db = GetDB()
    db.combatHide = db.combatHide or {}
    db.combatHide.zoneFilter = db.combatHide.zoneFilter or {}

    local z = db.combatHide.zoneFilter

    local anyChecked =
        (z.world == true)
        or (z.party == true)
        or (z.raid == true)
        or (z.pvp == true)
        or (z.arena == true)

    -- 全不勾 = 全地區不生效
    if not anyChecked then
        return false
    end

    local _, instanceType = GetInstanceInfo()

    if instanceType == "none" then
        return z.world == true
    elseif instanceType == "party" or instanceType == "scenario" then
        return z.party == true
    elseif instanceType == "raid" then
        return z.raid == true
    elseif instanceType == "pvp" then
        return z.pvp == true
    elseif instanceType == "arena" then
        return z.arena == true
    end

    return false
end

local fadeErrorReported = false

local function ReportFadeError(err)
    if fadeErrorReported then return end
    fadeErrorReported = true
    local msg = (L("淡入淡出錯誤") or "Fade Error:") .. " " .. tostring(err)
    if DamageMeterTools and DamageMeterTools.ReportError then
        DamageMeterTools:ReportError(msg)
    else
        print("|cffff0000[DMT Error][CombatHide]|r " .. msg)
    end
end

local function IsFadeEnabled()
    local db = GetDB()
    db.combatHide = db.combatHide or {}
    return db.combatHide.enableFade ~= false
end

local function FadeTo(w, alpha, time)
    if not w or not w.SetAlpha then
        return
    end

    -- 關閉淡入淡出 = 直接 SetAlpha
    if not IsFadeEnabled() then
        w:SetAlpha(alpha)
        return
    end

    -- 戰鬥中 / 受保護框架：安全降級
    if InCombatLockdown and InCombatLockdown() then
        w:SetAlpha(alpha)
        return
    end
    if w.IsProtected and w:IsProtected() then
        w:SetAlpha(alpha)
        return
    end

    local current = (w.GetAlpha and w:GetAlpha()) or 1
    local dur = tonumber(time) or 0.2

    local ok, err = pcall(function()
        if UIFrameFadeRemoveFrame then
            UIFrameFadeRemoveFrame(w)
        end
        if alpha > current and UIFrameFadeIn then
            UIFrameFadeIn(w, dur, current, alpha)
        elseif alpha < current and UIFrameFadeOut then
            UIFrameFadeOut(w, dur, current, alpha)
        else
            w:SetAlpha(alpha)
        end
    end)

    if not ok then
        ReportFadeError(err)
        w:SetAlpha(alpha)
    end
end

local function CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

local function StopMonitorTicker()
    if monitorTicker then
        monitorTicker:Cancel()
        monitorTicker = nil
    end
end

local function ShowAll()
    if DamageMeterTools_IsManualHidden and DamageMeterTools_IsManualHidden() then
        return
    end
    combatHideSuppressed = false

    local db = GetDB()
    db.combatHide = db.combatHide or {}

    for _, w in ipairs(GetWindows()) do
        if w and w:IsShown() then
            FadeTo(w, 1, db.combatHide.fadeInTime or 0.2)
        end
    end

    if DamageMeterTools_HoverApplyNow then
        C_Timer.After(0, function()
            DamageMeterTools_HoverApplyNow()
        end)
    end
end

local function GhostHideAll()
    if IsEditModeActive() then
        return
    end

    local db = GetDB()
    db.combatHide = db.combatHide or {}

    combatHideSuppressed = true

    for _, w in ipairs(GetWindows()) do
        if w and w:IsShown() then
            FadeTo(w, db.combatHide.hiddenAlpha or 0, db.combatHide.fadeOutTime or 0.3)
        end
    end

    if DamageMeterTools_HoverApplyNow then
        C_Timer.After(0, function()
            DamageMeterTools_HoverApplyNow()
        end)
    end
end

function DamageMeterTools_CombatHide_IsSuppressed()
    return combatHideSuppressed == true
end

local function ShouldForceShow()
    if DamageMeterTools_IsManualHidden and DamageMeterTools_IsManualHidden() then
        return false
    end
    if not IsEnabled() then
        return true
    end

    if IsEditModeActive() then
        return true
    end

    if InCombatLockdown and InCombatLockdown() then
        return true
    end

    if not ShouldHideByZone() then
        return true
    end

    return false
end

local function ApplyCurrentState()
    CancelHideTimer()

    if ShouldForceShow() then
        ShowAll()
        return
    end

    if IsMouseOverAnyWindow() then
        ShowAll()
    else
        GhostHideAll()
    end
end

local function StartShortMonitor(duration)
    StopMonitorTicker()

    local elapsed = 0
    local interval = 0.10
    local total = tonumber(duration) or 1.5
    if total < 0.3 then
        total = 0.3
    end

    monitorTicker = C_Timer.NewTicker(interval, function()
        elapsed = elapsed + interval

        if ShouldForceShow() then
            ShowAll()
            StopMonitorTicker()
            return
        end

        if IsMouseOverAnyWindow() then
            ShowAll()
        end

        if elapsed >= total then
            StopMonitorTicker()
        end
    end)
end

local function ScheduleHideCheck()
    CancelHideTimer()

    if ShouldForceShow() then
        ShowAll()
        return
    end

    local db = GetDB()
    db.combatHide = db.combatHide or {}
    local delay = tonumber(db.combatHide.fadeOutDelay) or 0

    hideTimer = C_Timer.NewTimer(delay, function()
        hideTimer = nil

        if ShouldForceShow() then
            ShowAll()
            return
        end

        if IsMouseOverAnyWindow() then
            ShowAll()
        else
            GhostHideAll()
        end
    end)

    StartShortMonitor(delay + 0.8)
end

local function HookWindow(window)
    if not window or windowsHooked[window] then
        return
    end
    windowsHooked[window] = true

    if window.EnableMouse then
        window:EnableMouse(true)
    end

    window:HookScript("OnEnter", function()
        if not IsEnabled() then
            return
        end
        ShowAll()
    end)

    window:HookScript("OnLeave", function()
        if not IsEnabled() then
            return
        end
        ScheduleHideCheck()
    end)

    if window.Header then
        window.Header:EnableMouse(true)

        window.Header:HookScript("OnEnter", function()
            if not IsEnabled() then
                return
            end
            ShowAll()
        end)

        window.Header:HookScript("OnLeave", function()
            if not IsEnabled() then
                return
            end
            ScheduleHideCheck()
        end)
    end
end

local function TryHookAllWindows()
    for i = 1, 3 do
        HookWindow(_G["DamageMeterSessionWindow" .. i])
    end
end

local function HookEditModeShowHide()
    if editModeHooked then
        return
    end

    if not EditModeManagerFrame then
        return
    end

    EditModeManagerFrame:HookScript("OnShow", function()
        CancelHideTimer()
        StopMonitorTicker()
        ShowAll()
    end)

    EditModeManagerFrame:HookScript("OnHide", function()
        C_Timer.After(0.1, function()
            ApplyCurrentState()
        end)
    end)

    editModeHooked = true
end

function DamageMeterTools_CombatHideApplyNow()
    TryHookAllWindows()
    ApplyCurrentState()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")

ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.6, function()
            HookEditModeShowHide()
            TryHookAllWindows()
            DamageMeterTools_CombatHideApplyNow()
        end)

    elseif event == "PLAYER_REGEN_DISABLED" then
        CancelHideTimer()
        StopMonitorTicker()
        C_Timer.After(0, ShowAll)

    elseif event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0.1, function()
            DamageMeterTools_CombatHideApplyNow()
        end)

    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(0.2, function()
            HookEditModeShowHide()
            TryHookAllWindows()
            DamageMeterTools_CombatHideApplyNow()
        end)
    end
end)

if DamageMeterTools then
    DamageMeterTools:RegisterSettingsCallback("CombatHide", function()
        DamageMeterTools_CombatHideApplyNow()
    end)
end