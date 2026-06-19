local addonName, addonTable = ...
local frame = CreateFrame("Frame")

-- 1. 先声明变量（但不赋值）
local MEDIA_PATH

local RING_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Ring_20px.tga"
local PLAYER_LEVEL = UnitLevel("player")
local NEXT_PLAYER_LEVEL = PLAYER_LEVEL + 1
local BOSS_LEVEL = PLAYER_LEVEL + 2
local UNIT_CAST_TRACKER = {}
local unitCastTracker = {}
local auraTriggeredCache = {}
local UNIT_SUCCEEDED_AND_INTERRUPTED_TRACKER = {}
local hasPlayedSiJiaoTingYuan = false
local encounterUnitTriggerCount = 0
local UNIT_CAST_TIMER_HANDLES = {} -- 用于存储定时器句柄
local UNIT_COMBAT_START_TIMES = {} -- 记录每个怪第一次进入逻辑的时间
local UNIT_CHANNEL_TRACKER = {} -- 专门记录引导状态的表
local RING_COLOR_NORMAL = {0.4, 1, 0.8, 0.85}
local RING_COLOR_ALARM = {1, 0.2, 0.2, 0.9} -- 红色警示
local TargetEndTime = 0 -- 记录当前圆环预计结束的时间点
local CurrentRingIsCastSensitive = false -- 新增：记录当前圆环是否受施法控制
local Lindormi = false
-- 1. 定义三个公共变量（在文件顶部定义）
local ttsStartTime = {}          -- 记录开始时间
-- local ttsEndTime = {}            -- 记录结束时间
local ttsDuration = {}           -- 记录时间差（持续时长）
local MyTTSDict = {
    skill1Time = 0,
    skill2Time = 0,
    tolerance = 0.05,
    isSampled = false, -- 标记是否正在初始化采样
    sampleIndex = 0,     -- 追踪当前执行到第几个技能
    -- isListening = false, -- 公共布尔变量
}

local CastMonitor = {
    startTime = 0,
    unit = "player" -- 监控目标
}

local castStarted = false
local channelStarted = false
local buffJustTriggered = false
local AudioTriggered = false
local UNIT_TARGET_Triggered = {}
local isTrackingStopped = {}
local falizhadanTriggered = false
local ENCOUNTER_WARNING_Triggered = false
local IsTrackingUtteranceID = false
local MyCurrentLockedUtteranceID = nil
local startTime = 0
local currentEncounterID = 0
local lastPlayedSecond = -1
local isAuraRegistered = false
local activeCircleTimer = nil   -- 主计时器句柄
local backupHideTimer = nil     -- 【新增】10秒绝对保底计时器句柄
local function RegisterPrivateAuras()
    if isAuraRegistered then return end
    if not (C_UnitAuras and C_UnitAuras.AddPrivateAuraAppliedSound) then return end

    for spellID, soundFile in pairs(addonTable.PrivateAura.list) do
        C_UnitAuras.AddPrivateAuraAppliedSound({
            unitToken = "player",
            spellID = spellID,
            soundFileName = MEDIA_PATH .. soundFile .. ".ogg", 
            outputChannel = DiGuaTimelineAudioHelper.audioChannel,
        })
    end
    isAuraRegistered = true    
end

-- 职责/专精 检查函数
local function CanPlayerHear(req)
    if not req then return true end
    
    local specIndex = GetSpecialization()
    if not specIndex then return false end
    
    local _, _, _, _, role = GetSpecializationInfo(specIndex)
    local specID = GetSpecializationInfo(specIndex)
    if type(req) == "table" then
        for _, r in ipairs(req) do
            if r == role or r == specID then return true end
        end
    -- 如果要求是字符串(职责)或数字(专精ID)
    else
        if req == role or req == specID then return true end
    end
    
    return false
end

-- 获取当前玩家职责
local function GetPlayerRole()
    local specIndex = GetSpecialization()
    if specIndex then
        local _, _, _, _, role = GetSpecializationInfo(specIndex)
        return role
    end
    return "NONE"
end


