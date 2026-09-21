local addonName, ns = ...

-- Localization
local L = LibStub("AceLocale-3.0"):GetLocale("MiliUI_ChatBar")
ns.L = L

ns.VERSION      = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
ns.PREFIX_COLOR = "|cffFF9999"


-- 設定分頁的 callback 派送用（Libs/Callbacks.lua 的 xpcall 處理器）。
-- 訂閱者之間不能連坐，但也不能變成黑洞——照常轉給全域 errorhandler。
function ns.ReportError(err)
    local handler = geterrorhandler()
    if handler then handler(err) end
end

-- Configuration
local width, height, padding = 25, 8, 5
local texture = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------
-- 套組標準底色
--
-- Chattynator 的暗色 skin：`skins.dark.chat_transparency = 0.2` → alpha 0.8。
-- 聊天列就貼在聊天視窗下面，跟統計視窗、資訊列並排時全部必須是**同一個灰**，
-- 各填一個很接近的數字日後會悄悄分岔。
-- 改這個值的時候記得同步 MiliUI_DamageMeters/Core/DB.lua 與
-- MiliUI_InfoBar/Config.lua 的同名常數。
--
-- 這個值沒有進 SavedVariables（一直都是寫死的），所以不需要遷移：
-- 舊玩家 /reload 之後直接就是新的顏色。
--
-- ⚠ 宣告位置要在 CreateSD 之前：Lua 的區域變數只對「宣告之後」的程式碼可見，
--   放在檔案後半的話 CreateSD 裡讀到的會是全域 nil。
------------------------------------------------------------
local DARK_BG = 0x1A / 255   -- 0.102
local DARK_BG_ALPHA = 0.8

--------
-- SavedVariables
--------
-- Single source of truth for DB defaults. InitDB is idempotent — every
-- callsite that touches MiliUI_ChatBar_DB should call it first.
local function InitDB()
    MiliUI_ChatBar_DB = MiliUI_ChatBar_DB or {}
    MiliUI_ChatBar_DB.Chatbar = MiliUI_ChatBar_DB.Chatbar or {}
    local cb = MiliUI_ChatBar_DB.Chatbar
    if cb.Hidden            == nil then cb.Hidden            = {}           end
    if cb.CustomColors      == nil then cb.CustomColors      = {}           end
    if cb.Locked            == nil then cb.Locked            = true         end
    if cb.Orientation       == nil then cb.Orientation       = "HORIZONTAL" end
    if cb.DBMPullSeconds    == nil then cb.DBMPullSeconds    = 10           end
    if cb.ButtonWidth       == nil then cb.ButtonWidth       = width        end
    if cb.ButtonHeight      == nil then cb.ButtonHeight      = height       end
    if cb.FontSize          == nil then cb.FontSize          = 9            end
    -- 跟聊天視窗綁在一起：預設開。位置本身存在 cb.Position，由 Anchor.lua 管
    -- （舊玩家的 SetUserPlaced 位置在 Anchor.Init 抄過來，所以這裡不給預設值）
    if cb.GroupWithChat     == nil then cb.GroupWithChat     = true         end

    -- 自適應寬度預設開（舊玩家一起）。原本的按鈕寬度沒有被丟掉，只是先不生效，
    -- 取消勾選就會整條回到原本的樣子。
    if cb.MatchChatWidth    == nil then cb.MatchChatWidth    = true         end
    if cb.AutoButtonWidth   == nil then cb.AutoButtonWidth   = true         end
end

--------
-- Utilities
--------
-- 按鈕底。跟聊天列本身、傷害統計、資訊列同一個灰（見上面的 DARK_BG）。
--
-- 框線刻意設成**全透明**而不是「跟底色同色」：backdrop 的邊是畫在底色**之上**
-- 的，兩層都是 0.8 的話邊緣會疊成 0.96，看起來就是一圈比中間更深的框——
-- 那正是我們不想要的東西。要無框就讓它真的不畫。
local function CreateSD(parent)
    parent:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    parent:SetBackdropColor(DARK_BG, DARK_BG, DARK_BG, DARK_BG_ALPHA)
    parent:SetBackdropBorderColor(0, 0, 0, 0)
end

-- 全部重置：SavedVariables 整張丟掉再重載。SetUserPlaced(false) 一定要在重載前做，
-- 否則暴雪會把「玩家擺過的位置」再寫回去，位置就重置不掉。
-- （確認彈窗在設定視窗那邊，用共用元件庫的樣式）
function ns.ResetAll()
    MiliUI_ChatBar_DB = nil
    if MiliUI_ChatBar then MiliUI_ChatBar:SetUserPlaced(false) end
    ReloadUI()
end

local function PixelIcon(parent, texturePath, isZoome)
    if not parent.Icon then
        parent.Icon = parent:CreateTexture(nil, "ARTWORK")
        parent.Icon:SetAllPoints()
    end
    parent.Icon:SetTexture(texturePath)
    if isZoome then
        parent.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local function HexRGB(r, g, b)
    return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
end

local function ShowButtonTooltip(bu)
    if not bu.tooltipText then return end
    GameTooltip:SetOwner(bu, bu.tooltipAnchor or "ANCHOR_TOP")
    GameTooltip:ClearLines()
    local r, g, b = bu.Icon:GetVertexColor()
    GameTooltip:AddLine(HexRGB(r, g, b)..bu.tooltipText)
    GameTooltip:Show()
end

-- ⚠ 頻道按鈕整面都是超連結，而滑鼠停在連結區上時按鈕收到的是 OnLeave 不是 OnEnter
--   （連結區是引擎另一個滑鼠焦點）。所以這裡的 OnEnter 只管沒被連結蓋到的那一小圈，
--   連結上的提示由 Sink 的 OnHyperlinkEnter 顯示（見 Sink 段），兩邊都走 ShowButtonTooltip。
local function AddTooltip(parent, anchor)
    parent.tooltipAnchor = anchor
    parent:SetScript("OnEnter", ShowButtonTooltip)
    parent:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

--------
-- Chatbar
--------
local Chatbar = CreateFrame("Frame", "MiliUI_ChatBar", UIParent, "BackdropTemplate")
Chatbar:SetSize(width, height)
Chatbar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
Chatbar:SetMovable(true)
-- ⚠ 這裡的 true 是**給舊玩家搬家用的**，不是還在用暴雪存位置。
-- 開著它，暴雪才會在載入時把舊版存下來的位置擺回來，Anchor.Init 才抄得到；
-- 抄完它就會把 UserPlaced 關掉，之後位置全部由 SavedVariables 管。
Chatbar:SetUserPlaced(true)
Chatbar:SetClampedToScreen(true)
-- 放開拖曳：位置與吸附全部交給 Anchor.lua 決定（按住 Shift 放開＝不吸）。
-- 位置不再走 SetUserPlaced，錨在聊天視窗上的位置暴雪存不了。
local function StopDragging()
    Chatbar:StopMovingOrSizing()
    if ns.Anchor then ns.Anchor.OnDragStop() end
