------------------------------------------------------------
-- 本插件專屬的選單清單（共用層 Controls.lua 不放宿主資料）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Specs = {}
local Specs = ns.Specs

------------------------------------------------------------
-- 團隊標記
------------------------------------------------------------
-- 名稱用遊戲內建的全域字串（RAID_TARGET_1..8），自動跟著客戶端語言走
function Specs.MarkItems()
    local items = {}
    for i = 1, 8 do
        items[i] = {
            text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i .. ":16|t "
                .. (_G["RAID_TARGET_" .. i] or tostring(i)),
            value = i,
        }
    end
    return items
end

------------------------------------------------------------
-- 音效
--
-- 每一筆的 SoundKit ID 都查過 SoundKitEntry → FileDataID → 社群 listfile 的
-- 實際檔名（註解裡那個），確定播得出來也確定是哪個音。
--
-- 要加新的請照同一套流程查證，**而且要看 SoundKit 的 VolumeFloat**：
-- 37666（首領密語警告）檔案存在、SoundKitEntry 也對，但 VolumeFloat=0.01
-- ＝ 音量在資料表就被壓成靜音，實際播出來什麼都聽不到，已拔掉。
-- 以下每一筆的 VolumeFloat 都在 0.35~1.0 之間。
------------------------------------------------------------
Specs.SOUND_BUILTINS = {
    { text = L["PvP flag alarm"],     value = 8332  },  -- Sound/SPELLS/PVPFlagTaken.ogg
    { text = L["Raid warning"],       value = 8959  },  -- INTERFACE/RaidWarning.ogg
    { text = L["Boss warning"],       value = 12197 },  -- INTERFACE/RaidBossWarning.ogg
    { text = L["Keystone warning"],   value = 34154 },  -- INTERFACE/UI_ChallengeMode_Warning.OGG
    { text = L["Alarm clock 1"],      value = 18871 },  -- INTERFACE/AlarmClockWarning1.ogg
    { text = L["Alarm clock 2"],      value = 12867 },  -- INTERFACE/AlarmClockWarning2.ogg
    { text = L["Alarm clock 3"],      value = 12889 },  -- INTERFACE/AlarmClockWarning3.ogg
    { text = L["Map ping"],           value = 3175  },  -- INTERFACE/MapPing.ogg
    { text = L["Rare vignette ping"], value = 37881 },  -- INTERFACE/UI_Vignette_MapPing_01.OGG
    { text = L["Message ping"],       value = 7355  },  -- INTERFACE/igTextPopupPing02.ogg
    { text = L["GM message"],         value = 15273 },  -- INTERFACE/GM_ChatWarning.ogg
    { text = L["Aggro warning"],      value = 15262 },  -- INTERFACE/Aggro_Enter_Warning_State.ogg
}

function Specs.SoundItems()
    local items = {}
    for _, s in ipairs(Specs.SOUND_BUILTINS) do
        items[#items + 1] = { text = s.text, value = s.value }
    end
    local lsm = ns.Media.LSM()
    if lsm then
        for _, name in ipairs(lsm:List("sound")) do
            items[#items + 1] = { text = "[LSM] " .. name, value = name }
        end
    end
    return items
end

------------------------------------------------------------
-- 擷取快捷鍵
------------------------------------------------------------
-- 單獨按下不算數的鍵
Specs.HOTKEY_MODIFIER_ONLY = {
    LSHIFT = true, RSHIFT = true,
    LCTRL  = true, RCTRL  = true,
    LALT   = true, RALT   = true,
    -- Mac 的 Command：綁定字串沒有 META- 前綴，當成不可用
    LMETA  = true, RMETA  = true,
    UNKNOWN = true,
}

-- OnClick 的 button 名稱 → 綁定字串（左右鍵留給「開始擷取 / 取消」）
Specs.HOTKEY_MOUSE = {
    MiddleButton = "BUTTON3",
    Button4 = "BUTTON4",
    Button5 = "BUTTON5",
}

-- 綁定字串的修飾鍵順序是固定的：ALT-CTRL-SHIFT-鍵
function Specs.BuildHotkeyString(key)
    local prefix = ""
    if IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    return prefix .. key
end
