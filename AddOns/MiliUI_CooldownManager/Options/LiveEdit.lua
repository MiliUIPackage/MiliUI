------------------------------------------------------------
-- 畫面編輯（2026-11-21）：設定視窗開著時，每一條「條」在它畫面上的實際位置畫一份完整的假格，玩家看著畫面直接改。
-- 2026-11-22 使用者實機後改：**一開設定視窗就是這個樣子**，不必另外按一顆鈕；那顆鈕改叫「隱藏設定介面」，
-- 只管把視窗收成一條（Options.SetCompact）讓出畫面，跟假格畫不畫無關。
--
--   LE.Active()          唯一的判準：設定視窗顯示中（收合不收合都算）且 不在暴雪編輯模式 且 不在戰鬥
--                        （InCombatLockdown()，加上自己在 PLAYER_REGEN_DISABLED 當下同步設的旗標）。
--                        假格要不要畫、真實條要不要壓、點擊層要不要讓位，全部問它
--   LE.Wants(key)        Active() 而且這條能畫假格（點擊層問這支決定讓不讓位：跟 Refresh 的先後無關）
--   LE.Suppresses(key)   這條現在真的畫著假格（Visibility.Alpha 最前面問：是 ⇒ 真實的條 alpha 0）
--   LE.Refresh()         照 Active() 建／顯示／收起每條的宿主；畫著哪幾條變了才重套 alpha、覆蓋層、點擊層
--
-- 畫什麼：就是設定頁的預覽那一套（Preview.Create 的 bare 模式）——連現在沒亮的增益、沒點的天賦、
-- 「不顯示」的格都列出來，暗格與記號的規則、左鍵開逐法術小窗（貼在那一格旁邊）、中鍵移除、拖曳排序、
-- 尾端「＋」開挑選器，都是同一份 Fill／Wire。放置目標換成本檔（BeginDrop／DropTargetAtCursor／
-- ButtonAtCursor／EndDrop，跟左欄 ns.Sidebar 同名同語意）：拖到**另一條的假格區**上＝搬到那一條，
-- 放不進去的照舊跳原因（Preview.DropRefusal）。
--
-- 條名籤（每條假格**左上角外側**一組「［條名］［＋］」，左緣對齊假格左緣、貼在上緣上面；HUD 皮：黑透明底、1px 職業色邊、
-- 白字、直角；「＋」＝加入法術，預覽在畫面編輯模式不畫自己的「＋」格。2026-11-22 使用者實機兩次調整：「＋」原本掛在每條
-- 右邊／下面，位置每條不同、空條那顆又跟籤不等高，很亂 ⇒ 併成一組；整組原本放左邊，會壓到左邊的單位框 ⇒ 改左上）：
--   拖＝移動那一條（EM.BeginDrag／EndDrag，同點擊層）、左鍵＝展開設定視窗並切到那一條、右鍵＝點擊層那份條選單（CL.ShowMenu）、
--   方向鍵微調（EM.KeyOfSelection 認得它）。
--   放上方的代價：條一條疊一條時，下一條的籤會壓在上一條最後一列的左下角（籤只有 18 高，使用者看過後選這個）。
--
-- 宿主：每條一個自己的框（parent UIParent、strata HIGH），裡面是 bare 預覽；預覽框錨在真實容器的
-- Bars.AnchorPoint(key) 同一點（格子座標＝Layout.Compute 的 rect 原值 ⇒ 每一格疊在真實那一格的位置）。
-- 容器被拖著走時假格跟著走。框池化、不丟（frame 刪不掉）；只在戰鬥外建、戰鬥外顯示。
-- 面板（資源條、施法條…）不畫假格，照舊蓋點擊層（點了＝展開並切頁：Options.ShowPage 收合時會先展開）。
--
-- 離開：關視窗（含 ESC）、進戰鬥、進暴雪編輯模式（收合著的視窗跟著展開）。
-- ⚠ 進戰鬥那一刻（PLAYER_REGEN_DISABLED，鎖定還沒生效）**同步**把真實條的 alpha 還回去：先設 combat 旗標
--   （Suppresses 從這一刻起回 false），當場 Visibility.ApplyAll，再收假格。Visibility 自己還有兩道戰鬥閘
--   （它的 inCombat 與 InCombatLockdown()），任何一條路讓這裡在戰鬥中還說「壓」都壓不下去。
--   脫戰（0.15 秒後，等 Visibility 自己 0.1 秒的脫戰緩衝過去）若視窗還是收合的就恢復畫面編輯。
--
-- 查清楚再決定的三件事（2026-11-21 讀碼）：
--   1. 跟著游標的自訂圖示群組（Core/Cursor.lua）：Cur.Following 在設定視窗開著時（optionsShown 旗標＋
--      panel:IsShown()）一律 false，容器回到存檔位置、不跟游標 ⇒ 收合也是「開著」，這種條照樣畫假格、照樣壓真實條。
--      錨定選單項目照每頁摘要列的規矩：跟著游標的條不列（摘要列那時是停用的）。
--   2. 可點擊的群組（Core/Clickable.lua）：secure 鈕是容器的子框（level 容器 +40），alpha 只影響畫，
--      **容器 alpha 0 之後鈕照樣收滑鼠**。條的 strata 存檔固定 MEDIUM（Core/DB.lua，設定頁沒有改它的控件），
--      假格的宿主是 HIGH ⇒ 假格整片蓋在鈕上面，點到的是假格。假格沒蓋到的地方（假格比真實格少的情況
--      不存在：假格是完整清單）理論上沒有鈕露出來。**未實機**：見回報的待驗清單。
--   3. 設定視窗的子彈窗（確認、選擇、輸入 ID、挑選器的欄位／預設清單小窗）是**對視窗置中**的（共用層
--      W.CreateConfirmPopup／CreateChoicePopup／CreateInputPopup、Picker 的三個小窗都是 SetPoint("CENTER")），
--      遮罩 SetAllPoints(視窗)。視窗收成一條之後：彈窗照樣置中在那一條上、比它高的部分上下凸出去；
--      遮罩只剩那一條大（擋不住畫面上的假格，這是可以接受的）。條貼在螢幕上下緣時凸出去的部分會被切掉
--      ⇒ 收合時把視窗的夾邊範圍上下各撐大（Options/Panel.lua 的 COMPACT_CLAMP），整條被推離邊緣、彈窗放得下。
--      不改共用層。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.LiveEdit = {}
local LE = ns.LiveEdit

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local TAG_H, TAG_PAD, TAG_GAP = 18, 6, 4
local HUD_BG, HUD_BG_HOT = 0x1A / 255, 0.2