end

-- Create a mover/handle
local Mover = CreateFrame("Frame", nil, Chatbar, "BackdropTemplate")
Mover:SetAllPoints()
Mover:SetFrameLevel(Chatbar:GetFrameLevel() + 5)
Mover:EnableMouse(true)
Mover:RegisterForDrag("LeftButton")
Mover:SetScript("OnDragStart", function() Chatbar:StartMoving() end)
Mover:SetScript("OnDragStop", StopDragging)

-- Edit Mode Integration
-- When WoW's Edit Mode is active, allow dragging regardless of lock state
local isInEditMode = false

-- Create Edit Mode selection frame (visual highlight)
local EditModeSelection = CreateFrame("Frame", nil, Chatbar, "EditModeSystemSelectionTemplate")
-- The template's XML binds OnMouseDown -> EditModeManagerFrame:SelectSystem(self.parent).
-- We are not a real Edit Mode system: a click without a drag lets Blizzard run that
-- selection pass tainted by us across EVERY registered system (action bars included).
-- Silent at click time; it surfaces later as blocked action buttons in combat.
EditModeSelection:SetScript("OnMouseDown", function() end)
EditModeSelection:SetAllPoints()
EditModeSelection:Hide()

-- Make EditModeSelection draggable
EditModeSelection:RegisterForDrag("LeftButton")
EditModeSelection:SetScript("OnDragStart", function() Chatbar:StartMoving() end)
EditModeSelection:SetScript("OnDragStop", StopDragging)

-- Add system info for the selection template
EditModeSelection.system = {
    GetSystemName = function()
        return "MiliUI Chatbar"
    end
}

local function UpdateMoverState()
    if isInEditMode then
        -- Always allow dragging in Edit Mode
        Mover:EnableMouse(true)
        EditModeSelection:ShowHighlighted()
    else
        -- Respect lock setting when not in Edit Mode
        local isLocked = MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.Locked
        Mover:EnableMouse(not isLocked)
        EditModeSelection:Hide()
    end
end

-- Hook EditModeManagerFrame if it exists (Retail WoW)
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnShow", function()
        isInEditMode = true
        UpdateMoverState()
    end)
    
    EditModeManagerFrame:HookScript("OnHide", function()
        isInEditMode = false
        UpdateMoverState()
    end)
end

------------------------------------------------------------
-- ⚠⚠ 開聊天輸入框的那一下，執行裡不能有插件的程式碼
--
-- 12.1 之後密語對象的名字可能是秘密字串（跨服、戰網、不在隊伍裡的玩家）。
-- 插件從自己的 OnClick 呼叫 ChatFrame_OpenChat → ActivateChat，暴雪就在**我們的**堆疊上
-- 寫了全域 LAST_ACTIVE_CHAT_EDIT_BOX，那一筆寫入帶著 MiliUI_ChatBar 的污染。之後**任何**
-- 開輸入框的路（按 R 回覆、點名字密語、Enter）都先讀這個全域 → 執行變髒 → 碰到秘密名字
-- 就炸，而暴雪每一條寫回它的路都先讀它，所以髒了就一路髒到 /reload。
-- 在錯誤路徑上做任何降級（鏡射對象、代填 /r、洗輸入框）都只是把炸點往後推。
--
-- 唯一的乾淨路：**讓按鈕變成聊天超連結**。聊天訊息裡的 [隊伍] 標頭本身就是
-- |Hchannel:PARTY|h 超連結，點下去是引擎派送 → ChatFrameTemplate 的 OnHyperlinkClick
--（暴雪的 method）→ SetItemRef → 暴雪的 channel 處理器 → OpenChat("/PARTY")。
-- 整條鏈沒有插件的 Lua，全域保持乾淨。Chattynator 就是這樣做的：它的
-- ChattynatorHyperlinkHandler 是一個 ChatFrameTemplate 框，訊息框用
-- SetHyperlinkPropagateToParent(true) 把點擊往上交 —— 所以在它裡面點名字密語從來不炸。
--
-- 這裡照抄：Sink 是一個 ChatFrameTemplate 框（Sink.xml），每顆按鈕是它的子框、propagate 給它。
-- 點擊區用**真的字**：標籤那個字本身就是連結（可見的字是最保險的點擊區，跟聊天訊息裡的
-- 連結同一種東西），條的部分再放一串空白撐出跟條一樣大的連結。
-- ⚠ 踩過的坑（2026-09-16）：alpha 0 的 FontString 裡放 |T 貼圖當點擊區、Lua 呼叫
--   SetHyperlinksEnabled、按鈕用 SecureActionButtonTemplate —— 三個一起上，結果整條點不動，
--   而且沒有任何錯誤。全部換成 Chattynator 驗證過的寫法之後才動。
--   * 回覆 = |Hchannel:REPLY|h：/REPLY 由暴雪在乾淨執行下解析，秘密名字直接填進去，
--     跟按 R 一模一樣。
--   * 頻道 = |Hchannel:CHANNEL:編號|h，暴雪自己的格式。
--
-- 限制（都來自暴雪的處理器，不是我們選的）：
--   * 只有**左鍵**會開頻道，右鍵是它的頻道選單 —— 所以「右鍵切替代頻道」做不到，
--     喊話／回覆／幹部拆成各自一顆；按鈕的右鍵穿透給底下的條，開我們自己的選單。
--   * chatStyle = "im"（介面設定的「即時通訊風格」）時 ChooseBoxForSend 走
--     `preferredChatFrame:IsShown()` → `return preferredChatFrame.editBox`，**沒有 nil 備援**：
--     Sink 是裸的 ChatFrameTemplate、沒有這個欄位 ⇒ ActivateChat(nil) 在
--     ChatFrameUtil.lua:450 硬錯，整排按鈕全死（玩家回報 2026-09-20）。所以下面補
--     Sink.editBox。這個欄位是我們寫的，im 的玩家讀到它那次執行會髒（R 鍵回秘密名字
--     那條跟著壞到 /reload）—— 這是 im 樣式下唯一的選擇，Chattynator 的
--     HyperlinkHandler 同一寫法。classic（預設）在前一個分支就 return 了，
--     **根本不讀這個欄位**，沒被讀的髒欄位不染任何東西，所以無條件補不傷預設玩家。
--
-- 詳見 .claude/notes/wow-121-chat-reply-secret-taint.md
------------------------------------------------------------
-- 框本身在 Sink.xml（hyperlinksEnabled 要走 XML 屬性）；這裡只把它掛到聊天列底下。
-- 模板預設 hidden；大小無所謂，子框的點擊區不受父框裁切。
local Sink = MiliUI_ChatBar_LinkSink
Sink:SetParent(Chatbar)
Sink:SetPoint("TOPLEFT")
Sink:SetSize(1, 1)
Sink:Show()
-- 模板的 OnLoad 註冊了一整批聊天事件；這顆框只負責收超連結點擊
Sink:UnregisterAllEvents()
Sink:SetScript("OnEvent", nil)
-- im 聊天樣式的備援，見上面「限制」第二點
Sink.editBox = DEFAULT_CHAT_FRAME.editBox
-- 滑鼠停在連結區上時，按鈕自己收到的是 OnLeave 而不是 OnEnter —— 連結區是引擎另一個
-- 滑鼠焦點（暴雪自己的聊天框也因此用游標輪詢管捲軸淡出，不用 OnEnter/OnLeave）。
-- 按鈕整面都是連結，所以提示要從 propagate 的終點這裡顯示：region 是被滑到的 FontString，
-- 它的父框就是按鈕。模板原本的 Enter/Leave 只是廣播 ChatFrame.OnHyperlinkEnter 事件，
-- 不在點擊的路上，換掉沒有污染問題。
Sink:SetScript("OnHyperlinkEnter", function(_, _, _, region)
    local bu = region and region:GetParent()
    if bu then ShowButtonTooltip(bu) end
end)
Sink:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
if Sink.ScrollBar then Sink.ScrollBar:Hide() end
-- ⚠ OnHyperlinkClick 不要碰：那是模板從 ChatFrameMixin 接來的暴雪 method，
--   換成自己的 SetScript 就等於把整條路又拉回插件的堆疊上。

