------------------------------------------------------------
-- 小項（P5）的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Extras_test.lua
--
-- 覆蓋：
--   1. 自訂法術的距離／可用上色：優先序（ColorState）、暴雪常數讀得到／讀不到（StateColor）、
--      距離檢查開關與「暴雪也在查就不關」、範圍事件（明文才收、秘密值當讀不到）、未學會不上色
--   2. 自訂圖示：覆寫的判讀（IconOverrideOf：壞值／false／光環格）、ns.IconFor、暴雪 item 的貼圖掛勾
--      （沒設不掛、設了蓋回去、身分換了不蓋、拿掉覆寫換回原圖、掛勾不碰傳進來的參數）
--   3. 跟著游標：資格（Eligible）、位移預設、座標換算、Configured／Following、排開把它當不存在、
--      OnUpdate 只在看得到時掛、保護框不動
--   4. 語音播報：要念的字（SpeakText）、Speak 的參數／總開關／節流、WantsReady／出現消失批次會念、覆寫分組
--   5. 長條火花：預設值、進條層簽章；新欄位的預設值（舊存檔沒有＝行為不變）
--   6. 增益持續時間的倒數換色：三態 × 條層開關（DurationColorOf）、兩段顏色（PhaseColors）、預設值與
--      覆寫登記、SpellOverride 分得出跟隨、簽章、SetUseAuraDisplayTime 後掛勾（明文／秘密／掛上時先問 getter）
--      ＋ SetCooldown 後掛勾換色
-- 環境表做法同 DB_test.lua：這支本身不寫任何全域。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."

local unpack = table.unpack or unpack

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
local function near(name, got, want)
    check(name, type(got) == "number" and math.abs(got - want) < 1e-9, "got " .. tostring(got) .. ", want " .. tostring(want))
end

------------------------------------------------------------
-- 秘密值的替身：任何讀取、比較、串接都拋錯（掛勾碰到它就會被抓到）
------------------------------------------------------------
local SECRET_MT = {
    __index = function() error("讀了秘密值") end,
    __eq = function() error("比較了秘密值") end,
    __lt = function() error("比較了秘密值") end,
    __le = function() error("比較了秘密值") end,
    __concat = function() error("串接了秘密值") end,
}
local function Secret() return setmetatable({}, SECRET_MT) end
local function IsSecret(v) return type(v) == "table" and getmetatable(v) == SECRET_MT end

------------------------------------------------------------
-- WoW API stub
------------------------------------------------------------
local state = { now = 100, combat = false, cx = 500, cy = 400, scale = 2 }
local env = setmetatable({}, { __index = _G })
env._G = env
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.InCombatLockdown = function() return state.combat end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.UnitClass = function() return "聖騎士", "PALADIN", 2 end
env.GetTime = function() return state.now end
env.canaccessvalue = function(v) return not IsSecret(v) end
env.Enum = {
    CompressionMethod = { Deflate = 1 },
    CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 },
    CooldownSetSpellFlags = { HideByDefault = 2 },
    TtsVoiceType = { Standard = 0, Alternate = 1 },
}
env.CDM_HIDE_INVISIBLE_ITEMS = false
local SETS = { [0] = { 11, 12 }, [1] = { 21 }, [2] = { 31, 32 }, [3] = { 41 } }
env.C_CooldownViewer = {
    GetCooldownViewerCategorySet = function(cat) return SETS[cat] or {} end,
    GetCooldownViewerCooldownInfo = function(id)
        return { cooldownID = id, spellID = id * 100, category = math.floor(id / 10) - 1, isKnown = true, flags = 0 }
    end,
    GetLayoutData = function() return "" end,
}

