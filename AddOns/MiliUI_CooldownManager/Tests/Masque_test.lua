------------------------------------------------------------
-- Core/Masque.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Masque_test.lua
--
-- 做法：DB.lua 與 Masque.lua 載進同一張**自己的環境表**（ns.Setting 用真的三層繼承），
-- Masque 本身用假的 LibStub 函式庫代替：Group／AddButton／ReSkin／RemoveButton 只記帳。
-- ns.Write 用跟 Core/Init.lua 同語意的小替身（戰鬥中＋保護框 → 記帳，脫戰補做）。
--
-- 覆蓋：預設值、icon.skin 的繼承（跟 follow.icon）、沒裝 Masque 退回米利、登入快照與重載判斷、
-- 之後才建的條用主題的快照、型別、交格子（完整 regions＋Strict、同尺寸不重套、尺寸變了 ReSkin、
-- 換框先 Remove、秘密幾何不交、戰鬥中保護框延到脫戰並叫 onLate）、群組停用、開 Masque 設定；
-- 皮的形狀（ShapeOf 的快取與 Generation、秘密值、只讀原始欄位）、公開 API 的兩支貼圖查詢，
-- 以及 Core/Glow.lua 的發光跟著形狀：沒裝 Masque、米利模式、方形皮、圓形／六角形皮 × 四種樣式、換皮重讀、API 讀不到退方形。
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

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

