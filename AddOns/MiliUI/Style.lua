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

local _, ns = ...

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
------------------------------------------------------------
-- 兩支 Apply*Button 共用的兩件小事
--
-- ⚠⚠ **這兩支必須是冪等的**（同一個框套第二次不能長出第二層東西）。
--   1. FontString 存在就重用 —— WoW 的 frame 與 region **刪不掉**，每呼叫一次就
--      新建一個等於永久洩漏一層文字，而且兩層疊在一起會糊掉
--      （見 .claude/notes/wow-frame-lifecycle-costs.md）。
--   2. hover 腳本**只設第一次**。呼叫端常常會在套完樣式之後再 HookScript 疊自己的行為，
--      而 `HookScript` 是把兩支包成一個 wrapper 掛上去 —— 再 `SetScript` 一次就把
--      整條鏈（原本的＋掛上去的）一起洗掉，而且是靜默的
--      （見 .claude/notes/wow-setscript-clobbers-hookscript.md）。
--      所以第二次呼叫只更新外觀，腳本一律不碰。
--      兩個呼叫點的註解本來都寫著「⚠ 一定要在 ApplyDarkButton 之後才 Hook」——
--      那是把陷阱寫進文件而不是拆掉它，現在順序反過來也不會壞。
------------------------------------------------------------
local function EnsureText(frame, fontSize, outline)
    local fs = frame._miliText
    if not fs then
        fs = frame:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", 0, 0)
        frame._miliText = fs
    end
    fs:SetFont(S.Font, fontSize, outline)
    return fs
end

local function GoldEnter(self)
    self:SetBackdropColor(unpack(S.Colors.bgHover))
    self:SetBackdropBorderColor(unpack(S.Colors.borderHover))
end

local function GoldLeave(self)
    self:SetBackdropColor(unpack(S.Colors.bg))
    self:SetBackdropBorderColor(unpack(S.Colors.border))
end

function S.ApplyButton(frame, text, size, fontSize)
    if not frame then return end
    if size then frame:SetSize(size[1], size[2]) end

    frame:SetBackdrop(S.Backdrop)
    frame:SetBackdropColor(unpack(S.Colors.bg))
    frame:SetBackdropBorderColor(unpack(S.Colors.border))

    local fs = EnsureText(frame, fontSize or 11, "OUTLINE")
    fs:SetTextColor(unpack(S.Colors.text))
    if text then fs:SetText(text) end

    if not frame._miliHoverHooked then
        frame._miliHoverHooked = true
        frame:SetScript("OnEnter", GoldEnter)
        frame:SetScript("OnLeave", GoldLeave)
    end

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

------------------------------------------------------------
-- 深色皮：對齊 MiliUI_UnitFrames 設定介面的外觀
--
-- 白貼圖 backdrop、1px 純黑硬邊、白字、hover 走職業色。數值是從
-- MiliUI_UnitFrames/Libs/MiliUIWidgets/Widgets.lua 抄過來的，那邊改了這邊要跟。
--
-- 跟上面那組 ApplyButton（暗夜藍＋暗金邊）是**兩套並存**的皮，不是要取代它 ——
-- ESC 選單那顆按鈕還吃暗金那套，就地改掉會把它一起換色。
------------------------------------------------------------
S.Dark = {
    panel     = { 0.1, 0.1, 0.1, 0.97 },     -- 選單／面板底
    fill      = { 0.115, 0.115, 0.115, 1 },  -- 控件底
    fillHover = { 0.23, 0.23, 0.23, 1 },
    border    = { 0, 0, 0, 1 },
    text      = { 1, 1, 1, 1 },
    textDim   = { 0.8, 0.8, 0.8, 1 },
}

------------------------------------------------------------
-- HUD 皮：**常駐在遊戲畫面上**的東西共用的一套外觀
--
-- 一句話：黑色半透明底 ＋ 1px 職業色硬邊 ＋ 白字 ＋ 直角。
--
-- 這是套組第三套皮，跟上面兩套的判準只有一句：
--
--   這個東西的背後會不會有地形在動？
--     會 → HUD 皮（半透明底、職業色邊，讓它「浮」在世界之上）
--     不會 → S.Dark（不透明底、純黑邊，讓它像一個獨立視窗）
--
--   小地圖、資訊列、傷害統計視窗、單位框都是前者；
--   設定面板、選單、彈窗、ESC 選單那顆按鈕是後者。
--
-- ⚠ 這裡准許半透明，跟 `miliui-color-states` 技能的「底色要不透明」不衝突 ——
--   那條規則管的是**帶身分色的小元件**（一排標籤、一排按鈕），它們的底色本身在
--   傳達「這是誰」，飄了就讀不出來。HUD 面板的底色不傳達任何資訊，它只是
--   「把世界壓暗好讓白字讀得出來」的一層紗。身分色在 HUD 這裡由**邊框**承擔，
--   跟那條規則的第二點（底色壓暗、邊框保飽和）是同一個結論。
--
-- 灰階 0x1A/255 是套組的既有值（MiliUI_DamageMeters 的視窗底、Chattynator 的
-- Dark 皮都是它）。拉成常數而不是各寫各的：兩個框並排時要是**同一個灰**，
-- 各填一個很接近的數字，日後改一邊就會悄悄分岔。
--
-- 完整說明與由來：.claude/notes/project-miliui-hud-skin.md
-- 可執行的獨立版本（給單體發佈的插件複製）：
--   AddOns/MiliUI_Minimap/Core/Style.lua
------------------------------------------------------------
-- 提示框皮的灰階。**唯一真相來源是 `MiliUI_Tooltip` 的 `general.background`**
-- （0.133、alpha 1、白貼圖純色）—— 套組裡任何「彈出來給人讀內容」的表面都用它，
-- 這樣滑鼠提示、滑過去的名單、未來的彈出面板才會是同一個底。
--
-- ⚠ 它比 HUD 面板底（0x1A = 0.102）**亮一階**，而且**不透明**，這兩點都是刻意的：
--   面板底色不承載資訊所以可以透、可以更暗；提示底色承載的是「讓字讀得出來」。
-- ⚠ 數字寫死不去讀 MiliUI_Tooltip 的 SavedVariables：插件是單體發佈的，
--   玩家可能只裝其中一支，跨插件讀設定會在對方缺席時退回不一樣的顏色。改要兩邊一起改。
S.TIP_BG = 0.133

