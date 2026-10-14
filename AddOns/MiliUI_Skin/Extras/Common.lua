------------------------------------------------------------
-- 自建功能（Extras/）的共用件：啟動、秘密值收手與「交給引擎畫」、細捲軸、自畫底與邊、
-- 編輯狀態的廣播
--
-- Extras 跟 Skins 是兩種東西（STYLE.md ③ 的「Extras（自建功能）」小節）：
--   * Skins 是**換皮**：只重畫暴雪自己的物件，不重排、不自建內容。
--   * Extras 是**自建功能**：自己的框、自己讀 API、自己畫列，疊在暴雪的面板上，
--     暴雪原本那一份用 `Engine.Neutralize`（SetAlpha 0）藏起來照跑。
--   對暴雪物件的規矩沒有放寬：零欄位寫入，只准 SetAlpha（走 Engine.Neutralize）、
--   HookScript、hooksecurefunc、把自己的框錨到／掛在暴雪框底下。每支模組的檔頭
--   有自己的接觸面清單。lint（check_skin.py）對 Extras 只套較鬆的那一組規則 ——
--   定位類呼叫對**自己的框**是合法的，lint 又分不出變數是不是暴雪的框。
--
-- 啟動：`Core/Init.lua` 在 `Engine.Boot()` 之後呼叫 `ns.Extras.Boot()`。
--   戰鬥中（戰鬥中 /reload）延到 PLAYER_REGEN_ENABLED —— 我們會把子框掛到暴雪的
--   面板底下，戰鬥中不動暴雪框的子框清單是這包的通則（Engine.lua 的保護框那段）。
------------------------------------------------------------
local _, ns = ...

local T = ns.Tokens
local P = ns.P
local S = ns.Secret

ns.Extras = {}
local X = ns.Extras

local WHITE = "Interface\\BUTTONS\\WHITE8X8"

------------------------------------------------------------
-- 登記與啟動
--
-- 每支模組在檔案層呼叫 `X.Register(key, build)`；`key` ＝ `db.extras` 裡那個開關。
-- 開關關掉（或總開關關掉）就整支不建 —— 沒有「建了再藏」這條路，關掉就是
-- 暴雪原本的樣子，跟 DB.lua 檔頭「設定變更一律 /reload」同一個理由。
------------------------------------------------------------
local modules = {}
X.built = {}

function X.Register(key, build)
    modules[#modules + 1] = { key = key, build = build }
end

local function BuildAll()
    for _, m in ipairs(modules) do
        if not X.built[m.key] and ns.DB.IsExtraEnabled(m.key) then
            local ok = xpcall(m.build, ns.ReportError)
            -- 出錯也記成已處理：重試只會在每次脫戰再炸一次
            X.built[m.key] = ok and "built" or "error"
        end
    end
end

local waiter
function X.Boot()
    if not InCombatLockdown() then
        BuildAll()
        return
    end
    if not waiter then
        waiter = CreateFrame("Frame")
        waiter:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            BuildAll()
        end)
    end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
end

------------------------------------------------------------
-- 錯誤處理：秘密值是「預期中的拒絕」，其他錯誤才報
--
-- 要在 Lua 裡**讀**數字的程式（組 tooltip、算「上一次明碼值」）一律包在 `X.Try` 裡，
-- 數字先過 `X.Num`：拿到秘密值（或不是數字）就丟一個哨兵錯誤，整段收手。
-- 這樣「秘密值不能算術／比較」的規則不必在每一行重寫一次，而且**不會**半途
-- 算到一半才炸在 `format` 裡。哨兵以外的錯誤是真的 bug，照常交給 ns.ReportError
-- （每個 label 只報一次，事件一秒好幾發，不能洗版）。
-- ⚠ **顯示**數字不走這條 —— 見下一節 `X.ValueParts`：秘密值照樣畫得出來。
------------------------------------------------------------
local SECRET = {}
X.SECRET = SECRET

function X.Num(v)
    if type(v) ~= "number" or S.IsSecret(v) then error(SECRET, 0) end
    return v
end

local reported = {}
local function Handler(err)
    if err == SECRET then return SECRET end
    return err
end

-- 多重回傳值打包：中間有 nil 也不掉（`{ ... }` ＋ `unpack` 遇到洞會截斷）
function X.Pack(...)
    return { n = select("#", ...), ... }
end

