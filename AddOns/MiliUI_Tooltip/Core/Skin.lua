------------------------------------------------------------
-- Skin 引擎：每個 tooltip 一個自有的 overlay 框
--
-- 設計核心（taint 圍堵）：
--   * 背景、邊框、遮罩、大陣營圖、血條全部畫在**自己的** skin frame 上，
--     暴雪的 tooltip 只被動當定位參考（SetAllPoints，錨點解算在 C 端）。
--   * skin 是 tip 的 child、frameLevel 壓在 tip 之下 ⇒ 蓋不到文字，
--     tooltip 顯示/隱藏時 skin 自動跟著，不需要 OnShow/OnHide 掛勾。
--   * 純貼圖、零 SetBackdrop ⇒ 沒有材質重建成本，也沒有跟暴雪
--     SetBackdropStyle 的攻防戰（TinyTooltip 效能地板的根源）。
--   * 上色一律 SetVertexColor（吃秘密分量）。
--   * per-tip 狀態放這裡的 State[tip]，暴雪物件上零欄位寫入。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local P = ns.P
local Media = ns.Media

ns.Skin = {}
local Skin = ns.Skin

local State = {}      -- [tip] = state
Skin.State = State

function Skin.Get(tip)
    return tip and State[tip] or nil
end

-- 走訪所有已接管的 tooltip
function Skin.Each(fn)
    for tip, state in pairs(State) do
        fn(tip, state)
    end
end

------------------------------------------------------------
-- 共用輪詢：**只有在有 tooltip 顯示中的時候才跑**
--
-- 有兩件事需要輪詢（血條的數值、mouseover 的目標行），兩邊原本各自開一個永久顯示的
-- driver frame 掛 OnUpdate，內部累加到門檻才做事。問題不在做事那部分，而是
-- **OnUpdate 本身每一幀都會進 Lua**：兩支加起來在 144fps 是每秒約 300 次空轉，
-- 從登入到登出，即使畫面上根本沒有任何提示。（2026-08-28 體檢抓到。）
--
-- 這裡收成一支 ticker，並且掛在「有沒有 tooltip 在顯示」上：沒有提示的時候
-- ticker 根本不存在。形狀照 MiliUI_UnitFrames/Core/Events.lua 的 ns.Metro
-- （那邊是綁在單位框的可見度上），同一個結論：整張表空了就要停得掉。
--
-- ⚠ 判斷可見度用的是我們**自己的** skin frame 的 OnShow/OnHide，不是掛暴雪 tooltip
--   的腳本。skin 是 tip 的 child，父層一藏子層就跟著發 OnHide，等價而且零接觸面。
------------------------------------------------------------
-- 共用 ticker 在 Libs/MiliUIWidgets/Metro.lua（逐項隔離、沒項目就不存在都在那裡）。
-- 基礎心跳 0.05 秒，要比任何一個 interval 短。
local poll = ns.Metro.New(0.05, ns.ReportError)
Skin.Poll = poll.Add
Skin.Unpoll = poll.Remove

local shownCount = 0

-- skin 的 OnShow/OnHide 呼叫；state.visible 當去重閘，避免計數飄掉
local function NoteVisibility(state, visible)
    if state.visible == visible then return end
    state.visible = visible
    shownCount = shownCount + (visible and 1 or -1)
    if shownCount < 0 then shownCount = 0 end
    poll.SetEnabled(shownCount > 0)
end

------------------------------------------------------------
-- 一次性視覺中和：把暴雪自己的底框藏起來（alpha，不動結構、不掛勾）
-- 動態 forbidden 有可能發生，所以每次都閘。
------------------------------------------------------------
local function NeutralizeNineSlice(tip)
    if S.IsForbiddenObject(tip) then return end
    local nine = tip.NineSlice
    if nine and not S.IsForbiddenObject(nine) and nine.SetAlpha then
        pcall(nine.SetAlpha, nine, 0)
    end
end

