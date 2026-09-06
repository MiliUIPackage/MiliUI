------------------------------------------------------------
-- 資訊列的彈出名單：一個**可以把滑鼠移上去**的列表面板
--
-- 第一版是自己開一個 GameTooltip（GameTooltipTemplate ＋ 換皮）。它的問題只有一個，
-- 但那一個是決定性的：**提示框碰不到**。GameTooltip 是「跟著游標、游標一離開來源就
-- 消失」的東西，名單上的人名再怎麼排得漂亮，玩家都只能看、不能點 —— 要找人講話
-- 得先離開名單、再從格子的選單裡找一次同一個名字。
--
-- 所以改成自己畫：一個面板、一池列。每一列是一顆 Button，人名列可以點
-- （左鍵密語／右鍵邀請），最底下一列是「開完整面板」的按鈕，標題與說明列只是
-- 不吃滑鼠的文字。
--
-- ⚠⚠ **「開公會名冊／好友清單」不能從插件 Lua 直接呼叫 ToggleGuildFrame /
--   ToggleFriendsFrame。** 12.1 起那條路會污染暴雪的面板系統，玩家看到的是
--   「介面功能因插件而失效」的封鎖彈窗、面板打不開（實測）。正解跟 MiliUI_InfoBar
--   的微型選單同一套：一顆 SecureActionButtonTemplate，*type1="click"、
--   *clickbutton1 指向暴雪自己的按鈕（GuildMicroButton／QuickJoinToastButton），
--   點我們的鈕＝在 secure 環境裡點暴雪的鈕。
--   代價是戰鬥紀律，而且**名單面板本身一個 secure 的東西都不能沾**：
--   secure 鈕不能是面板的子框，也**不能錨在面板上** —— 有 secure 子框的祖先、
--   被 secure 框 SetPoint 錨定的目標框，戰鬥中一樣被當保護框（wow-combat-drag-release
--   寫著的；第一版錨在面板上，結果戰鬥中每次滑過去都被封鎖）。
--   所以 secure 鈕掛 UIParent、用**絕對座標**擺到按鈕列的位置，面板跟它之間沒有任何
--   父子或錨點關係。戰鬥中名單照開照用；只有那顆鈕不動（進戰鬥時先藏起來，
--   字變灰表示暫時不能按），出戰鬥再擺回來。
-- 「游標在面板上就留著、離開才關」的判定不在這裡 —— 那是資訊列（Panel/Bar.lua
-- 的 Hover 段）的事，這支只負責畫與排。
--
-- 對外的介面刻意長得像 GameTooltip（AddLine / AddDoubleLine / Show）：
-- Map/Skin.lua 的拉把手也借這個面板顯示尺寸，那邊不需要知道底下換了實作。
--
-- ⚠ 列是**池化**的，只增不減（frame 刪不掉，見 wow-frame-lifecycle-costs）。
--   每次 Open 從第一列重新用起，Show 時把多出來的藏掉；上限由 tipMaxRows 管。
------------------------------------------------------------
local _, ns = ...

ns.Tip = {}
local Tip = ns.Tip
local S = ns.Style
local P = ns.P

local panel
local rows = {}
local used = 0             -- 這一輪用到第幾列
local owner                -- 是誰開的（資訊列的哪一格）
local buttonRow, buttonKind   -- 這一輪的底部按鈕列與它要開的面板（guild / friends）

local SyncOpeners, RefreshButtonRow   -- 定義在下面的 Openers 段，Show() 會用到

local PAD_X   = 8          -- 左右內距
local PAD_Y   = 5          -- 上下內距
local COL_GAP = 18         -- 左欄與右欄之間至少留多寬
local MIN_W   = 120

-- 一列的高度跟著字級走：字級 + 6 讓可點的列有足夠的落點，
-- 又不會讓三十列的名單長到一個螢幕都裝不下。
local function RowHeight()
    local d = ns.DB and ns.DB.Get()
    return ((d and d.tipFontSize) or 12) + 6
end

