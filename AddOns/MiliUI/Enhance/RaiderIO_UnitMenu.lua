------------------------------------------------------------
-- MiliUI: 關掉 Raider.IO 的右鍵選單整合
--
-- Raider.IO 用 Menu.ModifyMenu 在所有 MENU_UNIT_* 右鍵選單裡加「複製 Raider.IO 網址」。
-- 選單一經插件修改，之後在那個選單裡按暴雪自己的項目也算插件的執行：
-- taint.log 實測（2026-09-27）右鍵好友 →「密語」（UnitPopupSharedButtonMixins
-- → SendBNetTell → OpenChat）以 RaiderIO 的污染寫入 LAST_ACTIVE_CHAT_EDIT_BOX，
-- 之後每次 Enter 開聊天、點連結都讀到髒值，一路髒到 /reload。
-- 跟 .claude/notes/wow-121-chat-reply-secret-taint.md 是同一類：聊天輸入框被染，
-- 首領戰／M+ 的聊天封鎖下就可能打不了字。
--
-- 治本就是別讓它掛上去。Raider.IO 自己有開關 RaiderIO_Config.disableDropdownMenu
-- （設定面板「停用下拉選單按鈕」），而且是**第一次開選單時才讀**
-- （core.lua：hooksecurefunc(MenuGetManager, "OpenMenu", init)，init 只跑一次），
-- 所以登入時把值寫進去就來得及，不用改 Raider.IO 的檔案。
-- 反過來說，當次已經掛上去就拔不掉 ⇒ 改設定要重載。
--
-- 跟 WorldMapCoords 同一個語意：這個勾選決定開關，不備份玩家原本的值；
-- 取消勾選一律設回 false（Raider.IO 的預設）。
-- 讀寫於 MiliUI_DB.hideRaiderIOUnitMenu（boolean，預設 true）。
------------------------------------------------------------

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.hideRaiderIOUnitMenu == nil then
        MiliUI_DB.hideRaiderIOUnitMenu = true
    end
    return MiliUI_DB
end

local function IsEnabled()
    return GetDB().hideRaiderIOUnitMenu and true or false
end

local function Apply()
    if not C_AddOns.IsAddOnLoaded("RaiderIO") then return end
    -- 全新安裝時沒有存檔，這張表是 Raider.IO 在自己檔案裡先建好的；
    -- 它的 PLAYER_LOGIN 只在「不是表」時才換掉，所以寫進這張表不會被蓋
    if type(RaiderIO_Config) ~= "table" then return end
    local value = IsEnabled()
    -- 讀的時候會落到 Raider.IO 的預設值表，值一樣就不寫
    if RaiderIO_Config.disableDropdownMenu ~= value then
        RaiderIO_Config.disableDropdownMenu = value
    end
end

local function SetEnabled(enabled)
    GetDB().hideRaiderIOUnitMenu = enabled and true or false
    Apply()
end

------------------------------------------------------------
-- 對外 API（給 Options/Tab_Enhance.lua 用）
------------------------------------------------------------
MiliUI_RaiderIOUnitMenu = {
    IsEnabled  = IsEnabled,
    SetEnabled = SetEnabled,
    Apply      = Apply,
}

-- PLAYER_LOGIN 時兩邊存檔都已載入，而右鍵選單最早也要登入後才開得了
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    Apply()
end)
