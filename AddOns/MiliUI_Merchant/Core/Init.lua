------------------------------------------------------------
-- MiliUI_Merchant 命名空間與啟動流程
--
-- 這支插件**不自己畫商人視窗**。暴雪的 MerchantFrame 仍然是唯一的渲染引擎，
-- 我們只做三件事：把 MERCHANT_ITEMS_PER_PAGE 調大、照那個數字補建格子、
-- 每次暴雪重畫完再把格子排成想要的列欄數並把已收藏的那幾格變暗。
--
-- 為什麼沿用暴雪的格子而不是自己畫一套：商品格是**別的插件的掛勾點**。
-- 套組裡有三支照 `MERCHANT_ITEMS_PER_PAGE` ＋ `_G["MerchantItem"..i]` ＋
-- 頁碼公式 `(page-1)*perPage+i` 往格子上貼東西（裝等、塑形角標、單價）。
-- 自己畫格子＝那三支在商人視窗上全部失效，而且是靜默失效。
--
-- 啟動一律等到 PLAYER_LOGIN：自己的 SavedVariables 那時才在，
-- MerchantFrame 也已經建好了（它住在 Blizzard_UIPanels_Game，隨基礎 UI 載入，
-- 不是隨選載入的，所以不必等 ADDON_LOADED）。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1

-- player token 不受 12.1 身分限制，讀職業是安全的
ns.playerClass = select(2, UnitClass("player"))

-- 聊天前綴與設定視窗標題共用這一個色，跟 TOC 的 [商人] 標籤同色
ns.PREFIX_COLOR = "|cff33B8FF"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Merchant"] .. "]|r", ...)
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--
-- 這條路徑上沒有保護框（MerchantFrame 與 MerchantItemTemplate 都不是），
-- 所以攔截器平常應該一片安靜；真的響了就是有人把商人視窗接到保護路徑上，
-- 那是要知道的事。
------------------------------------------------------------
ns.Errors.Install(function(line)
    ns.Print("|cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 衝突閘
--
-- 判準刻意**不點名任何插件**，只看現場：`MERCHANT_ITEMS_PER_PAGE` 不是原廠的
-- 10，或者第 13 格已經存在 —— 兩者任一成立就表示已經有別的插件在擴充同一個
-- 視窗。兩支一起動會互相覆蓋排版與全域，畫面是亂的而且沒有人會報錯，
-- 所以我們整支休眠：不寫全域、不建格子、不掛勾，只在聊天框說一次為什麼。
--
-- ⚠ 判定要等 PLAYER_LOGIN：對方多半也是那時才動手（或更早，在 MerchantFrame
--   載入時），提早判會判到還沒發生的狀態。
------------------------------------------------------------
ns.dormant = false

local function DetectConflict()
    if _G.MERCHANT_ITEMS_PER_PAGE ~= 10 then return true end
    if _G.MerchantItem13 ~= nil then return true end
    return false
end

------------------------------------------------------------
-- 啟動：初始化資料庫 → 判衝突 → 叫醒各模組
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.DB.Init()

    if DetectConflict() then
        ns.dormant = true
        ns.Print(ns.L["Another add-on is already extending the merchant window, so this one is standing down. Disable one of them and reload."])
        return
    end

    ns.Collected.Init()
    ns.Grid.Init()
    ns.Dim.Init()
end)

_G.MiliUIMerchant = ns