local hosts = {}            -- key → { holder, pv, tag, edge }（池化，不丟）
LE.hosts = hosts            -- 除錯／測試用
local drawn = {}            -- key → true：這條現在畫著假格（Suppresses 看這個）
local combat = false        -- PLAYER_REGEN_DISABLED 當下同步設；脫戰 0.15 秒後清

------------------------------------------------------------
-- 判準
------------------------------------------------------------
function LE.Active()
    if combat or InCombatLockdown() then return false end
    if ns.released then return false end
    local O = ns.Options
    local panel = O and O.panel
    if not (panel and panel:IsShown()) then return false end
    if ns.EditMode and ns.EditMode.active then return false end
    return true
end

-- 這條能不能畫假格：是條（不是面板）、容器在、不是閒置的、容器的幾何讀得到明文
-- （錨在外部單位框上、秘密錨點沿錨定鏈傳染的條：假格錨在它身上也會讀回秘密值，拖曳排序要拿格子中心做算術 ⇒ 不畫，留給點擊層）
function LE.Eligible(key)
    local p = ns.profile
    local bar = p and type(p.bars) == "table" and p.bars[key]
    if type(bar) ~= "table" then return false end
    local B = ns.Bars
    local c = B and B.Get(key)
    if not c then return false end
    if B.Dormant and B.Dormant(key) then return false end
    local l, t = c:GetLeft(), c:GetTop()
    if ns.IsSecret(l) or ns.IsSecret(t) then return false end
    return type(l) == "number" and type(t) == "number"
end

function LE.Wants(key)
    return LE.Active() and LE.Eligible(key)
end

-- ⚠ 戰鬥中一律 false（Active 查 InCombatLockdown 與 combat 旗標；Visibility 那邊另有兩道閘）
function LE.Suppresses(key)
    return drawn[key] == true and LE.Active()
end

