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
-- 可點擊的預設值與判準（DB.BarClickable）。
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
eq("schemaVersion", sv.schemaVersion, 1)
eq("DB_VERSION", ns.DB_VERSION, 1)
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
eq("長條位置 point", S("buffbars", "pos.point"), "BOTTOM")
eq("長條位置 y", S("buffbars", "pos.y"), 544)
eq("輔助跟著核心（跟自訂格子同一邊，由排開決定先後）", S("utility", "anchor.to"), "essential")
eq("自訂格子錨在核心", DB.GetPath(ns.profile, "pips.anchor.to"), "essential")
eq("輔助錨點", S("utility", "anchor.relPoint"), "BOTTOM")
eq("核心沒有錨定", S("essential", "anchor"), false)
eq("第二列尺寸預設關", S("essential", "layout.row2Size"), false)
eq("增益預設不固定格位", S("buffs", "layout.fixedSlots"), false)
eq("核心不固定格位", S("essential", "layout.fixedSlots"), false)
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
DB.MIGRATIONS[1] = function() calls = calls + 1 end
DB.MigrateProfile({}, 0)
eq("從 0 補到 1 跑一次", calls, 1)
DB.MigrateProfile({}, 1)
eq("已是 1 不再跑", calls, 1)

calls = 0
sv.schemaVersion = 0
sv.schemaVersionSeen = nil
DB.Init()
eq("舊 SV：每份設定檔各跑一次", calls, 1)
eq("舊 SV：版本推到目前", sv.schemaVersion, 1)

calls = 0
sv.schemaVersion = 5
DB.Init()
eq("較新的 SV：版本壓回目前", sv.schemaVersion, 1)
eq("較新的 SV：記住看過第幾版", sv.schemaVersionSeen, 5)
eq("較新的 SV：不跑遷移", calls, 0)
DB.MIGRATIONS[1] = real

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

print(("DB_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
