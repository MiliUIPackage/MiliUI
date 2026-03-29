if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end

local frameManager = CreateFrame("Frame", "DamageMeterFrameManager", UIParent)
frameManager:RegisterEvent("PLAYER_ENTERING_WORLD")
frameManager:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

local dragTicker = nil
local editModeTicker = nil
local editModeHooked = false

local hookedSecondaryWindows = setmetatable({}, { __mode = "k" })
local hookedDragTargets = setmetatable({}, { __mode = "k" })
local snappedState = setmetatable({}, { __mode = "k" })
local originalDragStart = setmetatable({}, { __mode = "k" })
local originalDragStop = setmetatable({}, { __mode = "k" })
local frameBindHooked = setmetatable({}, { __mode = "k" })
local dragActive = setmetatable({}, { __mode = "k" })

local SyncWindowsToLayout
local StartDragTicker

local function GetDB()
    DamageMeterToolsDB.frameBind = DamageMeterToolsDB.frameBind or {}
    DamageMeterToolsDB.frameBind.freePositions = DamageMeterToolsDB.frameBind.freePositions or {}
    return DamageMeterToolsDB
end

local function EnsureDB()
    local db = GetDB()
    local fb = db.frameBind

    if fb.enableSnap == nil then fb.enableSnap = true end

    local snapGroupMode = tostring(fb.snapGroupMode or "123"):upper()
    if snapGroupMode == "ALL" then
        snapGroupMode = "123"
    end
    if snapGroupMode ~= "123" and snapGroupMode ~= "12" and snapGroupMode ~= "23" then
        snapGroupMode = "123"
    end
    fb.snapGroupMode = snapGroupMode

    if fb.win2Position == nil then fb.win2Position = "DOWN" end
    if fb.win3Position == nil then fb.win3Position = "RIGHT" end

    if fb.spacing == nil then fb.spacing = 0 end
    if fb.matchSize == nil then fb.matchSize = true end

    local sizeMode = tostring(fb.sizeSyncMode or "123"):upper()
    if sizeMode == "ALL" then
        sizeMode = "123"
    end
    if sizeMode ~= "123" and sizeMode ~= "12" and sizeMode ~= "23" then
        sizeMode = "123"
    end
    fb.sizeSyncMode = sizeMode

    if fb.tickInterval == nil then fb.tickInterval = 0.08 end

    fb.freePositions = fb.freePositions or {}

    return db
end

local function IsModuleEnabled()
    if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
        return DamageMeterTools:IsModuleEnabled("FrameBind", true)
    end
    return false
end

local function GetWindow(index)
    return _G["DamageMeterSessionWindow" .. index]
end

local function GetWindowIndex(window)
    if not window then
        return nil
    end

    if window.sessionWindowIndex then
        return tonumber(window.sessionWindowIndex)
    end

    if window.GetName then
        local name = window:GetName()
        if type(name) == "string" then
            return tonumber(name:match("DamageMeterSessionWindow(%d+)"))
        end
    end

    return nil
end

local function IsEditModeActive()
    if C_EditMode and C_EditMode.IsEditModeActive then
        return C_EditMode.IsEditModeActive()
    end
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end
local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function IsSnapEnabled()
    local db = EnsureDB()
    return db.frameBind.enableSnap == true
end

local function IsSizeSyncEnabled()
    local db = EnsureDB()
    return db.frameBind.matchSize == true
end

local function GetSizeSyncMode()
    local db = EnsureDB()
    local mode = tostring(db.frameBind.sizeSyncMode or "123"):upper()

    if mode == "ALL" then
        mode = "123"
    end

    if mode ~= "123" and mode ~= "12" and mode ~= "23" then
        mode = "123"
    end

    return mode
end

local function GetSnapGroupMode()
    local db = EnsureDB()
    local mode = tostring(db.frameBind.snapGroupMode or "123"):upper()

    if mode == "ALL" then
        mode = "123"
    end

    if mode ~= "123" and mode ~= "12" and mode ~= "23" then
        mode = "123"
    end

    return mode