-- 回傳 ok, ...。ok == false 時第二個值是錯誤（或 SECRET）。
function X.Try(label, fn, ...)
    local res = X.Pack(xpcall(fn, Handler, ...))
    if not res[1] and res[2] ~= SECRET and not reported[label] then
        reported[label] = true
        ns.ReportError(res[2])
    end
    return unpack(res, 1, res.n)
end

------------------------------------------------------------
-- 秘密值交給引擎畫：`FontString:SetFormattedText(template, ...)`
--
-- 12.1 戰鬥中（與受限內容裡）屬性 API 回的是秘密值。秘密值**拒絕被檢查** ——
-- 比較、算術、在 Lua 裡 `format`／`tostring` 都會炸 —— 但**畫得出來**：
-- `SetFormattedText` 是 C 端的 sink，秘密值當**參數**丟進去，引擎照樣把真的數字
-- 畫在畫面上，戰鬥中照樣跳動。做法照 EllesmereUI QoL 的 Secondary Stats overlay：
--
--   * 數字一律當參數，**template 只由明碼組成**（標籤要先過 `X.Esc` 把 `%` 跳脫，
--     不然翻譯裡的「%」會變成多出來的格式符）。
--   * 只在**明碼**時做的事：hideZero 的「等於 0」、兩個 getter 相加（臨機應變）、
--     多個法術系取最小（法術強度、爆擊）、評等的 BreakUpLargeNumbers。秘密時：
--     要相加／挑選的沿用**上一次明碼的結果**（EllesmereUI 同；從沒拿過明碼就顯示「—」），
--     hideZero 維持上一次的可見性，評等改用 `%d` 直接把秘密值當參數。
--   * ⚠ **餵過秘密值的 FontString 不能 GetStringWidth／GetStringHeight**（會炸），
--     而且**下一次明碼那一幀也還是秘密**（度量屬於上一次排版出來的字串）。
--     要量尺寸只在「這一輪全部明碼」時量，量到的寬高還要再問一次 `IsSecret`；
--     不是的話沿用上一次的尺寸，等下一輪（PLAYER_REGEN_ENABLED 會再畫一次）。
--   * 「—」只留給 nil（真的讀不到）；秘密值不再顯示「—」。
------------------------------------------------------------
local DASH = "\226\128\148"   -- 「—」
X.DASH = DASH

function X.IsSecret(v)
    return S.IsSecret(v)
end

-- 放進 template 的明碼字串：`%` 跳脫成 `%%`
function X.Esc(s)
    return (tostring(s or ""):gsub("%%", "%%%%"))
end

local function Push(args, v)
    args.n = (args.n or 0) + 1
    args[args.n] = v
end

-- 一格數值的 template ＋ 參數。把參數依序 push 進 `args`（`args.n` 記長度，中間不會有 nil），
-- 回傳 (template, 這一格有沒有餵秘密值)。
--   kind    "pct"｜"int"｜"dec"｜"speed"
--   v, v2   數值（可能是秘密值；nil ＝ 讀不到 ⇒「—」）。v2 只有 speed 用（副手）
--   rating  評等（可能是秘密值；nil ＝ 這一格沒有評等）
--   mode    pct 才看："pct"｜"rating"｜"pct_rating"｜"rating_pct"
--   sign    pct 才看：false ＝ 不要「%」
function X.ValueParts(args, kind, v, v2, rating, mode, sign)
    if v == nil then return DASH, false end
    local secret = S.IsSecret(v)
    if kind == "int" then
        if secret then
            Push(args, v)
            return "%.0f", true
        end
        Push(args, BreakUpLargeNumbers(math.floor(v + 0.5)))
        return "%s", false
    elseif kind == "dec" then
        Push(args, v)
        return "%.2f", secret
    elseif kind == "speed" then
        Push(args, v)
        if v2 ~= nil then
            Push(args, v2)
            return "%.2f / %.2f", secret or S.IsSecret(v2)
        end
        return "%.2f", secret
    end
    -- pct
    local pct = (sign == false) and "%.2f" or "%.2f%%"
    if rating == nil or mode == nil or mode == "pct" then
        Push(args, v)
        return pct, secret
    end
    local rt, rSecret
    if S.IsSecret(rating) then
        rt, rSecret = "%d", true
    else
        rt = "%s"
        rating = BreakUpLargeNumbers(math.floor(rating + 0.5))
    end
    if mode == "rating" then
        Push(args, rating)
        return rt, rSecret
    elseif mode == "rating_pct" then
        Push(args, rating)
        Push(args, v)
        return rt .. " (" .. pct .. ")", secret or rSecret
    end
    Push(args, v)
    Push(args, rating)
    return pct .. " (" .. rt .. ")", secret or rSecret
