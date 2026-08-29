-- UpdateUiWidgetTracker.lua
-- 跟踪 UIWidget 顶部文本变化：某次事件返回值含 "6/6"，下一次变成 nil → 触发 5 秒倒数 + 语音倒数
-- 仅副本 2825（纳洛拉克的洞穴）生效；所有打印已注释。

local addonName, addonTable = ...

-- 状态记忆：上一次事件时，GetTopWidgetText() 是否包含 "6/6"
local lastContainedSixSix = false

local frame = CreateFrame("Frame")
frame:RegisterEvent("UPDATE_UI_WIDGET")

frame:SetScript("OnEvent", function(self, event, ...)
    -- 仅限副本 2825（纳洛拉克的洞穴）生效
    if select(8, GetInstanceInfo()) ~= 2825 then return end

    -- 1. 记录当前返回值
    local current = addonTable.GetTopWidgetText()

    -- 2. 打印：本次事件拿到的值 + 上一轮状态
    -- print(string.format("|cff00ff00[Widget跟踪]|r 事件=%s | 当前文本=%s | 上一轮含6/6=%s",
    --     tostring(event), tostring(current), tostring(lastContainedSixSix)))

    -- 3. 判断本次是否含 "6/6"
    local currentHasSixSix = current and current:find("6/6", 1, true) and true or false
    -- if currentHasSixSix then
    --     print("|cffffaa00[Widget跟踪]|r ✅ 检测到文本包含 6/6")
    -- end

    -- 4. 关键判定：上一轮含 6/6，且本轮变成 nil → 触发 5 秒倒数 + 语音倒数
    if lastContainedSixSix and current == nil then
        -- print("|cffff0000[Widget跟踪]|r 🎯 命中！上一轮=6/6 且本轮=nil → 触发 5 秒倒数！")

        -- 触发 5 秒倒数（剩余 5 秒时屏幕中央显示）
        if addonTable.CustomEncounterBar then
            addonTable.CustomEncounterBar(460693, 5, "首领激活")
        end

        -- 5 秒语音倒数：5 → 4 → 3 → 2 → 1（嵌套 C_Timer.After，路径直接调用 addonTable.GetMediaPath()）
        PlaySoundFile(addonTable.GetMediaPath() .. "DaoShu5.ogg", DiGuaTimelineAudioHelper.audioChannel)
        C_Timer.After(1, function()
            PlaySoundFile(addonTable.GetMediaPath() .. "DaoShu4.ogg", DiGuaTimelineAudioHelper.audioChannel)
            C_Timer.After(1, function()
                PlaySoundFile(addonTable.GetMediaPath() .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel)
                C_Timer.After(1, function()
                    PlaySoundFile(addonTable.GetMediaPath() .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    C_Timer.After(1, function()
                        PlaySoundFile(addonTable.GetMediaPath() .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end)
                end)
            end)
        end)
    -- elseif lastContainedSixSix and current ~= nil and not currentHasSixSix then
    --     -- 观察用：上一轮是 6/6，本轮变成别的文本（未触发）
    --     print("|cffffaa00[Widget跟踪]|r ⚠️ 6/6 变成了其他文本，未触发")
    end

    -- 5. 更新状态，供下一轮判定
    lastContainedSixSix = currentHasSixSix
end)
