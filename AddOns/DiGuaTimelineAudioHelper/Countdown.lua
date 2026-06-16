-- 创建模块表
local _, addonTable = ...
local Countdown = {}
addonTable.Countdown = Countdown -- 挂载到插件表，方便别的文件调用（如果需要的话）

local ticker = nil

local function GetMediaPath()
    if C_AddOns.IsAddOnLoaded("DiGua-WYJJ") then
        return "Interface\\AddOns\\DiGua-WYJJ\\Media\\"
    else
        return "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
    end
end

function Countdown:Stop()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

function Countdown:PlayReadyCheckVoice()
    if C_AddOns.IsAddOnLoaded("DBM-Core") or C_AddOns.IsAddOnLoaded("BigWigs") then
        return 
    end
    local _, battleTag = BNGetInfo()
    if battleTag and battleTag:find("简繁") then
        return
    end
    -- [优化] 动态获取声道配置
    local channel = DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master"
    local path = GetMediaPath() .. "JiuWeiQueRen.ogg"
    PlaySoundFile(path, channel)
end

-- 内部开始函数 (修正延迟，完美对齐时间轴)
function Countdown:Start(timeRemaining)
    if C_AddOns.IsAddOnLoaded("DBM-Core") or C_AddOns.IsAddOnLoaded("BigWigs") then
        return 
    end

    local currentMediaPath = GetMediaPath()
    self:Stop() 

    -- 向上取整
    local totalSeconds = math.ceil(timeRemaining)
    if totalSeconds <= 0 then return end

    -- 播放声音的内部函数
    local function PlayVoice(num)
        local channel = DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master"
        local path = currentMediaPath .. "DaoShu" .. num .. ".ogg"
        PlaySoundFile(path, channel)
    end

    -- 【关键修正】因为 Ticker 会在 1 秒后才第一次执行
    -- 所以当 Ticker 第一次执行时，系统时间实际上已经过去了 1 秒！
    -- 我们让 currentTick 直接从 (总秒数 - 1) 开始倒数，精准对齐系统画面
    local currentTick = totalSeconds - 1

    -- 如果总倒计时只有 5 秒，而刚好又没开启 10 秒倒数，特殊处理
    -- （防止 5 秒倒计时刚拉出来的那一瞬间漏掉声音）
    local isTenSec = DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.tenSecCountDown
    if (isTenSec and totalSeconds <= 10) or (not isTenSec and totalSeconds <= 5) then
        PlayVoice(totalSeconds)
    end

    -- 启动 Ticker（因为上面已经提前消费了第 0 秒，这里总次数要减 1）
    if totalSeconds > 1 then
        ticker = C_Timer.NewTicker(1, function()
            if currentTick > 0 then
                -- 核心判定：只有满足播放条件时才出声
                if isTenSec then
                    -- 开启 10 秒倒数，限制在 10 秒以内才播
                    if currentTick <= 10 then
                        PlayVoice(currentTick)
                    end
                else
                    -- 未开启 10 秒倒数，限制在 5 秒以内才播
                    if currentTick <= 5 then
                        PlayVoice(currentTick)
                    end
                end
                
                -- 倒计时递减
                currentTick = currentTick - 1
            else
                self:Stop()
            end
        end, totalSeconds - 1)
    end
end

-- 模块初始化（注册事件）
local frame = CreateFrame("Frame")
frame:RegisterEvent("START_PLAYER_COUNTDOWN")
frame:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
frame:RegisterEvent("READY_CHECK") 

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "START_PLAYER_COUNTDOWN" then
        local _, timeRemaining = ...
        Countdown:Start(timeRemaining)
    -- [修正逻辑] 当剩余时间更新或取消时，触发 Stop
    elseif event == "CANCEL_PLAYER_COUNTDOWN" then
        Countdown:Stop()
    elseif event == "READY_CHECK" then
        Countdown:PlayReadyCheckVoice()
    end
end)