end

local function ShouldFollowPosition(force)
    local db = EnsureDB()
    local fb = db.frameBind

    if not IsModuleEnabled() then
        return false
    end

    if not fb.enableSnap then
        return false
    end

    return true
end

local function StopDragTicker()
    if dragTicker then
        dragTicker:Cancel()
        dragTicker = nil
    end
end

local function StopEditModeTicker()
    if editModeTicker then
        editModeTicker:Cancel()
        editModeTicker = nil
    end
end

local function SaveFreePosition(window)
    if not window then
        return
    end

    local index = GetWindowIndex(window)
    if not index or index == 1 then
        return
    end

    local db = EnsureDB()
    local fb = db.frameBind

    local point, _, relativePoint, x, y = window:GetPoint()
    if point then
        fb.freePositions[index] = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
end

local function RestoreFreePosition(window)
    if not window then
        return false
    end

    if IsCombatLocked() then
        return false
    end

    local index = GetWindowIndex(window)
    if not index or index == 1 then
        return false
    end

    local db = EnsureDB()
    local fb = db.frameBind
    local pos = fb.freePositions and fb.freePositions[index]

    if not pos then
        return false
    end

    window:ClearAllPoints()
    window:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    snappedState[window] = false
    return true
end

local function IsWindowLockedByGame(window)
    if not window then
        return false
    end

    if window.GetIsLocked then
        local ok, result = pcall(window.GetIsLocked, window)
        if ok and result ~= nil then
            return result == true
        end
    end

    if window.IsLocked then
        local ok, result = pcall(window.IsLocked, window)
        if ok and result ~= nil then
            return result == true
        end
    end

    if window.isLocked ~= nil then
        return window.isLocked == true
    end

    if window.locked ~= nil then
        return window.locked == true
    end

    return false
end

local function BeginManualDrag(window)
    if not window then
        return
    end

    local index = GetWindowIndex(window)
    if not index or index == 1 then
        return
    end

    if snappedState[window] then
        return
    end

    if IsWindowLockedByGame(window) then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local orig = originalDragStart[window]
    if orig then
        orig(window)
    else
        window:StartMoving()
    end
end

local function EndManualDrag(window)
    if not window then
        return
    end

    local index = GetWindowIndex(window)
    if not index or index == 1 then
        return
    end

    if snappedState[window] then
        return
    end

    local orig = originalDragStop[window]
    if orig then
        orig(window)
    else
        if window.StopMovingOrSizing then
            window:StopMovingOrSizing()
        end
    end

    SaveFreePosition(window)
end

local function HookDragTarget(target, ownerWindow)
    if not target or hookedDragTargets[target] then
        return
    end

    local index = GetWindowIndex(ownerWindow)
    if not index or index == 1 then
        return
    end

    hookedDragTargets[target] = true

    if target.EnableMouse then
        target:EnableMouse(true)
    end

    if target.HookScript then
        target:HookScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then
                return
            end
            dragActive[ownerWindow] = true
            BeginManualDrag(ownerWindow)
            if ShouldFollowPosition(false) then
                StartDragTicker()
            end
        end)

        target:HookScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" then
                return
            end
            dragActive[ownerWindow] = nil
            EndManualDrag(ownerWindow)

            if ShouldFollowPosition(false) then
                StopDragTicker()
                if SyncWindowsToLayout then
                    SyncWindowsToLayout(false)
                end
            end
        end)
    end
end