------------------------------------------------------------
-- 條名籤
------------------------------------------------------------
local function PaintTag(tag, hot)
    local px = P.Pixel(1)
    if tag.edgePx ~= px then
        tag.edgePx = px
        tag:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = px })
        if ns.NoSnapBackdrop then ns.NoSnapBackdrop(tag) end
    end
    local g = hot and HUD_BG_HOT or HUD_BG
    tag:SetBackdropColor(g, g, g, hot and 0.95 or 0.8)
    tag:SetBackdropBorderColor(W.Accent(1))
    tag.text:SetTextColor(1, 1, 1, hot and 1 or 0.9)
end

local function TagTip(tag, key)
    GameTooltip:SetOwner(tag, "ANCHOR_TOP")
    GameTooltip:SetText(ns.Options.PageTitle(key) or ns.Options.BarTitle(key))
    GameTooltip:AddLine(L["Click to open this bar's settings."], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["Right-click: more options"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["Drag to move. Hold Shift to disable snapping."], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["Hover a bar and press the arrow keys to nudge it by 1 (Shift: 10)."], 0.8, 0.8, 0.8)
    GameTooltip:Show()
    if ns.EditMode and ns.EditMode.AppendHint then ns.EditMode.AppendHint(tag, key) end
end

local function NewTag(holder, key)
    local tag = CreateFrame("Button", nil, holder, "BackdropTemplate")
    tag:SetFrameLevel(holder:GetFrameLevel() + 60)
    tag:SetClampedToScreen(true)
    tag:EnableMouse(true)
    tag:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tag:RegisterForDrag("LeftButton")
    local fs = tag:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetPoint("CENTER", tag, "CENTER", 0, 0)
    fs:SetWordWrap(false)
    tag.text = fs
    tag:SetScript("OnDragStart", function()
        GameTooltip:Hide()
        if ns.EditMode and ns.EditMode.BeginDrag then ns.EditMode.BeginDrag(key) end
    end)
    tag:SetScript("OnDragStop", function()
        if ns.EditMode and ns.EditMode.EndDrag then ns.EditMode.EndDrag(true) end
    end)
    tag:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if ns.ClickLayer and ns.ClickLayer.ShowMenu then ns.ClickLayer.ShowMenu(key, nil, self) end
            return
        end
        GameTooltip:Hide()
        ns.Options.ShowPage(key)          -- 收合中 ⇒ 先展開
    end)
    tag:SetScript("OnEnter", function(self)
        PaintTag(self, true)
        TagTip(self, key)
    end)
    tag:SetScript("OnLeave", function(self)
        PaintTag(self, false)
        GameTooltip:Hide()
    end)
    tag.key = key
    return tag
end

-- 「＋」（加入法術）：跟條名籤同一張皮、同高，緊貼在籤的右邊併成一組（共用中間那條邊）。
-- 每條只有這一組控件、位置都一樣（假格左邊、上緣對齊）；空條也就是「條名＋」一組，不另外冒一顆大小不同的「＋」
local function NewPlus(holder, key)
    local b = CreateFrame("Button", nil, holder, "BackdropTemplate")
    b:SetFrameLevel(holder:GetFrameLevel() + 60)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp")
    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    fs:SetText("+")
    b.text = fs
    b:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        if ns.Picker then ns.Picker.Open(key, self) end
    end)
    b:SetScript("OnEnter", function(self)
        PaintTag(self, true)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Add spells to this bar"])
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        PaintTag(self, false)
        GameTooltip:Hide()
    end)
    return b
end

-- 方向鍵微調：游標停在哪一條的條名籤上（EM.KeyOfSelection 問；不是籤回 nil）
function LE.KeyOfTag(f)
    if not f then return nil end
    for key, h in pairs(hosts) do
        if h.tag == f and drawn[key] then return key end
    end
    return nil
end

