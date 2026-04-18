------------------------------------------------------------
-- MiliUI: TeleportMenu 按鈕間距增強
-- 在 TeleportMenu 按鈕之間加入垂直間距，不改 TeleportMenu 原始碼。
--
-- 問題背景：
--   TeleportMenu 透過 hooksecurefunc("ToggleGameMenu") 建立按鈕，
--   註冊時機在 tpm:Setup()，而 tpm:Setup 又透過 ContinueOnLoad
--   非同步執行 — 所以我們無法在載入期保證 hook 註冊順序。
--
-- 策略：
--   1) 第一次 GameMenuFrame:OnShow：OnShow 當下即 SetAlpha(0) 把整個
--      選單藏起來（1 幀，~16ms 人眼不可察）。下一幀 tpm 已建好按鈕，
--      我們套間距再 SetAlpha(1)。這樣看不到 jump。
--   2) 同時註冊 ToggleGameMenu 的 sync post-hook；因為此時 tpm 已
--      完成首次註冊，我們的 hook 排在它之後，之後每次開選單都是
--      tpm → 我們，同步、無延遲。
--
-- 使用冪等 (idempotent) 演算法：讀取當前 yOfs、猜 slot、套用含間距
-- 位置。不論按鈕處於預設或已間距狀態，結果都正確。
------------------------------------------------------------
local SPACING = 3  -- 按鈕之間的垂直間距 (像素)

------------------------------------------------------------
-- 對一側的 ButtonsFrame（及跨側重用的按鈕）套用間距
------------------------------------------------------------
local function RespaceSide(frameName)
    local frame = _G[frameName]
    if not frame then return end

    -- 讀取按鈕尺寸 (TeleportMenu 預設 40)
    local buttonSize = (TeleportMenuDB and TeleportMenuDB["Button:Size"]) or 40
    local step = buttonSize + SPACING

    -- TeleportMenu 的 flyOutButton 物件池回收不會重設 parent，
    -- 所以同一個按鈕可能出現在對側的 child 清單裡。掃雙側，
    -- 用 relativeTo 判斷真正的歸屬。
    local otherFrame = _G[(frameName == "TeleportMeButtonsFrameLeft")
        and "TeleportMeButtonsFrameRight" or "TeleportMeButtonsFrameLeft"]

    local function RepositionChildrenOf(sourceFrame)
        for _, child in pairs({ sourceFrame:GetChildren() }) do
            if child:GetNumPoints() > 0 then
                local point, relativeTo, relativePoint, xOfs, yOfs = child:GetPoint(1)
                if relativeTo == frame and yOfs then
                    -- 冪等：推算 slot index，套用含間距的位置
                    local absY = math.abs(yOfs)
                    local slotOrig   = math.floor(absY / buttonSize + 0.5)
                    local slotSpaced = math.floor(absY / step + 0.5)
                    local errOrig   = math.abs(absY - slotOrig   * buttonSize)
                    local errSpaced = math.abs(absY - slotSpaced * step)
                    local slot = (errOrig <= errSpaced) and slotOrig or slotSpaced

                    child:ClearAllPoints()
                    child:SetPoint(point, frame, relativePoint, xOfs, -step * slot)
                end
            end
        end
    end

    RepositionChildrenOf(frame)
    if otherFrame then RepositionChildrenOf(otherFrame) end
end

local function ApplySpacing()
    if InCombatLockdown() then return end
    RespaceSide("TeleportMeButtonsFrameLeft")
    RespaceSide("TeleportMeButtonsFrameRight")
end

------------------------------------------------------------
-- 第一次開啟：SetAlpha(0) 即時隱藏，下一幀套間距再顯示
-- 之後：由 sync post-hook 處理，無延遲
------------------------------------------------------------
local initialized = false

GameMenuFrame:HookScript("OnShow", function(self)
    if initialized then return end

    -- 關鍵：alpha=0 要在 OnShow 當下就設定，讓「第一幀」就已經看不到。
    -- 若放在 C_Timer.After(0) 裡，第一幀會先渲染預設位置，造成 jump。
    -- GameMenuFrame 的 alpha 會 cascade 到所有 child（包含 TeleportMe 子框）。
    self:SetAlpha(0)

    C_Timer.After(0, function()
        -- 此時 tpm.ReloadFrames 已在上一幀的 ToggleGameMenu post-hook 中跑完，
        -- TeleportMe 子框已建立並放置預設位置。
        ApplySpacing()
        self:SetAlpha(1)

        initialized = true

        -- 註冊 sync post-hook。因為 tpm 首次註冊已完成，我們的 hook 會排
        -- 在它之後，之後每次開選單都按 tpm → 我們 的順序同步執行。
        hooksecurefunc("ToggleGameMenu", function()
            if GameMenuFrame:IsShown() then
                ApplySpacing()
            end
        end)
    end)
end)
