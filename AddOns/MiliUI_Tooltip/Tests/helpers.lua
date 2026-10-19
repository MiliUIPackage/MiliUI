------------------------------------------------------------
-- 離線測試共用：check／eq、秘密值哨兵、假框、假環境、載入器（不進 TOC，不是 *_test）
--
--   local H = dofile(here .. "/helpers.lua")
--
-- 秘密值用一個帶 metamethod 的哨兵表：比較、算術、串接都當場 error ⇒
-- 「測試沒炸」就證明受測程式碼沒有讀它（只傳遞）。
------------------------------------------------------------
local H = {}

H.passed, H.failed = 0, 0
function H.check(name, cond, detail)
    if cond then
        H.passed = H.passed + 1
    else
        H.failed = H.failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
function H.eq(name, got, want)
    H.check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end
function H.near(name, got, want, eps)
    H.check(name, type(got) == "number" and math.abs(got - want) <= (eps or 1e-6),
        "got " .. tostring(got) .. ", want " .. tostring(want))
end
function H.finish(title)
    print(("%s: %d passed, %d failed"):format(title, H.passed, H.failed))
    if H.failed > 0 then os.exit(1) end
end

local function boom(what) return function() error(what .. " a secret", 2) end end
H.SECRET = setmetatable({}, {
    __tostring = function() return "<secret>" end,
    __eq = boom("compared"), __lt = boom("compared"), __le = boom("compared"),
    __add = boom("arithmetic on"), __sub = boom("arithmetic on"), __mul = boom("arithmetic on"),
    __div = boom("arithmetic on"), __concat = boom("concatenated"), __len = boom("length of"),
    __index = boom("indexed"), __newindex = boom("indexed"),
})
function H.IsSecret(v) return rawequal(v, H.SECRET) end

------------------------------------------------------------
-- 假框：記錄 setter 呼叫，getter 回記下的值
------------------------------------------------------------
local Region = {}
Region.__index = function(self, k)
    local m = Region[k]
    if m ~= nil then return m end
    return nil
end

