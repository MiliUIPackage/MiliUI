-- FeastEmoteSound.lua
-- 监听队伍/团队成员触发的大餐等表情音效

local addonName, addonTable = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")

frame:SetScript("OnEvent", function(self, event, text, playerName)
    -- 1. 秘密值/安全检查 (11.0+ / 12.0+ API 兼容保护)
    if issecretvalue and issecretvalue(text) then return end
    if issecrettable and issecrettable(text) then return end

    if not text or not playerName then return end

    -- 2. 队员过滤：判断发送者是否在队伍或团队中
    if not UnitInParty(playerName) and not UnitInRaid(playerName) then
        return
    end

    -- 3. 文本匹配与语音触发
    if string.find(text, "供大家享用") then
        local soundFile = addonTable.GetMediaPath and (addonTable.GetMediaPath() .. "QuChiDaCan.ogg") or (MEDIA_PATH .. "QuChiDaCan.ogg")
        local channel = DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master"

        PlaySoundFile(soundFile, channel)
    end
end)