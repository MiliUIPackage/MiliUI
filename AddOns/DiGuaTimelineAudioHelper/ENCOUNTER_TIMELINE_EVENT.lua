-- ENCOUNTER_TIMELINE_EVENT.lua
-- 处理战斗时间轴事件的独立分支

local addonName, addonTable = ...

-- 运行时状态
local eventCounter = 0
local windowStartTime = 0
local triggerOccurrences = 0
local lastEncounterID = 0
local totalEventCount = 0          -- 本场战斗累计事件数（用于每满 5 次触发）
local startTriggerScheduled = false -- 战斗开始 22 秒定时器是否已安排
local openScheduled = false         -- 防止 22 秒开启定时器重复安排（防抖）

local frame = CreateFrame("Frame")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")

-- 剧毒萎缩（3457）开关：打开 + 重置计数 + 10 秒后自动关闭
local function OpenJuDuWeiSuo()
    -- 先释放防抖标志，避免残留导致后续 5 次触发被跳过
    openScheduled = false

    -- 【前置条件】必须仍在 3457 首领战中才打开（防止延迟到点时已切到别的 Boss）
    if not (addonTable.GetEncounterID and addonTable.GetEncounterID() == 3457) then
        -- print("[剧毒萎缩] 已不在 3457 首领战，跳过开启")
        return
    end

    -- print("[剧毒萎缩] 时间轴触发 → 打开开关，重置计数")
    addonTable.JuDuWeiSuo = true
    addonTable.JuDuWeiSuoCounter = 0
    C_Timer.After(13, function()
        -- print("[剧毒萎缩] 18秒超时 → 关闭开关")
        addonTable.JuDuWeiSuo = false
    end)
end

frame:SetScript("OnEvent", function(self, event)
    local encID = addonTable.GetEncounterID and addonTable.GetEncounterID()

    -- 切 Boss 或重进战斗时重置
    if encID ~= lastEncounterID then
        eventCounter = 0
        windowStartTime = 0
        triggerOccurrences = 0
        totalEventCount = 0
        startTriggerScheduled = false
        openScheduled = false
        lastEncounterID = encID
    end

    local now = GetTime()

    ---------------------------------------------------------------------------
    -- 1. 扭曲盘蛇 (3457)
    ---------------------------------------------------------------------------
    if encID == 3457 then
        -- 事件累计 +1（用于每满 5 次触发剧毒萎缩开关）
        totalEventCount = totalEventCount + 1

        -- 触发点①：战斗开始后的第 22 秒（一次性）
        if not startTriggerScheduled then
            startTriggerScheduled = true
            local startTime = addonTable.GetStartTime and addonTable.GetStartTime() or 0
            local base = (startTime > 0) and startTime or now -- 没有正式开始时间就用第一个事件时刻
            local delay = math.max(0, 13 - (now - base))
            C_Timer.After(delay, OpenJuDuWeiSuo)
        end

        -- 触发点②：每累计满 5 次事件后 +22 秒开启（防抖：前一个还没执行就不重复安排）
        if totalEventCount % 5 == 0 and not openScheduled then
            openScheduled = true
            C_Timer.After(21, OpenJuDuWeiSuo)
        end

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

            C_Timer.After(26, function()
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