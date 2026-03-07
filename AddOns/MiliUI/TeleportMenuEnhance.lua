------------------------------------------------------------
-- MiliUI: TeleportMenu 按鈕間距增強
-- 在 TeleportMenu 按鈕之間加入垂直間距，
-- 不修改 TeleportMenu 原始程式碼。
--
-- 使用冪等 (idempotent) 演算法：
-- 無論目前定位是原始值還是已含間距值，都能推算出正確的
-- slot index 並套用 -(buttonSize + SPACING) * slot 的位置。
-- 因此不會疊加，多次呼叫結果一致。
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
    -- 原始位置格式：yOfs = -buttonSize * slot
    -- 含間距格式：  yOfs = -step * slot
    -- 兩者取誤差較小的那個來決定 slot
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

-- 第一次開啟：OnShow + C_Timer.After(0) → 1 幀延遲（幾乎看不到）
-- 第二次起：hooksecurefunc 同步執行 → 無延遲
GameMenuFrame:HookScript("OnShow", function()
    C_Timer.After(0, function()
        if not TeleportMeButtonsFrameRight then return end
        ApplySpacing()
        -- 註冊同步 hook（在 TeleportMenu 的 hook 之後執行）
        if not hooked then
            hooked = true
            hooksecurefunc("ToggleGameMenu", function()
                if GameMenuFrame:IsShown() then
                    ApplySpacing()
                end
            end)
        end
    end)
end)
