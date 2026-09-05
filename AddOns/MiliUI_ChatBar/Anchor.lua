------------------------------------------------------------
-- 位置：吸附聊天視窗、跟著聊天視窗走
--
-- 「跟著走」不是靠 OnUpdate 追座標，而是直接把聊天列 SetPoint 在聊天視窗上——
-- 錨點是引擎自己維護的，聊天視窗被拖、被拉大，聊天列自動跟著跑，零成本。
-- 拖曳只在「放開的那一刻」判斷要不要吸；按住 Shift 放開就一定不吸。
--
-- 位置以前是交給暴雪的 SetUserPlaced 存的。改成自己存進 SavedVariables：
-- 錨在別的框上的位置暴雪存不了（它只記絕對座標），兩邊都想管就會互相蓋掉。
-- 舊玩家的位置在 Init 時抄一次過來，之後 UserPlaced 就關掉。
------------------------------------------------------------
local _, ns = ...

local Anchor = {}
ns.Anchor = Anchor

local SNAP_DIST = 2    -- 吸附判定距離（螢幕像素）：離 2px 以內才吸（使用者指定）
local SNAP_GAP  = 2    -- 吸上去之後留的縫

local function DB()
    ns.InitDB()
    return MiliUI_ChatBar_DB.Chatbar
end

------------------------------------------------------------
-- 聊天視窗是哪個框
--
-- Chattynator 會把暴雪的 ChatFrame1 整個 SetParent 到隱藏框，自己另開一組
-- **沒有名字**的視窗，而它的 addonTable 是區域變數，外面拿不到。唯一的公開路徑是
-- 那組視窗掛在全域的 ChattynatorHyperlinkHandler 底下 —— 列出子框、用
-- ChatFrameMixin 留在框上的欄位當指紋認出來。
--
-- 認不到就退回 ChatFrame1，但要確認它還掛在 UIParent 底下：被收走的那顆
-- 尺寸位置都還在（只是看不見），拿它當吸附對象會吸到畫面外。
------------------------------------------------------------
local function ChattynatorWindow()
    local host = ChattynatorHyperlinkHandler
    if not host or not host.GetChildren then return nil end
    local best
    for _, child in ipairs({ host:GetChildren() }) do
        if child.ScrollingMessages and child.TabsBar and child:IsShown() then
            if not best or child:GetID() == 1 then best = child end
        end
    end
    return best
end

function Anchor.GetChatFrame()
    local f = ChattynatorWindow()
    if f then return f end
    local cf = ChatFrame1
    if cf and cf:GetParent() == UIParent and cf:IsShown() then return cf end
    return nil
end

-- 聊天視窗現在多寬（換算成聊天列自己的座標單位）。
-- 兩個框的 scale 不一定一樣，直接拿 GetWidth 比會差一個縮放。
function Anchor.ChatWidth()
    local chat = Anchor.GetChatFrame()
    if not chat then return nil end
    local w = chat:GetWidth()
    if not w or w <= 0 then return nil end
    local bar = ns.Chatbar
    local bs = bar and bar:GetEffectiveScale() or 1
    if bs <= 0 then return nil end
    return w * chat:GetEffectiveScale() / bs
end

------------------------------------------------------------
-- 幾何
------------------------------------------------------------
-- 絕對螢幕座標。GetLeft() 這些回的是「框自己座標系」的值，兩個 scale 不同的框
-- 不能直接比大小，一律乘上 effective scale 拉到同一把尺上。
local function ScreenRect(f)
    local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
    if not l or not r or not t or not b then return nil end
    local s = f:GetEffectiveScale()
    return l * s, r * s, t * s, b * s
end

------------------------------------------------------------
-- 聊天視窗「內容」的底在哪
--
-- Chattynator 把輸入列（ChatFrame1EditBox）錨在視窗框的下緣、但往下伸出框外
-- 一截（Display/Main.lua 的 UpdateEditBox：偏移量是 clamp inset 算出來的）。
-- 拿框的下緣當吸附基準，聊天列就會蓋在輸入列上（2026-09-05 使用者回報）。
-- 所以「底」要取框下緣與輸入列下緣兩者較低的那個。輸入列沒錨在這顆視窗上
-- （輸入列在上方、或不是 Chattynator）就只看框。回傳螢幕座標。
------------------------------------------------------------
local function ContentBottom(chat)
    local _, _, _, cbm = ScreenRect(chat)
    if not cbm then return nil end
    local eb = ChatFrame1EditBox
    if eb and eb.GetPoint then
        local _, rel = eb:GetPoint(1)
        if rel == chat then
            local _, _, _, ebb = ScreenRect(eb)
            if ebb and ebb < cbm then return ebb, cbm - ebb end
        end
    end
    return cbm, 0
