local addonName, addonTable = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("BOSS_KILL")

frame:SetScript("OnEvent", function(self, event, encounterID, encounterName)
    -- 直接硬编码判断击杀的 Boss encounterID (例如: 2902)
    if encounterID == 3101 then
        PlaySoundFile(addonTable.GetMediaPath() .. "HuoQuWeiZhuang.ogg", DiGuaTimelineAudioHelper.audioChannel)
    end
end)