local function FontSize()
    local d = ns.DB and ns.DB.Get()
    return (d and d.tipFontSize) or 12
end

------------------------------------------------------------
-- 列池
------------------------------------------------------------
local function EnsureRow(i)
    local row = rows[i]
    if row then return row end

    row = CreateFrame("Button", nil, panel)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- 按鈕列的底：整列一塊比面板亮一階的實心帶。平常就看得到（它是按鈕，
    -- 要讓人知道這裡可以按），滑過再疊上 hl 亮一階 —— 狀態只換明暗不換色。
    row.fill = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    row.fill:SetAllPoints(row)
    row.fill:SetColorTexture(1, 1, 1, 0.07)
    row.fill:Hide()

    -- 滑過的回饋走**底色明暗**，不換色（miliui-color-states）。
    -- 跟資訊列格子的那塊一樣淡：這裡是清單，不是選單，亮太多會像每一列都被選中。
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints(row)
    row.hl:SetColorTexture(1, 1, 1, 0.10)
    row.hl:Hide()

    -- ⚠ 建出來就給字型（wow-fontstring-font-before-settext）。
    --   不描邊：面板底是不透明的，字不會壓在地形上，描邊只會讓小字糊掉。
    row.left = row:CreateFontString(nil, "OVERLAY")
    row.left:SetPoint("LEFT", row, "LEFT", PAD_X, 0)
    row.left:SetJustifyH("LEFT")
    row.left:SetWordWrap(false)
    S.SetFont(row.left, FontSize(), "")

    row.right = row:CreateFontString(nil, "OVERLAY")
    row.right:SetPoint("RIGHT", row, "RIGHT", -PAD_X, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetWordWrap(false)
    S.SetFont(row.right, FontSize(), "")

    -- 置中的字只給按鈕列用
    row.center = row:CreateFontString(nil, "OVERLAY")
    row.center:SetPoint("CENTER", row, "CENTER", 0, 0)
    row.center:SetJustifyH("CENTER")
    row.center:SetWordWrap(false)
    S.SetFont(row.center, FontSize(), "")

    row:SetScript("OnEnter", function(self)
        if self.onClick then self.hl:Show() end
    end)
    row:SetScript("OnLeave", function(self) self.hl:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if self.onClick then ns.Safe(self.onClick, self.entry, button) end
    end)

    rows[i] = row
    return row
end

-- 取下一列並歸零。回傳的列還沒排位置，Show 時一起排。
local function NextRow()
    used = used + 1
    local row = EnsureRow(used)
    row.height = RowHeight()
    row.onClick = nil
    row.entry = nil
    row.hl:Hide()
    row.fill:Hide()
    row:EnableMouse(false)
    row.left:SetText("")
    row.right:SetText("")
    row.center:SetText("")
    row.left:SetTextColor(1, 1, 1)
    row.right:SetTextColor(1, 1, 1)
    row:Show()
    return row
end

------------------------------------------------------------
-- 建面板
------------------------------------------------------------
local function Build()
    if panel then return panel end

    panel = CreateFrame("Frame", "MiliUIMinimapTooltip", UIParent, "BackdropTemplate")
    -- TOOLTIP 層：它是暫時彈出來的東西，要壓在任務追蹤框、收納袋、其他插件視窗之上；
    -- 選單（FULLSCREEN_DIALOG）仍然在它上面。
    panel:SetFrameStrata("TOOLTIP")
    panel:SetClampedToScreen(true)
    -- 吃滑鼠：這是一塊可以停在上面操作的面板，點到列與列之間的縫不該穿到世界去。
    panel:EnableMouse(true)
    panel:Hide()
    -- 深色、不透明的提示皮。完整理由寫在 Core/Style.lua 的 S.ApplyTooltipSkin：
    -- 一句話是「面板底色不承載資訊所以可以透，提示底色承載的是『讓字讀得出來』，
    -- 那就不能透」。
    S.ApplyTooltipSkin(panel)

    ------------------------------------------------------------
    -- GameTooltip 相容介面：AddLine / AddDoubleLine / Show
    --
    -- ⚠ AddLine 的第四個參數在 GameTooltip 是 wrapText —— 這裡照樣**不收 alpha**，
    --   呼叫端把 S.Accent() 直接展開的話第四個值會被丟掉而不是變成怪色，
    --   但別依賴這點，一律先解成三個變數再傳（見 Tip.AddSection 的註解）。
    ------------------------------------------------------------
    function panel:AddLine(text, r, g, b)
        local row = NextRow()
        row.left:SetText(text or "")
        if r then row.left:SetTextColor(r, g, b) end
        return row
    end

    function panel:AddDoubleLine(l, r, rl, gl, bl, rr, gr, br)
        local row = NextRow()
        row.left:SetText(l or "")
        row.right:SetText(r or "")
        if rl then row.left:SetTextColor(rl, gl, bl) end
        if rr then row.right:SetTextColor(rr, gr, br) end
        return row
    end

    -- 半列高的空白，取代 GameTooltip 時代的 AddLine(" ")
    function panel:AddGap()
        local row = NextRow()
        row.height = math.floor(RowHeight() / 2)
        return row
    end

    ------------------------------------------------------------
    -- 排版＋顯示
    --
    -- 寬度＝最寬那一列的「左欄 ＋ 間距 ＋ 右欄」，全部量完再一次設；
    -- 高度＝各列高度加總。列是滿寬的（錨在面板左右緣），所以右欄永遠貼右。
    --
    -- ⚠ 蓋掉 frame 自己的 Show：呼叫端（含 Map/Skin.lua）寫的是 tip:Show()，
    --   排版要在那一刻做。原本的 Show 先抓下來，排完再叫它。
    ------------------------------------------------------------
    local rawShow = panel.Show
    function panel:Show()
        local width = MIN_W
        local y = -PAD_Y
        for i = 1, used do
            local row = rows[i]
            local w = row.left:GetStringWidth() or 0
            local rw = row.right:GetStringWidth() or 0
            if rw > 0 then w = w + COL_GAP + rw end
            local cw = row.center:GetStringWidth() or 0
            if cw > w then w = cw end
            if w > width then width = w end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self, "TOPLEFT", 1, y)
            row:SetPoint("TOPRIGHT", self, "TOPRIGHT", -1, y)
            row:SetHeight(row.height)
            -- 重畫（名單刷新）時游標可能正停在某一列上，OnEnter 不會再觸發一次，
            -- 這裡補判一次讓亮起來的列跟著內容走。
            row.hl:SetShown(row.onClick ~= nil and row:IsMouseOver())
            y = y - row.height
        end
        for i = used + 1, #rows do rows[i]:Hide() end

        -- 最後一列是按鈕的話貼著下緣（只留 1px 邊框），secure 鈕就是錨在那裡
        local bottom = (used > 0 and rows[used] == buttonRow) and 1 or PAD_Y
        self:SetSize(math.ceil(width + PAD_X * 2 + 2), math.ceil(-y + bottom))
        rawShow(self)
        -- secure 鈕的位置要讀面板的 rect，而 rect 在貼齊螢幕（ClampedToScreen）之後
        -- 才是最終值 —— 延一幀再擺。這一幀先照「現在按不按得到」把字上色。
        RefreshButtonRow()
        C_Timer.After(0, function()
            if not panel:IsShown() then return end
            SyncOpeners()
            RefreshButtonRow()
        end)
    end

    panel:HookScript("OnShow", function(self)
        S.RefreshTooltipSkin(self)
    end)

    return panel