-- /mcb links：把空白換成底線，看得到每顆按鈕的點擊區有沒有蓋住條
local LINK_DEBUG = false

------------------------------------------------------------
-- 超連結按鈕的滑鼠設定：點擊矩形、右鍵穿透
--
-- RenderLink 戰鬥中也會跑 —— 頻道事件（CHANNEL_UI_UPDATE…）不挑時間，UpdateChannelButtons
-- 每次都把每顆頻道按鈕整個重畫一遍。畫字免費，這兩支不是：
--   * SetHitRectInsets 是保護函式，按鈕是保護框的話戰鬥中會被擋。
--   * SetPassThroughButtons 戰鬥中對**任何**框都擋（API 文件標 HasRestrictions）。
-- 頻道清單沒變，點擊矩形就一樣大、穿透也早就設好了，本來就沒有東西要寫 ⇒ 只在真的變了才寫。
-- 真的要變卻剛好寫不了（戰鬥中才加入的頻道要設穿透），就先不寫也不記：脫戰時
-- PLAYER_REGEN_ENABLED → UpdateButtonVisibility → UpdateLayout 會對每顆顯示中的按鈕重跑
-- RenderLink，比對到差異自然補上。戰鬥中新建的按鈕在那之前也還沒排版，不會被點到。
--
-- 骰／開怪／重置沒有超連結、走不到這裡：它們的右鍵各有用途（type2 巨集、戰鬥記錄），不穿透。
------------------------------------------------------------
local function SyncMouseRect(bu, labelH)
    local locked = InCombatLockdown()
    -- 右鍵穿透給底下的條，開聊天列自己的選單（暴雪的處理器右鍵是它的頻道選單）
    if not bu.passThrough and not locked then
        bu:SetPassThroughButtons("RightButton")
        bu.passThrough = true
    end
    local _, _, top = bu:GetHitRectInsets()
    if top ~= -labelH and not (locked and bu:IsProtected()) then
        bu:SetHitRectInsets(0, 0, -labelH, 0)
    end
end

-- 把按鈕上的兩個連結重畫成按鈕現在的樣子。按鈕改大小、標籤改字級都要重畫。
local function RenderLink(bu)
    if not bu.hyperlink then return end

    -- ① 標籤：字本身就是連結。標籤在條的上方、在按鈕矩形外，所以把按鈕的點擊矩形
    --    往上撐到蓋住它 —— 滑鼠事件要先落在按鈕上，按鈕的 FontString 才輪得到比對連結。
    local labelH = 0
    if bu.fs and bu.labelText then
        bu.fs:SetFormattedText("|H%s|h%s|h", bu.hyperlink, bu.labelText)
        labelH = math.ceil(bu.fs:GetStringHeight() + 1)
    end
    SyncMouseRect(bu, labelH)

    -- ② 條：一串空白撐出跟條一樣大的連結。字級＝條的高度（一行的高度就是條的高度），
    --    寬度靠算出一個空白的寬度再除。空白沒有墨水，所以這個 FontString 不必藏。
    local w, h = bu:GetWidth(), bu:GetHeight()
    if w < 1 or h < 1 then return end
    local link = bu.link
    link:SetFont(STANDARD_TEXT_FONT, math.max(6, math.floor(h + 0.5)), "")
    link:SetText("x x")
    local spaced = link:GetStringWidth()
    link:SetText("xx")
    local adv = spaced - link:GetStringWidth()
    local n = (adv and adv > 0) and math.ceil(w / adv) or 1
    link:SetFormattedText("|H%s|h%s|h", bu.hyperlink, string.rep(LINK_DEBUG and "_" or " ", n))
end

function ns.SetLinkDebug(on)
    LINK_DEBUG = on and true or false
    for _, bu in ipairs(ns.buttonList or {}) do
        RenderLink(bu)
        if LINK_DEBUG and bu.hyperlink then
            print(string.format("%s: %s  (%dx%d)", tostring(bu.configKey), bu.hyperlink,
                math.floor(bu:GetWidth() + 0.5), math.floor(bu:GetHeight() + 0.5)))
        end
    end
end

-- 指定按鈕點下去要開的連結（"channel:PARTY"、"channel:CHANNEL:2"、"player:名字"）。
-- 同一顆按鈕的連結會隨狀態換（隊伍→副本、目標換人），所以可以重複呼叫。
-- 右鍵穿透在 RenderLink 裡設（SyncMouseRect），戰鬥中才建的按鈕要等脫戰。
local function SetChannelLink(bu, hyperlink)
    if bu.hyperlink == hyperlink then return end
    bu.hyperlink = hyperlink
    RenderLink(bu)
end

local buttonList = {}

