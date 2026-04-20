-- 创建模块表
local _, addonTable = ...
local Countdown = {}
addonTable.Countdown = Countdown

local ticker = nil

-- 获取媒体路径的辅助函数
local function GetMediaPath()
    if C_AddOns.IsAddOnLoaded("DiGua-WYJJ") then
        return "Interface\\AddOns\\DiGua-WYJJ\\Media\\"
    else
        return "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
    end
end

-- 内部停止函数
function Countdown:Stop()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- === 核心修改：带环境检测的就位确认处理函数 ===
function Countdown:PlayReadyCheckVoice()
    -- 1. 冲突检测：如果装了 DBM/BW，通常它们会处理语音，不重复播放
    if C_AddOns.IsAddOnLoaded("DBM-Core") or C_AddOns.IsAddOnLoaded("BigWigs") then
        return 
    end

    -- 2. 获取 CVar 状态（对应你截图中的红框设置）
    -- Sound_EnableSFX: "1" 表示勾选了“声音效果”，"0" 表示没勾
    -- Sound_SFXVolume: 效果音量滑块数值 (0.0 到 1.0)
    local isSFXEnabled = C_CVar.GetCVar("Sound_EnableSFX")
    local sfxVolume = tonumber(C_CVar.GetCVar("Sound_SFXVolume")) or 0

    -- 3. 判断条件：如果对勾没勾，或者滑块音量为 0
    if isSFXEnabled == "0" or sfxVolume <= 0 then
        local path = GetMediaPath() .. "DengDengDeng.ogg"
        
        -- 使用 "Master" 通道播放，可以绕过“效果”开关，只要主音量开着就能听到
        PlaySoundFile(path, "Master")
    end
end

-- 内部开始函数 (倒计时)
function Countdown:Start(timeRemaining)
    if C_AddOns.IsAddOnLoaded("DBM-Core") or C_AddOns.IsAddOnLoaded("BigWigs") then
        return 
    end

    local currentMediaPath = GetMediaPath()
    self:Stop() 

    local count = math.floor(timeRemaining)
    if count <= 0 then return end

    local function PlayVoice(num)
        local path = currentMediaPath .. "DaoShu" .. num .. ".ogg"
        PlaySoundFile(path, "Master")
    end

    PlayVoice(count)
    count = count - 1

    if count >= 0 then
        ticker = C_Timer.NewTicker(1, function()
            if count > 0 then
                PlayVoice(count)
                count = count - 1
            elseif count == 0 then
                self:Stop()
            else
                self:Stop()
            end
        end, count + 1)
    end
end

-- 模块初始化（注册事件）
local frame = CreateFrame("Frame")
frame:RegisterEvent("START_PLAYER_COUNTDOWN")
frame:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
frame:RegisterEvent("READY_CHECK") 
frame:RegisterEvent("READY_CHECK_FINISHED")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "START_PLAYER_COUNTDOWN" then
        local _, timeRemaining = ...
        Countdown:Start(timeRemaining)
    elseif event == "CANCEL_PLAYER_COUNTDOWN" then
        Countdown:Stop()
    elseif event == "READY_CHECK" then
        -- 当团长发起就位确认时触发
        Countdown:PlayReadyCheckVoice()
    elseif event == "READY_CHECK_FINISHED" then
        -- 预留：全员就位逻辑
    end
end)