------------------------------------------------------------
-- 資訊列：地圖正下方一條，切成三格
--
--   ┌──────────────┬────┬──────────────┐
--   │     公會 12  │ ▦  │    好友 4    │
--   └──────────────┴────┴──────────────┘
--
-- 三格各自可選：公會／好友／插件收納袋／無。
--
-- ── 寬度怎麼分 ──────────────────────────────────────────────
--
-- **收納袋那格是固定寬（一個正方形），其餘的平分剩下的寬度。**
-- 理由：收納袋格裡只有一顆 3×3 的圖示，給它四分之一條的寬度只會讓那顆圖示
-- 孤零零地飄在一大片空白中間；而公會／好友是文字，寬度多一點才不會截斷。
-- 選「無」的格子完全不佔位置，剩下的自動填滿 —— 所以「只留公會」就是
-- 一條整寬的公會列，不是一格公會加兩格空白。
--
-- ── 文字置中 ────────────────────────────────────────────────
--
-- ⚠ 標籤與數字是**同一個 FontString**（數字用 |cff 色碼上色），不是兩個。
--   兩個 FontString 各自置中會分別以自己的中心對齊，中間的縫會隨著數字位數
--   變動而左右晃 —— 從 9 跳到 10 的時候整組字會抖一下。
------------------------------------------------------------
local _, ns = ...

ns.Bar = {}
local Bar = ns.Bar
local S = ns.Style
local D = ns.Data
local W = ns.W
local P = ns.P

local bar
local seps = {}
local slots = {}          -- [1..3] 由左至右

-- 提示裡的名單上限。大公會不設限會長出一條蓋滿整個螢幕的提示，
-- 而超過三十行之後那張表已經不是「掃一眼」而是「找人」—— 那是公會面板的工作。
local function MaxRows()
    local n = ns.DB.Get().tipMaxRows
    return (n and n > 0) and n or math.huge
end

------------------------------------------------------------
-- 兩種讀數的定義
--
-- 做成表而不是兩段 if：左右哪一格放什麼是設定，加第三種讀數（例如「隊伍」）
-- 時只要往這裡多加一筆。
------------------------------------------------------------
local SOURCES = {}