local function ProcessAlert(alert, debugSource, actualLevel, currentMapID, unitTarget)
    if not alert then return end
    
    local reqLevel = type(alert) == "table" and alert.unitLevel or nil
    local reqMapID = type(alert) == "table" and alert.mapID or nil
    
    -- 提取文件名或表（用于打印）
    local alertFile = type(alert) == "table" and alert.file or alert
    local displayTitle = type(alertFile) == "table" and alertFile[1] or alertFile

    -- 【关键修改点：通用的匹配函数】
    local function CheckMatch(required, actual)
        if not required then return true end -- 如果配置没写，默认匹配成功
        if type(required) == "table" then
            for _, val in ipairs(required) do
                if val == actual then return true end
            end
            return false
        end
        return required == actual -- 如果是单个值，直接对比
    end
    -- 调试 1：开始检查某条具体配置
    -- print(string.format("|cff00ffff[检查配置]|r %s | 需要Level:%s, 需要Map:%s", displayTitle, tostring(reqLevel), tostring(reqMapID)))

    -- 使用新逻辑进行匹配
    local levelMatch = CheckMatch(reqLevel, actualLevel)
    local mapMatch = CheckMatch(reqMapID, currentMapID)

    if levelMatch and mapMatch then        
        local fileName
        if type(alertFile) == "table" then
            unitCastTracker[unitTarget] = (unitCastTracker[unitTarget] or 0) + 1
            local index = ((unitCastTracker[unitTarget] - 1) % #alertFile) + 1
            fileName = alertFile[index]
            
            -- print(string.format("|cff00ff00[循环计数]|r 次数:%d, 播放索引:%d, 文件:%s", unitCastTracker[unitTarget], index, fileName))
        else
            fileName = alertFile
        end

        if fileName and CanPlayerHear(alert.role) then
            PlaySoundFile(MEDIA_PATH .. fileName, DiGuaTimelineAudioHelper.audioChannel)
        end
    else
        -- 调试 3：匹配失败的原因
        local reason = ""
        if not levelMatch then reason = reason .. "等级不对(目标" .. actualLevel .. ") " end
        if not mapMatch then reason = reason .. "地图ID不对(目标" .. currentMapID .. ") " end
        -- print("|cffffd100[跳过条目]|r " .. displayTitle .. " | 原因: " .. reason)
    end
end

local function OnUpdate()
    if startTime == 0 then return end
    local now = GetTime()
    local elapsed = math.floor(now - startTime)
    if elapsed < 0 or elapsed == lastPlayedSecond then return end
    lastPlayedSecond = elapsed
    
    local bossData = addonTable.AudioTimeline[currentEncounterID]
    if bossData then
        local relativeTime = now - startTime - bossData.startOffset
        if relativeTime >= 0 then
            local moduloTime = relativeTime % bossData.interval
            for triggerTime, alert in pairs(bossData.alerts) do
                if moduloTime >= triggerTime and moduloTime < (triggerTime + 0.8) then
                    ProcessAlert(alert, "Timeline:"..triggerTime)
                    StartMyCircleTimer(alert)
                    break 
                end
            end
        end
    end
end

local function ApplyTimelineSounds()
    local count = 0
    local playerRole = GetPlayerRole()

    -- 清空声音的函数
    local function ClearTimelineSounds(dataTable)
        if not dataTable then return end
        for eventID, configs in pairs(dataTable) do
            -- 遍历该 ID 下的所有配置
            for _, config in ipairs(configs) do
                local triggerType = config[2]
                C_EncounterEvents.SetEventSound(eventID, triggerType, nil)
            end
        end
    end

    -- 注册声音的函数
    local function registerTable(dataTable)
        if not dataTable then return end
        
        for eventID, configs in pairs(dataTable) do
            -- 遍历该 ID 下的所有配置
            for _, config in ipairs(configs) do
                local fileName = config[1]
                local triggerType = config[2]
                local roleConfig = config[3]
                
                local isMatch = false
                
                -- 过滤逻辑
                if roleConfig == nil then
                    isMatch = true
                elseif type(roleConfig) == "table" then
                    if roleConfig[playerRole] then
                        isMatch = true
                    end
                elseif type(roleConfig) == "string" then
                    if roleConfig == playerRole then
                        isMatch = true
                    end
                end

                -- 执行注册
                if isMatch then
                    C_EncounterEvents.SetEventSound(eventID, triggerType, {
                        file = MEDIA_PATH .. fileName, 
                        channel = DiGuaTimelineAudioHelper.audioChannel, 
                        volume = 1
                    })
                    count = count + 1
                end
            end
        end
    end

    ClearTimelineSounds(addonTable.EventSoundData)
    registerTable(addonTable.EventSoundData)
    
    -- print("已根据职责成功加载 " .. count .. " 个语音事件")
end

local function GetTopWidgetText()
    local container = UIWidgetTopCenterContainerFrame
    if not container or not container.widgetFrames then return nil end

    for _, widget in pairs(container.widgetFrames) do
        -- 截图显示它有一个 .Text 属性
        if widget.Text and widget.Text:GetText() then           
            return widget.Text:GetText()
        end
    end
    return nil
end

local function GetWidgetLabelText()
    local container = UIWidgetTopCenterContainerFrame
    if not container or not container.widgetFrames then return nil end
    -- 遍历所有挂载在该容器下的 Widget
    for _, widget in pairs(container.widgetFrames) do
        -- 针对截图中的特殊层级：widget -> Label
        if widget.Bar.Label and widget.Bar.Label.GetText then
            local text = widget.Bar.Label:GetText()
            -- 排除空字符串，确保拿到有效文字
            if text and text:trim() ~= "" then
                return text
            end
        end
    end    
    return nil
end

local function FindBestVoice()
    local ttsVoices = C_VoiceChat.GetTtsVoices()
    
    -- 兜底：如果 API 连表都没返回（nil），直接给个默认值 0
    if not ttsVoices then 
        return 0 
    end
    
    for _, v in ipairs(ttsVoices) do
        -- 示例：寻找中文（Huihui）或者特定风格的声音
        -- 加一个 v.name 的非空校验，防止个别语音包数据异常
        if v.name and v.name:find("Huihui") then
            return v.voiceID
        end
    end
    
    -- 如果没找到 Huihui，尝试返回第一个语音的 ID
    if ttsVoices[1] and ttsVoices[1].voiceID then
        return ttsVoices[1].voiceID
    end

    -- 终极兜底：如果连第一个语音都没有（空表），强制返回 0
    return 0
end
-- 核心比对逻辑函数
local function ExecuteClosestLogic(measuredTime, sound1, sound2)
    local diff1 = math.abs(measuredTime - MyTTSDict.skill1Time)
    local diff2 = math.abs(measuredTime - MyTTSDict.skill2Time)
    
    if diff1 < diff2 and diff1 < MyTTSDict.tolerance and MyTTSDict.isSampled == true then
        -- print(string.format("技能 1 实际耗时: %.3f 秒", measuredTime))
        -- print("识别为：技能1 逻辑执行")
        PlaySoundFile(MEDIA_PATH .. sound1, DiGuaTimelineAudioHelper.audioChannel)
        -- 执行技能1逻辑
        if sound1 == "DuoKaiChongFeng.ogg" then
            CustomEncounterBar(4667427, 19, "躲开冲锋") -- 破军奔袭
        end
        
    elseif diff2 < diff1 and diff2 < MyTTSDict.tolerance and MyTTSDict.isSampled == true then
        -- print(string.format("技能 2 实际耗时: %.3f 秒", measuredTime))
        -- print("识别为：技能2 逻辑执行")
        PlaySoundFile(MEDIA_PATH .. sound2, DiGuaTimelineAudioHelper.audioChannel)
        if sound2 == "ZhunBeiChenMo.ogg" then
            CustomEncounterBar(852826, 24, "准备沉默") -- 干扰尖啸
        end
    else
        -- print("无法识别，误差过大")
    end
end

-- 定义全局函数
function CustomEncounterBar(iconID, duration, name)
    -- 兜底处理：防止未传参数导致报错
    iconID = iconID or 132117
    duration = duration or 10
    name = name or "未命名提示"

    -- 调用底层 API
    C_EncounterTimeline.AddScriptEvent({
        spellID = 0,                    -- 锁死为 0，防止底层代码报错
        iconFileID = iconID,
        duration = duration,
        overrideName = name,
        icons = 0x1,
        severity = 2,
        maxQueueDuration = 0,
        paused = false,
    })
end
--- 连续顺序播放音频函数
--- 支持传入任意数量的【延迟时间】和【音频文件名】组合
function PlayAudioSequence(...)
    local args = {...}
    local totalDelay = 0 -- 累计延迟时间

    -- 步长为 2 循环遍历参数（奇数项是延迟，偶数项是音频）
    for i = 1, #args, 2 do
        local delay = tonumber(args[i])
        local fileName = args[i+1]

        -- 安全检查：确保延迟是数字，且后面确实跟着一个音频文件名
        if delay and fileName then
            -- 累加前面的延迟，确保它们排队执行，而不是同时触发
            totalDelay = totalDelay + delay 
            
            -- 开启定时器排队播放
            C_Timer.After(totalDelay, function()
                -- 1. 优先使用当前确定的 MEDIA_PATH 尝试播放
                local fullPath = MEDIA_PATH .. fileName
                local willPlay = PlaySoundFile(fullPath, DiGuaTimelineAudioHelper.audioChannel)
                
                -- 2. 兜底逻辑：如果当前使用的是 WYJJ 路径且音频文件不存在（willPlay 为假/nil）
                --    则立即改用 DiGuaTimelineAudioHelper 的本地 Media 路径再试一次
                if not willPlay and MEDIA_PATH == "Interface\\AddOns\\DiGua-WYJJ\\Media\\" then
                    local fallbackPath = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\" .. fileName
                    PlaySoundFile(fallbackPath, DiGuaTimelineAudioHelper.audioChannel)
                end
            end)
        end
    end
end

-- 🛠️ 封装一个稳定获取小怪进度文本的函数
local function GetTrashProgressString()
    -- 动态遍历前 10 个索引
    for i = 1, 10 do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        -- 🎯 关键：只有小怪进度的 isWeightedProgress 才会是 true
        if info and info.isWeightedProgress then
            -- 直接返回暴雪拼好的字符串，比如 "85%"
            return info.quantityString or "0%"
        end
    end
    return "0%" -- 没找到时的兜底
end

-- 🛠️ 职责优先的特征指纹扫描仪（施法/意图/能量 强固版）
local function IsMobTargetAndPlayerFingerprintMatch(mobToken)
    -- 1. 拼接出怪的目标 Token
    local targetToken = mobToken .. "target"
    
    -- 2. 安全安检：带全量 Debug 打印的早期拦截
    if not UnitExists(targetToken) then
        -- print("|cff00ff00[地瓜指纹]|r 💨 扫描中断：该小怪当前【没有任何目标】。")
        return false
    elseif not UnitIsPlayer(targetToken) then
        local npcName = UnitName(targetToken) or "未知单位"
        -- print(string.format("|cff00ff00[地瓜指纹]|r 🤖 扫描中断：目标【%s】不是活人玩家（可能是宠物、图腾或机制NPC）。", npcName))
        return false
    end
    
    -- 基础调试变量：先抓个名字打印用
    local targetName = UnitName(targetToken) or "未知目标"
    -- print(string.format("|cff00ff00[地瓜指纹]|r 🛰️ 开始扫描小怪目标: 【%s】 (%s)", targetName, targetToken))
    
    -- =========================================================
    -- 核心优化层：职责（Role）判定（优先放最前面）
    -- =========================================================
    local targetRole = UnitGroupRolesAssigned(targetToken) or "NONE"
    local playerRole = UnitGroupRolesAssigned("player") or "NONE"
    
    -- print(string.format("|cff00ff00[地瓜指纹]|r 🎭 职责对比 -> 目标职责: [%s] | 玩家自身职责: [%s]", targetRole, playerRole))
    
    -- 【第一关】：如果职责根本对不上，直接无情拒绝
    if targetRole ~= playerRole then
        -- print("|cff00ff00[地瓜指纹]|r ❌ 职责不匹配，绝非同款，直接退出。")
        return false
    end
    
    -- 【第二关】：职责匹配成功！触发大秘境独家特权
    if targetRole == "TANK" or targetRole == "HEALER" then
        -- print(string.format("|cff00ff00[地瓜指纹]|r ✨ 触发特权 -> 目标是唯一的【%s】且与你一致，直接返回 TRUE！", targetRole))
        return true
    end
    
    -- =========================================================
    -- 精细筛查层：如果走到这里，说明大家都是 DPS (DAMAGER)
    -- =========================================================
    -- print("|cff00ff00[地瓜指纹]|r ⚔️ 目标是 DPS，启动高精细物理外壳筛查...")
    
    -- 1. 服务器判定
    local sameServer = UnitIsSameServer(targetToken)
    -- print(string.format("|cff00ff00[地瓜指纹]|r 🌐 服务器判定 -> 目标与你同服状态: [%s]", tostring(sameServer)))
    if not sameServer then
        -- print("|cff00ff00[地瓜指纹]|r ❌ 服务器指纹不一致，拦截。")
        return false
    end
    
    -- 2. 性别比对
    local targetSex = UnitSex(targetToken)
    local playerSex = UnitSex("player")
    -- print(string.format("|cff00ff00[地瓜指纹]|r 🚹 性别对比 -> 目标性别: %s | 玩家性别: %s", targetSex, playerSex))
    if targetSex ~= playerSex then 
        -- print("|cff00ff00[地瓜指纹]|r ❌ 性别不匹配，拦截。")
        return false 
    end
    
    -- 3. 职业比对
    local _, targetClass = UnitClass(targetToken)
    local _, playerClass = UnitClass("player")
    -- print(string.format("|cff00ff00[地瓜指纹]|r 🔮 职业对比 -> 目标职业: %s | 玩家职业: %s", targetClass, playerClass))
    if targetClass ~= playerClass then 
        -- print("|cff00ff00[地瓜指纹]|r ❌ 职业不匹配，拦截。")
        return false 
    end
    
    -- 4. 种族比对
    local _, targetRace = UnitRace(targetToken)
    local _, playerRace = UnitRace("player")
    -- print(string.format("|cff00ff00[地瓜指纹]|r 🧬 种族对比 -> 目标种族: %s | 玩家种族: %s", targetRace, playerRace))
    if targetRace ~= playerRace then 
        -- print("|cff00ff00[地瓜指纹]|r ❌ 种族不匹配，拦截。")
        return false 
    end
    
    -- 5. 公会与阶级深度比对
    local targetGuild, targetRankName, targetRankIndex = GetGuildInfo(targetToken)
    local playerGuild, playerRankName, playerRankIndex = GetGuildInfo("player")
    -- print(string.format("|cff00ff00[地瓜指纹]|r 🏰 公会对比 -> 目标: [%s](阶级:%s) | 玩家: [%s](阶级:%s)", 
    --     tostring(targetGuild), tostring(targetRankIndex), tostring(playerGuild), tostring(playerRankIndex)))
    
    -- 第一步：公会名字一致性检查（若双方都无公会，nil ~= nil 不成立，会允许通过进入后续专精比对）
    if targetGuild ~= playerGuild then 
        -- print("|cff00ff00[地瓜指纹]|r ❌ 公会名字不匹配，拦截。")
        return false 
    end

    -- 第二步：如果双方都在公会中，进一步精确校对公会内的职位阶级
    if targetGuild then
        -- 防御性兜底：防止大米中距离过远或底层缓存未同步，导致名字拿到了但阶级索引爆 nil
        if not targetRankIndex or not playerRankIndex then
            -- print("|cff00ff00[地瓜指纹]|r ⚠️ 阶级数据不全（缓存延迟），安全拦截。")
            return false
        end

        if targetRankIndex ~= playerRankIndex then
            -- print("|cff00ff00[地瓜指纹]|r ❌ 处于同一公会，但公会阶级职位不一致，拦截。")
            return false
        end
    end
    
    -- 6. 专精 ID 比对
    local targetSpec = GetInspectSpecialization(targetToken) or 0
    local playerSpec = GetSpecializationInfo(GetSpecialization()) or 0
    -- print(string.format("|cff00ff00[地瓜指纹]|r 📜 专精对比 -> 目标专精ID: %d | 玩家专精ID: %d", targetSpec, playerSpec))
    
    if targetSpec ~= 0 and targetSpec ~= playerSpec then
        -- print("|cff00ff00[地瓜指纹]|r ❌ 专精ID不匹配，拦截。")
        return false
    end
    
    -- =========================================================
    -- 新增筛查项 7：能量类型比对 (UnitPowerType)
    -- =========================================================
    local targetPowerID, targetPowerToken = UnitPowerType(targetToken)
    local playerPowerID, playerPowerToken = UnitPowerType("player")
    -- print(string.format("|cff00ff00[地瓜指纹]|r 🔋 能量类型对比 -> 目标: [%s](%s) | 玩家: [%s](%s)", 
        -- tostring(targetPowerToken), tostring(targetPowerID), tostring(playerPowerToken), tostring(playerPowerID)))
        
    if targetPowerID ~= playerPowerID then
        -- print("|cff00ff00[地瓜指纹]|r ❌ 能量类型主键不一致，拦截。")
        return false
    end

    -- =========================================================
    -- 新增筛查项 8：施法/引导状态存在性强校对
    -- =========================================================
    -- 检查目标是否在 读条 或 引导机制技能
    local targetIsCasting = (UnitCastingInfo(targetToken) or UnitChannelInfo(targetToken)) and true or false
    local playerIsCasting = (UnitCastingInfo("player") or UnitChannelInfo("player")) and true or false
    
    -- print(string.format("|cff00ff00[地瓜指纹]|r ⚡ 施法状态对比 -> 目标读条中: [%s] | 玩家读条中: [%s]", tostring(targetIsCasting), tostring(playerIsCasting)))
    if targetIsCasting ~= playerIsCasting then
        -- print("|cff00ff00[地瓜指纹]|r ❌ 动态施法状态不一致（时空错位），拦截。")
        return false
    end
 
    -- 🎉 突破重重重围，完全对齐！
    -- print("|cff00ff00[地瓜指纹]|r 👑 🎉 [SUCCESS] 发现同款肉体外壳，完美匹配！")
    return true
end

-- 调试工具：全指标抓取代码生成器（仅需传 unitTarget，一行行 print 输出）
function GenerateAllSpecsCodeBlock(unitTarget)
    if not UnitExists(unitTarget) then return end
    
    -- 1. 自动获取当前怪物正在施放的法术名称和 spellID
    local spellName, _, _, _, _, _, _, _, spellID = UnitCastingInfo(unitTarget)
    -- 兜底：如果没在施法，尝试获取引导法术（Channel）
    if not spellName then
        spellName, _, _, _, _, _, _, _, spellID = UnitChannelInfo(unitTarget)
    end
    spellName = spellName or "未知法术"
    local spellComment = spellName .. (spellID and (" (" .. spellID .. ")") or "")

    C_Timer.After(0.5, function()
        if not UnitExists(unitTarget) then print("❌ [错误] 0.5秒后怪物血条已消失") return end

        ------------------------------------------------------------
        -- 核心数据快照抓取
        ------------------------------------------------------------
        local currentMapID = C_Map.GetBestMapForUnit("player") or 0  
        local name = UnitName(unitTarget) or "未知"
        local actualLevel = UnitLevel(unitTarget) or 0
        local classification = UnitClassification(unitTarget) or "normal"
        local unitPowerType = UnitPowerType(unitTarget) or 0   
        local sex = UnitSex(unitTarget) or 1
        local isInside = IsIndoors()
        
        local classInfo = { UnitClass(unitTarget) }
        local className = classInfo[2] or "NONE"
        
        local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 2, "HELPFUL") 
        local inCombat = UnitAffectingCombat(unitTarget)
        local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo() or 0
        
        local creatureFamily, familyID = UnitCreatureFamily(unitTarget)
        creatureFamily = creatureFamily or "无"
        
        local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
        local stepName = (type(stepInfo) == "table" and stepInfo.title) or "无"
        local actualValue, percentValue, percentValueString = C_ScenarioInfo.GetUnitCriteriaProgressValues("target")
        
        local currentPercentText = GetTrashProgressString and GetTrashProgressString() or "0%"
        
        local hasTarget = UnitExists(unitTarget .. "target")
        local rawTargetName = UnitSpellTargetName(unitTarget) -- 保持原生返回值用于做逻辑判断
        local targetRole = UnitGroupRolesAssigned(unitTarget .. "target") or "NONE"
        
        local instName, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        instanceID = instanceID or 0
        
        local boss1Kill = C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false   
        local boss2Kill = C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false
        local boss3Kill = C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false 
        local boss4Kill = C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false

        -- 自动寻找未完成进度
        local activeCriteriaIndex = 0
        for i = 1, 4 do
            local info = C_ScenarioInfo.GetCriteriaInfo(i)
            if info and info.completed == false then
                activeCriteriaIndex = i
                break
            end
        end

        ------------------------------------------------------------
        -- 核心逻辑区分：动态决定生成的代码字符串（带中文提示尾巴）
        ------------------------------------------------------------
        -- 1. 区分法术目标 (UnitSpellTargetName)
        local spellTargetCodeStr = ""
        if rawTargetName then
            spellTargetCodeStr = "            and UnitSpellTargetName(unitTarget) -- 法术有目标"
        else
            spellTargetCodeStr = "            and not UnitSpellTargetName(unitTarget) -- 法术没目标"
        end

        -- 2. 区分目标存活状态 (UnitExists .. "target")
        local hasTargetStr = hasTarget and "UnitExists(unitTarget .. \"target\")" or "not UnitExists(unitTarget .. \"target\")"
        local hasTargetComment = hasTarget and "并且【有】目标" or "并且【没有】目标"

        ------------------------------------------------------------
        -- 2. 直接一行一行打印
        ------------------------------------------------------------
        -- 控制台提示头
        print("🎯 [当前抓取目标] => " .. name)
        print("🔮 [当前识别法术] => " .. spellComment)
        print("--------------------------------------------------")

        -- 备忘录数据块
        print("        -- [[ 📊 实时抓取快照数据备忘：")
        print("        --    级别分类: " .. classification .. " | 职业: " .. className)
        print("        --    室内状态: " .. tostring(isInside) .. " | 大秘境层数: " .. keyLevel .. " | 小怪进度: " .. tostring(currentPercentText))
        print("        --    生物家族: " .. creatureFamily)
        print("        --    战役步骤: " .. stepName .. " | 进度条数值: " .. tostring(percentValueString))
        print("        --    法术目标名字: " .. (rawTargetName or "nil") .. " | 目标职责: " .. targetRole)
        print("        --    BOSS击杀状态 -> M1: " .. tostring(boss1Kill) .. " | M2: " .. tostring(boss2Kill) .. " | M3: " .. tostring(boss3Kill) .. " | M4: " .. tostring(boss4Kill))
        print("        -- ]]\n")

        -- 纯净版运行代码块
        print("        if isAttackableNameplate")
        print("            and select(8, GetInstanceInfo()) == " .. instanceID .. " -- 副本ID (" .. (instName or "未知") .. ")")
        print("            and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL ")
        print("            and UnitPowerType(unitTarget) == " .. unitPowerType)
        print("            and UnitSex(unitTarget) == " .. sex)
        
        if activeCriteriaIndex > 0 then
            print("            and C_ScenarioInfo.GetCriteriaInfo(" .. activeCriteriaIndex .. ") ")
            print("            and C_ScenarioInfo.GetCriteriaInfo(" .. activeCriteriaIndex .. ").completed == false -- 拦截未完成步骤")
        end

        print(spellTargetCodeStr) -- 打印动态生成的带有“-- 法术有/没目标”的代码行
        print("            and " .. hasTargetStr .. " then -- " .. hasTargetComment)
        print("            C_Timer.After(0.5, function()")
        print("                if UnitExists(unitTarget) then")
        print("                    PlaySoundFile(MEDIA_PATH .. \"音频文件名.ogg\", DiGuaTimelineAudioHelper.audioChannel)")
        print("                end")
        print("            end)end")

    end)
end





frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("ENCOUNTER_WARNING")
frame:RegisterEvent("CLEAR_BOSS_EMOTES")
frame:RegisterEvent("ENCOUNTER_WARNING")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_BLOCK_STATE_CHANGED")
frame:RegisterEvent("RAID_BOSS_EMOTE")
frame:RegisterEvent("RAID_BOSS_WHISPER")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
frame:RegisterEvent("UNIT_AURA")
-- frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_STARTED")
frame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
frame:RegisterEvent("LOADING_SCREEN_DISABLED")
frame:RegisterEvent("BOSS_KILL")
frame:RegisterEvent("UNIT_TARGET")
frame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
-- frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
-- frame:RegisterEvent("UNIT_FLAGS")
frame:RegisterEvent("UNIT_COMBAT")
-- frame:RegisterEvent("UNIT_DIED")

-- frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID = ...
        encounterUnitTriggerCount = 0
        currentEncounterID = encounterID
        startTime = GetTime()
        lastPlayedSecond = -1
        frame:SetScript("OnUpdate", OnUpdate)
        -- 延迟 0.01 秒执行
        C_Timer.After(0.01, function()
            ApplyTimelineSounds()
        end)
        -- print("|cFF00FF00[神秘地瓜副本语音插件]|r 已加载")
    elseif event == "ENCOUNTER_END" then
        startTime = 0
        currentEncounterID = 0
        frame:SetScript("OnUpdate", nil)
        -- print("|cFF00FF00[TimelineAudio]|r 战斗结束")
        return

    elseif event == "VOICE_CHAT_TTS_PLAYBACK_STARTED" then
        utteranceID = ...

        if IsTrackingUtteranceID then
            IsTrackingUtteranceID = false       -- 捕获成功，立刻关闭开关
            MyCurrentLockedUtteranceID = utteranceID  -- 把 ID 锁进变量里
            -- print("🔊 抓到了！当前圆圈绑定的 TTS ID 是:", MyCurrentLockedUtteranceID)
        else
            -- print("监听未开启")
        end
        -- print(utteranceID)
        ttsStartTime[utteranceID] = GetTime() -- 记录当前精确时间
        return
    elseif event == "VOICE_CHAT_TTS_PLAYBACK_FINISHED" then
        utteranceID = ...
        -- print(utteranceID)
        ttsDuration[utteranceID] = GetTime() - ttsStartTime[utteranceID]
        -- print(ttsDuration[utteranceID])
        -- 如果开关没开，说明这次 TTS 播放不是由我们的插件触发的，直接拦截
        -- if not MyTTSDict.isListening then return end
        -- 仅在采样模式下进行赋值
        if MyTTSDict.isSampled == false then
            if MyTTSDict.sampleIndex == 1 then
                MyTTSDict.skill1Time = ttsDuration[utteranceID]
                -- print(string.format("技能 1 采样完成: %.3f 秒", ttsDuration[utteranceID]))
            elseif MyTTSDict.sampleIndex == 2 then
                MyTTSDict.skill2Time = ttsDuration[utteranceID]
                -- print(string.format("技能 2 采样完成: %.3f 秒", ttsDuration[utteranceID]))
                MyTTSDict.isSampled = true
                MyTTSDict.sampleIndex = 0
                -- print("TTS 技能指纹预存完成")
            end
        else
            local subZone = GetSubZoneText()
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            if select(8, GetInstanceInfo()) == 2805 and currentMapID == 2498 and (subZone == "幽灵悲歌" or subZone == "亡靈悲悼") then 
                ExecuteClosestLogic(ttsDuration[utteranceID], "DuoKaiChongFeng.ogg", "ZhunBeiChenMo.ogg")
            end
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        wipe(unitCastTracker) 
        return
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_STOP" then
        local unitTarget = ...
        if unitTarget == "player" then
            UpdateRingColor(false)
        end
    --     -- 获取该 unit 对应的姓名板框架
    --     local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
        
    --     if nameplate then
    --         -- 如果之前没创建过文字，就创建一个
    --         if not nameplate.BigText then
    --             nameplate.BigText = nameplate:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    --             -- 设置字体、大小、描边 (参数：路径, 大小, 描边)
    --             nameplate.BigText:SetFont(STANDARD_TEXT_FONT, 80, "OUTLINE")
    --             nameplate.BigText:SetPoint("BOTTOM", nameplate, "TOP", 0, 10)
    --             nameplate.BigText:SetTextColor(1, 0, 0) -- 红色
    --         end
            
    --         -- 设置文字内容并显示
    --         nameplate.BigText:SetText("快断！！！")
    --         nameplate.BigText:Show()
            
    --         -- (可选) 3秒后自动隐藏
    --         C_Timer.After(3, function() 
    --             if nameplate.BigText then nameplate.BigText:Hide() end 
    --         end)
    --     end
    --     return
    elseif event == "UNIT_AURA" then
        local unitTarget, updateInfo = ...
        local subZone = GetSubZoneText()
        local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
        local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
        -- 2. 基础条件过滤：必须有数据、目标是玩家、处于特定 Boss 战
        if unitTarget and unitTarget:find("player") and currentEncounterID == 2562 then -- 维克萨姆斯
            if updateInfo and not updateInfo.isFullUpdate and updateInfo.addedAuras then       
                -- 5. 遍历本次事件中所有【新添加】的 Aura
                for _, auraData in ipairs(updateInfo.addedAuras) do                    
                    -- 6. 判断是否是 debuff 
                    -- print(falizhadanTriggered)  
                    if auraData.isHarmful and falizhadanTriggered == true then
                        -- print("成功")                
                        StartCircleTimerBySeconds(4)
                        PlayAudioSequence(0, "TieBianFangShui.ogg", 1,"DaoShu3.ogg", 1,"DaoShu2.ogg", 1,"DaoShu1.ogg")
                        break 
                    end
                end
            end
        end
        if unitTarget and unitTarget:find("player") and instanceID == 1209 and currentEncounterID == 0 then -- 通天峰
            if updateInfo and not updateInfo.isFullUpdate and updateInfo.addedAuras then       
                
                -- 1. 获取玩家自己施加给自己的 HARMFUL 光环的唯一 ID 列表
                local playerCastAuraInstanceIDsTest = {}
                local playerCastAuraInstanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL|PLAYER")
                if playerCastAuraInstanceIDs then
                    for _, auraInstanceID in ipairs(playerCastAuraInstanceIDs) do
                        playerCastAuraInstanceIDsTest[auraInstanceID] = true
                    end
                end

                -- 5. 遍历本次事件中所有【新添加】的 Aura
                for _, auraData in ipairs(updateInfo.addedAuras) do                    
                    -- 6. 判断是否是 debuff 
                    if auraData.isHarmful and castStarted == true then
                        
                        -- 2. 检查当前新加的 debuff 是否不在刚才建立的“自身施加”表中（即过滤掉自身施加）
                        if not playerCastAuraInstanceIDsTest[auraData.auraInstanceID] then
                            -- print("成功")
                            if AudioTriggered == false then
                                AudioTriggered = true
                                PlayAudioSequence(0, "LiuXue.ogg", 1,"KuaiKaiJianShang.ogg")
                                castStarted = false
                                C_Timer.After(5, function()
                                    AudioTriggered = false
                                end)
                            end                                             
                            break 
                        end
                    end
                end
            end
        end
        if unitTarget and unitTarget:find("player") and instanceID == 1209 then -- 通天峰
            if updateInfo and not updateInfo.isFullUpdate and updateInfo.addedAuras then       
                
                -- 1. 获取玩家自己施加给自己的 HARMFUL 光环的唯一 ID 列表
                local playerCastAuraInstanceIDsTest = {}
                local playerCastAuraInstanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL|PLAYER")
                if playerCastAuraInstanceIDs then
                    for _, auraInstanceID in ipairs(playerCastAuraInstanceIDs) do
                        playerCastAuraInstanceIDsTest[auraInstanceID] = true
                    end
                end

                -- 5. 遍历本次事件中所有【新添加】的 Aura
                for _, auraData in ipairs(updateInfo.addedAuras) do                    
                    -- 6. 判断是否是 debuff 
                    if auraData.isHarmful and channelStarted == true then
                        
                        -- 2. 检查当前新加的 debuff 是否不在刚才建立的“自身施加”表中（即过滤掉自身施加）
                        if not playerCastAuraInstanceIDsTest[auraData.auraInstanceID] then
                            -- print("成功")
                            if AudioTriggered == false then
                                AudioTriggered = true
                                PlayAudioSequence(0, "KuaiKaiJianShang.ogg") -- 日光烈焰
                                channelStarted = false
                                C_Timer.After(5, function()
                                    AudioTriggered = false
                                end)
                            end                                             
                            break 
                        end
                    end
                end
            end
        end
        if unitTarget and unitTarget:find("player") and instanceID == 658 then -- Pit of Saron
            if updateInfo and not updateInfo.isFullUpdate and updateInfo.addedAuras then       
                
                -- 1. 获取玩家自己施加给自己的 HARMFUL 光环的唯一 ID 列表
                local playerCastAuraInstanceIDsTest = {}
                local playerCastAuraInstanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL|PLAYER")
                if playerCastAuraInstanceIDs then
                    for _, auraInstanceID in ipairs(playerCastAuraInstanceIDs) do
                        playerCastAuraInstanceIDsTest[auraInstanceID] = true
                    end
                end
                -- 5. 遍历本次事件中所有【新添加】的 Aura
                for _, auraData in ipairs(updateInfo.addedAuras) do                    
                    -- 6. 判断是否是 debuff 
                    if auraData.isHarmful and channelStarted == true then
                        
                        -- 2. 检查当前新加的 debuff 是否不在刚才建立的“自身施加”表中（即过滤掉自身施加）
                        if not playerCastAuraInstanceIDsTest[auraData.auraInstanceID] then
                            -- print("成功")
                            if AudioTriggered == false then
                                AudioTriggered = true
                                PlayAudioSequence(0, "WuYaoDianNi.ogg") -- 苦难洪流
                                channelStarted = false -- 保险
                                C_Timer.After(5, function()
                                    AudioTriggered = false
                                end)
                            end                                             
                            break 
                        end
                    end
                end
            end
        end
        if unitTarget and unitTarget:find("player") and instanceID == 1753 then -- 执政团之座
            if updateInfo and not updateInfo.isFullUpdate and updateInfo.addedAuras then 
                local playerCastAuraInstanceIDsTest = {}
                local playerCastAuraInstanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL|PLAYER")
                if playerCastAuraInstanceIDs then
                    for _, auraInstanceID in ipairs(playerCastAuraInstanceIDs) do
                        playerCastAuraInstanceIDsTest[auraInstanceID] = true
                    end
                end
                for _, auraData in ipairs(updateInfo.addedAuras) do
                    C_Timer.After(0.05, function()
                        -- 6. 判断是否是 debuff 
                        if auraData.isHarmful and channelStarted == true then                            
                            -- 2. 检查当前新加的 debuff 是否不在刚才建立的“自身施加”表中（即过滤掉自身施加）
                            if not playerCastAuraInstanceIDsTest[auraData.auraInstanceID] then
                                -- print("成功")
                                if AudioTriggered == false then
                                    AudioTriggered = true
                                    PlayAudioSequence(0, "JiGuangDianNi.ogg") -- 虚空灌输
                                    channelStarted = false -- 保险
                                    C_Timer.After(5, function()
                                        AudioTriggered = false
                                    end)
                                end                                             
                            end
                        end
                    end)
                end
            end
        end




        if unitTarget and unitTarget:find("player") and instanceID == 1753 and currentEncounterID == 2066 and UnitGroupRolesAssigned("player") ~= "TANK" then -- 执政团之座  萨普瑞什
            local keystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo() or 0
            if updateInfo and not updateInfo.isFullUpdate and updateInfo.addedAuras and keystoneLevel >= 12 then       
                
                -- 1. 获取玩家自己施加给自己的 HARMFUL 光环的唯一 ID 列表
                local playerCastAuraInstanceIDsTest = {}
                local playerCastAuraInstanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL|PLAYER")
                if playerCastAuraInstanceIDs then
                    for _, auraInstanceID in ipairs(playerCastAuraInstanceIDs) do
                        playerCastAuraInstanceIDsTest[auraInstanceID] = true
                    end
                end

                -- 5. 遍历本次事件中所有【新添加】的 Aura
                for _, auraData in ipairs(updateInfo.addedAuras) do                    
                    -- 6. 判断是否是 debuff 
                    if auraData.isHarmful then
                        
                        -- 2. 检查当前新加的 debuff 是否不在刚才建立的“自身施加”表中（即过滤掉自身施加）
                        if not playerCastAuraInstanceIDsTest[auraData.auraInstanceID] then
                            -- print("成功")
                            if AudioTriggered == false then
                                AudioTriggered = true
                                PlayAudioSequence(0, "LiuXue.ogg", 1,"KuaiKaiJianShang.ogg")
                                castStarted = false
                                C_Timer.After(5, function()
                                    AudioTriggered = false
                                end)
                            end                                             
                            break 
                        end
                    end
                end
            end
        end





        if unitTarget and unitTarget:find("player") and instanceID == 2915 then -- 节点希纳斯
            if updateInfo and not updateInfo.isFullUpdate and updateInfo.addedAuras then 
                local playerCastAuraInstanceIDsTest = {}
                local playerCastAuraInstanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL|PLAYER")
                if playerCastAuraInstanceIDs then
                    for _, auraInstanceID in ipairs(playerCastAuraInstanceIDs) do
                        playerCastAuraInstanceIDsTest[auraInstanceID] = true
                    end
                end
                for _, auraData in ipairs(updateInfo.addedAuras) do
                    C_Timer.After(0.05, function()
                        -- 6. 判断是否是 debuff 
                        if auraData.isHarmful and castStarted == true then                            
                            -- 2. 检查当前新加的 debuff 是否不在刚才建立的“自身施加”表中（即过滤掉自身施加）
                            if not playerCastAuraInstanceIDsTest[auraData.auraInstanceID] then
                                -- print("成功")
                                if AudioTriggered == false then
                                    AudioTriggered = true
                                    PlayAudioSequence(0, "KuaiKaiJianShang.ogg")
                                    castStarted = false -- 保险
                                    C_Timer.After(5, function()
                                        AudioTriggered = false
                                    end)
                                end                                             
                            end
                        end
                    end)
                end
            end
        end


        if unitTarget and unitTarget:find("player") and instanceID == 1209 and currentEncounterID == 1701 and UnitGroupRolesAssigned("player") == "DAMAGER" then -- 通天峰
            if updateInfo and not updateInfo.isFullUpdate and updateInfo.addedAuras then 
                local playerCastAuraInstanceIDsTest = {}
                local playerCastAuraInstanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL|PLAYER")
                if playerCastAuraInstanceIDs then
                    for _, auraInstanceID in ipairs(playerCastAuraInstanceIDs) do
                        playerCastAuraInstanceIDsTest[auraInstanceID] = true
                    end
                end
                for _, auraData in ipairs(updateInfo.addedAuras) do
                    C_Timer.After(0.3, function()
                        -- 6. 判断是否是 debuff 
                        if auraData.isHarmful and castStarted == true then                            
                            -- 2. 检查当前新加的 debuff 是否不在刚才建立的“自身施加”表中（即过滤掉自身施加）
                            if not playerCastAuraInstanceIDsTest[auraData.auraInstanceID] then
                                -- print("成功")
                                if AudioTriggered == false then
                                    AudioTriggered = true
                                    StartCircleTimerBySeconds(2.7, false)
                                    PlayAudioSequence(0, "JiGuangDianNi.ogg") -- 眩光
                                    castStarted = false -- 保险
                                    C_Timer.After(5, function()
                                        AudioTriggered = false
                                    end)
                                end                                             
                            end
                        end
                    end)
                end
            end
        end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "护核虚无结界" or subZone == "核心防禦空無結界" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 and currentEncounterID == 0 then
                    -- 【核心判断】：确保 updateInfo 存在且不是全量刷新，并且本次事件有新增的光环
                    if updateInfo and not updateInfo.isFullUpdate and updateInfo.addedAuras then
                        -- 遍历本次增量更新中所有【新添加】的光环
                        for _, auraData in ipairs(updateInfo.addedAuras) do
                            -- 判断光环类型
                            if not auraData.isHarmful then
                                if buffJustTriggered == false then
                                    buffJustTriggered = true
                                    -- print("检测到薛定谔的哨兵获得【增益 Buff】，脉冲锁激活！")
                                    C_Timer.After(1, function()
                                        buffJustTriggered = false
                                    end)
                                end
                            end
                        end
                    end
                    return
                end
            end               
        end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if (subZone == "风行者宝库" or subZone == "風行者寶庫") and keyLevel >= 12 then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)
                local auraData2 = C_UnitAuras.GetAuraDataByIndex(unitTarget, 2, "HELPFUL") 
                local auraData3 = C_UnitAuras.GetAuraDataByIndex(unitTarget, 3, "HELPFUL") 
                local auraCheck = false
                if Lindormi == false then
                    auraCheck = auraData2
                else
                    auraCheck = auraData3
                end
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2498 and unitPowerType == 0 and auraCheck then
                    if not auraTriggeredCache[unitTarget] then
                        PlaySoundFile(MEDIA_PATH .. "JiNu.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        auraTriggeredCache[unitTarget] = true
                    end
                    return
                end
            end                
        end
        return
    elseif event == "UNIT_TARGET" then
        local unitTarget = ...
        local subZone = GetSubZoneText()
        -- if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
        --     local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
        --     if instanceID == 2811 then -- 魔导师平台
        --         local actualLevel = UnitLevel(unitTarget)
        --         local unitPowerType = UnitPowerType(unitTarget)    
        --         local sex = UnitSex(unitTarget)
        --         local scenarioCriteriaInfo = C_ScenarioInfo.GetCriteriaInfo(1)
        --         if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 3 and scenarioCriteriaInfo and scenarioCriteriaInfo.completed == true then -- 奥能金刚库斯托斯
        --             local targetsPlayer = PlayerIsSpellTarget(unitTarget, "player")
        --             local PlayerRole = GetPlayerRole()
        --             UNIT_TARGET_Triggered[unitTarget] = true
        --             C_Timer.After(1.6, function()
        --                 UNIT_TARGET_Triggered[unitTarget] = nil
        --                 return
        --             end)                    
        --         end
        --     end                
        -- end
        -- print(unitTarget)
        -- print(UnitCanAttack("player", unitTarget))

    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        local subZone = GetSubZoneText()
        if (subZone == "四角庭院" or subZone == "學院中庭") and not hasPlayedSiJiaoTingYuan then
            PlaySoundFile(MEDIA_PATH .. "XuanZeZengYi.ogg", DiGuaTimelineAudioHelper.audioChannel)
            hasPlayedSiJiaoTingYuan = true
        end
        return

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...  
        if unit and unit:find("nameplate") and UnitCanAttack("player", unit) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            if currentMapID == 184 and keyLevel >= 12 then                   
                local actualLevel = UnitLevel(unit)
                local classification = UnitClassification(unit)
                local unitPowerType = UnitPowerType(unit)   
                local sex = UnitSex(unit)
                local auraData = C_UnitAuras.GetAuraDataByIndex(unit, 3, "HELPFUL")                 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 2 and auraData then     
                    Lindormi = true
                    return
                end
            end         
        end
        if unit and unit:find("nameplate") and UnitCanAttack("player", unit) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            local subZone = GetSubZoneText()
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            if currentMapID == 2492 and (subZone == "幽灵悲歌" or subZone == "亡靈悲悼") and keyLevel >= 12 then                   
                local actualLevel = UnitLevel(unit)
                local classification = UnitClassification(unit)
                local unitPowerType = UnitPowerType(unit)   
                local sex = UnitSex(unit)
                local auraData = C_UnitAuras.GetAuraDataByIndex(unit, 2, "HELPFUL")                 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and classification == "elite" and sex == 2 and auraData then     
                    Lindormi = true
                    return
                end
            end         
        end

    elseif event == "UNIT_SPELLCAST_START" then
        -- print("当前机制文字: " .. (GetTopWidgetText() or "没找到"))
        -- UnitAffectingCombat(unit)
        local unitTarget = ...
        local subZone = GetSubZoneText()   
        local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(unitTarget)
        local isAttackableNameplate = unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget)
        -- if isAttackableNameplate then
        --     GenerateAllSpecsCodeBlock(unitTarget)
        -- end
        
        -- local targetToken = unitTarget .. "target"
        -- if UnitIsUnit(targetToken, "player") then
        --     print("目标是玩家")
        -- else
        --     print("不是玩家")
        -- end

        -- local spellInfo = C_Spell.GetSpellInfo(spellID)
        -- -- 获取事件信息
        -- local eventID = 66
        -- local info = C_EncounterEvents.GetEventInfo(eventID)
        
        -- if info then
        --     print("|cffffd100[Debug] 事件 " .. eventID .. " 数据详情:|r")
            
        --     -- 文本类
        --     print("文本 (text):", info.text)
        --     print("施法者 (casterName):", info.casterName)
        --     print("目标 (targetName):", info.targetName)
            
        --     -- GUID
        --     print("施法者GUID:", info.casterGUID)
        --     print("目标GUID:", info.targetGUID)
            
        --     -- 数字/ID
        --     print("图标文件ID (iconFileID):", info.iconFileID)
        --     print("技能ID (tooltipSpellID):", info.tooltipSpellID)
        --     print("持续时间 (duration):", info.duration)
        --     print("严重程度 (severity):", info.severity)
            
        --     -- 布尔值 (使用 tostring 强制显示 true/false/nil)
        --     print("是否致命 (isDeadly):", tostring(info.isDeadly))
        --     print("播放声音 (shouldPlaySound):", tostring(info.shouldPlaySound))
        --     print("聊天框消息 (shouldShowChatMessage):", tostring(info.shouldShowChatMessage))
        --     print("显示警告 (shouldShowWarning):", tostring(info.shouldShowWarning))
            
        --     -- 颜色处理
        --     if info.color then
        --         print("颜色 (RGB):", info.color.r, info.color.g, info.color.b)
        --     else
        --         print("颜色: nil")
        --     end
        -- else
        --     print("|cffff0000[Error] 无法获取事件 " .. eventID .. " 的信息，请确认 ID 是否正确。|r")
        -- end



        -- -- 检查是否有在读条
        -- if name then
        --     print("--- 施法详情 ---")
        --     print("1. 技能名称 (name):", name)
        --     print("2. 进度条文字 (text):", text)
        --     print("3. 图标路径 (texture):", texture)
        --     print("4. 开始时间 (startTimeMS):", startTimeMS) -- 绝对时间(毫秒)
        --     print("5. 结束时间 (endTimeMS):", endTimeMS)     -- 绝对时间(毫秒)
        --     print("6. 专业制造 (isTradeSkill):", isTradeSkill)
        --     print("7. 施法唯一ID (castID):", castID)
        --     print("8. 不可打断 (notInterruptible):", notInterruptible)
        --     print("9. 技能ID (spellID):", spellID)

        -- end

        if unitTarget == "player" and endTimeMS and CurrentRingIsCastSensitive then
            -- 【双重保险】只有当前时间还处于圆环倒计时内，才处理颜色和声音
            if GetTime() < TargetEndTime then
                local castEndTime = endTimeMS / 1000
                -- 如果玩家读条结束时间 晚于 圆环结束时间
                if not notInterruptible and castEndTime > TargetEndTime then
                    UpdateRingColor(true)
                else
                    UpdateRingColor(false)
                end
            else
                -- 如果时间已经过了，说明圆环该结束了，直接重置标记
                CurrentRingIsCastSensitive = false
            end
        end
        -- local currentMapID = C_Map.GetBestMapForUnit("player") or 0  
        -- local name = UnitName(unitTarget) or "未知"
        -- local actualLevel = UnitLevel(unitTarget)
        -- local classification = UnitClassification(unitTarget)
        -- local unitPowerType = UnitPowerType(unitTarget)   
        -- local sex = UnitSex(unitTarget)
        -- local isInside = IsIndoors()
        -- local classInfo = { UnitClass(unitTarget) }
        -- local className = classInfo[2]
        -- local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 2, "HELPFUL") 
        -- local inCombat = UnitAffectingCombat(unitTarget)
        -- local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
        -- local creatureFamily, familyID = UnitCreatureFamily(unitTarget)
        -- local maxhealthMod = GetUnitMaxHealthModifier(unitTarget)
        -- local raceID = UnitRace(unitTarget)
        -- local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
        -- local actualValue, percentValue, percentValueString = C_ScenarioInfo.GetUnitCriteriaProgressValues("target")
        -- local getWidgetLabelText = GetWidgetLabelText()
        -- local hasTarget -- 先在外面声明变量
        -- C_Timer.After(0.5, function() hasTarget = UnitExists(unitTarget .. "target") end)
        -- local targetName = UnitSpellTargetName(unitTarget)
        -- local targetsPlayer = PlayerIsSpellTarget(unitTarget, "player")
        -- local currentPercentText = GetTrashProgressString()
        -- print("📊 当前小怪进度百分比（文字）：", currentPercentText) 
        -- local scenarioCriteriaInfo = C_ScenarioInfo.GetCriteriaInfo(1)
        -- local boss1Kill = C_ScenarioInfo.GetCriteriaInfo(1).completed    
        -- local boss2Kill = C_ScenarioInfo.GetCriteriaInfo(2).completed
        -- local boss3Kill = C_ScenarioInfo.GetCriteriaInfo(3).completed 
        -- local boss4Kill = C_ScenarioInfo.GetCriteriaInfo(4).completed
        -- local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
        -- local targetRole = UnitGroupRolesAssigned(unitTarget .. "target")
        -- print(targetsPlayer)
        -- print(getWidgetLabelText)
        -- print(name .. " | 等级: " .. actualLevel .. " | 区域: " .. subZone .. " | 地图ID: ".. currentMapID .. " | 分类: " .. classification .. " | 能量类型: " .. unitPowerType .. " | 性别: " .. sex .. " | 室内: " .. tostring(isInside) .. " | 职业: " .. className .. " | 存在两个增益: " .. (auraData and "是" or "否") .. " | 法术加速: " .. spellHastePercent .. " | 生物家族: " .. tostring(creatureFamily))
        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "下层平台" or subZone == "主峰" or subZone == "山崁" or subZone == "巍峨峰" then
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)   
                local creatureFamily, familyID = UnitCreatureFamily(unitTarget)
                if not creatureFamily and actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    local PlayerRole = GetPlayerRole()
                    if targetName then
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKePoJia.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 剪切
                            CustomEncounterBar(4635276, 26.5, "坦克破甲")
                            if PlayerRole == "TANK" then
                                StartCircleTimerBySeconds(3)
                            end                                
                        end
                    else
                        C_Timer.After(1.95, function()                            
                            if PlayerRole == "HEALER" then
                                PlaySoundFile(MEDIA_PATH .. "DanShuaLiuXue.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 刀锋冲刺
                                CustomEncounterBar(1035036, 26.5, "单刷流血")
                            end
                            if PlayerRole == "DAMAGER" then
                                -- print("castStarted = true")
                                castStarted = true
                                C_Timer.After(1.4, function()
                                    castStarted = false
                                end)                          
                            end
                        end)
                    end
                end            
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "下层平台" or subZone == "主峰" or subZone == "山崁" or subZone == "巍峨峰" then 
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget) 
                local creatureFamily, familyID = UnitCreatureFamily(unitTarget)                
                if creatureFamily and actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    if targetName then
                        -- print("")
                    else
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        CustomEncounterBar(132372, 28, "准备AOE")
                    end
                    return
                end            
            end
        end
        -- 死亡印记
        if subZone == "眺望台" and isAttackableNameplate and UnitLevel(unitTarget) == PLAYER_LEVEL and UnitPowerType(unitTarget) == 0 then PlaySoundFile(MEDIA_PATH .. "KongDuanDaGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            if instanceID == 1209 then -- 通天峰  
                local actualLevel = UnitLevel(unitTarget)
                local sex = UnitSex(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    local targetsPlayer = PlayerIsSpellTarget(unitTarget, "player")
                    if targetName then
                        if GetPlayerRole() ~= "TANK" then
                            StartCircleTimerBySeconds(2, false, targetsPlayer)
                            C_Timer.After(0.5, function()
                                if IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true then
                                    PlaySoundFile(MEDIA_PATH .. "JiGuangDianNi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 日光烈焰
                                end
                            end)
                            -- C_Timer.After(0.6, function()
                            --     if MyCurrentLockedUtteranceID and ttsDuration[MyCurrentLockedUtteranceID] then
                            --         -- print("不播报")
                            --     else
                            --         PlaySoundFile(MEDIA_PATH .. "JiGuangDianNi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 日光烈焰
                            --         -- print("播报")
                            --     end
                            --     -- print(ttsDuration[currentUtteranceID])
                            -- end)
                        end                       
                        -- if GetPlayerRole() == "HEALER" then
                        --     PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        -- end
                    else
                        C_Timer.After(0.2, function()
                            local hasTarget = UnitExists(unitTarget .. "target")
                            if hasTarget then
                                C_Timer.After(1.8, function()
                                    if GetPlayerRole() ~= "HEALER" then
                                        PlaySoundFile(MEDIA_PATH .. "ZhuanHuoBaoZhu.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 太阳宝珠
                                    end
                                end)                                
                            else
                                PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 日光新星
                            end
                        end)
                    end   
                end
            end               
        end

        -- 虚空爆发
        if C_Map.GetBestMapForUnit("player") == 184 and isAttackableNameplate and UnitLevel(unitTarget) == PLAYER_LEVEL and UnitPowerType(unitTarget) == 0 and UnitSex(unitTarget) == 2 and UnitClassification(unitTarget) == "elite" and not UnitSpellTargetName(unitTarget) then PlaySoundFile(MEDIA_PATH .. "XuKongBaoFa.ogg", DiGuaTimelineAudioHelper.audioChannel) return end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            if currentMapID == 184 and keyLevel >= 12 and Lindormi == false then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local sex = UnitSex(unitTarget)
                local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 2, "HELPFUL") 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 2 and auraData then                    
                    -- local castInfo = { UnitCastingInfo(unitTarget) }
                    -- local spellName = castInfo[1]
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "TANK" then
                        PlaySoundFile(MEDIA_PATH .. "HanBingChongJi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 寒冰冲击
                    end                    
                    return
                end
            end         
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if currentEncounterID == 2000 then   -- 天灾领主泰兰努斯
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget) 
                if actualLevel == PLAYER_LEVEL and classification == "elite" then
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "TANK" or PlayerRole == "DAMAGER" then
                        UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1
                        local remainder = UNIT_CAST_TRACKER[unitTarget] % 3
                        if remainder == 1 and AudioTriggered == false then
                            PlaySoundFile(MEDIA_PATH .. "YiDaDuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                            AudioTriggered = true
                            C_Timer.After(5, function()
                                AudioTriggered = false
                            end)
                        elseif remainder == 2 and AudioTriggered == false then
                            PlaySoundFile(MEDIA_PATH .. "ErDaDuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                            AudioTriggered = true
                            C_Timer.After(6, function()
                                AudioTriggered = false
                            end)
                        elseif remainder == 0 and AudioTriggered == false then
                            PlaySoundFile(MEDIA_PATH .. "SanDaDuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                            AudioTriggered = true
                            C_Timer.After(6, function()
                                AudioTriggered = false
                            end)
                        end
                        return
                    end             
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            if currentMapID == 184 and keyLevel >= 12 then 
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local sex = UnitSex(unitTarget)
                local auraData2 = C_UnitAuras.GetAuraDataByIndex(unitTarget, 2, "HELPFUL") 
                local auraData3 = C_UnitAuras.GetAuraDataByIndex(unitTarget, 3, "HELPFUL") 
                local auraCheck = false
                if Lindormi == false then
                    auraCheck = not auraData2
                else
                    auraCheck = not auraData3
                end
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 2 and auraCheck then 
                    local targetName = UnitSpellTargetName(unitTarget)
                    if targetName then
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel)
                            CustomEncounterBar(1476273, 19, "坦克尖刺") -- 冰霜猛袭
                        end
                    end     
                end
            end         
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            if currentMapID == 184 then 
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 2 then 
                    local targetName = UnitSpellTargetName(unitTarget)
                    if not targetName then
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 黑暗裂口
                    end     
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if currentEncounterID == 2001 then 
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local sex = UnitSex(unitTarget)
                if actualLevel == BOSS_LEVEL and unitPowerType == 3 and sex == 2 then 
                    local targetName = UnitSpellTargetName(unitTarget)
                    local PlayerRole = GetPlayerRole()
                    if targetName and PlayerRole ~= "HEALER" then
                        PlayAudioSequence(1, "DaDuanBoss.ogg") -- 湮灭之箭
                    end
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "" or subZone == "艾杰斯亚学院" or subZone == "阿爾蓋薩學院" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local isInside = IsIndoors()
                local scenarioCriteriaInfo = C_ScenarioInfo.GetCriteriaInfo(2)
                if UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL and (currentMapID == 2097 or currentMapID == 2098) and unitPowerType == 1 and sex == 1 and isInside == false and scenarioCriteriaInfo and scenarioCriteriaInfo.completed == true then -- 茂林古树
                    C_Timer.After(0.4, function()
                        local hasTarget = UnitExists(unitTarget .. "target")
                        local targetsPlayer = PlayerIsSpellTarget(unitTarget, "player")
                        if hasTarget then
                            PlaySoundFile(MEDIA_PATH .. "ZhunBeiTiaoRen.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 邪恶伏击
                            CustomEncounterBar(132089, 18, "准备跳人")
                            StartCircleTimerBySeconds(3.1, false, targetsPlayer)
                            C_Timer.After(0.8, function()
                                if addonTable.PlayerSpellStatus.spells[58984] == true and IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true then -- 影遁
                                    PlaySoundFile(MEDIA_PATH .. "YingDun.ogg", DiGuaTimelineAudioHelper.audioChannel)
                                end
                            end)
                        else
                            PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 裂隙之息
                        end
                    end)
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if currentEncounterID == 2563 then -- 茂林古树 
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)  
                if actualLevel == PLAYER_LEVEL and unitPowerType == 0 then
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "TANK" or PlayerRole == "DAMAGER" then
                            PlaySoundFile(MEDIA_PATH .. "DaDuanDaGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 治疗之触
                        end
                    return
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "艾杰斯亚学院" or subZone == "阿爾蓋薩學院" then
                if UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL and C_Map.GetBestMapForUnit("player") == 2098 and UnitPowerType(unitTarget) == 1 and UnitSex(unitTarget) == 1 then
                    if UnitSpellTargetName(unitTarget) then
                        if GetPlayerRole() == "TANK" or GetPlayerRole() == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 风暴斩击
                        end
                    else
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 驱除闯入者 和 致命狂风
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "体育场" or subZone == "運動場" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2098 then
                    C_Timer.After(0.3, function()
                        local hasTarget = UnitExists(unitTarget .. "target")
                        if hasTarget == false and UNIT_TARGET_Triggered[unitTarget] == nil then
                            PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel)
                            UNIT_TARGET_Triggered[unitTarget] = true
                            C_Timer.After(5, function()
                                UNIT_TARGET_Triggered[unitTarget] = nil
                            end)
                        else
                            PlayAudioSequence(0, "ZhunBeiAOE.ogg", 2.7, "JiNu.ogg")
                            CustomEncounterBar(537444, 26, "准备AOE")
                        end
                    end)
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if currentEncounterID == 2562 then -- 维克萨姆斯
                local actualLevel = UnitLevel(unitTarget)
                if actualLevel == BOSS_LEVEL then
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "HEALER" or PlayerRole == "DAMAGER" then
                        CastMonitor.startTime = GetTime()
                        -- print(CastMonitor.startTime)
                    end
                    return
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "" or subZone == "首席教师之地" or subZone == "院長區" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2097 and unitPowerType == 1 and sex == 3 then
                    PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    CustomEncounterBar(1391782, 26, "准备AOE")
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2501 and unitPowerType == 1 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    if targetName then
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeLiuXue.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 撕裂角刺
                        end
                    else
                        PlayAudioSequence(0, "ZhunBeiChenMo.ogg", 3.5, "AnQuan.ogg") -- 震耳咆哮
                        StartCircleTimerBySeconds(3.5, true)
                        CustomEncounterBar(132117, 25, "准备沉默")
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if select(8, GetInstanceInfo()) == 2874 then -- 迈萨拉洞窟
                local scenarioCriteriaInfo = C_ScenarioInfo.GetCriteriaInfo(1)      
                if UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL and UnitPowerType(unitTarget) == 1 and UnitSex(unitTarget) == 1 and scenarioCriteriaInfo and scenarioCriteriaInfo.completed == true then
                    PlayAudioSequence(0, "JinZhanXuanFeng.ogg") -- 灵魂风暴
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2501 and unitPowerType == 0 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    local targetsPlayer = PlayerIsSpellTarget(unitTarget, "player")
                    if targetName then                        
                        PlaySoundFile(MEDIA_PATH .. "MianJuDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 岩浆涌动
                        StartCircleTimerBySeconds(3.5, false, targetsPlayer)
                        CustomEncounterBar(451169, 20.5, "面具点名")
                        C_Timer.After(0.6, function()
                            if MyCurrentLockedUtteranceID and ttsDuration[MyCurrentLockedUtteranceID] then
                                -- print("不播报")
                            else
                                PlaySoundFile(MEDIA_PATH .. "MuBiaoShiNi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 岩浆涌动
                                -- print("播报")
                            end
                            -- print(ttsDuration[currentUtteranceID])
                        end)
                    else
                        C_Timer.After(2.5, function()
                            local PlayerRole = GetPlayerRole()
                            if PlayerRole == "HEALER" then
                                PlaySoundFile(MEDIA_PATH .. "QuSanMoFa.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 仪式火印
                                CustomEncounterBar(2175503, 19.5, "驱散魔法")
                            else
                                PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 仪式火印
                                CustomEncounterBar(2175503, 19.5, "注意躲圈")
                            end                            
                        end)                        
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if select(8, GetInstanceInfo()) == 2874 then -- 迈萨拉洞窟
                local scenarioCriteriaInfo = C_ScenarioInfo.GetCriteriaInfo(1)
                if scenarioCriteriaInfo and scenarioCriteriaInfo.completed == true then
                    local actualLevel = UnitLevel(unitTarget)
                    local unitPowerType = UnitPowerType(unitTarget)    
                    local sex = UnitSex(unitTarget)
                    if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 2 then
                        C_Timer.After(0.2, function()
                            local hasTarget = UnitExists(unitTarget .. "target")
                            -- print(hasTarget)
                            if hasTarget then
                                local PlayerRole = GetPlayerRole()
                                if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                                    PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 震荡打击
                                end
                            else
                                PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 先祖碾碎
                            end
                        end)
                    end
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0     
            if currentMapID == 184 then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local isInside = IsIndoors()
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 1 and isInside == true then
                    C_Timer.After(0.3, function()
                        if ENCOUNTER_WARNING_Triggered == false then
                            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 专注防御
                            return
                        end
                    end)  
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0     
            if currentMapID == 184 then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local isInside = IsIndoors()
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 1 and isInside == false then
                    PlayAudioSequence(0.4, "DuoKaiTouQian.ogg") -- 冰霜吐息
                    return
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "影卫入侵营地" or subZone == "影衛哨站" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentText = GetTopWidgetText() or ""
                if currentText:find("关闭虚空裂隙") or currentText:find("關閉的虛無裂隙") then     
                    if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                        UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                        if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                            local PlayerRole = GetPlayerRole()
                            if PlayerRole == "HEALER" then
                                PlayAudioSequence(3, "QuSanMoFa.ogg") -- 裂隙精华
                            end
                        else
                            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)                     
                        end
                        return
                    end
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "影卫入侵营地" or subZone == "影衛哨站" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentText = GetTopWidgetText() or ""
                if currentText:find("关闭虚空裂隙") or currentText:find("關閉的虛無裂隙") then    
                    if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 2 then
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "TANK" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeJiTui.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 虚空重殴
                            CustomEncounterBar(6718454, 22, "坦克击退")
                        end                        
                        return
                    end
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "执政团之座" or subZone == "影卫入侵营地" or subZone == "三傑議會之座" or subZone == "影衛哨站" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentText = GetTopWidgetText() or ""
                if not currentText:find("关闭虚空裂隙") and not currentText:find("關閉的虛無裂隙") then  
                    if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                        UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                        if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                            PlaySoundFile(MEDIA_PATH .. "WuMaFenSan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        else
                            PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        end
                        return
                    end
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "执政团之座" or subZone == "三傑議會之座" then
                local PlayerRole = GetPlayerRole()
                if UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL and UnitPowerType(unitTarget) == 0 and UnitSex(unitTarget) == 3 then
                    C_Timer.After(0.1, function()
                        local targetName = UnitSpellTargetName(unitTarget)
                        if targetName then
                            StartCircleTimerBySeconds(2, false, PlayerIsSpellTarget(unitTarget, "player"))
                            C_Timer.After(0.3, function()
                                if IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true then
                                    PlaySoundFile(MEDIA_PATH .. "MuBiaoShiNi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 虚空灌输
                                end
                            end)
                            if PlayerRole == "HEALER" then
                                PlayAudioSequence(1.5, "ZhuYiDanShua.ogg") -- 虚空灌输
                            end
                        else
                            PlayAudioSequence(6, "DuoQiu.ogg") -- 深渊之门
                        end
                    end)
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "三人议政厅" or subZone == "影卫入侵营地" or subZone == "三傑講修院" or subZone == "影衛哨站" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local targetName = UnitSpellTargetName(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 3 then
                    if targetName then
                        StartCircleTimerBySeconds(1.7, false, PlayerIsSpellTarget(unitTarget, "player"))
                        C_Timer.After(0.3, function()
                            if IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true then
                                PlaySoundFile(MEDIA_PATH .. "MuBiaoShiNi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 抽取虚空
                            end
                        end)
                        if GetPlayerRole() == "HEALER" then
                            PlayAudioSequence(1.5, "ShuaXiNaiDun.ogg") -- 抽取虚空
                        end
                    else
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiYouBu.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 制伏锁链
                        CustomEncounterBar(135834, 23, "准备诱捕")
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "温蕾萨之憩" or subZone == "凡蕾莎之憩" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    local PlayerRole = GetPlayerRole()
                    if targetName then
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeLiuXue.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                            CustomEncounterBar(132127, 24, "坦克流血")
                        end
                    else
                        PlaySoundFile(MEDIA_PATH .. "WuMaFenSan.ogg", DiGuaTimelineAudioHelper.audioChannel)  
                        CustomEncounterBar(132142, 23, "五码分散")
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "温蕾萨之憩" or subZone == "凡蕾莎之憩" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2494 and unitPowerType == 3 then                 
                    local targetName = UnitSpellTargetName(unitTarget)
                    if targetName then
                        -- print("真菌之箭")
                    else
                        UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1
                        local remainder = UNIT_CAST_TRACKER[unitTarget] % 3
                        if remainder == 1 then                        
                            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                            CustomEncounterBar(5789328, 27.5, "准备AOE")
                        elseif remainder == 2 then
                            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                            CustomEncounterBar(5789328, 30, "准备AOE")
                        elseif remainder == 0 then
                            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                            CustomEncounterBar(5789328, 30, "准备AOE")
                        end
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "希尔瓦娜斯的营房" or subZone == "希瓦娜斯閨房" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    local PlayerRole = GetPlayerRole()
                    if targetName then
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        end   
                    else
                        if PlayerRole == "TANK" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeDaiWei.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        else
                            PlayAudioSequence(1, "WuMaFenSan.ogg")
                            CustomEncounterBar(132099, 23, "五码分散")
                        end
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "幽灵悲歌" or subZone == "亡靈悲悼" or subZone == "望塔步道" then    
                if UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL and UnitPowerType(unitTarget) == 0 and UnitSex(unitTarget) == 2 and C_Map.GetBestMapForUnit("player") == 2492 then
                    PlaySoundFile(MEDIA_PATH .. "TanKeDaiWei.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 护法者庇护
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "幽灵悲歌" or subZone == "亡靈悲悼" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 1 and currentMapID == 2498 then
                    -- local castInfo = { UnitCastingInfo(unitTarget) }
                    -- local spellName = castInfo[1]
                    -- print(texture)
                    -- 🎯 启动抓取信号
                    IsTrackingUtteranceID = true
                    C_VoiceChat.SpeakText(FindBestVoice(), texture, 10, 0, true)
                    return
                end
            end                
        end
        if isAttackableNameplate -- 幻臾嗜血
            and C_Map.GetBestMapForUnit("player") == 2498
            and (GetSubZoneText() == "风行者宝库" or GetSubZoneText() == "風行者寶庫") 
            and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL 
            and UnitPowerType(unitTarget) == 0 
            and currentEncounterID == 0
            and not UnitSpellTargetName(unitTarget) then
            C_Timer.After(0.6, function()
                if UnitExists(unitTarget) and UnitExists(unitTarget .. "target") then
                    PlaySoundFile(MEDIA_PATH .. "ZhunBeiJiNu.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end
            end)end

        if isAttackableNameplate -- 烈焰新星
            and C_Map.GetBestMapForUnit("player") == 2498
            and (GetSubZoneText() == "风行者宝库" or GetSubZoneText() == "風行者寶庫") 
            and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL 
            and UnitPowerType(unitTarget) == 0 
            and currentEncounterID == 0
            and not UnitSpellTargetName(unitTarget) then
            C_Timer.After(0.6, function() 
                if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") then
                    PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    CustomEncounterBar(236215, 23, "准备AOE")
                    StartCircleTimerBySeconds(3.4, false)
                end
            end)end
        if isAttackableNameplate -- 烈焰新星(首领战)
            and C_Map.GetBestMapForUnit("player") == 2498
            and (GetSubZoneText() == "风行者宝库" or GetSubZoneText() == "風行者寶庫") 
            and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL 
            and UnitPowerType(unitTarget) == 0 
            and currentEncounterID ~= 0
            and not UnitSpellTargetName(unitTarget) then
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) 
            StartCircleTimerBySeconds(4, false) end
        if isAttackableNameplate -- 人群驱散
            and select(8, GetInstanceInfo()) == 2811 -- 魔导师平台    
            and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL 
            and UnitPowerType(unitTarget) == 3 
            and UnitSex(unitTarget) == 1 
            and C_ScenarioInfo.GetCriteriaInfo(2)
            and C_ScenarioInfo.GetCriteriaInfo(2).completed == false -- 瑟拉奈尔·日鞭
            and not UnitSpellTargetName(unitTarget) then
            StartCircleTimerBySeconds(3, false)
            PlayAudioSequence(0, "XiaoXinJiTui.ogg") 
            CustomEncounterBar(1041234, 27.4, "小心击退") end
        if isAttackableNameplate -- 奥术光束
            and select(8, GetInstanceInfo()) == 2811 -- 魔导师平台    
            and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL 
            and UnitPowerType(unitTarget) == 3 
            and UnitSex(unitTarget) == 1 
            and C_ScenarioInfo.GetCriteriaInfo(2)
            and C_ScenarioInfo.GetCriteriaInfo(2).completed == false -- 瑟拉奈尔·日鞭
            and UnitSpellTargetName(unitTarget) then
            C_Timer.After(0.1, function()
                if UnitGroupRolesAssigned(unitTarget .. "target") ~= "TANK" then
                    StartCircleTimerBySeconds(2.9, false, PlayerIsSpellTarget(unitTarget))
                    PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 奥术光束
                end
            end) end
        
        if isAttackableNameplate -- 吞噬打击
            and select(8, GetInstanceInfo()) == 2811 -- 魔导师平台    
            and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL
            and UnitPowerType(unitTarget) == 1 
            and UnitSex(unitTarget) == 1 
            and C_ScenarioInfo.GetCriteriaInfo(2) 
            and C_ScenarioInfo.GetCriteriaInfo(2).completed == true 
            and UnitGroupRolesAssigned("player") ~= "DAMAGER" then
            PlaySoundFile(MEDIA_PATH .. "TanKeChengShang.ogg", DiGuaTimelineAudioHelper.audioChannel)
            CustomEncounterBar(132095, 17.5, "坦克承伤") end
        if isAttackableNameplate -- 炎爆术
            and select(8, GetInstanceInfo()) == 2811 -- 魔导师平台            
            and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL 
            and UnitPowerType(unitTarget) == 0 
            and UnitSex(unitTarget) == 3 
            and C_ScenarioInfo.GetCriteriaInfo(1) 
            and C_ScenarioInfo.GetCriteriaInfo(1).completed == false -- 奥能金刚库斯托斯
            and UnitSpellTargetName(unitTarget) 
            and (UnitGroupRolesAssigned("player") == "TANK" or UnitGroupRolesAssigned("player") == "DAMAGER") then
            PlaySoundFile(MEDIA_PATH .. "DaDuanDaGuai.ogg", DiGuaTimelineAudioHelper.audioChannel)
            CustomEncounterBar(1387354, 17.5, "打断大怪") end       
            
        if isAttackableNameplate -- 燃烧
            and select(8, GetInstanceInfo()) == 2811 -- 魔导师平台            
            and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL 
            and UnitPowerType(unitTarget) == 0 
            and UnitSex(unitTarget) == 3 
            and C_ScenarioInfo.GetCriteriaInfo(1) 
            and C_ScenarioInfo.GetCriteriaInfo(1).completed == false -- 奥能金刚库斯托斯
            and not UnitSpellTargetName(unitTarget) then -- 没有施法目标
            C_Timer.After(0.2, function()
                if UnitExists(unitTarget) and UnitExists(unitTarget .. "target") then
                    PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    CustomEncounterBar(135824, 22.1, "准备AOE")
                end
            end)end
        
        if isAttackableNameplate -- 烈焰风暴
            and select(8, GetInstanceInfo()) == 2811 -- 魔导师平台            
            and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL 
            and UnitPowerType(unitTarget) == 0 
            and UnitSex(unitTarget) == 3 
            and C_ScenarioInfo.GetCriteriaInfo(1) 
            and C_ScenarioInfo.GetCriteriaInfo(1).completed == false -- 奥能金刚库斯托斯
            and not UnitSpellTargetName(unitTarget) then    -- 没有施法目标
            C_Timer.After(0.2, function()
                if not UnitExists(unitTarget .. "target") then
                    PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end
            end)end       



        if isAttackableNameplate then
            if select(8, GetInstanceInfo()) == 2811 then -- 魔导师平台
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local scenarioCriteriaInfo = C_ScenarioInfo.GetCriteriaInfo(1)
                if UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 3 and scenarioCriteriaInfo and scenarioCriteriaInfo.completed == true then -- 奥能金刚库斯托斯
                    local targetsPlayer = PlayerIsSpellTarget(unitTarget, "player")
                    local PlayerRole = GetPlayerRole()
                    -- if PlayerRole ~= "TANK" then                                
                    --     StartCircleTimerBySeconds(3, false, targetsPlayer)
                    --     C_Timer.After(0.8, function()
                    --         if IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true then
                    --             PlaySoundFile(MEDIA_PATH .. "MuBiaoShiNi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 符文战刃
                    --         end
                    --     end)
                    -- end
                    if UNIT_CAST_TRACKER[unitTarget] == nil then
                        UNIT_CAST_TRACKER[unitTarget] = true
                        if PlayerRole ~= "TANK" then
                            StartCircleTimerBySeconds(3, false, targetsPlayer)
                            PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 符文战刃
                            CustomEncounterBar(5927616, 19, "注意点名")
                            C_Timer.After(0.8, function()
                                if IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true then
                                    PlaySoundFile(MEDIA_PATH .. "MuBiaoShiNi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 符文战刃
                                end
                            end)
                        end
                        C_Timer.After(18, function()
                            UNIT_CAST_TRACKER[unitTarget] = nil
                        end)  
                    else
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end
            end                
        end
        if isAttackableNameplate then
            if select(8, GetInstanceInfo()) == 2811 then -- 魔导师平台
                if UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL and UnitPowerType(unitTarget) == 3 and UnitSex(unitTarget) == 1 and C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed == true and C_Map.GetBestMapForUnit("player") ~= 2515 then -- 瑟拉奈尔·日鞭
                    PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    CustomEncounterBar(136160, 33, "准备AOE") -- 吞噬暗影
                    return
                end
            end
        end




        -- if isAttackableNameplate
        --     and select(8, GetInstanceInfo()) == 2915 -- 副本ID (节点希纳斯)
        --     and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL 
        --     and UnitPowerType(unitTarget) == 0
        --     and UnitSex(unitTarget) == 2
        --     and C_ScenarioInfo.GetCriteriaInfo(1) 
        --     and C_ScenarioInfo.GetCriteriaInfo(1).completed == false -- 拦截未完成步骤
        --     and not UnitSpellTargetName(unitTarget) 
        --     and not UnitExists(unitTarget .. "target") then -- 并且【没有】目标
        --     C_Timer.After(0.5, function()
        --         if UnitExists(unitTarget) then
        --             PlaySoundFile(MEDIA_PATH .. "音频文件名.ogg", DiGuaTimelineAudioHelper.audioChannel)
        --         end
        --     end)end








        if isAttackableNameplate and UnitAffectingCombat(unitTarget) then
            if select(8, GetInstanceInfo()) == 2915 then -- 节点希纳斯
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 2 and currentEncounterID == 0 then
                    -- local duration = GetTime() - UNIT_COMBAT_START_TIMES[unitTarget]
                    -- print(duration)
                    local targetName = UnitSpellTargetName(unitTarget)
                    local PlayerRole = GetPlayerRole()
                    local targetsPlayer = PlayerIsSpellTarget(unitTarget, "player")
                    if targetName then
                        C_Timer.After(0.3, function()
                            -- print(UnitGroupRolesAssigned(unitTarget .. "target"))
                            if UnitGroupRolesAssigned(unitTarget .. "target") == "TANK" then
                                if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                                    PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 灼热撕裂
                                    -- isTrackingStopped[unitTarget] = false
                                end
                            else
                                StartCircleTimerBySeconds(3, false, targetsPlayer)
                                if IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true then
                                    PlaySoundFile(MEDIA_PATH .. "MuBiaoShiNi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 酷热惩击
                                end
                                C_Timer.After(2.7, function()
                                    if PlayerRole == "HEALER" then
                                        PlaySoundFile(MEDIA_PATH .. "DanShuaDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 酷热惩击
                                    end                                
                                end)
                            end
                        end)
                    else
                        -- isTrackingStopped[unitTarget] = true
                        PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 荧光闪耀
                        CustomEncounterBar(135934, 21, "躲开头前")
                    end                        
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "护核虚无结界" or subZone == "核心防禦空無結界" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)   
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    local PlayerRole = GetPlayerRole()
                    if targetName then
                        -- PlayAudioSequence(0, "TanKeChengShang.ogg")  
                    else
                        C_Timer.After(0.5, function()
                            local hasTarget = UnitExists(unitTarget .. "target")
                            if hasTarget then
                                PlayAudioSequence(3, "TanKeTouQian.ogg") -- 虚空鞭笞
                            else
                                PlayAudioSequence(0, "ZhunBeiAOE.ogg")
                                CustomEncounterBar(136185, 33, "准备AOE") -- 恐惧咆哮
                                StartCircleTimerBySeconds(4, false)
                            end
                        end)                        
                    end
                    return
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "护核虚无结界" or subZone == "核心防禦空無結界" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)   
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 1 then                    
                    C_Timer.After(0.2, function()
                        if UnitAffectingCombat(unitTarget) then
                            local targetName = UnitSpellTargetName(unitTarget)
                            if targetName then
                                StartCircleTimerBySeconds(3.8, false, PlayerIsSpellTarget(unitTarget, "player")) -- 熵能吸取
                                if IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true then
                                    PlaySoundFile(MEDIA_PATH .. "MuBiaoShiNi.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 熵能吸取
                                end
                            else
                                PlayAudioSequence(2, "ZhunBeiDuoQiu.ogg", 2.3, "DuoQiu.ogg") -- 黑暗呼唤
                                CustomEncounterBar(136194, 29, "准备躲球")                     
                            end
                            return
                        end
                    end)
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "护核虚无结界" or subZone == "核心防禦空無結界" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)   
                if actualLevel == PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    PlayAudioSequence(0, "KongDuanXiaoGuai.ogg") -- 吸血帷幕
                    return
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "核闪引擎道" or subZone == "核火引擎通路" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)   
                local unitAffectingCombat = UnitAffectingCombat(unitTarget)                
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 1 and unitAffectingCombat == true then
                    castStarted = true
                    C_Timer.After(2, function()
                        castStarted = false
                    end)
                    return
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "核闪引擎道" or subZone == "核火引擎通路" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)            
                if actualLevel == PLAYER_LEVEL and unitPowerType == 3 and sex == 1 then
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole ~= "HEALER" then
                        PlayAudioSequence(0, "KuaiDaDianChi.ogg") -- 法力电池
                    end
                    return
                end
            end
        end
        if startTime ~= 0 or currentEncounterID ~= 0 then return end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unitTarget = ...
        local subZone = GetSubZoneText()   
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "执政团之座" or subZone == "三傑議會之座" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local targetName = UnitSpellTargetName(unitTarget)
                local PlayerRole = GetPlayerRole()
                if targetName then
                    if PlayerRole == "DAMAGER" then
                        channelStarted = true -- 虚空灌输
                        C_Timer.After(0.1, function()
                            channelStarted = false 
                        end)
                    end
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "三人议政厅" or subZone == "影卫入侵营地" or subZone == "三傑講修院" or subZone == "影衛哨站" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local targetName = UnitSpellTargetName(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 3 then
                    PlaySoundFile(MEDIA_PATH .. "YouBu.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if select(8, GetInstanceInfo()) == 1209 then -- 通天峰  
                local actualLevel = UnitLevel(unitTarget)
                local sex = UnitSex(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    if not targetName then
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    else
                        if GetPlayerRole() == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "DanShuaDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        end
                        if GetPlayerRole() == "DAMAGER" then
                            channelStarted = true
                            C_Timer.After(0.1, function()
                                channelStarted = false
                            end)
                        end
                    end   
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "幽灵悲歌" or subZone == "亡靈悲悼" or subZone == "望塔步道" then    
                local actualLevel = UnitLevel(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2492 then
                    PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 奥术齐射
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "HEALER" then
                        CustomEncounterBar(1391677, 21, "准备AOE")
                    end                    
                    return
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "幽灵悲歌" or subZone == "亡靈悲悼" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == PLAYER_LEVEL and unitPowerType == 1 and sex == 3 and currentMapID == 2498 then
                    PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 矢如雨下
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0      
            if subZone == "温蕾萨之憩" or subZone == "" or subZone == "凡蕾莎之憩" then
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local sex = UnitSex(unitTarget)
                if (currentMapID == 2493 or currentMapID == 2494 or currentMapID == 2492) and actualLevel == PLAYER_LEVEL and classification == "elite" and sex == 1 then
                    PlaySoundFile(MEDIA_PATH .. "KongDuanLongYing.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 火焰吐息
                    CustomEncounterBar(135812, 17.6, "控断龙鹰")
                    return
                end
            end          
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0  
            if subZone == "希尔瓦娜斯的营房" or subZone == "希瓦娜斯閨房" then     
                local actualLevel = UnitLevel(unitTarget)
                if (currentMapID == 2496 or currentMapID == 2497) and actualLevel == NEXT_PLAYER_LEVEL then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                    if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                        PlaySoundFile(MEDIA_PATH .. "HuDunKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 脉冲尖啸
                    else
                        PlaySoundFile(MEDIA_PATH .. "DaDuanNvYao.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 脉冲尖啸
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if select(8, GetInstanceInfo()) == 2874 then -- 迈萨拉洞窟
                -- local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local scenarioCriteriaInfo = C_ScenarioInfo.GetCriteriaInfo(1)      
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 and scenarioCriteriaInfo and scenarioCriteriaInfo.completed == true then
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "DAMAGER" then
                        PlaySoundFile(MEDIA_PATH .. "BeiMianKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if select(8, GetInstanceInfo()) == 2874 then -- 迈萨拉洞窟
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local sex = UnitSex(unitTarget) 
                if subZone == "" and actualLevel == NEXT_PLAYER_LEVEL and sex == 3 and currentMapID == 2501 then
                    PlayAudioSequence(2, "ZhuYiDuoQuan.ogg") -- 蟾蜍雨
                    return
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "恸哭深渊" or subZone == "蒙难之台" or subZone == "哀嚎深淵" or subZone == "苦難平臺" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    if not UNIT_CHANNEL_TRACKER[unitTarget] then
                        if AudioTriggered == false then
                            AudioTriggered = true
                            PlaySoundFile(MEDIA_PATH .. "DaDuanFuHuo.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 复活
                            UNIT_CHANNEL_TRACKER[unitTarget] = true
                            C_Timer.After(5, function()
                                AudioTriggered = false
                            end)
                            return
                        end
                    end
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if select(8, GetInstanceInfo()) == 2811 then -- 魔导师平台
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                local scenarioCriteriaInfo = C_ScenarioInfo.GetCriteriaInfo(2)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 3 and sex == 1 and scenarioCriteriaInfo and scenarioCriteriaInfo.completed == true then -- 影卫虚空召唤师 -- 瑟拉奈尔·日鞭
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1
                    local remainder = UNIT_CAST_TRACKER[unitTarget] % 3
                    if remainder == 1 then                        
                        PlaySoundFile(MEDIA_PATH .. "ZhaoHuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 虚空召唤
                    elseif remainder == 2 then
                        -- PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    elseif remainder == 0 then
                        PlaySoundFile(MEDIA_PATH .. "ZhaoHuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 虚空召唤
                    end                    
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0     
            if currentMapID == 184 then
                if UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL and UnitPowerType(unitTarget) == 1 and UnitClassification(unitTarget) == "elite" and UnitSex(unitTarget) == 1 and IsIndoors() == true then
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "TANK" or PlayerRole == "DAMAGER" then
                        PlaySoundFile(MEDIA_PATH .. "BeiMianKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end                    
                    return
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            if currentMapID == 184 then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 2 and currentEncounterID == 0 then
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "HEALER" then
                        PlaySoundFile(MEDIA_PATH .. "DanShuaDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 苦难洪流
                        CustomEncounterBar(3528298, 26, "单刷点名")
                    end
                    if PlayerRole == "DAMAGER" then
                        channelStarted = true
                        C_Timer.After(0.1, function()
                            channelStarted = false
                        end)
                    end
                    return
                end
            end         
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            if currentMapID == 184 then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local sex = UnitSex(unitTarget)
                if actualLevel == PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 3 then     
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "TANK" or PlayerRole == "DAMAGER" then
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiJiuRen.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 猛拽擒握
                        CustomEncounterBar(4632787, 30, "注意救人")
                    end                
                    return
                end
            end         
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "护核虚无结界" or subZone == "核心防禦空無結界" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)   
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    local PlayerRole = GetPlayerRole()
                    if targetName then
                        if GetPlayerRole() == "HEALER" then
                            PlayAudioSequence(0.2, "ShuaXiNaiDun.ogg") -- 熵能吸取
                        end               
                    end
                    return
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "护核虚无结界" or subZone == "核心防禦空無結界" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)
                C_Timer.After(0.5, function()
                    if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 and currentEncounterID == 0 then
                        if buffJustTriggered == false then
                            local PlayerRole = GetPlayerRole()
                            if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                                PlaySoundFile(MEDIA_PATH .. "TanKeChengShang.ogg", DiGuaTimelineAudioHelper.audioChannel)
                                CustomEncounterBar(4914668, 24, "坦克承伤")
                            end
                        else
                            PlaySoundFile(MEDIA_PATH .. "JianRenFengBao.ogg", DiGuaTimelineAudioHelper.audioChannel)   
                            return
                        end                 
                    end
                end)
            end               
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "核闪引擎道" or subZone == "核火引擎通路" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)   
                local unitAffectingCombat = UnitAffectingCombat(unitTarget)                
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 1 and unitAffectingCombat == true then
                    if castStarted == false then
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        CustomEncounterBar(3528282, 25.5, "准备AOE")
                    else
                        PlayAudioSequence(2.5, "ZhuYiDuoQuan.ogg")
                    end
                    return
                end
            end               
        end
        if startTime ~= 0 or currentEncounterID ~= 0 then return end

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        -- print("测试")
        local unitTarget = ...
        local interruptedBy = (event == "UNIT_SPELLCAST_INTERRUPTED") and select(4, ...) or nil
        local subZone = GetSubZoneText()
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0   
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()         
            if currentMapID == 184 and keyLevel >= 12 then                   
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 3, "HELPFUL") 
                if interruptedBy and UnitLevel(unitTarget) == PLAYER_LEVEL and unitPowerType == 0 and classification == "elite" and UnitSex(unitTarget) == 2 and auraData then
                    CustomEncounterBar(1041233, 20, "虚空爆发")
                    return
                end
            end          
        end
        if unitTarget and unitTarget:find("boss") and UnitCanAttack("player", unitTarget) then
            if subZone == "体育场" or subZone == "運動場" then
                local LabelText = GetWidgetLabelText()
                if LabelText == nil then
                    -- print("火焰")
                    if currentEncounterID ~= 0 then
                        PlayAudioSequence(
                            0, "YiShangJieDuan.ogg",7 , "DaoShu5.ogg",1 , "DaoShu4.ogg",1 , "DaoShu3.ogg",1 , "DaoShu2.ogg",1 , "DaoShu1.ogg",1 , "YiShangJieShu.ogg"                    
                        )
                    end                   
                else
                    -- print("狂风")
                    PlaySoundFile(MEDIA_PATH .. "JieDuanZhuanHuan.ogg", DiGuaTimelineAudioHelper.audioChannel)     
                end           
            end          
        end
        return
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unitTarget = ...
        local subZone = GetSubZoneText()
    elseif event == "UNIT_COMBAT" then
        local unitTarget = ...
            -- print(unitTarget)
            -- print("玩家可攻击")
            -- print(UnitCanAttack("player", unitTarget))
            -- print("进入战斗")
            -- print(UnitAffectingCombat(unitTarget))
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) and UnitAffectingCombat(unitTarget) then

            -- print("成功")
            -- print(UNIT_COMBAT_START_TIMES[unitTarget])
            if UNIT_COMBAT_START_TIMES[unitTarget] == nil then
                if select(8, GetInstanceInfo()) == 2915 then -- 节点希纳斯
                    local actualLevel = UnitLevel(unitTarget)
                    local unitPowerType = UnitPowerType(unitTarget)    
                    local sex = UnitSex(unitTarget)
                    if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 2 and currentEncounterID == 0 then
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            CustomEncounterBar(135973, 3, "坦克尖刺")
                        end
                        if PlayerRole == "DAMAGER" or PlayerRole == "HEALER" then
                            CustomEncounterBar(5764906, 8, "酷热惩击")
                        end                        
                        CustomEncounterBar(135934, 18, "躲开头前") -- 荧光闪耀
                        UNIT_COMBAT_START_TIMES[unitTarget] = GetTime()
                        -- print(UNIT_COMBAT_START_TIMES[unitTarget])
                        return
                    end
                end
            end
        end
    elseif event == "RAID_BOSS_EMOTE" or event == "ENCOUNTER_WARNING" then

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
        if currentEncounterID == 3056 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            -- print("成功：检测到炽焰腾流")
            PlaySoundFile(MEDIA_PATH .. "TieBianFangShuiSanMiaoSanErYi.ogg", DiGuaTimelineAudioHelper.audioChannel)
            StartCircleTimerBySeconds(6)
            return
        end
        if (C_Map.GetBestMapForUnit("player") == 601 or C_Map.GetBestMapForUnit("player") == 602) and currentEncounterID == 0 then
            PlaySoundFile(MEDIA_PATH .. "XiaoXinJiTui.ogg", DiGuaTimelineAudioHelper.audioChannel)
            StartCircleTimerBySeconds(2.7)
            return
        end
        if C_Map.GetBestMapForUnit("player") == 2501 and currentEncounterID == 0 then
            PlaySoundFile(MEDIA_PATH .. "ZhuYiJiuRen.ogg", DiGuaTimelineAudioHelper.audioChannel)
            return
        end
        if currentEncounterID == 1701 and encounterWarningInfo.severity and encounterWarningInfo.severity == 2 then
            -- print("成功：检测到炫光")
            castStarted = true
            C_Timer.After(0.6, function()
                castStarted = false -- 保险
            end)
            return
        end
        if currentEncounterID == 3056 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            -- print("成功：检测到炽焰腾流")
            PlaySoundFile(MEDIA_PATH .. "TieBianFangShuiSanMiaoSanErYi.ogg", DiGuaTimelineAudioHelper.audioChannel)
            StartCircleTimerBySeconds(6)
            return
        end
        if currentEncounterID == 3179 and encounterWarningInfo.severity and encounterWarningInfo.severity == 0 then
            -- print("成功：检测到专制命令")
            -- PlaySoundFile(MEDIA_PATH .. "TieBianFangShui.ogg", DiGuaTimelineAudioHelper.audioChannel)
            StartCircleTimerBySeconds(12)
            return
        end
        if currentEncounterID == 2065 and encounterWarningInfo.targetName then
            -- print("成功：检测到残杀")
            StartCircleTimerBySeconds(5)
            return
        end
        if currentEncounterID == 2564 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            -- print("成功：检测到震耳尖啸")
            StartCircleTimerBySeconds(2.3, true)
            return
        end        
        if currentEncounterID == 3072 and encounterWarningInfo.severity and encounterWarningInfo.severity == 2 then
            -- print("成功：检测到静默浪潮")
            StartCircleTimerBySeconds(4.8)
            return
        end


        if currentEncounterID == 3057 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            -- print("成功：检测到黑暗诅咒和飞溅喷吐")
            StartCircleTimerBySeconds(4.1)
            return
        end        
        if currentEncounterID == 3073 and encounterWarningInfo.severity and encounterWarningInfo.severity == 2 then
            -- print("成功：检测到星界束缚")
            PlayAudioSequence(9, "DaoShu3.ogg",1 ,"DaoShu2.ogg",1 ,"DaoShu1.ogg",1 ,"AnQuan.ogg")
            return
        end
        if currentEncounterID == 3182 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            -- print("成功：检测到复生")            
            C_Timer.After(35, function()
                if currentEncounterID == 3182 then
                    PlayAudioSequence(0, "DaoShu5.ogg",1 ,"DaoShu4.ogg",1 ,"DaoShu3.ogg",1 ,"DaoShu2.ogg",1 ,"DaoShu1.ogg")
                end
            end)
            C_Timer.After(44, function()
                if currentEncounterID == 3182 then
                    PlayAudioSequence(0, "KaiShiHuanSe.ogg")
                end
            end)
            return
        end
        if currentEncounterID == 3214 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            -- print("成功：检测到粉碎灵魂")
            StartCircleTimerBySeconds(4.5)
        end
        if currentEncounterID == 3181 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 and not encounterWarningInfo.targetName and encounterWarningInfo.duration == 3.5 then
            -- print("成功：检测到干扰震荡)
            local preciseTime = GetTime() - startTime
            if preciseTime >= 3 and preciseTime <= 6 then
                StartCircleTimerBySeconds(5, true)
            end
            if preciseTime >= 24 and preciseTime <= 26 then
                StartCircleTimerBySeconds(5, true)
            end
            if preciseTime >= 40 and preciseTime <= 42 then
                StartCircleTimerBySeconds(5, true)
            end
        end
        if currentEncounterID == 3181 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 and encounterWarningInfo.targetName and encounterWarningInfo.duration == 5 then
            -- print("成功：检测到银峰箭或游侠队长的印记或终末守护")
            StartCircleTimerBySeconds(6, true)
        end
        if currentEncounterID == 3178 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 and encounterWarningInfo.shouldPlaySound == true then
            -- print("成功：检测到亡者吐息")
            local _, _, difficultyID = GetInstanceInfo()            
            -- 如果是史诗难度（ID 16）
            if difficultyID == 16 then
                local preciseTime = GetTime() - startTime
                if preciseTime >= 4 and preciseTime <= 6 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 69 and preciseTime <= 71 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 131 and preciseTime <= 134 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 190 and preciseTime <= 193 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 315 and preciseTime <= 318 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 359 and preciseTime <= 362 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 359 and preciseTime <= 362 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 411 and preciseTime <= 414 then
                    StartCircleTimerBySeconds(6)
                end
            end
            return
        end
        if currentEncounterID == 3183 and encounterWarningInfo.severity == 1 then
            local _, _, difficultyID = GetInstanceInfo()
            
            -- 定义默认时间为 3.9 秒（普通/英雄）
            local timerDuration = 3.9
            
            -- 如果是史诗难度（ID 16），则改为 2.9 秒
            if difficultyID == 16 then
                timerDuration = 2.9
            end
            StartCircleTimerBySeconds(timerDuration)
            return 
        end
        if currentEncounterID == 3332 and not encounterWarningInfo.targetName and encounterWarningInfo.severity == 2 then
            -- print("成功：检测到光痕")
            C_Timer.After(21, function()
                if currentEncounterID ~= 0 then
                    PlayAudioSequence(0, "DaoShu5.ogg", 1, "DaoShu4.ogg", 1, "DaoShu3.ogg", 1, "DaoShu2.ogg", 1, "DaoShu1.ogg", 1, "YiShangJieShu.ogg")
                -- print("易伤结束")
                end
            end)
            return
        end
        if startTime ~= 0 or currentEncounterID ~= 0 then 
            return 
        end

        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return end

        
        -- print("['" .. encounterWarningInfo.duration .. "']")
        if encounterWarningInfo.duration == 3.5 and mapID == 184 then
            -- print("成功")
            local isInside = IsIndoors()
            if isInside == true then
                PlaySoundFile(MEDIA_PATH .. "WuMaFenSanSanErYiZhuYiJiaoXia.ogg", DiGuaTimelineAudioHelper.audioChannel)
                StartCircleTimerBySeconds(5.1)
                ENCOUNTER_WARNING_Triggered = true
                C_Timer.After(1, function()
                    ENCOUNTER_WARNING_Triggered = false
                end)  
            end
            return
        end
        return

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget = ...
        local subZone = GetSubZoneText()
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) and UnitAffectingCombat(unitTarget) then
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            if instanceID == 2915 then -- 节点希纳斯
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 2 and currentEncounterID == 0 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    local PlayerRole = GetPlayerRole()
                    if targetName then
                        if PlayerRole == "DAMAGER" then
                            castStarted = true
                            C_Timer.After(0.1, function()
                                castStarted = false
                            end)     
                        end                 
                    end                        
                    return              
                end
            end                
        end        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) and select(8, GetInstanceInfo()) == 2811 and UnitLevel(unitTarget) == NEXT_PLAYER_LEVEL and UnitPowerType(unitTarget) == 3 and UnitSex(unitTarget) == 1 and C_ScenarioInfo.GetCriteriaInfo(2).completed == false and UnitSpellTargetName(unitTarget) and UnitGroupRolesAssigned(unitTarget .. "target") == "TANK" then -- 瑟拉奈尔·日鞭
            if UnitGroupRolesAssigned("player") == "TANK" or UnitGroupRolesAssigned("player") == "HEALER" then PlaySoundFile(MEDIA_PATH .. "TanKeDingShen.ogg", DiGuaTimelineAudioHelper.audioChannel) return end
        end -- 虚灵枷锁
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if currentEncounterID == 2562 then -- 维克萨姆斯
                if UnitLevel(unitTarget) == BOSS_LEVEL then
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "HEALER" or PlayerRole == "DAMAGER" then
                        local duration = GetTime() - CastMonitor.startTime
                        -- print(duration)
                        if duration <= 2.6 then
                            -- print("<= 2.6,falizhadanTriggered = true")
                            falizhadanTriggered = true
                            C_Timer.After(1, function()
                                falizhadanTriggered = false
                                -- print("1,falizhadanTriggered = false")
                            end)    
                            return                       
                        end
                    end
                end
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "护核虚无结界" or subZone == "核心防禦空無結界" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)   
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    local targetName = UnitSpellTargetName(unitTarget)
                    if not targetName then
                        -- print("castStarted = false")
                        castStarted = false
                    end
                    return
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        -- 2. 根据检测结果动态赋值
        if C_AddOns.IsAddOnLoaded("DiGua-WYJJ") then
            MEDIA_PATH = "Interface\\AddOns\\DiGua-WYJJ\\Media\\"
            -- print("|cff00ff00[联动]|r 检测到 DiGua-WYJJ，[忘忧景久语音包启动]")
        else
            MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
            -- print("|cffaaaaaa[系统]|r 未检测到 DiGua-WYJJ，使用默认素材路径")
        end
        -- 1. 专门针对 BigWigs 的判断
        local hasBigWigs = C_AddOns.IsAddOnLoaded("BigWigs")

        -- 2. 只有在【没有 BigWigs】的情况下，才在 2 秒后强制开启系统警报
        if not hasBigWigs then
            C_Timer.After(2, function()
                SetCVar("encounterWarningsEnabled", 1)
            end)
        end       
        SetCVar("Sound_NumChannels", 128)
        -- 【修改这里】如果“不是”大秘境进行中，才执行该函数
        -- 建议加一个极其微小的延时（如 0.1 秒）确保 API 数据已准备好
        C_Timer.After(0.5, function()
            if not C_ChallengeMode.IsChallengeModeActive() then
                RegisterPrivateAuras()
            end
        end)
        --[[C_Timer.After(2, function()
            print("感謝使用|cFF00FF00[神秘地瓜副本語音插件]|r如果覺得好用，請在|cFFFFA6D5“愛發電”|r平台搜索|cFFFFFF00“神秘地瓜”|r支持我的插件，您的支持就是我最大的動力。")
        --end)]]        
        -- ApplyTimelineSounds()       
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        hasPlayedSiJiaoTingYuan = false
        Lindormi = false
        MyTTSDict.isSampled = false
        MyTTSDict.sampleIndex = 0
        local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
        -- print("当前副本 ID: " .. (instanceID or "nil"))
        C_Timer.After(4, function()
            if instanceID == 2805 then 
                C_Timer.After(2, function()                    
                    if FindBestVoice() then
                        MyTTSDict.sampleIndex = 1
                        C_VoiceChat.SpeakText(FindBestVoice(), "4667427", 10, 0, true)
                    end
                end)
                -- 2秒后读第二个
                C_Timer.After(4, function()                    
                    if FindBestVoice() then
                        MyTTSDict.sampleIndex = 2
                        C_VoiceChat.SpeakText(FindBestVoice(), "852826", 10, 0, true)
                    end
                end)
            end
        end)
        return

    elseif event == "CHAT_MSG_MONSTER_EMOTE" then
        -- 获取前两个参数：text 是消息内容，playerName 是 NPC 名字
        local text, playerName = ...
        
        -- 打印接收到的原始数据，方便调试
        -- print(string.format("MONSTER_EMOTE: [%s] %s", playerName, text))

        -- 2. 秘密值检查（重点添加了打印）
        if issecretvalue(text) or issecrettable(text) then
            -- print("|cff00ccff[Debug]|r 拦截到秘密值或秘密表，已忽略。内容: " .. tostring(text))
            return
        end

        -- 1. 过滤：判断发送者是否在队伍或团队中
        if not UnitInParty(playerName) and not UnitInRaid(playerName) then
            return -- 不是队友/团员，直接静默退出，不打印以保持控制台整洁
        end

        -- 3. 逻辑触发与匹配
        if string.match(text, "供大家享用") then
            -- print("|cff00ff00[Success]|r 匹配成功！播放语音: " .. tostring(text))
            PlaySoundFile(MEDIA_PATH .. "QuChiDaCan.ogg", DiGuaTimelineAudioHelper.audioChannel)
        end

    -- elseif event == "LOADING_SCREEN_DISABLED" then
    --     print("LOADING_SCREEN_DISABLED")
        
    --     return
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        local subZone = GetSubZoneText()
        if subZone == "绿植场圃" or subZone == "藥草園" then
            encounterUnitTriggerCount = (encounterUnitTriggerCount or 0) + 1
            if encounterUnitTriggerCount >= 3 and encounterUnitTriggerCount % 2 ~= 0 then
                C_Timer.After(0.1, function()
                    if UnitExists("boss1") and not UnitIsDead("boss1") and currentEncounterID ~= 0 then
                        PlaySoundFile(MEDIA_PATH .. "KuaiJinLvQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end             
                end)

            end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...  
        if unit and UNIT_CAST_TRACKER[unit] then
            UNIT_CAST_TRACKER[unit] = nil
        end
        if unit and auraTriggeredCache[unit] then
            auraTriggeredCache[unit] = nil
        end
        -- 清理时间戳和播放状态
        UNIT_COMBAT_START_TIMES[unit] = nil
        UNIT_CAST_TRACKER[unit] = nil
        -- 如果还有之前 NewTimer 的句柄，也顺手清理（虽然新逻辑不用了，但为了保险）
        if UNIT_CAST_TIMER_HANDLES[unit] then
            UNIT_CAST_TIMER_HANDLES[unit]:Cancel()
            UNIT_CAST_TIMER_HANDLES[unit] = nil
        end
        if unit then
            UNIT_CHANNEL_TRACKER[unit] = nil
        end
        if unit then
            isTrackingStopped[unit] = nil
        end
        if unit then
            UNIT_TARGET_Triggered[unit] = nil
        end
    end

    local bossData = addonTable.AudioTimeline[currentEncounterID]
    if bossData and bossData.eventAlerts then
        local specificAlert = bossData.eventAlerts[event]
        if specificAlert then
            ProcessAlert(specificAlert, "Event:"..event)
            if type(specificAlert) == "table" and specificAlert.action then
                if specificAlert.action == "STOP" then
                    startTime = 0
                    lastPlayedSecond = -1
                    frame:SetScript("OnUpdate", nil) 
                    -- print("|cFFFF0000[TimelineAudio]|r 收到 STOP：时间轴已挂起")                    
                elseif specificAlert.action == "START" then
                    startTime = GetTime()
                    lastPlayedSecond = -1
                    frame:SetScript("OnUpdate", OnUpdate)
                    -- print("|cFF00FF00[TimelineAudio]|r 收到 START：时间轴已重新启动")
                end
            end
        end
    end
end)


-- 1. 创建主框架
local RingFrame = CreateFrame("Frame", "MyCustomCircleTimer", UIParent)
RingFrame:SetSize(120, 120)
RingFrame:SetPoint("CENTER", 0, 0)
RingFrame:Hide()

-- 2. 创建底色圆环 (背景)
local bg = RingFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture(RING_PATH)
bg:SetVertexColor(0, 0, 0, 0.3)

-- 3. 创建进度层
local cd = CreateFrame("Cooldown", nil, RingFrame, "CooldownFrameTemplate")
cd:SetAllPoints()
cd:SetDrawEdge(false)           
cd:SetDrawSwipe(true)           
cd:SetSwipeTexture(RING_PATH)   
cd:SetSwipeColor(0.4, 1, 0.8, 0.85) 
cd:SetHideCountdownNumbers(true)
cd:SetBlingTexture("")          

-- 【新增】专门的隐藏和清理函数，确保安全彻底
local function ForceHideRingFrame()
    RingFrame:Hide()
    CurrentRingIsCastSensitive = false -- 关闭读条敏感标记
    
    -- 清理主计时器
    if activeCircleTimer then
        activeCircleTimer:Cancel()
        activeCircleTimer = nil
    end
    
    -- 清理保底计时器自身
    if backupHideTimer then
        backupHideTimer:Cancel()
        backupHideTimer = nil
    end
end

function StartMyCircleTimer(alert)
    -- 1. 只有当 alert 是 table 且包含 duration 字段时才继续
    if type(alert) ~= "table" or not alert.duration then 
        return 
    end

    local duration = alert.duration
    
    -- 2. 执行倒计时逻辑
    local startTime = GetTime()
    
    -- --- 新增逻辑：同步全局变量 ---
    TargetEndTime = startTime + duration             -- 记录全局结束时间
    CurrentRingIsCastSensitive = alert.checkCast     -- 从表中读取 checkCast 参数
    UpdateRingColor(false)                           -- 恢复默认颜色
    -- ---------------------------

    -- --- 核心修改：只有在勾选时才显示 ---
    if DiGuaTimelineAudioHelper.ringEnabled then
        cd:SetCooldown(startTime, duration)
        RingFrame:Show()
    else
        RingFrame:Hide() -- 确保它是关闭的
        return -- 如果压根没显示，就不用走后面的定时器逻辑了
    end
    
    -- 🎯 【重置】如果上一次的任何计时器还在跑，先强行取消
    if activeCircleTimer then activeCircleTimer:Cancel() end
    if backupHideTimer then backupHideTimer:Cancel() end

    -- 3. 主延时隐藏
    activeCircleTimer = C_Timer.NewTimer(duration, function()
        ForceHideRingFrame()
    end)

    -- 4. 【保底】10秒绝对强制隐藏
    -- 无论 duration 是多少，10秒后这个定时器必定触发并强行重置 UI
    backupHideTimer = C_Timer.NewTimer(10, function()
        ForceHideRingFrame()
    end)
end

function StartCircleTimerBySeconds(seconds, checkCast, PlayerIsSpellTarget)
    -- 1. 安全检查：确保传入的是数字且大于 0
    local duration = tonumber(seconds)
    if not duration or duration <= 0 then 
        return 
    end

    -- --- 核心修改：如果没传第三个参数，默认赋值为 true ---
    if PlayerIsSpellTarget == nil then
        PlayerIsSpellTarget = true
    end

    -- 2. 执行倒计时逻辑
    local startTime = GetTime()
    TargetEndTime = startTime + duration 
    CurrentRingIsCastSensitive = checkCast 

    UpdateRingColor(false) 

    -- --- 核心修改：只有在勾选时才显示 ---
    if DiGuaTimelineAudioHelper.ringEnabled then
        cd:SetCooldown(startTime, duration)
        RingFrame:Show()
    else
        RingFrame:Hide()
        return -- 如果压根没显示，直接拦截
    end

    RingFrame:SetAlphaFromBoolean(PlayerIsSpellTarget, 0.85, 0)

    -- 🎯 启动抓取信号
    IsTrackingUtteranceID = true
    C_VoiceChat.SpeakText(FindBestVoice(), RingFrame:GetAlpha(), 10, 0, true)

    -- 🎯 【重置】如果上一次的任何计时器还在跑，先强行取消
    if activeCircleTimer then activeCircleTimer:Cancel() end
    if backupHideTimer then backupHideTimer:Cancel() end

    -- 3. 主延时隐藏
    activeCircleTimer = C_Timer.NewTimer(duration, function()
        ForceHideRingFrame()
    end)

    -- 4. 【保底】10秒绝对强制隐藏
    backupHideTimer = C_Timer.NewTimer(10, function()
        ForceHideRingFrame()
    end)
end

-- 5. 颜色切换函数
function UpdateRingColor(isAlarm)
    if isAlarm then
        PlaySoundFile(MEDIA_PATH .. "BuBu.ogg", DiGuaTimelineAudioHelper.audioChannel)
        cd:SetSwipeColor(unpack(RING_COLOR_ALARM))
    else
        cd:SetSwipeColor(unpack(RING_COLOR_NORMAL))
    end
end


-- ============================================================================
-- 1. 数据库初始化与路径判定逻辑 (Core.lua 范畴)
-- ============================================================================
local initLoader = CreateFrame("Frame")
initLoader:RegisterEvent("ADDON_LOADED")

initLoader:SetScript("OnEvent", function(self, event, addonNameInput)
    if addonNameInput == addonName then
        
        -- 1. 确保大表存在
        if DiGuaTimelineAudioHelper == nil then
            DiGuaTimelineAudioHelper = {
                enabled = true,
                ringEnabled = true,
                tenSecCountDown = false,
                coTankAuraEnabled = false, -- [核心改动] 新用户默认不开启副坦光环监控
                audioChannel = "Master",
                path = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\",
                -- [新增] 默认坐标
                coTankX = -400,
                coTankY = 350,
            }
        else
            -- 2. 老用户补全逻辑
            if DiGuaTimelineAudioHelper.ringEnabled == nil then
                print("|cffffd100[DiGua]|r 检测到新功能，已为你默认开启倒计时光圈。")
                DiGuaTimelineAudioHelper.ringEnabled = true
            end

            if DiGuaTimelineAudioHelper.audioChannel == nil then
                DiGuaTimelineAudioHelper.audioChannel = "Master"
            end

            if DiGuaTimelineAudioHelper.tenSecCountDown == nil then
                DiGuaTimelineAudioHelper.tenSecCountDown = false
            end

            -- [核心改动] 老用户升级时补全配置，默认关闭
            if DiGuaTimelineAudioHelper.coTankAuraEnabled == nil then
                DiGuaTimelineAudioHelper.coTankAuraEnabled = false
            end

            -- [新增] 老用户升级时补全坐标
            if DiGuaTimelineAudioHelper.coTankX == nil then
                DiGuaTimelineAudioHelper.coTankX = -400
                DiGuaTimelineAudioHelper.coTankY = 350
            end
        end
        
        -- 3. UI 状态同步
        if cbRing then cbRing:SetChecked(DiGuaTimelineAudioHelper.ringEnabled) end
        if cbChannel then cbChannel:SetChecked(DiGuaTimelineAudioHelper.audioChannel == "Ambience") end
        if cbTenSec then cbTenSec:SetChecked(DiGuaTimelineAudioHelper.tenSecCountDown) end 
        if cbCoTank then cbCoTank:SetChecked(DiGuaTimelineAudioHelper.coTankAuraEnabled) end -- [核心改动]
        
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- 核心：路径更新逻辑
local function RefreshMediaPath()
    if DiGuaTimelineAudioHelper.enabled == false then
        MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Mute\\"
    else
        if C_AddOns.IsAddOnLoaded("DiGua-WYJJ") then
            MEDIA_PATH = "Interface\\AddOns\\DiGua-WYJJ\\Media\\"
        else
            MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
        end
    end
end

-- ============================================================================
-- 2. UI 界面创建 (Core.lua 范畴)
-- ============================================================================
local f = CreateFrame("Frame", "DiGuaTimelineMainFrame", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(180, 170) -- [核心改动] 高度由 145 增加到 170，容纳第五个选项
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

-- 标题
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -3)
f.title:SetText("DiGua 控制台")

-- 复选框 1：启用语音
local cb = CreateFrame("CheckButton", "DiGuaTimelineEnableCheck", f, "ChatConfigCheckButtonTemplate")
cb:SetPoint("TOPLEFT", 20, -35)
local cbText = _G[cb:GetName() .. "Text"]
cbText:SetText("启用语音")
cbText:SetTextColor(1, 0.82, 0)

-- 复选框 2：启用倒计时光圈
local cbRing = CreateFrame("CheckButton", "DiGuaTimelineRingCheck", f, "ChatConfigCheckButtonTemplate")
cbRing:SetPoint("TOPLEFT", 20, -60) 
local cbRingText = _G[cbRing:GetName() .. "Text"]
cbRingText:SetText("显示倒计时光圈")
cbRingText:SetTextColor(1, 0.82, 0)

-- 复选框 3：环境音频道
local cbChannel = CreateFrame("CheckButton", "DiGuaTimelineChannelCheck", f, "ChatConfigCheckButtonTemplate")
cbChannel:SetPoint("TOPLEFT", 20, -85) 
local cbChannelText = _G[cbChannel:GetName() .. "Text"]
cbChannelText:SetText("使用环境音频道")
cbChannelText:SetTextColor(1, 0.82, 0)

-- 复选框 4：开启10秒倒数
local cbTenSec = CreateFrame("CheckButton", "DiGuaTimelineTenSecCheck", f, "ChatConfigCheckButtonTemplate")
cbTenSec:SetPoint("TOPLEFT", 20, -110) 
local cbTenSecText = _G[cbTenSec:GetName() .. "Text"]
cbTenSecText:SetText("开启 10 秒倒数")
cbTenSecText:SetTextColor(1, 0.82, 0)

-- [核心改动] 复选框 5：副坦私有光环监控
local cbCoTank = CreateFrame("CheckButton", "DiGuaTimelineCoTankCheck", f, "ChatConfigCheckButtonTemplate")
cbCoTank:SetPoint("TOPLEFT", 20, -135) -- 放在第四个按钮下方 25 像素处
local cbCoTankText = _G[cbCoTank:GetName() .. "Text"]
cbCoTankText:SetText("副坦私有光环监控")
cbCoTankText:SetTextColor(1, 0.82, 0)

-- ============================================================================
-- 3. 事件与点击逻辑 (Core.lua 范畴)
-- ============================================================================
-- [新增] 联动逻辑：控制台显示与隐藏时触发绿框状态刷新
f:SetScript("OnShow", function(self)
    if addonTable.RefreshAnchorState then
        addonTable.RefreshAnchorState(true)
    end
end)

f:SetScript("OnHide", function(self)
    if addonTable.RefreshAnchorState then
        addonTable.RefreshAnchorState(false)
    end
end)

SLASH_DIGUA1 = "/digua"
SlashCmdList["DIGUA"] = function()
    if f:IsShown() then f:Hide() else f:Show() end
end

cb:SetScript("OnClick", function(self)
    DiGuaTimelineAudioHelper.enabled = self:GetChecked()
    RefreshMediaPath()
    local status = DiGuaTimelineAudioHelper.enabled and "|cff00ff00已开启|r" or "|cffff0000已禁用|r"
    print("|cffffd100[DiGua]|r 整体音效状态: " .. status)
end)

cbRing:SetScript("OnClick", function(self)
    DiGuaTimelineAudioHelper.ringEnabled = self:GetChecked()
    local status = DiGuaTimelineAudioHelper.ringEnabled and "|cff00ff00已显示|r" or "|cffff0000已隐藏|r"
    print("|cffffd100[DiGua]|r 倒计时光圈图标状态: " .. status)
end)

cbChannel:SetScript("OnClick", function(self)
    if self:GetChecked() then
        DiGuaTimelineAudioHelper.audioChannel = "Ambience"
        print("|cffffd100[DiGua]|r 播放声道已切换至: |cff00ff00环境音 (Ambience)|r")
    else
        DiGuaTimelineAudioHelper.audioChannel = "Master"
        print("|cffffd100[DiGua]|r 播放声道已切换至: |cffffd100主音量 (Master)|r")
    end
end)

cbTenSec:SetScript("OnClick", function(self)
    DiGuaTimelineAudioHelper.tenSecCountDown = self:GetChecked()
    local status = DiGuaTimelineAudioHelper.tenSecCountDown and "|cff00ff00已开启 (10秒)|r" or "|cffff0000未开启 (默认5秒)|r"
    print("|cffffd100[DiGua]|r 团队倒计时模式: " .. status)
end)

-- [核心改动] 点击复选框 5 (副坦私有光环切换)
cbCoTank:SetScript("OnClick", function(self)
    DiGuaTimelineAudioHelper.coTankAuraEnabled = self:GetChecked()
    local status = DiGuaTimelineAudioHelper.coTankAuraEnabled and "|cff00ff00已开启|r" or "|cffff0000已关闭|r"
    print("|cffffd100[DiGua]|r 副坦私有光环监控: " .. status)
    
    -- 【新增】复选框状态改变时，立刻联动绿框的显隐和可移动状态
    if addonTable.RefreshAnchorState then
        addonTable.RefreshAnchorState(f:IsShown())
    end
    
    -- 手动切换时，通过私有表立刻触发一次实际的暴雪光环刷新
    if addonTable.UpdateRaidTankAuras then
        addonTable.UpdateRaidTankAuras()
    end
end)

-- 监听登录事件进行初始化
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        cb:SetChecked(DiGuaTimelineAudioHelper.enabled)
        cbRing:SetChecked(DiGuaTimelineAudioHelper.ringEnabled)
        cbChannel:SetChecked(DiGuaTimelineAudioHelper.audioChannel == "Ambience")
        cbTenSec:SetChecked(DiGuaTimelineAudioHelper.tenSecCountDown)
        cbCoTank:SetChecked(DiGuaTimelineAudioHelper.coTankAuraEnabled) -- [核心改动] 同步状态
        RefreshMediaPath()
    end
end)