function Region:SetPoint(p, rel, rp, x, y)
    self.points[#self.points + 1] = { p, rel, rp, x, y }
end
function Region:ClearAllPoints() self.points = {} end
function Region:SetAllPoints(rel) self.points = { { "ALL", rel } } end
function Region:GetNumPoints() return #self.points end
function Region:GetPoint(i) local p = self.points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
function Region:SetSize(w, h) self.w, self.h = w, h end
function Region:SetWidth(w) self.w = w end
function Region:SetHeight(h) self.h = h end
function Region:GetWidth() return self.w end
function Region:GetHeight() return self.h end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetShown(v) self.shown = v and true or false end
function Region:IsShown() return self.shown end
function Region:SetAlpha(a) self.alpha = a end
function Region:GetAlpha() return self.alpha end
function Region:SetScale(s) self.scale = s end
function Region:GetScale() return self.scale end
function Region:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Region:SetFrameLevel(l) self.level = l end
function Region:GetFrameLevel() return self.level or 1 end
function Region:SetFrameStrata(s) self.strata = s end
function Region:GetFrameStrata() return self.strata or "MEDIUM" end
function Region:SetClampedToScreen(v) self.clamped = v end
function Region:IsClampedToScreen() return self.clamped and true or false end
function Region:SetClampRectInsets(l, r, t, b) self.clampInsets = { l, r, t, b } end
function Region:GetClampRectInsets() local c = self.clampInsets or { 0, 0, 0, 0 }; return c[1], c[2], c[3], c[4] end
function Region:GetParent() return self.parent end
function Region:GetName() return self.name end
function Region:IsForbidden() return false end
function Region:SetScript(event, fn) self.scripts[event] = fn end
function Region:HookScript(event, fn) self.scripts[event] = fn end
function Region:HasScript() return true end
function Region:EnableMouse() end
-- 貼圖
function Region:SetTexture(t) self.texture = t end
function Region:SetTexCoord() end
function Region:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
function Region:SetColorTexture() end
function Region:SetDrawLayer(layer, sub) self.layer, self.sublevel = layer, sub end
function Region:SetRotation(r) self.rotation = r end
function Region:SetAtlas(a) self.atlas = a; self.texture = nil end
function Region:SetBlendMode() end
function Region:SetDesaturated(v) self.desaturated = v end
-- 文字
function Region:SetFont(path, size, flags)
    self.font, self.size, self.flags = path, size, flags
    return true
end
function Region:GetFont() return self.font, self.size, self.flags end
function Region:SetFontObject() self.size = self.size or 12 end
function Region:SetShadowOffset() end
function Region:SetShadowColor() end
function Region:GetShadowOffset() return 1, -1 end
function Region:GetShadowColor() return 0, 0, 0, 0.9 end
function Region:SetJustifyH(j) self.justifyH = j end
function Region:SetJustifyV() end
function Region:SetWordWrap() end
function Region:SetTextColor(r, g, b) self.textColor = { r, g, b } end
function Region:GetTextColor() local c = self.textColor or { 1, 1, 1 }; return c[1], c[2], c[3], 1 end
function Region:SetText(t)
    if not self.size then error("FontString:SetText(): Font not set") end
    self.text = t
end
function Region:GetText() return self.text end
-- 假字寬：每個位元組 size × 0.5（夠用來驗幾何）
function H.TextWidth(text, size)
    return #(text or "") * (size or 12) * 0.5
end
function Region:GetUnboundedStringWidth() return H.TextWidth(self.text, self.size) end
function Region:GetStringWidth() return H.TextWidth(self.text, self.size) end
function Region:GetStringHeight()
    local tw = H.TextWidth(self.text, self.size)
    local lines = 1
    if self.w and self.w > 0 and tw > self.w then lines = math.ceil(tw / self.w) end
    return lines * (self.size or 12)
end
-- 子物件
function Region:CreateTexture(_, layer)
    local t = H.Region("Texture", self)
    t.layer = layer
    self.children[#self.children + 1] = t
    return t
end
function Region:CreateFontString()
    local t = H.Region("FontString", self)
    self.children[#self.children + 1] = t
    return t
end

function H.Region(kind, parent, name)
    return setmetatable({
        kind = kind, parent = parent, name = name, points = {}, scripts = {}, children = {},
        shown = kind ~= "Frame", alpha = 1,
    }, Region)
end
H.RegionMethods = Region

------------------------------------------------------------
-- 假環境
------------------------------------------------------------
function H.Env(extra)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.unpack = env.unpack or table.unpack
    env.issecretvalue = H.IsSecret
    env.GetLocale = function() return "zhTW" end
    env.UIParent = H.Region("Frame", nil, "UIParent")
    env.UIParent.shown = true
    env.CreateFrame = function(kind, name, parent)
        local f = H.Region(kind or "Frame", parent, name)
        f.RegisterEvent = function() end
        f.UnregisterEvent = function() end
        f.Click = function(self) self.clicks = (self.clicks or 0) + 1 end
        if name then env[name] = f end
        return f
    end
    -- 1 UI 單位 = 1 實體像素 × 縮放；Snap 到 1/scale 的格
    env.PixelUtil = {
        GetNearestPixelSize = function(v, scale)
            local px = 1 / scale
            return math.floor(v / px + 0.5) * px
        end,
        GetPixelToUIUnitFactor = function() return 1 end,
    }
    -- hooksecurefunc(table, method, fn)：把原方法包起來、之後呼叫 fn（跟遊戲一樣是後掛勾）
    env.hooksecurefunc = function(t, method, fn)
        local orig = t[method]
        t[method] = function(...)
            local r = { orig(...) }
            fn(...)
            return table.unpack(r)
        end
    end
    env.now = 0
    env.GetTime = function() return env.now end
    env.timers = {}
    env.C_Timer = {
        After = function(_, fn) env.timers[#env.timers + 1] = fn end,
        NewTicker = function() return { Cancel = function() end } end,
    }
    function env.FlushTimers()
        local list = env.timers
        env.timers = {}
        for _, fn in ipairs(list) do fn() end
    end
    env.Enum = {
        TooltipDataType = { Item = 0, Spell = 1, Unit = 2 },
        -- 12.1.5 實值（Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua）
        TooltipDataLineType = {
            None = 0, Blank = 1, UnitName = 2, GemSocket = 3, LearnableSpell = 6, SellPrice = 11,
            ProfessionCraftingQuality = 12, SpellName = 13, ItemEnchantmentPermanent = 15, NestedBlock = 19,
            ItemBinding = 20, EquipSlot = 21, ItemName = 22, Separator = 23, GemSocketEnchantment = 30,
            ItemLevel = 31, ItemUpgradeLevel = 32, SpellPassive = 33, SpellDescription = 34, ItemQuality = 35,
            TradeTimeRemaining = 36, FlavorText = 37, ItemSpellTriggerLearn = 38, ErrorLine = 41, DisabledLine = 42,
            UsageRequirement = 43, ItemSpellTriggerOnUse = 44, ItemSpellTriggerOnEquip = 45, ItemSpellTriggerOnProc = 46,
        },
    }
    env.GameTooltipText = H.Region("Font"); env.GameTooltipText:SetFont("body.ttf", 12, "")
    env.GameTooltipHeaderText = H.Region("Font"); env.GameTooltipHeaderText:SetFont("title.ttf", 14, "")
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    for k, v in pairs(extra or {}) do env[k] = v end
    return env
end

function H.Load(env, ns, rel, addon)
    local here = H.here
    local path = here .. "/../" .. rel
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    assert(chunk, err)
    chunk(addon or "MiliUI_Tooltip", ns)
end

-- 一個 tooltip 假框：行用 TextLeftN／TextRightN 全域
function H.Tip(env, name, lines)
    local tip = env.CreateFrame("GameTooltip", name, env.UIParent)
    tip.shown = true
    tip.w, tip.h = 200, 100
    tip.padding = { 0, 0, 0, 0 }
    tip.left, tip.top = 100, 500
    function tip:GetPadding() local p = self.padding; return p[1], p[2], p[3], p[4] end
    function tip:SetPadding(r, b, l, t)
        self.padCalls = (self.padCalls or 0) + 1
        local p = self.padding
        self.w = self.w + (r - p[1]); self.h = self.h + (b - p[2])
        self.padding = { r, b, l, t }
    end
    local setAlpha = tip.SetAlpha
    function tip:SetAlpha(a) self.alphaCalls = (self.alphaCalls or 0) + 1; setAlpha(self, a) end
    function tip:NumLines() return #self.lines end
    function tip:GetLeft() return self.left end
    function tip:GetRight() return self.left + self.w end
    function tip:GetTop() return self.top end
    function tip:GetBottom() return self.top - self.h end
    tip:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 100, 100)
    tip.lines = {}
    function tip:SetLines(list)
        self.lines = list
        for i, l in ipairs(list) do
            local left = env[name .. "TextLeft" .. i] or H.Region("FontString", self)
            local right = env[name .. "TextRight" .. i] or H.Region("FontString", self)
            left.size, right.size = 12, 12
            left.text, left.textColor, left.shown = l.left, l.color or { 1, 1, 1 }, true
            right.text, right.textColor, right.shown = l.right, l.rightColor or { 1, 1, 1 }, l.right ~= nil
            env[name .. "TextLeft" .. i], env[name .. "TextRight" .. i] = left, right
        end
    end
    tip:SetLines(lines or {})
    return tip
end

-- 比價框的標頭（暴雪的 CompareHeader 是 tooltip 上方獨立的框，字在 .Label）
function H.CompareHeader(tip, text, shown)
    local header = H.Region("Frame", tip)
    header.shown = shown ~= false
    header.Label = H.Region("FontString", header)
    header.Label.size, header.Label.text = 12, text
    tip.CompareHeader = header
    return header
end

return H
