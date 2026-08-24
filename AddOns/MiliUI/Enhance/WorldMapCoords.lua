------------------------------------------------------------
-- MiliUI: 隱藏內建世界地圖座標
--
-- 12.1 之後世界地圖左下角會自己長出「玩家座標」與「游標座標」兩塊面板
-- （Blizzard_WorldMap 的 WorldMapCoordsPanelMixin），字體與位置都不好看，
-- 而且套組本身已經有座標顯示。這裡把兩個 CVar 一起關掉。
--
-- 兩個 CVar 一起處理，不分開給選項 —— 玩家要的是「不要那塊東西」，
-- 不是要單獨留一個。
--
-- 面板走 CVarCallbackRegistry 監聽這兩個 CVar，所以 SetCVar 當下就生效，
-- 不需要重載介面。
--
-- 刻意不備份玩家原本的值：取消勾選一律設回 1（兩個都顯示），
-- 語意就是「這個勾選決定它顯不顯示」，不做三態也不做還原。
--
-- 讀寫於 MiliUI_DB.hideWorldMapCoords（boolean，預設 true）。
------------------------------------------------------------

local CVARS = {
    "worldMapShowPlayerCoords",   -- 玩家地圖座標
    "worldMapShowCursorCoords",   -- 游標地圖座標
}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.hideWorldMapCoords == nil then
        MiliUI_DB.hideWorldMapCoords = true
    end
    return MiliUI_DB
end

local function IsEnabled()
    return GetDB().hideWorldMapCoords and true or false
end

-- 勾選 = 隱藏 = 兩個 CVar 都設 0
local function Apply()
    local value = IsEnabled() and "0" or "1"
    for _, cvar in ipairs(CVARS) do
        -- 值沒變就不寫，免得白白觸發一次 CVar 回呼
        if GetCVar(cvar) ~= value then
            SetCVar(cvar, value)
        end
    end
end

local function SetEnabled(enabled)
    GetDB().hideWorldMapCoords = enabled and true or false
    Apply()
end

------------------------------------------------------------
-- 對外 API（給 Options/Tab_Enhance.lua 用）
------------------------------------------------------------
MiliUI_WorldMapCoords = {
    IsEnabled  = IsEnabled,
    SetEnabled = SetEnabled,
    Apply      = Apply,
}

-- 每次載入套用一次；玩家中途自己去遊戲選項打開就隨他，不持續搶
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    Apply()
end)
