------------------------------------------------------------
-- Modules/Anchor.lua（戰鬥中按修飾鍵叫回提示）＋Core/Bar.lua 引擎血條閘的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/Anchor_test.lua
--
-- 覆蓋（2026-10-25 玩家回報：戰鬥中按修飾鍵叫回「探究者的補給品」，底下冒出血條、滑開後跟著游標飛）：
-- 世界單位叫回來用 SetUnit("mouseover")，血條照叫回來時世界游標那份的 healthGUID；內容被換掉就不再管；
-- 滑鼠離開（世界游標沒東西）照 SetWorldCursor 的規則收（Default 淡出、其他藏）；滑到別的東西上不收；
-- 頭像框照舊 SetUnit(unit)、不記；放開修飾鍵藏掉；不在戰鬥不動。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local H = dofile(here .. "/helpers.lua")
H.here = here
local check, eq = H.check, H.eq
local SECRET = H.SECRET

local function AnchorDB(inherit)
    return {
        position = inherit and "inherit" or "cursor",
        hiddenInCombat = not inherit,
        modifierShowInCombatKey = inherit and "global" or "shift",
        returnInCombat = false, returnOnUnitFrame = false,
        x = -30, y = 30, p = "BOTTOMRIGHT", cp = "BOTTOMLEFT", cx = 0, cy = 0,
    }
end

