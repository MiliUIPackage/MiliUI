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
-- 接觸面 #15：hooksecurefunc(tip, "FadeOut") 後掛勾（同一個 HookShow 裡），只讓自己的面板跟著淡出。
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

-- /mtip log 開著時記下對原生的每一筆寫入（逐幀取樣看不到的抖動：變動發生在取樣之後、繪製之前，只能從寫入點追）。
-- 呼叫端要自己用 ns.logEnabled 閘住整句：參數是急切求值的，Geo 每次三個 pcall＋format，關著時不該付這個錢
local function Log(fmt, ...)
    if ns.logEnabled and ns.Log then ns.Log(fmt, ...) end
end
local function Geo(tip)
    local okT, t = pcall(tip.GetTop, tip)
    local okB, b = pcall(tip.GetBottom, tip)
    local okH, h = pcall(tip.GetHeight, tip)
    return ("top=%s bottom=%s h=%s"):format(okT and ns.Describe and ns.Describe(t) or "?", okB and ns.Describe and ns.Describe(b) or "?", okH and ns.Describe and ns.Describe(h) or "?")
end

local function ReadPadding(tip)
    if not tip.GetPadding then return 0, 0, 0, 0 end
    local ok, r, b, l, t = pcall(tip.GetPadding, tip)
    if not ok then return end
    r, b, l, t = r or 0, b or 0, l or 0, t or 0
    if not Plain(r, b, l, t) then return end
    return r, b, l, t
end

-- 原生排好的文字寬（自然寬扣掉我們撐的 padding、扣掉左右內距）。身分受限單位的名字是秘密字串、我們量不出寬，
-- 但暴雪在引擎端替原生排好了版、原生的寬是明文（2026-10-21 探針：副本裡 GetWidth／GetPoint／GetPadding 全是明文）
-- ⇒ 面板照它替秘密字串留位置。原生最寬的那一行不一定是名字，所以只會留多、不會留少。讀不到回 nil
local NATIVE_TEXT_INSET = 20          -- 原生的行左右各留 10（GameTooltip 的第一行從 10,-10 起排）
function Native.ContentWidth(tip, state)
    local okW, w = pcall(tip.GetWidth, tip)
    if not okW or not Plain(w) then return nil end
    local pr = ReadPadding(tip)
    if not pr then return nil end
    local saved = state and state.native
    local natural = w - (saved and (pr - saved.right) or 0)
    return math.max(0, natural - NATIVE_TEXT_INSET)
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
            if state.panel then Panel.Unfade(state.panel) end
        end
    end
    if tip.Show then hooksecurefunc(tip, "Show", repress) end
    -- 接觸面 #15：世界單位滑開時暴雪叫 FadeOut（C 端調原生的 alpha）。原生在 alpha 0、面板是獨立的框 ⇒ 面板自己淡。
    -- 一樣只掛在用過面板的 tooltip 上，掛勾裡只動自己的面板
    if tip.FadeOut then
        hooksecurefunc(tip, "FadeOut", function()
            if state.native and state.panel and state.panel:IsShown() then Panel.FadeOut(state.panel) end
        end)
    end
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
        -- 接觸面 #13：原生**照暴雪的夾邊**留在螢幕內（撐到跟面板一樣大之後，夾的就是整組的範圍，面板貼著它走）。
        -- 我們只替它設夾邊範圍（UpdateClamp：四邊留呼吸、上緣多留比價標籤），原值記下來、Restore 寫回。
        -- 曾經在這裡把夾邊關掉改由面板自己夾（2026-10-18～19）：原生超出螢幕之後，所有讀原生幾何的東西
        -- （外觀預覽的定位器、暴雪的比價定位）都被誤導，補了四輪下游症狀；原生寬高「只長不縮」之後
        -- 當初關掉的理由（高度一抖夾邊就切換）已經不在，2026-10-19 改回來
        if tip.GetClampRectInsets then
            local okI, il, ir, it, ib = pcall(tip.GetClampRectInsets, tip)
            if okI and Plain(il, ir, it, ib) then saved.insets = { il, ir, it, ib } end
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
        if ns.logEnabled then Log("原生 padding 被清掉 ⇒ 補回 %.1f,%.1f  %s", set[1], set[2], Geo(tip)) end
        return true
    end
    return false
