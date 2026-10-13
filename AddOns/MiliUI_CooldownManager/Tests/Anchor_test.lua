------------------------------------------------------------
-- Core/Anchor.lua（錨到單位框與具名框，H4）＋ Bars 的外部錨定的離線測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Anchor_test.lua
--
-- 覆蓋：存檔字串的形狀（Parse／IsExternal）、提供者順序（六個單位 × 五家）、Provider、快取與作廢、自己的條容器名被擋、
-- CheckName 的四種原因、forbidden／字型物件不算框、Fallback 路徑、Recheck 的變動偵測；
-- DB.AnchorWouldCycle 對外部目標；Bars：外部目標當堆疊根（同一個目標同一邊照 STACK_RANK 往外排）、
-- 解析不到時照 fallback（沒有就 pos）貼 UIParent、SetPoint 被擋時退回 fallback、不做半像素補正、
-- 秘密尺寸不讓半像素補正炸掉。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

local SECRET = setmetatable({}, {
    __tostring = function() return "<secret>" end,
    __eq = function() error("compared a secret") end,
    __lt = function() error("compared a secret") end,
    __le = function() error("compared a secret") end,
    __add = function() error("arithmetic on a secret") end,
    __sub = function() error("arithmetic on a secret") end,
    __mul = function() error("arithmetic on a secret") end,
    __div = function() error("arithmetic on a secret") end,
})
local function IsSecret(v) return rawequal(v, SECRET) end

local Methods = {}
function Methods:SetPoint(p, rel, rp, x, y)
    if type(rel) == "table" and rawget(rel, "refuse") then error("Cannot anchor to a region dependent on it") end
    self.points[#self.points + 1] = { p, rel, rp, x, y }
end
function Methods:ClearAllPoints() self.points = {} end
function Methods:SetSize(w, h) self.w, self.h = w, h end
function Methods:GetSize() return self.w, self.h end
function Methods:Show() self.shown = true end
function Methods:Hide() self.shown = false end
function Methods:IsShown() return self.shown end
function Methods:GetFrameLevel() return 1 end
function Methods:GetObjectType() return "Frame" end
function Methods:GetPoint() return nil end
local function Frame(name)
    local f = { points = {}, w = 1, h = 1, shown = true, name = name }
    return setmetatable(f, { __index = function(_, k) return Methods[k] or function() end end })
end
-- 外部框：只有 GetObjectType／GetPoint（讀它的尺寸就炸 ⇒ 證明沒讀）
local function ExtFrame(name, opts)
    opts = opts or {}
    local f = { name = name, refuse = opts.refuse }
    f.GetObjectType = function() return opts.type or "Button" end
    f.GetPoint = function() return nil end
    if opts.forbidden ~= nil then f.IsForbidden = function() return opts.forbidden end end
    f.GetSize = function() error("read external geometry") end
    f.GetWidth = f.GetSize
    f.GetHeight = f.GetSize
    f.IsShown = function() error("read external visibility") end
    return f
end

local env = setmetatable({}, { __index = _G })
env._G = env
env.GetLocale = function() return "zhTW" end
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.InCombatLockdown = function() return false end
env.CreateFrame = function(_, name) return Frame(name) end
env.UIParent = Frame("UIParent")
env.Enum = { CompressionMethod = { Deflate = 1 } }
env.C_Timer = { After = function() end }
local now = 0
env.GetTime = function() now = now + 1; return now end

local registered = {}
local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = IsSecret,
    RegisterCallback = function() end,
    Fire = function() end,
    Events = { Register = function(ev, key) registered[ev .. ":" .. key] = true end, Unregister = function() end },
    Defer = function(fn, ...) fn(...) end,
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
    Write = function(frame, fn) fn(frame) return true end,
    Style = { ApplyPanel = function() end },
    P = { Scale = function(v) return v end },
}

local function Load(rel)
    local path = here .. "/../" .. rel
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end

Load("Core/DB.lua")
Load("Core/Layout.lua")
Load("Core/Anchor.lua")
local A, DB = ns.Anchor, ns.DB
-- 假的全域表
local G = {}
A.G = G

