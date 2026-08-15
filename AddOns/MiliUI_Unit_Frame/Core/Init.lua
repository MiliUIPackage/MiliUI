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
    boss = "首領", totem = "圖騰",
}

ns.frames = {}          -- [unitToken] = uf
ns.playerClass = select(2, UnitClass("player"))   -- player token 不受 12.1 身分限制，安全

-- 錯誤收集：xpcall 隔離不能變成黑洞——記下最近的錯誤供 /muf debug 印出，
-- 同時照常轉給全域 errorhandler（BugSack 有裝就進 BugSack）
ns.errors = {}
function ns.ReportError(err)
    tinsert(ns.errors, tostring(err))
    if #ns.errors > 10 then tremove(ns.errors, 1) end
    local handler = geterrorhandler()
    if handler then handler(err) end
end

_G.MiliUIUF = ns
