------------------------------------------------------------
-- MiliUI 共用視覺風格
-- 從 ChallengesUI_LootTable 的「掉落對照表」按鈕抽出，
-- 供其他 MiliUI 元件沿用一致的外觀。
--
-- 主要色票：
--   底色   = (0.15, 0.15, 0.22, 0.9)    暗夜藍
--   邊框   = (0.6, 0.5, 0.25, 0.8)      暗金
--   文字   = (1, 0.84, 0, 1)            金色
--   Hover  = 底色加亮、邊框加深、文字保持金色
------------------------------------------------------------

local _, _ = ...

MiliUI = MiliUI or {}
MiliUI.Style = MiliUI.Style or {}
local S = MiliUI.Style

-- 在地化字體（與 LootTable 一致）
local function GetLocaleFont()
    if LOCALE_koKR then return "Fonts\\2002.TTF" end
    if LOCALE_zhCN then return "Fonts\\ARKai_T.ttf" end
    if LOCALE_zhTW then return "Fonts\\blei00d.TTF" end
    return "Fonts\\FRIZQT__.TTF"
end
S.Font = GetLocaleFont()

-- 色票常數
S.Colors = {
    bg            = { 0.15, 0.15, 0.22, 0.9 },
    bgHover       = { 0.25, 0.25, 0.35, 1 },
    border        = { 0.6, 0.5, 0.25, 0.8 },
    borderHover   = { 0.8, 0.7, 0.3, 1 },
    text          = { 1, 0.84, 0, 1 },
    textDisabled  = { 0.4, 0.4, 0.4, 1 },
    headerGold    = { 1, 0.84, 0, 1 },
    panelBg       = { 0.06, 0.06, 0.10, 0.92 },
}

-- 標準 backdrop 表
S.Backdrop = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

------------------------------------------------------------
-- 套用按鈕風格至既有 Frame/Button
-- frame  : 已 CreateFrame("Button", ..., parent, "BackdropTemplate") 的物件
-- text   : 顯示文字
-- size   : 可選 {width, height}，省略沿用既有大小
-- fontSize: 可選字體大小，預設 11
-- 回傳 fontstring 物件以便外部後續調整
------------------------------------------------------------
function S.ApplyButton(frame, text, size, fontSize)
    if not frame then return end
    if size then frame:SetSize(size[1], size[2]) end

    frame:SetBackdrop(S.Backdrop)
    frame:SetBackdropColor(unpack(S.Colors.bg))
    frame:SetBackdropBorderColor(unpack(S.Colors.border))

    local fs = frame:CreateFontString(nil, "OVERLAY")
    fs:SetFont(S.Font, fontSize or 11, "OUTLINE")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetTextColor(unpack(S.Colors.text))
    if text then fs:SetText(text) end
    frame._miliText = fs

    frame:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(S.Colors.bgHover))
        self:SetBackdropBorderColor(unpack(S.Colors.borderHover))
    end)
    frame:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(S.Colors.bg))
        self:SetBackdropBorderColor(unpack(S.Colors.border))
    end)

    return fs
end

------------------------------------------------------------
-- 套用面板風格（如 LootTable 主面板）
------------------------------------------------------------
function S.ApplyPanel(frame)
    if not frame then return end
    frame:SetBackdrop(S.Backdrop)
    frame:SetBackdropColor(unpack(S.Colors.panelBg))
    frame:SetBackdropBorderColor(unpack(S.Colors.border))
end