local function EnsureSecondaryWindowDrag(window)
    if not window then
        return
    end

    local index = GetWindowIndex(window)
    if not index or index == 1 then
        return
    end

    if hookedSecondaryWindows[window] then
        return
    end

    hookedSecondaryWindows[window] = true

    originalDragStart[window] = window:GetScript("OnDragStart")
    originalDragStop[window] = window:GetScript("OnDragStop")

    window:SetMovable(true)
    if window.EnableMouse then
        window:EnableMouse(true)
    end

    HookDragTarget(window, window)
    HookDragTarget(window.Header, window)

    window:HookScript("OnHide", function(self)
        dragActive[self] = nil
        StopDragTicker()
    end)

    window:HookScript("OnSizeChanged", function()
        if IsSizeSyncEnabled() then
            local mode = GetSizeSyncMode()
            local indexNow = GetWindowIndex(window)
            if mode == "23" and indexNow == 2 then
                local win3 = GetWindow(3)
                if win3 and win3:IsShown() then
                    win3:SetSize(window:GetWidth(), window:GetHeight())
                end
            end
        end

        if ShouldFollowPosition(false) then
            if SyncWindowsToLayout then
                SyncWindowsToLayout(false)
            end
        end
    end)
end

local function EnableFreeDrag(window)
    if not window then
        return
    end

    local index = GetWindowIndex(window)
    if not index or index == 1 then
        return
    end

    EnsureSecondaryWindowDrag(window)
    snappedState[window] = false
    window:SetMovable(true)

    if window.EnableMouse then
        window:EnableMouse(true)
    end
    if window.Header and window.Header.EnableMouse then
        window.Header:EnableMouse(true)
    end
end

local function UnlockBoundWindows()
    if IsCombatLocked() then
        return
    end

    for i = 2, 3 do
        local w = GetWindow(i)
        if w then
            EnableFreeDrag(w)

            if not RestoreFreePosition(w) then
                local cx, cy = w:GetCenter()
                if cx and cy then
                    w:ClearAllPoints()
                    w:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
                else
                    w:ClearAllPoints()
                    w:SetPoint("CENTER", UIParent, "CENTER", i * 40, -i * 40)
                end
            end
        end
    end
end

local function ApplySizeSync()
    if IsCombatLocked() then
        return
    end

    if not IsModuleEnabled() then
        return
    end

    if not IsSizeSyncEnabled() then
        return
    end

    local mode = GetSizeSyncMode()
    local win1 = GetWindow(1)
    local win2 = GetWindow(2)
    local win3 = GetWindow(3)

    if mode == "123" or mode == "12" then
        if win1 and win2 and win2:IsShown() then
            local w, h = win1:GetWidth(), win1:GetHeight()
            if w and h and w > 0 and h > 0 then
                win2:SetSize(w, h)
            end
        end
    end

    if mode == "123" then
        if win1 and win3 and win3:IsShown() then
            local w, h = win1:GetWidth(), win1:GetHeight()
            if w and h and w > 0 and h > 0 then
                win3:SetSize(w, h)
            end
        end
    elseif mode == "23" then
        if win2 and win3 and win2:IsShown() and win3:IsShown() then
            local w, h = win2:GetWidth(), win2:GetHeight()
            if w and h and w > 0 and h > 0 then
                win3:SetSize(w, h)
            end
        end
    end
end

local function SnapWindowTo(current, target, direction, spacing, applySize)
    if not current or not target or not target:IsShown() then
        return
    end

    if IsCombatLocked() then
        return
    end

    if applySize then
        current:SetSize(target:GetWidth(), target:GetHeight())
    end

    current:ClearAllPoints()
    direction = tostring(direction or "DOWN"):upper()

    if direction == "UP" then
        current:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, spacing)
        current:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, spacing)
    elseif direction == "DOWN" then
        current:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -spacing)
        current:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, -spacing)
    elseif direction == "LEFT" then
        current:SetPoint("TOPRIGHT", target, "TOPLEFT", -spacing, 0)
        current:SetPoint("BOTTOMRIGHT", target, "BOTTOMLEFT", -spacing, 0)
    elseif direction == "RIGHT" then
        current:SetPoint("TOPLEFT", target, "TOPRIGHT", spacing, 0)
        current:SetPoint("BOTTOMLEFT", target, "BOTTOMRIGHT", spacing, 0)
    else
        current:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -spacing)
        current:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, -spacing)
    end

    snappedState[current] = true

    if current.SetUserPlaced then
        current:SetUserPlaced(true)
    end