end

------------------------------------------------------------
-- 開啟：一律錨在來源按鈕上
--
-- anchor 由呼叫端決定貼哪一邊 —— 資訊列在畫面右上角，提示往左下長才不會出畫面。
-- 回傳面板本身，呼叫端接著 AddLine… 最後 Show()。
------------------------------------------------------------
function Tip.Open(who, anchorPoint, relPoint, x, y)
    Build()
    owner = who
    used = 0
    buttonRow, buttonKind = nil, nil
    panel:ClearAllPoints()
    panel:SetPoint(anchorPoint or "TOPRIGHT", who, relPoint or "BOTTOMRIGHT", x or 0, y or -4)
    return panel
end

function Tip.Close()
    if panel then
        panel:Hide()
        owner = nil
        buttonRow, buttonKind = nil, nil
        SyncOpeners()
    end
end

function Tip.IsOwnedBy(who)
    return panel ~= nil and panel:IsShown() and owner == who
end

function Tip.Frame()
    return panel
end

------------------------------------------------------------
-- 一行「名字 ── 區域」，可以點
--
-- 左欄職業色、右欄同區綠／不同區灰。這是名單裡唯一破例上彩色的地方：
-- 職業色在這裡承載的是「這是誰、哪個職業」，不是狀態，符合
-- miliui-color-states 的「顏色只承載身分」那條。
--
-- onClick(entry, button)：button 是 "LeftButton" / "RightButton"。
-- 給了才吃滑鼠；沒給的列（不會有這種情況，但留著）就只是文字。
------------------------------------------------------------
local ZONE_SAME = { 0.35, 0.85, 0.35 }
local ZONE_OTHER = { 0.6, 0.6, 0.6 }

