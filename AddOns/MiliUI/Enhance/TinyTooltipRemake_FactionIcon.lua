---------------------------------------------------------------
-- MiliUI Enhance: 浮動資訊的陣營圖示改用扁平版
--
-- 插件內建的是 Interface\TargetingFrame\UI-PVP-ALLIANCE/HORDE，
-- 那是舊版帶金屬圓框的立體徽章，縮到 14px 只剩一坨。
-- 這裡換成暴雪現行 UI 在用的扁平 atlas（純色符號，無外框）。
--
-- 只覆蓋 TinyTooltip.icons 的兩個鍵，GetFactionIcon() 是即時查表，
-- 換完不用 reload 也會生效，插件更新也不會被蓋掉。
--
-- Author: Mili
---------------------------------------------------------------

-- 想換款式改這行就好，可用的值看下面 STYLES
local STYLE = "questlog"

local STYLES = {
    -- 社群面板的陣營標：純色符號、完全沒有描邊，最扁平，但顏色偏暗
    communities = {
        Horde    = { atlas = "communities-icon-faction-horde",    width = 12, height = 14 },
        Alliance = { atlas = "communities-icon-faction-alliance", width = 12, height = 14 },
    },
    -- 世界任務地圖標：一樣是扁平圖，小尺寸下最清楚、顏色最飽和
    worldquest = {
        Horde    = { atlas = "worldquest-icon-horde",    width = 14, height = 13 },
        Alliance = { atlas = "worldquest-icon-alliance", width = 14, height = 13 },
    },
    -- 任務日誌的陣營任務標：介於前兩者之間，線條比較粗
    questlog = {
        Horde    = { atlas = "questlog-questtypeicon-horde",    width = 14, height = 14 },
        Alliance = { atlas = "questlog-questtypeicon-alliance", width = 14, height = 14 },
    },
    -- 登入畫面的陣營剪影：單色灰白、完全沒有陣營色（兩邊原生比例不同）
    mono = {
        Horde    = { atlas = "CharacterSelection_Horde_Icon",    width = 8,  height = 14 },
        Alliance = { atlas = "CharacterSelection_Alliance_Icon", width = 11, height = 14 },
    },
}

local function AtlasExists(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function ApplyFactionIcons()
    local addon = _G.TinyTooltip
    if (type(addon) ~= "table" or type(addon.icons) ~= "table") then return end
    if (type(CreateAtlasMarkup) ~= "function") then return end

    local style = STYLES[STYLE]
    if (not style) then return end

    for faction, def in pairs(style) do
        -- atlas 被暴雪拿掉的話就維持插件原本的圖，不要塞出一個綠框
        if (AtlasExists(def.atlas)) then
            addon.icons[faction] = CreateAtlasMarkup(def.atlas, def.width, def.height)
        end
    end
end

if (_G.TinyTooltip) then
    ApplyFactionIcons()
else
    -- MiliUI 的資料夾名排在前面，通常比浮動資訊早載入
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, loadedAddon)
        if (loadedAddon == "TinyTooltip-Remake") then
            ApplyFactionIcons()
            self:UnregisterEvent("ADDON_LOADED")
            self:SetScript("OnEvent", nil)
        end
    end)
end
