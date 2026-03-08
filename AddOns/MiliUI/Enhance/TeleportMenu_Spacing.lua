------------------------------------------------------------
-- MiliUI: TeleportMenu 按鈕間距增強
-- 在 TeleportMenu 按鈕之間加入垂直間距，
-- 不修改 TeleportMenu 原始程式碼。
--
-- 原理：TeleportMenu 透過 hooksecurefunc("ToggleGameMenu")
-- 建立按鈕。我們在第一次 GameMenuFrame:OnShow 後註冊
-- 自己的 ToggleGameMenu hook，確保執行順序在 TeleportMenu
-- 之後（hooksecurefunc 按註冊順序執行）。
--
-- 第一次開啟：先隱藏框架 → 等一幀 → 套用間距 → 顯示框架（無閃爍）
-- 第二次起：hooksecurefunc 同步執行 → 無延遲
--
-- 使用冪等 (idempotent) 演算法，多次呼叫結果一致。
------------------------------------------------------------
local SPACING = 3  -- 按鈕之間的垂直間距 (像素)
local hooked = false

local function RespaceSide(frameName)
    local frame = _G[frameName]
    if not frame then return end

    -- 讀取按鈕尺寸 (TeleportMenu 預設 40)
    local buttonSize = 40
    if TeleportMenuDB and TeleportMenuDB["Button:Size"] then
        buttonSize = TeleportMenuDB["Button:Size"]
    end
    local step = buttonSize + SPACING  -- 含間距的步進值

    -- 因為 TeleportMenu 的 flyOutButton 物件池回收不會重設 parent，
    -- 跨側重用的按鈕 parent 會指向錯誤的框架。
    -- 因此必須掃描雙側框架的子元素，根據錨點 (relativeTo) 判斷歸屬。
    local otherName = (frameName == "TeleportMeButtonsFrameLeft")
        and "TeleportMeButtonsFrameRight"
        or  "TeleportMeButtonsFrameLeft"
    local otherFrame = _G[otherName]

    local anchors = {}
    local function ScanChildren(sourceFrame)
        for _, child in pairs({ sourceFrame:GetChildren() }) do
            local ok, numPts = pcall(child.GetNumPoints, child)
            if ok and numPts and numPts > 0 then
                local point, relativeTo, relativePoint, xOfs, yOfs = child:GetPoint(1)
                if relativeTo == frame and yOfs then
                    table.insert(anchors, {
                        widget = child,
                        point = point,
                        relativePoint = relativePoint,
                        xOfs = xOfs,
                        yOfs = yOfs,
                    })
                end
            end
        end
    end
    ScanChildren(frame)
    if otherFrame then
        ScanChildren(otherFrame)
    end

    if #anchors == 0 then return end

    -- 冪等定位：推算每個元素的 slot index，套用含間距的位置
    for _, a in ipairs(anchors) do
        local absY = math.abs(a.yOfs)
        local slotFromOrig   = math.floor(absY / buttonSize + 0.5)
        local slotFromSpaced = math.floor(absY / step + 0.5)
        local errOrig   = math.abs(absY - slotFromOrig * buttonSize)
        local errSpaced = math.abs(absY - slotFromSpaced * step)
        local slot = (errOrig <= errSpaced) and slotFromOrig or slotFromSpaced

        local newY = -step * slot
        a.widget:ClearAllPoints()
        a.widget:SetPoint(a.point, frame, a.relativePoint, a.xOfs, newY)
    end
end

local function ApplySpacing()
    if InCombatLockdown() then return end
    RespaceSide("TeleportMeButtonsFrameLeft")
    RespaceSide("TeleportMeButtonsFrameRight")
end

-- 第一次開啟：OnShow → 隱藏框架 → 等一幀（按鈕已建好）→ 套用間距 → 顯示
-- 同時註冊 hooksecurefunc，之後的開啟都是同步執行、零延遲
GameMenuFrame:HookScript("OnShow", function()
    C_Timer.After(0, function()
        local left  = TeleportMeButtonsFrameLeft
        local right = TeleportMeButtonsFrameRight
        if not right then return end

        -- 第一次開啟：先隱藏 → 調整 → 再顯示，避免閃爍
        if not hooked then
            if left  then left:SetAlpha(0) end
            if right then right:SetAlpha(0) end
        end

        ApplySpacing()

        if not hooked then
            if left  then left:SetAlpha(1) end
            if right then right:SetAlpha(1) end

            hooked = true
            -- 此時 TeleportMenu 已註冊它的 hook，
            -- 我們的 hook 會排在它之後（同一幀內同步執行）
            hooksecurefunc("ToggleGameMenu", function()
                if GameMenuFrame:IsShown() then
                    ApplySpacing()
                end
            end)
        end
    end)
end)