------------------------------------------------------------
-- 1. 存檔字串
------------------------------------------------------------
check("事件：ADDON_LOADED 有註冊", registered["ADDON_LOADED:anchor_ext"])
check("事件：PLAYER_ENTERING_WORLD 有註冊", registered["PLAYER_ENTERING_WORLD:anchor_ext"])
check("unit:player 是外部", A.IsExternal("unit:player"))
check("frame:Foo 是外部", A.IsExternal("frame:Foo"))
check("frame:（空名）也是外部", A.IsExternal("frame:"))
check("條的 key 不是外部", not A.IsExternal("essential"))
check("g1 不是外部", not A.IsExternal("g1"))
check("nil 不是外部", not A.IsExternal(nil))
do
    local k, u = A.Parse("unit:target")
    check("Parse unit:target", k == "unit" and u == "target")
    k, u = A.Parse("unit:pet")
    check("Parse unit:pet", k == "unit" and u == "pet")
    k, u = A.Parse("unit:targettarget")
    check("Parse unit:targettarget", k == "unit" and u == "targettarget")
    k, u = A.Parse("unit:focustarget")
    check("Parse unit:focustarget", k == "unit" and u == "focustarget")
    k = A.Parse("unit:boss1")
    eq("Parse 不認得的單位 ＝ nil", k, nil)
    local _, n = A.Parse("frame:  Foo  ")
    eq("Parse frame 名字去頭尾空白", n, "Foo")
    _, n = A.Parse("frame:")
    eq("Parse frame 空名", n, "")
