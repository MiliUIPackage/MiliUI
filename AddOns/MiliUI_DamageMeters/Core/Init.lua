------------------------------------------------------------
-- MiliUI_DamageMeters 命名空間與啟動流程
--
-- 這支插件是「渲染器」，不是統計引擎：所有加總由暴雪 12.0 起的 C_DamageMeter
-- 做完，這裡只負責把資料畫成長條。因此它**完全不註冊
-- COMBAT_LOG_EVENT_UNFILTERED**——CPU 成本只跟「可見列數 × 刷新率」成長，
-- 跟團隊人數與戰鬥記錄流量無關。設計理由見 .claude/notes/wow-damagemeter-c-api-design.md。
--
-- 啟動一律等到 PLAYER_LOGIN：SavedVariables 那時才保證載入，也不必猜插件順序。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1

-- player token 不受 12.1 身分限制，讀職業是安全的
ns.playerClass = select(2, UnitClass("player"))
ns.playerGUID  = UnitGUID("player")

-- 聊天前綴與設定視窗標題共用這一個色，跟 TOC 的 [統計] 標籤同色（FFB627）。
-- 跟 DamageMeterTools 的 [統計] 是同色系不同亮度：我們是主體（飽和），
-- 它是增強工具（收斂）—— 兩個在插件列表裡相鄰，這樣看得出是一組又分得出主從。
ns.PREFIX_COLOR = "|cffFFB627"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Damage Meters"] .. "]|r", ...)
end

------------------------------------------------------------
-- 錯誤收集：xpcall 隔離不能變成黑洞——記下最近的錯誤供 /mdm debug 印出，
-- 同時照常轉給全域 errorhandler（有裝 BugSack 就進 BugSack）
--
-- ⚠ 這支是 **xpcall 的訊息處理器**，所以它自己絕對不能拋錯 —— 拋了的話錯誤會
--   穿出 xpcall 的隔離變成「error in error handling」，比原本那個錯誤更難查。
--   三道守衛，每一道都對應一個真的會發生的情況：
------------------------------------------------------------
ns.errors = {}
local inReport = false

function ns.ReportError(err)
    -- (1) 防遞迴。有些插件會「包住前一個 handler 再呼叫」，錯誤有可能繞回這裡；
    --     沒有這道閘就是 stack overflow。代價是那一次的錯誤會被丟掉，換 stack。
    if inReport then return end
    inReport = true

    -- (2) err 可能是**秘密字串**：只要呼叫堆疊上有秘密值參與，debugstack() 就是
    --     秘密的，而 tostring(secret) 是禁止的操作。這支最常被 Meter/Combat.lua 的
    --     UNIT_SPELLCAST_SUCCEEDED 路徑叫到 —— 那正是秘密值流過的地方。
    local text
    if issecretvalue and issecretvalue(err) then
        text = "<secret error>"
    else
        local ok, str = pcall(tostring, err)
        text = ok and str or "<unprintable error>"
    end
    tinsert(ns.errors, text)
    if #ns.errors > 10 then tremove(ns.errors, 1) end

    -- (3) 下游的 handler 包 pcall：對方拋錯不能連坐。順便擋掉「handler 就是自己」
    --     （有插件把別人的 handler 抓去 seterrorhandler 就會這樣），那是無窮迴圈。
    local handler = geterrorhandler()
    if type(handler) == "function" and handler ~= ns.ReportError then
        pcall(handler, err)
    end

    inReport = false
end

------------------------------------------------------------
-- 客戶端閘：C_DamageMeter 是 12.0 才有的 API。沒有它這支插件無事可做，
-- 與其在每個呼叫點散一堆 nil 檢查，不如開檔就判斷一次、講一句話然後裝死。
------------------------------------------------------------
ns.HAS_API = (C_DamageMeter ~= nil
    and C_DamageMeter.GetCombatSessionFromType ~= nil
    and Enum ~= nil and Enum.DamageMeterType ~= nil)

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    ns.DB.Init()
    ns.Media.RegisterSharedMedia()   -- LSM 比我們晚載入時，開檔那次會沒註冊到

    if not ns.HAS_API then
        C_Timer.After(6, function()
            ns.Print("|cffff5555" .. ns.L["This client has no C_DamageMeter API (needs patch 12.0 or later); the addon is idle."] .. "|r")
        end)
        return
    end

    ns.Fire("Init")
end)

_G.MiliUIDamageMeters = ns