------------------------------------------------------------
-- 假的 Masque
------------------------------------------------------------
local calls = {}
local function Log(...) calls[#calls + 1] = { ... } end
local function Reset() calls = {} end

local fakeGroup = { db = { Disabled = false } }
function fakeGroup:AddButton(button, regions, btype, strict) Log("add", button, regions, btype, strict) end
function fakeGroup:ReSkin(button) Log("reskin", button) end
function fakeGroup:RemoveButton(button) Log("remove", button) end
function fakeGroup:RegisterCallback(fn) self.cb = fn end

local masqueLib = {}
local groupNames = {}
function masqueLib:Group(name)
    groupNames[#groupNames + 1] = name
    return fakeGroup
end

local masqueInstalled = false
local LibStubFake = setmetatable({}, { __call = function(self, ...) return self:GetLibrary(...) end })
function LibStubFake:GetLibrary(name)
    if name == "Masque" and masqueInstalled then return masqueLib end
    return nil
end

------------------------------------------------------------
-- 環境
------------------------------------------------------------
local state = { combat = false }
local env = setmetatable({}, { __index = _G })
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.InCombatLockdown = function() return state.combat end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.CreateFrame = function()
    local f = {}
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript() end
    return f
end
env.LibStub = LibStubFake
local slashArgs
env.SlashCmdList = { MASQUE = function(arg) slashArgs = arg end }

local printed = {}
local closed = 0
local writeQueue = {}
local ns = {
    playerClass = "PALADIN",
    Events = { Register = function() end },
    Fire = function() end,
    ReportError = function(err) print("ReportError: " .. tostring(err)) end,
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = function(v) return rawequal(v, SECRET) end,
    Guard = function(fn) return fn end,
    Print = function(msg) printed[#printed + 1] = msg end,
    Viewers = { AURA_KIND = { buffs = true, buffbars = true } },
    Options = { Close = function() closed = closed + 1 end },
}
function ns.RefreshSpec() ns.specIndex = 1; ns.specID = 61 end
-- 同 Core/Init.lua 的語意：戰鬥中而且框是保護的才記帳
function ns.Write(frame, fn)
    if not (state.combat and frame.protected) then fn(frame) return true end
    writeQueue[#writeQueue + 1] = { frame = frame, fn = fn }
    return false
end
local function Regen()
    state.combat = false
    local list = writeQueue
    writeQueue = {}
    for _, job in ipairs(list) do job.fn(job.frame) end
end

local function Load(path)
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

local function Frame(w)
    local f = { w = w or 36 }
    function f:GetWidth() return self.w end
    return f
end

------------------------------------------------------------
-- 發光（Core/Glow.lua）用的假 MiliUIGlow：Start 系列照實建框（池化的閃光框會輪用），記帳
------------------------------------------------------------
local glowLog = {}
local function GLog(...) glowLog[#glowLog + 1] = { ... } end
local BTN_GLOW = [[Interface\SpellActivationOverlay\IconAlert]]
local BTN_ANTS = [[Interface\SpellActivationOverlay\IconAlertAnts]]
local function Tex(tex)
    local t = { tex = tex, sets = 0 }
    function t:SetTexture(v) self.tex, self.atlas, self.sets = v, nil, self.sets + 1 end
    function t:SetAtlas(v) self.atlas, self.tex = v, nil end
    return t
end
local function FlipBook()
    local fb = {}
    for _, k in ipairs({ "SetFlipBookFrameWidth", "SetFlipBookFrameHeight", "SetFlipBookRows", "SetFlipBookColumns", "SetFlipBookFrames" }) do
        fb[k] = function(self, v) self[k:sub(4)] = v end
    end
    return fb
end
local function AnimGroup(fb)
    local a = { flipbookRepeat = fb, playing = true, plays = 0 }
    function a:IsPlaying() return self.playing end
    function a:Stop() self.playing = false end
    function a:Play() self.playing, self.plays = true, self.plays + 1 end
    return a
end
local btnPool = {}
local fakeLCG = {}
function fakeLCG.PixelGlow_Start(h, color, _, _, _, _, _, _, _, key) GLog("pixel+", h, key, color) end
function fakeLCG.PixelGlow_Stop(h, key) GLog("pixel-", h, key) end
function fakeLCG.AutoCastGlow_Start(h, color, _, _, _, _, _, key) GLog("autocast+", h, key, color) end
function fakeLCG.AutoCastGlow_Stop(h, key) GLog("autocast-", h, key) end
function fakeLCG.ButtonGlow_Start(h, color)
    if not h._ButtonGlow then
        local f = table.remove(btnPool)
        if not f then
            f = { ants = Tex(BTN_ANTS) }
            for _, k in ipairs({ "spark", "innerGlow", "innerGlowOver", "outerGlow", "outerGlowOver" }) do f[k] = Tex(BTN_GLOW) end
        end
        h._ButtonGlow = f
    end
    GLog("button+", h, nil, color)
end
function fakeLCG.ButtonGlow_Stop(h)
    if h._ButtonGlow then btnPool[#btnPool + 1] = h._ButtonGlow; h._ButtonGlow = nil end
    GLog("button-", h)
end
function fakeLCG.ProcGlow_Start(h, o)
    local k = "_ProcGlow" .. o.key
    local f = h[k]
    if not f then
        f = { ProcLoop = Tex(nil), ProcLoopAnim = AnimGroup(FlipBook()) }
        f.ProcLoop:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
        h[k] = f
    end
    GLog("proc+", h, o.key, o.color, o.startAnim)
end
function fakeLCG.ProcGlow_Stop(h, key) h["_ProcGlow" .. key] = nil; GLog("proc-", h, key) end

local function LastGlow() return glowLog[#glowLog] or {} end
local function GlowRec(barKey, button)
    return { overlay = {}, glowHosts = { proc = {}, ready = {}, active = {}, assist = {} }, glowW = 36, glowH = 36,
             claimKey = barKey, msqSkinned = button ~= nil, msqButton = button }
end

------------------------------------------------------------
-- 1. 沒裝 Masque
------------------------------------------------------------
Load(here .. "/../Core/DB.lua")
ns.RefreshSpec()
ns.DB.Init()
local P = ns.profile
local S = ns.Setting

eq("預設 icon.skin", S("theme", "icon.skin"), "miliui")
eq("條跟隨主題", S("essential", "icon.skin"), "miliui")

do
    -- 沒裝：Masque.lua 自己的狀態（快照、群組）用一份獨立載入的，免得汙染後面裝了的那一段
    Load(here .. "/../Core/Masque.lua")
    local M = ns.Masque
    eq("沒裝 Available", M.Available(), false)
    P.theme.icon.skin = "masque"
    eq("沒裝時設定成 Masque 也退回米利", M.Desired("theme"), "miliui")
    eq("沒裝時條也退回", M.Desired("essential"), "miliui")
    eq("沒裝時 Mode", M.Mode("essential"), "miliui")
    eq("沒裝時不需要重載", M.NeedsReload(), false)
    eq("沒裝時交不出去", M.Sync({}, Frame(), {}, "Action", 36, 36), false)
    eq("沒裝時沒有群組", #groupNames, 0)
    M.OpenOptions()
    eq("沒裝時不開設定", slashArgs, nil)
    eq("沒裝時 ShapeOf ⇒ nil", M.ShapeOf({ _MSQ_CFG = { Shape = "Circle" } }), nil)
    eq("沒裝時 SpellAlertLoop ⇒ nil", M.SpellAlertLoop("Circle"), nil)
    eq("沒裝時 SpellAlertOverlay ⇒ nil", M.SpellAlertOverlay("Circle"), nil)

    -- 發光：沒裝 Masque 的路徑跟以前一樣（不問形狀、觸發用暴雪圖集＋入場動畫、閃光的貼圖一張都不換）
    ns.MiliUIGlow = fakeLCG
    Load(here .. "/../Core/Glow.lua")
    local G = ns.Glow
    local asks = 0
    local realShapeOf = M.ShapeOf
    M.ShapeOf = function(...) asks = asks + 1; return realShapeOf(...) end
    local r = GlowRec("essential", nil)
    G.Start(r, "proc", "essential", { type = "pixel" })
    eq("沒裝：像素照畫像素", LastGlow()[1], "pixel+")
    G.Start(r, "ready", "essential", { type = "autocast" })
    eq("沒裝：自動施法照畫", LastGlow()[1], "autocast+")
    G.Start(r, "active", "essential", { type = "button" })
    eq("沒裝：閃光照畫", LastGlow()[1], "button+")
    local bf = r.glowHosts.active._ButtonGlow
    check("沒裝：閃光的貼圖沒換過", bf and bf.spark.sets == 0 and bf.ants.sets == 0 and bf.spark.tex == BTN_GLOW)
    G.Start(r, "assist", nil, { type = "proc" })
    eq("沒裝：觸發照畫", LastGlow()[1], "proc+")
    eq("沒裝：assist 的觸發不播入場動畫（同以前）", LastGlow()[5], false)
    G.Stop(r, "proc")
    G.Start(r, "proc", "essential", { type = "proc" })
    eq("沒裝：proc 那格有入場動畫", LastGlow()[5], true)
    eq("沒裝：暴雪圖集", r.glowHosts.proc._ProcGlowproc.ProcLoop.atlas, "UI-HUD-ActionBar-Proc-Loop-Flipbook")
    eq("沒裝：格子尺寸 0（圖集）", r.glowHosts.proc._ProcGlowproc.ProcLoopAnim.flipbookRepeat.FlipBookFrameWidth, 0)
    eq("沒裝：記下的樣式", r.glowOn.proc, "proc")
    r.msqSkinned = false
    G.Start(r, "proc", "essential", { type = "button" })
    eq("沒裝：一次都沒問形狀", asks, 0)
    M.ShapeOf = realShapeOf
    for k in pairs(r.glowOn) do G.Stop(r, k) end
    P.theme.icon.skin = "miliui"
end

------------------------------------------------------------
-- 2. 裝了 Masque：繼承與快照
------------------------------------------------------------
masqueInstalled = true
Load(here .. "/../Core/Masque.lua")         -- 重新載入 ＝ 新的工作階段（快照、群組都是空的）
local M = ns.Masque
eq("裝了 Available", M.Available(), true)
eq("預設 Desired", M.Desired("essential"), "miliui")

-- 第一次問 Mode 的當下快照：主題 Masque、輔助自己不跟隨並設回米利
P.theme.icon.skin = "masque"
P.bars.utility.follow.icon = false
P.bars.utility.icon.skin = "miliui"
eq("跟隨的條讀主題", M.Desired("essential"), "masque")
eq("不跟隨且自己有值 → 讀自己", M.Desired("utility"), "miliui")
P.bars.buffs.follow.icon = false
eq("不跟隨但自己沒存 → 退回主題", M.Desired("buffs"), "masque")
P.bars.buffs.icon.skin = "bogus"
eq("認不得的值當米利", M.Desired("buffs"), "miliui")
P.bars.buffs.icon.skin = nil
P.bars.buffs.follow.icon = true

eq("Mode 快照 主題", M.Mode("theme"), "masque")
eq("Mode 快照 核心", M.Mode("essential"), "masque")
eq("Mode 快照 輔助", M.Mode("utility"), "miliui")
eq("Mode nil ＝ 主題", M.Mode(nil), "masque")
eq("快照當下不需要重載", M.NeedsReload(), false)

local sig0 = M.ModesSig()
P.theme.icon.skin = "miliui"
eq("改了設定 Desired 跟著變", M.Desired("essential"), "miliui")
eq("改了設定 Mode 不變（工作階段固定）", M.Mode("essential"), "masque")
eq("改了設定需要重載", M.NeedsReload(), true)
check("ModesSig 跟著變", M.ModesSig() ~= sig0)
P.theme.icon.skin = "masque"
eq("改回來就不用重載", M.NeedsReload(), false)
eq("改回來 ModesSig 一樣", M.ModesSig(), sig0)

-- 跟隨開關一切：實際要的模式變了也算
P.bars.utility.follow.icon = true
eq("輔助改成跟隨 → Desired 變 Masque", M.Desired("utility"), "masque")
eq("輔助跟隨切換需要重載", M.NeedsReload(), true)
P.bars.utility.follow.icon = false
eq("切回不跟隨不用重載", M.NeedsReload(), false)

-- 之後才建的條沒有自己的快照 → 主題的
local g = ns.DB.CreateBar("icons", "新群組")
eq("新群組 Mode ＝ 主題快照", M.Mode(g), "masque")
eq("新群組跟隨主題不需要重載", M.NeedsReload(), false)
P.theme.icon.skin = "miliui"
eq("主題改了：新群組 Mode 仍是主題快照", M.Mode(g), "masque")
P.theme.icon.skin = "masque"
ns.DB.DeleteBar(g)

------------------------------------------------------------
-- 3. 型別
------------------------------------------------------------
eq("核心 Action", M.TypeFor("essential"), "Action")
eq("增益圖示 Debuff", M.TypeFor("buffs"), "Debuff")
eq("增益長條 Debuff", M.TypeFor("buffbars"), "Debuff")
eq("item 來源優先：增益來源", M.TypeFor("g1", "buffs"), "Debuff")
eq("item 來源優先：核心來源", M.TypeFor("buffs", "essential"), "Action")
eq("自訂項目", M.TypeFor("essential", "custom"), "Action")
local gb = ns.DB.CreateBar("icons", "增益群")
P.bars[gb].source = "buffs"
eq("增益來源的群組（佔位用）", M.TypeFor(gb), "Debuff")
ns.DB.DeleteBar(gb)

------------------------------------------------------------
-- 4. 交格子
------------------------------------------------------------
local holder, btn = {}, Frame(36)
local regions = { Icon = {}, Cooldown = {} }
Reset()
eq("第一次交 → Masque 在畫", M.Sync(holder, btn, regions, "Action", 36, 36), true)
eq("群組名稱是插件標題", groupNames[1], "MiliUI Cooldown Manager")
eq("只建一個群組", #groupNames, 1)
eq("AddButton 一次", #calls, 1)
eq("AddButton 動作", calls[1][1], "add")
check("AddButton 給完整 regions", calls[1][3] == regions)
eq("AddButton 型別", calls[1][4], "Action")
eq("AddButton Strict", calls[1][5], true)
check("regions 不帶 Count", regions.Count == nil)
eq("holder 記下框", holder.msqButton, btn)
eq("IsSkinned", M.IsSkinned(holder), true)

Reset()
eq("同尺寸再叫", M.Sync(holder, btn, regions, "Action", 36, 36), true)
eq("同尺寸不重套", #calls, 0)

Reset()
M.Sync(holder, btn, regions, "Action", 40, 36)
eq("尺寸變了 ReSkin", calls[1] and calls[1][1], "reskin")
eq("ReSkin 只一次", #calls, 1)

-- 換了框（例如格子形狀變了）：舊的先拿掉
Reset()
local btn2 = Frame(36)
M.Sync(holder, btn2, regions, "Action", 40, 36)
eq("換框 先 Remove 舊的", calls[1] and calls[1][1], "remove")
check("Remove 的是舊框", calls[1] and calls[1][2] == btn)
eq("再 Add 新的", calls[2] and calls[2][1], "add")
eq("holder 換成新框", holder.msqButton, btn2)

Reset()
M.Release(holder)
eq("Release → RemoveButton", calls[1] and calls[1][1], "remove")
eq("Release 清掉 holder", holder.msqButton, nil)
eq("Release 後不算 skinned", M.IsSkinned(holder), false)

-- 秘密幾何：不交
Reset()
local hs, bs = {}, Frame(SECRET)
eq("秘密寬度 → 不交", M.Sync(hs, bs, regions, "Action", 36, 36), false)
eq("秘密寬度 → 沒叫 Masque", #calls, 0)
eq("秘密寬度 → holder 空", hs.msqButton, nil)

-- 戰鬥中、框在保護鏈上：延到脫戰，補做完叫 onLate
Reset()
local hc, bc = {}, Frame(36)
bc.protected = true
state.combat = true
local late = 0
eq("戰鬥中保護框 → 先不算 Masque 在畫", M.Sync(hc, bc, regions, "Action", 36, 36, function() late = late + 1 end), false)
eq("戰鬥中沒叫 Masque", #calls, 0)
eq("戰鬥中 holder 還沒記", hc.msqButton, nil)
-- 同一場戰鬥又套了一次（尺寸變了）：照樣記帳
M.Sync(hc, bc, regions, "Action", 40, 36, function() late = late + 1 end)
Regen()
eq("脫戰補做 Add", calls[1] and calls[1][1], "add")
eq("補做完叫 onLate", late >= 1, true)
eq("補做完 holder 記下框", hc.msqButton, bc)
eq("補做完 Masque 在畫", M.IsSkinned(hc), true)

-- 戰鬥中、框不在保護鏈上：當場交
Reset()
local hn, bn = {}, Frame(36)
state.combat = true
eq("戰鬥中一般框 → 當場交", M.Sync(hn, bn, regions, "Debuff", 36, 36), true)
eq("戰鬥中一般框 → Add", calls[1] and calls[1][1], "add")
eq("戰鬥中一般框 → 型別", calls[1] and calls[1][4], "Debuff")
state.combat = false

------------------------------------------------------------
-- 5. 群組在 Masque 裡被停用
------------------------------------------------------------
check("有掛 Masque 的回呼", type(fakeGroup.cb) == "function")
fakeGroup.db.Disabled = true
eq("停用 → Active false", M.Active(), false)
eq("停用 → 不算 Masque 在畫", M.IsSkinned(holder), false)
eq("停用 → 已交的格子也不算", M.IsSkinned(hn), false)
local invalidated, requested = 0, nil
ns.Decorate = { InvalidateAll = function() invalidated = invalidated + 1 end }
ns.Bars = { RequestAll = function(level) requested = level end }
fakeGroup.cb(fakeGroup, "Disabled", true)
eq("停用回呼 → 全部重套", invalidated, 1)
eq("停用回呼 → 重排等級", requested, "layout")
eq("停用回呼 → 聊天框提示一次", #printed, 1)
fakeGroup.cb(fakeGroup, "Disabled", true)
eq("提示只一次", #printed, 1)
fakeGroup.db.Disabled = false
fakeGroup.cb(fakeGroup, "Disabled", false)
eq("啟用回呼 → 也重套", invalidated, 3)
eq("啟用 → 已交的格子又算 Masque 在畫", M.IsSkinned(hn), true)
fakeGroup.cb(fakeGroup, "SkinID", "Zoomed")
eq("換皮 → 重套（轉圈色寫回）", invalidated, 4)

-- 光環格的探針：Generation 跟著回呼加、GetNormal 只走公開 API
local g0 = M.Generation()
fakeGroup.cb(fakeGroup, "Gloss", true)
eq("回呼 → Generation +1", M.Generation(), g0 + 1)
local nt = {}
masqueLib.GetNormal = function(_, b) if b == "probe" then return nt end end
eq("GetNormal：公開 API 拿到的貼圖", M.GetNormal("probe"), nt)
eq("GetNormal：沒有 ⇒ nil", M.GetNormal("other"), nil)
masqueLib.GetNormal = function() error("boom") end
eq("GetNormal：API 出錯 ⇒ nil（不報錯）", M.GetNormal("probe"), nil)
masqueLib.GetNormal = nil
eq("GetNormal：沒有這支 API ⇒ nil", M.GetNormal("probe"), nil)

------------------------------------------------------------
-- 5b. 皮的形狀（ShapeOf）＋公開 API 的兩支貼圖查詢
------------------------------------------------------------
do
    local cfg = { Shape = "Circle" }
    local fr = { _MSQ_CFG = cfg }
    eq("ShapeOf：讀 _MSQ_CFG.Shape", M.ShapeOf(fr), "Circle")
    cfg.Shape = "Hexagon"
    eq("ShapeOf：同一個 Generation 走快取", M.ShapeOf(fr), "Circle")
    fakeGroup.cb(fakeGroup, "SkinID", "Hex")
    eq("ShapeOf：Generation 變了 ⇒ 重讀", M.ShapeOf(fr), "Hexagon")
    eq("ShapeOf：沒有 _MSQ_CFG ⇒ nil", M.ShapeOf({}), nil)
    eq("ShapeOf：Shape 不是字串 ⇒ nil", M.ShapeOf({ _MSQ_CFG = { Shape = 3 } }), nil)
    eq("ShapeOf：Shape 空字串 ⇒ nil", M.ShapeOf({ _MSQ_CFG = { Shape = "" } }), nil)
    eq("ShapeOf：Shape 是秘密值 ⇒ nil", M.ShapeOf({ _MSQ_CFG = { Shape = SECRET } }), nil)
    eq("ShapeOf：_MSQ_CFG 是秘密值 ⇒ nil", M.ShapeOf({ _MSQ_CFG = SECRET }), nil)
    eq("ShapeOf：nil ⇒ nil", M.ShapeOf(nil), nil)
    -- 只讀原始欄位：__index 不會被叫到
    local touched = false
    local trap = setmetatable({}, { __index = function() touched = true; error("boom") end })
    eq("ShapeOf：欄位不在 ⇒ nil（不走 __index、不報錯）", M.ShapeOf(trap), nil)
    eq("ShapeOf：沒碰 __index", touched, false)
    local late = {}
    eq("ShapeOf：套皮前讀不到", M.ShapeOf(late), nil)
    late._MSQ_CFG = { Shape = "Circle" }
    eq("ShapeOf：讀不到不快取（套皮晚到照樣讀得到）", M.ShapeOf(late), "Circle")

    local styles = {}
    local FB = {
        Circle = { LoopTexture = "Masque/Circle/Loop", FrameWidth = 84, FrameHeight = 84 },
        Square = { LoopTexture = "Masque/Square/Loop", FrameWidth = 84, FrameHeight = 84 },
        Hexagon = { LoopTexture = "Masque/Hexagon/Loop", FrameWidth = 84, FrameHeight = 84 },
        Odd = { LoopTexture = "Odd/Loop", FrameWidth = 64, FrameHeight = 64, Rows = 4, Columns = 4, Frames = 16 },
        Junk = { LoopTexture = 12 },
    }
    masqueLib.GetSpellAlertFlipBook = function(_, style, shape) styles[#styles + 1] = style; return FB[shape] end
    masqueLib.GetSpellAlert = function(_, shape)
        if shape == "Circle" then return "Masque/Circle/Glow", "Masque/Circle/Ants" end
    end
    local lp = M.SpellAlertLoop("Circle")
    check("SpellAlertLoop：圓形循環圖", lp and lp.tex == "Masque/Circle/Loop" and lp.w == 84 and lp.h == 84 and lp.rows == nil)
    eq("SpellAlertLoop：風格固定 Modern", styles[1], "Modern")
    local odd = M.SpellAlertLoop("Odd")
    check("SpellAlertLoop：排法不是 6×5／30 才帶", odd and odd.rows == 4 and odd.cols == 4 and odd.frames == 16)
    eq("SpellAlertLoop：沒有這個形狀 ⇒ nil", M.SpellAlertLoop("Star"), nil)
    eq("SpellAlertLoop：資料不對 ⇒ nil", M.SpellAlertLoop("Junk"), nil)
    eq("SpellAlertLoop：不是字串 ⇒ nil", M.SpellAlertLoop(nil), nil)
    local g1, a1 = M.SpellAlertOverlay("Circle")
    check("SpellAlertOverlay：圓形兩張", g1 == "Masque/Circle/Glow" and a1 == "Masque/Circle/Ants")
    eq("SpellAlertOverlay：六角形沒有 ⇒ nil", M.SpellAlertOverlay("Hexagon"), nil)

    --------------------------------------------------------
    -- 發光跟著皮的形狀（Core/Glow.lua）
    --------------------------------------------------------
    env.C_AddOns = { IsAddOnLoaded = function(n) return n == "Masque" end }
    local G = ns.Glow
    local function Btn(shape) return { _MSQ_CFG = { Shape = shape } } end
    local asks = 0
    local realShapeOf = M.ShapeOf
    M.ShapeOf = function(...) asks = asks + 1; return realShapeOf(...) end

    -- 圓形皮 × 四種樣式
    local circle = Btn("Circle")
    local r = GlowRec("essential", circle)
    G.Start(r, "active", "essential", { type = "pixel", color = { r = 0.2, g = 0.4, b = 0.6, a = 1 } })
    local lg = LastGlow()
    eq("圓形：像素改畫觸發", lg[1], "proc+")
    eq("圓形：顏色沿用原設定", lg[4] and lg[4][2], 0.4)
    eq("圓形：沒有入場動畫", lg[5], false)
    eq("圓形：記下實際樣式（停的時候照它停）", r.glowOn.active, "proc")
    local pf = r.glowHosts.active._ProcGlowactive
    eq("圓形：循環圖換成圓形", pf and pf.ProcLoop.tex, "Masque/Circle/Loop")
    eq("圓形：格子 84", pf and pf.ProcLoopAnim.flipbookRepeat.FlipBookFrameWidth, 84)
    check("圓形：換了貼圖重播", pf and pf.ProcLoopAnim.plays >= 1)
    check("圓形：問過形狀", asks > 0)
    G.Start(r, "ready", "essential", { type = "autocast" })
    eq("圓形：自動施法改畫觸發", LastGlow()[1], "proc+")
    eq("圓形：自動施法 → 圓形循環圖", r.glowHosts.ready._ProcGlowready.ProcLoop.tex, "Masque/Circle/Loop")
    G.Start(r, "proc", "essential", { type = "proc" })
    eq("圓形：觸發照畫觸發", LastGlow()[1], "proc+")
    eq("圓形：觸發沒有入場動畫", LastGlow()[5], false)
    eq("圓形：觸發 → 圓形循環圖", r.glowHosts.proc._ProcGlowproc.ProcLoop.tex, "Masque/Circle/Loop")
    G.Start(r, "assist", nil, { type = "button" })
    eq("圓形：閃光照畫閃光", LastGlow()[1], "button+")
    local bf = r.glowHosts.assist._ButtonGlow
    check("圓形：閃光五張換成圓形 Glow", bf and bf.spark.tex == "Masque/Circle/Glow" and bf.outerGlowOver.tex == "Masque/Circle/Glow"
        and bf.innerGlow.tex == "Masque/Circle/Glow")
    eq("圓形：螞蟻線換成圓形 Ants", bf and bf.ants.tex, "Masque/Circle/Ants")
    -- 同設定再叫：簽章一樣不重畫
    local n0 = #glowLog
    G.Start(r, "active", "essential", { type = "pixel", color = { r = 0.2, g = 0.4, b = 0.6, a = 1 } })
    eq("圓形：同簽章不重畫", #glowLog, n0)

    -- 換皮（Generation 變了）成方形：舊的照記下的樣式停乾淨、重畫成原樣式；閃光框回池子後拿回來要換回暴雪的貼圖
    circle._MSQ_CFG.Shape = "Square"
    fakeGroup.cb(fakeGroup, "SkinID", "Sq")
    G.Start(r, "active", "essential", { type = "pixel", color = { r = 0.2, g = 0.4, b = 0.6, a = 1 } })
    eq("換成方形：先停觸發", glowLog[#glowLog - 1][1], "proc-")
    eq("換成方形：停的是那一格", glowLog[#glowLog - 1][3], "active")
    eq("換成方形：重畫成像素", LastGlow()[1], "pixel+")
    eq("換成方形：記下的樣式", r.glowOn.active, "pixel")
    G.Start(r, "assist", nil, { type = "button" })
    local bf2 = r.glowHosts.assist._ButtonGlow
    check("換成方形：閃光換回暴雪的兩張", bf2 and bf2.spark.tex == BTN_GLOW and bf2.innerGlowOver.tex == BTN_GLOW
        and bf2.ants.tex == BTN_ANTS)
    -- 方形皮的觸發：跟以前一樣（Masque 的方形循環圖、沒有入場動畫）
    G.Stop(r, "proc")
    G.Start(r, "proc", "essential", { type = "proc" })
    eq("方形皮：觸發用方形循環圖（同以前）", r.glowHosts.proc._ProcGlowproc.ProcLoop.tex,
        [[Interface\AddOns\Masque\Textures\Square\SpellAlert-Loop-Modern]])
    eq("方形皮：沒有入場動畫（同以前）", LastGlow()[5], false)
    G.Start(r, "ready", "essential", { type = "autocast" })
    eq("方形皮：自動施法照畫", LastGlow()[1], "autocast+")
    -- 池化的閃光框輪到別的宿主：方形宿主拿到的是暴雪的貼圖
    G.Stop(r, "assist")
    local r2 = GlowRec("essential", Btn("Circle"))
    G.Start(r2, "active", "essential", { type = "button" })
    eq("另一格圓形：拿到池裡那顆、換成圓形", r2.glowHosts.active._ButtonGlow.spark.tex, "Masque/Circle/Glow")
    G.Stop(r2, "active")
    local r3 = GlowRec("essential", nil)
    G.Start(r3, "active", "essential", { type = "button" })
    eq("沒交給 Masque 的格子拿到同一顆：換回暴雪的", r3.glowHosts.active._ButtonGlow.spark.tex, BTN_GLOW)
    eq("Modern 也算方形", (G.SkinShape(Btn("Modern"), "essential")), nil)

    -- 六角形：閃光拿不到貼圖 ⇒ 改畫六角形的觸發
    local r4 = GlowRec("essential", Btn("Hexagon"))
    G.Start(r4, "active", "essential", { type = "button" })
    eq("六角形：閃光改畫觸發", LastGlow()[1], "proc+")
    eq("六角形：六角形循環圖", r4.glowHosts.active._ProcGlowactive.ProcLoop.tex, "Masque/Hexagon/Loop")

    -- 循環圖排法不是 6×5：寫進去；之後換回暴雪圖集要把排法寫回預設
    local r5 = GlowRec("essential", Btn("Odd"))
    G.Start(r5, "proc", "essential", { type = "proc" })
    local fb5 = r5.glowHosts.proc._ProcGlowproc.ProcLoopAnim.flipbookRepeat
    check("排法不同：寫進去", fb5.FlipBookRows == 4 and fb5.FlipBookColumns == 4 and fb5.FlipBookFrames == 16)
    env.C_AddOns = nil
    local r6 = GlowRec("essential", nil)
    G.Start(r6, "proc", "essential", { type = "proc" })
    local fb6 = r6.glowHosts.proc._ProcGlowproc.ProcLoopAnim.flipbookRepeat
    check("寫過之後換回圖集：排法寫回 6×5／30", fb6.FlipBookRows == 6 and fb6.FlipBookColumns == 5 and fb6.FlipBookFrames == 30)
    env.C_AddOns = { IsAddOnLoaded = function(n) return n == "Masque" end }

    -- 短路：米利模式的條、沒交出去、長條 ⇒ 不問形狀
    asks = 0
    local rm = GlowRec("utility", Btn("Circle"))          -- utility 的快照是米利
    G.Start(rm, "active", "utility", { type = "pixel" })
    eq("米利模式：照畫像素", LastGlow()[1], "pixel+")
    local rn = GlowRec("essential", Btn("Circle")); rn.msqSkinned = false
    G.Start(rn, "active", "essential", { type = "pixel" })
    eq("沒交出去：照畫像素", LastGlow()[1], "pixel+")
    local rb = GlowRec("essential", Btn("Circle")); rb.barGeometry = { h = 20 }
    G.Start(rb, "active", "essential", { type = "pixel" })
    eq("長條：照畫像素", LastGlow()[1], "pixel+")
    eq("短路：三種都沒問形狀", asks, 0)

    -- 群組停用（Active false）：Decorate 重套後 msqSkinned 變 false ⇒ 舊的圓形停掉、回原樣式
    local rd = GlowRec("essential", Btn("Circle"))
    G.Start(rd, "active", "essential", { type = "pixel" })
    eq("停用前：圓形觸發", rd.glowOn.active, "proc")
    rd.msqSkinned = false
    G.Start(rd, "active", "essential", { type = "pixel" })
    eq("停用後：舊的觸發停掉", glowLog[#glowLog - 1][1], "proc-")
    eq("停用後：回到像素", rd.glowOn.active, "pixel")

    -- API 讀不到（回 nil／出錯）⇒ 方形（原樣式）
    masqueLib.GetSpellAlertFlipBook = function() return nil end
    masqueLib.GetSpellAlert = function() error("boom") end
    fakeGroup.cb(fakeGroup, "SkinID", "Broken")             -- 貼圖快取跟著 Generation 作廢
    local ra = GlowRec("essential", Btn("Circle"))
    G.Start(ra, "active", "essential", { type = "pixel" })
    eq("API 讀不到：像素照畫像素", LastGlow()[1], "pixel+")
    G.Start(ra, "assist", nil, { type = "button" })
    eq("API 讀不到：閃光照畫閃光", LastGlow()[1], "button+")
    eq("API 讀不到：閃光是暴雪的貼圖", ra.glowHosts.assist._ButtonGlow.spark.tex, BTN_GLOW)
    G.Start(ra, "proc", "essential", { type = "proc" })
    eq("API 讀不到：觸發用方形循環圖", ra.glowHosts.proc._ProcGlowproc.ProcLoop.tex,
        [[Interface\AddOns\Masque\Textures\Square\SpellAlert-Loop-Modern]])
    masqueLib.GetSpellAlertFlipBook, masqueLib.GetSpellAlert = nil, nil
    fakeGroup.cb(fakeGroup, "SkinID", "None")
    eq("API 不在：ShapedStyle 照原樣式", (G.ShapedStyle("pixel", "Circle")), "pixel")

    -- 光環按鈕（Attach 之後換貼圖）
    local af = { ProcLoop = Tex(nil), ProcLoopAnim = AnimGroup(FlipBook()) }
    G.SkinAttached(af, { t = "proc", loop = { tex = "Masque/Circle/Loop", w = 84, h = 84 } })
    check("SkinAttached：觸發換循環圖、格子、重播", af.ProcLoop.tex == "Masque/Circle/Loop"
        and af.ProcLoopAnim.flipbookRepeat.FlipBookFrameWidth == 84 and af.ProcLoopAnim.plays == 1)
    local ab = { spark = Tex(BTN_GLOW), outerGlow = Tex(BTN_GLOW), ants = Tex(BTN_ANTS) }
    G.SkinAttached(ab, { t = "button", glow = "Masque/Circle/Glow", ants = "Masque/Circle/Ants" })
    check("SkinAttached：閃光換三張", ab.spark.tex == "Masque/Circle/Glow" and ab.outerGlow.tex == "Masque/Circle/Glow"
        and ab.ants.tex == "Masque/Circle/Ants")
    G.SkinAttached(ab, nil)
    eq("SkinAttached：沒有 art 不動", ab.spark.sets, 1)

    M.ShapeOf = realShapeOf
    env.C_AddOns = nil
end

------------------------------------------------------------
-- 6. 開 Masque 設定
------------------------------------------------------------
state.combat = true
M.OpenOptions()
eq("戰鬥中不開", slashArgs, nil)
state.combat = false
M.OpenOptions()
eq("走 /msq", slashArgs, "")
eq("先關自己的設定視窗", closed, 1)

print(("Masque_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
