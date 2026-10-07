------------------------------------------------------------
-- Core/DB.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/DB_test.lua
--   （lua5.1／luajit／5.2 以後都可以；從哪個工作目錄跑都行）
--
-- 做法：把 DB.lua 載進一張**自己的環境表**，WoW API 全部在那張表裡 stub 掉。
-- 這支測試本身一個全域都不寫（提交前檢查會掃全域寫入），DB.lua 寫的
-- MiliUI_CooldownManager_DB 也只落在環境表裡。
--
-- 覆蓋：預設值（套組現值）、三層繼承的每一種路徑、逐法術覆寫、設定檔建立／複製／
-- 切換／刪除、戰鬥中切換延後、專精自動切換、遷移鏈與版本號、合併不覆蓋使用者值、
-- 可點擊的預設值與判準（DB.BarClickable）、圓環顯示的預設值／舊存檔補值／判準（DB.BarIsRings）／填色覆寫。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local DB_PATH = here .. "/../Core/DB.lua"

------------------------------------------------------------
-- 迷你斷言
------------------------------------------------------------
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

------------------------------------------------------------
-- WoW API stub（全部放在環境表裡）
------------------------------------------------------------
local state = {
    combat = false, spec = 1, player = "米利", realm = "世界之樹",
}
local frames = {}