local UpdateLayout
local AddColorKeyButton
local AddRGBButton
local UpdateFontSize
local UpdateButtonSize
local UpdateButtonVisibility

--------
-- Availability
--------
-- 一顆按鈕「現在有沒有意義」由它自己的 isAvailable() 決定：沒隊伍就沒 /p、
-- 沒公會就沒 /g、離開的頻道也算不可用。沒有 isAvailable 的按鈕永遠可用。
-- 這個判斷同時餵給按鈕顯示與 Tab 循環，兩邊不會有落差。
local function IsButtonAvailable(bu)
    if bu.isAvailable then return bu.isAvailable() and true or false end
    return true
end

-- 使用者在設定裡關掉的按鈕永遠不顯示；剩下的再看可用性。
local function IsButtonVisible(bu)
    local hidden = MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.Hidden
    if hidden and hidden[bu.configKey] then return false end
    return IsButtonAvailable(bu)
end

-- 動態頻道是否還在頻道列表裡（UpdateChannelButtons 每次重建）
local channelActive = {}

local function GetButtonWidth()
    return (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.ButtonWidth) or width
end

local function GetButtonHeight()
    return (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.ButtonHeight) or height
end

UpdateFontSize = function()
    local size = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.FontSize) or 9
    for _, btn in ipairs(buttonList) do
        if btn.fs then
            btn.fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
            RenderLink(btn)   -- 標籤高度變了，點擊矩形跟著撐
        end
    end
end

UpdateButtonSize = function()
    local bw = GetButtonWidth()
    local bh = GetButtonHeight()
    for _, btn in ipairs(buttonList) do
        btn:SetSize(bw, bh)
    end
    UpdateLayout()
end

-- 單一入口：按鈕該不該出現，全部走 IsButtonVisible。
-- 骰／開怪／重置是 SecureActionButtonTemplate，戰鬥中不能 Show/Hide，重排也會動到它們
-- 與聊天列 ⇒ 整段戰鬥中不做，PLAYER_REGEN_ENABLED 會補跑一次。
UpdateButtonVisibility = function()
    if InCombatLockdown() then return end
    for _, bu in ipairs(buttonList) do
        if IsButtonVisible(bu) then
            bu:Show()
        else
            bu:Hide()
        end
    end
    UpdateLayout()
end





-- Chattynator integration: if Chattynator is loaded, prefer its chat colors
-- over Blizzard's ChatTypeInfo. Lookup tries configKey first, then colorKey.
local function GetChattynatorColor(configKey, colorKey)
    if CHATTYNATOR_CONFIG and CHATTYNATOR_CURRENT_PROFILE and CHATTYNATOR_CONFIG.Profiles then
        local profile = CHATTYNATOR_CONFIG.Profiles[CHATTYNATOR_CURRENT_PROFILE]
        if profile and profile.chat_colors then
            local c = profile.chat_colors[configKey] or (colorKey and profile.chat_colors[colorKey])
            if c then return c.r, c.g, c.b end
        end
    end
    return nil
end

-- 骰／開怪／重置是 secure 動作鈕（巨集屬性、右鍵各有用途）。其餘全部是超連結按鈕：
-- 不需要 secure 模板，也不能要 —— secure 按鈕的 OnClick 會先接走點擊，超連結輪不到。
local FUNCTION_BUTTONS = { ROLL = true, DBM = true, RESET = true }

-- Find-or-create a button by configKey. Pooled: existing buttons are reused.
local function CreateOrRecycleButton(configKey)
    for _, btn in ipairs(buttonList) do
        if btn.configKey == configKey then return btn end
    end
    local template = FUNCTION_BUTTONS[configKey] and "SecureActionButtonTemplate, BackdropTemplate"
                     or "BackdropTemplate"
    local bu = CreateFrame("Button", nil, Sink, template)
    bu:SetSize(GetButtonWidth(), GetButtonHeight())
    bu:SetFrameLevel(Chatbar:GetFrameLevel() + 10) -- Above mover
    PixelIcon(bu, texture, true)
    CreateSD(bu)
    bu:RegisterForClicks("AnyUp")

    -- 超連結點擊往上交給 Sink（見檔案前段）。條上那串空白連結鋪滿整顆按鈕。
    bu:SetHyperlinkPropagateToParent(true)
    local link = bu:CreateFontString(nil, "OVERLAY")
    link:SetFont(STANDARD_TEXT_FONT, 12, "")   -- 沒字型 SetText 會硬錯；真正的字級在 RenderLink 裡設
    link:SetPoint("CENTER")
    link:SetWordWrap(false)
    bu.link = link

    local fs = bu:CreateFontString(nil, "OVERLAY")
    local fSize = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.FontSize) or 9
    fs:SetFont(STANDARD_TEXT_FONT, fSize, "OUTLINE")
    fs:SetPoint("BOTTOM", bu, "TOP", 0, 1)
    bu.fs = fs

    table.insert(buttonList, bu)
    return bu
end

-- Shared button configuration (color, text, tooltip, click handler)
local function ConfigureButton(bu, configKey, colorKey, r, g, b, text, labelText, func, order)
    bu.Icon:SetVertexColor(r, g, b)
    bu.configKey   = configKey
    bu.colorKey    = colorKey
    bu.order       = order or 99
    bu.tooltipText = text
    if text then AddTooltip(bu, "ANCHOR_TOP") end

    -- 標籤原文另存一份：有連結的按鈕會把它包成 |H…|h 再畫（RenderLink），
    -- 設定頁列名字也讀這個，不讀 GetText（那會拿到帶連結碼的字串）。
    bu.labelText = labelText
    if labelText then
        bu.fs:SetText(labelText)
        bu.fs:SetTextColor(r, g, b)
        bu.fs:Show()
    else
        bu.fs:Hide()
    end
    RenderLink(bu)

    if func then bu:SetScript("OnClick", func) end
end

-- Add/update a button whose color is derived from a ChatTypeInfo key
-- (e.g. "SAY", "PARTY", "CHANNEL3"). Chattynator override is honored.
AddColorKeyButton = function(configKey, colorKey, text, labelText, func, order)
    local c = ChatTypeInfo[colorKey] or { r = 1, g = 1, b = 1 }
    local r, g, b = c.r, c.g, c.b
    local cR, cG, cB = GetChattynatorColor(configKey, colorKey)
    if cR then r, g, b = cR, cG, cB end

    local bu = CreateOrRecycleButton(configKey)
    ConfigureButton(bu, configKey, colorKey, r, g, b, text, labelText, func, order)
    return bu
end