-- GameTooltipTemplate **自帶**一條 `$parentStatusBar`（GameTooltip 的就是全域
-- GameTooltipStatusBar，我們的預覽 tooltip 也有自己的 MiliUITip_PreviewStatusBar），
-- 單位提示時引擎會把它顯示出來，跟我們自己的血條疊在一起、寬度又不同
--（/fstack 實測抓到兩條）。接管的 tip 一律把它 alpha 0。
function Skin.NeutralizeTemplateBar(tip)
    if S.IsForbiddenObject(tip) then return end
    local ok, name = pcall(tip.GetName, tip)
    -- ⚠ 名字也可能是秘密字串（框掛進秘密錨點鏈、帶 ObjectName aspect 時），
    --   拿去查 `_G` 會當場「cannot be indexed with secret keys」⇒ 秘密就跳過
    if not ok or type(name) ~= "string" or S.IsSecret(name) then return end
    local tplBar = _G[name .. "StatusBar"]
    if tplBar and tplBar.SetAlpha then
        pcall(tplBar.SetAlpha, tplBar, 0)
    end
end

------------------------------------------------------------
-- skin 建立
------------------------------------------------------------
local function LowerSkinLevel(skin)
    local tip = skin:GetParent()
    if not tip or S.IsForbiddenObject(tip) then return end
    local ok, level = pcall(tip.GetFrameLevel, tip)
    if ok and type(level) == "number" and not S.IsSecret(level) then
        skin:SetFrameLevel(math.max(0, level - 1))
    end
end

-- opts.keepScale：這顆的縮放不歸我們管（見 `MiliUITip_API.Adopt`），ApplyBase 不寫 SetScale
function Skin.Attach(tip, opts)
    if not tip or State[tip] then return State[tip] end
    if S.IsForbiddenObject(tip) then return end

    local state = {}
    State[tip] = state
    state.keepScale = opts and opts.keepScale and true or nil

    local skin = CreateFrame("Frame", nil, tip)
    skin:SetAllPoints(tip)
    state.skin = skin

    -- 背景
    local bg = Media.NoSnap(skin:CreateTexture(nil, "BACKGROUND"))   -- 內縮量要跟邊框對得上，同樣不貼齊
    bg:SetTexture(Media.WHITE8X8)
    state.bg = bg

    -- 邊框：四張貼圖（上下橫貫全寬、左右夾在中間），SetVertexColor 上色
    local edges = {}
    for i = 1, 4 do
        edges[i] = Media.NoSnap(skin:CreateTexture(nil, "BORDER"))
        edges[i]:SetTexture(Media.WHITE8X8)
    end
    state.edges = edges

    -- 頂部漸層遮罩（設定開啟才顯示）
    local mask = skin:CreateTexture(nil, "ARTWORK")
    mask:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    mask:SetBlendMode("ADD")
    if mask.SetGradient then
        mask:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0.9, 0.9, 0.9, 0.4))
    end
    mask:Hide()
    state.mask = mask

    -- 大陣營底圖
    local faction = skin:CreateTexture(nil, "ARTWORK", nil, 1)
    faction:SetPoint("TOPRIGHT", skin, "TOPRIGHT", 18, 0)
    faction:SetBlendMode("ADD")
    faction:SetScale(0.24)
    faction:SetAlpha(0.40)
    faction:Hide()
    state.factionBig = faction

    -- skin 自己的腳本（自有框，不是掛勾）：
    -- 顯示時重新壓層級＋重申 NineSlice 隱藏；隱藏時清掉單位暫態、還原內容色
    skin:SetScript("OnShow", function(self)
        LowerSkinLevel(self)
        Skin.LayoutBorder(state)         -- 縮放可能在接管之後才定（登入時），見 LayoutBorder
        NeutralizeNineSlice(tip)
        Skin.NeutralizeTemplateBar(tip)
        Skin.RaiseAccents(tip)
        NoteVisibility(state, true)      -- 共用輪詢的開關，見 Skin.Poll
        if ns.Panel then ns.Panel.OnSkinShow(tip, state) end   -- 重繪面板：重申原生 alpha 0
    end)
    skin:SetScript("OnHide", function()
        Skin.ClearTransient(tip)
        if ns.Panel then ns.Panel.OnSkinHide(tip, state) end   -- 重繪面板：延一幀、沒被重新認領才拆（Panel/Try.lua）
        NoteVisibility(state, false)
    end)

    LowerSkinLevel(skin)
    NeutralizeNineSlice(tip)
    Skin.NeutralizeTemplateBar(tip)
    Skin.ApplyBase(tip)
    return state
