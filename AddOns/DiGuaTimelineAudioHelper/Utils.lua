-- Utils.lua
-- 插件通用工具函数库（挂载于 addonTable，供全插件调用）

local addonName, addonTable = ...

-- 判断 unit 与“我的焦点”是否为同一类机制怪。
-- 只比较各打断块用到的公开筛选特征（等级/能量/分类/副官/生物家族/施法目标有无），
-- 副本/地图/室内外/Boss进度/职责 是同帧全局上下文，无需比较。不用 UnitIsUnit。
local function IsFocusLikeUnit(unit)
    if not unit or unit == "" then return false end
    if not (UnitExists("focus") and UnitCanAttack("player", "focus")) then return false end

    if UnitLevel(unit) ~= UnitLevel("focus") then return false end
    if UnitPowerType(unit) ~= UnitPowerType("focus") then return false end
    if UnitClassification(unit) ~= UnitClassification("focus") then return false end
    if (not not UnitIsLieutenant(unit)) ~= (not not UnitIsLieutenant("focus")) then return false end
    if (not not select(2, UnitCreatureFamily(unit))) ~= (not not select(2, UnitCreatureFamily("focus"))) then return false end
    -- 施法目标存在性一致（二者当前都在施法中）
    if (not not UnitSpellTargetName(unit)) ~= (not not UnitSpellTargetName("focus")) then return false end
    return true
end

-- 打断提醒是否忽略焦点目标：
-- 控制台开关“有焦点也提醒打断”开启时 → 始终提醒打断；否则按原逻辑仅在无焦点时提醒
-- 供 UNIT_SPELLCAST_START / UNIT_SPELLCAST_CHANNEL 等共用
-- 传入本次施法单位 unit（nameplateN），用于判定“是否让位给焦点播报”：
-- 当“有焦点也提醒打断”与“焦点特定技能施法条”同时开启，且施法单位与焦点特征完全一致
-- （说明焦点走 FocusInterrupt 播报），这里返回 false，避免同一施法播报两次。
function addonTable.ShouldWarnInterruptWithFocus(unit)
    local db = DiGuaTimelineAudioHelper
    if db and db.interruptIgnoreFocus then
        if db.focusCastBarEnabled and IsFocusLikeUnit(unit) then
            return false
        end
        return true
    end
    return not UnitExists("focus")
end

function addonTable.FindBestVoice()
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

-- 获取玩家职责（优先通过专精获取，无专精时兜底队伍职责）
function addonTable.GetPlayerRole()
    local spec = GetSpecialization()
    local role = spec and GetSpecializationRole(spec)

    if role and role ~= "NONE" then
        return role
    end

    -- 兜底：未选择专精时回退至队伍职责
    return UnitGroupRolesAssigned("player")
end

-- ==================== 专精 近战/远程 分类 ====================
-- specID -> 战斗定位（"MELEE" 近战 / "RANGED" 远程）
addonTable.SpecPosition = {
    melee = {
        -- 近战输出
        70, -- 圣骑士-惩戒
        71, -- 战士-武器
        72, -- 战士-狂暴
        103, -- 德鲁伊-野性
        251, -- 死亡骑士-冰霜
        252, -- 死亡骑士-邪恶
        259, -- 潜行者-刺杀
        260, -- 潜行者-狂徒
        261, -- 潜行者-敏锐
        263, -- 萨满-增强
        269, -- 武僧-踏风
        577, -- 恶魔猎手-浩劫
        255, -- 猎人-生存
        -- 坦克
        66, -- 圣骑士-防护
        73, -- 战士-防护
        104, -- 德鲁伊-守护
        250, -- 死亡骑士-鲜血
        268, -- 武僧-酒仙
        581, -- 恶魔猎手-复仇
        -- 治疗
        65, -- 圣骑士-神圣
        270, -- 武僧-织雾
    },
    ranged = {
        -- 远程输出
        62, -- 法师-奥术
        63, -- 法师-火焰
        64, -- 法师-冰霜
        102, -- 德鲁伊-平衡
        253, -- 猎人-兽王
        254, -- 猎人-射击
        258, -- 牧师-暗影
        262, -- 萨满-元素
        265, -- 术士-痛苦
        266, -- 术士-恶魔学识
        267, -- 术士-毁灭
        1467, -- 唤魔师-湮灭
        1473, -- 唤魔师-增辉
        1480, -- 恶魔猎手-噬灭（远程施法者）
        -- 治疗
        105, -- 德鲁伊-恢复
        256, -- 牧师-戒律
        257, -- 牧师-神圣
        264, -- 萨满-恢复
        1468, -- 唤魔师-恩护
    },
}