end

------------------------------------------------------------
-- 自畫的底與邊（Extras 不准用暴雪的 backdrop 模板 —— 它自帶的 OnSizeChanged Lua
-- 會跑進暴雪的執行堆疊，lint 也會擋）
--
-- 一張底 ＋ 四條邊，邊寬 `P.Pixel(1)`（1 個實體像素，見 Hairline）。
-- 回傳一張可換色的表：
--   bd:SetFill(c)／bd:SetBorder(c)     c ＝ { r, g, b, a }（或 nil 不變）
--   bd:SetFillShown(on)／bd:SetBorderShown(on)
-- 兩種皮：
--   設定視窗皮 X.Backdrop(f, T.fill, T.border)
--   HUD 皮     X.Backdrop(f, X.HUD_FILL, { T.Accent() })（0.102 灰 alpha 0.8 ＋ 1px 職業色邊，
--              .claude/notes/project-miliui-hud-skin.md）
------------------------------------------------------------
X.HUD_FILL = { 0.102, 0.102, 0.102, 0.8 }

local function Paint(tex, c)
    tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

function X.Backdrop(frame, fill, border)
    local bd = {}
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(WHITE)
    bg:SetAllPoints(frame)
    bd.bg = bg

    local px = P.Pixel(1)
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(px)
    local b = frame:CreateTexture(nil, "BORDER")
    b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(px)
    local l = frame:CreateTexture(nil, "BORDER")
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(px)
    local r = frame:CreateTexture(nil, "BORDER")
    r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(px)
    bd.edges = { t, b, l, r }
    for _, e in ipairs(bd.edges) do e:SetTexture(WHITE) end

    function bd:SetFill(c)
        if c then Paint(bg, c) end
    end
    function bd:SetBorder(c)
        if not c then return end
        for _, e in ipairs(self.edges) do Paint(e, c) end
    end
    function bd:SetFillShown(on)
        bg:SetShown(on and true or false)
    end
    function bd:SetBorderShown(on)
        for _, e in ipairs(self.edges) do e:SetShown(on and true or false) end
    end

    bd:SetFill(fill or T.fill)
    bd:SetBorder(border or T.border)
    return bd
end

------------------------------------------------------------
-- 屬性清單的「編輯狀態」（角色面板右上角的齒輪開的設定面板開著＝on）
--
-- 不存檔：每次登入都是關的。狀態本身放在這裡（而不是 StatsSettings.lua），因為
-- 清單（CharacterStats.lua）與畫面顯示（StatsHud.lua）都要聽 —— 誰先載入都一樣。
-- `X.OnEditChanged(fn)` 登記監聽，`X.SetEditing(on)` 改狀態並通知（沒變就不通知）。
------------------------------------------------------------
local editing = false
local editListeners = {}

function X.IsEditing()
    return editing
end