end

-- UIParent 現在在螢幕上的上下緣（螢幕座標）。資訊列停靠會把 UIParent 往內縮，
-- 聊天列的夾限與「下面還有沒有空間」都要看它，不是看螢幕。
local function ParentBounds()
    local s = UIParent:GetEffectiveScale()
    local t, b = UIParent:GetTop(), UIParent:GetBottom()
    if not t or not b then return nil end
    return t * s, b * s
end

-- 夾限跟著 UIParent 走：UIParent 被資訊列內縮時，聊天列不准掉進縮出來的那條
local function ApplyClamp(bar)
    local pt, pb = ParentBounds()
    if not pt then return end
    local screenTop = GetScreenHeight() * UIParent:GetEffectiveScale()
    local scale = bar:GetEffectiveScale()
    local topInset = math.max(0, screenTop - pt) / scale
    local bottomInset = math.max(0, pb) / scale
    -- 正值＝把夾限邊往內推（上緣是往下、下緣是往上），跟 ClampRectInsets 的方向一致
    bar:SetClampRectInsets(0, 0, -topInset, bottomInset)
end

------------------------------------------------------------
-- 套用位置
------------------------------------------------------------
local applyRetry

-- 預設位置＝吸在聊天視窗正下方、左緣對齊
local function DefaultPosition()
    return { attached = true, point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -SNAP_GAP }
end

function Anchor.Apply()
    local bar = ns.Chatbar
    if not bar then return end
    -- 聊天列本身不是受保護的框，但底下掛著一排 SecureActionButton；
    -- 戰鬥中一律不動版面，PLAYER_REGEN_ENABLED 會補跑（跟 UpdateLayout 同一套規矩）
    if InCombatLockdown() then return end

    local cb = DB()
    local chat = Anchor.GetChatFrame()
    Anchor.Watch(chat)
    if not chat then Anchor.RetryLater() end

    -- 全新安裝：預設吸在聊天視窗下。
    -- 聊天視窗還沒生出來就先不寫 DB —— 寫下去就變成「玩家自己選了左下角」，
    -- 而 Chattynator 的視窗是登入之後才建的，一開始一定拿不到。
    local pos = cb.Position
    if not pos and chat then
        pos = DefaultPosition()
        cb.Position = pos
    end

    bar:ClearAllPoints()
    ApplyClamp(bar)
    if pos and pos.attached and chat then
        local point, relPoint, y = pos.point, pos.relPoint, pos.y or 0
        if relPoint:find("^BOTTOM") then
            -- 吸在下方：從框下緣再往下讓出輸入列伸出來的那截
            local _, hang = ContentBottom(chat)
            local scale = bar:GetEffectiveScale()
            y = y - (hang or 0) / scale
            -- 下面放不下（會被夾限推回來蓋在聊天上）就改吸在上方。
            -- 只在套用時判斷、不寫回 DB：聊天視窗往上搬之後它就自己回到下面
            local _, cbm = ScreenRect(chat)
            local _, pb = ParentBounds()
            if cbm and pb then
                local barBottom = cbm - (hang or 0) + (pos.y or 0) * scale - bar:GetHeight() * scale
                if barBottom < pb then
                    point = point:gsub("^TOP", "BOTTOM")
                    relPoint = relPoint:gsub("^BOTTOM", "TOP")
                    y = SNAP_GAP
                end
            end
        end
        bar:SetPoint(point, chat, relPoint, pos.x or 0, y)
    elseif pos and not pos.attached then
        bar:SetPoint(pos.point or "BOTTOMLEFT", UIParent, pos.relPoint or "BOTTOMLEFT",
                     pos.x or 0, pos.y or 0)
    else
        -- 想吸但沒得吸：先擺左下角，等聊天視窗出現再吸回去
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    end
end

-- 聊天視窗晚一步才生出來（Chattynator 的視窗是登入之後才建的）。
-- 重試有次數上限，找不到就放棄 —— 玩家可能真的把聊天視窗關掉了，不能無限輪詢。
-- 一次只跑一條鏈：Apply 會被很多地方呼叫，不擋的話會疊出一堆計時器。
local RETRY_MAX = 12
local retrying = false

