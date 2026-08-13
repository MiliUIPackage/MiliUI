-- INSTANCE_ENCOUNTER_ENGAGE_UNIT.lua

local addonName, addonTable = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
frame:RegisterEvent("ENCOUNTER_END")

-- 分别记录 boss2 和 boss3 的上一次存在状态
local wasActive = {
    boss2 = false,
    boss3 = false,
}

frame:SetScript("OnEvent", function(self, event, ...)
    -- 脱战/战斗结束时重置状态
    if event == "ENCOUNTER_END" then
        wasActive.boss2 = false
        wasActive.boss3 = false
        return
    end

    if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        -- 限制特定的 EncounterID
        if addonTable.GetEncounterID() ~= 3208 then return end

        local targets = { "boss2", "boss3" }

        for _, unitToken in ipairs(targets) do
            local isActive = UnitExists(unitToken)

            -- 上一次还在，但当前已不存在 -> 刚消失瞬间
            if wasActive[unitToken] and not isActive then
                -- print(string.format("|cffff0000[Boss 消失]|r %s 框架消失了！", unitToken))
                
                -- 播放语音
                PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiJieQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end

            -- 更新状态记录
            wasActive[unitToken] = isActive
        end
    end
end)