function X.OnEditChanged(fn)
    editListeners[#editListeners + 1] = fn
end

function X.SetEditing(on)
    on = on and true or false
    if on == editing then return end
    editing = on
    for _, fn in ipairs(editListeners) do
        xpcall(fn, ns.ReportError, on)
    end
end

-- 「屬性的設定改了」：清單與畫面顯示各自登記重畫（顏色、隱藏、排序、評等…）
local changeListeners = {}

function X.OnStatsChanged(fn)
    changeListeners[#changeListeners + 1] = fn
end

function X.NotifyStatsChanged(what)
    for _, fn in ipairs(changeListeners) do
        xpcall(fn, ns.ReportError, what)
    end
end

------------------------------------------------------------
-- 髮絲線：1 個**實體**像素（P.Pixel，不是 P.Scale —— 1440p 以上 P.Scale(1) 是 2px）
------------------------------------------------------------
function X.Hairline(parent, color, layer)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK")
    tex:SetTexture(WHITE)
    tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    tex:SetHeight(P.Pixel(1))
    return tex
end

------------------------------------------------------------
-- 捲動容器 ＋ 套組那種細捲軸
--
-- 不用 `ScrollFrameTemplate`：它帶的是暴雪的 MinimalScrollBar（兩端兩顆立體箭頭），
-- 我們要的是 Skin 換皮後的那種長相 —— `T.scrollTrack` 的軌道上一條置中的
-- `T.scrollThumb` 細條，沒有箭頭。整支只碰自己建的框。
--
-- 回傳 scroll（ScrollFrame）。用法：
--   scroll.child                    捲動內容，寬度自動跟著 scroll 走
--   scroll:SetContentHeight(h)      內容高度變了就叫
--   scroll:ScrollToTop()
-- opts.step：滾輪一格捲多少（預設 32）
------------------------------------------------------------
local BAR_W = 6          -- 軌道寬（拇指同寬，T.scrollThumbSize）
local BAR_GAP = 3        -- 內容與軌道之間
local THUMB_MIN = 16

function X.CreateScroll(parent, opts)
    opts = opts or {}
    local step = opts.step or 32
    local barW = T.scrollThumbSize or BAR_W

    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll.child = child

    local track = CreateFrame("Frame", nil, parent)
    track:SetWidth(barW)
    track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
    track:SetFrameLevel(scroll:GetFrameLevel() + 5)
    local trackTex = track:CreateTexture(nil, "BACKGROUND")
    trackTex:SetAllPoints()
    trackTex:SetColorTexture(T.scrollTrack[1], T.scrollTrack[2], T.scrollTrack[3], T.scrollTrack[4] or 1)

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(barW)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:SetHeight(THUMB_MIN)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    local function PaintThumb(hover)
        local c = hover and T.scrollThumbHover or T.scrollThumb
        thumbTex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
    PaintThumb(false)

    local contentH = 0
    local dragging, dragStartY, dragStartOffset

    local function ViewHeight()
        local h = S.PlainNumber(scroll:GetHeight())
        return h or 0
    end

    local function Range()
        return math.max(0, contentH - ViewHeight())
    end

    local function UpdateThumb()
        local view = ViewHeight()
        local range = Range()
        if range <= 0 or view <= 0 then
            track:Hide()
            return
        end
        track:Show()
        local th = math.max(THUMB_MIN, view * view / contentH)
        thumb:SetHeight(th)
        local offset = scroll:GetVerticalScroll() or 0
        local y = (view - th) * (offset / range)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -y)
    end

    local function SetOffset(v)
        local range = Range()
        if v < 0 then v = 0 elseif v > range then v = range end
        scroll:SetVerticalScroll(v)
        UpdateThumb()
    end
    scroll.SetOffset = function(_, v) SetOffset(v) end

    -- 內容寬度：軌道顯示時讓出軌道寬 ＋ 間距（軌道不顯示也讓 —— 內容寬不跟著跳）
    local function SyncWidth()
        local w = S.PlainNumber(scroll:GetWidth())
        if w and w > 0 then child:SetWidth(math.max(1, w - barW - BAR_GAP)) end
    end

    function scroll:SetContentHeight(h)
        contentH = h or 0
        child:SetHeight(math.max(1, contentH))
        SyncWidth()
        SetOffset(scroll:GetVerticalScroll() or 0)
    end

    function scroll:ScrollToTop()
        SetOffset(0)
    end

    function scroll:ContentWidth()
        local w = S.PlainNumber(scroll:GetWidth()) or 0
        return math.max(1, w - barW - BAR_GAP)
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        SetOffset((scroll:GetVerticalScroll() or 0) - delta * step)
    end)
    scroll:SetScript("OnSizeChanged", function()
        SyncWidth()
        SetOffset(scroll:GetVerticalScroll() or 0)
    end)

    thumb:SetScript("OnEnter", function() PaintThumb(true) end)
    thumb:SetScript("OnLeave", function() if not dragging then PaintThumb(false) end end)
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local _, y = GetCursorPosition()
        dragging = true
        dragStartY = y / (self:GetEffectiveScale() or 1)
        dragStartOffset = scroll:GetVerticalScroll() or 0
        self:SetScript("OnUpdate", function(me)
            local _, cy = GetCursorPosition()
            cy = cy / (me:GetEffectiveScale() or 1)
            local view = ViewHeight()
            local room = view - (me:GetHeight() or 0)
            if room <= 0 then return end
            SetOffset(dragStartOffset + (dragStartY - cy) * Range() / room)
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        dragging = false
        self:SetScript("OnUpdate", nil)
        if not self:IsMouseOver() then PaintThumb(false) end
    end)
    -- 點軌道空白處：往那個方向翻一頁
    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function(self)
        local _, cy = GetCursorPosition()
        cy = cy / (self:GetEffectiveScale() or 1)
        local top = thumb:GetTop()
        local page = ViewHeight() * 0.9
        local cur = scroll:GetVerticalScroll() or 0
        if top and cy > top then SetOffset(cur - page) else SetOffset(cur + page) end
    end)

    track:Hide()
    return scroll
end
