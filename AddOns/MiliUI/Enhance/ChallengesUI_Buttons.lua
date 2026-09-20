--------------------------------------------------------------------------------
-- ChallengesUI_Buttons
-- 在 M+ 鑰石放置介面 (ChallengesKeystoneFrame) 加入：
--   1. 準備確認按鈕 — DoReadyCheck()
--   2. 倒數按鈕 + 秒數滑桿 — C_PartyInfo.DoCountdown(n)
--      倒數進行中按鈕變成「停止倒數」，可隨時取消
--
-- 外觀走套組的**設定視窗皮**（`MiliUI.Style` 的 `S.Dark`）：不透明 0.1／0.115 底、
-- 1px 純黑邊、白字、直角，hover 時邊框換職業色。
--
-- 原本是這個檔案自己手寫的一套「深色半透明底 ＋ 金色邊框 ＋ 金字」，
-- 跟同一個畫面上的 `MiliUI_Skin`（暴雪視窗的皮）與隊伍鑰石面板各長一個樣。
-- 三支在 2026 年的第五輪一起改成同一套，色票全部從 `Style.lua` 拿。
--
-- ⚠ 只動外觀。事件、時機、按鈕行為（`DoReadyCheck` / `C_PartyInfo.DoCountdown`）
--   一行都沒有改：那幾支掛在暴雪的視窗上，寫法有 taint 上的理由
--   （見 .claude/notes/project-charframe-taint.md）。
--------------------------------------------------------------------------------

-- `Style.lua` 在 MiliUI.toc 排在所有 Enhance 之前（:26 對 :52-54），一定在。
local S = MiliUI.Style
local barFont = S.Font

-- 倒數狀態
local isCountingDown = false
local countdownTimer = nil
local DEFAULT_COUNTDOWN = 5

