------------------------------------------------------------
-- 在 ESC 選單 (GameMenuFrame) 加入「米利UI設定」入口按鈕，
-- 以及右側的「重載介面」圖示按鈕。
-- 風格走 MiliUI.Style 的深色皮（對齊米利單位框架設定介面：黑邊白字、hover 職業色）。
--
-- 設定按鈕：
--   點擊 → 隱藏 ESC 選單、開主設定視窗的「快速設定」分頁（Options/QuickPanel.lua：
--          分組標籤＋三欄卡片，點卡片直接開那支插件的設定、卡片底部開關插件）
--   原本右鍵開「插件總覽」分頁，2026-11-28 那一頁併進快速設定後左右鍵都一樣。
--   原本滑過會往上展開一整排插件名的選單，同一天拿掉了。
-- 重載按鈕：左鍵跳出確認視窗，右鍵直接 ReloadUI()
------------------------------------------------------------

local AddonName, ns = ...
if AddonName ~= "MiliUI" then return end

local BUTTON_TEXT = "米利UI設定"
local SETTING_TIP = "開啟快速設定：調整各插件、啟用或停用"
local RELOAD_TIP_LEFT  = "重新載入"
local RELOAD_TIP_RIGHT = "右鍵：立即重新載入"
local RELOAD_ICON = "Interface\\Buttons\\UI-RefreshButton"

local VERSION_FORMAT     = "米利UI套組：%s"
local VERSION_NEW_FORMAT = "米利UI套組：%s\n發現新版本：%s"

local settingBtn -- 設定按鈕，OnShow 時建立一次
local reloadBtn  -- 重載按鈕，OnShow 時建立一次
local versionText -- 右下角版本標籤，OnShow 時建立一次

StaticPopupDialogs["MILIUI_GAMEMENU_RELOAD"] = {
    text = "確定要重新載入介面嗎？",
    button1 = YES,
    button2 = NO,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function OpenSettings(_, button)
    -- 收 ESC 選單是動暴雪面板系統管的框，戰鬥中不碰
    if InCombatLockdown() then
        print("|cff00ff00[MiliUI]|r 戰鬥中無法開啟。")
        return
    end
    HideUIPanel(GameMenuFrame)
    ns.OpenOptions("quick")
end

local function DoReload(_, button)
    if button == "RightButton" then
        -- 右鍵不問，直接重載。
        -- ⚠ 這裡**不要**先 HideUIPanel：反正整個介面要重來，收選單是多餘的；
        --   而永恆實機（2026-11-14 taint.log）這條路徑的 C_UI.Reload() 被擋
        --   （「An action was blocked because of taint from MiliUI - Reload()」），
        --   正式服同一段程式沒事。永恆版 GameMenuFrame 收起來時多跑一段手把／焦點
        --   轉場（InputUtil.RegisterForInterfaceTransitions），先把它從點擊路徑上拿掉。
        ReloadUI()
    else
        HideUIPanel(GameMenuFrame)
        StaticPopup_Show("MILIUI_GAMEMENU_RELOAD")
    end
end

local function EnsureButton()
    if settingBtn then return settingBtn end
    if not GameMenuFrame then return nil end

    settingBtn = CreateFrame("Button", "MiliUI_GameMenuButton", GameMenuFrame, "BackdropTemplate")
    if MiliUI and MiliUI.Style and MiliUI.Style.ApplyDarkButton then
        MiliUI.Style.ApplyDarkButton(settingBtn, BUTTON_TEXT, nil, 12)
    else
        local fs = settingBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER")
        fs:SetText(BUTTON_TEXT)
    end

    -- 與 GameMenuFrame 同 strata，level 高一階確保在前景接得到滑鼠
    settingBtn:SetFrameStrata(GameMenuFrame:GetFrameStrata())
    settingBtn:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 10)
    settingBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    settingBtn:SetScript("OnClick", OpenSettings)

    -- ⚠ 一定要在 ApplyDarkButton 之後才 Hook：那支是用 SetScript 掛 hover 變色的，
    -- 順序反過來這個 hook 會被整個蓋掉，而且不報錯。
    settingBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(SETTING_TIP, 1, 0.84, 0)
        GameTooltip:Show()
    end)
    settingBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    return settingBtn
end