-- 根据专精 ID 返回 "MELEE" / "RANGED"，未知专精返回 nil
-- 不传参数（或传 nil）时，自动使用玩家当前专精
function addonTable.GetSpecPosition(specID)
    if not specID then
        local specIndex = GetSpecialization()
        if not specIndex then return nil end
        specID = select(1, GetSpecializationInfo(specIndex))
    end
    for _, id in ipairs(addonTable.SpecPosition.melee) do
        if id == specID then return "MELEE" end
    end
    for _, id in ipairs(addonTable.SpecPosition.ranged) do
        if id == specID then return "RANGED" end
    end
    return nil
end

--- 连续顺序播放音频函数
--- 支持传入任意数量的【延迟时间】和【音频文件名】组合
function addonTable.PlayAudioSequence(...)
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
                local fullPath = addonTable.GetMediaPath() .. fileName
                local willPlay = PlaySoundFile(fullPath, DiGuaTimelineAudioHelper.audioChannel)
                
                -- 2. 动态兜底逻辑：如果当前播放失败（willPlay为假/nil），且当前用的不是内置默认路径
                --    （即启用了第三方 DiGua- 语音包且恰好缺该文件），则改用内置 Media 路径再试一次
                if not willPlay and addonTable.GetMediaPath() ~= addonTable.GetDefaultMediaPath() then
                    local fallbackPath = addonTable.GetDefaultMediaPath() .. fileName
                    PlaySoundFile(fallbackPath, DiGuaTimelineAudioHelper.audioChannel)
                end
            end)
        end
    end
end

-- ==================== 固定默认路径音频 ====================
-- 以下文件无论是否启用第三方 DiGua- 语音包，都强制从内置 Media 目录播放
-- （保证关键警报音永远使用本插件自带的原始音源，不被语音包替换）
local FIXED_DEFAULT_PATH_SOUNDS = {
    ["alarmbeep.ogg"] = true,
    ["jingbao.ogg"]   = true,
    ["bubu.ogg"]      = true,
}

--- 获取音频完整路径（带固定默认路径覆盖）
--- 传入 "xxx.ogg" 文件名，返回完整路径。
--- 若文件名命中固定列表，则强制使用内置默认路径；否则使用当前语音包/内置路径。
--- 注意：本函数在运行时才调用，因此即使依赖 Core.lua 中定义的
--- GetMediaPath / GetDefaultMediaPath（加载顺序靠后）也不受影响。
function addonTable.GetSoundFullPath(fileName)
    if FIXED_DEFAULT_PATH_SOUNDS[fileName:lower()] then
        local defaultPath = addonTable.GetDefaultMediaPath and addonTable.GetDefaultMediaPath()
        if defaultPath then
            return defaultPath .. fileName
        end
    end
    return addonTable.GetMediaPath() .. fileName
end

-- 🛠️ 职责优先的特征指纹扫描仪（施法/意图/能量 强固版）
function addonTable.IsMobTargetAndPlayerFingerprintMatch(mobToken)
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

    -- 1. 服务器判定
    local sameServer = UnitIsSameServer(targetToken)
    -- print(string.format("|cff00ff00[地瓜指纹]|r 🌐 服务器判定 -> 目标与你同服状态: [%s]", tostring(sameServer)))
    if not sameServer then
        -- print("|cff00ff00[地瓜指纹]|r ❌ 服务器指纹不一致，拦截。")
        return false
    end
    
    -- =========================================================
    -- 🎖️ 新增：荣誉等级绝杀锁
    -- =========================================================
    -- local targetHonorLevel = UnitHonorLevel(targetToken) or 0
    -- local playerHonorLevel = UnitHonorLevel("player") or 0
    -- -- print(string.format("|cff00ff00[地瓜指纹]|r 🎖️ 荣誉等级对比 -> 目标: [%d] | 玩家: [%d]", targetHonor, playerHonor))
    -- if targetHonorLevel ~= playerHonorLevel then
    --     -- print("|cff00ff00[地瓜指纹]|r ❌ 荣誉等级（PvP账号DNA）不匹配，无情拦截！")
    --     return false
    -- end    
    
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


function addonTable.GetTopWidgetText()
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

local RING_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Ring_20px.tga"
local RING_COLOR_NORMAL = {0.4, 1, 0.8, 0.85}
local RING_COLOR_ALARM = {1, 0.2, 0.2, 0.9}

