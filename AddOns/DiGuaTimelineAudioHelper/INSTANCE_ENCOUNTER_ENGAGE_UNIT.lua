-- INSTANCE_ENCOUNTER_ENGAGE_UNIT.lua

local addonName, addonTable = ...

-- 2623：记录本场 INSTANCE_ENCOUNTER_ENGAGE_UNIT 触发次数（addonTable 共享变量，供 BossHealthCenterDisplay 第 3 次后停显血量）
addonTable.Boss2623EngageCount = 0

local frame = CreateFrame("Frame")
frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")

-- 分别记录 boss2 和 boss3 的上一次存在状态
local wasActive = {
    boss2 = false,
    boss3 = false,
}

frame:SetScript("OnEvent", function(self, event, ...)
    -- 2623 开战：计数归零（顺带重置 3208 的 boss 状态）
    if event == "ENCOUNTER_START" then
        local encounterID = ...
        wasActive.boss2 = false
        wasActive.boss3 = false
        if encounterID == 2623 then
            addonTable.Boss2623EngageCount = 0
            -- print("|cffffd100[DiGua]|r 2623 开战，Boss2623EngageCount 已重置为 0")
        end
        return
    end

    -- 脱战/战斗结束：重置 3208 状态与 2623 计数
    if event == "ENCOUNTER_END" then
        wasActive.boss2 = false
        wasActive.boss3 = false
        addonTable.Boss2623EngageCount = 0
        return
    end

    if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        -- print("INSTANCE_ENCOUNTER_ENGAGE_UNIT")

        -- 2623：每次触发都 +1（addonTable 共享变量）
        if addonTable.GetEncounterID and addonTable.GetEncounterID() == 2623 then
            addonTable.Boss2623EngageCount = (addonTable.Boss2623EngageCount or 0) + 1
            -- print(string.format("|cff00ffff[DiGua]|r 2623 INSTANCE_ENCOUNTER_ENGAGE_UNIT 第 %d 次", addonTable.Boss2623EngageCount))
            -- 第 3 次触发 → 播放阶段转换语音（事件驱动，恰好只播一次）
            if addonTable.Boss2623EngageCount == 3 then
                PlaySoundFile(addonTable.GetMediaPath() .. "JieDuanZhuanHuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                -- print("|cff00ff00[DiGua]|r 2623 第 3 次触发 → 播放 JieDuanZhuanHuan")
            end
        end

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