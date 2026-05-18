-- ============================================================================
-- 1. 初始化全局/局部变量与配置
-- ============================================================================
local MEDIA_PATH
local PLAYER_LEVEL = UnitLevel("player")
local NEXT_PLAYER_LEVEL = PLAYER_LEVEL + 1
-- 核心数据字典
local MyTTSDict = {
    tolerance = 0.06,      -- 允许的时间误差范围（秒）
    isSampled = false,    -- 是否采样完成
    sampleIndex = 0,      -- 当前采样的是哪个技能
    skill1Time = 0,       -- 技能1 的 TTS 播放预设耗时
    skill2Time = 0,       -- 技能2 的 TTS 播放预设耗时
}

-- 运行时临时变量与Boss击杀状态
local ttsStartTime = 0
local BOSS_KILL_3056 = false -- 记录3056号Boss是否被击杀

-- 核心修改：将计数器改为表格，用于存储每个 unitTarget 独立的技能2计数
local UNIT_CAST_TRACKER = {} 
-- 运行时追踪：记录当前正在播放 TTS 的单位是谁（用于在播完时精准定位小怪）
local CURRENT_CASTING_UNIT = nil

-- ============================================================================
-- 2. 核心辅助函数
-- ============================================================================

-- 获取玩家职责 (TANK, HEALER, DAMAGER, NONE)
local function GetPlayerRole()
    local assignedRole = UnitGroupRolesAssigned("player")
    if assignedRole and assignedRole ~= "NONE" then return assignedRole end
    local specIndex = GetSpecialization()
    if specIndex then
        local _, _, _, _, role = GetSpecializationInfo(specIndex)
        return role
    end
    return "NONE"
end

-- 核心比对与执行逻辑（已支持多目标独立轮次过滤）
local function ExecuteClosestLogic(measuredTime, sound1, sound2)
    if not MyTTSDict.isSampled then 
        -- print("|cFFFF0000[MyTTS 错误] 核心逻辑未执行：系统尚未完成采样！|r")
        return 
    end

    -- 计算绝对时间差
    local diff1 = math.abs(measuredTime - MyTTSDict.skill1Time)
    local diff2 = math.abs(measuredTime - MyTTSDict.skill2Time)
    
    -- print(string.format("|cFFCCCCFF[MyTTS 识别中] 当前测得耗时: %.3f 秒 | 技能1预设: %.3f 秒 (差值: %.3f) | 技能2预设: %.3f 秒 (差值: %.3f)|r", measuredTime, MyTTSDict.skill1Time, diff1, MyTTSDict.skill2Time, diff2))


    -- 判断命中技能 1
    if diff1 < diff2 and diff1 < MyTTSDict.tolerance then
        -- print(string.format("|cFF00FF00[MyTTS 命中] 成功匹配【技能 1】(误差 %.3f 秒)，即将播放声音: %s|r", diff1, sound1))
        PlaySoundFile(MEDIA_PATH .. sound1, "Master")
        
    -- 判断命中技能 2
    elseif diff2 < diff1 and diff2 < MyTTSDict.tolerance then
        -- 确定当前触发技能的是哪只怪，如果因为特殊原因丢失则降级为默认目标
        local unitKey = CURRENT_CASTING_UNIT or "default"
        
        -- 为当前怪初始化或递增计数器
        UNIT_CAST_TRACKER[unitKey] = (UNIT_CAST_TRACKER[unitKey] or 0) + 1
        local currentCount = UNIT_CAST_TRACKER[unitKey]
        
        -- 判断该怪对应的单位是否为单数轮次（1, 3, 5, 7...）
        if currentCount % 2 == 1 then
            -- print(string.format("|cFF00FF00[MyTTS 命中] 单位[%s] 成功匹配【技能 2】(第 %d 轮: 单数轮)，即将播放声音: %s|r", unitKey, currentCount, sound2))
            PlaySoundFile(MEDIA_PATH .. sound2, "Master")
            if currentEncounterID == 0 then
                C_EncounterTimeline.AddScriptEvent({
                    spellID = 1270618,
                    iconFileID = 236215,
                    duration = 26,
                    overrideName = "准备AOE",
                    icons = 0x1,
                    severity = 2,
                    maxQueueDuration = 0,
                    paused = false,
                }) 
            end           
        else
            -- print(string.format("|cFF888888[MyTTS 跳过] 单位[%s] 成功匹配【技能 2】(第 %d 轮: 双数轮)，本次不播放声音。|r", unitKey, currentCount))
        end
        
    -- 两者都没命中
    else
        -- print(string.format("|cFFFF5555[MyTTS 未命中] 耗时 %.3f 秒未能匹配任何技能。最接近的误差分别为: 技能1(%.3f), 技能2(%.3f) [容忍上限: %.1f]|r", measuredTime, diff1, diff2, MyTTSDict.tolerance))

    end
end

-- 核心：路径更新逻辑
local function RefreshMediaPath()
    if C_AddOns.IsAddOnLoaded("DiGua-WYJJ") then
        MEDIA_PATH = "Interface\\AddOns\\DiGua-WYJJ\\Media\\"
    else
        MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
    end
end

local function FindBestVoice()
    local ttsVoices = C_VoiceChat.GetTtsVoices()
    
    for _, v in ipairs(ttsVoices) do
        -- 示例：寻找中文（Huihui）或者特定风格的声音
        if v.name:find("Huihui") then
            return v.voiceID
        end
    end
    
    -- 如果没找到，返回默认的第一个
    return ttsVoices[1] and ttsVoices[1].voiceID