local function EnsureReloadButton()
    if reloadBtn then return reloadBtn end
    if not GameMenuFrame then return nil end

    reloadBtn = CreateFrame("Button", "MiliUI_GameMenuReloadButton", GameMenuFrame, "BackdropTemplate")
    if MiliUI and MiliUI.Style and MiliUI.Style.ApplyDarkButton then
        -- 純圖示按鈕，不帶文字，其餘外觀與設定按鈕一致
        MiliUI.Style.ApplyDarkButton(reloadBtn, nil, nil, 12)
    end

    local icon = reloadBtn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(RELOAD_ICON)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetSize(14, 14)
    -- 與按鈕文字同一組白
    local c = MiliUI and MiliUI.Style and MiliUI.Style.Dark and MiliUI.Style.Dark.text
    if c then icon:SetVertexColor(c[1], c[2], c[3]) end
    reloadBtn._miliIcon = icon

    reloadBtn:SetFrameStrata(GameMenuFrame:GetFrameStrata())
    reloadBtn:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 10)
    reloadBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    reloadBtn:SetScript("OnClick", DoReload)

    -- ApplyButton 已用 SetScript 掛上 hover 變色，這裡再 Hook 疊加 tooltip
    reloadBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(RELOAD_TIP_LEFT, 1, 0.84, 0)
        GameTooltip:AddLine(RELOAD_TIP_RIGHT, 1, 0.84, 0)
        GameTooltip:Show()
    end)
    reloadBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    return reloadBtn
end

-- 右下角版本標籤：白字 + 1px 黑框
local function EnsureVersionText()
    if versionText then return versionText end
    if not GameMenuFrame then return nil end

    -- 掛在自己的 Frame 上而不是直接 CreateFontString 到 GameMenuFrame，
    -- 這樣才能把 level 拉高，不會被選單背景蓋掉。
    local holder = CreateFrame("Frame", nil, GameMenuFrame)
    holder:SetFrameStrata(GameMenuFrame:GetFrameStrata())
    holder:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 10)
    holder:SetSize(1, 1)
    holder:SetPoint("TOPRIGHT", GameMenuFrame, "BOTTOMRIGHT", 0, -6)

    versionText = holder:CreateFontString(nil, "OVERLAY")
    local font = MiliUI and MiliUI.Style and MiliUI.Style.Font or "Fonts\\FRIZQT__.TTF"
    versionText:SetFont(font, 12, "OUTLINE")
    versionText:SetTextColor(1, 1, 1, 1)
    versionText:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    versionText:SetJustifyH("RIGHT")
    versionText:SetJustifyV("TOP")
    versionText:SetSpacing(2)  -- 兩行時的行距

    return versionText
end

local function UpdateVersionText()
    if not versionText then return end
    local V = MiliUI and MiliUI.Version
    if not V then
        versionText:Hide()
        return
    end
    if V.newestText then
        versionText:SetFormattedText(VERSION_NEW_FORMAT, V.myText, V.newestText)
    else
        versionText:SetFormattedText(VERSION_FORMAT, V.myText)
    end
    versionText:Show()
end

local function PositionButton()
    if not settingBtn or not GameMenuFrame then return end
    -- 重載按鈕貼齊 GameMenuFrame 標題列右上外側，設定按鈕接在它左邊
    settingBtn:ClearAllPoints()
    settingBtn:SetSize(110, 24)

    if reloadBtn then
        reloadBtn:ClearAllPoints()
        reloadBtn:SetSize(24, 24)
        reloadBtn:SetPoint("BOTTOMRIGHT", GameMenuFrame, "TOPRIGHT", -10, 13)
        settingBtn:SetPoint("BOTTOMRIGHT", reloadBtn, "BOTTOMLEFT", -4, 0)
    else
        settingBtn:SetPoint("BOTTOMRIGHT", GameMenuFrame, "TOPRIGHT", -10, 13)
    end
end

GameMenuFrame:HookScript("OnShow", function()
    EnsureButton()
    EnsureReloadButton()
    EnsureVersionText()
    PositionButton()
    -- 每次開選單都重讀，這樣同一場 session 中途才收到的新版本也會反映出來
    UpdateVersionText()
    if settingBtn then settingBtn:Show() end
    if reloadBtn then reloadBtn:Show() end
end)
