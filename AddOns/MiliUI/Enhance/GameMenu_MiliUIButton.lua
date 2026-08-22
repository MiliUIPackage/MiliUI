------------------------------------------------------------
-- 在 ESC 選單 (GameMenuFrame) 加入「米利UI設定」入口按鈕，
-- 以及右側的「重載介面」圖示按鈕。
-- 風格走 MiliUI.Style 的深色皮（對齊米利單位框架設定介面：黑邊白字、hover 職業色）。
--
-- 設定按鈕：
--   點擊 → 隱藏 ESC 選單、開啟 Blizzard Settings → MiliUI 主分類（原本的行為）
--   滑過 → 往上展開米利UI選單，列出各米利系列插件的設定入口
--          （選單本體與註冊接口在 Menu.lua）
-- 重載按鈕：左鍵跳出確認視窗，右鍵直接 ReloadUI()
------------------------------------------------------------

local AddonName, ns = ...
if AddonName ~= "MiliUI" then return end

local BUTTON_TEXT = "米利UI設定"
local RELOAD_TIP_LEFT  = "左鍵：重新載入"
local RELOAD_TIP_RIGHT = "右鍵：立即重新載入"
local RELOAD_ICON = "Interface\\Buttons\\UI-RefreshButton"

local VERSION_FORMAT     = "米利UI套組：%s"
local VERSION_NEW_FORMAT = "米利UI套組：%s\n發現新版本：%s"

local settingBtn -- 設定按鈕，OnShow 時建立一次
local reloadBtn  -- 重載按鈕，OnShow 時建立一次
local menu       -- 滑過設定按鈕展開的米利UI選單，第一次滑過才建立
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

local function OpenSettings()
    if InCombatLockdown() then
        print("|cff00ff00[MiliUI]|r 戰鬥中無法開啟。")
        return
    end
    HideUIPanel(GameMenuFrame)
    -- 開自製設定視窗（Options/Panel.lua），不再繞暴雪 Settings 面板
    ns.OpenOptions()
end

local function DoReload(_, button)
    HideUIPanel(GameMenuFrame)
    if button == "RightButton" then
        ReloadUI()  -- 右鍵不問，直接重載
    else
        StaticPopup_Show("MILIUI_GAMEMENU_RELOAD")
    end
end

------------------------------------------------------------
-- 米利UI選單（滑過設定按鈕往上展開）
-- 項目由各米利系列插件自己註冊，清單與接口見 MiliUI/Menu.lua。
-- 沒有任何插件註冊時 OpenAt 會自己判空不開，這裡不必先檢查。
------------------------------------------------------------
local function EnsureMenu()
    if menu then return menu end
    if not (MiliUI and MiliUI.Menu and MiliUI.Menu.Create) then return nil end
    if not GameMenuFrame then return nil end

    menu = MiliUI.Menu.Create(GameMenuFrame, function()
        -- 開設定面板要先收掉 ESC 選單，但那是暴雪的面板系統管的框，
        -- 戰鬥中動它會惹麻煩 —— 跟設定按鈕本身同一套判斷。
        if InCombatLockdown() then
            print("|cff00ff00[MiliUI]|r 戰鬥中無法開啟。")
            return false
        end
        HideUIPanel(GameMenuFrame)
    end)
    -- 選單會長到 GameMenuFrame 的框外，level 要壓過設定按鈕（+10）
    menu:SetFrameStrata(GameMenuFrame:GetFrameStrata())
    menu:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 20)
    return menu
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
    settingBtn:RegisterForClicks("LeftButtonUp")
    settingBtn:SetScript("OnClick", OpenSettings)

    -- ⚠ 一定要在 ApplyDarkButton 之後才 Hook：那支是用 SetScript 掛 hover 變色的，
    -- 順序反過來這個 hook 會被整個蓋掉，而且不報錯。
    settingBtn:HookScript("OnEnter", function(self)
        local m = EnsureMenu()
        if m then m:OpenAt(self) end
    end)

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
