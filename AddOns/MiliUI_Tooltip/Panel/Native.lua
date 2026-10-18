------------------------------------------------------------
-- 原生 tooltip 在 panel 底下當替身：alpha 0、padding 撐到跟 panel 一樣大
--
-- 為什麼不直接 Hide：暴雪的比價框定位、螢幕邊夾邊、跟隨游標全部照**原生框**的尺寸算。
-- 原生框保持顯示、只是看不見，而且撐得跟 panel 一樣大 ⇒ 那些系統把兩者當成一個框，
-- 我們什麼定位都不用重寫。
--
-- 接觸面 #10（Core/Hooks.lua 檔頭）：只有 SetAlpha 與 SetPadding 兩支、都是 C 端定位 setter；
-- 只在 panel 成功顯示時寫，Restore 寫回原值。不掛任何 hooksecurefunc。
--
-- 暴雪自己也會動 padding：GameTooltip 的 OnShow／OnHide 會 ClearPadding（GameTooltip_CalculatePadding），
-- 所以第一次顯示時我們設的 padding 會被清掉一次 ⇒ Fit 不假設 padding 還是自己設的那個，
-- 每次都用 GetPadding 反推自然尺寸。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local Panel = ns.Panel

Panel.Native = {}
local Native = Panel.Native

local function Plain(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) ~= "number" or S.IsSecret(v) then return false end
    end
    return true
end

local function ReadPadding(tip)
    if not tip.GetPadding then return 0, 0, 0, 0 end
    local ok, r, b, l, t = pcall(tip.GetPadding, tip)
    if not ok then return end
    r, b, l, t = r or 0, b or 0, l or 0, t or 0
    if not Plain(r, b, l, t) then return end
    return r, b, l, t
end

-- 記下原值並藏起來。讀不到（秘密／錯誤）回 false，呼叫端整格退回。
function Native.Hide(tip, state)
    local saved = state.native
    if not saved then
        local okA, alpha = pcall(tip.GetAlpha, tip)
        alpha = okA and S.PlainNumber(alpha)
        if not alpha then return false end
        -- 淡出中途的值不能當原值（還原成它會讓提示永遠半透明）
        if alpha < 1 then alpha = 1 end
        local r, b, l, t = ReadPadding(tip)
        if not r then return false end
        saved = { alpha = alpha, right = r, bottom = b, left = l, top = t }
        state.native = saved
    end
    tip:SetAlpha(0)
    return true
end

-- 把原生撐到 panel 的尺寸。只在尺寸真的變了才 SetPadding（每次 SetPadding 都是一次完整排版）。
-- 不在同一幀讀回剛設的尺寸：猜錯了下一次 Fit 的比對自然會修。
-- 回傳 false 表示讀到秘密值（呼叫端退回）；nil 表示這次不用做（沒顯示、沒資料）。
function Native.Fit(tip, state)
    local saved, panel = state.native, state.panel
    if not saved or not panel or not panel.width or not panel.height then return end
    local okS, shown = pcall(tip.IsShown, tip)
    if not okS or S.IsSecret(shown) or not shown then return end

    local okW, w = pcall(tip.GetWidth, tip)
    local okH, h = pcall(tip.GetHeight, tip)
    if not okW or not okH or not Plain(w, h) then return false end
    local pr, pb = ReadPadding(tip)
    if not pr then return false end

    -- panel 跟 tooltip 的有效縮放不一定相同（預覽、別的父層），換成 tooltip 的單位
    local tipScale, panelScale = Panel.EffectiveScale(tip), Panel.EffectiveScale(panel)
    if not (tipScale and panelScale) then return false end
    local ratio = panelScale / tipScale
    local pw, ph = panel.width * ratio, panel.height * ratio

    local naturalW = w - (pr - saved.right)
    local naturalH = h - (pb - saved.bottom)
    local right = saved.right + math.max(0, pw - naturalW)
    local bottom = saved.bottom + math.max(0, ph - naturalH)
    if math.abs(right - pr) > 0.01 or math.abs(bottom - pb) > 0.01 then
        tip:SetPadding(right, bottom, saved.left, saved.top)
        state.paddingSet = state.paddingSet or {}
        state.paddingSet[1], state.paddingSet[2] = right, bottom
    end
    -- 從下緣錨定的 tooltip 撐高之後上緣會動 ⇒ 重新對齊
    if not Panel.Align(panel, tip) then return false end
    return true
end

-- 寫回原值、藏 panel。
-- padding 只在「tooltip 還顯示著、而且 padding 還是我們設的那個」時寫回：
-- 隱藏時暴雪的 OnHide 已經 ClearPadding；新內容（例如內嵌物品的世界任務）可能已經設了自己的。
function Native.Restore(tip, state)
    local saved = state.native
    state.native = nil
    local set = state.paddingSet
    state.paddingSet = nil
    if state.panel then
        state.panel:Hide()
        Panel.Detach(state.panel)
    end
    if not saved then return end
    if S.IsForbiddenObject(tip) then return end
    local okS, shown = pcall(tip.IsShown, tip)
    if okS and not S.IsSecret(shown) and shown and set then
        local pr, pb = ReadPadding(tip)
        if pr and math.abs(pr - set[1]) < 0.01 and math.abs(pb - set[2]) < 0.01 then
            tip:SetPadding(saved.right, saved.bottom, saved.left, saved.top)
        end
    end
    local okA, alpha = pcall(tip.GetAlpha, tip)
    alpha = okA and S.PlainNumber(alpha)
    -- 還是 0 ＝ 我們壓的；別人改過（淡出）就不搶
    if alpha == nil or alpha == 0 then
        tip:SetAlpha(saved.alpha)
    end
end

-- 每次 tooltip 顯示（skin OnShow）、輪詢時重申 alpha 0
function Native.Repress(tip, state)
    if not state.native then return end
    local ok, alpha = pcall(tip.GetAlpha, tip)
    alpha = ok and S.PlainNumber(alpha)
    if alpha and alpha ~= 0 then tip:SetAlpha(0) end
end
