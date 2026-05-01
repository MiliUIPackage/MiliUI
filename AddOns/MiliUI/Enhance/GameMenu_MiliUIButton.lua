------------------------------------------------------------
-- 在 ESC 選單 (GameMenuFrame) 加入「米利UI設定」入口按鈕。
-- 風格沿用 MiliUI.Style.ApplyButton（暗夜藍底 + 暗金邊 + 金色字）。
--
-- 點擊後：
--   1. 隱藏 ESC 選單（避免擋住設定面板）
--   2. 開啟 Blizzard Settings → MiliUI 主分類
------------------------------------------------------------

local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

local BUTTON_TEXT = "米利UI設定"

local btn  -- 唯一按鈕，OnShow 時建立一次

local function OpenSettings()
    if InCombatLockdown() then
        print("|cff00ff00[MiliUI]|r 戰鬥中無法開啟。")
        return
    end
    HideUIPanel(GameMenuFrame)
    local cat = MiliUI and MiliUI.SettingsCategory
    if cat and Settings and Settings.OpenToCategory then
        -- Blizzard 12.0+: OpenToCategory 收 numeric ID (C_SettingsUtil.OpenSettingsPanel)
        local id = cat.GetID and cat:GetID() or cat.ID
        if type(id) == "number" then
            Settings.OpenToCategory(id)
        else
            Settings.OpenToCategory(cat)  -- 退回傳物件
        end
    end
end


local function EnsureButton()
    if btn then return btn end
    if not GameMenuFrame then return nil end

    btn = CreateFrame("Button", "MiliUI_GameMenuButton", GameMenuFrame, "BackdropTemplate")
    if MiliUI and MiliUI.Style and MiliUI.Style.ApplyButton then
        MiliUI.Style.ApplyButton(btn, BUTTON_TEXT, nil, 12)
    else
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER")
        fs:SetText(BUTTON_TEXT)
    end

    -- 與 GameMenuFrame 同 strata，level 高一階確保在前景接得到滑鼠
    btn:SetFrameStrata(GameMenuFrame:GetFrameStrata())
    btn:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 10)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", OpenSettings)
    return btn
end

local function PositionButton()
    if not btn or not GameMenuFrame then return end
    btn:ClearAllPoints()
    -- 放在 GameMenuFrame 標題列右上外側（與「遊戲選項」標題同高度）
    btn:SetSize(110, 24)
    btn:SetPoint("BOTTOMRIGHT", GameMenuFrame, "TOPRIGHT", -10, 13)
end

GameMenuFrame:HookScript("OnShow", function()
    EnsureButton()
    PositionButton()
    if btn then btn:Show() end
end)
