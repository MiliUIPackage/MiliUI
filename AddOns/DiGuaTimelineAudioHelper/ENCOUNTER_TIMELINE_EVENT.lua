-- ENCOUNTER_TIMELINE_EVENT.lua
-- 处理战斗时间轴事件的独立分支

local addonName, addonTable = ...

-- 运行时状态
local eventCounter = 0
local windowStartTime = 0
local triggerOccurrences = 0
local lastEncounterID = 0

local frame = CreateFrame("Frame")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")

frame:SetScript("OnEvent", function(self, event)
    local encID = addonTable.GetEncounterID and addonTable.GetEncounterID()

    -- 切 Boss 或重进战斗时重置
    if encID ~= lastEncounterID then
        eventCounter = 0
        windowStartTime = 0
        triggerOccurrences = 0
        lastEncounterID = encID
    end

    local now = GetTime()

    ---------------------------------------------------------------------------
    -- 1. 扭曲盘蛇 (3457)
    ---------------------------------------------------------------------------
    if encID == 3457 then
        if (now - windowStartTime) > 0.2 then
            windowStartTime = now
            eventCounter = 1
        else
            eventCounter = eventCounter + 1
        end

        if eventCounter == 5 then
            triggerOccurrences = triggerOccurrences + 1

            if triggerOccurrences > 1 then
                PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiChongFeng.ogg", DiGuaTimelineAudioHelper.audioChannel)
                C_Timer.After(4.6, function() 
                    PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end)
            end

            eventCounter = 0
            windowStartTime = 0
        end
        return
    end

    ---------------------------------------------------------------------------
    -- 2. 拉维 (3456)
    ---------------------------------------------------------------------------
    if encID == 3456 then
        if (now - windowStartTime) > 0.5 then
            windowStartTime = now
            eventCounter = 1
        else
            eventCounter = eventCounter + 1
        end

        -- print(string.format("|cffffaa00[时间轴追踪-拉维]|r 窗口内计数: %d / 3 (距起点 %.3f 秒)", eventCounter, now - windowStartTime))

        if eventCounter == 3 then
            triggerOccurrences = triggerOccurrences + 1
            local triggerID = triggerOccurrences

            -- print(string.format("|cff00ffff[时间轴测试-拉维]|r 捕获到第 %d 次3连事件！开启 27 秒倒计时...", triggerID))

            C_Timer.After(27, function()
                if addonTable.GetEncounterID and addonTable.GetEncounterID() == 3456 then
                    -- print(string.format("|cff00ff00[时间轴测试-拉维]|r 第 %d 次 27 秒倒计时结束（战斗中），播放语音：ZhuYiDuoQuan", triggerID))
                    PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                else
                    -- print(string.format("|cffff0000[时间轴测试-拉维]|r 第 %d 次 27 秒倒计时结束，但已脱战，取消播报。", triggerID))
                end
            end)

            eventCounter = 0
            windowStartTime = 0
        end
        return
    end
end)