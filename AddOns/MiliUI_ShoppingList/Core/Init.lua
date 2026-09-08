------------------------------------------------------------
-- MiliUI_ShoppingList 命名空間與啟動流程
--
-- 採購清單：從製作頁或代工下單頁把配方加進清單，材料照「要做幾份」相乘，
-- 缺的到拍賣場搜尋、確認後購買。
--
-- 啟動一律等到 PLAYER_LOGIN：自己的 SavedVariables 那時已經載入，而且
-- 專業／拍賣兩邊的 LoadOnDemand 插件都還沒開，掛勾時機由各模組自己等。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1

-- player token 不受 12.1 身分限制，讀職業是安全的
ns.playerClass = select(2, UnitClass("player"))

-- 聊天前綴與設定視窗標題共用這一個色，跟 TOC 的 [清單] 標籤同色
ns.PREFIX_COLOR = "|cffFFFF99"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Shopping List"] .. "]|r", ...)
end

-- 12.1：任何從別人身上讀來的字串都有可能是秘密值，拿去當 table key 或
-- 串接都會直接崩潰。整包統一走這一支擋。
ns.issecret = issecretvalue or function() return false end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
------------------------------------------------------------
ns.Errors.Install(function(line)
    ns.Print("|cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 按鈕工具提示
--
-- ⚠ W.CreateButton 自己在 OnEnter/OnLeave 上換 backdrop 色，直接 SetScript
--   會把那段蓋掉（按鈕從此不會反白）。要掛提示就得連著一起重設，這件事
--   在三個模組都要做，所以收成一支。
------------------------------------------------------------
function ns.AttachTooltip(button, fill)
    button:SetScript("OnEnter", function(self)
        if self._colors and self:IsEnabled() then
            self:SetBackdropColor(unpack(self._colors[2]))
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        fill(self, GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if self._colors then self:SetBackdropColor(unpack(self._colors[1])) end
        GameTooltip:Hide()
    end)
end

------------------------------------------------------------
-- 啟動：初始化資料庫 → 通知各模組
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.DB.Init()
    ns.Media.UpdateFonts()      -- 字型物件要等 DB 才知道玩家挑了什麼
    ns.Fire("Init")
end)

_G.MiliUIShoppingList = ns