local TargetCircleEndTime = 0
local CurrentCircleIsCastSensitive = false
local activeCircleTimer = nil
local backupHideTimer = nil

-- 创建主光圈 UI
local RingFrame = CreateFrame("Frame", "MyCustomCircleTimer", UIParent)
RingFrame:SetSize(120, 120)
RingFrame:SetPoint("CENTER", 0, 0)
RingFrame:Hide()

local bg = RingFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture(RING_PATH)
bg:SetVertexColor(0, 0, 0, 0.3)

local cd = CreateFrame("Cooldown", nil, RingFrame, "CooldownFrameTemplate")
cd:SetAllPoints()
cd:SetDrawEdge(false)
cd:SetDrawSwipe(true)
cd:SetSwipeTexture(RING_PATH)
cd:SetSwipeColor(unpack(RING_COLOR_NORMAL))
cd:SetHideCountdownNumbers(true)
cd:SetBlingTexture("")

-- 更新光圈颜色与音效
local function UpdateRingColor(isAlarm)
    if isAlarm then
        PlaySoundFile(addonTable.GetSoundFullPath("BuBu.ogg"), DiGuaTimelineAudioHelper.audioChannel)
        cd:SetSwipeColor(unpack(RING_COLOR_ALARM))
    else
        cd:SetSwipeColor(unpack(RING_COLOR_NORMAL))
    end
end

-- 强制隐藏光圈及清理定时器
local function ForceHideRingFrame()
    RingFrame:Hide()
    CurrentCircleIsCastSensitive = false
    if cd:GetScript("OnUpdate") then
        cd:SetScript("OnUpdate", nil)
    end
    if activeCircleTimer then activeCircleTimer:Cancel(); activeCircleTimer = nil end
    if backupHideTimer then backupHideTimer:Cancel(); backupHideTimer = nil end
end

-- 启动光圈倒计时 (增加 checkCast 参数)
function addonTable.StartCircleTimerBySeconds(seconds, checkCast, PlayerIsSpellTarget)
    local duration = tonumber(seconds)
    if not duration or duration <= 0 then return end
    if PlayerIsSpellTarget == nil then PlayerIsSpellTarget = true end

    local startTime = GetTime()
    TargetCircleEndTime = startTime + duration
    CurrentCircleIsCastSensitive = checkCast

    UpdateRingColor(false)

    if DiGuaTimelineAudioHelper.ringEnabled then
        cd:SetCooldown(startTime, duration)
        RingFrame:Show()
    else
        RingFrame:Hide()
        return
    end

    RingFrame:SetAlphaFromBoolean(PlayerIsSpellTarget, 0.85, 0)

    -- 清理旧的 OnUpdate 与定时器
    cd:SetScript("OnUpdate", nil)
    if activeCircleTimer then activeCircleTimer:Cancel() end
    if backupHideTimer then backupHideTimer:Cancel() end

    local hasTriggeredAlarm = false -- 状态标记：防重复播放音效

    -- 实时检测玩家施法安全状态
    cd:SetScript("OnUpdate", function(self)
        local now = GetTime()
        local remainingCircle = TargetCircleEndTime - now

        if remainingCircle <= 0 then
            self:SetScript("OnUpdate", nil)
        else
            -- 施法时长敏感度检测
            if CurrentCircleIsCastSensitive then
                local _, _, _, _, castEndTime = UnitCastingInfo("player")
                if not castEndTime then
                    _, _, _, _, castEndTime = UnitChannelInfo("player")
                end

                local isDangerous = false
                if castEndTime then
                    local castRemaining = (castEndTime / 1000) - now
                    -- 关键逻辑：玩家施法剩余时间 > 光圈剩余时间 时判定为危险
                    if castRemaining > remainingCircle then
                        isDangerous = true
                    end
                end

                -- 状态切换判定与音效触发
                if isDangerous and not hasTriggeredAlarm then
                    UpdateRingColor(true)  -- 变红 + 播放音效
                    hasTriggeredAlarm = true
                elseif not isDangerous and hasTriggeredAlarm then
                    UpdateRingColor(false) -- 恢复原色
                    hasTriggeredAlarm = false
                end
            end
        end
    end)

    activeCircleTimer = C_Timer.NewTimer(duration, ForceHideRingFrame)
    backupHideTimer = C_Timer.NewTimer(15, ForceHideRingFrame)
end


----------------------------------------------------------------------
-- 以下为 Bar 模块保持不变
----------------------------------------------------------------------

