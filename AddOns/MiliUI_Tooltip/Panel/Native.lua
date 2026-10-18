------------------------------------------------------------
-- 原生 tooltip 在 panel 底下當替身：alpha 0、padding 撐到跟 panel 一樣大
--
-- 為什麼不直接 Hide：暴雪的比價框定位、螢幕邊夾邊、跟隨游標全部照**原生框**的尺寸算。
-- 原生框保持顯示、只是看不見，而且撐得跟 panel 一樣大 ⇒ 那些系統把兩者當成一個框，
-- 我們什麼定位都不用重寫。
--
-- 接觸面 #10（Core/Hooks.lua 檔頭）：SetAlpha 與 SetPadding 兩支 C 端定位 setter；
-- 只在 panel 成功顯示時寫，Restore 寫回原值。
-- 接觸面 #12：hooksecurefunc(tip, "Show"／"SetShown") 後掛勾，見下面 HookShow。
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

------------------------------------------------------------
-- 暴雪的 Show()／SetShown(true) 會把 tooltip 的 alpha 改回 1，而且在我們的 post-call **之後**才叫
--（ProcessInfo 結尾的 self:Show()、比價框的 TooltipComparisonManager:AnchorShoppingTooltips → SetShown）。
-- 只靠輪詢或下一幀重壓的話，那一幀原生框會整個露出來——被面板蓋住看不出來，只有主面板與附屬框之間的縫
-- 看得到，比價框每秒重建二十幾次 ⇒ 縫裡一直閃（2026-10-18 實機截圖）。
-- ⇒ 掛在 Show／SetShown 後面、同一幀立刻壓回 0。只掛在真的用過面板的 tooltip 上（第一次 Hide 時才掛），
--   掛勾裡只查自己的 state、只做 SetAlpha（C 端 setter）。
------------------------------------------------------------
local hooked = {}

local RestoreClearedPadding     -- 下面定義；Show 後掛勾與 Fit 都用


-- state 是這顆 tooltip 在 Skin.State 裡那一份（每顆一份、不會換），直接閉包住
local function HookShow(tip, state)
    if hooked[tip] then return end
    hooked[tip] = true
    local function repress(self)
        if state.native then
            Native.Repress(self, state)
            -- 暴雪的 OnShow（GameTooltip_CalculatePadding）也會在這之前把 padding 清掉：當幀補回
            RestoreClearedPadding(self, state)
        end
    end
    if tip.Show then hooksecurefunc(tip, "Show", repress) end
    if tip.SetShown then
        hooksecurefunc(tip, "SetShown", function(self, shown)
            if S.IsSecret(shown) or shown then repress(self) end
        end)
    end
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
        -- 接觸面 #13：原生的夾邊關掉、改由我們的面板自己夾（Panel/Frame.lua 的 panel 是 SetClampedToScreen(true)）。
        -- 暴雪的 clamp 照原生的總高決定要不要往下推；原生高度一抖就切換、整組跳一截
        -- （2026-10-18 實機 dump：三顆 top 全是螢幕上緣）。原值記下來，Restore 寫回。
        -- 暴雪只在 XML 設 clampedToScreen、執行期間不改（wow-ui-source 查過），不必在 Show 後重申
        local okC, clamped = pcall(tip.IsClampedToScreen, tip)
        if okC and not S.IsSecret(clamped) and type(clamped) == "boolean" then
            saved.clamped = clamped
            if tip.SetClampedToScreen then tip:SetClampedToScreen(false) end
        end
        state.native = saved
    end
    HookShow(tip, state)
    tip:SetAlpha(0)
    return true
end

-- 把原生撐到 panel 的尺寸。只在尺寸真的變了才 SetPadding（每次 SetPadding 都是一次完整排版）。
-- 不在同一幀讀回剛設的尺寸：猜錯了下一次 Fit 的比對自然會修。
-- 回傳 false 表示讀到秘密值（呼叫端退回）；nil 表示這次不用做（沒顯示、沒資料）。
-- padding 被暴雪清回基準值（SetOwner／ClearLines／OnShow）、而上次我們設過別的值 ⇒ 當幀直接補回上次的值，
-- 不重算：那一幀 GetHeight 還是清掉之前的舊值，GetPadding 卻已經是 0，拿來推自然尺寸一定算錯
-- （2026-10-18 實機：背包格每 0.2 秒重設提示，原生矮一截一幀，從下緣錨定的 panel 跟著跳）。
-- 下一幀的 Fit（Reconcile／輪詢）再用新鮮的尺寸修正。回 true＝補了。
local function Near(a, b) return math.abs(a - b) < 0.01 end

function RestoreClearedPadding(tip, state)
    local saved, set = state.native, state.paddingSet
    if not saved or not set then return false end
    if Near(set[1], saved.right) and Near(set[2], saved.bottom) then return false end
    local pr, pb = ReadPadding(tip)
    if not pr then return false end
    if Near(pr, saved.right) and Near(pb, saved.bottom) then
        tip:SetPadding(set[1], set[2], saved.left, saved.top)
        return true
    end
    return false
end
Native.RestoreClearedPadding = RestoreClearedPadding

function Native.Fit(tip, state)
    local saved, panel = state.native, state.panel
    if not saved or not panel or not panel.width or not panel.height then return end
    if RestoreClearedPadding(tip, state) then
        -- 不推自然尺寸，但對齊照做（比價面板要能在這裡轉成鏡射到主面板）
        if not Panel.Align(panel, tip) then return false end
        return true
    end
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
    -- 有附屬框時連它一起算：比價框、夾邊才會照整組的範圍
    -- 只長不縮（同一件）：撐到這件看過的最大總高，內容暫時變矮時原生的錨點不動
    local groupH = math.max(panel.totalHeight or panel.height, state.panelMaxTotalHeight or 0)
    local pw, ph = panel.width * ratio, groupH * ratio

    local naturalW = w - (pr - saved.right)
    local naturalH = h - (pb - saved.bottom)
    -- 原生自己的尺寸也只長不縮（同一件）：撐到這件看過的最大自然寬高。
    -- 原生的寬高是暴雪定位用的——比價框往哪邊放、要把主提示推多少（AnchorShoppingTooltips 的 slideAmount
    -- 用兩顆比價框原生的寬算）、夾邊。自然寬高在每次重設時短暫變（別家的行晚一幀補回、比價說明是不換行的長行），
    -- 推移量跟著切換 ⇒ 主提示原生左右移 ⇒ 整條鏈上的面板都動（2026-10-18 實機：最左那顆比價面板抖最兇）。
    -- 撐到最大值之後原生的寬高單調，暴雪算出來的位置就穩。原生看不見，多撐沒有視覺代價。換一件歸零（Try）
    state.nativeMaxW = math.max(state.nativeMaxW or 0, naturalW)
    state.nativeMaxH = math.max(state.nativeMaxH or 0, naturalH)
    pw, ph = math.max(pw, state.nativeMaxW), math.max(ph, state.nativeMaxH)
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
    Panel.ResetNativeClose(tip)      -- 聊天連結提示：原生關閉鈕貼回原位
    if not saved then return end
    if S.IsForbiddenObject(tip) then return end
    if saved.clamped ~= nil and tip.SetClampedToScreen then tip:SetClampedToScreen(saved.clamped) end
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
