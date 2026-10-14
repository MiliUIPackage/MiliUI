------------------------------------------------------------
-- 自建功能（Extras/）的共用件：啟動、細捲軸、線條箭頭
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
-- 讀值與組 tooltip 的程式一律包在 `X.Try` 裡，數字先過 `X.Num`：
-- 拿到秘密值（或不是數字）就丟一個哨兵錯誤，整段收手、顯示「—」。
-- 這樣「秘密值不能算術／比較」的規則不必在每一行重寫一次，而且**不會**半途
-- 算到一半才炸在 `format` 裡。哨兵以外的錯誤是真的 bug，照常交給 ns.ReportError
-- （每個 label 只報一次，事件一秒好幾發，不能洗版）。
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
-- 線條 chevron（∧／∨），同 `Engine` 的 BuildGlyph：兩條 CreateLine 畫在自己的框上。
-- 半高比半寬小（±0.5 對 ±1），不然小尺寸下像半個箭頭。回傳線的陣列（換色用）。
------------------------------------------------------------
local CHEVRON = {
    up   = { { -1, -0.5, 0,  0.5 }, { 0,  0.5, 1, -0.5 } },
    down = { { -1,  0.5, 0, -0.5 }, { 0, -0.5, 1,  0.5 } },
}

function X.Chevron(frame, dir, size, color)
    local half = (size or 8) / 2
    local lines = {}
    for _, seg in ipairs(CHEVRON[dir]) do
        local line = frame:CreateLine(nil, "ARTWORK")
        line:SetThickness(P.Pixel(1.5))
        line:SetTexture(WHITE)
        line:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        line:SetStartPoint("CENTER", frame, seg[1] * half, seg[2] * half)
        line:SetEndPoint("CENTER", frame, seg[3] * half, seg[4] * half)
        lines[#lines + 1] = line
    end
    return lines
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
