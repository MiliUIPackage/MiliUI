-- 创建模块表
local _, addonTable = ...
local Countdown = {}
addonTable.Countdown = Countdown

local ticker = nil

-- 内部停止函数
function Countdown:Stop()
    if ticker then
        ticker:Cancel()
        ticker = nil
        -- print("|cFFFF0000[地瓜语音助手]|r 倒数已取消")
    end
end

-- 内部开始函数
function Countdown:Start(timeRemaining)
    -- === 新增：检测 DBM 或 BigWigs ===
    -- C_AddOns.IsAddOnLoaded 是正式服最标准的检测方式
    if C_AddOns.IsAddOnLoaded("DBM-Core") or C_AddOns.IsAddOnLoaded("BigWigs") then
        -- 如果存在这俩插件，直接跳过本插件的倒数功能
        return 
    end
    -- ===============================

    self:Stop() 

    local count = math.floor(timeRemaining)
    if count <= 0 then return end -- 安全检查

    local function PlayVoice(num)
        local path = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\DaoShu" .. num .. ".ogg"
        PlaySoundFile(path, "Master")
    end

    PlayVoice(count) -- 立即播报起始数字
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

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "START_PLAYER_COUNTDOWN" then
        local _, timeRemaining = ...
        Countdown:Start(timeRemaining)
    elseif event == "CANCEL_PLAYER_COUNTDOWN" then
        Countdown:Stop()
    end
end)