-- Add/update a button with an explicit RGB triple (no ChatTypeInfo lookup).
-- Chattynator override still applies by configKey.
AddRGBButton = function(configKey, r, g, b, text, labelText, func, order)
    local cR, cG, cB = GetChattynatorColor(configKey, nil)
    if cR then r, g, b = cR, cG, cB end

    local bu = CreateOrRecycleButton(configKey)
    ConfigureButton(bu, configKey, nil, r, g, b, text, labelText, func, order)
    return bu
end

--------
-- Buttons
--------
-- 每顆頻道按鈕只有一個超連結，左鍵點下去由暴雪開輸入框（機制見檔案前段的 Sink）。
-- 右鍵穿透給底下的條 → 聊天列自己的右鍵選單。func 一律 nil：OnClick 上不能有任何
-- 會碰輸入框的程式碼。

-- SAY / YELL
local sayBtn = AddColorKeyButton("SAY", "SAY", SAY, L["SHORT_SAY"], nil, 10)
SetChannelLink(sayBtn, "channel:SAY")
sayBtn.tabChat = function() return "SAY" end

-- 大喊不進 Tab 循環：循環是「打字時換個頻道」用的，喊話不該被輪到
local yellBtn = AddColorKeyButton("YELL", "YELL", YELL, L["SHORT_YELL"], nil, 11)
SetChannelLink(yellBtn, "channel:YELL")

-- REPLY
-- 密語不做按鈕：密語要先有對象，從一顆按鈕開一個空的 /w 沒有意義（要密誰就點名字）。
-- 回覆不同，對象是「最後密我的人」，一顆鍵就成立。
-- |Hchannel:REPLY|h → 暴雪在乾淨執行下解析 /REPLY，秘密名字直接填進去，跟按 R 一樣。
-- 顏色跟密語同一組（ChatTypeInfo 的 REPLY 沒有自己的顏色）。刻意不給 tabChat。
local replyBtn = AddColorKeyButton("REPLY", "WHISPER", REPLY_MESSAGE, L["SHORT_REPLY"], nil, 12)
SetChannelLink(replyBtn, "channel:REPLY")

-- PARTY
local partyBtn = AddColorKeyButton("PARTY", "PARTY", PARTY, L["SHORT_PARTY"], nil, 14)
SetChannelLink(partyBtn, "channel:PARTY")
partyBtn.isAvailable = function() return IsInGroup() end
partyBtn.tabChat = function() return "PARTY" end

-- INSTANCE / RAID
local function InInstanceChat()
    return IsPartyLFG() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
end
local instanceBtn = AddColorKeyButton("INSTANCE", "INSTANCE_CHAT", INSTANCE.."/"..RAID, L["SHORT_RAID"], nil, 15)
-- 副本隊伍與一般團隊是兩個頻道，連結隨隊伍狀態換（RefreshGroupLinks）
local function RefreshGroupLinks()
    SetChannelLink(instanceBtn, InInstanceChat() and "channel:INSTANCE_CHAT" or "channel:RAID")
end
RefreshGroupLinks()
-- /raid 只在團隊裡有意義，小隊狀態下這顆沒用
instanceBtn.isAvailable = function() return InInstanceChat() or IsInRaid() end
instanceBtn.tabChat = function()
    if InInstanceChat() then return "INSTANCE_CHAT" end
    return "RAID"
end

-- GUILD / OFFICER
local guildBtn = AddColorKeyButton("GUILD", "GUILD", GUILD, L["SHORT_GUILD"], nil, 16)
SetChannelLink(guildBtn, "channel:GUILD")
guildBtn.isAvailable = function() return IsInGuild() end
guildBtn.tabChat = function() return "GUILD" end

local officerBtn = AddColorKeyButton("OFFICER", "OFFICER", OFFICER, L["SHORT_OFFICER"], nil, 17)
SetChannelLink(officerBtn, "channel:OFFICER")
-- 有幹部頻道權限的近似判斷（跟以前右鍵那條一樣）
officerBtn.isAvailable = function() return IsInGuild() and C_GuildInfo.CanEditOfficerNote() end

-- WORLD CHANNEL
-- DYNAMIC CHANNELS
local function GetFirstChar(s)
    if not s then return "" end
    local b = string.byte(s, 1)
    if not b then return "" end
    if b < 128 then return string.sub(s, 1, 1) end
    if b >= 240 then return string.sub(s, 1, 4) end
    if b >= 224 then return string.sub(s, 1, 3) end
    if b >= 192 then return string.sub(s, 1, 2) end
    return string.sub(s, 1, 1)
end




-- DYNAMIC CHANNELS UPDATE
local function UpdateChannelButtons()
    -- Rebuild the "still joined" set; buttons for channels the user left stay
    -- pooled but report themselves unavailable.
    wipe(channelActive)

    -- Use Display Info (UI List) instead of raw Channel List
    local num = GetNumDisplayChannels()
    for i = 1, num do
        local name, header, collapsed, channelNumber, count, active, category, channelType = GetChannelDisplayInfo(i)

        if not header and name and channelNumber then
            local label = GetFirstChar(name)
            local key = "CHANNEL"..channelNumber
            channelActive[key] = true

            -- UI index 'i' determines sort order (20+)
            local order = 20 + i
            local btn = AddColorKeyButton(key, key, name, label, nil, order)
            SetChannelLink(btn, "channel:CHANNEL:"..channelNumber)   -- 暴雪自己的頻道連結格式
            btn.tabChat = function() return "CHANNEL", channelNumber end
            btn.isAvailable = function() return channelActive[key] == true end
        end
    end

    UpdateButtonVisibility()
    -- 動態頻道進出會改變按鈕清單，設定頁的頻道列表要跟著長／縮
    if ns.RefreshChannelList then ns.RefreshChannelList() end
end

-- ROLL
local roll = AddRGBButton("ROLL", 0.8, 1, 0.6, ROLL, L["SHORT_ROLL"], nil, 50)
roll:SetAttribute("type", "macro")
roll:SetAttribute("macrotext", "/roll")
roll:RegisterForClicks("AnyUp", "AnyDown")

-- Native pull countdown — no DBM/BigWigs dependency.
-- C_PartyInfo.DoCountdown (added 9.0.1) triggers Blizzard's built-in group
-- countdown. It is insecure-callable and needs no hardware event, but a secure
-- macro can only run slash commands, so we expose it via a custom slash command
-- that the button's macrotext invokes the same way it used to call /dbm pull.
SLASH_MILIUICHATBARPULL1 = "/miliuichatbarpull"
SlashCmdList["MILIUICHATBARPULL"] = function(msg)
    local seconds = tonumber(msg) or 10
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        C_PartyInfo.DoCountdown(seconds)
    end
