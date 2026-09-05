------------------------------------------------------------
-- MiliUI_UnitFrames 命名空間與常數
------------------------------------------------------------
local ADDON, ns = ...

local L = ns.L          -- Locales\Locale.lua 在 TOC 排在本檔之前

ns.ADDON_NAME  = ADDON
ns.VERSION     = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION  = 18          -- schemaVersion，遷移鏈用（DB.Migrate 加條目時一起 bump）
                             -- ⚠ 沒有 12：開發期間推到 12 又整包丟掉，本機 SV 的
                             -- schemaVersionSeen 記著 12，重用會讓那步遷移被靜默跳過

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
    player = L["Player"], target = L["Target"], targettarget = L["Target of Target"],
    focus = L["Focus"], focustarget = L["Focus Target"], pet = L["Pet"],
    boss = L["Boss"], totem = L["Summons"],
}

ns.frames = {}          -- [unitToken] = uf
ns.playerClass = select(2, UnitClass("player"))   -- player token 不受 12.1 身分限制，安全

-- 聊天前綴與暴雪設定頁標題共用，跟 TOC 的 [頭像] 標籤同色
ns.PREFIX_COLOR = "|cff4DD2FF"

-- 點擊／開窗流程 log（抓「點小地圖鈕沒開起來」用），/muf debug 印出
ns.clickLog = {}
function ns.LogClick(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    tinsert(ns.clickLog, ("[%.2f] %s"):format(GetTime() % 1000, ok and line or fmt))
    if #ns.clickLog > 40 then tremove(ns.clickLog, 1) end
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截
--
-- 兩件事都在共用層 Libs/MiliUIWidgets/Errors.lua：
--   ns.ReportError  xpcall 的訊息處理器。三道守衛，其中一道是「err 本身可能是
--                   秘密字串」—— tostring(secret) 是禁止操作，而這支處理器最常
--                   被秘密值流過的那條路徑叫到。
--   封鎖動作攔截    「嘗試進行 Blizzard UI 專屬動作，遭到封鎖」那個彈窗來自
--                   ADDON_ACTION_FORBIDDEN，**pcall 攔不住**（不是 Lua error，
--                   是引擎事件）。事件會點名是哪個插件的哪個函式。
--
-- ⚠ ns.trace 是我們自己在做敏感操作前留的麵包屑（見 Core/Events.lua 的 Reg）。
--   事件發生時它是 nil ⇒ **不是我們自己呼叫的**，是暴雪的程式碼跑在被我們染過的
--   東西上 —— 那一句就能把「我方 bug」和「taint 傳染」分開。共用層會一起印出來。
------------------------------------------------------------
ns.Errors.Install(function(line)
    print(ns.PREFIX_COLOR .. "[米利單位框架]|r |cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 溢盾光暈：用秘密布林開關貼圖，但**不讀它**
--
-- `calc:GetDamageAbsorbs()` 的第二個回傳 isClamped 在吸收量溢出滿血時為真，
-- 它是秘密值不能 if。`SetAlphaFromBoolean(bool, 1, 0)` 由 C 端決定 alpha，
-- 貼圖保持 Shown、靠透明度隱藏。
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