local BAR_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Bar_20px.tga"

local BAR_COLOR_NORMAL = {0.4, 1, 0.8, 0.85}
local BAR_COLOR_ALARM = {1, 0.2, 0.2, 0.9}
local TargetBarEndTime = 0
local CurrentBarIsCastSensitive = false
local activeBarTimer = nil
local backupBarHideTimer = nil

-- 创建主进度条 UI
local BarFrame = CreateFrame("Frame", "MyCustomBarTimerFrame", UIParent)
BarFrame:SetSize(120, 15)
BarFrame:SetPoint("CENTER", 0, 60)
BarFrame:Hide()

-- 进度条背景
local barBg = BarFrame:CreateTexture(nil, "BACKGROUND")
barBg:SetAllPoints()
barBg:SetTexture(BAR_PATH)
barBg:SetVertexColor(0, 0, 0, 0.3)

-- 进度条主体
local statusBar = CreateFrame("StatusBar", nil, BarFrame)
statusBar:SetAllPoints()
statusBar:SetStatusBarTexture(BAR_PATH)
statusBar:SetStatusBarColor(unpack(BAR_COLOR_NORMAL))
statusBar:SetMinMaxValues(0, 1)
statusBar:SetValue(1)

-- 更新进度条颜色与音效
function UpdateBarColor(isAlarm)
    if isAlarm then
        PlaySoundFile(addonTable.GetSoundFullPath("BuBu.ogg"), DiGuaTimelineAudioHelper.audioChannel)
        statusBar:SetStatusBarColor(unpack(BAR_COLOR_ALARM))
    else
        statusBar:SetStatusBarColor(unpack(BAR_COLOR_NORMAL))
    end
end

-- 强制隐藏进度条及清理定时器
local function ForceHideBarFrame()
    BarFrame:Hide()
    CurrentBarIsCastSensitive = false
    if statusBar:GetScript("OnUpdate") then
        statusBar:SetScript("OnUpdate", nil)
    end
    if activeBarTimer then activeBarTimer:Cancel(); activeBarTimer = nil end
    if backupBarHideTimer then backupBarHideTimer:Cancel(); backupBarHideTimer = nil end
end

-- 启动 Bar 倒计时
function addonTable.StartBarTimerBySeconds(seconds, checkCast, PlayerIsSpellTarget)
    local duration = tonumber(seconds)
    if not duration or duration <= 0 then return end
    if PlayerIsSpellTarget == nil then PlayerIsSpellTarget = true end

    local startTime = GetTime()
    TargetBarEndTime = startTime + duration
    CurrentBarIsCastSensitive = checkCast

    UpdateBarColor(false)

    if DiGuaTimelineAudioHelper.ringEnabled then -- 或使用独立的 barEnabled 变量
        BarFrame:Show()
    else
        BarFrame:Hide()
        return
    end

    BarFrame:SetAlphaFromBoolean(PlayerIsSpellTarget, 0.85, 0)

    -- 清理旧的 OnUpdate 与定时器
    statusBar:SetScript("OnUpdate", nil)
    if activeBarTimer then activeBarTimer:Cancel() end
    if backupBarHideTimer then backupBarHideTimer:Cancel() end

    local hasTriggeredAlarm = false -- 状态标记：防重复播放音效

    -- 驱动进度条平滑减少
    statusBar:SetScript("OnUpdate", function(self)
        local now = GetTime()
        local remainingBar = TargetBarEndTime - now

        if remainingBar <= 0 then
            self:SetValue(0)
            self:SetScript("OnUpdate", nil)
        else
            self:SetValue(remainingBar / duration)

            -- 施法时长敏感度检测
            if CurrentBarIsCastSensitive then
                -- 获取玩家施法信息（第 5 个返回值 endTimeMillis 为毫秒单位的结束时间）
                local _, _, _, _, castEndTime = UnitCastingInfo("player")
                if not castEndTime then
                    _, _, _, _, castEndTime = UnitChannelInfo("player")
                end

                local isDangerous = false
                if castEndTime then
                    local castRemaining = (castEndTime / 1000) - now
                    -- 关键逻辑：玩家施法剩余时间 > Bar 剩余时间 时判定为危险
                    if castRemaining > remainingBar then
                        isDangerous = true
                    end
                end

                -- 状态切换判定与音效触发
                if isDangerous and not hasTriggeredAlarm then
                    UpdateBarColor(true)  -- 变红 + 播放音效
                    hasTriggeredAlarm = true
                elseif not isDangerous and hasTriggeredAlarm then
                    UpdateBarColor(false) -- 恢复原色（如果玩家取消施法或快读完条了）
                    hasTriggeredAlarm = false
                end
            end
        end
    end)

    activeBarTimer = C_Timer.NewTimer(duration, ForceHideBarFrame)
    backupBarHideTimer = C_Timer.NewTimer(15, ForceHideBarFrame)
