------------------------------------------------------------
-- MiliUI: 星雲之核擲骰確認
--
-- 按下骰裝提示（BonusRollFrame）的骰子鈕之前先問一聲，並順便顯示目前的
-- 拾取專精 —— 手滑點到、或忘了切拾取專精就花掉核心，事後救不回來。
-- 只攔「擲骰」，放棄鈕不動。預設開啟，讀寫於 MiliUI_DB.bonusRollConfirm。
--
-- 出處（12.1 live，Gethe/wow-ui-source）：
--   Blizzard_UIPanels_Game/Mainline/GroupLootFrame.xml  PromptFrame.RollButton
--       OnClick = AcceptSpellConfirmationPrompt(spellID) ＋ SetEnabled(false)
--       （普通按鈕，不是 secure 按鈕；AcceptSpellConfirmationPrompt 不受保護）
--   Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua
--       BonusRollFrame_StartBonusRoll 寫 frame.state = "prompt" / frame.spellID
--
-- 做法：把 RollButton 的 OnClick 包一層，開啟時先跳確認框，按確定才呼叫原本的
-- OnClick（整段照原樣跑，包括停用按鈕）。確認框自己畫，**不走 StaticPopup** ——
-- 從插件 Lua 開 StaticPopup 會把共用的彈窗框寫髒，首領剛倒時暴雪自己的彈窗
-- （拾取綁定確認之類）就得背這個污染。
-- 按確定時再核一次提示還在、而且還是同一個 spellID，逾時或換了一次提示就不送。
------------------------------------------------------------
local _, ns = ...

local DEFAULTS = {
    enabled = true,
}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local db = MiliUI_DB.bonusRollConfirm
    if not db then
        db = {}
        MiliUI_DB.bonusRollConfirm = db
    end
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    return db
end

-- 骰到的裝備依拾取專精決定；沒指定就是目前專精
local function LootSpecText()
    local specID = GetLootSpecialization and GetLootSpecialization()
    if specID and specID > 0 then
        local _, name = GetSpecializationInfoByID(specID)
        if name then return name end
    else
        local index = GetSpecialization and GetSpecialization()
        if index then
            local _, name = GetSpecializationInfo(index)
            if name then return name .. "（目前專精）" end
        end
    end
    return UNKNOWN
end

local popup, pending

local function BuildPopup()
    local W = ns.W
    local width = 260
    -- 高度在 ShowConfirm 依字高重算；字型大小跟著套組字型走，寫死會跟按鈕疊在一起
    popup = W.CreateFrame(nil, UIParent, width, 84)
    W.CloseOnEscape(popup)
    -- 貪需視窗（GroupLootFrameTemplate）與骰裝框都是 DIALOG ＋ toplevel，
    -- 在 GroupLootContainer 裡往上疊，正好疊在確認框錨的位置；同層會被
    -- toplevel 的點擊抬升蓋過去，所以要高一層
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetBackdropBorderColor(W.Accent(1))

    local fs = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOP", 0, -14)
    fs:SetWidth(width - 24)
    fs:SetJustifyH("CENTER")
    popup.text = fs

    local yes = W.CreateButton(popup, "擲骰", "primary", 80, 22)
    yes:SetPoint("BOTTOMLEFT", 26, 12)
    yes:SetScript("OnClick", function()
        local p = pending
        popup:Hide()
        if not p then return end
        -- 確認框開著的時候提示可能已經逾時、或換成下一個首領的提示
        if BonusRollFrame.state ~= "prompt" or BonusRollFrame.spellID ~= p.spellID
            or not p.button:IsEnabled() then
            return
        end
        p.onClick(p.button, "LeftButton", false)
    end)

    local no = W.CreateButton(popup, CANCEL, "normal", 80, 22)
    no:SetPoint("BOTTOMRIGHT", -26, 12)
    no:SetScript("OnClick", function() popup:Hide() end)

    popup:SetScript("OnHide", function() pending = nil end)
    popup:Hide()
end

local function ShowConfirm(button, onClick)
    if not popup then BuildPopup() end
    pending = { button = button, onClick = onClick, spellID = BonusRollFrame.spellID }
    popup.text:SetFormattedText("確定要使用星雲之核擲骰嗎？\n\n拾取專精：|cffffd200%s|r", LootSpecText())
    -- 上緣 14 ＋ 字 ＋ 間距 14 ＋ 按鈕 22 ＋ 下緣 12
    popup:SetHeight(math.ceil(popup.text:GetStringHeight()) + 62)
    popup:ClearAllPoints()
    popup:SetPoint("BOTTOM", BonusRollFrame, "TOP", 0, 8)
    popup:Show()
end

local function Hook()
    local prompt = BonusRollFrame and BonusRollFrame.PromptFrame
    local btn = prompt and prompt.RollButton
    if not btn then return end
    local orig = btn:GetScript("OnClick")
    if not orig then return end

    btn:SetScript("OnClick", function(self, mouseButton, down)
        if not GetDB().enabled then
            return orig(self, mouseButton, down)
        end
        ShowConfirm(self, orig)
    end)

    -- 提示收掉（逾時、開骰、被過濾）時確認框跟著關
    prompt:HookScript("OnHide", function()
        if popup then popup:Hide() end
    end)
end

Hook()

------------------------------------------------------------
-- 對外 API（給 Options/Tab_QoL.lua 用）
------------------------------------------------------------
MiliUI_BonusRollConfirm = {
    IsEnabled  = function() return GetDB().enabled and true or false end,
    SetEnabled = function(v)
        GetDB().enabled = v and true or false
        if not v and popup then popup:Hide() end
    end,
}
