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

function Skin.Attach(tip)
    if not tip or State[tip] then return State[tip] end
    if S.IsForbiddenObject(tip) then return end

    local state = {}
    State[tip] = state

    local skin = CreateFrame("Frame", nil, tip)
    skin:SetAllPoints(tip)
    state.skin = skin

    -- 背景
    local bg = skin:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(Media.WHITE8X8)
    state.bg = bg

    -- 邊框：四張貼圖（上下橫貫全寬、左右夾在中間），SetVertexColor 上色
    local edges = {}
    for i = 1, 4 do
        edges[i] = skin:CreateTexture(nil, "BORDER")
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
        NeutralizeNineSlice(tip)
        Skin.RaiseAccents(tip)
    end)
    skin:SetScript("OnHide", function()
        Skin.ClearTransient(tip)
    end)

    LowerSkinLevel(skin)
    NeutralizeNineSlice(tip)
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
    if state.bar then state.bar:SetFrameLevel(level + 1) end
    if state.model then state.model:SetFrameLevel(level + 1) end
end

------------------------------------------------------------
-- 基礎樣式（設定值 → skin），設定變更時對所有 tip 重跑
------------------------------------------------------------
function Skin.ApplyBase(tip)
    local state = State[tip]
    if not state or not ns.db then return end
    local g = ns.db.general
    local skin, bg, edges, mask = state.skin, state.bg, state.edges, state.mask

    local inset = P.Scale(math.max(0, g.borderSize or 1))
    state.borderInset = inset

    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", inset, -inset)
    bg:SetPoint("BOTTOMRIGHT", -inset, inset)
    bg:SetTexture(Media.Background(g.bgfile))
    bg:SetTexCoord(0, 1, 0, 1)

    local e = edges
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

    mask:ClearAllPoints()
    mask:SetPoint("TOPLEFT", inset, -inset)
    mask:SetPoint("BOTTOMRIGHT", skin, "TOPRIGHT", -inset, -32)
    mask:SetShown(g.mask and true or false)

    Skin.ResetColors(tip)

    -- 縮放：寫在暴雪 tip 上的定位類 API（接觸面清單第 8 條），skin 是 child 會跟著縮
    if not S.IsForbiddenObject(tip) and tip.SetScale then
        pcall(tip.SetScale, tip, g.scale or 1)
    end
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
end

function Skin.SetBackgroundColor(tip, r, g, b, a)
    local state = State[tip]
    if not state then return end
    state.bg:SetVertexColor(r, g, b, 1)
    state.bg:SetAlpha(S.PlainNumber(a) or 1)
end

-- 還原成全域預設色（明文，可安全 unpack）
function Skin.ResetColors(tip)
    local state = State[tip]
    if not state or not ns.db then return end
    local g = ns.db.general
    local bc, bgc = g.borderColor, g.background
    Skin.SetBorderColor(tip, bc.r, bc.g, bc.b, bc.a)
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