function Tip.AddMember(entry, currentZone, showZone, onClick)
    local row
    ------------------------------------------------------------
    -- 不在 WoW 的好友：整列壓成灰的，右欄顯示他在玩什麼。
    -- 不上職業色也不標等級 —— 那兩樣是「這個人現在能不能一起打」的訊號，
    -- 對不在遊戲裡的人套上去只會讓清單看起來每一列都一樣重要。
    ------------------------------------------------------------
    if entry.inWoW == false then
        local left = "|cff888888" .. entry.name .. "|r"
        if entry.zone ~= "" then
            row = panel:AddDoubleLine(left, entry.zone, 1, 1, 1, 0.45, 0.45, 0.45)
        else
            row = panel:AddLine(left, 1, 1, 1)
        end
    else
        local hex = S.ClassHex(entry.class)
        local left
        if entry.level then
            local lc = GetQuestDifficultyColor(entry.level)
            left = string.format("|cff%02x%02x%02x%d|r |c%s%s|r",
                lc.r * 255, lc.g * 255, lc.b * 255, entry.level, hex, entry.name)
        else
            left = string.format("|c%s%s|r", hex, entry.name)
        end

        -- 戰網好友：角色名後面補戰網暱稱，兩個都要看得到才認得出是誰
        if entry.tag and entry.tag ~= entry.name then
            left = left .. " |cff888888(" .. entry.tag .. ")|r"
        end

        local tag = ns.Data.StatusTag(entry)
        if tag then left = left .. " " .. tag end

        if not showZone or entry.zone == "" then
            row = panel:AddLine(left, 1, 1, 1)
        else
            local zc = (entry.zone == currentZone) and ZONE_SAME or ZONE_OTHER
            row = panel:AddDoubleLine(left, entry.zone, 1, 1, 1, zc[1], zc[2], zc[3])
        end
    end

    if onClick then
        row.onClick = onClick
        row.entry = entry
        row:EnableMouse(true)
    end
    return row
end

------------------------------------------------------------
-- 區段標題。用強調色（職業色）＋半列空白隔開。
------------------------------------------------------------
-- ⚠ **不能寫 `AddDoubleLine(l, r, S.Accent())`。** S.Accent() 回四個值（含 alpha），
--   而 AddDoubleLine 的簽章是 (左, 右, rL, gL, bL, rR, gR, bR) —— alpha 會被當成
--   右欄的紅色分量，右欄變成半紅的字。一律先解成三個變數再傳。
function Tip.AddSection(text, count)
    local ar, ag, ab = S.Accent()
    panel:AddGap()
    if count then
        panel:AddDoubleLine(text, count, ar, ag, ab, ar, ag, ab)
    else
        panel:AddLine(text, ar, ag, ab)
    end
end