end

-- Pull button (Left: Ready Check, Right: Pull Ns, Middle: Pull 5s)
-- Uses the native countdown above; configKey stays "DBM" for SavedVariables compat.
local dbm = AddRGBButton("DBM", 0.8, 0.568, 0.937, L["TIP_DBM"], L["SHORT_DBM"], nil, 51)
dbm:SetAttribute("type", "macro")
dbm:SetAttribute("macrotext", "/readycheck")
dbm:SetAttribute("type2", "macro")
dbm:SetAttribute("macrotext2", "/miliuichatbarpull 10")
dbm:SetAttribute("type3", "macro")
dbm:SetAttribute("macrotext3", "/miliuichatbarpull 5")
dbm:RegisterForClicks("AnyUp", "AnyDown")

-- Function to update pull button macro and tooltip based on saved seconds
local function UpdateDBMButton()
    local seconds = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar and MiliUI_ChatBar_DB.Chatbar.DBMPullSeconds) or 10
    if not InCombatLockdown() then
        dbm:SetAttribute("macrotext2", "/miliuichatbarpull " .. seconds)
    end
    -- Update tooltip text with current seconds value
    dbm.tooltipText = string.format(L["TIP_DBM_FORMAT"], seconds)
end

-- Exposed on addon namespace for cross-section use (settings panel)
ns.UpdateDBMButton = UpdateDBMButton


-- Reset Instance
local reset = AddColorKeyButton("RESET", "PARTY", L["TIP_RESET"], L["SHORT_RESET"], function(_, btn)
    if btn == "RightButton" then
        if SlashCmdList["COMBATLOG"] then
            SlashCmdList["COMBATLOG"]("")
        end
    elseif btn == "LeftButton" then
        StaticPopup_Show("CONFIRM_RESET_INSTANCES")
    end
end, 52)
reset:RegisterForClicks("AnyUp")

--------
-- Tab 循環聊天頻道
--------
-- 聊天輸入框開啟時按 Tab，依照 ChatBar 上按鈕的排列順序輪流切換頻道標頭。
-- 只吃「骰」之前的按鈕（order < 50），所以骰/開怪/重置那三顆功能鍵不參與；
-- 密語沒有 tabChat（需要對象），同樣跳過。
-- 隱藏起來的按鈕也不會出現在循環裡 —— 循環的就是看得到的那幾顆。
local TAB_CYCLE_MAX_ORDER = 50  -- ROLL 的 order

-- 循環清單就是「現在看得到的那幾顆」——同樣走 IsButtonVisible，
-- 所以按鈕上沒有的頻道，Tab 也絕對切不到。
local function BuildTabCycle()
    local list = {}
    for _, bu in ipairs(buttonList) do
        if bu.tabChat and (bu.order or 99) < TAB_CYCLE_MAX_ORDER and IsButtonVisible(bu) then
            local chatType, target = bu.tabChat()
            if chatType then
                table.insert(list, { order = bu.order or 99, chatType = chatType, target = target })
            end
        end
    end
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

local function ApplyChatType(editBox, entry)
    editBox:SetAttribute("chatType", entry.chatType)
    if entry.chatType == "CHANNEL" then
        editBox:SetAttribute("channelTarget", entry.target)
    end
    ChatEdit_UpdateHeader(editBox)
end

local function CycleChatType(editBox, backwards)
    local list = BuildTabCycle()
    if #list == 0 then return false end

    local curType   = editBox:GetAttribute("chatType")
    local curTarget = editBox:GetAttribute("channelTarget")

    local idx
    for i, e in ipairs(list) do
        if e.chatType == curType
           and (e.chatType ~= "CHANNEL" or tostring(e.target) == tostring(curTarget)) then
            idx = i
            break
        end
    end

    local nextIdx
    if not idx then
        -- 目前頻道不在循環內（密語、大喊…），直接跳到第一個
        nextIdx = 1
    elseif backwards then
        nextIdx = (idx - 2) % #list + 1
    else
        nextIdx = idx % #list + 1
    end

    ApplyChatType(editBox, list[nextIdx])
    return true
end

-- ChatEdit_CustomTabPressed 是 Blizzard 留給插件的覆寫點：
-- 回傳 true 表示這次 Tab 已被處理，FrameXML 就不會再跑預設的循環／補完。
-- 保留原本的實作往下串，才不會踩到其他也掛在這裡的插件（例如 AceTab）。
local origCustomTabPressed = ChatEdit_CustomTabPressed
function ChatEdit_CustomTabPressed(...)
    local editBox = ...
    if type(editBox) ~= "table" or not editBox.GetAttribute then
        editBox = ChatEdit_GetActiveWindow()
    end

    if editBox then
        -- 斜線指令留給暴雪的指令補完，不搶
        local text = editBox:GetText() or ""
        if string.sub(text, 1, 1) ~= "/" then
            if CycleChatType(editBox, IsShiftKeyDown()) then
                return true
            end
        end
    end

    if origCustomTabPressed then return origCustomTabPressed(...) end
    return false
end

-- Background styling
local bgFrame = CreateFrame("Frame", nil, Chatbar)
bgFrame:SetPoint("LEFT", Chatbar, "LEFT")
bgFrame:SetPoint("RIGHT", Chatbar, "RIGHT")
bgFrame:SetHeight(18)
bgFrame:SetFrameLevel(Chatbar:GetFrameLevel() - 1)

-- 自適應時按鈕最窄壓到幾像素。頻道多的時候平分下來會很細，但再細就只剩一條線、
-- 點不到也看不出顏色了 —— 寧可讓整條稍微超出聊天視窗也不要有點不到的按鈕。
local MIN_AUTO_BUTTON_W = 6

