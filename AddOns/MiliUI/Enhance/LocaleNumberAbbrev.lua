------------------------------------------------------------
-- MiliUI: 在地化數字縮寫
-- 將 Ayije_CDM 的法力顯示從 K 改為在地語系格式（zhTW 為萬/億）。
--
-- 實作方式：
--   1. 直接修改 Ayije_CDM/Modules/Tags.lua 第 239 行附近，
--      讓 CDM 自己讀 _G.MiliUI_DB.localeNumberAbbrev 旗標。
--   2. 此處只負責管理 SavedVariable 與設定面板的橋接，
--      不替換任何全域、不 hook 任何 closure，避免 taint。
--
-- 已知限制：
--   - 不影響 Stuf。Stuf 的 _abbrev 會經由全域 AbbreviateLargeNumbers
--     路徑取得，從外部替換會造成 Blizzard secure UI taint，無法
--     從 MiliUI 安全 hook。如要改 Stuf，需直接修改 Stuf 源碼。
------------------------------------------------------------

local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

MiliUI_LocaleNumberAbbrev = MiliUI_LocaleNumberAbbrev or {}
local M = MiliUI_LocaleNumberAbbrev

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.localeNumberAbbrev == nil then
        MiliUI_DB.localeNumberAbbrev = true
    end
end)

function M.SetEnabled(v)
    v = v and true or false
    if not MiliUI_DB then MiliUI_DB = {} end
    MiliUI_DB.localeNumberAbbrev = v
    -- Ayije_CDM 會在下一次 tag 更新時讀到新值，無需立即重繪
end

function M.IsEnabled()
    if not MiliUI_DB then return true end  -- 預設開啟
    return MiliUI_DB.localeNumberAbbrev ~= false
end

function M.IsAvailable()
    return _G.Ayije_CDM ~= nil
end