-- 名單底部的操作說明。一律灰字、排在按鈕之前。
function Tip.AddHint(...)
    panel:AddGap()
    local dim = S.TEXT_DIM
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line then panel:AddLine(line, dim[1], dim[2], dim[3]) end
    end
end

------------------------------------------------------------
-- 最底下的按鈕列：整列滿寬、字置中、平常就有一層底、貼著面板下緣
--
-- 「開公會名冊／好友清單」原本綁在中鍵上，使用者的回饋是不直覺 —— 沒有人會
-- 想到去按中鍵。做成一顆看得見的按鈕。
--
-- 這一列**自己不吃滑鼠**：真正接點擊的是蓋在它上面的 secure 鈕（見檔頭與下面的
-- Openers 段）。這列只負責畫底與字，亮塊由 secure 鈕的 OnEnter/OnLeave 來開關。
------------------------------------------------------------
local function ButtonHeight() return RowHeight() + 4 end

function Tip.AddButton(text, kind)
    panel:AddGap()
    local row = NextRow()
    row.height = ButtonHeight()
    row.center:SetText(text or "")
    row.fill:Show()
    buttonRow, buttonKind = row, kind
    return row
end

------------------------------------------------------------
-- Openers：兩顆 secure 鈕，各開一種暴雪面板
--
-- 掛 UIParent、錨在面板**下緣**（不是錨在按鈕列上）：按鈕列永遠是最後一列、
-- 貼著下緣，錨面板等於錨那一列，但不用每次重排都 SetPoint —— 那在戰鬥中是
-- 被封鎖的。只有字級改變（列高變）時才重錨一次，而且要在戰鬥外。
--
-- 為什麼是 GuildMicroButton／QuickJoinToastButton 而不是巨集：
--   /friends 不帶參數會開好友清單沒錯，但它前面有一行
--   「目標是玩家就把目標名字當參數」—— 選著一個人按下去會變成**加他好友**。
--   點暴雪自己的按鈕沒有這種歧義。QuickJoinToastButton 在「有快速加入通知」時
--   會改開快速加入面板，那是暴雪按鈕本來的行為，接受。
------------------------------------------------------------
local OPENERS = {
    guild   = { name = "MiliUIMinimapOpenGuild",   targets = { "GuildMicroButton" } },
    friends = { name = "MiliUIMinimapOpenFriends", targets = { "QuickJoinToastButton", "FriendsMicroButton" } },
}
local openers = {}        -- kind → secure 鈕
local combatWatcher       -- 進戰鬥藏、出戰鬥擺回來

-- ⚠ **絕對座標，不錨面板。** 面板是 UIParent 的直接子框、scale 1，GetLeft/GetBottom
--   就是 UIParent 座標空間裡的值，直接當位移用。
local function PlaceOpener(btn)
    local l, b, w = panel:GetLeft(), panel:GetBottom(), panel:GetWidth()
    if not l or not b or not w then return false end
    btn:ClearAllPoints()
    btn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l + 1, b + 1)
    btn:SetSize(math.max(1, w - 2), ButtonHeight())
    return true
end

-- 讓 secure 鈕跟面板對上：面板開著且有按鈕列 → 那一種擺到按鈕列上顯示、另一種藏；
-- 面板關著 → 全藏。戰鬥中一律不碰（Show/Hide/SetPoint 全會被封鎖），
-- 出戰鬥由 combatWatcher 補一次。
function SyncOpeners()
    if InCombatLockdown() then return false end
    local want = (panel and panel:IsShown()) and buttonKind or nil
    for kind, btn in pairs(openers) do
        if kind == want and PlaceOpener(btn) then
            btn:Show()
        else
            btn:Hide()
        end
    end
    return true
end

-- 按鈕列的外觀跟著「現在按得到嗎」走：secure 鈕真的顯示在上面才是白字，
-- 否則（戰鬥中沒同步到、或這個版本找不到暴雪的按鈕）灰字，讓人知道現在按不了。
function RefreshButtonRow()
    if not buttonRow then return end
    local btn = openers[buttonKind]
    local live = btn ~= nil and btn:IsShown()
    if live then
        buttonRow.center:SetTextColor(S.TEXT[1], S.TEXT[2], S.TEXT[3])
    else
        buttonRow.center:SetTextColor(S.TEXT_DIM[1], S.TEXT_DIM[2], S.TEXT_DIM[3])
    end