------------------------------------------------------------
-- 宿主
------------------------------------------------------------
local function Ensure(key)
    local h = hosts[key]
    if h then return h end
    if InCombatLockdown() or not (ns.Preview and ns.Preview.Create) then return nil end
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetFrameStrata("HIGH")
    holder:SetSize(1, 1)
    holder:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    holder:Hide()
    local pv = ns.Preview.Create(holder, key, nil, { bare = true, drop = LE })
    -- 可以放的條：拖曳中亮 1px 職業色框（滑過的那條全亮＋淡淡的底）
    local edge = CreateFrame("Frame", nil, pv.frame, "BackdropTemplate")
    edge:SetPoint("TOPLEFT", pv.frame, "TOPLEFT", -2, 2)
    edge:SetPoint("BOTTOMRIGHT", pv.frame, "BOTTOMRIGHT", 2, -2)
    edge:SetFrameLevel(pv.frame:GetFrameLevel() + 50)
    edge:EnableMouse(false)
    edge:Hide()
    h = { holder = holder, pv = pv, tag = NewTag(holder, key), plus = NewPlus(holder, key), edge = edge }
    hosts[key] = h
    -- 預覽每次重畫完（設定變了、增刪格）：照新的大小與錨點重貼
    pv.onRefresh = function() LE.Place(key) end
    -- 引擎重排比預覽晚（設定改了 0.2 秒後才套）：成長方向一換，容器的錨點跟著換，那時才重貼得對。
    -- 自己的容器，掛它的 OnSizeChanged 沒有污染問題
    local c = ns.Bars and ns.Bars.Get(key)
    if c and c.HookScript then
        c:HookScript("OnSizeChanged", function()
            if drawn[key] then LE.Place(key) end
        end)
    end
    return h
end

-- 預覽框錨到真實容器的同一個錨點；條名籤那一組貼在框的左上角外側（左緣對齊、在上緣上面）
function LE.Place(key)
    local h = hosts[key]
    local c = ns.Bars and ns.Bars.Get(key)
    if not (h and c) then return end
    local ap = ns.Bars.AnchorPoint(key)
    local f = h.pv.frame
    f:ClearAllPoints()
    f:SetPoint(ap, c, ap, 0, 0)
    local tag = h.tag
    tag.text:SetText(ns.Options.PageTitle(key) or ns.Options.BarTitle(key))
    local w = math.ceil(tag.text:GetStringWidth() or 0) + TAG_PAD * 2
    P.Size(tag, math.max(TAG_H, w), TAG_H)
    -- 一組：［條名］［＋］，左緣對齊假格左緣、貼在上緣上面；兩顆疊 1px，中間只有一條邊
    local plus = h.plus
    P.Size(plus, TAG_H, TAG_H)
    tag:ClearAllPoints()
    tag:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, TAG_GAP)
    plus:ClearAllPoints()
    plus:SetPoint("TOPLEFT", tag, "TOPRIGHT", -P.Pixel(1), 0)
    PaintTag(tag, tag:IsMouseOver())
    PaintTag(plus, plus:IsMouseOver())
end

local function PaintEdge(h, a, fill)
    local e = h.edge
    local px = P.Pixel(1)
    if e.edgePx ~= px then
        e.edgePx = px
        e:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = px })
        if ns.NoSnapBackdrop then ns.NoSnapBackdrop(e) end
    end
    e:SetBackdropBorderColor(W.Accent(a))
    local r, g, b = W.Accent(1)
    e:SetBackdropColor(r, g, b, fill and 0.15 or 0)
    e:Show()
end

local function HideHost(key)
    local h = hosts[key]
    drawn[key] = nil
    if not h then return end
    -- 拖到一半被收掉（進戰鬥、關視窗）：當作沒放手
    if h.pv.press then h.pv:EndDrag(false) end
    h.edge:Hide()
    h.holder:Hide()
end

-- 畫著哪幾條變了：真實條的 alpha、編輯模式覆蓋層（假格那幾條收起來）、點擊層（讓位）跟著對一次
local function Changed()
    if ns.Visibility and ns.Visibility.ApplyAll then ns.Visibility.ApplyAll() end
    if ns.EditMode and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
    if ns.ClickLayer and ns.ClickLayer.Refresh then ns.ClickLayer.Refresh() end
end

function LE.Refresh()
    local active = LE.Active()
    local seen = {}
    local changed = false
    if active then
        local p = ns.profile
        for key in pairs(p and type(p.bars) == "table" and p.bars or {}) do
            if LE.Eligible(key) then
                local h = Ensure(key)
                if h then
                    seen[key] = true
                    h.holder:Show()
                    h.pv:Refresh()            -- 結尾 onRefresh → Place
                    if not drawn[key] then drawn[key] = true; changed = true end
                end
            end
        end
    end
    for key in pairs(hosts) do
        if not seen[key] then
            if drawn[key] then changed = true end
            HideHost(key)
        end
    end
    for key in pairs(drawn) do
        if not seen[key] then drawn[key] = nil; changed = true end
    end
    if changed then Changed() end