-- Layout Logic
--
-- ⚠ 每顆按鈕都直接錨在聊天列上（偏移自己算），**不要改回「錨在前一顆」的鏈**。
--   保護框錨在誰身上，誰就被隱式保護，而且沿著錨點鏈一路往回傳（warcraft.wiki.gg
--   ScriptRegion:IsProtected：「This applies recursively」）。骰／開怪／重置是
--   SecureActionButton、排在最後；鏈起來的話它前面的每一顆超連結按鈕都成了保護框，
--   戰鬥中連 SetHitRectInsets 都被擋（2026-09-21 taint.log：打木樁時頻道事件重畫按鈕，
--   四顆頻道鈕各擋一次）。聊天列本來就是 secure 鈕的祖先、早就是保護框，錨在它上面不牽連任何人。
UpdateLayout = function()
    if InCombatLockdown() then return end
    local cb = (MiliUI_ChatBar_DB and MiliUI_ChatBar_DB.Chatbar) or {}
    local orientation = cb.Orientation or "HORIZONTAL"
    local bw = GetButtonWidth()
    local bh = GetButtonHeight()
    local endPadding = 10 -- Main axis padding
    local sidePadding = 5 -- Cross axis padding

    -- Sort buttonList first
    table.sort(buttonList, function(a, b)
        return (a.order or 99) < (b.order or 99)
    end)

    local visibleButtons = {}
    for _, bu in ipairs(buttonList) do
        if bu:IsShown() then
            table.insert(visibleButtons, bu)
        end
    end

    if orientation == "VERTICAL" then
        local spacing = 15
        local vTopPadding = 20
        local vBottomPadding = 10
        
        -- Height calculation uses distinct top/bottom padding
        local barHeight = (#visibleButtons * bh) + ((#visibleButtons - 1) * spacing) + vTopPadding + vBottomPadding
        -- Dynamic sizing: fit content exactly
        Chatbar:SetSize(bw, barHeight)
        
        for i, bu in ipairs(visibleButtons) do
            -- 直向沒有自適應寬度，但橫向可能剛把寬度算成別的值，這裡要收回來
            bu:SetSize(bw, bh)
            RenderLink(bu)   -- 超連結的點擊區跟著按鈕大小走
            bu:ClearAllPoints()
            bu:SetPoint("TOP", Chatbar, "TOP", 0, -(vTopPadding + (i - 1) * (bh + spacing)))
        end
        
        -- Adjust background for vertical
        -- Width calculation uses sidePadding (Left/Right)
        bgFrame:ClearAllPoints()
        bgFrame:SetPoint("TOP", Chatbar, "TOP")
        bgFrame:SetPoint("BOTTOM", Chatbar, "BOTTOM")
        bgFrame:SetWidth(bw + (sidePadding * 2)) -- Width + 10 (Default behavior)
        bgFrame:SetPoint("CENTER", Chatbar, "CENTER")
        
    else
        -- HORIZONTAL

        ------------------------------------------------------------
        -- 自適應寬度
        --
        -- 兩段獨立的開關：
        --   MatchChatWidth  → 整條的總寬度＝聊天視窗的寬度（跟著它一起變）
        --   AutoButtonWidth → 再把總寬度扣掉內距與間隔之後，由按鈕顆數平分
        -- 只在橫向有意義：直向那條是「一排往下」，寬度對齊聊天視窗沒有意義。
        -- 拿不到聊天視窗（還沒建好／玩家關掉了）就整組退回手動寬度，不要留一條
        -- 寬度為零的空棒子在畫面上。
        ------------------------------------------------------------
        local n = #visibleButtons
        local chatWidth = cb.MatchChatWidth and ns.Anchor and ns.Anchor.ChatWidth() or nil

        if chatWidth and cb.AutoButtonWidth and n > 0 then
            local avail = chatWidth - (endPadding * 2) - ((n - 1) * padding)
            bw = math.max(MIN_AUTO_BUTTON_W, math.floor(avail / n))
        end

        -- Width calculation uses endPadding (Left/Right)
        local totalButtonWidth = (n * bw) + ((n - 1) * padding)
        local fitWidth = totalButtonWidth + (endPadding * 2)

        local barWidth = chatWidth or fitWidth
        -- Height calculation uses sidePadding (Top/Bottom)
        local barHeight = bh + (sidePadding * 2) -- e.g., 8 + 10 = 18

        Chatbar:SetSize(barWidth, barHeight)

        -- 整排置中。沒有對齊聊天視窗的時候 barWidth 剛好是 fitWidth，算出來就是
        -- endPadding，跟以前一樣靠左；有對齊的時候多出來的寬度才會左右平分
        -- —— 平分不盡的餘數（floor）也一起被吃掉，右邊不會單獨留一條縫。
        local startOffset = math.max(0, math.floor((barWidth - totalButtonWidth) / 2))

        for i, bu in ipairs(visibleButtons) do
            bu:SetSize(bw, bh)
            RenderLink(bu)   -- 超連結的點擊區跟著按鈕大小走
            bu:ClearAllPoints()
            bu:SetPoint("LEFT", Chatbar, "LEFT", startOffset + (i - 1) * (bw + padding), 0)
        end
        
        -- Adjust background for horizontal
        bgFrame:ClearAllPoints()
        bgFrame:SetPoint("LEFT", Chatbar, "LEFT")
        bgFrame:SetPoint("RIGHT", Chatbar, "RIGHT")
        bgFrame:SetPoint("CENTER", Chatbar, "CENTER")
        bgFrame:SetHeight(barHeight)
    end
end

-- 聊天視窗改變大小要重排（總寬度對齊聊天視窗時尤其明顯）。
-- 掛勾的對象由 Anchor 決定 —— Chattynator 在的話真正的聊天視窗不是 ChatFrame1。

-- Initial Layout
UpdateLayout()

------------------------------------------------------------
-- 條的底色。常數與出處在檔案開頭的 DARK_BG（按鈕底也共用同一個），
-- 這裡不要再宣告一份——兩份會在改值時悄悄分岔。
------------------------------------------------------------
local grad = bgFrame:CreateTexture(nil, "BACKGROUND")
grad:SetAllPoints()
grad:SetColorTexture(DARK_BG, DARK_BG, DARK_BG, DARK_BG_ALPHA)

------------------------------------------------------------
-- 右鍵選單
--
-- 選單本體在 Menu.lua（載入順序在共用層之後，所以這裡只在被點到的時候問一次
-- 有沒有 ns.ShowBarMenu）。這支只負責「哪裡按右鍵會叫出它」。
------------------------------------------------------------
local function OnContextClick(self, btn)
    if btn ~= "RightButton" then return end
    if ns.ShowBarMenu then ns.ShowBarMenu() end
end

bgFrame:EnableMouse(true)
bgFrame:SetScript("OnMouseUp", OnContextClick)
-- Also allow Mover to trigger context menu on Right Click
Mover:SetScript("OnMouseUp", OnContextClick)


-- Persistence and Commands
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
loader:RegisterEvent("CHANNEL_UI_UPDATE")
loader:RegisterEvent("PLAYER_ENTERING_WORLD") -- For zone changes
loader:RegisterEvent("UPDATE_CHAT_WINDOWS")
loader:RegisterEvent("CHANNEL_FLAGS_UPDATED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
-- 隊伍 / 公會狀態改變 → 隊、團/副、公 這幾顆的可用性跟著變
loader:RegisterEvent("GROUP_ROSTER_UPDATE")
loader:RegisterEvent("PLAYER_GUILD_UPDATE")


-- Throttled Update to prevent massive spam on login/zone change
local pendingDelay = 0
local function RequestChannelUpdate(forceDelay)
    if loader.updateTimer then loader.updateTimer:Cancel() end
    
    -- If forceDelay is true (login/zone), ensure we stick to the long delay (2.0s).
    -- If false (UI update), use 0.5s, BUT do not override a pending long delay.
    local newDelay = forceDelay and 2.0 or 0.5
    
    if newDelay > pendingDelay then
        pendingDelay = newDelay
    end
    
    -- Always restart the timer with the maximum required delay
    loader.updateTimer = C_Timer.NewTimer(pendingDelay, function()
        if MiliUI_ChatBar_DB then
             UpdateChannelButtons()
        end
        loader.updateTimer = nil
        pendingDelay = 0 -- Reset after firing
    end)
end

loader:SetScript("OnEvent", function(self, event)
    if event == "CHAT_MSG_CHANNEL_NOTICE" or event == "CHANNEL_UI_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_CHAT_WINDOWS" or event == "CHANNEL_FLAGS_UPDATED" then
        if event == "PLAYER_ENTERING_WORLD" then
             -- Force longer delay for map switch to ensure channels are ready
             RequestChannelUpdate(true)
             RefreshGroupLinks()   -- 進副本／出副本會改變是不是副本隊伍
        else
             RequestChannelUpdate(false)
        end
        return
    end

    -- 離開戰鬥後補跑：戰鬥中被擋掉的顯示變更與位置在這裡補上
    if event == "PLAYER_REGEN_ENABLED" then
        if ns.Anchor then ns.Anchor.Apply() end
        UpdateButtonVisibility()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        RefreshGroupLinks()
        UpdateButtonVisibility()
        return
    end

    InitDB()

    -- Apply lock state (respects Edit Mode)
    UpdateMoverState()

    -- Update colors
    for _, bu in ipairs(buttonList) do
        -- Colors
        if bu.colorKey then
            local c = ChatTypeInfo[bu.colorKey]
            if c then
                bu.Icon:SetVertexColor(c.r, c.g, c.b)
                if bu.fs then bu.fs:SetTextColor(c.r, c.g, c.b) end
            end
        end

        -- Custom Colors (Override)
        if MiliUI_ChatBar_DB.Chatbar.CustomColors[bu.configKey] then
            local cc = MiliUI_ChatBar_DB.Chatbar.CustomColors[bu.configKey]
            bu.Icon:SetVertexColor(cc.r, cc.g, cc.b)
            if bu.fs then bu.fs:SetTextColor(cc.r, cc.g, cc.b) end
        end
    end

    UpdateButtonVisibility()

    -- Request update on login as well
    RequestChannelUpdate(true)
    
    -- Force font size update on login/reload to ensure all buttons (including early created ones) get the correct size
    UpdateFontSize()
    
    -- Force button size update on login/reload
    UpdateButtonSize()
    
    -- Update DBM button with saved pull seconds
    UpdateDBMButton()

    -- 位置／吸附。這一步會把舊玩家的 SetUserPlaced 位置抄進 DB，所以要在
    -- 任何 SetPoint 之後才跑（不然抄到的是程式寫死的初始值）。
    -- 跑完才知道聊天視窗在哪、多寬 ⇒ 再重排一次，自適應寬度才吃得到。
    if ns.Anchor then
        ns.Anchor.Init()
        UpdateLayout()
    end

    -- Delayed final refresh to catch any channel buttons added late
    C_Timer.After(2, function()
        if ns.RefreshChannelList then ns.RefreshChannelList() end
    end)
end)

--------
-- 對設定視窗開放的介面
--
-- 設定頁在 Options/ 底下，跟這支檔案之間只透過 ns 溝通：這裡不知道有沒有設定頁
-- （呼叫端一律加 nil 判斷），設定頁也不碰這裡的區域變數。
--------
ns.InitDB   = InitDB
ns.Chatbar  = Chatbar
ns.buttonList = buttonList

ns.UpdateLayout           = function() UpdateLayout() end
ns.UpdateFontSize         = function() UpdateFontSize() end
ns.UpdateButtonSize       = function() UpdateButtonSize() end
ns.UpdateButtonVisibility = function() UpdateButtonVisibility() end
ns.UpdateMoverState       = function() UpdateMoverState() end

-- 位置重置：回到預設（吸在聊天視窗下；沒有聊天視窗就左下角），再重排一次
function ns.ResetPosition()
    if ns.Anchor then ns.Anchor.Reset() end
    UpdateLayout()
    print(L["MSG_RESET"])
end

------------------------------------------------------------
-- 右鍵選單與設定頁共用的三個開關
--
-- 兩邊都會改到同樣的東西，副作用（重排、存檔、通知另一邊刷新）只寫一份。
-- ns.Fire 來自 Libs/Callbacks.lua，載入順序在本檔之後 ⇒ 呼叫前先確認有沒有。
------------------------------------------------------------
local function Changed()
    if ns.Fire then ns.Fire("SettingsChanged") end
end

function ns.SetLocked(locked)
    InitDB()
    MiliUI_ChatBar_DB.Chatbar.Locked = locked and true or false
    UpdateMoverState()
    print(locked and L["MSG_LOCKED"] or L["MSG_UNLOCKED"])
    Changed()
end

function ns.SetOrientation(orientation)
    InitDB()
    MiliUI_ChatBar_DB.Chatbar.Orientation =
        (orientation == "VERTICAL") and "VERTICAL" or "HORIZONTAL"
    UpdateLayout()
    Changed()
end

function ns.SetGroupWithChat(grouped)
    InitDB()
    MiliUI_ChatBar_DB.Chatbar.GroupWithChat = grouped and true or false
    if ns.Anchor then ns.Anchor.OnSettingsChanged() end
    UpdateLayout()
    Changed()
end

-- 一顆按鈕現在的顏色（自訂色優先，其次頻道預設色）
function ns.GetButtonColor(bu)
    InitDB()   -- CustomColors 由它保證存在（少了這行，DB 還沒初始化就查會炸）
    local cc = MiliUI_ChatBar_DB.Chatbar.CustomColors[bu.configKey]
    if cc then return cc.r, cc.g, cc.b end
    return bu.Icon:GetVertexColor()
end

function ns.SetButtonColor(bu, r, g, b)
    InitDB()
    MiliUI_ChatBar_DB.Chatbar.CustomColors[bu.configKey] = { r = r, g = g, b = b }
    bu.Icon:SetVertexColor(r, g, b)
    if bu.fs then bu.fs:SetTextColor(r, g, b) end
end
