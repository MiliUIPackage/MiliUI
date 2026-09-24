------------------------------------------------------------
-- MiliUI_MythicPlus 命名空間與啟動流程
--
-- 一句話：**鑰石打完之後，把「這一趟發生了什麼」留下來。**
--
-- 三件事，其餘一律不做：
--   1. 記錄場次（Run/）—— 完賽資訊 ＋ 戰鬥統計快照 ＋ 戰利品，存進 SavedVariables
--   2. 結算面板（UI/）—— 一場一張表，每人一列
--   3. 探針（Debug/）—— 在遊戲裡量「API 什麼時候才給得出明碼值」，預設關
--
-- 這支**完全不碰暴雪的任何框**：不 hook、不寫欄位、不 Show/Hide 別人的東西。
-- 12.1 之後「寫暴雪會讀的欄位」本身就是炸點（污染跟著執行流走，不跟保護框走），
-- 而我們要的資料全部來自 C_ 系列的讀取函式，沒有任何需要碰暴雪 frame 的理由。
--
-- ⚠ 12.1 秘密值：鑰石裡幾乎所有「別人的身分與數字」都可能是秘密值。規矩只有一條 ——
--   **存進 SavedVariables 的每一個值都必須是明碼**（秘密值存不進去，而且下次讀出來
--   拿去比較、當 key、串字串全部會硬錯）。所有入口一律先過 ns.Secret 的守衛。
--
-- 啟動等 PLAYER_LOGIN：SavedVariables 那時才在。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 2

-- player token 不受 12.1 身分限制，讀職業是安全的
ns.playerClass = select(2, UnitClass("player"))

-- 聊天前綴與設定視窗標題共用這一個色，跟 TOC 的 [M+] 標籤同色
ns.PREFIX_COLOR = "|cffFF7F00"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Mythic Plus"] .. "]|r", ...)
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--
-- 這支沒有任何保護路徑，攔截器平常應該一片安靜；真的響了就是有東西把我們接到
-- 保護路徑上，那是要知道的事。
------------------------------------------------------------
ns.Errors.Install(function(line)
    ns.Print("|cffff5555" .. line .. "|r")
end)

-- 逐項隔離的統一寫法：一個 handler 拋錯不能拖垮整批
function ns.Guard(fn, ...)
    return xpcall(fn, ns.ReportError, ...)
end

------------------------------------------------------------
-- 有沒有戰鬥統計 API
--
-- C_DamageMeter 是 12.0 起才有的。沒有它的話表頭資訊照記（完賽資訊是另一組 API），
-- 只是每人一列的數字整片空白 —— 那比整支插件不啟動好。
------------------------------------------------------------
ns.HAS_DM_API = (C_DamageMeter ~= nil) and (Enum and Enum.DamageMeterType ~= nil) and true or false

------------------------------------------------------------
-- 12.x 插件限制閘
--
-- `Enum.AddOnRestrictionType`：Combat / Encounter / ChallengeMode / PvPMatch / Map / Chat。
-- ⚠ **ChallengeMode 是「整趟未完成的鑰石」都算**，不是只有戰鬥中。所以「鑰石裡讀不到
--   統計」不是 bug，是設計；我們的作法是完賽之後排重試，等限制自己解除。
-- ⚠ 事件派送當下，`IsAddOnRestrictionActive` 對**正在變的那個型別**一律回 false
--   （官方文件明寫），所以事件裡要重算狀態得延一幀。
------------------------------------------------------------
function ns.RestrictionActive(name)
    local t = Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType[name]
    if t == nil then return false end
    if not (C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive) then return false end
    return C_RestrictedActions.IsAddOnRestrictionActive(t) and true or false
end

-- 六個型別的名字，探針要逐一印，功能端只問前三個
ns.RESTRICTION_TYPES = { "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map", "Chat" }

------------------------------------------------------------
-- 「現在可以安全地讀戰鬥統計了嗎」
--
-- 戰鬥中與限制生效中讀到的多半是秘密值（讀得到也存不進 SV），所以乾脆不讀、等下一次。
------------------------------------------------------------
function ns.CanReadStats()
    if InCombatLockdown() then return false end
    if ns.RestrictionActive("Combat") then return false end
    if ns.RestrictionActive("Encounter") then return false end
    if ns.RestrictionActive("ChallengeMode") then return false end
    return true
end

------------------------------------------------------------
-- 註冊事件：對**不存在的事件** RegisterEvent 會拋錯
--
-- 而且那是硬錯：一支初始化裡註冊十個事件，第三個名字拼錯，後面七個就沒註冊到，
-- 症狀是「某幾個功能安靜地沒反應」。所以一律包起來、失敗記進錯誤表。
------------------------------------------------------------
function ns.SafeRegister(frame, event)
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then
        ns.errors[#ns.errors + 1] = "RegisterEvent failed: " .. tostring(event)
    end
    return ok
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.DB.Init()
    ns.Probe.Init()
    ns.Recorder.Init()
    ns.Loot.Init()
    ns.Publish.Init()
    ns.Keystone.Init()
    ns.MinimapButton.Apply()
end)

_G.MiliUIMythicPlus = ns