end

-- ⚠ 在 Init（PLAYER_LOGIN）就建，不要等第一次滑過去：secure 鈕的建立與 SetAttribute
--   在戰鬥中都是違禁品，第一次滑過去如果剛好在打架就會建不出來。
local function BuildOpeners()
    Build()
    for kind, def in pairs(OPENERS) do
        local target
        for _, g in ipairs(def.targets) do
            if _G[g] then target = _G[g]; break end
        end
        if target and not openers[kind] then
            local btn = CreateFrame("Button", def.name, UIParent, "SecureActionButtonTemplate")
            btn:SetFrameStrata("TOOLTIP")
            btn:SetFrameLevel(panel:GetFrameLevel() + 5)
            btn:RegisterForClicks("AnyUp")
            -- 機制逐字照 MiliUI_InfoBar 的微型選單：
            -- useOnKeyDown=false —— 沒有這行，ActionButtonUseKeyDown 這個 CVar
            -- 會讓 secure handler 只認 key-down，把 AnyUp 的點擊丟掉。
            btn:SetAttribute("*clickbutton1", target)
            btn:SetAttribute("useOnKeyDown", false)
            btn:SetAttribute("*type1", "click")
            btn:Hide()
            -- 亮塊畫在底下那一列上（這顆鈕自己是透明的）
            btn:HookScript("OnEnter", function() if buttonRow then buttonRow.hl:Show() end end)
            btn:HookScript("OnLeave", function() if buttonRow then buttonRow.hl:Hide() end end)
            -- 面板開了之後名單就沒事了：宿主（Panel/Bar.lua）用 afterOpen 把名單收掉
            btn:HookScript("OnClick", function()
                if Tip.afterOpen then ns.Safe(Tip.afterOpen) end
            end)
            openers[kind] = btn
        end
    end
end

------------------------------------------------------------
-- 戰鬥
--
-- PLAYER_REGEN_DISABLED 在 lockdown 生效**之前**發火（wow-combat-drag-release），
-- 是碰 secure 鈕的最後窗口：把兩顆都藏掉。不藏的話，名單在戰鬥中關掉之後那顆
-- 透明的鈕會留在原地變成一塊看不見的點擊區，一直到出戰鬥。
-- 出戰鬥再同步一次：名單如果還開著，鈕會擺回它的按鈕列上。
------------------------------------------------------------
local function WatchCombat()
    if combatWatcher then return end
    combatWatcher = CreateFrame("Frame")
    combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatWatcher:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            for _, btn in pairs(openers) do btn:Hide() end
        else
            ns.Safe(SyncOpeners)
        end
        RefreshButtonRow()
    end)
end

ns.RegisterCallback("Init", "TipOpeners", function()
    ns.Safe(BuildOpeners)
    WatchCombat()
end)

------------------------------------------------------------
-- 設定變動：皮重上色、字級重套
--
-- 字級只在面板關著的時候才會被看到差異（開著時下一次 Open 就會重排），
-- 所以這裡只改 FontString，不重排。
------------------------------------------------------------
local function Restyle()
    if not panel then return end
    S.RefreshTooltipSkin(panel)
    local size = FontSize()
    for _, row in ipairs(rows) do
        S.SetFont(row.left, size, "")
        S.SetFont(row.right, size, "")
        S.SetFont(row.center, size, "")
    end
    -- 列高變了 → secure 鈕的尺寸也要跟；面板開著的話下一次 Show 會重擺，
    -- 關著的話它本來就藏著。這裡只要確保沒有一顆還顯示著。
    SyncOpeners()
end

ns.RegisterCallback("AccentChanged", "Tip", Restyle)
ns.RegisterCallback("ConfigChanged", "Tip", Restyle)
