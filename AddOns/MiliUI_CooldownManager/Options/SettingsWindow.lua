------------------------------------------------------------
-- 「一列一個設定小視窗」的共用殼（資源條每種資源的設定 Options/ResourceSettings.lua、天空騎術每一列的設定
-- Options/SkyridingSettings.lua 共用）
--
--   local win = ns.SettingsWindow.New({
--       id        = "resourcesettings",          -- 回呼登記的名字（要唯一）
--       configKey = "resources",                 -- 表單讀寫哪張設定表（Specs.MakeCtx 的 key）
--       width     = 540, maxH = 560,
--       controls  = function(key) → specs,       -- 這一列的表單
--       signature = function(key) → string,      -- 表單的「形狀」：一樣就重用（frame 刪不掉）
--       prepare   = function(key, specs, ctx) → specs,   -- 可選：建表單前加工（子分頁過濾）
--       onApply   = function(spec),              -- 值寫進去之後（重排引擎）；換形狀的比對由殼延一幀做
--       onHide    = function(),                  -- 可選：視窗關掉時（收跟著它的彈窗）
--       hideOn    = { "OptionsHidden", … },      -- 這些回呼一來就關
--   })
--   win:Open(key, title, icon)   開（已經開著就換成這一列）
--   win:Close() ／ win:Refresh() ／ win:ShowForm(reset) ／ win:IsOpen() ／ win:Current()
--
-- 非強制回應的小視窗：DIALOG 300，彈窗（確認、門檻）在 FULLSCREEN_DIALOG 蓋在它上面。
-- 開窗時**貼在設定視窗右邊**（右邊放不下改左邊，再不行交給 PlaceClamped 平移）：蓋在設定視窗正中央的話，
-- 列表那排被遮住，要換另一列得先關窗。一次只開一個；表單照形狀快取。
------------------------------------------------------------
local _, ns = ...

local W, P = ns.W, ns.P

local Options = ns.Options

ns.SettingsWindow = {}
local SW = ns.SettingsWindow

local PAD     = 12
local HEAD_H  = 30
SW.PAD, SW.HEAD_H = PAD, HEAD_H

local Win = {}
Win.__index = Win

function SW.New(opts)
    local win = setmetatable({ opts = opts, forms = {} }, Win)
    win.width = opts.width or 540
    win.maxH = opts.maxH or 560
    win.formW = win.width - PAD * 2 - 24      -- 扣掉捲軸
    return win
end

function Win:Build()
    if self.frame then return end
    local frame = W.CreateFrame(nil, Options.panel, self.width, 300)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(300)
    frame:SetBackdropBorderColor(W.Accent(1))
    frame:SetPoint("CENTER")
    frame:Hide()
    W.CloseOnEscape(frame)
    self.frame = frame

    local close = W.CreateButton(frame, "", "red", 18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    local x = close:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(10, 10)
    x:SetPoint("CENTER")
    close:SetScript("OnClick", function() frame:Hide() end)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    P.Size(icon, 20, 20)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", PAD, -PAD + 2)
    frame.icon = icon
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    frame.title = title              -- 錨點在 SetHeader（有沒有圖示兩種排法）

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD - 4, -(PAD + HEAD_H))
    holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, PAD)
    self.scroll = W.CreateScrollFrame(holder)

    local opts = self.opts
    if opts.onHide then frame:HookScript("OnHide", opts.onHide) end
    for _, ev in ipairs(opts.hideOn or { "OptionsHidden", "ProfileChanged" }) do
        ns.RegisterCallback(ev, opts.id, function() frame:Hide() end)
    end
end

-- 標題：文字＋（有的話）前面一顆圖示
function Win:SetHeader(text, tex)
    local frame = self.frame
    frame.icon:SetShown(tex ~= nil)
    if tex then frame.icon:SetTexture(tex) end
    frame.title:ClearAllPoints()
    if tex then
        frame.title:SetPoint("LEFT", frame.icon, "RIGHT", 8, 0)
    else
        frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD - 1)
    end
    frame.title:SetPoint("RIGHT", frame, "RIGHT", -28, 0)
    frame.title:SetText(text or "")