local function Setup()
    local env = H.Env()
    local frames = {}
    local createFrame = env.CreateFrame
    env.CreateFrame = function(...)
        local f = createFrame(...)
        f.events = {}
        f.RegisterEvent = function(self, e) self.events[e] = true end
        frames[#frames + 1] = f
        return f
    end
    local defaultAnchorHooks = {}
    local hook = env.hooksecurefunc
    env.hooksecurefunc = function(a, b, c)
        if type(a) == "string" then defaultAnchorHooks[a] = b return end
        return hook(a, b, c)
    end
    env.strupper = string.upper
    env.floor = math.floor
    env.combat = true
    env.InCombatLockdown = function() return env.combat end
    env.shift = false
    env.IsShiftKeyDown = function() return env.shift end
    env.IsAltKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.mouseoverExists = true
    env.UnitExists = function(u) if u == "mouseover" then return env.mouseoverExists end return u == "party1" end
    env.UnitIsPlayer = function(u) return u == "party1" end
    env.focus = H.Region("Frame", nil, "WorldFrame")      -- 游標下沒有頭像框
    env.GetMouseFoci = function() return { env.focus } end
    env.worldData = { type = 2, healthGUID = nil }        -- 補給品：世界游標那份沒有 healthGUID
    env.C_TooltipInfo = { GetWorldCursor = function() return env.worldData end }
    env.Enum.WorldCursorAnchorType = { None = 0, Default = 1, Cursor = 2, Nameplate = 3 }

    -- GameTooltip：SetOwner／SetUnit／Hide 照暴雪的語意（Hide 清 owner 與 infoList；沒有 owner 的 Show 是空操作）
    local tip = H.Tip(env, "GameTooltip")
    tip.shown = false
    tip.StatusBar = H.Region("StatusBar", tip)
    tip.StatusBar.shown = true      -- 引擎血條：GetUnit 那份有 healthGUID ⇒ SetWatch 過
    tip.setUnits = {}
    function tip:SetOwner(owner, anchorType)
        self.ownerCalls = (self.ownerCalls or 0) + 1
        self.owner, self.anchorType, self.infoList = owner, anchorType, nil
    end
    function tip:GetOwner() return self.owner end
    function tip:GetAnchorType() return self.anchorType end
    function tip:SetAnchorType(anchorType, x, y)
        self.anchorTypeCalls = (self.anchorTypeCalls or 0) + 1
        self.anchorType, self.anchorX, self.anchorY = anchorType, x, y
    end
    function tip:SetUnit(unit)
        self.setUnits[#self.setUnits + 1] = unit
        self.infoList = { { getterName = "GetUnit", getterArgs = { unit } } }
        if env.onPostCall then env.onPostCall(self) end      -- post-call 在 SetUnit 回來之前
        if self.owner then self.shown = true end
        return true
    end
    function tip:GetPrimaryTooltipInfo() return self.infoList and self.infoList[1] end
    function tip:Show() if self.owner then self.shown = true end end
    function tip:Hide() self.shown, self.owner, self.infoList = false, nil, nil end
    function tip:FadeOut() self.fades = (self.fades or 0) + 1 end
    -- 暴雪的 SetWorldCursor 換上新內容
    function tip:WorldCursorContent() self.infoList = { { getterName = "GetWorldCursor" } } end
    -- 暴雪的 SetWorldCursor 整支（Blizzard_GameTooltip/Mainline/GameTooltip.lua）：Default 走 SetDefaultAnchor；
    -- Cursor 直接 SetOwner(UIParent, "ANCHOR_CURSOR")（地上的戰利品物件是 ANCHOR_CURSOR_RIGHT），引擎把框貼到游標；
    -- 有資料就畫內容＋Show，沒有（滑開）就收掉自己那份
    function tip:SetWorldCursor(anchorType)
        local data = env.C_TooltipInfo.GetWorldCursor()
        local old = self:GetPrimaryTooltipInfo()
        if anchorType == 1 then
            self:SetOwner(env.UIParent, "ANCHOR_NONE")
            self:ClearAllPoints()
            self:SetPoint("BOTTOMRIGHT", env.UIParent, "BOTTOMRIGHT", -13, 76)
            defaultAnchorHooks.GameTooltip_SetDefaultAnchor(self, env.UIParent)
        elseif anchorType == 2 then
            self:SetOwner(env.UIParent, data and data.worldLootObjectInventoryType and "ANCHOR_CURSOR_RIGHT" or "ANCHOR_CURSOR")
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 640, 300)
        end
        if data then
            self:WorldCursorContent()
            self:Show()
        elseif old and old.getterName == "GetWorldCursor" then
            self:Hide()
        end
    end

    local barState = { barUnit = "mouseover" }
    local ns = {
        db = { anchor = AnchorDB(false), unit = { player = { anchor = AnchorDB(true) }, npc = { anchor = AnchorDB(true) } },
            statusbar = { hideInCombat = false } },
        P = { Scale = function(v) return v end },
        Media = {},
        Colors = {},
        ReportError = function() end,
        Skin = {
            Get = function(t) if t == tip then return barState end end,
            Poll = function() end,
        },
    }
    for _, f in ipairs({ "Libs/MiliUIWidgets/Secret.lua", "Core/Bar.lua", "Modules/Anchor.lua" }) do
        H.Load(env, ns, f)
    end
    barState.bar = H.Region("StatusBar")
    barState.bar.shown = false
    local watcher
    for _, f in ipairs(frames) do
        if f.events.MODIFIER_STATE_CHANGED then watcher = f end
    end
    local t = { env = env, ns = ns, tip = tip, watcher = watcher, bar = barState.bar, defaultAnchorHooks = defaultAnchorHooks }
    function t.Event(event, ...) watcher.scripts.OnEvent(watcher, event, ...) end
    function t.Shift(down)
        env.shift = down
        t.Event("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    end
    -- 戰鬥中滑到世界裡的東西上：暴雪 SetWorldCursor → SetDefaultAnchor（我們的掛勾藏掉）
    function t.Enter(anchorType)
        t.Event("WORLD_CURSOR_TOOLTIP_UPDATE", anchorType)
        tip:SetOwner(env.UIParent, "ANCHOR_NONE")
        tip:Hide()
    end
    return t
end

check("前提：找到修飾鍵 watcher", Setup().watcher ~= nil)
check("前提：watcher 也聽世界游標", Setup().watcher.events.WORLD_CURSOR_TOOLTIP_UPDATE)

------------------------------------------------------------
-- 1. 世界單位（補給品）叫回來：SetUnit("mouseover")，血條照世界游標那份（沒有）
------------------------------------------------------------
do
    local t = Setup()
    local A = t.ns.Anchor
    local duringPostCall = "unset"
    t.env.onPostCall = function(tip) duringPostCall = A.ReviveHealth(tip) end
    t.Enter(1)
    t.Shift(true)
    eq("叫回：SetUnit 一次", #t.tip.setUnits, 1)
    eq("叫回：用 mouseover", t.tip.setUnits[1], "mouseover")
    check("叫回：提示顯示", t.tip.shown)
    eq("叫回：post-call 當下就知道不要血條", duringPostCall, false)
    eq("叫回：之後也一樣", A.ReviveHealth(t.tip), false)
    -- Bar 的閘：引擎血條開著（GetUnit 那份有 healthGUID），我們的條照世界游標那份不畫
    t.bar.shown = true
    t.ns.Bar.Refresh(t.tip)
    check("血條：叫回來的補給品不畫", not t.bar.shown)
    -- 別的提示接手（內容換掉）⇒ 不再管，照引擎血條
    t.tip:WorldCursorContent()
    eq("內容換掉：不再管", A.ReviveHealth(t.tip), nil)
    t.env.mouseoverExists = false           -- RefreshInner 讀到單位不在就停（維持畫面），不碰其他 API
    t.ns.Bar.Refresh(t.tip)
    check("內容換掉：照引擎血條畫", t.bar.shown)
end

------------------------------------------------------------
-- 2. 有血量的單位：世界游標那份有 healthGUID（秘密也算有）⇒ 畫
------------------------------------------------------------
do
    local t = Setup()
    t.env.worldData = { type = 2, healthGUID = SECRET }
    t.Enter(1)
    t.Shift(true)
    eq("有血量：要血條", t.ns.Anchor.ReviveHealth(t.tip), true)
end

------------------------------------------------------------
-- 3. 叫回來之後滑鼠離開：暴雪的 SetWorldCursor 只收 GetWorldCursor 的內容 ⇒ 我們照它的規則收
------------------------------------------------------------
do
    -- Default：淡出
    local t = Setup()
    t.Enter(1)
    t.Shift(true)
    t.env.worldData = nil
    t.Event("WORLD_CURSOR_TOOLTIP_UPDATE", 1)
    eq("離開（Default）：淡出", t.tip.fades, 1)
    eq("離開後：不再管", t.ns.Anchor.ReviveHealth(t.tip), nil)
    t.Event("WORLD_CURSOR_TOOLTIP_UPDATE", 1)
    eq("離開後：不重複收", t.tip.fades, 1)

    -- Cursor：直接藏
    local c = Setup()
    c.Enter(2)
    c.Shift(true)
    check("前提：顯示中", c.tip.shown)
    c.env.worldData = nil
    c.Event("WORLD_CURSOR_TOOLTIP_UPDATE", 2)
    check("離開（Cursor）：藏掉", not c.tip.shown)
    eq("離開（Cursor）：不淡出", c.tip.fades, nil)

    -- 滑到別的東西上：不收（暴雪會換內容）
    local o = Setup()
    o.Enter(1)
    o.Shift(true)
    o.env.worldData = { type = 2 }
    o.Event("WORLD_CURSOR_TOOLTIP_UPDATE", 1)
    check("換到別的東西：不藏", o.tip.shown)
    eq("換到別的東西：不淡出", o.tip.fades, nil)

    -- 內容已經被換掉：離開時不歸我們收
    local r = Setup()
    r.Enter(1)
    r.Shift(true)
    r.tip:WorldCursorContent()
    r.env.worldData = nil
    r.Event("WORLD_CURSOR_TOOLTIP_UPDATE", 1)
    eq("內容換過：不淡出", r.tip.fades, nil)
    check("內容換過：不藏", r.tip.shown)
end

------------------------------------------------------------
-- 4. 頭像框：照舊 SetUnit(unit)，不記叫回
------------------------------------------------------------
do
    local t = Setup()
    t.env.focus = H.Region("Frame", nil, "PartyFrame1")
    t.env.focus.unit = "party1"
    t.Shift(true)
    eq("頭像框：SetUnit(unit)", t.tip.setUnits[1], "party1")
    eq("頭像框：不記叫回", t.ns.Anchor.ReviveHealth(t.tip), nil)
end

------------------------------------------------------------
-- 5. 放開修飾鍵：藏掉、不再管；不在戰鬥：完全不動
------------------------------------------------------------
do
    local t = Setup()
    t.Enter(1)
    t.Shift(true)
    t.Shift(false)
    check("放開：藏掉", not t.tip.shown)
    eq("放開：不再管", t.ns.Anchor.ReviveHealth(t.tip), nil)
    eq("放開：沒有再 SetUnit", #t.tip.setUnits, 1)

    local o = Setup()
    o.env.combat = false
    o.Shift(true)
    eq("不在戰鬥：不叫回", #o.tip.setUnits, 0)
end

------------------------------------------------------------
-- 6. 世界游標的 Cursor 分支（2026-10-25 玩家回報：錨點設固定位置，滑過補給品還是跟著游標）：
--    暴雪直接 SetOwner(UIParent, "ANCHOR_CURSOR")、不經過 SetDefaultAnchor ⇒ SetWorldCursor 後掛勾照設定重新定位；
--    內容已經畫好 ⇒ 只換錨點型別與點，不再 SetOwner
------------------------------------------------------------
local function WorldSetup(position)
    local t = Setup()
    t.env.combat = false
    t.ns.db.anchor.position = position
    t.ns.db.anchor.hiddenInCombat = false
    return t
end

do
    local t = WorldSetup("static")
    local tip = t.tip
    tip:SetWorldCursor(2)
    check("固定位置：顯示中", tip.shown)
    eq("固定位置：錨點型別換成 ANCHOR_NONE（引擎不再拉回游標）", tip:GetAnchorType(), "ANCHOR_NONE")
    eq("固定位置：只有暴雪那一次 SetOwner", tip.ownerCalls, 1)
    check("固定位置：owner 不變", tip:GetOwner() == t.env.UIParent)
    local info = tip:GetPrimaryTooltipInfo()
    eq("固定位置：內容還在", info and info.getterName, "GetWorldCursor")
    eq("固定位置：只有一個點", tip:GetNumPoints(), 1)
    local p, rel, rp, x, y = tip:GetPoint(1)
    eq("固定位置：點", tostring(p) .. "|" .. tostring(rp), "BOTTOMRIGHT|BOTTOMRIGHT")
    check("固定位置：貼 UIParent", rel == t.env.UIParent)
    eq("固定位置：位移", tostring(x) .. "," .. tostring(y), "-30,30")
    -- 滑開：暴雪自己藏，我們不動
    t.env.worldData = nil
    local calls = tip.anchorTypeCalls
    tip:SetWorldCursor(2)
    check("滑開：藏掉", not tip.shown)
    eq("滑開：不再換錨點", tip.anchorTypeCalls, calls)
end

do  -- 地上的戰利品物件（ANCHOR_CURSOR_RIGHT）一樣搬
    local t = WorldSetup("static")
    t.env.worldData = { type = 2, worldLootObjectInventoryType = 1 }
    t.tip:SetWorldCursor(2)
    eq("戰利品物件：搬到固定位置", t.tip:GetAnchorType(), "ANCHOR_NONE")
end

do  -- 跟隨游標（預設右上）：照設定換成 ANCHOR_CURSOR_RIGHT 36,-12，不 SetOwner
    local t = WorldSetup("cursor")
    t.tip:SetWorldCursor(2)
    eq("跟隨游標：照設定的方向", t.tip:GetAnchorType(), "ANCHOR_CURSOR_RIGHT")
    eq("跟隨游標：位移", tostring(t.tip.anchorX) .. "," .. tostring(t.tip.anchorY), "36,-12")
    eq("跟隨游標：只有暴雪那一次 SetOwner", t.tip.ownerCalls, 1)
    -- 之後一般的 SetDefaultAnchor 照舊 SetOwner（旗標有收回）
    t.defaultAnchorHooks.GameTooltip_SetDefaultAnchor(t.tip, t.env.UIParent)
    eq("旗標收回：SetDefaultAnchor 照舊 SetOwner", t.tip.ownerCalls, 2)
end

do  -- 暴雪預設：不動（游標旁就是暴雪對物件的預設）
    local t = WorldSetup("default")
    t.tip:SetWorldCursor(2)
    eq("暴雪預設：照暴雪的游標錨點", t.tip:GetAnchorType(), "ANCHOR_CURSOR")
    eq("暴雪預設：沒換錨點型別", t.tip.anchorTypeCalls, nil)
end

do  -- Default 分支：SetDefaultAnchor 掛勾已經搬好，後掛勾不重做
    local t = WorldSetup("static")
    t.tip:SetWorldCursor(1)
    eq("Default 分支：後掛勾不碰", t.tip.anchorTypeCalls, nil)
    local p, _, _, x, y = t.tip:GetPoint(1)
    eq("Default 分支：照固定位置", tostring(p) .. "|" .. tostring(x) .. "," .. tostring(y), "BOTTOMRIGHT|-30,30")
end

H.finish("Anchor_test")