end

-- 生成"按当前法术快照"过滤代码块的工具函数（调试/抓取条件用，供 UNIT_SPELLCAST_START / CHANNEL 调用）
function addonTable.GenerateAllSpecsCodeBlock(unitTarget)
    if not UnitExists(unitTarget) then return end
    
    local spellName, _, _, _, _, _, _, _, spellID = UnitCastingInfo(unitTarget)
    if not spellName then
        spellName, _, _, _, _, _, _, _, spellID = UnitChannelInfo(unitTarget)
    end
    spellName = spellName or "未知法术"
    local spellComment = spellName .. (spellID and (" (" .. spellID .. ")") or "")

    C_Timer.After(0.5, function()
        if not UnitExists(unitTarget) then print("❌ [错误] 0.5秒后怪物血条已消失") return end

        print("🎯 [开始抓取快照] 技能 => " .. spellComment)
        print("--------------------------------------------------")

        local canAttack = UnitCanAttack("player", unitTarget)
        print(" -> 是否可攻击:", canAttack)

        local currentMapID = C_Map.GetBestMapForUnit("player") or 0  
        print(" -> 当前地图ID:", currentMapID)

        local subZoneText = GetSubZoneText() or ""
        print(" -> 当前子区域名字:", subZoneText ~= "" and subZoneText or "无")

        local name = UnitName(unitTarget) or "未知"
        print(" -> 怪物名字:", name)

        local actualLevel = UnitLevel(unitTarget) or 0
        print(" -> 实际等级:", actualLevel)

        local classification = UnitClassification(unitTarget) or "normal"
        print(" -> 分类(精英/普通):", classification)

        local isLieutenant = UnitIsLieutenant(unitTarget)
        print(" -> 是否为中尉(Lieutenant):", isLieutenant)

        local unitPowerType = UnitPowerType(unitTarget) or 0   
        print(" -> 能量类型代码:", unitPowerType)

        -- local sex = UnitSex(unitTarget) or 1
        -- print(" -> 性别代码:", sex)

        local isInside = IsIndoors()
        print(" -> 是否在室内:", isInside)

        -- -- 严格获取大写英文职业名
        -- local className = select(2, UnitClass(unitTarget)) or "NONE"
        -- print(" -> 职业名称:", className)

        -- local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 1, "HELPFUL") 
        -- print(" -> 1号位增益光环(SpellID):", auraData and auraData.spellId or "无")

        local inCombat = UnitAffectingCombat(unitTarget)
        print(" -> 是否在战斗中:", inCombat)

        local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo() or 0
        print(" -> 大秘境层数:", keyLevel)

        local creatureFamily, familyID = UnitCreatureFamily(unitTarget)
        creatureFamily = creatureFamily or "无"
        print(" -> 生物家族:", creatureFamily, "(家族ID:", familyID or "nil", ")")

        local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
        local stepName = (type(stepInfo) == "table" and stepInfo.title) or "无"
        print(" -> 战役步骤名称:", stepName)

        local actualValue, percentValue, percentValueString = C_ScenarioInfo.GetUnitCriteriaProgressValues("target")
        print(" -> 战役条件进度(数值/百分比/文本):", actualValue, percentValue, percentValueString)

        local currentPercentText = GetTrashProgressString and GetTrashProgressString() or "0%"
        print(" -> 当前小怪进度%:", currentPercentText)

        local hasTarget = UnitExists(unitTarget .. "target")
        print(" -> 目标是否存在(是否有目标):", hasTarget)

        local rawTargetName = UnitSpellTargetName(unitTarget) 
        print(" -> 法术指向目标名字:", rawTargetName)

        local targetRole = UnitGroupRolesAssigned(unitTarget .. "target") or "NONE"
        print(" -> 目标职责(TANK/HEALER/DAMAGER):", targetRole)

        local instName, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        instanceID = instanceID or 0
        print(" -> 副本信息(副本名/ID):", instName, instanceID)

        local boss1Kill = C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false   
        local boss2Kill = C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false
        local boss3Kill = C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false 
        local boss4Kill = C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false
        print(" -> Boss击杀状态(1-4号):", boss1Kill, boss2Kill, boss3Kill, boss4Kill)

        print("--------------------------------------------------")

        -- 计算战斗文本注释
        local combatComment = inCombat and "在战斗中" or "不在战斗中"
        
        -- 计算室内文本注释
        local indoorComment = isInside and "在室内" or "在室外"

        -- 计算性别文本注释
        local sexComment = "无性别"
        if sex == 2 then sexComment = "男性" elseif sex == 3 then sexComment = "女性" end

        -- 计算分类注释
        local classifcationComment = "普通怪"
        if classification == "elite" then classifcationComment = "精英怪"
        elseif classification == "rare" then classifcationComment = "稀有怪"
        elseif classification == "rareelite" then classifcationComment = "稀有精英"
        elseif classification == "worldboss" then classifcationComment = "世界Boss" end

        -- 动态匹配客户端常量等级字符串
        local levelCodeStr = tostring(actualLevel)
        if actualLevel == 90 then
            levelCodeStr = "PLAYER_LEVEL"
        elseif actualLevel == 91 then
            levelCodeStr = "NEXT_PLAYER_LEVEL"
        elseif actualLevel == 92 then
            levelCodeStr = "BOSS_LEVEL"
        elseif actualLevel == -1 then
            levelCodeStr = "-1"
        end

        local spellTargetCodeStr = rawTargetName and "            and UnitSpellTargetName(unitTarget) -- 法术有目标" or "            and not UnitSpellTargetName(unitTarget) -- 法术没目标"
        local hasTargetStr = hasTarget and "UnitExists(unitTarget .. \"target\")" or "not UnitExists(unitTarget .. \"target\")"
        -- local roleCheckStr = (hasTarget and targetRole ~= "NONE") and (" and UnitGroupRolesAssigned(unitTarget .. \"target\") == \"" .. targetRole .. "\"") or ""

        -- 建立生物家族的判定行
        local familyCodeStr = familyID and "            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族" or "            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族"

        -- 纯净版运行代码块生成
        print("        if unitTarget and unitTarget:find(\"nameplate\") and UnitCanAttack(\"player\", unitTarget)")
        print("            and select(8, GetInstanceInfo()) == " .. instanceID .. " -- 副本ID (" .. (instName or "未知") .. ")")
        print("            and (C_Map.GetBestMapForUnit(\"player\") or 0) == " .. currentMapID .. " -- 地图ID")
        if subZoneText ~= "" then
            print("            and GetSubZoneText() == \"" .. subZoneText .. "\" -- 子区域 (" .. subZoneText .. ")")
        end
        print("            and IsIndoors() == " .. tostring(isInside) .. " -- " .. indoorComment)
        print("            and UnitLevel(unitTarget) == " .. levelCodeStr .. " -- 怪物等级: " .. actualLevel)
        print("            and UnitPowerType(unitTarget) == " .. unitPowerType)
        -- print("            and UnitSex(unitTarget) == " .. sex .. " -- " .. sexComment)
        print("            and UnitClassification(unitTarget) == \"" .. classification .. "\" -- " .. classifcationComment)
        print("            and UnitIsLieutenant(unitTarget) == " .. tostring(isLieutenant) .. " -- 是否为中尉")
        print("            and UnitAffectingCombat(unitTarget) == " .. tostring(inCombat) .. " -- " .. combatComment)
        
        -- 生成代码块时，严格输出大写英文键，不夹带任何本地化文本
        -- if className ~= "NONE" then
        --     print("            and select(2, UnitClass(unitTarget)) == \"" .. className .. "\"")
        -- end

        -- 动态生成生物家族代码行
        print(familyCodeStr)
        
        -- 4个Boss击杀状态判定条件生成
        print("            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == " .. tostring(boss1Kill) .. " -- Boss1")
        print("            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == " .. tostring(boss2Kill) .. " -- Boss2")
        print("            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == " .. tostring(boss3Kill) .. " -- Boss3")
        print("            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == " .. tostring(boss4Kill) .. " -- Boss4")

        print(spellTargetCodeStr)
        print("        then")
        print("            C_Timer.After(0.5, function()")
        -- print("                if UnitExists(unitTarget) and " .. hasTargetStr .. roleCheckStr .. " then")
        print("                    PlaySoundFile(MEDIA_PATH .. \"音频文件名.ogg\", DiGuaTimelineAudioHelper.audioChannel)")
        print("                end")
        print("            end)")
        print("        end")
    end)
end