function Anchor.RetryLater()
    if retrying or (applyRetry or 0) >= RETRY_MAX then return end
    retrying = true
    applyRetry = (applyRetry or 0) + 1
    C_Timer.After(1, function()
        retrying = false
        if Anchor.GetChatFrame() then
            applyRetry = 0
            Anchor.Apply()
            if ns.UpdateLayout then ns.UpdateLayout() end
        else
            Anchor.RetryLater()
        end
    end)
end

------------------------------------------------------------
-- 聊天視窗改變大小 → 重排（總寬度對齊聊天視窗時才看得出來，但重排本身很便宜）
--
-- 一定要 HookScript 不能 SetScript：Chattynator 自己的 OnSizeChanged 要存視窗尺寸，
-- 蓋掉的話它的視窗大小就存不起來了。
------------------------------------------------------------
local watched = setmetatable({}, { __mode = "k" })

function Anchor.Watch(chat)
    if not chat or watched[chat] then return end
    watched[chat] = true
    chat:HookScript("OnSizeChanged", function()
        if ns.UpdateLayout then ns.UpdateLayout() end
    end)
    -- 視窗被拖過之後「下面還放不放得下」要重算（Apply 裡的上下翻面）
    chat:HookScript("OnDragStop", function() Anchor.Apply() end)
end

-- UIParent 尺寸一變（資訊列停靠推開、換解析度）夾限與翻面都要重算
UIParent:HookScript("OnSizeChanged", function()
    if ns.Chatbar then Anchor.Apply() end
end)

------------------------------------------------------------
-- 存位置
------------------------------------------------------------
-- 絕對座標：UIParent 的左下角就是螢幕 (0,0)，所以偏移量直接用 GetLeft/GetBottom
local function SaveAbsolute()
    local bar = ns.Chatbar
    local l, b = bar:GetLeft(), bar:GetBottom()
    if not l then return end
    DB().Position = {
        attached = false,
        point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT",
        x = math.floor(l + 0.5), y = math.floor(b + 0.5),
    }
end
Anchor.SaveAbsolute = SaveAbsolute

------------------------------------------------------------
-- 吸附判定
--
-- 只吸上下：聊天列是一條，貼在聊天視窗上緣或下緣才有意義。左右再各判一次
-- 「左緣對左緣 / 右緣對右緣」，兩邊都不近就維持原本的水平位置（只吸垂直）。
-- 回傳 Position 表；不該吸就回 nil。
------------------------------------------------------------
local function ComputeSnap()
    local bar = ns.Chatbar
    local chat = Anchor.GetChatFrame()
    if not chat then return nil end

    local bl, br, bt, bb = ScreenRect(bar)
    local cl, cr, ct = ScreenRect(chat)
    local cbm = ContentBottom(chat)   -- 含輸入列伸出來的那截
    if not bl or not cl or not cbm then return nil end

    -- 整條跑到聊天視窗左邊或右邊去了就不算「貼著」
    if br < cl - SNAP_DIST or bl > cr + SNAP_DIST then return nil end

    local point, relPoint, oy
    if math.abs(bt - cbm) <= SNAP_DIST then
        point, relPoint, oy = "TOP", "BOTTOM", -SNAP_GAP      -- 吸在下方
    elseif math.abs(bb - ct) <= SNAP_DIST then
        point, relPoint, oy = "BOTTOM", "TOP", SNAP_GAP       -- 吸在上方
    else
        return nil
    end

    local scale = bar:GetEffectiveScale()
    local ox
    if math.abs(bl - cl) <= SNAP_DIST then
        point, relPoint, ox = point .. "LEFT", relPoint .. "LEFT", 0
    elseif math.abs(br - cr) <= SNAP_DIST then
        point, relPoint, ox = point .. "RIGHT", relPoint .. "RIGHT", 0
    else
        point, relPoint, ox = point .. "LEFT", relPoint .. "LEFT", (bl - cl) / scale
    end

    return { attached = true, point = point, relPoint = relPoint,
             x = math.floor(ox + 0.5), y = oy }
end

-- 拖曳放開。allowSnap 為 false（按住 Shift）就純粹記絕對座標。
function Anchor.OnDragStop()
    local cb = DB()
    local allowSnap = cb.GroupWithChat and not IsShiftKeyDown()
    local snapped = allowSnap and ComputeSnap() or nil
    if snapped then
        cb.Position = snapped
    else
        SaveAbsolute()
    end
    Anchor.Apply()
    if ns.UpdateLayout then ns.UpdateLayout() end
end