end
Native.RestoreClearedPadding = RestoreClearedPadding

-- partial = true：同一件重設的 post-call 當下。那一刻的內容**已知不完整**——別家插件的行、比價說明都是同一幀稍後才加
-- （Try 檔頭第 2 點），量到的自然高度偏矮；照它算 padding 會先撐大，行進來之後原生總高超過目標，直到下一幀對帳才改回。
-- 沒夾邊時多出來的往上長（面板貼在下緣）看不見；原生被夾在螢幕上緣時上緣被釘住、多出來的變成**下緣往下掉一幀**，
-- 面板跟著掉，每 0.2 秒一次（2026-10-19 實機 log：padding 125.3↔35.1 交替、逐幀取樣永遠在對帳之後所以看不到）。
-- ⇒ partial 時自然尺寸用「上次對帳量到的」（state.nativeSettledW／H）與當下量到的取大者：內容會回來的話 padding 一個數字
--   都不用改、連 SetPadding 都省；真的變少（修飾鍵放開）頂多矮一幀，下一幀對帳量到新值就修正。對帳／輪詢（partial 為 nil）
--   量到的才記成 settled。
function Native.Fit(tip, state, partial)
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
    if partial then
        naturalW = math.max(naturalW, state.nativeSettledW or 0)
        naturalH = math.max(naturalH, state.nativeSettledH or 0)
    else
        state.nativeSettledW, state.nativeSettledH = naturalW, naturalH
    end
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
        if ns.logEnabled then Log("原生 SetPadding %.1f,%.1f（之前 %.1f,%.1f；自然 %.1fx%.1f 撐到 %.1fx%.1f）  %s",
            right, bottom, pr, pb, naturalW, naturalH, pw, ph, Geo(tip)) end
    end
    Native.UpdateClamp(tip, state, ratio)
    -- 從下緣錨定的 tooltip 撐高之後上緣會動 ⇒ 重新對齊
    if not Panel.Align(panel, tip) then return false end
    return true
end

-- 原生的夾邊範圍（接觸面 #13）：四邊各往外一圈 EDGE_MARGIN（貼死螢幕邊時 1px 邊框看不見），上緣再多留
-- 露在面板外的比價標籤——含鏡射在這顆面板上的那幾顆的（Panel.ClampReserve 沿鏈收到根）。
-- 面板的單位換成原生的（ratio = panelScale / tipScale）。只在值變了才寫；沒記到原值（讀不到）就不碰。
-- 方向同暴雪 SetClampRectInsets(left, right, top, bottom)：左負、右正、上正、下負＝範圍比框大
function Native.UpdateClamp(tip, state, ratio)
    local saved, panel = state.native, state.panel
    if not saved or not saved.insets or not panel or not tip.SetClampRectInsets then return end
    local top, margin = Panel.ClampReserve(panel)
    if not top then return end
    ratio = ratio or 1
    top, margin = top * ratio, margin * ratio
    local sig = ("%.3f|%.3f"):format(top, margin)
    if state.clampSig == sig then return end
    state.clampSig = sig
    tip:SetClampRectInsets(-margin, margin, top + margin, -margin)
    if ns.logEnabled then Log("原生 夾邊範圍 %.1f,%.1f,%.1f,%.1f  %s", -margin, margin, top + margin, -margin, Geo(tip)) end
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
    state.clampSig = nil
    if not saved then return end
    if S.IsForbiddenObject(tip) then return end
    if saved.insets and tip.SetClampRectInsets then
        tip:SetClampRectInsets(saved.insets[1], saved.insets[2], saved.insets[3], saved.insets[4])
    end
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
    if alpha and alpha ~= 0 then
        tip:SetAlpha(0)
        if ns.logEnabled then Log("原生 alpha 被改回 %.2f ⇒ 壓回 0", alpha) end
    end
end
