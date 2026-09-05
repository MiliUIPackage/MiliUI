-- EncounterWarning.lua

local addonName, addonTable = ... 

-- ------------------------------------------
-- 独立事件分发控制中心（直接平铺业务逻辑）
-- ------------------------------------------
local WarningFrame = CreateFrame("Frame")
addonTable.JuDuWeiSuo = false
addonTable.JuDuWeiSuoCounter = 0
WarningFrame:RegisterEvent("ENCOUNTER_WARNING")
WarningFrame:RegisterEvent("RAID_BOSS_EMOTE")

WarningFrame:SetScript("OnEvent", function(self, event, ...)
    if event ~= "RAID_BOSS_EMOTE" and event ~= "ENCOUNTER_WARNING" then return end

    local encounterWarningInfo = ...
    
    -- if encounterWarningInfo then
    --     print("|cffffd100[Debug] 捕获到实时事件数据:|r")
        
    --     -- 1. 文本类
    --     print("文本 (text):", encounterWarningInfo.text)
    --     print("施法者 (casterName):", encounterWarningInfo.casterName)
    --     print("目标 (targetName):", encounterWarningInfo.targetName)
        
    --     -- 2. GUID
    --     print("施法者GUID:", encounterWarningInfo.casterGUID)
    --     print("目标GUID:", encounterWarningInfo.targetGUID)
        
    --     -- 3. 数字/ID
    --     print("图标ID (iconFileID):", encounterWarningInfo.iconFileID)
    --     print("技能ID (tooltipSpellID):", encounterWarningInfo.tooltipSpellID)
    --     print("持续时间 (duration):", encounterWarningInfo.duration)
    --     print("严重程度 (severity):", encounterWarningInfo.severity)
        
    --     -- 4. 布尔值
    --     print("是否致命 (isDeadly):", tostring(encounterWarningInfo.isDeadly))
    --     print("播放声音 (shouldPlaySound):", tostring(encounterWarningInfo.shouldPlaySound))
    --     print("聊天框消息 (shouldShowChatMessage):", tostring(encounterWarningInfo.shouldShowChatMessage))
    --     print("显示警告 (shouldShowWarning):", tostring(encounterWarningInfo.shouldShowWarning))
        
    --     -- 5. 颜色
    --     if encounterWarningInfo.color then
    --         print("颜色 (RGB):", encounterWarningInfo.color.r, encounterWarningInfo.color.g, encounterWarningInfo.color.b)
    --     else
    --         print("颜色: nil")
    --     end

    -- else
    --     print("|cffff0000[Error] 事件触发但数据为空|r")
    -- end

    -- 【安全安全防护】如果是表情事件，把纯文本字符串动态包成表，完美兼容下面的所有逻辑，防止报错
    if event == "RAID_BOSS_EMOTE" then
        encounterWarningInfo = {
            text = encounterWarningInfo, -- 此时第一个参数其实是 text 字符串
            severity = 0,
            duration = 0,
            targetName = nil
        }
    end

    if not encounterWarningInfo then return end

    -- 实时从小函数里捞取主文件内部最新的隐身 local 变量
    local currentEncounterID = addonTable.GetEncounterID()
    -- 首领语音开关：仅当关闭且正处首领战(encounterID≠0)时拦截；encounterID==0 的小怪机制(如强风)不受影响
    if not DiGuaTimelineAudioHelper.bossVoiceEnabled and currentEncounterID ~= 0 then return end
    local startTime = addonTable.GetStartTime()
    local MEDIA_PATH = addonTable.GetMediaPath() or addonTable.GetDefaultMediaPath()
    local currentMap = C_Map.GetBestMapForUnit("player")


    -- ------------------------------------------
    -- 2. 特定技能判定
    -- ------------------------------------------
    local severity = encounterWarningInfo.severity or 0
    local duration = encounterWarningInfo.duration or 0
    local targetName = encounterWarningInfo.targetName


    -- 技能：闪现新星 -- 巨力重击
    if currentEncounterID == 3497 and severity == 1 and duration == 3 and targetName then 
            addonTable.StartCircleTimerBySeconds(6.9)
        return
    end


    -- 技能：狂怒侧风
    if currentEncounterID == 3420 and severity == 1 then 
            addonTable.StartCircleTimerBySeconds(7.9)
        return
    end

    -- 技能：剧毒涌动
    if currentEncounterID == 3420 and severity == 2 then 
            addonTable.StartCircleTimerBySeconds(9.9)
        return
    end


    -- 技能：盘卷脓液
    if currentEncounterID == 3421 and severity == 1 and duration == 3.5 and targetName then 
            addonTable.StartCircleTimerBySeconds(11.9)
        return
    end

    -- 技能：强风
    if currentMap == 2514 and currentEncounterID == 0 and severity == 2 and duration == 5 and not targetName 
    and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
    and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2   
    and (GetSubZoneText() == "漫长寒冬" or GetSubZoneText() == "恆常凜冬") -- 子区域 (漫长寒冬)
    then
        addonTable.CustomEncounterBar(135857, 50, "強風")
        PlaySoundFile(MEDIA_PATH .. "KuaiZhaoYanTi.ogg", DiGuaTimelineAudioHelper.audioChannel)
        C_Timer.After(14.5, function()
            if currentEncounterID == 0 then
                PlaySoundFile(MEDIA_PATH .. "ChuiFengJieShu.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end
        end)
        return
    end


    -- 技能：幽暗炸弹
    if currentEncounterID == 3429 and severity == 1 and targetName then 
            addonTable.StartCircleTimerBySeconds(4.9)
        return
    end


    -- 技能：剧毒萎缩
    -- if currentEncounterID == 3457 and severity == 1 then
    --     print("[剧毒萎缩] severity==1 命中 → 打开开关，重置计数")
    --     addonTable.JuDuWeiSuo = true
    --     addonTable.JuDuWeiSuoCounter = 0
    --     C_Timer.After(10, function()
    --         print("[剧毒萎缩] 10秒超时 → 关闭开关")
    --         addonTable.JuDuWeiSuo = false
    --     end)
    --     return
    -- end

    -- 技能：濒死喘息
    if currentEncounterID == 3457 and severity == 2 then 
        C_Timer.After(3.9, function()
            PlaySoundFile(MEDIA_PATH .. "LaDuanLianXian.ogg", DiGuaTimelineAudioHelper.audioChannel)
        end)  
        return
    end

    -- 技能：黑暗绽放
    if currentEncounterID == 3285 and severity == 2 then 
        C_Timer.After(4, function()
            PlaySoundFile(MEDIA_PATH .. "DuoQiu.ogg", DiGuaTimelineAudioHelper.audioChannel)
        end)  
        return
    end

    -- 技能：阻断暴雨（非 战士/盗贼/死骑/猎人 且 非坦克职责 才生效）
    if currentEncounterID == 2623 and severity == 1 and not targetName then 
        local class = UnitClassBase("player")
        local spec = GetSpecialization()
        local role = spec and GetSpecializationRole(spec)

        if role ~= "TANK" and class ~= "WARRIOR" and class ~= "ROGUE" and class ~= "DEATHKNIGHT" and class ~= "HUNTER" and class ~= "PALADIN" then
            addonTable.StartCircleTimerBySeconds(4.9, true)
            C_Timer.After(1.9, function()
                PlaySoundFile(MEDIA_PATH .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end)  
            C_Timer.After(2.9, function()
                PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end)  
            C_Timer.After(3.9, function()
                PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end)  
            C_Timer.After(4.9, function()
                PlaySoundFile(MEDIA_PATH .. "AnQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end)
        end
        return
    end

    -- 技能：烈焰喷吐（仅 战士/盗贼/死骑/猎人 才生效）
    if currentEncounterID == 2623 and severity == 1 and targetName then
        local class = UnitClassBase("player")
        if class == "WARRIOR" or class == "ROGUE" or class == "DEATHKNIGHT" or class == "HUNTER" or class == "PALADIN" then
            addonTable.StartCircleTimerBySeconds(5.9)
        end
        return
    end

    -- 技能：空灵冲刺
    if currentEncounterID == 2923 and severity == 0 then
        addonTable.StartCircleTimerBySeconds(6)
        C_Timer.After(4, function()
            PlaySoundFile(MEDIA_PATH .. "KuaiKaiJianShang.ogg", DiGuaTimelineAudioHelper.audioChannel)
        end)        
        return
    end

    -- 技能：霜风
    if currentEncounterID == 2609 and severity == 1 then
        addonTable.StartCircleTimerBySeconds(4.4)
        C_Timer.After(1.5, function()
            PlaySoundFile(MEDIA_PATH .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel)
        end)
        C_Timer.After(2.5, function()
            PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel)
        end)
        C_Timer.After(3.5, function()
            PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel)
        end)
        return
    end


    -- 技能：吐金
    if currentEncounterID == 2139 and severity == 1 then
        local function SafePlay(soundFile)
            if addonTable.GetEncounterID() == 2139 then
                PlaySoundFile(MEDIA_PATH .. soundFile, audioChannel or DiGuaTimelineAudioHelper.audioChannel)
            end
        end
        C_Timer.After(4.9, function()
            SafePlay("DaoShu3.ogg")
        end)
        C_Timer.After(5.9, function()
            SafePlay("DaoShu2.ogg")
        end)
        C_Timer.After(6.9, function()
            SafePlay("DaoShu1.ogg")
        end)
        addonTable.StartCircleTimerBySeconds(7.9)
        return
    end



    -- 技能：燃烧腐蚀
    if currentEncounterID == 2142 and severity == 1 then
        addonTable.StartCircleTimerBySeconds(3.9)
        local function SafePlay(soundFile)
            if addonTable.GetEncounterID() == 2142 then
                PlaySoundFile(MEDIA_PATH .. soundFile, audioChannel or DiGuaTimelineAudioHelper.audioChannel)
            end
        end
        C_Timer.After(0.9, function()
            SafePlay("DaoShu3.ogg")
        end)
        C_Timer.After(1.9, function()
            SafePlay("DaoShu2.ogg")
        end)
        C_Timer.After(2.9, function()
            SafePlay("DaoShu1.ogg")
        end)
        return
    end



    -- 技能：元素的召唤（非 战士/盗贼/死骑/猎人 且 非坦克职责 才生效）
    if currentEncounterID == 2140 and severity == 2 and not targetName then
        local class = UnitClassBase("player")
        local spec = GetSpecialization()
        local role = spec and GetSpecializationRole(spec)

        if role ~= "TANK" and class ~= "WARRIOR" and class ~= "ROGUE" and class ~= "DEATHKNIGHT" and class ~= "HUNTER" and class ~= "PALADIN" then
            local function SafePlay(soundFile)
                if addonTable.GetEncounterID() == 2140 then
                    PlaySoundFile(MEDIA_PATH .. soundFile, audioChannel or DiGuaTimelineAudioHelper.audioChannel)
                end
            end
            -- 跟 SafePlay 一样：只有仍在 2140 战斗中才显示圆环
            local function SafeCircle()
                if addonTable.GetEncounterID() == 2140 then
                    addonTable.StartCircleTimerBySeconds(3.9, true)
                end
            end
            C_Timer.After(6.4, function()
                SafeCircle()
                SafePlay("ZhunBeiChenMo.ogg")
            end)
            C_Timer.After(7.4, function()
                SafePlay("DaoShu3.ogg")
            end)
            C_Timer.After(8.4, function()
                SafePlay("DaoShu2.ogg")
            end)
            C_Timer.After(9.4, function()
                SafePlay("DaoShu1.ogg")
            end)
            C_Timer.After(10.4, function()
                SafePlay("AnQuan.ogg")
            end)
            C_Timer.After(15.3, function()
                SafeCircle()
                SafePlay("ZhunBeiChenMo.ogg")
            end)
            C_Timer.After(16.4, function()
                SafePlay("DaoShu3.ogg")
            end)
            C_Timer.After(17.4, function()
                SafePlay("DaoShu2.ogg")
            end)
            C_Timer.After(18.4, function()
                SafePlay("DaoShu1.ogg")
            end)
            C_Timer.After(19.4, function()
                SafePlay("AnQuan.ogg")
            end)
        end
        return
    end

    -- 技能：镀金毁灭
    if currentEncounterID == 2143 and severity == 1 and not targetName then
        local function SafePlay(soundFile)
            if addonTable.GetEncounterID() == 2143 then
                PlaySoundFile(MEDIA_PATH .. soundFile, audioChannel or DiGuaTimelineAudioHelper.audioChannel)
            end
        end
        C_Timer.After(3, function()
            SafePlay("DaoShu3.ogg")
        end)
        C_Timer.After(4, function()
            SafePlay("DaoShu2.ogg")
        end)
        C_Timer.After(5, function()
            SafePlay("DaoShu1.ogg")
        end)
        return
    end

    -- 技能：寒冰暴雨
    if currentEncounterID == 3208 and severity == 2 then
        local function SafePlay(soundFile)
            if addonTable.GetEncounterID() == 3208 then
                PlaySoundFile(MEDIA_PATH .. soundFile, audioChannel or DiGuaTimelineAudioHelper.audioChannel)
            end
        end

        C_Timer.After(9, function()
            SafePlay("DaoShu3.ogg")
        end)

        C_Timer.After(10, function()
            SafePlay("DaoShu2.ogg")
        end)

        C_Timer.After(11, function()
            SafePlay("DaoShu1.ogg")
        end)
        
        C_Timer.After(12, function()
            SafePlay("AnQuan.ogg")
        end)
        return
    end


    -- 技能：魔化狂怒
    if currentEncounterID == 3103 and severity == 2 then
        -- 核心防御局部函数：只有当前依然在3103号Boss战斗中，才允许播放指定音频
        local function SafePlay(soundFile)
            if addonTable.GetEncounterID() == 3103 then
                PlaySoundFile(MEDIA_PATH .. soundFile, audioChannel or DiGuaTimelineAudioHelper.audioChannel)
            end
        end
        C_Timer.After(3.9, function()
            SafePlay("YiShangJieDuan.ogg")
        end)

        C_Timer.After(16, function()
            SafePlay("DaoShu3.ogg")
        end)

        C_Timer.After(17, function()
            SafePlay("DaoShu2.ogg")
        end)

        C_Timer.After(18, function()
            SafePlay("DaoShu1.ogg")
        end)
        
        C_Timer.After(19, function()
            SafePlay("YiShangJieShu.ogg")
        end)
        return
    end


    -- 技能：光明灌注
    if currentEncounterID == 3101 and severity == 1 then
        -- 核心防御局部函数：只有当前依然在3101号Boss战斗中，才允许播放指定音频
        local function SafePlay(soundFile)
            if addonTable.GetEncounterID() == 3101 then
                PlaySoundFile(MEDIA_PATH .. soundFile, audioChannel or DiGuaTimelineAudioHelper.audioChannel)
            end
        end


        C_Timer.After(1, function()
            SafePlay("YiShangJieDuan.ogg")
        end)

        C_Timer.After(6, function()
            SafePlay("KuaiKaiJianShang.ogg")
        end)
        -- 18秒后开始进入 3、2、1 倒计时序列
        C_Timer.After(19, function()
            SafePlay("DaoShu3.ogg")
        end)

        C_Timer.After(20, function()
            SafePlay("DaoShu2.ogg")
        end)

        C_Timer.After(21, function()
            SafePlay("DaoShu1.ogg")
        end)

        C_Timer.After(22, function()
            SafePlay("YiShangJieShu.ogg")
        end)
        
        C_Timer.After(24, function()
            if UnitGroupRolesAssigned("player") == "DAMAGER" then
                SafePlay("ZhuanHuoDaGuai.ogg")
            end
        end)
        return
    end

    -- 技能：嗜血注视
    if currentEncounterID == 3200 and severity == 2 then
        -- 核心防御局部函数：只有当前依然在3200号Boss战斗中，才允许播放指定音频
        local function SafePlay(soundFile)
            if addonTable.GetEncounterID() == 3200 then
                PlaySoundFile(MEDIA_PATH .. soundFile, audioChannel or DiGuaTimelineAudioHelper.audioChannel)
            end
        end

        -- 从第 9 秒开始进入 5、4、3、2、1 倒计时序列
        C_Timer.After(9, function()
            SafePlay("DaoShu5.ogg")
        end)

        C_Timer.After(10, function()
            SafePlay("DaoShu4.ogg")
        end)

        C_Timer.After(11, function()
            SafePlay("DaoShu3.ogg")
        end)

        C_Timer.After(12, function()
            SafePlay("DaoShu2.ogg")
        end)

        C_Timer.After(13, function()
            SafePlay("DaoShu1.ogg")
        end)

        C_Timer.After(14, function()
            SafePlay("AnQuan.ogg")
        end)
        
        return
    end

end)