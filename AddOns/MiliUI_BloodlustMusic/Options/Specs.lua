------------------------------------------------------------
-- 本插件專屬的選單清單（共用層 Controls.lua 不放宿主資料）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Specs = {}
local Specs = ns.Specs

------------------------------------------------------------
-- 播放模式
------------------------------------------------------------
function Specs.PlayModeItems()
    return {
        { text = L["PLAY_MODE_RANDOM"],     value = "random" },
        { text = L["PLAY_MODE_SEQUENTIAL"], value = "sequential" },
    }
end

------------------------------------------------------------
-- 音效頻道
--
-- CHANNEL_CVAR 是「這個頻道的音量存在哪個 CVar」——設定頁要就地顯示／調整它，
-- 玩家才不用為了「怎麼沒聲音」跑去翻遊戲的音效選項。
------------------------------------------------------------
Specs.CHANNEL_CVAR = {
    Master = "Sound_MasterVolume",
    SFX    = "Sound_SFXVolume",
    Dialog = "Sound_DialogVolume",
}

Specs.CHANNEL_DESC = {
    Master = L["CHANNEL_MASTER_DESC"],
    SFX    = L["CHANNEL_SFX_DESC"],
    Dialog = L["CHANNEL_DIALOG_DESC"],
}

function Specs.ChannelItems()
    local items = {}
    for _, ch in ipairs(ns.CHANNELS) do
        items[#items + 1] = { text = ch, value = ch }
    end
    return items
end

------------------------------------------------------------
-- 提醒音效
--
-- 內建那組是暴雪的 SoundKit ID，名字刻意只編號（「音效 1」…）——這些音沒有官方
-- 名稱，硬取名反而會讓人以為聽得出差別；旁邊有試聽鈕。
-- 另外把 LibSharedMedia 註冊的音效一起列進來（裝了 DBM／Ayije_CDM 就會多一堆）。
------------------------------------------------------------
Specs.SOUND_BUILTINS = {
    8457, 8959, 8960, 8332, 8414, 8454, 3081, 48149, 48150, 56747,
    5674, 102607, 8458, 8455, 5874, 3175, 8463, 11466, 17316, 3439,
    111370, 39517, 895,
}

function Specs.SoundItems()
    local items = {}
    local prefix = (L["SOUND_PREFIX"] or "Sound") .. " "
    for i, id in ipairs(Specs.SOUND_BUILTINS) do
        items[i] = { text = prefix .. i, value = id }
    end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        for _, name in ipairs(lsm:List("sound")) do
            items[#items + 1] = { text = "[LSM] " .. name, value = name }
        end
    end
    return items
end

-- 試聽：數字 = 暴雪 SoundKit ID，字串 = LibSharedMedia 註冊名
function Specs.PlaySound(sound)
    if not sound then return end
    local num = tonumber(sound)
    if num then
        PlaySound(num, "Master")
        return
    end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local path = lsm:Fetch("sound", sound, true)
        if path then PlaySoundFile(path, "Master") end
    end
end