------------------------------------------------------------
-- 設定改變
------------------------------------------------------------
-- 「同組」關掉 → 把現在的位置固定成絕對座標，聊天視窗再怎麼拖都不再跟。
-- 「同組」打開 → 現在就貼著聊天視窗的話直接吸上去，沒貼著就維持原位。
--
-- ⚠ 只在**這個開關真的翻面**的時候動位置。設定頁的 Apply 是「整組重套一次」，
--   每動一次字級、按鈕高度都會走到這裡；不記上一次的值的話，玩家按著 Shift
--   拖開的聊天列會在調下一個滑桿時莫名其妙又吸回去。
local lastGrouped
function Anchor.OnSettingsChanged()
    local cb = DB()
    local grouped = cb.GroupWithChat and true or false
    local pos = cb.Position

    if lastGrouped ~= nil and grouped ~= lastGrouped then
        if not grouped then
            if pos and pos.attached then SaveAbsolute() end
        elseif not (pos and pos.attached) then
            local snapped = ComputeSnap()
            if snapped then cb.Position = snapped end
        end
    end

    lastGrouped = grouped
    Anchor.Apply()
end

-- 重置：回到預設的「吸在聊天視窗下」；沒有聊天視窗就回左下角
function Anchor.Reset()
    local cb = DB()
    if cb.GroupWithChat and Anchor.GetChatFrame() then
        cb.Position = DefaultPosition()
    else
        cb.Position = { attached = false, point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 0, y = 0 }
    end
    Anchor.Apply()
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
function Anchor.Init()
    local bar = ns.Chatbar
    if not bar then return end
    local cb = DB()

    if type(cb.Position) ~= "table" then
        -- 舊版位置存在暴雪的 layout-local 裡（SetUserPlaced）。這時候暴雪已經把框
        -- 擺回去了，抄一份進 DB 再關掉 UserPlaced，之後位置全部自己管。
        -- 抄到的如果就是程式寫死的初始值，代表玩家從來沒搬過 ⇒ 留 nil 走預設吸附。
        local p, relTo, rp, x, y = bar:GetPoint(1)
        local onUIParent = (relTo == nil or relTo == UIParent)
        local untouched = (p == "BOTTOMLEFT" and rp == "BOTTOMLEFT"
                           and (x or 0) == 0 and (y or 0) == 0)
        if p and onUIParent and not untouched then
            cb.Position = { attached = false, point = p, relPoint = rp or p,
                            x = x or 0, y = y or 0 }
        end
    end

    bar:SetUserPlaced(false)
    lastGrouped = cb.GroupWithChat and true or false
    applyRetry = 0
    Anchor.Apply()
end

------------------------------------------------------------
-- /mcb debug：幾何現況（吸錯位置時先看這個，再猜）
------------------------------------------------------------
function Anchor.Debug()
    local bar = ns.Chatbar
    local chat = Anchor.GetChatFrame()
    local cb = DB()
    local function rect(f)
        local l, r, t, b = ScreenRect(f)
        if not l then return "nil" end
        return ("L%.0f R%.0f T%.0f B%.0f"):format(l, r, t, b)
    end
    print("|cff00ff00MiliUI ChatBar debug|r")
    print("  bar   " .. rect(bar))
    print("  chat  " .. (chat and rect(chat) or "nil") .. (chat and ("  contentBottom=%.0f hang=%.0f"):format(ContentBottom(chat)) or ""))
    if ChatFrame1EditBox then
        local _, rel = ChatFrame1EditBox:GetPoint(1)
        print("  edit  " .. rect(ChatFrame1EditBox) .. "  anchoredToChat=" .. tostring(rel == chat) .. " shown=" .. tostring(ChatFrame1EditBox:IsShown()))
    end
    local pt, pb = ParentBounds()
    print(("  UIParent top=%.0f bottom=%.0f screenTop=%.0f"):format(pt or -1, pb or -1, GetScreenHeight() * UIParent:GetEffectiveScale()))
    local p = cb.Position
    print("  Position " .. (p and ("attached=%s %s->%s x=%s y=%s"):format(tostring(p.attached), tostring(p.point), tostring(p.relPoint), tostring(p.x), tostring(p.y)) or "nil")
        .. "  group=" .. tostring(cb.GroupWithChat))
    local a1, a2, a3, a4, a5 = bar:GetPoint(1)
    print("  live point " .. tostring(a1) .. " -> " .. tostring(a2 and a2.GetName and a2:GetName() or (a2 == chat and "chat" or a2)) .. "." .. tostring(a3) .. " " .. tostring(a4) .. "," .. tostring(a5))
end
