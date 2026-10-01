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
-- 換框先 Remove、秘密幾何不交、戰鬥中保護框延到脫戰並叫 onLate）、群組停用、開 Masque 設定。
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