end

-- 視窗高度：內容少就縮、最多 maxH。keepTop：換表單形狀時上緣不動（往下長）
function Win:Fit(form, keepTop)
    local frame = self.frame
    local h = math.min(self.maxH, PAD + HEAD_H + form.height + PAD)
    local parent = frame:GetParent()
    local top, pb = frame:GetTop(), parent and parent:GetBottom()
    local pcx = parent and parent:GetCenter()
    local fcx = frame:GetCenter()
    P.Height(frame, h)
    if keepTop and top and pb and pcx and fcx then
        frame:ClearAllPoints()
        frame:SetPoint("TOP", parent, "BOTTOM", fcx - pcx, top - pb)
    else
        local pts = { "TOPLEFT", parent, "TOPRIGHT", 6, 0 }
        local right, sw = parent and parent:GetRight(), UIParent:GetRight()
        if right and sw and right + self.width + 10 > sw then
            pts = { "TOPRIGHT", parent, "TOPLEFT", -6, 0 }
        end
        W.PlaceClamped(frame, pts)
    end
    return h - PAD - HEAD_H - PAD
end

-- 值寫進去之後：引擎重排（opts.onApply），形狀可能變了 ⇒ 延一幀再比對，不在按鈕的處理器裡換表單
function Win:Applied(spec)
    if self.opts.onApply then self.opts.onApply(spec) end
    ns.Defer(function()
        if self:IsOpen() and (self.frame.sig ~= self.opts.signature(self.cur) or (spec and spec.refreshPage)) then
            self:ShowForm(false)
        end
    end)
end

-- reset：換列或剛開窗（捲回最上面、重新貼位置）；否則同一列換表單形狀（維持捲動位置與上緣）
function Win:ShowForm(reset)
    local frame, key = self.frame, self.cur
    if not (frame and key) then return end
    local opts = self.opts
    local sig = opts.signature(key)
    local form = self.forms[sig]
    if not form then
        local ctx
        ctx = ns.Specs.MakeCtx({ mode = "panel", key = opts.configKey }, function(spec) self:Applied(spec) end)
        local specs = opts.controls(key)
        if opts.prepare then specs = opts.prepare(key, specs, ctx) or specs end
        form = ns.Specs.BuildForm(self.scroll.child, specs, ctx, self.formW)
        self.forms[sig] = form
    end
    for _, fm in pairs(self.forms) do fm.content:SetShown(fm == form) end
    local scroll = self.scroll
    local keep = (not reset) and scroll:GetVerticalScroll() or 0
    frame.form, frame.sig = form, sig
    local viewH = self:Fit(form, not reset)
    scroll:SetContentHeight(form.height)
    scroll:SetVerticalScroll(math.min(keep, math.max(0, form.height - viewH)))
    form:Refresh()
end

function Win:Open(key, title, tex)
    self:Build()
    if not self.frame then return end
    self.cur = key
    self:SetHeader(title, tex)
    -- 先 Show 再建表單：說明列的換行高度要在顯示中才量得準
    self.frame:Show()
    self:ShowForm(true)
end

function Win:Close()
    if self.frame then self.frame:Hide() end
end

function Win:IsOpen()
    return self.frame and self.frame:IsShown() and self.cur ~= nil or false
end

function Win:Current() return self.cur end

-- 開著就重讀（別的頁改了它顯示的值）：形狀變了換表單，否則原地 Refresh
function Win:Refresh()
    if not self:IsOpen() then return end
    if self.frame.sig ~= self.opts.signature(self.cur) then
        self:ShowForm(false)
    elseif self.frame.form then
        self.frame.form:Refresh()
    end
end