end

------------------------------------------------------------
-- 血條 / 模型的層級要**明寫在 tip 之上**（子 frame 層級要明寫）：
-- 它們是 skin（tip−1）的 child，放著不管會落在 tip 之下——血條文字往上
-- 溢進 tooltip 矩形的那半截會被 tooltip 背景蓋掉（實測：文字被吃半行）。
-- skin 本體維持 tip−1（背景不能蓋字），只有這兩個附掛件抬到 tip+1。
------------------------------------------------------------
function Skin.RaiseAccents(tip)
    local state = State[tip]
    if not state or S.IsForbiddenObject(tip) then return end
    local ok, level = pcall(tip.GetFrameLevel, tip)
    if not ok or type(level) ~= "number" or S.IsSecret(level) then return end
    -- 貼在重繪面板上時（面板 = tip + 5，Panel.SyncLevel）再往上一層
    if state.bar then state.bar:SetFrameLevel(level + (state.barHost and 6 or 1)) end
    if state.model then state.model:SetFrameLevel(level + (state.modelHost and 6 or 1)) end
end

------------------------------------------------------------
-- 基礎樣式（設定值 → skin），設定變更時對所有 tip 重跑
------------------------------------------------------------
-- 邊框粗細是「n 個實體像素」（P.Pixel 的語意，見 wow-hairline-p-pixel-not-p-scale），
-- 基準是 skin 自己的有效縮放（tip 會 SetScale(general.scale)；Panel.Pixel 同款）。讀不到或秘密退 P.Pixel
local function SkinPixel(skin, n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    if n <= 0 then return 0 end
    local ok, scale = pcall(skin.GetEffectiveScale, skin)
    scale = ok and S.PlainNumber(scale)
    if not (scale and scale > 0) then return P.Pixel(n) end
    return n * PixelUtil.GetPixelToUIUnitFactor() / scale
end
Skin.Pixel = SkinPixel       -- 血條的黑框同一個基準（Core/Bar.lua）

-- 邊框／背景／遮罩的錨點（全部跟著 inset 走）。inset 跟上次一樣就不動。
-- ⚠ inset 不能只在 ApplyBase 算一次：ApplyBase 第一次跑在 ADDON_LOADED，那時 UIParent 還沒套上
--   最終的 UI 縮放（見 wow-login-screen-size-not-final），算出來的「1px」實際不到 1 個實體像素，
--   之後又沒人重算 ⇒ 登入／reload 後單位提示的上邊、左邊整條不見（2026-10-20 玩家回報：
--   右下角釘在整數像素上還蓋得到像素中心，上、左落在小數座標就漏掉）。
--   所以 skin 每次 OnShow 都重新換算一次、變了才重排（重繪面板 Panel.Pixel 本來就是畫的時候才算）。
local function LayoutBorder(state)
    local g = ns.db and ns.db.general
    if not g then return end
    local inset = SkinPixel(state.skin, g.borderSize or 1)
    if state.borderInset == inset then return end
    state.borderInset = inset

    local bg = state.bg
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", inset, -inset)
    bg:SetPoint("BOTTOMRIGHT", -inset, inset)

    local e = state.edges
    for i = 1, 4 do
        e[i]:ClearAllPoints()
        e[i]:SetShown(inset > 0)
    end
    if inset > 0 then
        e[1]:SetPoint("TOPLEFT", 0, 0);    e[1]:SetPoint("TOPRIGHT", 0, 0);    e[1]:SetHeight(inset)
        e[2]:SetPoint("BOTTOMLEFT", 0, 0); e[2]:SetPoint("BOTTOMRIGHT", 0, 0); e[2]:SetHeight(inset)
        e[3]:SetPoint("TOPLEFT", 0, -inset);  e[3]:SetPoint("BOTTOMLEFT", 0, inset);  e[3]:SetWidth(inset)
        e[4]:SetPoint("TOPRIGHT", 0, -inset); e[4]:SetPoint("BOTTOMRIGHT", 0, inset); e[4]:SetWidth(inset)
    end

    local mask = state.mask
    mask:ClearAllPoints()
    mask:SetPoint("TOPLEFT", inset, -inset)
    mask:SetPoint("BOTTOMRIGHT", state.skin, "TOPRIGHT", -inset, -32)
end
Skin.LayoutBorder = LayoutBorder

function Skin.ApplyBase(tip)
    local state = State[tip]
    if not state or not ns.db then return end
    local g = ns.db.general

    -- 縮放先寫（底下的邊框粗細照縮放後的有效縮放換算）：寫在暴雪 tip 上的定位類 API（接觸面清單第 8 條），skin 是 child 會跟著縮
    -- ⚠ keepScale 的不寫：那種框掛在已經縮放過的 tooltip 底下，再縮一次會變成平方
    if not state.keepScale and not S.IsForbiddenObject(tip) and tip.SetScale then
        pcall(tip.SetScale, tip, g.scale or 1)
    end

    state.borderInset = nil      -- 設定可能改了粗細：強制重排
    LayoutBorder(state)

    state.bg:SetTexture(Media.Background(g.bgfile))
    state.bg:SetTexCoord(0, 1, 0, 1)
    state.mask:SetShown(g.mask and true or false)

    Skin.ResetColors(tip)
end

function Skin.ApplyBaseAll()
    for tip in pairs(State) do
        Skin.ApplyBase(tip)
    end
end

------------------------------------------------------------
-- 內容色（單位職業框、物品品質框、NPC 立場底色…）：
-- 分量可能是秘密值，只走 SetVertexColor / SetAlpha。
------------------------------------------------------------
function Skin.SetBorderColor(tip, r, g, b, a)
    local state = State[tip]
    if not state then return end
    for i = 1, 4 do
        state.edges[i]:SetVertexColor(r, g, b, a or 1)
    end
    -- 重繪面板讀這份畫自己的邊（分量可能是秘密值：只存、只交給 SetVertexColor）
    local c = state.borderColor
    if not c then
        c = {}
        state.borderColor = c
    end
    c[1], c[2], c[3], c[4] = r, g, b, a or 1
end

function Skin.SetBackgroundColor(tip, r, g, b, a)
    local state = State[tip]
    if not state then return end
    state.bg:SetVertexColor(r, g, b, 1)
    state.bg:SetAlpha(S.PlainNumber(a) or 1)
end

-- 還原成全域預設色（明文，可安全 unpack）。邊色走基底（Panel.BaseBorderColor：職業色或 general.borderColor）
function Skin.ResetColors(tip)
    local state = State[tip]
    if not state or not ns.db then return end
    local g = ns.db.general
    local bc, bgc = g.borderColor, g.background
    if ns.Panel and ns.Panel.BaseBorderColor then
        Skin.SetBorderColor(tip, ns.Panel.BaseBorderColor())
    else
        Skin.SetBorderColor(tip, bc.r, bc.g, bc.b, bc.a)
    end
    Skin.SetBackgroundColor(tip, bgc.r, bgc.g, bgc.b, bgc.a)
end

function Skin.SetFactionBig(tip, factionGroup)
    local state = State[tip]
    if not state then return end
    local group = S.PlainText(factionGroup)
    if group == "Alliance" or group == "Horde" then
        state.factionBig:SetTexture("Interface\\Timer\\" .. group .. "-Logo")
        state.factionBig:Show()
    else
        state.factionBig:Hide()
    end
end

------------------------------------------------------------
-- 單位暫態清理（skin OnHide 與 OnTooltipCleared 都會走這裡）
------------------------------------------------------------
function Skin.ClearTransient(tip)
    local state = State[tip]
    if not state then return end
    if ns.logEnabled and (state.unit or state.isUnitTip) then
        ns.Log("ClearTransient tip=%s 原state.unit=%s", tip:GetName() or "?", ns.Describe(state.unit))
    end
    state.unit = nil
    state.unitGuid = nil
    state.specGuid = nil
    state.specLine = nil
    state.isUnitTip = nil
    state.targetLine = nil
    state.lastSpellId = nil
    -- state.idData（物品 link 解析快取）刻意不清：它以 link 為 key 自我驗證，
    -- 清掉會讓比價重建風暴每秒重跑 20 幾次 gmatch 解析
    state.factionBig:Hide()
    Skin.ResetColors(tip)
    if ns.Bar then ns.Bar.Deactivate(tip) end
    if ns.Model then ns.Model.Clear(tip) end
end