SOURCES.guild = {
    label = function() return ns.L["Guild"] end,

    count = function()
        local online = D.GuildOnline()
        return online          -- nil = 沒公會
    end,

    -- 沒公會時整格變灰字「無公會」，不要顯示 0 —— 0 的意思是「有公會但沒人在線」，
    -- 兩件事的下一步動作完全不同。
    empty = function() return ns.L["No Guild"] end,

    tooltip = function(tip)
        local online, total = D.GuildOnline()
        if not online then
            tip:AddLine(ns.L["No Guild"], 1, 1, 1)
            return
        end
        local gname = ns.Secret.PlainText(GetGuildInfo("player"))
        local ar, ag, ab = S.Accent()   -- ⚠ 不能直接展開，見 Tip.AddSection 的註解
        tip:AddDoubleLine(gname or ns.L["Guild"],
            string.format("%d / %d", online, total or 0), ar, ag, ab, ar, ag, ab)

        local roster = D.GuildRoster()
        local zone = D.CurrentZone()
        local showZone = ns.DB.Get().tipShowZone
        local cap = MaxRows()

        if #roster == 0 then
            ns.Tip.AddSection(ns.L["Nobody else online."])
        else
            tip:AddLine(" ")
            for i, entry in ipairs(roster) do
                if i > cap then
                    tip:AddLine(ns.L["...and %d more"]:format(#roster - cap), S.TEXT_DIM[1], S.TEXT_DIM[2], S.TEXT_DIM[3])
                    break
                end
                ns.Tip.AddMember(entry, zone, showZone)
            end
        end
        ns.Tip.AddHint(ns.L["Left-click: guild roster"], ns.L["Right-click: whisper / invite"])
    end,

    click = function(btn, slot)
        if btn == "RightButton" then
            Bar.ShowMemberMenu("guild", slot)
        else
            ToggleGuildFrame()
        end
    end,
}

SOURCES.friends = {
    label = function() return ns.L["Friends"] end,

    count = function() return D.FriendsOnline() end,

    tooltip = function(tip)
        local favorites, others = D.FriendsRoster()
        local total = #favorites + #others
        local ar, ag, ab = S.Accent()
        tip:AddDoubleLine(ns.L["Friends"], tostring(total), ar, ag, ab, ar, ag, ab)

        local zone = D.CurrentZone()
        local showZone = ns.DB.Get().tipShowZone
        local cap = MaxRows()

        if total == 0 then
            ns.Tip.AddSection(ns.L["Nobody else online."])
        else
            local shown = 0
            -- 星號好友獨立一段排最前面。玩家標星號就是在說「這幾個先給我看」。
            if #favorites > 0 then
                ns.Tip.AddSection(ns.L["Favorites"])
                for _, entry in ipairs(favorites) do
                    if shown >= cap then break end
                    ns.Tip.AddMember(entry, zone, showZone)
                    shown = shown + 1
                end
            end
            if #others > 0 then
                if #favorites > 0 then
                    ns.Tip.AddSection(ns.L["Friends"])
                else
                    tip:AddLine(" ")
                end
                for _, entry in ipairs(others) do
                    if shown >= cap then
                        tip:AddLine(ns.L["...and %d more"]:format(total - shown), S.TEXT_DIM[1], S.TEXT_DIM[2], S.TEXT_DIM[3])
                        break
                    end
                    ns.Tip.AddMember(entry, zone, showZone)
                    shown = shown + 1
                end
            end
        end
        ns.Tip.AddHint(ns.L["Left-click: friends list"], ns.L["Right-click: whisper / invite"])
    end,

    click = function(btn, slot)
        if btn == "RightButton" then
            Bar.ShowMemberMenu("friends", slot)
        else
            ToggleFriendsFrame()
        end
    end,
}

------------------------------------------------------------
-- 收納袋那一格：不是讀數，是一顆按鈕
--
-- 它沒有 count/label（那兩個是給文字格用的），改用 `icon = true` 讓
-- 排版與更新兩邊都認得出「這格畫圖示、寬度固定」。
------------------------------------------------------------
SOURCES.bag = {
    icon = true,

    -- ⚠ 袋子開著的時候**不要再彈提示**。兩者從同一格的下緣往下長 ＝ 完全重疊，
    --   而提示在 TOOLTIP 層、袋子在 HIGH 層，提示永遠壓在上面 ——
    --   使用者看到的是「整排圖示被蓋了一層遮罩」，完全看不出跟提示有關。
    --   而且袋子已經開著的時候，提示那兩行（幾顆、左鍵打開）本來就沒用了。
    suppress = function() return ns.Buttons.IsOpen() end,

    tooltip = function(tip)
        local inBag, pinned = ns.Buttons.Counts()
        -- ⚠ 不能直接展開 S.Accent()（回四個值，第四個會被 AddLine 當成 wrapText）
        local ar, ag, ab = S.Accent()
        tip:AddLine(ns.L["Addon buttons"], ar, ag, ab)
        tip:AddLine(ns.L["%d in the bag, %d pinned"]:format(inBag, pinned), 1, 1, 1)
        ns.Tip.AddHint(ns.L["Left-click: open the bag"], ns.L["Right-click: settings"])
    end,

    click = function(btnName, slot)
        if btnName == "RightButton" then
            ns.Buttons.ShowMenu(slot)
        else
            ns.Buttons.Toggle(slot)
        end
    end,
}

------------------------------------------------------------
-- 右鍵選單：密語／邀請
--
-- ⚠ 密語與邀請的目標名字**必須是明文**。秘密字串餵進 SendChatMessage 或
--   `SetAttribute("macrotext", ...)` 都會被拒（見 wow-121-chat-reply-secret-taint）。
--   Data.lua 已經把每個 name 過了 PlainText，所以這裡拿到的都是明文；
--   撈不出明文的那幾筆在那邊就被丟掉了。
------------------------------------------------------------
local MENU_CAP = 30

local function MemberItems(list, action)
    local items = {}
    local n = 0
    for _, entry in ipairs(list) do
        if n >= MENU_CAP then break end
        -- ⚠ 兩道過濾，缺一個就會在選單裡看到空白列：
        --   ① 沒有名字的（戰網好友卡在選角畫面時 characterName 是空字串）
        --   ② 邀請清單裡邀不到的人（沒角色名、或在經典服那種跨版本的帳號）
        --      —— 密語照樣可以走戰網暱稱，所以只擋邀請。
        local skip = (not entry.name) or entry.name == ""
            or (action == "invite" and not entry.canInvite)
        if not skip then
        n = n + 1
        local hex = S.ClassHex(entry.class)
        -- 邀請一律用「角色名-伺服器」；密語則優先走戰網暱稱 —— 對方換角色、
        -- 甚至離開 WoW 之後那條路還通得到，角色名不行。
        local target = entry.full or entry.name
        local bnetName = entry.bnetName
        items[#items + 1] = {
            text = string.format("|c%s%s|r", hex, entry.name),
            onClick = function()
                if action == "invite" then
                    C_PartyInfo.InviteUnit(target)
                elseif bnetName and ChatFrame_SendBNetTell then
                    ChatFrame_SendBNetTell(bnetName)
                else
                    ChatFrame_SendTell(target)
                end
            end,
        }
        end
    end
    if #items == 0 then
        items[1] = { text = ns.L["Nobody else online."], isTitle = true }
    end
    return items
end

function Bar.ShowMemberMenu(kind, slot)
    local list
    if kind == "guild" then
        list = D.GuildRoster()
    else
        local fav, others = D.FriendsRoster()
        list = fav
        for _, e in ipairs(others) do list[#list + 1] = e end
    end

    local items = {
        { text = kind == "guild" and ns.L["Guild"] or ns.L["Friends"], isTitle = true },
        { text = ns.L["Whisper"], submenu = MemberItems(list, "whisper") },
        { text = ns.L["Invite"],  submenu = MemberItems(list, "invite") },
        { isSeparator = true },
        { text = ns.L["Settings"], onClick = function() ns.Options.Open() end },
    }
    W.Menu.Show(items, slot)
end

------------------------------------------------------------
-- 一格
------------------------------------------------------------
local NUM_SLOTS = 3

local function BuildSlot(index)
    local btn = CreateFrame("Button", nil, bar)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- hover 的視覺回饋走**底色明暗**，不換色（miliui-color-states 的核心規則）。
    -- alpha 0 = 平常完全看不見，只有滑過去才浮出一塊比條再亮一階的方塊。
    btn.hl = btn:CreateTexture(nil, "BACKGROUND")
    btn.hl:SetAllPoints(btn)
    btn.hl:SetColorTexture(1, 1, 1, 0.08)
    btn.hl:Hide()

    -- ⚠ 建出來就給字型。沒有字型物件的 FontString 一 SetText 就丟
    --   "Font not set"，而且會中斷整支初始化
    --   （見 .claude/notes/wow-fontstring-font-before-settext.md）。
    btn.text = btn:CreateFontString(nil, "OVERLAY")
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.text:SetJustifyH("CENTER")
    btn.text:SetWordWrap(false)
    S.SetFont(btn.text, ns.DB.Get().infoBarFontSize)

    btn:SetScript("OnEnter", function(self)
        self.hl:Show()
        -- 收納袋那格的圖示跟著亮起來。狀態只換明暗、色相不動
        -- （miliui-color-states 的核心規則）。
        if self.dots and self.sourceKey == "bag" then
            ns.Buttons.TintIcon(self, 1)
        end
        local src = SOURCES[self.sourceKey]
        if not src or not src.tooltip then return end
        if src.suppress and src.suppress() then ns.Tip.Close(); return end
        -- 提示往**下**長（資訊列貼在畫面上緣，往上開會被切掉），
        -- 左右對齊跟著格子在螢幕的哪一半走，才不會橫跨整個畫面。
        local left = (self:GetCenter() or 0) < (GetScreenWidth() or 1920) / 2
        local tip = ns.Tip.Open(self,
            left and "TOPLEFT" or "TOPRIGHT",
            left and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, -4)
        ns.Safe(src.tooltip, tip)
        tip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        self.hl:Hide()
        if self.dots and self.sourceKey == "bag" then
            ns.Buttons.TintIcon(self, S.STATE_ALPHA.idle)
        end
        ns.Tip.Close()
    end)

    btn:SetScript("OnClick", function(self, mouseBtn)
        local src = SOURCES[self.sourceKey]
        if src and src.click then ns.Safe(src.click, mouseBtn, self) end
    end)

    slots[index] = btn
    return btn
end

------------------------------------------------------------
-- 讀數更新
--
-- 只做 SetText，不碰版面。事件很密（公會名冊每次更新都發），
-- 這裡做任何 SetPoint 都會變成每秒好幾次的重排。
------------------------------------------------------------
local function UpdateSlot(btn)
    ns.Count("Bar.UpdateSlot")
    local src = SOURCES[btn.sourceKey]
    if not src or not btn.laidOut then
        btn:Hide()
        return
    end
    btn:Show()

    -- 圖示格（收納袋）沒有文字
    if src.icon then
        btn.text:SetText("")
        return
    end

    -- ⚠ 這裡**不要**包 ns.Meter。包了就得傳一個 closure，而 closure 是每次呼叫
    --   都會配置的 —— 即使剖析關著。量測工具自己變成配置點是最糟的一種 bug
    --   （ns.Fire 那裡已經踩過一次）。要量單次成本就直接量 Data 那一層。
    local n = src.count()
    if n == nil then
        -- 沒公會：灰字「無公會」。不要顯示 0 —— 0 的意思是「有公會但沒人在線」，
        -- 兩件事的下一步動作完全不同。
        btn.text:SetText(src.empty and src.empty() or "")
        btn.text:SetTextColor(unpack(S.TEXT_DIM))
        btn.lastN = nil    -- 退出這個狀態時要能重畫（例如重新加入公會）
        return
    end

    btn.text:SetTextColor(unpack(S.TEXT))
    -- ⚠ 內容沒變就不要重寫。`SetFormattedText` 每次都會**組一條新字串**
    --   （還要先組出 |cffXXXXXX 的色碼），而這支是掛在事件上的 ——
    --   公會名冊與好友狀態在大公會裡一秒可以發好幾十次。
    --   數字沒動的那幾十次全部是純垃圾。
    if btn.lastN ~= n then
        btn.lastN = n
        if ns.DB.Get().infoAccentNumbers then
            btn.text:SetFormattedText("%s |c%s%d|r", src.label(), S.AccentHex(), n)
        else
            btn.text:SetFormattedText("%s %d", src.label(), n)
        end
    end
end

local lastTipRefresh = 0

function Bar.Update()
    ns.Count("Bar.Update")
    if not bar or not bar:IsShown() then return end
    for _, btn in ipairs(slots) do UpdateSlot(btn) end

    -- 提示開著的時候順便重畫：公會有人上線時那張名單要跟著動，
    -- 不然玩家會看到「數字變了但名單沒變」。
    --
    -- ⚠ 但這是**整條路徑上最貴的一件事** —— 重建一張 30 列的名單要走一遍
    --   761 人的公會名冊，每一列還要 string.format 好幾次。而觸發它的事件
    --   （BN_FRIEND_INFO_CHANGED）是會連發的，所以自己再壓一道秒級節流。
    --   名單晚一秒更新，人眼看不出來。
    local now = GetTime()
    if now - lastTipRefresh < 1 then return end
    for _, btn in ipairs(slots) do
        if ns.Tip.IsOwnedBy(btn) then
            lastTipRefresh = now
            local enter = btn:GetScript("OnEnter")
            if enter then ns.Safe(enter, btn) end
        end
    end
end

------------------------------------------------------------
-- 事件合流
--
-- ⚠⚠ **`BN_FRIEND_INFO_CHANGED` 是消防水管。** 好友一換區域、改狀態、改廣播
--   都會發一次；三十個好友在打副本的時候一秒可以來好幾十發。把 Bar.Update
--   直接掛上去，等於把「掃一遍全部好友」掛上那個頻率。
--
--   （2026-08-30 第二輪：第一輪只在 D.FriendsOnline 加了 1 秒 TTL，那只是把
--   「每幀」壓成「每秒」—— 只要事件不停就永遠每秒掃一次，一小時還是好幾 MB。
--   TTL 是**地板**不是節流，真正該做的是讓事件本身合流。）
--
--   一連串事件只排一次更新，而且**分兩種急迫度**：
--     慢（5 秒）好友名單的雜訊 —— 人數晚五秒更新沒有人看得出來
--     快（0.5 秒）真的上下線／換公會 —— 這種要有反應
------------------------------------------------------------
local pending
local function Schedule(delay)
    if pending and pending <= delay then return end
    pending = delay
    C_Timer.After(delay, function()
        pending = nil
        ns.Safe(Bar.Update)
    end)
end

-- 只有雜訊事件走慢速；會真的改變人數的走快速（見下面的 EXACT_EVENTS）
local SLOW_EVENTS = {
    BN_FRIEND_INFO_CHANGED = true,
    GUILD_ROSTER_UPDATE = true,
}

-- ⚠ 這幾個是**人數真的會變**的時刻，而且很少發生 —— 讓好友快取強制失效，
--   其餘時間就吃 30 秒的 TTL。這樣「有人上線」還是即時反映，但閒著的時候
--   完全不會去掃那份 242 KB 的名單。
local EXACT_EVENTS = {
    BN_FRIEND_ACCOUNT_ONLINE = true,
    BN_FRIEND_ACCOUNT_OFFLINE = true,
    BN_CONNECTED = true,
    BN_DISCONNECTED = true,
    FRIENDLIST_UPDATE = true,
}

------------------------------------------------------------
-- 建框
------------------------------------------------------------
local function Build()
    if bar then return end

    bar = CreateFrame("Frame", "MiliUIMinimapInfoBar", UIParent, "BackdropTemplate")
    bar:SetFrameStrata("LOW")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    S.ApplyPanel(bar)
    ns.infoBar = bar

    for i = 1, NUM_SLOTS do
        BuildSlot(i)
        -- 分隔線一格一條（畫在該格的左緣），最左邊那條在排版時關掉。
        -- 只有 1px、alpha 很低 —— 它的工作是「告訴你這是幾個可以分別點的東西」，
        -- 不是切開版面。畫得跟外框一樣重就變成三個框並排了。
        seps[i] = bar:CreateTexture(nil, "ARTWORK")
        seps[i]:SetPoint("TOP", bar, "TOP", 0, -3)
        seps[i]:SetPoint("BOTTOM", bar, "BOTTOM", 0, 3)
        seps[i]:SetColorTexture(1, 1, 1, 0.12)
        seps[i]:Hide()
    end
end

------------------------------------------------------------
-- 排版：算出每一格多寬、擺在哪
--
-- 收納袋固定寬（正方形），其餘平分剩下的。選「無」的格子不佔位置。
------------------------------------------------------------
local function LayoutSlots(db, barW, barH)
    -- 第一遍：先知道有幾格是彈性的、固定的總共吃掉多少寬
    local keys = { db.infoSlot1, db.infoSlot2, db.infoSlot3 }
    local fixedTotal, flexCount = 0, 0
    for i = 1, NUM_SLOTS do
        local src = SOURCES[keys[i]]
        if src then
            -- 扣掉上下各 1px 的外框，格子的可用高就是 barH - 2；
            -- 寬用同一個數字才是真正的正方形。
            if src.icon then fixedTotal = fixedTotal + (barH - 2) else flexCount = flexCount + 1 end
        end
    end

    -- 全部選「無」：整條收起來，不要留一條空的深色橫槓在畫面上
    if fixedTotal == 0 and flexCount == 0 then
        for i = 1, NUM_SLOTS do
            slots[i].laidOut = false
            seps[i]:Hide()
        end
        return false
    end

    local flexW = flexCount > 0 and math.floor((barW - 2 - fixedTotal) / flexCount) or 0

    -- 第二遍：依序擺過去。x 是累加的，所以「無」自然不佔位置。
    local x = 1
    local first = true
    for i = 1, NUM_SLOTS do
        local btn, src = slots[i], SOURCES[keys[i]]
        btn.sourceKey = keys[i]
        if not src then
            btn.laidOut = false
            btn:Hide()
            seps[i]:Hide()
        else
            local w = src.icon and (barH - 2) or flexW
            btn.laidOut = true
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -1)
            btn:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 1)
            btn:SetWidth(w)
            -- 最左邊那格前面不畫線（那裡是外框）
            seps[i]:ClearAllPoints()
            seps[i]:SetPoint("LEFT", bar, "LEFT", x, 0)
            seps[i]:SetWidth(P.Scale(1))
            seps[i]:SetShown(not first)
            x = x + w
            first = false
        end
    end
    return true
end

------------------------------------------------------------
-- 套用設定
------------------------------------------------------------
function Bar.Apply()
    ns.Count("Bar.Apply")
    local db = ns.DB.Get()
    if not db.infoBar then
        if bar then bar:Hide() end
        return
    end

    Build()
    S.RefreshPanel(bar)

    local h = P.Scale(db.infoBarHeight)
    bar:SetHeight(h)
    bar:ClearAllPoints()
    local barW
    if db.infoBarAttached and ns.holder then
        -- 貼著地圖：寬度也跟著地圖走，兩件東西的左右緣要對齊到像素
        -- （見 project-miliui-pixel-snapping —— 差半格就會看到一條白邊）。
        bar:SetPoint("TOPLEFT", ns.holder, "BOTTOMLEFT", 0, -P.Scale(db.infoBarGap))
        bar:SetPoint("TOPRIGHT", ns.holder, "BOTTOMRIGHT", 0, -P.Scale(db.infoBarGap))
        barW = ns.holder:GetWidth()
    else
        barW = P.Scale(db.size)
        bar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", db.infoBarX, db.infoBarY)
        bar:SetWidth(barW)
    end
    bar:SetScale(db.scale)

    for _, btn in ipairs(slots) do
        S.SetFont(btn.text, db.infoBarFontSize)
    end

    -- 設定變動（換來源、開關職業色數字、換字級）之後標籤本身會變，
    -- 清掉 UpdateSlot 的去重快取讓它重畫一次
    for _, btn in ipairs(slots) do btn.lastN = nil end

    local any = LayoutSlots(db, barW, h)
    bar:SetShown(any)

    -- 收納袋那格的 3×3 圖示。⚠ 換到別的來源時要把點**藏起來** ——
    -- 貼圖建了就刪不掉（wow-frame-lifecycle-costs），只能顯隱。
    for _, btn in ipairs(slots) do
        local isBag = btn.laidOut and btn.sourceKey == "bag"
        if isBag then
            ns.Buttons.BuildIcon(btn, h - 2)
            ns.Buttons.TintIcon(btn, S.STATE_ALPHA.idle)
            for _, t in ipairs(btn.dots) do t:Show() end
        elseif btn.dots then
            for _, t in ipairs(btn.dots) do t:Hide() end
        end
    end

    Bar.Update()
end

------------------------------------------------------------
-- 事件
--
-- ⚠ 公會名冊要**主動要**：GetNumGuildMembers() 在沒有請求過的情況下可能是 0。
--   C_GuildInfo.GuildRoster() 有伺服器端節流（約 10 秒），所以可以放心在
--   進入世界與滑過去的時候各叫一次，叫太密它自己會忽略。
------------------------------------------------------------
-- ⚠ 這裡**故意不叫 Bar.Apply()**。
--   ns.Fire 的派送順序是 pairs()，不保證 Skin 的 Init 先跑 —— 先跑到這裡的話
--   ns.holder 還是 nil，「貼在地圖下緣」那條路走不到，資訊列會用絕對座標貼出去，
--   要到下一次設定變動才修正。改由 Skin.Apply 結尾的 SkinApplied 驅動，
--   順序就由呼叫鏈保證而不是靠運氣。
ns.RegisterCallback("Init", "Bar", function()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("GUILD_ROSTER_UPDATE")
    ev:RegisterEvent("PLAYER_GUILD_UPDATE")
    ev:RegisterEvent("FRIENDLIST_UPDATE")
    ev:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    ev:RegisterEvent("BN_CONNECTED")
    ev:RegisterEvent("BN_DISCONNECTED")
    ev:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    ev:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" and IsInGuild() then
            C_GuildInfo.GuildRoster()
        end
        if EXACT_EVENTS[event] then
            D.InvalidateFriends()          -- 人數真的變了：強制重算
        elseif event == "BN_FRIEND_INFO_CHANGED" then
            D.TouchFriends()               -- 可能變了：等 TTL 到期再說
        end
        Schedule(SLOW_EVENTS[event] and 5 or 0.5)
    end)
end)

ns.RegisterCallback("ConfigChanged", "Bar", function() ns.Safe(Bar.Apply) end)
ns.RegisterCallback("AccentChanged", "Bar", function() ns.Safe(Bar.Apply) end)
ns.RegisterCallback("SkinApplied", "Bar", function() ns.Safe(Bar.Apply) end)
ns.RegisterCallback("BagCountChanged", "Bar", function() ns.Safe(Bar.Update) end)