-- 法術：距離與可用
local hasRange = { [500] = true, [600] = true }
local inRange = {}            -- id → true／false／nil
local usable = {}             -- id → { isUsable, noMana }
local rangeCalls = {}         -- { id, enable }
env.C_Spell = {
    GetSpellTexture = function(id) return 900000 + id end,
    GetSpellName = function(id) return "法術" .. id end,
    GetOverrideSpell = function(id) return id end,
    SpellHasRange = function(id) return hasRange[id] == true end,
    EnableSpellRangeCheck = function(id, on) rangeCalls[#rangeCalls + 1] = { id, on } end,
    IsSpellInRange = function(id) return inRange[id] end,
    IsSpellUsable = function(id)
        local u = usable[id]
        if not u then return true, false end
        return u[1], u[2]
    end,
}
env.C_SpellBook = { IsSpellKnown = function() return true end }
env.C_Item = {
    GetItemIconByID = function(id) return 800000 + id end,
    GetItemNameByID = function(id) return "物品" .. id end,
    GetItemInfoInstant = function(id) return id, "", "", "", 800000 + id end,
}

-- 語音
local spoken = {}
env.C_VoiceChat = { SpeakText = function(...) spoken[#spoken + 1] = { ... } end }
env.C_TTSSettings = {
    GetVoiceOptionID = function(t) if t == 0 then return 7 end return 8 end,
    GetSpeechRate = function() return 2 end,
    GetSpeechVolume = function() return 80 end,
}
env.PlaySoundFile = function() return true end
local lsm = { Fetch = function(_, kind, name) if kind == "sound" and name == "Ding" then return "ding.ogg" end end }
env.LibStub = function(name) if name == "LibSharedMedia-3.0" then return lsm end end

-- 框：記下腳本與錨點
local function Frame()
    local f = { scripts = {}, points = {}, setPointCalls = 0 }
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... }; self.setPointCalls = self.setPointCalls + 1 end
    return f
end
local created = {}
env.CreateFrame = function() local f = Frame(); created[#created + 1] = f; return f end
-- 現在掛著 OnUpdate 的框（Cursor 的 driver）
local function Driver()
    for _, f in ipairs(created) do if f.scripts.OnUpdate then return f end end
end
env.UIParent = { GetEffectiveScale = function() return state.scale end }
env.GetCursorPosition = function() return state.cx, state.cy end

local hooks = {}
env.hooksecurefunc = function(t, name, fn) hooks[#hooks + 1] = { t = t, name = name, fn = fn } end

local deferred = {}
local callbacks = {}
local events = {}
local notes = {}
local protected = {}          -- 框 → true（ns.IsProtectedFrame 的替身）
local visAlpha = {}           -- key → alpha（Visibility.Current 的替身）
local containers = {}         -- key → 框（Bars.Get 的替身）
local itemIDs = {}            -- 暴雪 item → 目前身分（Viewers.ReadItemID 的替身）
local ns = {
    playerClass = "PALADIN",
    IsSecret = IsSecret,
    Events = {
        Register = function(ev, key, fn) events[ev] = events[ev] or {}; events[ev][key] = fn end,
        Unregister = function(ev, key) if events[ev] then events[ev][key] = nil end end,
    },
    Defer = function(fn, ...) deferred[#deferred + 1] = { fn = fn, n = select("#", ...), ... } end,
    Fire = function() end,
    RegisterCallback = function(ev, key, fn) callbacks[ev .. "|" .. key] = fn end,
    ReportError = function(err) print("ReportError: " .. tostring(err)) end,
    Guard = function(fn) return fn end,
    Write = function(frame, fn) fn(frame) return true end,
    IsProtectedFrame = function(f) return protected[f] == true end,
    Diag = { Note = function(kind, text) notes[#notes + 1] = { kind, text } end },
    Viewers = {
        frames = setmetatable({}, { __mode = "k" }),
        AURA_KIND = { buffs = true, buffbars = true },
        ReadItemID = function(item) return itemIDs[item] end,
    },
    Visibility = { Current = function(key) return visAlpha[key] end },
    Bars = { Get = function(key) return containers[key] end },
    EditMode = { active = false },
}
function ns.RefreshSpec() ns.specIndex = 1; ns.specID = 61 end
local function Flush()
    local list = deferred
    deferred = {}
    for _, job in ipairs(list) do job.fn(unpack(job, 1, job.n)) end
end

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
Load("Core/Catalog.lua")
Load("Core/Layout.lua")
Load("Core/SpellIndex.lua")
Load("Core/Decorate.lua")
Load("Core/Sound.lua")
Load("Modules/Custom.lua")
Load("Core/Cursor.lua")
local DB, C, D, S, CU, Cur, Lay = ns.DB, ns.Catalog, ns.Decorate, ns.Sound, ns.Custom, ns.Cursor, ns.Layout
ns.RefreshSpec()
DB.Init()
C.Refresh("test")
local p = ns.profile

------------------------------------------------------------
-- 1. 自訂法術的距離／可用上色
------------------------------------------------------------
eq("優先序：超出距離最先", CU.ColorState(true, true, false), "range")
eq("超出距離蓋過不可用", CU.ColorState(true, false, true), "range")
eq("可用", CU.ColorState(false, true, false), "usable")
eq("資源不夠", CU.ColorState(false, false, true), "noMana")
eq("不可用", CU.ColorState(nil, false, false), "unusable")
eq("不可用、資源欄位讀不到", CU.ColorState(nil, false, nil), "unusable")
eq("可用讀不到 ⇒ 當可用", CU.ColorState(nil, nil, nil), "usable")
eq("距離讀不到（nil）不算超出", CU.ColorState(nil, true, false), "usable")

do
    local r, g, b, a = CU.StateColor("range")
    near("讀不到暴雪常數：超出距離用同值 r", r, 0.64); near("g", g, 0.15); near("b", b, 0.15); near("a", a, 1)
    r, g, b = CU.StateColor("noMana")
    near("資源不夠 r", r, 0.5); near("資源不夠 b", b, 1)
    r = CU.StateColor("unusable")
    near("不可用 0.4", r, 0.4)
    r = CU.StateColor("bogus")
    near("不認得的狀態 ⇒ 可用（白）", r, 1)
    -- 暴雪的常數讀得到就用它的
    env.CooldownViewerConstants = { ITEM_NOT_IN_RANGE_COLOR = { GetRGBA = function() return 0.7, 0.1, 0.2, 0.9 end } }
    r, g, b, a = CU.StateColor("range")
    near("讀得到暴雪常數就用它的 r", r, 0.7); near("a", a, 0.9)
    env.CooldownViewerConstants = nil
    r = CU.StateColor("range")
    near("讀到過就快取", r, 0.7)
end

-- 假的自訂法術 rec（直接塞進 Custom 的記錄表，不經過 Sync／Place）
local function IconFrame()
    local icon = { colors = {} }
    function icon:SetVertexColor(r, g, b, a) self.colors[#self.colors + 1] = { r, g, b, a } end
    return { Icon = icon }
end
local recs = CU.Records()
local sr = { kind = "spell", spellID = 500, cooldownID = "c:1", placedBar = "essential", known = true, frame = IconFrame() }
recs.test500 = sr
inRange[500] = false
CU.EnsureRange(sr)
eq("有距離的法術開了檢查", rangeCalls[1] and rangeCalls[1][2], true)
eq("開的是基底 id", rangeCalls[1] and rangeCalls[1][1], 500)
eq("起始狀態：超出距離", sr.outOfRange, true)
CU.RefreshColor(sr)
local last = sr.frame.Icon.colors[#sr.frame.Icon.colors]
near("超出距離染紅（已快取暴雪的 0.7）", last and last[1], 0.7)
local nColors = #sr.frame.Icon.colors
CU.RefreshColor(sr)
eq("狀態沒變不重寫", #sr.frame.Icon.colors, nColors)
CU.EnsureRange(sr)
eq("已開的不重開", #rangeCalls, 1)

-- 範圍事件：明文才收；checksRange false ＝ 不算超出
CU.OnRangeUpdate(500, true, true)
eq("回到距離內", sr.outOfRange, false)
last = sr.frame.Icon.colors[#sr.frame.Icon.colors]
near("回到距離內是白色", last and last[1], 1)
CU.OnRangeUpdate(500, false, false)
eq("沒做距離檢查（沒目標）不算超出", sr.outOfRange, false)
CU.OnRangeUpdate(500, false, true)
eq("超出距離", sr.outOfRange, true)
CU.OnRangeUpdate(Secret(), false, true)
eq("秘密 spellID 不收（狀態不動）", sr.outOfRange, true)
CU.OnRangeUpdate(500, Secret(), Secret())
eq("秘密的距離參數當讀不到：不算超出", sr.outOfRange, false)
CU.OnRangeUpdate(999, false, true)
eq("不是我們開的法術不理", sr.outOfRange, false)

-- 可用與否
usable[500] = { false, true }
CU.RefreshColor(sr)
eq("資源不夠", sr.colorState, "noMana")
usable[500] = { false, false }
CU.RefreshColor(sr)
eq("不可用", sr.colorState, "unusable")
usable[500] = { Secret(), Secret() }
CU.RefreshColor(sr)
eq("可用讀不到（秘密）⇒ 當可用", sr.colorState, "usable")
usable[500] = nil
sr.known = false
sr.outOfRange = true
CU.RefreshColor(sr)
eq("未學會不上色（白）", sr.colorState, "usable")
sr.known = true

-- 收起來：關掉；暴雪自己也在查同一個法術時不關
CU.DropRange(sr)
eq("收起來關掉", rangeCalls[#rangeCalls][2], false)
eq("rec 清掉", sr.rangeID, nil)
local blizz = {}
blizz.rangeCheckSpellID = 500
ns.Viewers.frames[blizz] = { barKey = "essential" }
CU.EnsureRange(sr)
local before = #rangeCalls
CU.DropRange(sr)
eq("暴雪也在查：不關", #rangeCalls, before)
ns.Viewers.frames[blizz] = nil
local nr = { kind = "spell", spellID = 777, frame = IconFrame() }
CU.EnsureRange(nr)
eq("沒有距離的法術不開", nr.rangeID, nil)
eq("沒有距離記下來（不每輪重問）", nr.noRange, true)
CU.DropRange(nr)
eq("收起來清掉記號", nr.noRange, nil)
recs.test500 = nil

------------------------------------------------------------
-- 2. 自訂圖示
------------------------------------------------------------
eq("沒設 ⇒ nil", D.IconOverrideOf(11), nil)
DB.SetOverride(11, "customIcon", 135000)
eq("讀回覆寫", D.IconOverrideOf(11), 135000)
eq("IconFor 用覆寫", ns.IconFor("essential", 11, { icon = 1 }), 135000)
eq("IconFor 沒覆寫用 info.icon", ns.IconFor("essential", 12, { icon = 4242 }), 4242)
eq("IconFor 沒 info", ns.IconFor("essential", 12, nil), nil)
DB.SetOverride(12, "customIcon", false)
eq("false ＝ 沒設", D.IconOverrideOf(12), nil)
DB.SetOverride(12, "customIcon", "abc")
eq("字串是壞值", D.IconOverrideOf(12), nil)
DB.SetOverride(12, "customIcon", -5)
eq("負數是壞值", D.IconOverrideOf(12), nil)
DB.SetOverride(12, "customIcon", 1.5)
eq("小數是壞值", D.IconOverrideOf(12), nil)
DB.SetOverride(12, "customIcon", nil)
eq("覆寫分組：圖示節", DB.OVERRIDE_GROUP.customIcon, "icon")
eq("沒有條層值（固定 false）", DB.SPELL_CONST.customIcon, false)
DB.AddCustom({ kind = "aura", spellID = 700, filter = "HELPFUL", placeholder = true, bar = "essential" })
DB.SetOverride("c:1", "customIcon", 135001)
eq("光環格不支援", D.IconOverrideOf("c:1"), nil)
eq("光環格 IconFor 照原圖", ns.IconFor("essential", "c:1", { icon = 77 }), 77)
DB.SetOverride("c:1", "customIcon", nil)

-- 暴雪 item 的貼圖掛勾
local function Texture()
    local t = { log = {} }
    function t:SetTexture(v) self.tex = v; self.log[#self.log + 1] = v end
    function t:GetObjectType() return "Texture" end
    return t
end
local item = { Icon = Texture() }
local irec = { barKey = "essential", cooldownID = 12 }
ns.Viewers.frames[item] = irec
itemIDs[item] = 12
local nh = #hooks
D.ApplyIconOverride(item, irec, 12, false, nil)
eq("沒設覆寫：不掛勾", #hooks, nh)
eq("沒設覆寫：不碰貼圖", #item.Icon.log, 0)
D.ApplyIconOverride(item, irec, 12, false, 135100)
eq("設了：掛上 SetTexture 後掛勾", #hooks, nh + 1)
eq("掛在 Icon 貼圖上", hooks[#hooks].t, item.Icon)
eq("當場換圖", item.Icon.tex, 135100)
local onTex = hooks[#hooks].fn
D.ApplyIconOverride(item, irec, 12, false, 135100)
eq("同一張貼圖不重掛", #hooks, nh + 1)
-- 暴雪換回它的圖（參數可能是秘密值）：蓋回來，而且掛勾不碰參數
local sec = Secret()
item.Icon:SetTexture(sec)
local ok, err = pcall(onTex, item.Icon, sec)
check("掛勾不碰秘密參數", ok, err)
eq("暴雪換圖後蓋回覆寫", item.Icon.tex, 135100)
-- 身分換了（SetCooldownID 的 RefreshData 比我們的後掛勾先跑）：不蓋，交回 Apply
itemIDs[item] = 31
item.Icon:SetTexture(4444)
onTex(item.Icon, 4444)
eq("身分換了：暴雪的圖留著", item.Icon.tex, 4444)
eq("身分換了：覆寫清掉", irec.iconOverride, nil)
item.Icon:SetTexture(5555)
onTex(item.Icon, 5555)
eq("清掉之後掛勾立刻走", item.Icon.tex, 5555)
-- 拿掉覆寫：換回目錄的圖
itemIDs[item] = 12
D.ApplyIconOverride(item, irec, 12, false, 135100)
D.ApplyIconOverride(item, irec, 12, false, nil)
eq("拿掉覆寫：換回原本的圖", item.Icon.tex, 900000 + 1200)
eq("拿掉覆寫：rec 清掉", irec.iconOverride, nil)
-- 長條：圖示貼圖在 item.Icon.Icon
local bitem = { Icon = { Icon = Texture() } }
ns.Viewers.frames[bitem] = { barKey = "buffbars", cooldownID = 41 }
itemIDs[bitem] = 41
D.ApplyIconOverride(bitem, ns.Viewers.frames[bitem], 41, true, 135200)
eq("長條換的是 item.Icon.Icon", bitem.Icon.Icon.tex, 135200)
-- 遞迴防護：掛勾自己的 SetTexture 不會再進來（假貼圖不會自己叫掛勾，這裡模擬一次巢狀呼叫）
do
    local t = Texture()
    local it = { Icon = t }
    local r = { barKey = "essential" }
    ns.Viewers.frames[it] = r
    itemIDs[it] = 21
    D.ApplyIconOverride(it, r, 21, false, 135300)
    local fn = hooks[#hooks].fn
    local depth = 0
    function t:SetTexture(v)
        self.tex = v
        depth = depth + 1
        if depth < 5 then fn(self, v) end
    end
    t:SetTexture(1)
    fn(t, 1)
    check("遞迴防護：巢狀呼叫不會無限遞迴", depth < 5, depth)
    eq("遞迴防護：最後是覆寫", t.tex, 135300)
end
eq("簽章帶自訂圖示", D.Signature({ sig = "s" }, 11, { customIcon = 5 }, 1, 1)
    ~= D.Signature({ sig = "s" }, 11, { customIcon = 6 }, 1, 1), true)

-- 長條名字的退路：暴雪寫進 nil／空字串時用法術名字頂（召喚物第一拍沒名字）；秘密字串與真名不碰
do
    local fs = { log = {} }
    function fs:SetText(v) self.text = v; self.log[#self.log + 1] = v end
    local bi = { Bar = { Name = fs } }
    local br = { barKey = "buffbars", cooldownID = 12 }
    ns.Viewers.frames[bi] = br
    itemIDs[bi] = 12
    local nh2 = #hooks
    D.HookItem(bi, br)
    local nameHook
    for i = nh2 + 1, #hooks do if hooks[i].t == fs then nameHook = hooks[i].fn end end
    check("HookItem 掛上名字的 SetText 後掛勾", nameHook ~= nil)
    fs:SetText(nil); nameHook(fs, nil)
    eq("nil ⇒ 用法術名字頂", fs.text, "法術1200")
    fs:SetText(""); nameHook(fs, "")
    eq("空字串 ⇒ 用法術名字頂", fs.text, "法術1200")
    fs:SetText("真名"); nameHook(fs, "真名")
    eq("真名不碰", fs.text, "真名")
    local s2 = Secret()
    fs:SetText(s2)
    local ok2, err2 = pcall(nameHook, fs, s2)
    check("秘密字串：掛勾不碰、不拋錯", ok2, err2)
    eq("秘密字串留著", fs.text, s2)
    -- 自訂框不掛
    local fs2 = {}
    function fs2:SetText() end
    local ci = { Bar = { Name = fs2 } }
    local cr = { barKey = "buffbars", custom = true }
    ns.Viewers.frames[ci] = cr
    local nh3 = #hooks
    D.HookItem(ci, cr)
    local hooked = false
    for i = nh3 + 1, #hooks do if hooks[i].t == fs2 then hooked = true end end
    eq("自訂框不掛名字掛勾", hooked, false)
end

------------------------------------------------------------
-- 3. 跟著游標
------------------------------------------------------------
check("自訂圖示群組可以", (Cur.Eligible({ kind = "icons", source = "custom" }, false)))
eq("有光環格不行", select(2, Cur.Eligible({ kind = "icons", source = "custom" }, true)), "aura")
eq("可點擊不行", select(2, Cur.Eligible({ kind = "icons", source = "custom", clickable = true }, false)), "click")
eq("內建條不行", select(2, Cur.Eligible({ kind = "icons", source = "essential" }, false)), "kind")
eq("長條群組不行", select(2, Cur.Eligible({ kind = "bars", source = "custom" }, false)), "kind")
eq("沒有表不行", select(2, Cur.Eligible(nil, false)), "kind")
do
    local x, y = Cur.Offsets({})
    eq("位移預設 x", x, 20); eq("位移預設 y", y, -20)
    x, y = Cur.Offsets({ cursor = { x = "a", y = 5 } })
    eq("壞值退回預設", x, 20); eq("y 照存", y, 5)
    x, y = Cur.Point(500, 400, 2, 20, -20)
    eq("游標換算 x（除以縮放＋位移）", x, 270); eq("游標換算 y", y, 180)
    x, y = Cur.Point(100, 100, 0, 0, 0)
    eq("縮放 0 當 1", x, 100)
end

-- 新欄位的預設：自訂圖示群組、內建條都有 cursor（關），舊存檔沒有這欄也當關
local g = DB.CreateBar("icons", "G")
eq("新群組預設關", p.bars[g].cursor.enabled, false)
eq("新群組位移 x", p.bars[g].cursor.x, 20)
eq("內建條也有預設（不讀）", p.bars.essential.cursor.enabled, false)
check("關著 ⇒ 不是 Configured", not Cur.Configured(g))
p.bars[g].cursor = nil
check("舊存檔沒有這欄 ⇒ 不是 Configured", not Cur.Configured(g))
p.bars[g].cursor = { enabled = true, x = 10, y = -10 }
check("開了 ⇒ Configured", Cur.Configured(g))
check("開了 ⇒ Following", Cur.Following(g))
ns.EditMode.active = true
check("編輯模式中不跟", not Cur.Following(g))
check("編輯模式中仍是 Configured（排開穩定）", Cur.Configured(g))
ns.EditMode.active = false
Cur.Init()
callbacks["OptionsShown|cursor"]()
check("設定視窗開著不跟", not Cur.Following(g))
callbacks["OptionsHidden|cursor"]()
check("設定視窗關了又跟", Cur.Following(g))
p.bars[g].clickable = true
check("勾了可點擊 ⇒ 不生效", not Cur.Configured(g))
p.bars[g].clickable = false
local ai = DB.AddCustom({ kind = "aura", spellID = 701, filter = "HELPFUL", placeholder = true, bar = g })
check("上面有光環格 ⇒ 不生效", not Cur.Configured(g))
DB.RemoveCustom(DB.CustomID(ai))
check("光環格拿掉 ⇒ 回來", Cur.Configured(g))
check("內建條開了也不算", (function()
    p.bars.utility.cursor.enabled = true
    local v = Cur.Configured("utility")
    p.bars.utility.cursor.enabled = false
    return not v
end)())

-- 排開：Bars 給 Layout 的設定表把它當不存在（Core/Bars.lua 的 AnchorCfg 同一個判準）
do
    local cfg = {
        essential = { anchor = false },
        [g] = { anchor = { to = "essential", point = "TOP", relPoint = "BOTTOM" } },
        other = { anchor = { to = g, point = "TOP", relPoint = "BOTTOM" } },
        third = { anchor = { to = "essential", point = "TOP", relPoint = "BOTTOM" } },
    }
    local function BarCfg(k) return cfg[k] end
    local function AnchorCfg(k) if Cur.Configured(k) then return nil end return BarCfg(k) end
    local keys = { "essential", g, "other", "third" }
    local function rank(k) if k == g then return 1 end if k == "third" then return 2 end return 3 end
    eq("沒排除時第三條貼在群組那一串的最外面", Lay.StackTarget("third", BarCfg, keys, rank), "other")
    eq("跟著游標的條自己不錨定", Lay.StackTarget(g, AnchorCfg, keys, rank), nil)
    eq("跟著游標的條不佔位：第三條直接貼核心", Lay.StackTarget("third", AnchorCfg, keys, rank), "essential")
    eq("錨著它的條當目標不存在", Lay.AnchorOf("other", AnchorCfg), nil)
end

-- OnUpdate 只在看得到時掛；每幀照游標貼，沒動不重貼
local cont = Frame()
containers[g] = cont
visAlpha[g] = 1
Cur.Refresh()
eq("看得到 ⇒ 掛上", Cur.ActiveCount(), 1)
check("在跟", Cur.IsActive(g))
check("DebugLine 說掛著", (Cur.DebugLine() or ""):find("掛著") ~= nil)
do
    Cur.Place(cont, g)
    local pt = cont.points[1]
    eq("Place：TOPLEFT", pt and pt[1], "TOPLEFT")
    eq("Place：貼 UIParent 的 BOTTOMLEFT", pt and pt[3], "BOTTOMLEFT")
    eq("Place：x ＝ 游標/縮放＋位移", pt and pt[4], 500 / 2 + 10)
    eq("Place：y", pt and pt[5], 400 / 2 - 10)
    -- 每幀：游標沒動不重貼、動了照游標貼
    local drv = Driver()
    check("driver 掛著 OnUpdate", drv ~= nil)
    local calls = cont.setPointCalls
    drv.scripts.OnUpdate(drv, 0.016)
    eq("游標沒動（Place 剛貼過）不重貼", cont.setPointCalls, calls)
    state.cx, state.cy = 600, 300
    drv.scripts.OnUpdate(drv, 0.016)
    eq("游標動了重貼一次", cont.setPointCalls, calls + 1)
    pt = cont.points[1]
    eq("跟著游標 x", pt and pt[4], 600 / 2 + 10)
    eq("跟著游標 y", pt and pt[5], 300 / 2 - 10)
    -- 戰鬥中變成保護框（不該發生）：這條停下來、不寫
    state.combat = true
    protected[cont] = true
    state.cx = 700
    drv.scripts.OnUpdate(drv, 0.016)
    eq("戰鬥中保護框：不寫", cont.setPointCalls, calls + 1)
    eq("戰鬥中保護框：停下來", Cur.ActiveCount(), 0)
    eq("沒有要跟的了：OnUpdate 卸掉", drv.scripts.OnUpdate, nil)
    state.combat = false
    protected[cont] = nil
    notes = {}
    Cur.Refresh()
    eq("脫戰重判又跟", Cur.ActiveCount(), 1)
    state.cx, state.cy = 500, 400
end
visAlpha[g] = 0
Cur.Refresh()
eq("看不到（alpha 0）⇒ 卸掉", Cur.ActiveCount(), 0)
check("DebugLine 說卸了", (Cur.DebugLine() or ""):find("卸了") ~= nil)
visAlpha[g] = 0.5
protected[cont] = true
Cur.Refresh()
eq("保護框 ⇒ 不動", Cur.ActiveCount(), 0)
eq("保護框記一筆 Diag", notes[#notes] and notes[#notes][1], "cursor")
local nNotes = #notes
Cur.Refresh()
eq("同一條只記一次", #notes, nNotes)
protected[cont] = nil
Cur.Refresh()
eq("保護解除 ⇒ 又跟", Cur.ActiveCount(), 1)
ns.EditMode.active = true
Cur.Refresh()
eq("編輯模式 ⇒ 卸掉", Cur.ActiveCount(), 0)
ns.EditMode.active = false
p.bars[g].cursor.enabled = false
Cur.Refresh()
eq("關掉 ⇒ 卸掉", Cur.ActiveCount(), 0)
eq("DebugLine 沒有設定的條 ⇒ nil", Cur.DebugLine(), nil)
-- Visibility 套 alpha 時只理會設了的條
p.bars[g].cursor.enabled = true
Cur.OnAlpha("essential")
eq("別條的 alpha 不觸發", Cur.ActiveCount(), 0)
Cur.OnAlpha(g)
eq("設了的條觸發重判", Cur.ActiveCount(), 1)
p.bars[g].cursor.enabled = false
Cur.Refresh()

------------------------------------------------------------
-- 4. 語音播報
------------------------------------------------------------
local ST = S.Logic.SpeakText
eq("true ⇒ 法術名", ST(true, "聖光術"), "聖光術")
eq("字串 ⇒ 原文", ST("快開", "聖光術"), "快開")
eq("空字串 ⇒ 法術名", ST("", "聖光術"), "聖光術")
eq("只有空白 ⇒ 法術名", ST("   ", "聖光術"), "聖光術")
eq("頭尾空白去掉", ST("  開盾  ", "x"), "開盾")
eq("false ⇒ 不念", ST(false, "聖光術"), nil)
eq("nil ⇒ 不念", ST(nil, "聖光術"), nil)
eq("數字 ⇒ 不念", ST(5, "聖光術"), nil)
eq("true、名字讀不到 ⇒ 不念", ST(true, nil), nil)
eq("空字串、名字是空的 ⇒ 不念", ST("", ""), nil)
eq("語音覆寫分組：音效節", DB.OVERRIDE_GROUP.readySpeak, "sound")
eq("gainSpeak 分組", DB.OVERRIDE_GROUP.gainSpeak, "sound")
eq("沒設 ⇒ false", ns.SpellSetting("essential", 11, "readySpeak"), false)

S.Init()                                  -- 進場：靜音到 102
state.now = 200
check("API 在", S.CanSpeak())
local rec = { cooldownID = 11, claimKey = "essential" }
check("沒設 ⇒ 不要探針", not S.WantsReady(rec))
DB.SetOverride(11, "readySpeak", true)
check("只設語音也要探針", S.WantsReady(rec))
S.OnReady(rec)
eq("就緒念了", #spoken, 1)
local call = spoken[1] or {}
eq("voiceID 照 TTS 設定（Standard）", call[1], 7)
eq("念法術名（目錄的名字）", call[2], "法術1100")
eq("語速照設定", call[3], 2)
eq("音量照設定", call[4], 80)
eq("overlap false", call[5], false)
S.OnReady(rec)
eq("同一格 1.5 秒內不重複", #spoken, 1)
state.now = 202
DB.SetOverride(11, "readySpeak", "  好了 ")
S.OnReady(rec)
eq("念自訂的字", spoken[#spoken] and spoken[#spoken][2], "好了")
p.theme.sound.enabled = false
state.now = 210
S.OnReady(rec)
eq("總開關關掉不念", #spoken, 2)
check("總開關關掉不要探針", not S.WantsReady(rec))
check("試聽不看總開關", S.PreviewSpeak("測試"))
eq("試聽念了", spoken[#spoken] and spoken[#spoken][2], "測試")
p.theme.sound.enabled = true
-- 增益 item 的出現／消失：跟音效同一個批次
DB.SetOverride(31, "gainSpeak", true)
local brec = { barKey = "buffs", cooldownID = 31 }
state.now = 300
local n0 = #spoken
S.PushAura(brec, "gain")
Flush()
eq("出現念了", #spoken, n0 + 1)
eq("念增益的名字", spoken[#spoken] and spoken[#spoken][2], "法術3100")
S.PushAura(brec, "lose"); S.PushAura(brec, "gain")
Flush()
eq("消失又出現抵消不念", #spoken, n0 + 1)
state.now = 305
S.PushAura(brec, "lose")
Flush()
eq("只設了出現：消失不念", #spoken, n0 + 1)
-- API 不在 ⇒ 什麼都不做
local saved = env.C_VoiceChat
env.C_VoiceChat = nil
check("API 不在 ⇒ CanSpeak 假", not S.CanSpeak())
check("API 不在 ⇒ 只設語音不要探針", not S.WantsReady(rec))
check("API 不在 ⇒ 試聽回 false", not S.PreviewSpeak("x"))
env.C_VoiceChat = saved
-- 語音 ID 讀不到（秘密／nil）⇒ 不念、不拋錯
local savedT = env.C_TTSSettings
env.C_TTSSettings = { GetVoiceOptionID = function() return Secret() end }
check("voiceID 讀不到 ⇒ 不念", not S.PreviewSpeak("x"))
env.C_TTSSettings = savedT
-- SpeakText 拋錯（被擋）⇒ pcall 接住
env.C_VoiceChat = { SpeakText = function() error("blocked") end }
check("SpeakText 拋錯 ⇒ 回 false、不往外拋", not S.PreviewSpeak("x"))
env.C_VoiceChat = saved
check("DebugLine 是字串", type(S.DebugLine()) == "string")

------------------------------------------------------------
-- 5. 長條火花
------------------------------------------------------------
eq("增益長條預設不顯示火花", p.bars.buffbars.bar.spark, false)
eq("新長條群組預設不顯示", DB.NewBarTable("bars", "x").bar.spark, false)
do
    local a = D.Resolve("buffbars", true).sig
    p.bars.buffbars.bar.spark = true
    local b = D.Resolve("buffbars", true).sig
    check("火花進條層簽章", a ~= b)
    p.bars.buffbars.bar.spark = false
end

------------------------------------------------------------
-- 6. 增益持續時間的倒數換色
------------------------------------------------------------
do
    local YELLOW = { r = 1, g = 0.85, b = 0.1, a = 1 }
    local MINE = { r = 0.2, g = 0.4, b = 1, a = 1 }
    -- 三態 × 條層開關
    eq("跟隨＋條開 ⇒ 條的顏色", D.DurationColorOf(nil, true, YELLOW), YELLOW)
    eq("跟隨＋條關 ⇒ 不換色", D.DurationColorOf(nil, false, YELLOW), nil)
    eq("不換色＋條開 ⇒ 不換色", D.DurationColorOf(false, true, YELLOW), nil)
    eq("不換色＋條關 ⇒ 不換色", D.DurationColorOf(false, false, YELLOW), nil)
    eq("自訂＋條開 ⇒ 自訂色", D.DurationColorOf(MINE, true, YELLOW), MINE)
    eq("自訂＋條關 ⇒ 照樣自訂色（覆寫就是覆寫）", D.DurationColorOf(MINE, false, YELLOW), MINE)
    eq("條開但沒有顏色 ⇒ 不換色", D.DurationColorOf(nil, true, nil), nil)
    eq("壞值當跟隨", D.DurationColorOf(true, true, YELLOW), YELLOW)

    -- 預設值與覆寫登記
    local ct = p.theme.cooldownText
    eq("主題預設開", ct.colorDuration, true)
    near("主題預設黃 r", ct.durationColor.r, 1); near("g", ct.durationColor.g, 0.85); near("b", ct.durationColor.b, 0.1)
    eq("條讀得到（繼承主題）", ns.Setting("essential", "cooldownText.colorDuration"), true)
    eq("SPELL_FALLBACK durationColor", DB.SPELL_FALLBACK.durationColor, "cooldownText.durationColor")
    eq("覆寫分組：文字節", DB.OVERRIDE_GROUP.durationColor, "text")

    -- SpellOverride 分得出跟隨；SpellSetting 沒覆寫時回條的顏色
    eq("沒覆寫 ⇒ nil", ns.SpellOverride(11, "durationColor"), nil)
    eq("SpellSetting 沒覆寫回條的顏色", ns.SpellSetting("essential", 11, "durationColor"), ct.durationColor)
    eq("SpellStyle 跟隨 ⇒ nil", D.SpellStyle("essential", 11).durationColor, nil)
    DB.SetOverride(11, "durationColor", false)
    eq("覆寫成不換色", ns.SpellOverride(11, "durationColor"), false)
    eq("SpellStyle 保留 false（不被 or 吃掉）", D.SpellStyle("essential", 11).durationColor, false)
    eq("SpellSetting 照樣回 false", ns.SpellSetting("essential", 11, "durationColor"), false)
    DB.SetOverride(11, "durationColor", MINE)
    eq("覆寫成色表", ns.SpellOverride(11, "durationColor"), MINE)
    DB.SetOverride(11, "durationColor", nil)
    eq("清掉回到跟隨", ns.SpellOverride(11, "durationColor"), nil)

    -- 兩段顏色（Decorate.Apply 寫進 rec.style 的那兩張）
    local cdc, durc = D.PhaseColors({ color = { r = 1, g = 1, b = 1 }, colorDuration = true, durationColor = YELLOW }, nil)
    near("冷卻段＝倒數原色", cdc[1], 1); near("a 補 1", cdc[4], 1)
    near("增益段＝黃 g", durc and durc[2], 0.85)
    cdc, durc = D.PhaseColors({ colorDuration = false, durationColor = YELLOW }, nil)
    eq("條關 ⇒ 增益段 nil", durc, nil)
    near("沒有原色 ⇒ 白", cdc[1], 1)
    cdc, durc = D.PhaseColors({ colorDuration = false, durationColor = YELLOW }, MINE)
    near("條關＋自訂 ⇒ 自訂色 b", durc and durc[3], 1)
    cdc, durc = D.PhaseColors({ colorDuration = true, durationColor = YELLOW }, false)
    eq("條開＋不換色 ⇒ nil", durc, nil)
    cdc, durc = D.PhaseColors(nil, nil)
    eq("沒有 cooldownText 不炸、不換色", durc, nil)

    -- 覆寫進簽章
    local st = D.Resolve("essential", true)
    local base = { borderColor = nil, durationColor = nil }
    local a = D.Signature(st, 11, base, 30, 30)
    local b = D.Signature(st, 11, { durationColor = false }, 30, 30)
    local c = D.Signature(st, 11, { durationColor = MINE }, 30, 30)
    check("不換色進簽章", a ~= b)
    check("自訂色進簽章", a ~= c and b ~= c)
    -- 條層開關進條層簽章
    local s1 = D.Resolve("essential", true).sig
    ct.colorDuration = false
    local s2 = D.Resolve("essential", true).sig
    ct.colorDuration = true
    check("條層開關進簽章", s1 ~= s2)

    -- 掛勾：SetUseAuraDisplayTime 只記旗標，SetCooldown 換色
    Load("Core/Text.lua")
    local fs = { colors = {} }
    function fs:SetTextColor(r, g, b, a2) self.colors[#self.colors + 1] = { r, g, b, a2 } end
    local getterFlag = true
    local cd = {
        SetCooldown = function() end, Clear = function() end,
        SetUseAuraDisplayTime = function() end,
        GetUseAuraDisplayTime = function() return getterFlag end,
        GetCountdownFontString = function() return fs end,
    }
    local item = { Cooldown = cd }
    local rec = { barKey = "essential", cooldownID = 11 }
    ns.Viewers.frames[item] = rec
    local h0 = #hooks
    D.HookItem(item, rec)
    local onFlag, onSet
    for i = h0 + 1, #hooks do
        if hooks[i].t == cd and hooks[i].name == "SetUseAuraDisplayTime" then onFlag = hooks[i].fn end
        if hooks[i].t == cd and hooks[i].name == "SetCooldown" then onSet = hooks[i].fn end
    end
    check("掛了 SetUseAuraDisplayTime", onFlag ~= nil)
    eq("掛上時先問 getter（增益還在）", rec.auraTime, true)
    rec.style = { cdColor = { 1, 1, 1, 1 }, durColor = { 1, 0.85, 0.1, 1 } }
    onSet(cd, 1, 2, 1)
    local last2 = fs.colors[#fs.colors]
    near("增益那一段 ⇒ 黃", last2 and last2[2], 0.85)
    onFlag(cd, false)
    eq("旗標 false", rec.auraTime, false)
    onSet(cd, 1, 2, 1)
    last2 = fs.colors[#fs.colors]
    near("冷卻那一段 ⇒ 原色", last2 and last2[2], 1)
    onFlag(cd, true)
    eq("旗標 true", rec.auraTime, true)
    local ok = pcall(onFlag, cd, Secret())
    check("秘密旗標不報錯", ok)
    eq("秘密旗標當 false", rec.auraTime, false)
    onFlag(cd, true)
    rec.style.durColor = nil
    onSet(cd, 1, 2, 1)
    last2 = fs.colors[#fs.colors]
    near("這格不換色（durColor nil）⇒ 原色", last2 and last2[2], 1)
    rec.style.cdColor = nil
    local n0 = #fs.colors
    onSet(cd, 1, 2, 1)
    eq("沒有 cdColor（自訂框／增益類）⇒ 不動", #fs.colors, n0)
    -- 不是我們的 item 不理
    local stranger = { SetCooldown = function() end }
    check("陌生的 Cooldown 不報錯", pcall(onFlag, stranger, true))
    -- getter 回秘密值：掛上時當 false
    getterFlag = Secret()
    local cd2 = {
        SetCooldown = function() end, SetUseAuraDisplayTime = function() end,
        GetUseAuraDisplayTime = function() return getterFlag end,
    }
    local rec2 = { barKey = "utility", cooldownID = 21 }
    local item2 = { Cooldown = cd2 }
    ns.Viewers.frames[item2] = rec2
    D.HookItem(item2, rec2)
    eq("getter 秘密 ⇒ false", rec2.auraTime, false)
    -- 自訂框不掛
    local cd3 = { SetCooldown = function() end, SetUseAuraDisplayTime = function() end }
    local rec3 = { custom = true }
    local h1 = #hooks
    D.HookItem({ Cooldown = cd3 }, rec3)
    local hooked3 = false
    for i = h1 + 1, #hooks do if hooks[i].t == cd3 then hooked3 = true end end
    check("自訂框不掛 Cooldown 的後掛勾", not hooked3)
    ns.Viewers.frames[item], ns.Viewers.frames[item2] = nil, nil

    -- 預覽格：ApplyPreviewIcon 用 cell.durColor
    ns.Media = ns.Media or {}
    ns.Media.SetPixelFont = ns.Media.SetPixelFont or function() end
    ns.Media.ElementFont = ns.Media.ElementFont or function() return nil end
    local function FS()
        local f = { colors = {} }
        function f:SetTextColor(r, g, b, a2) self.colors[#self.colors + 1] = { r, g, b, a2 } end
        function f:ClearAllPoints() end
        function f:SetPoint() end
        function f:SetAlpha(v) self.alpha = v end
        return f
    end
    local cell = { cdText = FS(), onCD = true, durColor = YELLOW }
    ns.Text.ApplyPreviewIcon(cell, { cooldownText = { color = { r = 1, g = 1, b = 1 } } }, {})
    near("預覽增益段 ⇒ 黃", cell.cdText.colors[1][2], 0.85)
    cell.durColor = nil
    ns.Text.ApplyPreviewIcon(cell, { cooldownText = { color = { r = 1, g = 1, b = 1 } } }, {})
    near("預覽其他格 ⇒ 原色", cell.cdText.colors[2][2], 1)
end

print(("Extras_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