end

SyncWindowsToLayout = function(force)
    if IsCombatLocked() then
        return
    end

    if not ShouldFollowPosition(force) then
        return
    end

    local db = EnsureDB()
    local fb = db.frameBind
    local spacing = tonumber(fb.spacing) or 0

    local win1 = GetWindow(1)
    local win2 = GetWindow(2)
    local win3 = GetWindow(3)

    local groupMode = GetSnapGroupMode()
    local sizeMode = GetSizeSyncMode()

    if not win1 or not win1:IsShown() then
        return
    end

    if win2 then
        EnsureSecondaryWindowDrag(win2)
    end
    if win3 then
        EnsureSecondaryWindowDrag(win3)
    end

    ----------------------------------------------------------------
    -- 群組 123：2 跟 1，3 跟 2
    ----------------------------------------------------------------
    if groupMode == "123" then
        if win2 and win2:IsShown() then
            local applySizeWin2 = (sizeMode == "123" or sizeMode == "12")
            SnapWindowTo(win2, win1, fb.win2Position or "DOWN", spacing, applySizeWin2)
        end

        if win3 and win3:IsShown() then
            local positionTarget = nil
            if win2 and win2:IsShown() then
                positionTarget = win2
            else
                positionTarget = win1
            end

            if sizeMode == "123" and win1 and win1:IsShown() then
                local w, h = win1:GetWidth(), win1:GetHeight()
                if w and h and w > 0 and h > 0 then
                    win3:SetSize(w, h)
                end
            elseif sizeMode == "23" and win2 and win2:IsShown() then
                local w, h = win2:GetWidth(), win2:GetHeight()
                if w and h and w > 0 and h > 0 then
                    win3:SetSize(w, h)
                end
            end

            SnapWindowTo(win3, positionTarget, fb.win3Position or "RIGHT", spacing, false)
        end

    ----------------------------------------------------------------
    -- 群組 12：2 跟 1，3 自由
    ----------------------------------------------------------------
    elseif groupMode == "12" then
        if win2 and win2:IsShown() then
            local applySizeWin2 = (sizeMode == "123" or sizeMode == "12")
            SnapWindowTo(win2, win1, fb.win2Position or "DOWN", spacing, applySizeWin2)
        end

        if win3 and win3:IsShown() then
            EnableFreeDrag(win3)

            if sizeMode == "123" and win1 and win1:IsShown() then
                local w, h = win1:GetWidth(), win1:GetHeight()
                if w and h and w > 0 and h > 0 then
                    win3:SetSize(w, h)
                end
            elseif sizeMode == "23" and win2 and win2:IsShown() then
                local w, h = win2:GetWidth(), win2:GetHeight()
                if w and h and w > 0 and h > 0 then
                    win3:SetSize(w, h)
                end
            end
        end

    ----------------------------------------------------------------
    -- 群組 23：2 自由，3 跟 2
    ----------------------------------------------------------------
    elseif groupMode == "23" then
        if win2 and win2:IsShown() then
            EnableFreeDrag(win2)
        end

        if win3 and win3:IsShown() then
            local positionTarget = nil
            if win2 and win2:IsShown() then
                positionTarget = win2
            else
                positionTarget = win1
            end

            if sizeMode == "123" and win1 and win1:IsShown() then
                local w, h = win1:GetWidth(), win1:GetHeight()
                if win2 and win2:IsShown() then
                    w, h = win2:GetWidth(), win2:GetHeight()
                end
                if w and h and w > 0 and h > 0 then
                    win3:SetSize(w, h)
                end
            elseif sizeMode == "23" and win2 and win2:IsShown() then
                local w, h = win2:GetWidth(), win2:GetHeight()
                if w and h and w > 0 and h > 0 then
                    win3:SetSize(w, h)
                end
            end

            SnapWindowTo(win3, positionTarget, fb.win3Position or "RIGHT", spacing, false)
        end
    end