local env = setmetatable({}, { __index = _G })
env.UnitName = function() return state.player end
env.GetRealmName = function() return state.realm end
env.InCombatLockdown = function() return state.combat end
env.GetSpecialization = function() return state.spec end
env.GetSpecializationInfo = function(i) return 60 + i end      -- 假 specID：61、62…
env.CreateFrame = function()
    local f = { events = {}, scripts = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    frames[#frames + 1] = f
    return f
end

local fired = {}
local eventHandlers = {}
local ns = {
    playerClass = "PALADIN",
    Events = {
        Register = function(event, key, fn) eventHandlers[event] = fn end,
    },
    Fire = function(event, ...) fired[#fired + 1] = { event = event, ... } end,
    ReportError = function(err) print("ReportError: " .. tostring(err)) end,
}
function ns.RefreshSpec()
    ns.specIndex = state.spec
    ns.specID = 60 + state.spec
end

-- 把所有「正在等某個事件」的 stub 框的 OnEvent 叫一次
local function FireEvent(event)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
    end
end

local function LoadDB()
    local chunk, err
    if setfenv then                                   -- Lua 5.1／LuaJIT
        chunk, err = loadfile(DB_PATH)
        if chunk then setfenv(chunk, env) end
    else                                              -- Lua 5.2+
        chunk, err = loadfile(DB_PATH, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end

LoadDB()
local DB = ns.DB

------------------------------------------------------------
-- 1. 全新登入
------------------------------------------------------------
ns.RefreshSpec()
DB.Init()
local sv = env.MiliUI_CooldownManager_DB
check("SV 建立", type(sv) == "table")
eq("schemaVersion", sv.schemaVersion, ns.DB_VERSION)
eq("DB_VERSION", ns.DB_VERSION, 7)
check("MIGRATIONS 有版本 3", type(DB.MIGRATIONS[3]) == "function")
check("MIGRATIONS 有版本 4", type(DB.MIGRATIONS[4]) == "function")
check("MIGRATIONS 有版本 1", type(DB.MIGRATIONS[1]) == "function")
eq("預設設定檔名", ns.profileName, "Default")
eq("profileKeys 記下角色", sv.profileKeys["米利 - 世界之樹"], "Default")
eq("charClasses", sv.charClasses["米利 - 世界之樹"], "PALADIN")
eq("帳號層 optionsWindow.lastBar", sv.optionsWindow.lastBar, "essential")
eq("帳號層 minimap.hide", sv.minimap.hide, false)

------------------------------------------------------------
-- 2. 預設值＝套組現值
------------------------------------------------------------
local S = ns.Setting
eq("核心 寬", S("essential", "layout.size.w"), 46)
eq("核心 高", S("essential", "layout.size.h"), 40)
eq("輔助 寬", S("utility", "layout.size.w"), 26)
eq("輔助 高", S("utility", "layout.size.h"), 24)
eq("增益 寬", S("buffs", "layout.size.w"), 40)
eq("增益 高", S("buffs", "layout.size.h"), 36)
eq("間距", S("essential", "layout.spacing"), 1)
eq("每列上限", S("essential", "layout.maxPerRow"), 8)
eq("字型", S("essential", "font"), "提示訊息")
eq("描邊", S("essential", "outline"), "OUTLINE")
eq("觸發發光樣式", S("essential", "glow.proc.type"), "proc")
eq("就緒發光樣式", S("essential", "glow.ready.type"), "button")
eq("長條往上長", S("buffbars", "layout.grow"), "CENTER_UP")
eq("長條 kind", S("buffbars", "kind"), "bars")
eq("核心位置 y", S("essential", "pos.y"), -202)
eq("增益位置 y", S("buffs", "pos.y"), -149)
eq("增益圖示錨在核心技能上方（排開後在施法條外面）", S("buffs", "anchor.to"), "essential")
eq("增益圖示錨點", S("buffs", "anchor.relPoint"), "TOP")
eq("長條位置 point", S("buffbars", "pos.point"), "BOTTOM")
eq("長條位置 y", S("buffbars", "pos.y"), 524)
eq("輔助跟著核心（跟自訂格子同一邊，由排開決定先後）", S("utility", "anchor.to"), "essential")
eq("自訂格子錨在核心", DB.GetPath(ns.profile, "pips.anchor.to"), "essential")
eq("輔助錨點", S("utility", "anchor.relPoint"), "BOTTOM")
eq("核心沒有錨定", S("essential", "anchor"), false)
eq("第二列尺寸預設關", S("essential", "layout.row2Size"), false)
eq("增益預設往前補", S("buffs", "layout.emptyMode"), "collapse")
eq("核心預設往前補", S("essential", "layout.emptyMode"), "collapse")
eq("barOrder[4]", ns.profile.barOrder[4], "buffbars")

------------------------------------------------------------
-- 3. 三層繼承：theme → bars[key]
------------------------------------------------------------
local P = ns.profile
eq("跟隨時讀主題", S("essential", "cooldownText.size"), 16)
P.theme.cooldownText.size = 20
eq("改主題、跟隨的條跟著變", S("essential", "cooldownText.size"), 20)
eq("改主題、另一條也跟著變", S("utility", "cooldownText.size"), 20)
eq("barKey=nil 讀主題", S(nil, "cooldownText.size"), 20)
eq("barKey=theme 讀主題", S("theme", "cooldownText.size"), 20)

P.bars.essential.follow.text = false
eq("不跟隨但自己沒存值 → 退回主題", S("essential", "cooldownText.size"), 20)
P.bars.essential.text.cooldownText = { size = 24 }
eq("不跟隨且自己有值 → 讀自己", S("essential", "cooldownText.size"), 24)
eq("同一張子表沒存的格 → 退回主題", S("essential", "cooldownText.lowBelow"), 5)
eq("別條不受影響", S("utility", "cooldownText.size"), 20)
P.bars.essential.follow.text = true
eq("重新跟隨 → 自己存的值被忽略", S("essential", "cooldownText.size"), 20)
P.bars.essential.follow.text = false

P.bars.essential.text.font = "自己的字型"
eq("font 走 text 群", S("essential", "font"), "自己的字型")

-- border 跟著 follow.icon，存在 bars[k].icon.border
P.bars.utility.icon.border = { size = 2 }
eq("跟隨 icon 時忽略條的邊框", S("utility", "border.size"), 1)
P.bars.utility.follow.icon = false
eq("不跟隨 icon → 條的邊框", S("utility", "border.size"), 2)
eq("邊框顏色退回主題", S("utility", "border.color"), P.theme.border.color)
P.bars.utility.icon.zoom = 0.2
eq("icon.zoom 存在 bars[k].icon", S("utility", "icon.zoom"), 0.2)
eq("icon 其他格退回主題", S("utility", "icon.desaturateOnCooldown"), true)

-- pandemic 跟著 follow.glow，存在 bars[k].glow.pandemic
P.bars.buffs.follow.glow = false
P.bars.buffs.glow.pandemic = { bars = false }
eq("pandemic 走 glow 群、false 照樣傳回", S("buffs", "pandemic.bars"), false)
P.bars.buffs.glow.proc = { color = { r = 0, g = 1, b = 0, a = 1 } }
eq("glow.proc.color 讀條的", S("buffs", "glow.proc.color").g, 1)
eq("glow.proc.type 退回主題", S("buffs", "glow.proc.type"), "proc")

-- fade：false（不淡）不能被當成「沒值」
eq("fade.whenMounted 預設 false", S("buffbars", "fade.whenMounted"), false)
P.bars.buffbars.follow.fade = false
P.bars.buffbars.fade.keepWithTarget = false
eq("條把 keepWithTarget 設 false → false，不退回主題的 true", S("buffbars", "fade.keepWithTarget"), false)

-- 非主題欄位不繼承
eq("不存在的條", S("nope", "layout.size.w"), nil)
eq("不存在的路徑", S("essential", "layout.nothing.here"), nil)
eq("主題沒有的欄位不會從主題冒出來", S("essential", "visibility.group"), "any")

------------------------------------------------------------
-- 4. 逐法術覆寫
------------------------------------------------------------
local SS = ns.SpellSetting
eq("沒覆寫 → 條的邊框色（跟隨 → 主題）", SS("essential", 1234, "borderColor"), P.theme.border.color)
eq("沒覆寫 → 觸發發光開", SS("essential", 1234, "procGlow"), true)
eq("沒覆寫 → 就緒發光關", SS("essential", 1234, "readyGlow"), false)
eq("沒覆寫 → 固定預設", SS("essential", 1234, "hideCooldownText"), false)
eq("未知欄位", SS("essential", 1234, "nope"), nil)
eq("生效發光條層預設關 ⇒ 關", SS("buffs", 1234, "activeGlow"), false)
eq("各段文字字型預設跟隨通用字型", S("essential", "cooldownText.font"), "INHERIT")
eq("施法條字型預設跟隨", P.castbar and P.castbar.font, "INHERIT")
eq("資源條字型預設跟隨", P.resources and P.resources.textFont, "INHERIT")
eq("生效發光顏色沒設 ⇒ nil（用條層預設色）", SS("buffs", 1234, "activeGlowColor"), nil)
check("生效發光的開關與樣式在主題裡、預設關", type(P.theme.glow.active) == "table" and P.theme.glow.active.enabled == false)
P.bars.buffs.follow = P.bars.buffs.follow or {}
P.bars.buffs.follow.glow = false
P.bars.buffs.glow = P.bars.buffs.glow or {}
P.bars.buffs.glow.active = { enabled = true }
eq("條層生效發光開 ⇒ 逐法術沒覆寫時跟著開（跟觸發／就緒同一套）", SS("buffs", 1234, "activeGlow"), true)
P.bars.buffs.glow.active = nil
P.bars.buffs.follow.glow = nil

P.spells[ns.specID] = { overrides = { [1234] = { procGlow = false, borderColor = { r = 1, g = 0, b = 0, a = 1 } },
                                        ["c:1"] = { hideStackText = true } } }
eq("覆寫 false 照樣生效", SS("essential", 1234, "procGlow"), false)
eq("覆寫顏色", SS("essential", 1234, "borderColor").r, 1)
eq("沒覆寫的欄位仍退回條", SS("essential", 1234, "desaturate"), true)
eq("自訂項目鍵 c:1", SS("essential", "c:1", "hideStackText"), true)
eq("別的專精看不到", SS("essential", 1234, "procGlow", ns.specID + 1), true)
P.bars.utility.follow.glow = false
P.bars.utility.glow.ready = { enabled = true }
eq("條層就緒發光開 → 逐法術沒覆寫時跟著開", SS("utility", 999, "readyGlow"), true)
-- 單一法術小窗的「（跟隨…）」：條在那一節跟隨主題／用自己的值／沒有可跟隨的
eq("值從哪來：跟隨主題", DB.SpellFallbackSource("essential", "procGlow"), "theme")
eq("值從哪來：條關掉跟隨 → 這一條", DB.SpellFallbackSource("utility", "readyGlow"), "bar")
eq("值從哪來：邊框看 icon 那一節（utility 關了 icon 跟隨）", DB.SpellFallbackSource("utility", "borderColor"), "bar")
eq("值從哪來：essential 的邊框跟隨主題", DB.SpellFallbackSource("essential", "borderColor"), "theme")
eq("值從哪來：沒有條層值 → nil", DB.SpellFallbackSource("essential", "hideCooldownText"), nil)
eq("生效發光樣式沒設 ⇒ nil", SS("buffs", 1234, "activeGlowType"), nil)
eq("生效發光預設脫戰也亮", SS("buffs", 1234, "activeGlowOutOfCombat"), true)
eq("脫戰也亮算在 glow 那一組", DB.OVERRIDE_GROUP.activeGlowOutOfCombat, "glow")
eq("生效發光算在 glow 那一組（跟觸發／就緒同一套）", DB.OVERRIDE_GROUP.activeGlow, "glow")

------------------------------------------------------------
-- 5. 設定檔：建立／複製／切換／刪除
------------------------------------------------------------
check("建立", DB.CreateProfile("  PvP  "))
check("建立時修掉前後空白", sv.profiles["PvP"] ~= nil)
eq("撞名拒絕", select(2, DB.CreateProfile("PvP")), "exists")
eq("空名拒絕", select(2, DB.CreateProfile("   ")), "empty")
check("複製", DB.CopyProfile("Default", "Copy"))
check("複製是深拷貝", sv.profiles.Copy.theme ~= sv.profiles.Default.theme)
eq("複製帶著內容", sv.profiles.Copy.theme.cooldownText.size, 20)
eq("清單排序", table.concat(DB.ListProfiles(), ","), "Copy,Default,PvP")

fired = {}
check("切換", DB.SwitchProfile("PvP"))
eq("目前設定檔", ns.profileName, "PvP")
eq("切換後讀新那份（預設值）", S("essential", "cooldownText.size"), 16)
eq("廣播 ProfileChanged", fired[1] and fired[1].event, "ProfileChanged")
eq("profileKeys 更新", sv.profileKeys["米利 - 世界之樹"], "PvP")
eq("GetProfile()", DB.GetProfile(), sv.profiles.PvP)
eq("切到不存在的", DB.SwitchProfile("nope"), false)

-- 戰鬥中延後，脫戰才換
state.combat = true
DB.SwitchProfile("Copy")
eq("戰鬥中先不換", ns.profileName, "PvP")
state.combat = false
FireEvent("PLAYER_REGEN_ENABLED")
eq("脫戰補換", ns.profileName, "Copy")

-- 戰鬥中選了別的又改回目前這份：排隊的要取消
state.combat = true
DB.SwitchProfile("PvP")
DB.SwitchProfile("Copy")
state.combat = false
FireEvent("PLAYER_REGEN_ENABLED")
eq("改回原本的，排隊取消", ns.profileName, "Copy")

eq("預設那份不給刪", DB.DeleteProfile("Default"), false)
check("刪目前這份", DB.DeleteProfile("Copy"))
eq("刪掉目前這份 → 回預設", ns.profileName, "Default")
eq("指著它的角色改回預設", sv.profileKeys["米利 - 世界之樹"], "Default")

------------------------------------------------------------
-- 6. 專精自動切換
------------------------------------------------------------
eq("預設沒開", DB.IsSpecProfilesEnabled(), false)
check("綁專精 2", DB.SetSpecProfile(2, "PvP"))
eq("沒開時不生效", DB.ProfileForSpec(2), nil)
DB.SetSpecProfilesEnabled(true)
eq("開了之後查得到", DB.ProfileForSpec(2), "PvP")
eq("目前專精 1 沒綁，不動", ns.profileName, "Default")
state.spec = 2
eventHandlers.PLAYER_SPECIALIZATION_CHANGED()
eq("換到專精 2 自動切 PvP", ns.profileName, "PvP")
eq("specID 更新", ns.specID, 62)
state.spec = 1
eventHandlers.PLAYER_SPECIALIZATION_CHANGED()
eq("換回專精 1（沒綁）維持目前這份", ns.profileName, "PvP")
eq("綁不存在的設定檔拒絕", DB.SetSpecProfile(3, "nope"), false)
DB.DeleteProfile("PvP")
eq("刪掉被綁的設定檔 → 綁定清掉", sv.specProfiles["米利 - 世界之樹"][2], nil)
eq("刪掉被綁的設定檔 → 回預設", ns.profileName, "Default")

------------------------------------------------------------
-- 7. 重新登入：使用者值不被覆蓋、false 被尊重
------------------------------------------------------------
sv.profiles.Default.bars.utility.anchor = false
sv.profiles.Default.bars.essential.layout.size.w = 50
sv.profiles.Default.bars.essential.layout.spacing = nil        -- 缺值要補回
ns.profile, ns.profileName = nil, nil
DB.Init()
eq("使用者值保留", S("essential", "layout.size.w"), 50)
eq("缺值補回預設", S("essential", "layout.spacing"), 1)
eq("anchor = false 不被預設表蓋回來", S("utility", "anchor"), false)

------------------------------------------------------------
-- 8. 遷移鏈與版本號
------------------------------------------------------------
local calls = 0
local real = DB.MIGRATIONS[1]
local real2 = DB.MIGRATIONS[2]
local real3 = DB.MIGRATIONS[3]
local real4 = DB.MIGRATIONS[4]
local real5 = DB.MIGRATIONS[5]
local real6 = DB.MIGRATIONS[6]
local real7 = DB.MIGRATIONS[7]
DB.MIGRATIONS[1] = function() calls = calls + 1 end
DB.MIGRATIONS[2] = function() end
DB.MIGRATIONS[3] = function() end
DB.MIGRATIONS[4] = function() end
DB.MIGRATIONS[5] = function() end
DB.MIGRATIONS[6] = function() end
DB.MIGRATIONS[7] = function() end
DB.MigrateProfile({}, 0)
eq("從 0 補到最新：v1 跑一次", calls, 1)
DB.MigrateProfile({}, 1)
eq("已是 1 不再跑 v1", calls, 1)

calls = 0
sv.schemaVersion = 0
sv.schemaVersionSeen = nil
DB.Init()
eq("舊 SV：每份設定檔各跑一次", calls, 1)
eq("舊 SV：版本推到目前", sv.schemaVersion, ns.DB_VERSION)

calls = 0
sv.schemaVersion = 8
DB.Init()
eq("較新的 SV：版本壓回目前", sv.schemaVersion, ns.DB_VERSION)
eq("較新的 SV：記住看過第幾版", sv.schemaVersionSeen, 8)
eq("較新的 SV：不跑遷移", calls, 0)
DB.MIGRATIONS[1] = real
DB.MIGRATIONS[2] = real2
DB.MIGRATIONS[3] = real3
DB.MIGRATIONS[4] = real4
DB.MIGRATIONS[5] = real5
DB.MIGRATIONS[6] = real6
DB.MIGRATIONS[7] = real7

-- v6：長條的 bar.stackSize 拿掉；跟生效字級一樣就刪，不一樣就搬到條自己的層數字級＋不跟隨全域文字
do
    local p = {
        theme = { stackText = { size = 14 } },
        bars = {
            same   = { bar = { stackSize = 14 } },
            diff   = { bar = { stackSize = 20 } },
            own    = { bar = { stackSize = 20 }, follow = { text = false }, text = { stackText = { size = 9 } } },
            ownEq  = { bar = { stackSize = 9 },  follow = { text = false }, text = { stackText = { size = 9 } } },
            none   = { bar = { height = 20 } },
        },
    }
    DB.MIGRATIONS[6](p)
    eq("v6：跟主題一樣 ⇒ 刪", p.bars.same.bar.stackSize, nil)
    eq("v6：跟主題一樣 ⇒ 照舊跟隨", p.bars.same.follow, nil)
    eq("v6：不一樣 ⇒ 搬到條自己的層數字級", p.bars.diff.text.stackText.size, 20)
    eq("v6：不一樣 ⇒ 不跟隨全域文字", p.bars.diff.follow.text, false)
    eq("v6：不一樣 ⇒ stackSize 刪掉", p.bars.diff.bar.stackSize, nil)
    eq("v6：條自己已經有層數字級 ⇒ 照舊", p.bars.own.text.stackText.size, 9)
    eq("v6：條自己已經有 ⇒ stackSize 刪掉", p.bars.own.bar.stackSize, nil)
    eq("v6：一樣 ⇒ 照舊", p.bars.ownEq.text.stackText.size, 9)
    eq("v6：沒有 stackSize 的不動", p.bars.none.follow, nil)
    DB.MIGRATIONS[6](p)
    eq("v6：重跑不再改", p.bars.diff.text.stackText.size, 20)
end

-- v2：施法條材質的預設改成暴雪施法條（值閘：舊預設或沒存才換）
do
    local function mig(tex)
        local p = { castbar = { texture = tex } }
        DB.MigrateProfile(p, 1)
        return p.castbar.texture
    end
    eq("v2：舊預設 solid → blizzard", mig("solid"), "blizzard")
    eq("v2：沒存 → blizzard", mig(nil), "blizzard")
    eq("v2：玩家選過的不碰", mig("TukTex"), "TukTex")
    local p = {}
    DB.MigrateProfile(p, 1)
    eq("v2：沒有施法條表不報錯", p.castbar, nil)
    eq("新設定檔：施法條預設暴雪材質", DB.BuildDefaults().profile.castbar.texture, "blizzard")
end

-- v3：開關分專精。專精資料在 Modules/Resources.lua（這支測試沒載）⇒ 沒有 ns.Resources 時什麼都不動、不報錯
-- （有載的情況在 Resources_test.lua 的「分專精開關」）
do
    local p = { resources = { rows = { Mana = true, Fury = false } } }
    DB.MigrateProfile(p, 2)
    eq("v3：沒有資源模組 ⇒ 平面的鍵留著", p.resources.rows.Mana, true)
    local q = {}
    DB.MigrateProfile(q, 2)
    eq("v3：沒有資源條表不報錯", q.resources, nil)
    local d = DB.BuildDefaults().profile.resources
    check("新設定檔：開關是空表、醉仙緩勁 3／4 段預設關、氣漩武器不摺、秘法靈魂印秒數",
        type(d.rows) == "table" and next(d.rows) == nil and d.staggerTier3Enabled == false and d.staggerTier4Enabled == false
        and d.staggerTier3At == 90 and d.staggerTier4At == 150 and d.maelstromFold == false and d.arcaneSoulText == "seconds")
end

------------------------------------------------------------
-- 9. 其他
------------------------------------------------------------
eq("FillReversed rtl", ns.FillReversed({ fillDirection = "rtl" }), true)
eq("FillReversed 缺鍵", ns.FillReversed({}), false)
eq("FillReversed nil", ns.FillReversed(nil), false)
DB.ResetProfile()
eq("ResetProfile 回預設", S("essential", "layout.size.w"), 46)
eq("ResetProfile 不換表", ns.profile, sv.profiles.Default)

------------------------------------------------------------
-- 10. 可點擊（clickable）：預設 false、只有自訂圖示群組算數
------------------------------------------------------------
eq("內建條 clickable 預設 false", ns.profile.bars.essential.clickable, false)
eq("增益長條 clickable 預設 false", ns.profile.bars.buffbars.clickable, false)
eq("NewBarTable 圖示群組 clickable false", DB.NewBarTable("icons", "x").clickable, false)
eq("NewBarTable 長條群組 clickable false", DB.NewBarTable("bars", "x").clickable, false)
eq("DefaultFor 自訂群組的 clickable", DB.DefaultFor("bar", "nope", "clickable"), false)
do
    local gi = DB.CreateBar("icons", "點我")
    local gb = DB.CreateBar("bars", "長條")
    eq("新圖示群組：預設不可點擊", DB.BarClickable(gi), false)
    ns.profile.bars[gi].clickable = true
    eq("自訂圖示群組勾了：可點擊", DB.BarClickable(gi), true)
    ns.profile.bars[gi].clickable = nil
    eq("nil 當 false（不做遷移）", DB.BarClickable(gi), false)
    ns.profile.bars[gi].clickable = "yes"
    eq("不是 true 就不算", DB.BarClickable(gi), false)
    ns.profile.bars[gb].clickable = true
    eq("長條群組勾了也不算", DB.BarClickable(gb), false)
    ns.profile.bars.essential.clickable = true
    eq("內建條勾了也不算", DB.BarClickable("essential"), false)
    ns.profile.bars.essential.clickable = false
    eq("不存在的條", DB.BarClickable("g999"), false)
    eq("nil key", DB.BarClickable(nil), false)
    DB.DeleteBar(gi)
    DB.DeleteBar(gb)
end

------------------------------------------------------------
-- 10b. 格數上限＋溢出（layout.maxIcons／overflowTo）：預設、刪掉接收條時清掉指向它的目標
------------------------------------------------------------
do
    eq("內建條 maxIcons 預設 0", ns.profile.bars.essential.layout.maxIcons, 0)
    eq("內建條 overflowTo 預設 false", ns.profile.bars.utility.layout.overflowTo, false)
    eq("NewBarTable 圖示群組 maxIcons 0", DB.NewBarTable("icons", "x").layout.maxIcons, 0)
    eq("DefaultFor 自訂群組的 overflowTo", DB.DefaultFor("bar", "nope", "layout.overflowTo"), false)
    local g = DB.CreateBar("icons", "接收")
    ns.profile.bars.essential.layout.maxIcons = 4
    ns.profile.bars.essential.layout.overflowTo = g
    ns.profile.bars.utility.layout.overflowTo = "buffs"
    DB.DeleteBar(g)
    eq("刪掉接收條 ⇒ 指向它的目標清掉", ns.profile.bars.essential.layout.overflowTo, false)
    eq("刪掉接收條 ⇒ 上限留著（不成立＝不限）", ns.profile.bars.essential.layout.maxIcons, 4)
    eq("指向別條的不動", ns.profile.bars.utility.layout.overflowTo, "buffs")
    ns.profile.bars.essential.layout.maxIcons = 0
    ns.profile.bars.utility.layout.overflowTo = false
end

------------------------------------------------------------
-- 11. 冷卻狀態效果（icon.cdState／cdStateAlpha）：預設、三層繼承、覆寫分組、舊存檔補預設
------------------------------------------------------------
do
    local d = DB.BuildDefaults().profile.theme.icon
    eq("預設冷卻狀態 none", d.cdState, "none")
    eq("預設變暗透明度 0.4", d.cdStateAlpha, 0.4)
    eq("SPELL_FALLBACK cdState", DB.SPELL_FALLBACK.cdState, "icon.cdState")
    eq("SPELL_FALLBACK cdStateAlpha", DB.SPELL_FALLBACK.cdStateAlpha, "icon.cdStateAlpha")
    eq("覆寫分組 cdState ＝ icon", DB.OVERRIDE_GROUP.cdState, "icon")
    eq("覆寫分組 cdStateAlpha ＝ icon", DB.OVERRIDE_GROUP.cdStateAlpha, "icon")
    local P2 = ns.profile
    P2.bars.essential.follow.icon = true
    eq("沒覆寫、條跟隨 ⇒ 主題的 none", SS("essential", 4321, "cdState"), "none")
    P2.theme.icon.cdState = "dim"
    eq("改主題 ⇒ 跟著變", SS("essential", 4321, "cdState"), "dim")
    P2.bars.essential.follow.icon = false
    P2.bars.essential.icon.cdState = "hideOnCD"
    eq("條不跟隨且有值 ⇒ 條的", SS("essential", 4321, "cdState"), "hideOnCD")
    eq("條沒存透明度 ⇒ 退回主題", SS("essential", 4321, "cdStateAlpha"), 0.4)
    eq("值從哪來：條的 icon 節", DB.SpellFallbackSource("essential", "cdState"), "bar")
    P2.spells[ns.specID] = P2.spells[ns.specID] or {}
    P2.spells[ns.specID].overrides = P2.spells[ns.specID].overrides or {}
    P2.spells[ns.specID].overrides[4321] = { cdState = "hideReady" }
    eq("逐法術覆寫優先", SS("essential", 4321, "cdState"), "hideReady")
    eq("別的法術照條", SS("essential", 4322, "cdState"), "hideOnCD")
    eq("覆寫數算在 icon 那一組", DB.CountOverrides({ 4321 }, "icon"), 1)
    eq("覆寫數不算在 glow 那一組", DB.CountOverrides({ 4321 }, "glow"), 0)
    P2.spells[ns.specID].overrides[4321] = nil
    P2.bars.essential.icon.cdState = nil
    P2.bars.essential.follow.icon = true
    -- 舊存檔（1.0.7）沒有這兩欄：重新登入合併預設值之後是 none／0.4（行為不變），不動 DB_VERSION
    P2.theme.icon.cdState = nil
    P2.theme.icon.cdStateAlpha = nil
    DB.Init()
    eq("舊存檔補上 none", ns.profile.theme.icon.cdState, "none")
    eq("舊存檔補上 0.4", ns.profile.theme.icon.cdStateAlpha, 0.4)
    eq("DB_VERSION 沒動（這一項不遷移；5 是冷卻低秒變色開關、6 是長條層數字級、7 是增益不在時）", ns.DB_VERSION, 7)
end

------------------------------------------------------------
-- 12. 複製自訂項目到其他專精（CopyCustomEntry）、職業專精清單（ClassSpecs）
------------------------------------------------------------
do
    local DB = ns.DB
    local P3 = ns.profile
    local cur = ns.specID
    local other, third = cur + 1, cur + 2
    P3.spells = P3.spells or {}
    P3.spells[cur] = nil
    P3.spells[other] = nil
    P3.spells[third] = nil
    local iPot = DB.AddCustom({ kind = "item", itemID = 241308, alts = { 241309 }, bar = "essential" })
    local iLust = DB.AddCustom({ kind = "aura", spellID = 2825, spellIDs = { 32182 }, filter = "HELPFUL", placeholder = true, bar = "buffs" })
    local iSpell = DB.AddCustom({ kind = "spell", spellID = 20594, bar = "essential" })
    local sp = DB.SpecSpells(true)
    sp.overrides["c:" .. iLust] = { gainSound = "Ding", activeGlowColor = { r = 1, g = 0, b = 0, a = 1 } }
    sp.overrides[11] = { procGlow = false }

    eq("目標專精還沒有 spells 表", P3.spells[other], nil)
    local n = DB.CopyCustomEntry("c:" .. iLust, other)
    eq("複製到沒有 spells 表的專精 → 第 1 筆", n, 1)
    local copied = P3.spells[other] and P3.spells[other].custom and P3.spells[other].custom[1]
    eq("複製過去的種類", copied and copied.kind, "aura")
    eq("複製過去的主 ID", copied and copied.spellID, 2825)
    eq("多法術跟著過去", copied and copied.spellIDs and copied.spellIDs[1], 32182)
    eq("bar 照抄", copied and copied.bar, "buffs")
    check("是深複製（不是同一張表）", copied ~= DB.CustomEntry("c:" .. iLust))
    check("spellIDs 也是深複製", copied and copied.spellIDs ~= DB.CustomEntry("c:" .. iLust).spellIDs)
    local oc = P3.spells[other].overrides and P3.spells[other].overrides["c:1"]
    eq("覆寫跟著到新 id", oc and oc.gainSound, "Ding")
    check("覆寫也是深複製", oc and oc.activeGlowColor ~= sp.overrides["c:" .. iLust].activeGlowColor)
    eq("暴雪法術的覆寫不跟著過去", P3.spells[other].overrides[11], nil)

    eq("目標已有同種類同主 ID ⇒ false", DB.CopyCustomEntry("c:" .. iLust, other), false)
    eq("已有時目標清單不動", #P3.spells[other].custom, 1)

    eq("沒有覆寫的那筆 → 第 2 筆", DB.CopyCustomEntry("c:" .. iPot, other), 2)
    eq("沒有覆寫就不建", P3.spells[other].overrides["c:2"], nil)
    eq("替代品跟著過去", P3.spells[other].custom[2].alts[1], 241309)
    eq("目標有 spells 表、沒 custom 時照樣建", DB.CopyCustomEntry("c:" .. iSpell, third), 1)
    eq("複製到自己這個專精 ⇒ false", DB.CopyCustomEntry("c:" .. iSpell, cur), false)
    eq("不存在的 id ⇒ false", DB.CopyCustomEntry("c:99", other), false)
    eq("沒給目標 ⇒ false", DB.CopyCustomEntry("c:" .. iSpell, nil), false)
    eq("目前專精的清單沒被動到", #DB.CustomList(false), 3)
    eq("FindCustomLike 看得到複製過去的", DB.FindCustomLike(DB.CustomEntry("c:" .. iPot), other), 2)
    eq("FindCustomLike 別的專精沒有", DB.FindCustomLike(DB.CustomEntry("c:" .. iPot), third), nil)

    -- ClassSpecs：API 不在 ⇒ 空表；在 ⇒ { id, name, icon }
    env.GetNumSpecializations = nil
    eq("ClassSpecs：API 不在 ⇒ 空表", #DB.ClassSpecs(), 0)
    env.GetNumSpecializations = function() return 3 end
    local savedInfo = env.GetSpecializationInfo
    env.GetSpecializationInfo = function(i)
        if i == 2 then error("boom") end
        return 60 + i, "專精" .. i, "", 1000 + i
    end
    local specs = DB.ClassSpecs()
    eq("ClassSpecs：拋錯的那個跳過", #specs, 2)
    eq("ClassSpecs：id", specs[1] and specs[1].id, 61)
    eq("ClassSpecs：name", specs[1] and specs[1].name, "專精1")
    eq("ClassSpecs：icon", specs[2] and specs[2].icon, 1003)
    env.GetSpecializationInfo = savedInfo
    env.GetNumSpecializations = nil
    P3.spells[cur], P3.spells[other], P3.spells[third] = nil, nil, nil
end

------------------------------------------------------------
-- 13. 層數門檻（stackGlow／stackColors）：固定預設 false、覆寫自成 "stack" 一組（清發光覆寫不清它）
------------------------------------------------------------
do
    local DB = ns.DB
    local SS2 = ns.SpellSetting
    eq("SPELL_CONST stackGlow ＝ false", DB.SPELL_CONST.stackGlow, false)
    eq("SPELL_CONST stackColors ＝ false", DB.SPELL_CONST.stackColors, false)
    eq("沒覆寫 ⇒ 層數發光關", SS2("buffs", 5555, "stackGlow"), false)
    eq("沒覆寫 ⇒ 層數換色關", SS2("buffbars", 5555, "stackColors"), false)
    eq("層數發光樣式沒設 ⇒ nil", SS2("buffs", 5555, "stackGlowType"), nil)
    eq("層數發光顏色沒設 ⇒ nil", SS2("buffs", 5555, "stackGlowColor"), nil)
    eq("SPELL_CONST stackBar ＝ false", DB.SPELL_CONST.stackBar, false)
    eq("SPELL_CONST stackTicks ＝ false", DB.SPELL_CONST.stackTicks, false)
    eq("沒覆寫 ⇒ 層數當填充關", SS2("buffbars", 5555, "stackBar"), false)
    eq("沒覆寫 ⇒ 層數刻度關", SS2("buffbars", 5555, "stackTicks"), false)
    eq("SPELL_CONST stackGlowOp ＝ >=", DB.SPELL_CONST.stackGlowOp, ">=")
    eq("沒覆寫 ⇒ 比較子 >=（舊存檔不變）", SS2("buffs", 5555, "stackGlowOp"), ">=")
    for _, f in ipairs({ "stackGlow", "stackGlowType", "stackGlowColor", "stackGlowOp", "stackColors", "stackBar", "stackTicks" }) do
        eq("覆寫分組 " .. f .. " ＝ stack", DB.OVERRIDE_GROUP[f], "stack")
    end
    DB.SetOverride(5555, "stackGlow", 4)
    eq("覆寫門檻", SS2("buffs", 5555, "stackGlow"), 4)
    eq("層數門檻不算在 glow 那一組", DB.CountOverrides({ 5555 }, "glow"), 0)
    eq("層數門檻算在 stack 那一組", DB.CountOverrides({ 5555 }, "stack"), 1)
    DB.ClearOverrides({ 5555 }, "glow")
    DB.SetOverride(5555, "activeGlow", true)
    eq("清發光覆寫不清層數", SS2("buffs", 5555, "stackGlow"), 4)
    DB.ClearOverrides({ 5555 }, "stack")
    eq("清 stack 那一組", SS2("buffs", 5555, "stackGlow"), false)
    eq("清 stack 那一組不動生效發光", SS2("buffs", 5555, "activeGlow"), true)
    DB.SetOverride(5555, "activeGlow", nil)
    eq("DB_VERSION 沒動（這一項不遷移；5 是冷卻低秒變色開關、6 是長條層數字級、7 是增益不在時）", ns.DB_VERSION, 7)
end

------------------------------------------------------------
-- 14. 2026-10-03（P7）：顯示條件的三個新欄位、以增益取代（replaceWith）的欄位登記
------------------------------------------------------------
do
    local DB = ns.DB
    local SS2 = ns.SpellSetting
    local d = DB.BuildDefaults().profile.bars
    for _, key in ipairs({ "essential", "utility", "buffs", "buffbars" }) do
        local v = d[key] and d[key].visibility or {}
        eq(key .. "：showEnemy 預設 false", v.showEnemy, false)
        eq(key .. "：hideSkyriding 預設 false", v.hideSkyriding, false)
        eq(key .. "：hideHousing 預設 false", v.hideHousing, false)
        eq(key .. "：hideResting 預設 false（F5）", v.hideResting, false)
        eq(key .. "：hideVehicle 預設 false（F5）", v.hideVehicle, false)
    end
    local nb = DB.NewBarTable("icons", "x")
    eq("新群組：showEnemy 預設 false", nb.visibility.showEnemy, false)
    eq("新群組：hideSkyriding 預設 false", nb.visibility.hideSkyriding, false)
    eq("新群組：hideHousing 預設 false", nb.visibility.hideHousing, false)
    eq("新群組：hideResting 預設 false（F5）", nb.visibility.hideResting, false)
    eq("新群組：hideVehicle 預設 false（F5）", nb.visibility.hideVehicle, false)
    local lb = DB.NewBarTable("bars", "y")
    eq("新長條群組：hideResting 預設 false（F5）", lb.visibility.hideResting, false)
    eq("新長條群組：hideVehicle 預設 false（F5）", lb.visibility.hideVehicle, false)

    eq("SPELL_CONST replaceWith ＝ false", DB.SPELL_CONST.replaceWith, false)
    eq("replaceWith 沒有條層對應", DB.SPELL_FALLBACK.replaceWith, nil)
    eq("覆寫分組 replaceWith ＝ replace（自成一組）", DB.OVERRIDE_GROUP.replaceWith, "replace")
    eq("沒覆寫 ⇒ 不取代", SS2("essential", 7777, "replaceWith"), false)
    DB.SetOverride(7777, "replaceWith", 8888)
    eq("覆寫 ⇒ 增益的 cooldownID", SS2("essential", 7777, "replaceWith"), 8888)
    eq("不算在 icon 那一組（條頁「清除外觀覆寫」不會清掉它）", DB.CountOverrides({ 7777 }, "icon"), 0)
    eq("不算在 glow 那一組", DB.CountOverrides({ 7777 }, "glow"), 0)
    DB.ClearOverrides({ 7777 }, "icon")
    eq("清 icon 那一組 ⇒ 還在", SS2("essential", 7777, "replaceWith"), 8888)
    DB.ClearOverrides({ 7777 }, "replace")
    eq("清 replace 那一組 ⇒ 不取代", SS2("essential", 7777, "replaceWith"), false)
    eq("DB_VERSION 沒動（P7 不遷移；4 是 master 的 colorDuration 遷移、5 是冷卻低秒變色開關、6 是長條層數字級、7 是增益不在時）", ns.DB_VERSION, 7)
end

------------------------------------------------------------
-- 15. 自訂項目的三層範圍（P8）：ParseCustomID、ResolveScopes（窄蓋寬）、CustomView（種族技能、沒學就不列）、
--     EffectiveCustom 的合併順序、AddCustomTo／uid、覆寫跟著那一筆走、MoveCustomScope、RemoveCustom（寬層）、DeleteBar
------------------------------------------------------------
do
    local P = ns.profile
    local cur = ns.specID
    local other = cur + 1
    local function ids(list) local o = {} for i, it in ipairs(list) do o[i] = it.id end return table.concat(o, ",") end

    -- ParseCustomID：三種、與不是自訂項目的
    local s1, k1 = DB.ParseCustomID("c:3")
    check("Parse c:", s1 == "spec" and k1 == 3)
    local s2, k2 = DB.ParseCustomID("k:12")
    check("Parse k:", s2 == "class" and k2 == 12)
    local s3, k3 = DB.ParseCustomID("w:7")
    check("Parse w:", s3 == "shared" and k3 == 7)
    eq("Parse 數字 ⇒ nil", DB.ParseCustomID(1234), nil)
    eq("Parse 前綴不認得 ⇒ nil", DB.ParseCustomID("x:3"), nil)
    eq("Parse 編號不是數字 ⇒ nil", DB.ParseCustomID("w:x"), nil)
    eq("Parse 多一段 ⇒ nil", DB.ParseCustomID("w:3:1"), nil)
    eq("CustomIndex 只認專精層", DB.CustomIndex("k:3"), nil)
    eq("CustomIndex c: 照舊", DB.CustomIndex("c:4"), 4)
    eq("ScopedCustomID 戰隊", DB.ScopedCustomID("shared", 9), "w:9")
    eq("ScopedCustomID 職業", DB.ScopedCustomID("class", 9), "k:9")
    eq("ScopedCustomID 專精", DB.ScopedCustomID("spec", 2), "c:2")

    -- ResolveScopes：窄的蓋寬的（三種身分：法術、物品、光環＋filter）
    local shared = {
        { kind = "item", itemID = 5512, bar = "essential", uid = 1 },
        { kind = "spell", spellID = 642, bar = "essential", uid = 2 },
        { kind = "aura", spellID = 2825, filter = "HELPFUL", bar = "buffs", uid = 3 },
        { kind = "aura", spellID = 800, filter = "HARMFUL", bar = "buffs", uid = 4 },
        { kind = "spell", spellID = 999, bar = "essential" },                 -- 沒 uid 的壞資料：跳過
    }
    local class = {
        { kind = "spell", spellID = 642, bar = "utility", uid = 5 },          -- 蓋掉戰隊層的 642
        { kind = "aura", spellID = 800, filter = "HELPFUL", bar = "buffs", uid = 6 },  -- filter 不同：不蓋
    }
    local spec = {
        { kind = "item", itemID = 5512, bar = "utility" },                    -- 蓋掉戰隊層的 5512
        { kind = "aura", spellID = 2825, filter = "HARMFUL", bar = "buffs" }, -- filter 不同：不蓋
        { kind = "spell", spellID = 1, bar = "essential" },
    }
    local r = DB.ResolveScopes(shared, class, spec)
    eq("窄蓋寬：生效清單（戰隊 → 職業 → 專精）", ids(r), "w:3,w:4,k:5,k:6,c:1,c:2,c:3")
    eq("被蓋掉的那筆不在（物品）", ids(DB.ResolveScopes(shared, nil, { spec[1] })), "w:2,w:3,w:4,c:1")
    eq("只有專精層 ＝ 舊行為", ids(DB.ResolveScopes(nil, nil, spec)), "c:1,c:2,c:3")
    eq("每一項帶範圍與原始資料", r[1].scope .. "/" .. tostring(r[1].raw == shared[3]) .. "/" .. tostring(r[1].key), "shared/true/3")
    eq("職業蓋戰隊（法術）：職業層那筆在", r[3].entry.bar, "utility")
    local dup = DB.ResolveScopes(nil, nil, { { kind = "spell", spellID = 1 }, { kind = "spell", spellID = 1 } })
    eq("同一層的重複照留（Custom.Sync 自己分 key）", ids(dup), "c:1,c:2")
    eq("壞資料（不是表）在專精層照留（Catalog 自己濾）", ids(DB.ResolveScopes(nil, nil, { "x" })), "c:1")
    local dropped = DB.ResolveScopes(shared, nil, nil, function(raw) if raw.kind == "item" then return nil end return raw end)
    eq("resolve 回 nil ＝ 不列", ids(dropped), "w:2,w:3,w:4")

    -- CustomView：種族技能、寬層沒學就不列
    local known = { [20594] = true, [642] = false }
    local opts = { isKnown = function(id) return known[id] end, racial = function() return 20594 end }
    local racial = { kind = "racial", bar = "essential", uid = 8, hideUnknown = true, overrides = { readySound = "x" } }
    local v = DB.CustomView(racial, "shared", opts)
    check("種族技能 ⇒ 法術視圖", v and v.kind == "spell" and v.spellID == 20594 and v.racial == true)
    eq("視圖讀得到原本那筆的欄位", v and v.bar, "essential")
    racial.bar = "utility"
    eq("視圖跟著原本那筆變", v and v.bar, "utility")
    eq("視圖不改原本那筆的種類", racial.kind, "racial")
    eq("種族技能解不到 ⇒ 不列", DB.CustomView(racial, "shared", { racial = function() return nil end }), nil)
    eq("寬層沒學 ⇒ 不列", DB.CustomView({ kind = "spell", spellID = 642, uid = 9 }, "class", opts), nil)
    check("寬層沒學但 hideUnknown = false ⇒ 照列（問號格）",
        DB.CustomView({ kind = "spell", spellID = 642, uid = 9, hideUnknown = false }, "class", opts) ~= nil)
    check("專精層沒學 ⇒ 照列（舊行為）", DB.CustomView({ kind = "spell", spellID = 642 }, "spec", opts) ~= nil)
    check("讀不到（nil）⇒ 當學了", DB.CustomView({ kind = "spell", spellID = 77, uid = 9 }, "shared", opts) ~= nil)
    check("物品不看學了沒", DB.CustomView({ kind = "item", itemID = 642, uid = 9 }, "shared", opts) ~= nil)
    eq("身分：種族技能（原本那筆）", DB.CustomIdentity(racial), "racial")
    eq("身分：種族技能的視圖 ＝ 那個法術", DB.CustomIdentity(v), "spell:20594")
    eq("身分：光環分 filter", DB.CustomIdentity({ kind = "aura", spellID = 5 }), "aura:5:HELPFUL")
    -- 種族技能在戰隊層、專精層有同一個法術 ⇒ 專精層的蓋掉它
    local rr = DB.ResolveScopes({ racial }, nil, { { kind = "spell", spellID = 20594 } },
        function(raw, scope) return DB.CustomView(raw, scope, opts) end)
    eq("種族技能被專精層的同一個法術蓋掉", ids(rr), "c:1")

    -- AddCustomTo／uid／EffectiveCustom 的合併順序（遊戲裡的 opts：沒有 Catalog ⇒ 當學了）
    P.spells = P.spells or {}
    P.spells[cur], P.spells[other] = nil, nil
    P.customShared, P.customClass, P.customNextUID = nil, nil, nil
    eq("沒有寬層 ⇒ 生效清單是空的", #DB.EffectiveCustom(), 0)
    local cSpec = DB.AddCustomTo("spec", { kind = "spell", spellID = 100, bar = "essential" })
    eq("AddCustomTo 專精 ⇒ c:1", cSpec, "c:1")
    local wPot = DB.AddCustomTo("shared", { kind = "item", itemID = 5512, bar = "essential" })
    eq("AddCustomTo 戰隊 ⇒ w:1", wPot, "w:1")
    local kDef = DB.AddCustomTo("class", { kind = "spell", spellID = 642, bar = "essential" })
    eq("AddCustomTo 職業 ⇒ k:2（兩層共用一個號碼空間）", kDef, "k:2")
    eq("職業層存在這個職業底下", P.customClass.PALADIN[1].spellID, 642)
    eq("寬層的一筆 hideUnknown 預設開", P.customShared[1].hideUnknown, true)
    eq("流水號往前走", P.customNextUID, 3)
    eq("不認得的範圍 ⇒ nil", DB.AddCustomTo("guild", { kind = "spell", spellID = 1 }), nil)
    eq("不認得的種類 ⇒ nil", DB.AddCustomTo("shared", { kind = "totem", spellID = 1 }), nil)
    eq("合併順序：戰隊 → 職業 → 專精", ids(DB.EffectiveCustom()), "w:1,k:2,c:1")
    -- 流水號比現有的小（手改過／匯入的）⇒ 從最大的下一號接
    P.customNextUID = 1
    eq("流水號落後 ⇒ 接在最大的後面", DB.NextCustomUID(), 3)
    eq("流水號不是數字 ⇒ 從最大的 uid 重算", (function() P.customNextUID = "x"; return DB.NextCustomUID() end)(), 3)
    eq("CustomEntry 寬層", DB.CustomEntry("w:1").itemID, 5512)
    eq("CustomEntry 寬層：第二個回傳是 uid", select(2, DB.CustomEntry("k:2")), 2)
    eq("CustomEntry 寬層：第三個回傳是範圍", select(3, DB.CustomEntry("k:2")), "class")
    eq("CustomEntry 不存在的 uid", DB.CustomEntry("w:99"), nil)
    -- 別的職業看不到這個職業的職業層
    ns.playerClass = "MAGE"
    eq("別的職業：職業層不列", ids(DB.EffectiveCustom()), "w:1,c:1")
    eq("別的職業：CustomEntry 職業層 ＝ nil", DB.CustomEntry("k:2"), nil)
    ns.playerClass = "PALADIN"
    -- 別的專精：戰隊層、職業層照樣看得到，專精層是它自己的
    ns.specID = other
    eq("別的專精：寬層照樣在", ids(DB.EffectiveCustom()), "w:1,k:2")
    ns.specID = cur
    -- FindEffective／FindInScope
    eq("FindEffective：戰隊層的物品", DB.FindEffective({ kind = "item", itemID = 5512 }), "w:1")
    eq("FindEffective：沒有", DB.FindEffective({ kind = "item", itemID = 1 }), nil)
    eq("FindInScope：職業層有", DB.FindInScope("class", { kind = "spell", spellID = 642 }), 1)
    eq("FindInScope：戰隊層沒有", DB.FindInScope("shared", { kind = "spell", spellID = 642 }), nil)

    -- 覆寫跟著那一筆走：SpellSetting／SetOverride／CountOverrides／ClearOverrides／ResetOverrides／HasOverrides
    DB.SetOverride("w:1", "readySound", "Ding")
    DB.SetOverride("w:1", "borderColor", { r = 1, g = 0, b = 0, a = 1 })
    eq("寬層覆寫存在那一筆身上", P.customShared[1].overrides.readySound, "Ding")
    check("不寫進專精表", not (P.spells[cur].overrides and P.spells[cur].overrides["w:1"]))
    eq("SpellSetting 讀得到", ns.SpellSetting("essential", "w:1", "readySound"), "Ding")
    ns.specID = other
    eq("別的專精讀同一份", ns.SpellSetting("essential", "w:1", "readySound"), "Ding")
    ns.specID = cur
    eq("沒覆寫的欄位退回條層", ns.SpellSetting("essential", "w:1", "procGlow"), ns.Setting("essential", "glow.proc.enabled"))
    eq("CountOverrides（sound 組）", DB.CountOverrides({ "w:1", "k:2" }, "sound"), 1)
    DB.ClearOverrides({ "w:1" }, "sound")
    eq("ClearOverrides 清 sound 組", ns.SpellOverride("w:1", "readySound"), nil)
    check("其他組留著", ns.SpellOverride("w:1", "borderColor") ~= nil)
    check("HasOverrides", DB.HasOverrides("w:1") and not DB.HasOverrides("k:2"))
    DB.ResetOverrides("w:1")
    eq("ResetOverrides 整張拿掉", P.customShared[1].overrides, nil)
    DB.SetOverride("k:2", "procGlow", false)
    DB.SetOverride("k:2", "procGlow", nil)
    eq("清到空 ⇒ 整張拿掉", P.customClass.PALADIN[1].overrides, nil)
    eq("SetOverride 不存在的寬層 id ⇒ false", DB.SetOverride("w:99", "procGlow", true), false)

    -- MoveCustomScope
    local sp = DB.SpecSpells(true)
    sp.order.essential = { 11, "c:1", "w:1", "k:2", 12 }
    DB.SetOverride("c:1", "readySound", "Bell")
    -- 專精 → 戰隊：覆寫搬到那一筆身上、順序裡換新 id、專精層那筆拿掉
    local n1 = DB.MoveCustomScope("c:1", "shared")
    eq("專精 → 戰隊：新 id", n1, "w:4")
    eq("覆寫跟著走", ns.SpellOverride(n1, "readySound"), "Bell")
    eq("專精表的舊覆寫拿掉", sp.overrides["c:1"], nil)
    eq("順序裡換新 id、位置不跳", table.concat((function() local o = {} for i, x in ipairs(sp.order.essential) do o[i] = tostring(x) end return o end)(), ","), "11,w:4,w:1,k:2,12")
    eq("專精層那筆沒了", #DB.CustomList(false), 0)
    eq("同一層 ⇒ 沒有錯誤原因", select(2, DB.MoveCustomScope("k:2", "class")), nil)
    eq("同一層 ⇒ 原 id", DB.MoveCustomScope("k:2", "class"), "k:2")
    -- 職業 → 戰隊：所有專精的順序都換
    P.spells[other] = { order = { essential = { "k:2" } }, hidden = {}, groupOf = {}, overrides = {} }
    DB.SetOverride("k:2", "procGlow", false)
    local n2 = DB.MoveCustomScope("k:2", "shared")
    eq("職業 → 戰隊：新 id", n2, "w:5")
    eq("別的專精的順序也換", P.spells[other].order.essential[1], "w:5")
    eq("覆寫跟著到戰隊層", ns.SpellOverride(n2, "procGlow"), false)
    eq("職業層那筆沒了", #P.customClass.PALADIN, 0)
    -- 戰隊 → 專精（往窄）：只搬到目前專精，別的專精的舊 id 清掉；覆寫搬進專精表
    local n3 = DB.MoveCustomScope(n2, "spec")
    eq("戰隊 → 專精：追加到尾端", n3, "c:1")
    eq("覆寫搬到專精表", sp.overrides[n3] and sp.overrides[n3].procGlow, false)
    eq("目前專精的順序換新 id", sp.order.essential[4], "c:1")
    eq("別的專精的順序清掉舊 id", #P.spells[other].order.essential, 0)
    ns.specID = other
    eq("別的專精看不到了", DB.FindEffective({ kind = "spell", spellID = 642 }), nil)
    ns.specID = cur
    -- 目標層已經有同身分的 ⇒ exists、不動
    DB.AddCustomTo("shared", { kind = "spell", spellID = 642, bar = "essential" })
    local nx, why = DB.MoveCustomScope("c:1", "shared")
    check("目標層已有 ⇒ nil, exists", nx == nil and why == "exists")
    eq("不動：專精層那筆還在", DB.CustomEntry("c:1") and DB.CustomEntry("c:1").spellID, 642)
    eq("不認得的範圍 ⇒ bad", select(2, DB.MoveCustomScope("c:1", "guild")), "bad")
    eq("不存在的 ⇒ missing", select(2, DB.MoveCustomScope("w:99", "spec")), "missing")

    -- RemoveCustom（寬層）：不用挪位、所有專精的順序／隱藏／群組清掉那個 id
    sp.hidden["w:1"] = true
    sp.groupOf["w:1"] = "g9"
    P.spells[other].order.essential = { "w:1", 21 }
    check("RemoveCustom w:1", DB.RemoveCustom("w:1"))
    eq("戰隊層那筆沒了", DB.CustomEntry("w:1"), nil)
    eq("其他寬層的 uid 不變", DB.CustomEntry("w:4") and DB.CustomEntry("w:4").spellID, 100)
    eq("目前專精的隱藏清掉", sp.hidden["w:1"], nil)
    eq("目前專精的群組清掉", sp.groupOf["w:1"], nil)
    eq("別的專精的順序清掉", table.concat(P.spells[other].order.essential, ","), "21")
    eq("刪不存在的寬層 id ⇒ false", DB.RemoveCustom("w:1"), false)

    -- DeleteBar：寬層上的一筆回家（光環 → 增益圖示、其他 → 核心）
    local g = DB.CreateBar("icons", "寬層群組")
    DB.SetCustomBar("w:4", g)
    eq("SetCustomBar 寬層", DB.CustomEntry("w:4").bar, g)
    DB.DeleteBar(g)
    eq("刪群組：寬層那筆回核心技能", DB.CustomEntry("w:4").bar, "essential")

    -- CopyCustomEntry：寬層不給（本來就每個專精都看得到）
    eq("CopyCustomEntry 寬層 ⇒ false", DB.CopyCustomEntry("w:4", other), false)

    P.customShared, P.customClass, P.customNextUID = nil, nil, nil
    P.spells[cur], P.spells[other] = nil, nil
    eq("DB_VERSION 沒動（P8 不遷移；5 是冷卻低秒變色開關、6 是長條層數字級、7 是增益不在時）", ns.DB_VERSION, 7)
end

------------------------------------------------------------
-- I. 增益持續時間的小數門檻與低秒變色（cooldownText.buffDecimalsBelow／buffLowColor）：預設 0／關、
--    舊存檔合併補成這樣、冷卻倒數的預設不變、逐法術覆寫登記
------------------------------------------------------------
do
    local d = DB.BuildDefaults().profile.theme.cooldownText
    eq("預設：增益持續時間小數門檻 0", d.buffDecimalsBelow, 0)
    eq("預設：增益持續時間低秒變色開", d.buffLowColor, true)
    eq("冷卻倒數的小數門檻不變", d.decimalsBelow, 3)
    eq("冷卻倒數的低秒變色不變（5 秒）", d.lowBelow, 5)
    eq("SPELL_FALLBACK buffDecimalsBelow", DB.SPELL_FALLBACK.buffDecimalsBelow, "cooldownText.buffDecimalsBelow")
    eq("SPELL_FALLBACK buffLowColor", DB.SPELL_FALLBACK.buffLowColor, "cooldownText.buffLowColor")
    eq("覆寫分組 buffDecimalsBelow ＝ text", DB.OVERRIDE_GROUP.buffDecimalsBelow, "text")
    eq("覆寫分組 buffLowColor ＝ text", DB.OVERRIDE_GROUP.buffLowColor, "text")
    -- J：增益持續時間自己的變色秒數
    eq("預設：增益持續時間變色秒數 5", d.buffLowBelow, 5)
    eq("SPELL_FALLBACK buffLowBelow", DB.SPELL_FALLBACK.buffLowBelow, "cooldownText.buffLowBelow")
    eq("覆寫分組 buffLowBelow ＝ text", DB.OVERRIDE_GROUP.buffLowBelow, "text")
    eq("增益持續時間變色顏色的資料路徑不變", DB.SPELL_FALLBACK.durationLowColor, "icon.durationLowColor")
    -- 舊存檔沒有這幾欄
    ns.profile.theme.cooldownText.buffDecimalsBelow = nil
    ns.profile.theme.cooldownText.buffLowColor = nil
    ns.profile.theme.cooldownText.buffLowBelow = nil
    DB.Init()
    eq("舊存檔補上 0", ns.profile.theme.cooldownText.buffDecimalsBelow, 0)
    eq("舊存檔補上開", ns.profile.theme.cooldownText.buffLowColor, true)
    eq("舊存檔補上 5", ns.profile.theme.cooldownText.buffLowBelow, 5)
    -- 玩家改過的不蓋
    ns.profile.theme.cooldownText.buffLowColor = true
    DB.Init()
    eq("玩家開過的留著", ns.profile.theme.cooldownText.buffLowColor, true)
    ns.profile.theme.cooldownText.buffLowColor = false
    eq("沒覆寫 ⇒ 條層的值", SS("essential", 4400, "buffDecimalsBelow"), 0)
end

------------------------------------------------------------
-- K. 冷卻倒數的低秒變色：開關 lowColorOn 跟變色秒數 lowBelow 分兩欄（2026-10-06）。
--    預設開、逐法術覆寫登記、MIGRATIONS[5] 把舊存檔的 lowBelow ≤ 0（＝關）搬成 關＋5 秒
------------------------------------------------------------
do
    local d = DB.BuildDefaults().profile.theme.cooldownText
    eq("預設：冷卻低秒變色開", d.lowColorOn, true)
    eq("預設：冷卻變色秒數 5", d.lowBelow, 5)
    eq("SPELL_FALLBACK cooldownTextLowColorOn", DB.SPELL_FALLBACK.cooldownTextLowColorOn, "cooldownText.lowColorOn")
    eq("覆寫分組 cooldownTextLowColorOn ＝ text", DB.OVERRIDE_GROUP.cooldownTextLowColorOn, "text")

    local M5 = DB.MIGRATIONS[5]
    check("MIGRATIONS[5] 存在", type(M5) == "function")
    local wide = { overrides = { cooldownTextLowBelow = 0 } }
    local prof = {
        theme = { cooldownText = { lowBelow = 0, size = 16 } },
        bars = {
            a = { text = { cooldownText = { lowBelow = 0 } } },          -- 條自己關掉
            b = { text = { cooldownText = { lowBelow = 8 } } },          -- 條自己開著、8 秒
            c = { text = { cooldownText = { size = 20 } } },             -- 沒存秒數：跟隨，不寫開關
            d = { text = {} },
            e = { text = { cooldownText = { lowBelow = 0, lowColorOn = true } } },   -- 已經有開關：不碰
        },
        spells = { [61] = { overrides = {
            [100] = { cooldownTextLowBelow = 0, procGlow = false },
            [101] = { cooldownTextLowBelow = 7 },
            [102] = { cooldownTextLowColorOn = false, cooldownTextLowBelow = 0 },      -- 已經有開關：不碰
        } } },
        customShared = { wide },
    }
    M5(prof)
    local th = prof.theme.cooldownText
    check("主題 lowBelow 0 → 關＋5 秒", th.lowColorOn == false and th.lowBelow == 5)
    eq("主題其他欄位不動", th.size, 16)
    local b = prof.bars
    check("條自己 0 → 關＋5 秒", b.a.text.cooldownText.lowColorOn == false and b.a.text.cooldownText.lowBelow == 5)
    check("條自己 8 → 開＋8 秒（成對明寫）", b.b.text.cooldownText.lowColorOn == true and b.b.text.cooldownText.lowBelow == 8)
    check("沒存秒數的條不寫開關", b.c.text.cooldownText.lowColorOn == nil and b.c.text.cooldownText.lowBelow == nil)
    eq("沒有倒數子表的條不建表", b.d.text.cooldownText, nil)
    check("已經有開關的條不碰", b.e.text.cooldownText.lowColorOn == true and b.e.text.cooldownText.lowBelow == 0)
    local o = prof.spells[61].overrides
    check("逐法術 0 → 開關覆寫成關、秒數覆寫拿掉",
        o[100].cooldownTextLowColorOn == false and o[100].cooldownTextLowBelow == nil and o[100].procGlow == false)
    check("逐法術 7 → 補上開（以前有秒數＝這一招開）、秒數留著",
        o[101].cooldownTextLowColorOn == true and o[101].cooldownTextLowBelow == 7)
    check("逐法術已經有開關的不碰", o[102].cooldownTextLowColorOn == false and o[102].cooldownTextLowBelow == 0)
    check("寬層自訂項目身上的覆寫也搬", wide.overrides.cooldownTextLowColorOn == false and wide.overrides.cooldownTextLowBelow == nil)
    -- 重跑不變（玩家之後在新版把秒數調成別的、又關掉，不會被洗）
    th.lowBelow = 9
    M5(prof)
    check("重跑：主題不再改", th.lowColorOn == false and th.lowBelow == 9)
    check("重跑：逐法術不再改", o[100].cooldownTextLowColorOn == false and o[100].cooldownTextLowBelow == nil
        and o[101].cooldownTextLowColorOn == true and o[101].cooldownTextLowBelow == 7)

    -- 整條路：1.2.7 的存檔（schemaVersion 4、主題 lowBelow = 0）登入 ⇒ 每份設定檔都搬
    local P = sv.profiles.Default
    P.theme.cooldownText.lowColorOn = nil
    P.theme.cooldownText.lowBelow = 0
    sv.profiles.Other = { theme = { cooldownText = { lowBelow = 0 } } }
    sv.schemaVersion, sv.schemaVersionSeen = 4, nil
    ns.profile, ns.profileName = nil, nil
    DB.Init()
    eq("登入遷移：版本推到目前", sv.schemaVersion, ns.DB_VERSION)
    check("登入遷移：目前設定檔 關＋5 秒", P.theme.cooldownText.lowColorOn == false and P.theme.cooldownText.lowBelow == 5)
    check("登入遷移：別份設定檔也搬", sv.profiles.Other.theme.cooldownText.lowColorOn == false
        and sv.profiles.Other.theme.cooldownText.lowBelow == 5)
    eq("讀單格：開關", S("essential", "cooldownText.lowColorOn"), false)
    -- 取消勾選只寫開關：秒數留著，再勾回來就是原本的秒數
    P.theme.cooldownText.lowColorOn = true
    P.theme.cooldownText.lowBelow = 12
    P.theme.cooldownText.lowColorOn = false
    eq("取消勾選秒數不變", S("theme", "cooldownText.lowBelow"), 12)
    P.theme.cooldownText.lowColorOn = true
    eq("勾回來還是原本的秒數", S("theme", "cooldownText.lowBelow"), 12)
    P.theme.cooldownText.lowBelow = 5
    sv.profiles.Other = nil
    -- 沒有開關欄（從沒存過的設定檔）：合併預設補成開
    P.theme.cooldownText.lowColorOn = nil
    ns.profile, ns.profileName = nil, nil
    DB.Init()
    eq("沒有開關 ⇒ 合併預設補開", P.theme.cooldownText.lowColorOn, true)
end

-- v7：「增益不在時」收成三態。條層 fixedSlots＋emptyStyle → layout.emptyMode；逐法術 placeholder → emptyMode
do
    local p = {
        bars = {
            buffs    = { kind = "icons", layout = { fixedSlots = true } },
            essential = { kind = "icons", layout = { fixedSlots = false } },
            buffbars = { kind = "bars", layout = { fixedSlots = true, emptyStyle = "bar" } },
            g1       = { kind = "bars", layout = { fixedSlots = true } },
            g2       = { kind = "bars", layout = { fixedSlots = false, emptyStyle = "bar" } },
            done     = { kind = "icons", layout = { emptyMode = "blank" } },
        },
        spells = {
            [250] = {
                order = { buffbars = { 31 }, g1 = { 32 }, buffs = { 33 } },
                overrides = {
                    [31] = { placeholder = true },
                    [32] = { placeholder = true },
                    [33] = { placeholder = true, borderColor = 1 },
                    [34] = { placeholder = true },            -- 不在任何 order 裡 ⇒ 暗圖示
                    [35] = { placeholder = false },
                    [36] = { placeholder = true, emptyMode = "collapse" },
                },
            },
        },
    }
    DB.MIGRATIONS[7](p)
    local L = function(k) return p.bars[k].layout end
    eq("v7：圖示類固定格位 ⇒ dim", L("buffs").emptyMode, "dim")
    eq("v7：固定格位欄拿掉", L("buffs").fixedSlots, nil)
    eq("v7：沒固定 ⇒ collapse", L("essential").emptyMode, "collapse")
    eq("v7：長條＋空長條 ⇒ dim", L("buffbars").emptyMode, "dim")
    eq("v7：長條＋隱藏（預設）⇒ blank", L("g1").emptyMode, "blank")
    eq("v7：長條沒固定 ⇒ collapse", L("g2").emptyMode, "collapse")
    eq("v7：長條沒固定 ⇒ emptyStyle 留著（被強制時的退路）", L("g2").emptyStyle, "bar")
    eq("v7：已有 emptyMode 不碰", L("done").emptyMode, "blank")
    local o = p.spells[250].overrides
    eq("v7：逐法術在空長條的長條 ⇒ dim", o[31].emptyMode, "dim")
    eq("v7：逐法術在隱藏的長條 ⇒ blank", o[32].emptyMode, "blank")
    eq("v7：逐法術在圖示類 ⇒ dim", o[33].emptyMode, "dim")
    eq("v7：placeholder 拿掉", o[33].placeholder, nil)
    eq("v7：別的覆寫不動", o[33].borderColor, 1)
    eq("v7：找不到條 ⇒ dim", o[34].emptyMode, "dim")
    eq("v7：placeholder false ⇒ 跟隨（不寫）", o[35].emptyMode, nil)
    eq("v7：placeholder false 也拿掉", o[35].placeholder, nil)
    eq("v7：已有 emptyMode 不碰", o[36].emptyMode, "collapse")
    -- 重跑不再改
    L("buffs").emptyMode = "collapse"
    DB.MIGRATIONS[7](p)
    eq("v7：重跑不改", L("buffs").emptyMode, "collapse")
end

------------------------------------------------------------
-- 圓環顯示（layout.style／ring 子表）：預設、舊存檔由合併補、判準、逐法術填色跟隨條
------------------------------------------------------------
do
    local P3 = ns.profile
    for _, k in ipairs({ "essential", "utility", "buffs" }) do
        eq("圓環：" .. k .. " 顯示樣式預設 icons", P3.bars[k].layout.style, "icons")
        local r = P3.bars[k].ring
        check("圓環：" .. k .. " ring 預設", type(r) == "table" and r.thickness == 8 and r.gap == 3
            and r.direction == "outward" and r.fillColor == false and r.timeText == "top"
            and r.showIcon == false and r.iconSize == 14)
        local tc = r.trackColor
        check("圓環：" .. k .. " 軌道色預設", type(tc) == "table" and tc.r == 0.04 and tc.g == 0.06 and tc.b == 0.08 and tc.a == 0.9)
    end
    local nb = DB.NewBarTable("icons", "圈")
    check("圓環：新圖示群組也有 ring 預設", nb.layout.style == "icons" and type(nb.ring) == "table" and nb.ring.thickness == 8)
    eq("圓環：DefaultFor 自訂群組的環寬", DB.DefaultFor("bar", "nope", "ring.thickness"), 8)
    eq("圓環：DefaultFor 自訂群組的顯示樣式", DB.DefaultFor("bar", "nope", "layout.style"), "icons")
    eq("圓環：DefaultFor 內建條的方向", DB.DefaultFor("bar", "buffs", "ring.direction"), "outward")
    eq("圓環：純新增欄位，不升 DB_VERSION", ns.DB_VERSION, 7)
    -- 舊存檔（沒有 style／ring）：合併補預設；玩家自己存的不蓋
    local old = DB.BuildDefaults().profile
    old.bars.buffs.layout.style = nil
    old.bars.buffs.ring = nil
    old.bars.essential.ring = { thickness = 12, fillColor = { r = 1, g = 0, b = 0, a = 1 } }
    old.bars.essential.layout.style = "rings"
    DB.MergeDefaults(old, DB.BuildDefaults().profile)
    eq("圓環：舊存檔補 style", old.bars.buffs.layout.style, "icons")
    eq("圓環：舊存檔補 ring 子表", old.bars.buffs.ring.gap, 3)
    eq("圓環：玩家存的環寬不蓋", old.bars.essential.ring.thickness, 12)
    eq("圓環：玩家存的填色不蓋", old.bars.essential.ring.fillColor.r, 1)
    eq("圓環：缺的欄位照補", old.bars.essential.ring.gap, 3)
    eq("圓環：玩家選的 rings 不蓋", old.bars.essential.layout.style, "rings")
    -- 判準：圖示類＋rings；長條類存著也不算
    check("BarIsRings：預設不是", not DB.BarIsRings("buffs"))
    P3.bars.buffs.layout.style = "rings"
    check("BarIsRings：圖示類＋rings", DB.BarIsRings("buffs"))
    P3.bars.buffbars.layout.style = "rings"
    check("BarIsRings：長條類不算", not DB.BarIsRings("buffbars"))
    check("BarIsRings：不存在的條", not DB.BarIsRings("nope"))
    P3.bars.buffbars.layout.style = "icons"
    -- 逐法術填色：沒覆寫跟隨條層 ring.fillColor（false ＝ 職業色）；覆寫優先
    eq("SPELL_FALLBACK ringColor", DB.SPELL_FALLBACK.ringColor, "ring.fillColor")
    eq("覆寫分組 ringColor ＝ icon", DB.OVERRIDE_GROUP.ringColor, "icon")
    eq("ringColor 沒覆寫 ⇒ 條層 false（職業色）", ns.SpellSetting("buffs", 777, "ringColor"), false)
    P3.bars.buffs.ring.fillColor = { r = 0, g = 1, b = 0, a = 1 }
    eq("ringColor 沒覆寫 ⇒ 條層的色", ns.SpellSetting("buffs", 777, "ringColor").g, 1)
    DB.SetOverride(777, "ringColor", { r = 0, g = 0, b = 1, a = 1 })
    eq("ringColor 覆寫優先", ns.SpellSetting("buffs", 777, "ringColor").b, 1)
    DB.SetOverride(777, "ringColor", nil)
    P3.bars.buffs.ring.fillColor = false
    P3.bars.buffs.layout.style = "icons"
end

print(("DB_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