end
-- ============================================================================
-- 3. 事件核心处理框架
-- ============================================================================
local frame = CreateFrame("Frame")

-- 注册需要的游戏事件
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BOSS_KILL") 
frame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_STARTED")
frame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
-- 事件回调函数
frame:SetScript("OnEvent", function(self, event, ...)
    local arg1, arg2, arg3 = ... -- 解包参数

    -- 插件加载完成
    if event == "ADDON_LOADED" and arg1 == "MyTTSPlugin" then
        -- print("|cFF00FF00MyTTS 语音插件已加载！静待 3056 号 Boss 击杀后采样...|r")
        
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...  
        if unit and UNIT_CAST_TRACKER[unit] then
            UNIT_CAST_TRACKER[unit] = nil
        end
    -- Boss 击杀事件：触发采样
    elseif event == "BOSS_KILL" then
        local encounterID = arg1 
        
        if encounterID == 3056 then
            BOSS_KILL_3056 = true
            MyTTSDict.isSampled = false -- 重置采样状态
            UNIT_CAST_TRACKER = {}      -- 清空所有怪的独立计数表
            
            -- print("|cFF99CCFF检测到 3056 号 Boss 倒地，开始按序采样...|r")
            
            -- 2秒后读第一个技能：闪电链
            C_Timer.After(2, function()
                MyTTSDict.sampleIndex = 1        
                C_VoiceChat.SpeakText(FindBestVoice(), "闪电链", 8, 0, true)
                -- print("【采样开始】-> 闪电链")
            end)
            
            -- 4秒后读第二个技能：烈焰新星
            C_Timer.After(4, function()
                MyTTSDict.sampleIndex = 2
                C_VoiceChat.SpeakText(FindBestVoice(), "烈焰新星", 8, 0, true)
                -- print("【采样开始】-> 烈焰新星")
            end)
            return
        end
    elseif event == "PLAYER_LOGIN" then
        RefreshMediaPath()
        
    -- TTS 开始播放：记录时间戳
    elseif event == "VOICE_CHAT_TTS_PLAYBACK_STARTED" then
        ttsStartTime = GetTime()

    -- TTS 播放结束：计算耗时
    elseif event == "VOICE_CHAT_TTS_PLAYBACK_FINISHED" then
        if ttsStartTime == 0 then return end
        
        local ttsDuration = GetTime() - ttsStartTime
        ttsStartTime = 0 -- 重置
        
        -- 分支 A：处于【采样阶段】
        if MyTTSDict.sampleIndex == 1 then
            MyTTSDict.skill1Time = ttsDuration
            -- print(string.format("【采样完成】闪电链 耗时: %.3f 秒", ttsDuration))
            
        elseif MyTTSDict.sampleIndex == 2 then
            MyTTSDict.skill2Time = ttsDuration
            MyTTSDict.sampleIndex = 0
            MyTTSDict.isSampled = true -- 激活核心识别逻辑
            -- print(string.format("【采样完成】烈焰新星 耗时: %.3f 秒。全系统就绪！", ttsDuration))
            
        -- 分支 B：采样已完成，进入【正常战斗识别阶段】
        elseif MyTTSDict.isSampled then
            -- ExecuteClosestLogic(ttsDuration, "MeiYouYinPin.ogg", "ZhunBeiAOE.ogg")
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            local subZone = GetSubZoneText()
            if instanceID == 2805 and subZone == "风行者宝库" and not C_CombatAudioAlert.IsEnabled() then 
                ExecuteClosestLogic(ttsDuration, "MeiYouYinPin.ogg", "ZhunBeiAOE.ogg")
            end            
        end
        
    -- 副本技能施法开始
    elseif event == "UNIT_SPELLCAST_START" then
        local unitTarget = ...
        local subZone = GetSubZoneText()
        local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(unitTarget)

        -- if name == "治疗波" then
        --     BOSS_KILL_3056 = true
        --     MyTTSDict.isSampled = false -- 重置采样状态
        --     UNIT_CAST_TRACKER = {}      -- 清空所有怪的独立计数表
            
        --     -- print("|cFF99CCFF检测到 3056 号 Boss 倒地，开始按序采样...|r")
            
        --     -- 2秒后读第一个技能：闪电链
        --     C_Timer.After(2, function()
        --         MyTTSDict.sampleIndex = 1        
        --         C_VoiceChat.SpeakText(FindBestVoice(), "闪电链", 10, 0, true)
        --         -- print("【采样开始】-> 闪电链")
        --     end)
            
        --     -- 4秒后读第二个技能：烈焰新星
        --     C_Timer.After(4, function()
        --         MyTTSDict.sampleIndex = 2
        --         C_VoiceChat.SpeakText(FindBestVoice(), "烈焰新星", 10, 0, true)
        --         -- print("【采样开始】-> 烈焰新星")
        --     end)
        --     return
        -- end
        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "风行者宝库" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2498 and unitPowerType == 0 then
                    -- 核心修改：在触发 TTS 之前，将当前施法单位的令牌（如 "nameplate1"）存入临时变量
                    CURRENT_CASTING_UNIT = unitTarget
                    C_VoiceChat.SpeakText(FindBestVoice(), name, 8, 0, true)
                end
            end                
        end
    end
end)