end

------------------------------------------------------------
-- 放置目標（Preview 的拖曳；跟 ns.Sidebar 同名同語意）
------------------------------------------------------------
local dropCands, dropFrom, dropHover

-- 游標底下是哪一條的假格（來源條自己優先：游標還在自己那一塊上就不算別條，兩條疊著時才能照常排序）
local function HostAtCursor()
    local src = dropFrom and hosts[dropFrom]
    if src and drawn[dropFrom] and src.pv.frame:IsMouseOver() then return nil end
    -- 條名籤那一組也算那一條（空條的假格區只有一格大，放在名字上比較好瞄）
    for key, h in pairs(hosts) do
        if drawn[key] and key ~= dropFrom
            and (h.pv.frame:IsMouseOver() or h.tag:IsMouseOver() or h.plus:IsMouseOver()) then return key end
    end
    return nil
end

function LE.BeginDrop(candidates, fromKey)
    dropCands, dropFrom, dropHover = candidates or {}, fromKey, nil
    for key, h in pairs(hosts) do
        if drawn[key] and key ~= fromKey and dropCands[key] then PaintEdge(h, 0.6, false) end
    end
end

function LE.DropTargetAtCursor()
    if not dropCands then return nil end
    local key = HostAtCursor()
    local hit = (key and dropCands[key]) and key or nil
    if hit ~= dropHover then
        local old = dropHover and hosts[dropHover]
        if old then PaintEdge(old, 0.6, false) end
        local new = hit and hosts[hit]
        if new then PaintEdge(new, 1, true) end
        dropHover = hit
    end
    return hit
end

-- 游標底下的別條（不管能不能放）：放不進去的要說為什麼
function LE.ButtonAtCursor()
    if not dropCands then return nil end
    return HostAtCursor()
end

function LE.EndDrop()
    dropCands, dropFrom, dropHover = nil, nil, nil
    for _, h in pairs(hosts) do h.edge:Hide() end
end

------------------------------------------------------------
-- 戰鬥
------------------------------------------------------------
-- 進戰鬥那一刻：旗標 → 同步還 alpha → 收假格（每一步各自隔離，前面炸了後面照做）
function LE.OnCombatStart()
    combat = true
    if ns.Visibility and ns.Visibility.ApplyAll then xpcall(ns.Visibility.ApplyAll, ns.ReportError) end
    for key in pairs(hosts) do xpcall(HideHost, ns.ReportError, key) end
    for key in pairs(drawn) do drawn[key] = nil end
    if ns.EditMode and ns.EditMode.RequestRefresh then xpcall(ns.EditMode.RequestRefresh, ns.ReportError) end
end

------------------------------------------------------------
-- 排程：跟點擊層同一批回呼，下一幀對一次
------------------------------------------------------------
local armed = false
local function Later()
    if armed then return end
    armed = true
    ns.Defer(function()
        armed = false
        LE.Refresh()
    end)
end
LE.Later = Later

ns.RegisterCallback("OptionsShown", "liveedit", Later)
ns.RegisterCallback("OptionsHidden", "liveedit", function() LE.Refresh() end)
ns.RegisterCallback("OptionsCompactChanged", "liveedit", Later)
-- 進暴雪編輯模式：畫面編輯結束、視窗跟著展開（編輯模式有自己的覆蓋層與選取框）
ns.RegisterCallback("EditModeChanged", "liveedit", function(on)
    local O = ns.Options
    if on and O and O.IsCompact and O.IsCompact() and O.SetCompact then O.SetCompact(false) end
    Later()
end)
ns.RegisterCallback("BarsListChanged", "liveedit", Later)
ns.RegisterCallback("ProfileChanged", "liveedit", Later)
ns.RegisterCallback("BarMoved", "liveedit", Later)
ns.RegisterCallback("SpecChanged", "liveedit", Later)
ns.RegisterCallback("CatalogChanged", "liveedit", Later)
ns.RegisterCallback("AnchorChanged", "liveedit", Later)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        LE.OnCombatStart()
    else
        C_Timer.After(0.15, function()
            if InCombatLockdown() then return end
            combat = false
            Later()
        end)
    end
end)