end
eq("提供者：玩家第一個是本套組", A.UNIT_PROVIDERS.player[1], "MiliUIUF_Player")
eq("提供者：玩家第二個", A.UNIT_PROVIDERS.player[2], "EllesmereUIUnitFrames_Player")
eq("提供者：玩家第三個", A.UNIT_PROVIDERS.player[3], "ElvUF_Player")
eq("提供者：玩家第四個是 MSUF", A.UNIT_PROVIDERS.player[4], "MSUF_player")
eq("提供者：玩家最後是暴雪", A.UNIT_PROVIDERS.player[5], "PlayerFrame")
eq("提供者：專注目標最後是暴雪", A.UNIT_PROVIDERS.focus[5], "FocusFrame")
eq("下拉：六個單位", #A.UNITS, 6)
do
    local want = { "player", "target", "focus", "pet", "targettarget", "focustarget" }
    for i, u in ipairs(want) do eq("下拉順序 " .. i, A.UNITS[i], u) end
    -- 六個單位 × 五家：Candidates 照「本套組 → EllesmereUI → ElvUI → MSUF → 暴雪」的順序
    local expect = {
        player       = { "MiliUIUF_Player", "EllesmereUIUnitFrames_Player", "ElvUF_Player", "MSUF_player", "PlayerFrame" },
        target       = { "MiliUIUF_Target", "EllesmereUIUnitFrames_Target", "ElvUF_Target", "MSUF_target", "TargetFrame" },
        focus        = { "MiliUIUF_Focus", "EllesmereUIUnitFrames_Focus", "ElvUF_Focus", "MSUF_focus", "FocusFrame" },
        pet          = { "MiliUIUF_Pet", "EllesmereUIUnitFrames_Pet", "ElvUF_Pet", "MSUF_pet", "PetFrame" },
        targettarget = { "MiliUIUF_TargetTarget", "EllesmereUIUnitFrames_TargetTarget", "ElvUF_TargetTarget", "MSUF_targettarget", "TargetFrameToT" },
        focustarget  = { "MiliUIUF_FocusTarget", "EllesmereUIUnitFrames_FocusTarget", "ElvUF_FocusTarget", "MSUF_focustarget", "FocusFrameToT" },
    }
    for u, names in pairs(expect) do
        local c = A.Candidates("unit:" .. u)
        eq("Candidates " .. u .. " 筆數", #c, 5)
        for i, n in ipairs(names) do eq("Candidates " .. u .. " #" .. i, c[i], n) end
        local fams = { "MiliUI", "EllesmereUI", "ElvUI", "MSUF", "Blizzard" }
        for i, n in ipairs(names) do eq("FRAME_PROVIDER " .. n, A.FRAME_PROVIDER[n], fams[i]) end
    end
end

------------------------------------------------------------
-- 2. 解析順序、快取、作廢
------------------------------------------------------------
do
    G.PlayerFrame = ExtFrame("PlayerFrame")
    local f, name = A.Resolve("unit:player")
    check("只有暴雪的：解析到 PlayerFrame", f == G.PlayerFrame and name == "PlayerFrame")
    G.MiliUIUF_Player = ExtFrame("MiliUIUF_Player")
    f = A.Resolve("unit:player")
    check("快取：作廢前仍是 PlayerFrame", f == G.PlayerFrame)
    A.Invalidate()
    f, name = A.Resolve("unit:player")
    check("作廢後：本套組優先", f == G.MiliUIUF_Player and name == "MiliUIUF_Player")
    G.ElvUF_Player = ExtFrame("ElvUF_Player")
    A.Invalidate()
    f = A.Resolve("unit:player")
    check("三家都在：本套組優先", f == G.MiliUIUF_Player)
    G.MiliUIUF_Player = nil
    A.Invalidate()
    f = A.Resolve("unit:player")
    check("本套組關掉：第二家", f == G.ElvUF_Player)
    eq("沒有目標框的提供者：解析不到", (A.Resolve("unit:target")), nil)
    G.TargetFrame = ExtFrame("TargetFrame")
    eq("解析不到也有快取（作廢前）", (A.Resolve("unit:target")), nil)
    A.Invalidate()
    check("作廢後找得到 TargetFrame", A.Resolve("unit:target") == G.TargetFrame)
    -- 不是框
    G.GameFontNormal = { GetObjectType = function() return "Font" end }
    eq("字型物件（沒有 GetPoint）不算框", (A.Resolve("frame:GameFontNormal")), nil)
    G.SomeTable = { a = 1 }
    eq("一般表不算框", (A.Resolve("frame:SomeTable")), nil)
    G.Forbidden = ExtFrame("Forbidden", { forbidden = true })
    eq("forbidden 不算", (A.Resolve("frame:Forbidden")), nil)
    G.SecretType = ExtFrame("SecretType")
    G.SecretType.GetObjectType = function() return SECRET end
    eq("GetObjectType 回秘密值不算", (A.Resolve("frame:SecretType")), nil)
    G.MiliUICDM_Bar_essential = ExtFrame("MiliUICDM_Bar_essential")
    eq("自己的條容器不收", (A.Resolve("frame:MiliUICDM_Bar_essential")), nil)
    eq("空名解析不到", (A.Resolve("frame:")), nil)
    G.WeakFrame = ExtFrame("WeakFrame")
    check("一般具名框", A.Resolve("frame:WeakFrame") == G.WeakFrame)

    -- Provider：解析到的框是哪一家
    eq("Provider：玩家（本套組關掉、第三家在）", A.Provider("unit:player"), "ElvUI")
    eq("Provider：目標＝暴雪", A.Provider("unit:target"), "Blizzard")
    eq("Provider：解析不到 ＝ nil", A.Provider("unit:pet"), nil)
    eq("Provider：不認得的具名框 ＝ nil", A.Provider("frame:WeakFrame"), nil)
    G.EllesmereUIUnitFrames_Pet = ExtFrame("EllesmereUIUnitFrames_Pet")
    G.PetFrame = ExtFrame("PetFrame")
    A.Invalidate()
    eq("Provider：寵物＝第二家（暴雪也在，排後面）", A.Provider("unit:pet"), "EllesmereUI")
    G.MiliUIUF_Pet = ExtFrame("MiliUIUF_Pet")
    A.Invalidate()
    eq("Provider：寵物＝本套組", A.Provider("unit:pet"), "MiliUI")
    G.TargetFrameToT = ExtFrame("TargetFrameToT")
    G.FocusFrameToT = ExtFrame("FocusFrameToT")
    A.Invalidate()
    local f, n = A.Resolve("unit:targettarget")
    check("目標的目標：只有暴雪的 TargetFrameToT", f == G.TargetFrameToT and n == "TargetFrameToT")
    f, n = A.Resolve("unit:focustarget")
    check("專注目標的目標：只有暴雪的 FocusFrameToT", f == G.FocusFrameToT and n == "FocusFrameToT")
    G.MiliUIUF_Pet, G.EllesmereUIUnitFrames_Pet = nil, nil
    G.MSUF_pet = ExtFrame("MSUF_pet")
    A.Invalidate()
    eq("Provider：寵物＝MSUF（暴雪也在，排後面）", A.Provider("unit:pet"), "MSUF")
    G.MSUF_pet = nil
    A.Invalidate()
end

------------------------------------------------------------
-- 3. CheckName（設定頁輸入框）
------------------------------------------------------------
do
    local ok, why = A.CheckName("")
    check("空字串：empty", not ok and why == "empty")
    ok, why = A.CheckName("   ")
    check("空白：empty", not ok and why == "empty")
    ok, why = A.CheckName("MiliUICDM_Bar_g1")
    check("自己的條：own（就算 _G 沒有也擋）", not ok and why == "own")
    ok, why = A.CheckName("NoSuchFrame")
    check("不存在：missing", not ok and why == "missing")
    ok, why = A.CheckName("GameFontNormal")
    check("字型物件：notframe", not ok and why == "notframe")
    ok = A.CheckName(" WeakFrame ")
    check("前後空白可以", ok)
end

------------------------------------------------------------
-- 4. Fallback／Unresolved／Label
------------------------------------------------------------
do
    local p, x, y = A.Fallback({ anchor = { to = "unit:player", fallback = { point = "BOTTOM", x = 3, y = 40 } },
                                 pos = { point = "CENTER", x = 9, y = 9 } })
    check("fallback 優先", p == "BOTTOM" and x == 3 and y == 40)
    p, x, y = A.Fallback({ anchor = { to = "unit:player" }, pos = { point = "TOP", x = 1, y = -2 } })
    check("沒有 fallback 用 pos", p == "TOP" and x == 1 and y == -2)
    p, x, y = A.Fallback({ anchor = { to = "unit:player" } })
    check("都沒有：CENTER 0,0", p == "CENTER" and x == 0 and y == 0)
    check("Unresolved：解析不到的外部", A.Unresolved({ anchor = { to = "frame:NoSuchFrame" } }))
    check("Unresolved：解析得到", not A.Unresolved({ anchor = { to = "frame:WeakFrame" } }))
    check("Unresolved：條的 key 不算", not A.Unresolved({ anchor = { to = "essential" } }))
    check("Unresolved：沒有錨定", not A.Unresolved({ anchor = false }))
    eq("Label：玩家", A.Label("unit:player"), "Player frame")
    eq("Label：專注目標", A.Label("unit:focus"), "Focus frame")
    eq("Label：寵物", A.Label("unit:pet"), "Pet frame")
    eq("Label：目標的目標", A.Label("unit:targettarget"), "Target of target frame")
    eq("Label：專注目標的目標", A.Label("unit:focustarget"), "Focus target frame")
    for _, u in ipairs(A.UNITS) do check("Label 不是 nil：" .. u, A.Label("unit:" .. u) ~= nil) end
    eq("Label：框名", A.Label("frame:WeakFrame"), "WeakFrame")
    eq("Label：空名", A.Label("frame:"), "Frame by name")
end

------------------------------------------------------------
-- 5. DB：環檢查不管外部
------------------------------------------------------------
ns.profile = DB.BuildDefaults().profile
local p = ns.profile
check("AnchorWouldCycle：外部目標不成環", not DB.AnchorWouldCycle("essential", "unit:player"))
check("AnchorWouldCycle：條照舊檢查", DB.AnchorWouldCycle("essential", "essential"))

------------------------------------------------------------
-- 6. Recheck：結果有變才回 true
------------------------------------------------------------
do
    p.castbar.anchor = { to = "unit:target", point = "TOP", relPoint = "BOTTOM", x = 0, y = -2 }
    A.Recheck()                                -- 先記一次
    check("沒變：false", not A.Recheck())
    local keep = G.TargetFrame
    G.TargetFrame = nil
    check("目標框不見了：true", A.Recheck())
    G.TargetFrame = keep
    check("回來了：true", A.Recheck())
    p.castbar.anchor = false
end

------------------------------------------------------------
-- 7. Bars：外部目標當堆疊根、fallback、SetPoint 被擋
------------------------------------------------------------
do
    ns.Layout.Snap = ns.Layout.Snap or function(v) return v end
    Load("Core/Bars.lua")
    local B = ns.Bars
    B.RegisterPanel("resources", { anchorPoint = "BOTTOM" })
    B.RegisterPanel("castbar", { anchorPoint = "CENTER" })
    -- 自訂列（預設錨在資源條上方）：沒有任何一列時收合、不佔位（遊戲裡就是這樣），這一節不測它
    B.RegisterPanel("custombars", { anchorPoint = "BOTTOM", collapsible = true })
    B.SetPanelSize("custombars", 100, 0)
    local res, cast = B.Get("resources"), B.Get("castbar")
    local function Pt(f) return f.points[#f.points] or {} end
    -- 貼 UIParent 時照舊有半像素補正（最多半個像素）
    local function near(v, want) return type(v) == "number" and math.abs(v - want) <= 0.5 end
    A.Invalidate()
    local tf = G.TargetFrame

    -- 兩個面板都錨在目標框架下方：資源條（rank 1）貼框，施法條（rank 4）貼在資源條外面
    p.resources.anchor = { to = "unit:target", point = "TOP", relPoint = "BOTTOM", x = 0, y = -2 }
    p.castbar.anchor = { to = "unit:target", point = "TOP", relPoint = "BOTTOM", x = 0, y = -2 }
    eq("排開：資源條直接貼外部框", B.StackTarget("resources"), "unit:target")
    eq("排開：施法條貼資源條外面", B.StackTarget("castbar"), "resources")
    B.ApplyStructure("resources")
    B.ApplyStructure("castbar")
    local pt = Pt(res)
    check("資源條：錨在 TargetFrame、偏移照設定（沒有半像素補正、沒讀外部尺寸）",
        pt[1] == "TOP" and pt[2] == tf and pt[3] == "BOTTOM" and pt[4] == 0 and pt[5] == -2)
    pt = Pt(cast)
    check("施法條：錨在資源條", pt[2] == res and pt[1] == "TOP")
    -- 不同邊：施法條在目標框上方 ⇒ 自己一疊
    p.castbar.anchor = { to = "unit:target", point = "BOTTOM", relPoint = "TOP", x = 0, y = 2 }
    eq("不同邊：施法條直接貼外部框", B.StackTarget("castbar"), "unit:target")
    -- 不同外部目標：各自一疊
    p.castbar.anchor = { to = "unit:player", point = "TOP", relPoint = "BOTTOM", x = 0, y = -2 }
    eq("不同外部目標：直接貼自己的目標", B.StackTarget("castbar"), "unit:player")

    -- 解析不到：fallback（沒有就 pos）貼 UIParent，也不參與排開
    p.resources.anchor = { to = "frame:NoSuchFrame", point = "TOP", relPoint = "BOTTOM", x = 0, y = -2,
                           fallback = { point = "CENTER", x = 11, y = -120 } }
    eq("解析不到：沒有排開目標", B.StackTarget("resources"), nil)
    B.ApplyStructure("resources")
    pt = Pt(res)
    check("解析不到：照 fallback 貼 UIParent", pt[2] == env.UIParent and pt[3] == "CENTER" and near(pt[4], 11) and near(pt[5], -120),
        table.concat({ tostring(pt[1]), tostring(pt[3]), tostring(pt[4]), tostring(pt[5]) }, " "))
    p.resources.anchor.fallback = nil
    p.resources.pos = { point = "BOTTOM", x = 5, y = 200 }
    B.ApplyStructure("resources")
    pt = Pt(res)
    check("沒有 fallback：照 pos", pt[2] == env.UIParent and pt[3] == "BOTTOM" and near(pt[4], 5) and near(pt[5], 200))

    -- SetPoint 被擋（那個框錨在我們身上）：退回 fallback、記下失敗
    G.Loop = ExtFrame("Loop", { refuse = true })
    A.Invalidate()
    p.resources.anchor = { to = "frame:Loop", point = "TOP", relPoint = "BOTTOM", x = 0, y = 0,
                           fallback = { point = "CENTER", x = 1, y = 2 } }
    B.ApplyStructure("resources")
    pt = Pt(res)
    check("SetPoint 被擋：退回 fallback", pt[2] == env.UIParent and near(pt[4], 1) and near(pt[5], 2))
    eq("SetPoint 被擋：AnchorFailed", B.AnchorFailed("resources"), "frame:Loop")
    p.resources.anchor = { to = "unit:target", point = "TOP", relPoint = "BOTTOM", x = 0, y = 0 }
    B.ApplyStructure("resources")
    eq("改回能錨的：AnchorFailed 清掉", B.AnchorFailed("resources"), nil)
    -- 尺寸變了的半像素重貼：外部錨定跳過（不讀外部框）
    res:SetSize(33, 7)
    B.PixelRefix("resources")
    check("PixelRefix 不讀外部框", Pt(res)[2] == tf)

    -- 秘密尺寸：半像素補正回 0 不炸
    local f1 = Frame("f1"); f1.w, f1.h = SECRET, SECRET
    local dx, dy = B.HalfPixelFix(f1, "TOP", Frame("r"), "BOTTOM")
    check("HalfPixelFix：秘密尺寸回 0,0", dx == 0 and dy == 0)

    p.resources.anchor = false
    p.castbar.anchor = false
end

------------------------------------------------------------
-- 8. 閒置的面板（資源列獨立擺放 "res:<key>"）：Bars.Dormant 的通用判斷
------------------------------------------------------------
do
    local B = ns.Bars
    local det = { on = true, anchor = { to = "resources", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 },
                  pos = { point = "CENTER", x = 0, y = -150 } }
    p.resources.detached = { Mana = det }
    p.castbar.anchor = { to = "resources", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 }
    local live = true
    B.RegisterPanel("res:Mana", { anchorPoint = "CENTER", rank = 1.1, idle = function() return not live end })
    local c = B.Get("res:Mana")
    check("拆出列：容器建好（名字照 MiliUICDM_Bar_<key>）", c ~= nil and c.name == "MiliUICDM_Bar_res:Mana")
    check("拆出列：不是靜態面板，但 Bars 認得", B.IsPanel("res:Mana") and not DB.IsPanel("res:Mana"))
    check("拆出列（現役）：不閒置", not B.PanelIdle("res:Mana") and not B.Dormant("res:Mana"))
    eq("拆出列（現役）：貼資源條", B.StackTarget("res:Mana"), "resources")
    eq("拆出列（現役）：施法條排在它外面（rank 1.1 < 4）", B.StackTarget("castbar"), "res:Mana")
    B.ApplyStructure("res:Mana")
    check("拆出列（現役）：容器顯示", c.shown == true)
    local pt = c.points[#c.points] or {}
    check("拆出列（現役）：錨在資源條容器上", pt[1] == "BOTTOM" and pt[2] == B.Get("resources") and pt[3] == "TOP")

    -- 閒置：當它不存在（AnchorCfg nil、不進排開、容器收起來）
    live = false
    check("閒置：PanelIdle／Dormant", B.PanelIdle("res:Mana") and B.Dormant("res:Mana"))
    eq("閒置：自己沒有排開目標", B.StackTarget("res:Mana"), nil)
    eq("閒置：施法條改貼資源條", B.StackTarget("castbar"), "resources")
    B.ApplyPanelStructure("res:Mana")
    check("閒置：容器收起來", c.shown == false)
    -- 開關關著也一樣（設定表還在、值留著）：閒置由模組的 idle 決定，Bars 不讀 on
    check("閒置：設定表留著", DB.ConfigTable("res:Mana") == det)

    -- 回到現役
    live = true
    B.ApplyPanelStructure("res:Mana")
    check("回到現役：容器顯示", c.shown == true)
    eq("回到現役：施法條又排到它外面", B.StackTarget("castbar"), "res:Mana")
    -- 天空騎術接力以外的面板：Dormant 不誤判
    check("Dormant：資源條不是", not B.Dormant("resources"))
    check("Dormant：沒登記的 key 不是", not B.Dormant("nope"))

    live = false
    B.ApplyPanelStructure("res:Mana")
    p.castbar.anchor = false
    p.resources.detached = {}
end

print(("Anchor_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