end
local function BurstApply(force)
    ApplySizeSync()
    SyncWindowsToLayout(force)
    C_Timer.After(0.06, function()
        ApplySizeSync()
        SyncWindowsToLayout(force)
    end)
    C_Timer.After(0.16, function()
        ApplySizeSync()
        SyncWindowsToLayout(force)
    end)
end

StartDragTicker = function()
    if dragTicker then
        return
    end

    local db = EnsureDB()
    local fb = db.frameBind
    local interval = tonumber(fb.tickInterval) or 0.08

    if interval < 0.03 then interval = 0.03 end
    if interval > 0.25 then interval = 0.25 end

    dragTicker = C_Timer.NewTicker(interval, function()
        if not ShouldFollowPosition(false) then
            StopDragTicker()
            return
        end
        SyncWindowsToLayout(false)
    end)
end

local function StartEditModeTicker()
    if editModeTicker then
        return
    end

    editModeTicker = C_Timer.NewTicker(0.1, function()
        if not IsEditModeActive() then
            StopEditModeTicker()
            return
        end

        ApplySizeSync()

        if ShouldFollowPosition(true) then
            SyncWindowsToLayout(true)
        end
    end)
end

local function HookMainWindow()
    local main = GetWindow(1)
    if not main then
        return
    end

    if frameBindHooked[main] then
        return
    end
    frameBindHooked[main] = true

    main:HookScript("OnDragStart", function()
        if ShouldFollowPosition(false) then
            StartDragTicker()
        end
    end)

    main:HookScript("OnDragStop", function()
        StopDragTicker()
        if ShouldFollowPosition(false) then
            BurstApply(false)
        end
    end)

    main:HookScript("OnSizeChanged", function()
        ApplySizeSync()
        if ShouldFollowPosition(false) then
            SyncWindowsToLayout(false)
        end
    end)

    main:HookScript("OnShow", function()
        ApplySizeSync()
        if ShouldFollowPosition(false) then
            BurstApply(false)
        end
    end)
end

local function HookEditModeShowHide()
    if editModeHooked then
        return
    end
    if not EditModeManagerFrame then
        return
    end

    EditModeManagerFrame:HookScript("OnShow", function()
        ApplySizeSync()
        if ShouldFollowPosition(true) then
            BurstApply(true)
        end
        StartEditModeTicker()
    end)

    EditModeManagerFrame:HookScript("OnHide", function()
        StopEditModeTicker()

        if not IsSnapEnabled() then
            UnlockBoundWindows()
        end
    end)

    editModeHooked = true
end

local function RefreshState()
    HookMainWindow()
    EnsureSecondaryWindowDrag(GetWindow(2))
    EnsureSecondaryWindowDrag(GetWindow(3))

    if not IsModuleEnabled() then
        StopDragTicker()
        StopEditModeTicker()
        UnlockBoundWindows()
        return
    end

    ApplySizeSync()

    if not IsSnapEnabled() then
        StopDragTicker()
        StopEditModeTicker()
        UnlockBoundWindows()
        return
    end

    if IsEditModeActive() then
        StartEditModeTicker()
    else
        StopEditModeTicker()
    end

    BurstApply(false)
end

frameManager:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        local tries = 0
        local ticker
        ticker = C_Timer.NewTicker(0.5, function()
            tries = tries + 1

            HookEditModeShowHide()
            RefreshState()

            if GetWindow(1) or tries >= 12 then
                ticker:Cancel()
            end
        end)

    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        C_Timer.After(0.1, function()
            HookEditModeShowHide()
            RefreshState()
        end)
    end
end)

function DamageMeterTools_FrameBindApplyNow()
    StopDragTicker()
    StopEditModeTicker()

    HookEditModeShowHide()
    RefreshState()
end

if DamageMeterTools then
    DamageMeterTools:RegisterSettingsCallback("FrameBind", function()
        DamageMeterTools_FrameBindApplyNow()
    end)
end