function S.ApplyTooltipPanel(frame)
    if not frame then return end
    local px = ns.P and ns.P.Scale(1) or 1
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = px,
    })
    frame:SetBackdropColor(S.TIP_BG, S.TIP_BG, S.TIP_BG, 1)
    frame:SetBackdropBorderColor(S.Accent(1))
    return frame
end

S.HUD = {
    bg       = { 0x1A / 255, 0x1A / 255, 0x1A / 255, 0.80 },  -- 面板底
    bgSolid  = { 0x1A / 255, 0x1A / 255, 0x1A / 255, 1 },     -- 標題列那種實心橫條
    text     = { 1, 1, 1, 1 },
    textDim  = { 0.65, 0.65, 0.65, 1 },
    -- 邊框沒有固定色：它一律是 S.Accent()（玩家職業色）。
    borderAlpha = 1,
    -- 狀態階梯：閒置／滑過／按下只換明暗，色相不動
    stateAlpha  = { idle = 0.55, hover = 1.00, down = 0.80 },
}

-- 套用 HUD 皮到一個框。`opaque` = 用實心底（標題列、需要跟內容區分開的橫條）。
-- ⚠ 邊寬走 P.Scale(1) 而不是寫死 1：UI 縮放不是 1 的時候寫死會畫出 1.3 個實體
--   像素，那條邊會有一側糊掉，而且四條邊糊的方向還不一樣
--   （見 .claude/notes/project-miliui-pixel-snapping.md）。
function S.ApplyHUD(frame, opaque)
    if not frame then return end
    local px = ns.P and ns.P.Scale(1) or 1
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = px,
    })
    frame:SetBackdropColor(unpack(opaque and S.HUD.bgSolid or S.HUD.bg))
    frame:SetBackdropBorderColor(S.Accent(S.HUD.borderAlpha))
    return frame
end

------------------------------------------------------------
-- 強調色 = 玩家職業色
--
-- 懶算＋快取：Style.lua 在 TOC 很前面就載入，那個時間點 UnitClass("player")
-- 不保證有值，載入時就算會拿到灰色而且再也不會更新。
-- （player token 讀職業在 12.1 下不是秘密值，可以放心讀。）
------------------------------------------------------------
local accentR, accentG, accentB
function S.Accent(alpha)
    if not accentR then
        accentR, accentG, accentB = 0.7, 0.7, 0.7
        local _, class = UnitClass("player")
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then accentR, accentG, accentB = c.r, c.g, c.b end
    end
    return accentR, accentG, accentB, alpha or 1
end

------------------------------------------------------------
-- 深色面板（選單框、彈出視窗）
------------------------------------------------------------
function S.ApplyDarkPanel(frame, color)
    if not frame then return end
    frame:SetBackdrop(S.Backdrop)
    frame:SetBackdropColor(unpack(color or S.Dark.panel))
    frame:SetBackdropBorderColor(unpack(S.Dark.border))
end

------------------------------------------------------------
-- 深色按鈕：底色固定，hover 時邊框換成職業色
-- 回傳 fontstring 以便外部後續調整（與 S.ApplyButton 同介面）
------------------------------------------------------------
local function DarkEnter(self)
    self:SetBackdropColor(unpack(S.Dark.fillHover))
    self:SetBackdropBorderColor(S.Accent(1))
end

local function DarkLeave(self)
    self:SetBackdropColor(unpack(S.Dark.fill))
    self:SetBackdropBorderColor(unpack(S.Dark.border))
end

function S.ApplyDarkButton(frame, text, size, fontSize)
    if not frame then return end
    if size then frame:SetSize(size[1], size[2]) end

    frame:SetBackdrop(S.Backdrop)
    frame:SetBackdropColor(unpack(S.Dark.fill))
    frame:SetBackdropBorderColor(unpack(S.Dark.border))

    local fs = EnsureText(frame, fontSize or 12, "")
    fs:SetShadowColor(0, 0, 0)
    fs:SetShadowOffset(1, -1)
    fs:SetTextColor(unpack(S.Dark.text))
    if text then fs:SetText(text) end

    if not frame._miliHoverHooked then
        frame._miliHoverHooked = true
        frame:SetScript("OnEnter", DarkEnter)
        frame:SetScript("OnLeave", DarkLeave)
    end

    return fs
end