--------------------------------------------------------------------------------
-- 建立 UI
--------------------------------------------------------------------------------
local function SetupKeystoneButtons(keystoneFrame)
    if keystoneFrame._miliButtons then return end
    keystoneFrame._miliButtons = true

    ---------------------------------------------------------------------------
    -- 容器面板：錨定在鑰石視窗下方
    ---------------------------------------------------------------------------
    local panel = CreateFrame("Frame", "MiliUI_KeystoneButtonsPanel", keystoneFrame, "BackdropTemplate")
    panel:SetHeight(130)
    panel:SetPoint("TOPLEFT", keystoneFrame, "BOTTOMLEFT", 0, -8)
    panel:SetPoint("TOPRIGHT", keystoneFrame, "BOTTOMRIGHT", 0, -8)
    S.ApplyDarkPanel(panel)

    -- 面板標題：白字（標題是身分不是值）
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(barFont, 11)
    title:SetPoint("TOP", panel, "TOP", 0, -6)
    title:SetTextColor(unpack(S.Dark.text))
    title:SetText("MiliUI")

    ---------------------------------------------------------------------------
    -- 自定義按鈕工廠
    --
    -- `S.ApplyDarkButton` 自己會建（或重用）`btn._miliText`、設好白字、並掛上
    -- hover 的 OnEnter/OnLeave（只掛第一次，見 Style.lua 的註解）。
    -- 呼叫端沿用 `btn.label` 這個名字，所以把回傳的 fontstring 接過來。
    ---------------------------------------------------------------------------
    local function CreateStyledButton(parent, width, height)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn.label = S.ApplyDarkButton(btn, nil, { width, height }, 13)
        btn:EnableMouse(true)
        return btn
    end

    ---------------------------------------------------------------------------
    -- 1. 準備確認按鈕
    ---------------------------------------------------------------------------
    local readyBtn = CreateStyledButton(panel, 150, 30)
    readyBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -26)
    readyBtn.label:SetText("準備確認")

    readyBtn:SetScript("OnClick", function()
        DoReadyCheck()
    end)

    ---------------------------------------------------------------------------
    -- 2. 倒數按鈕
    ---------------------------------------------------------------------------
    local countdownBtn = CreateStyledButton(panel, 150, 30)
    countdownBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -26)
    countdownBtn.label:SetText("開始倒數")

    ---------------------------------------------------------------------------
    -- 秒數滑桿（使用內建 OptionsSliderTemplate）
    ---------------------------------------------------------------------------
    local slider = CreateFrame("Slider", "MiliUI_CountdownSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("LEFT", panel, "LEFT", 20, 0)
    slider:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    slider:SetPoint("TOP", countdownBtn, "BOTTOM", 0, -22)
    slider:SetMinMaxValues(3, 30)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(DEFAULT_COUNTDOWN)

    -- 美化內建文字元素
    slider.Low:SetText("3秒")
    slider.High:SetText("30秒")
    slider.Text:SetFont(barFont, 12)
    slider.Text:SetTextColor(unpack(S.Dark.textDim))
    slider.Text:SetText(DEFAULT_COUNTDOWN .. " 秒")

    slider:SetScript("OnValueChanged", function(self, value)
        local sec = math.floor(value)
        self.Text:SetText(sec .. " 秒")
    end)

    ---------------------------------------------------------------------------
    -- 倒數控制邏輯
    ---------------------------------------------------------------------------
    -- ⚠ 底色與邊框**不再跟著狀態換**：那是 hover 在用的兩階明暗（S.Dark 的
    --   fill / fillHover ＋ 職業色邊），倒數中再塞一組紅底紅邊進去，同一顆按鈕
    --   就有兩套互相打架的狀態語彙。「正在倒數」改成只由**文字**說
    --   （「停止倒數」＋紅字）—— 紅色在這裡是值（會中斷別人的倒數），不是裝飾。
    local function SetCountdownActive(active)
        isCountingDown = active
        if active then
            countdownBtn.label:SetText("停止倒數")
            countdownBtn.label:SetTextColor(1, 0.3, 0.3, 1)
            slider:EnableMouse(false)
            slider:SetAlpha(0.4)
        else
            countdownBtn.label:SetText("開始倒數")
            countdownBtn.label:SetTextColor(unpack(S.Dark.text))
            slider:EnableMouse(true)
            slider:SetAlpha(1)
            if countdownTimer then
                countdownTimer:Cancel()
                countdownTimer = nil
            end
        end
    end

    countdownBtn:SetScript("OnClick", function()
        if isCountingDown then
            -- 停止倒數
            C_PartyInfo.DoCountdown(0)
            SetCountdownActive(false)
        else
            -- 開始倒數
            local sec = math.floor(slider:GetValue())
            C_PartyInfo.DoCountdown(sec)
            SetCountdownActive(true)

            -- 倒數結束後自動恢復按鈕狀態
            if countdownTimer then countdownTimer:Cancel() end
            countdownTimer = C_Timer.NewTimer(sec + 1, function()
                SetCountdownActive(false)
            end)
        end
    end)

    ---------------------------------------------------------------------------
    -- 面板跟隨鑰石視窗顯示/隱藏
    ---------------------------------------------------------------------------
    keystoneFrame:HookScript("OnShow", function()
        SetCountdownActive(false)
        panel:Show()
    end)
    keystoneFrame:HookScript("OnHide", function()
        SetCountdownActive(false)
        panel:Hide()
    end)

    -- 初始同步
    if keystoneFrame:IsShown() then
        panel:Show()
    else
        panel:Hide()
    end
end

--------------------------------------------------------------------------------
-- 載入：等待 Blizzard_ChallengesUI LoD 載入
--------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Blizzard_ChallengesUI" then
        if ChallengesKeystoneFrame then
            ChallengesKeystoneFrame:HookScript("OnShow", function()
                SetupKeystoneButtons(ChallengesKeystoneFrame)
            end)
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- 如果已經載入
if C_AddOns.IsAddOnLoaded("Blizzard_ChallengesUI") and ChallengesKeystoneFrame then
    ChallengesKeystoneFrame:HookScript("OnShow", function()
        SetupKeystoneButtons(ChallengesKeystoneFrame)
    end)
    frame:UnregisterEvent("ADDON_LOADED")
end
