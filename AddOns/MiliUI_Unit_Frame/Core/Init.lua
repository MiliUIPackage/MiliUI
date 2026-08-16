------------------------------------------------------------
-- MiliUI_Unit_Frame 命名空間與常數
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME  = ADDON
ns.VERSION     = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION  = 1          -- schemaVersion，遷移鏈用（DB.Migrate 加條目時一起 bump）

-- 支援的單位（spawn 順序）
ns.UNITS = {
    "player", "target", "targettarget", "focus", "focustarget", "pet",
    "boss1", "boss2", "boss3", "boss4", "boss5",
}

-- unit token → DB key（boss1-5 共用一份設定）
ns.UNIT_KEYS = {
    player = "player", target = "target", targettarget = "targettarget",
    focus = "focus", focustarget = "focustarget", pet = "pet",
    boss1 = "boss", boss2 = "boss", boss3 = "boss", boss4 = "boss", boss5 = "boss",
}

-- 全域框架名（其他插件靠這些名字整合，例如 MiliUI Focuser）
ns.GLOBAL_NAMES = {
    player = "MiliUIUF_Player", target = "MiliUIUF_Target",
    targettarget = "MiliUIUF_TargetTarget",
    focus = "MiliUIUF_Focus", focustarget = "MiliUIUF_FocusTarget",
    pet = "MiliUIUF_Pet",
    boss1 = "MiliUIUF_Boss1", boss2 = "MiliUIUF_Boss2", boss3 = "MiliUIUF_Boss3",
    boss4 = "MiliUIUF_Boss4", boss5 = "MiliUIUF_Boss5",
}

-- 單位顯示名（設定介面用）
ns.UNIT_LABELS = {
    player = "玩家", target = "目標", targettarget = "目標的目標",
    focus = "專注目標", focustarget = "專注目標的目標", pet = "寵物",
    boss = "首領", totem = "召喚物",
}

ns.frames = {}          -- [unitToken] = uf
ns.playerClass = select(2, UnitClass("player"))   -- player token 不受 12.1 身分限制，安全

-- 錯誤收集：xpcall 隔離不能變成黑洞——記下最近的錯誤供 /muf debug 印出，
-- 同時照常轉給全域 errorhandler（BugSack 有裝就進 BugSack）
-- 點擊／開窗流程 log（抓「點小地圖鈕沒開起來」用），/muf debug 印出
ns.clickLog = {}
function ns.LogClick(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    tinsert(ns.clickLog, ("[%.2f] %s"):format(GetTime() % 1000, ok and line or fmt))
    if #ns.clickLog > 40 then tremove(ns.clickLog, 1) end
end

ns.errors = {}
function ns.ReportError(err)
    tinsert(ns.errors, tostring(err))
    if #ns.errors > 10 then tremove(ns.errors, 1) end
    local handler = geterrorhandler()
    if handler then handler(err) end
end

------------------------------------------------------------
-- 封鎖／禁止動作攔截
--
-- 「嘗試進行 Blizzard UI 專屬動作，遭到封鎖」那個彈窗來自 ADDON_ACTION_FORBIDDEN，
-- **pcall 攔不住**（它不是 Lua error，是引擎事件）。事件本身會告訴我們是哪個插件、
-- 哪個函式，抓下來寫進錯誤紀錄，下次 /muf debug 就直接看得到兇手，不用猜。
------------------------------------------------------------
do
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
    local seen = {}
    watcher:SetScript("OnEvent", function(_, event, addonName, funcName)
        if addonName ~= "MiliUI_Unit_Frame" then return end
        -- ns.trace 是我們自己在做敏感操作前留的麵包屑（見 Core/Events.lua 的 Reg）。
        -- 事件發生時它是 nil ⇒ **不是我們自己呼叫的**，是暴雪的程式碼跑在被我們
        -- 染過的東西上——這一句就能把「我方 bug」和「taint 傳染」分開。
        local line = ("%s：%s（戰鬥中=%s，我方位置=%s）"):format(
            event == "ADDON_ACTION_FORBIDDEN" and "禁止動作" or "封鎖動作",
            tostring(funcName), tostring(InCombatLockdown() and true or false),
            ns.trace or "不在我們的呼叫裡")
        tinsert(ns.errors, line)
        if #ns.errors > 10 then tremove(ns.errors, 1) end
        -- 同一個函式一場只喊一次，直接印出來免得還要下 /muf debug 才看得到
        local key = tostring(funcName)
        if not seen[key] then
            seen[key] = true
            print("|cff4DD2FF[米利頭像]|r |cffff5555" .. line .. "|r")
        end
    end)
end

------------------------------------------------------------
-- 溢盾光暈：用秘密布林開關貼圖，但**不讀它**
--
-- `calc:GetDamageAbsorbs()` 的第二個回傳 isClamped 在吸收量溢出滿血時為真，
-- 它是秘密值不能 if。`SetAlphaFromBoolean(bool, 1, 0)` 由 C 端決定 alpha，
-- 貼圖保持 Shown、靠透明度隱藏（Cell 的 B.SetOvershieldGlow 同法）。
------------------------------------------------------------
function ns.SetOvershieldGlow(glow, enabled, isClamped)
    if not glow then return end
    if enabled and isClamped ~= nil and glow.SetAlphaFromBoolean then
        glow:Show()
        glow:SetAlphaFromBoolean(isClamped, 1, 0)
    else
        glow:Hide()
    end
end

_G.MiliUIUF = ns
