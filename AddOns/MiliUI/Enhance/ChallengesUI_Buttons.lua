--------------------------------------------------------------------------------
-- ChallengesUI_Buttons
-- 在 M+ 鑰石放置介面 (ChallengesKeystoneFrame) 加入：
--   1. 準備確認按鈕 — DoReadyCheck()
--   2. 倒數按鈕 + 秒數滑桿 — C_PartyInfo.DoCountdown(n)
--      倒數進行中按鈕變成「停止倒數」，可隨時取消
--
-- 設計風格：深色半透明面板 + 金色邊框 + 圓角按鈕，與 M+ 介面融合
--------------------------------------------------------------------------------

-- Locale-aware font
local barFont
if LOCALE_koKR then
    barFont = "Fonts\\2002.TTF"
elseif LOCALE_zhCN then
    barFont = "Fonts\\ARKai_T.ttf"
elseif LOCALE_zhTW then
    barFont = "Fonts\\blei00d.TTF"
else
    barFont = "Fonts\\FRIZQT__.TTF"
end

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
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.08, 0.08, 0.12, 0.9)
    panel:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.8) -- 金色邊框

    -- 面板標題
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(barFont, 11, "OUTLINE")
    title:SetPoint("TOP", panel, "TOP", 0, -6)
    title:SetTextColor(1, 0.84, 0, 1)
    title:SetText("MiliUI")

    ---------------------------------------------------------------------------
    -- 自定義按鈕工廠
    ---------------------------------------------------------------------------
    local function CreateStyledButton(parent, width, height)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(width, height)

        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.15, 0.15, 0.22, 1)
        btn:SetBackdropBorderColor(0.45, 0.40, 0.20, 1)

        -- 文字
        local text = btn:CreateFontString(nil, "OVERLAY")
        text:SetFont(barFont, 13, "OUTLINE")
        text:SetPoint("CENTER", 0, 0)
        text:SetTextColor(1, 0.84, 0, 1)
        btn.label = text

        -- Hover 效果
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.25, 0.25, 0.35, 1)
            self:SetBackdropBorderColor(0.8, 0.7, 0.3, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            if self._activeState then
                self:SetBackdropColor(0.35, 0.12, 0.12, 1)
                self:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
            else
                self:SetBackdropColor(0.15, 0.15, 0.22, 1)
                self:SetBackdropBorderColor(0.45, 0.40, 0.20, 1)
            end
        end)

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
    slider.Text:SetFont(barFont, 12, "OUTLINE")
    slider.Text:SetTextColor(0.8, 0.8, 0.8, 1)
    slider.Text:SetText(DEFAULT_COUNTDOWN .. " 秒")

    slider:SetScript("OnValueChanged", function(self, value)
        local sec = math.floor(value)
        self.Text:SetText(sec .. " 秒")
    end)

    ---------------------------------------------------------------------------
    -- 倒數控制邏輯
    ---------------------------------------------------------------------------
    local function SetCountdownActive(active)
        isCountingDown = active
        countdownBtn._activeState = active
        if active then
            countdownBtn.label:SetText("停止倒數")
            countdownBtn.label:SetTextColor(1, 0.3, 0.3, 1)
            countdownBtn:SetBackdropColor(0.35, 0.12, 0.12, 1)
            countdownBtn:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
            slider:EnableMouse(false)
            slider:SetAlpha(0.4)
        else
            countdownBtn.label:SetText("開始倒數")
            countdownBtn.label:SetTextColor(1, 0.84, 0, 1)
            countdownBtn:SetBackdropColor(0.15, 0.15, 0.22, 1)
            countdownBtn:SetBackdropBorderColor(0.45, 0.40, 0.20, 1)
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
