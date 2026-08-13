-- Utils.lua
-- 插件通用工具函数库（挂载于 addonTable，供全插件调用）

local addonName, addonTable = ...

--- 创建自定义战斗时间轴计时条
function addonTable.CustomEncounterBar(iconID, duration, name)
    iconID = iconID or 132117
    duration = duration or 10
    name = name or "未命名提示"

    C_EncounterTimeline.AddScriptEvent({
        spellID = 0,
        iconFileID = iconID,
        duration = duration,
        overrideName = name,
        icons = 0x1,
        severity = 2,
        maxQueueDuration = 0,
        paused = false,
    })
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
                
                -- 定义默认的本地兜底路径
                local defaultPath = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
                
                -- 2. 动态兜底逻辑：如果当前播放失败（willPlay为假/nil），且我们当前用的不是默认路径
                --    则说明用的是第三方语音包（无论是 WYJJ 还是 Ranran），立即改用本地 Media 路径再试一次
                if not willPlay and addonTable.GetMediaPath() ~= defaultPath then
                    local fallbackPath = defaultPath .. fileName
                    PlaySoundFile(fallbackPath, DiGuaTimelineAudioHelper.audioChannel)
                end
            end)
        end
    end
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
local TargetEndTime = 0
local CurrentRingIsCastSensitive = false
local activeCircleTimer = nil
local backupHideTimer = nil

-- 3. 创建主光圈 UI
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
cd:SetSwipeColor(0.4, 1, 0.8, 0.85)
cd:SetHideCountdownNumbers(true)
cd:SetBlingTexture("")

function UpdateRingColor(isAlarm)
    if isAlarm then
        PlaySoundFile(MEDIA_PATH .. "BuBu.ogg", DiGuaTimelineAudioHelper.audioChannel)
        cd:SetSwipeColor(unpack(RING_COLOR_ALARM))
    else
        cd:SetSwipeColor(unpack(RING_COLOR_NORMAL))
    end
end

local function ForceHideRingFrame()
    RingFrame:Hide()
    CurrentRingIsCastSensitive = false
    if activeCircleTimer then activeCircleTimer:Cancel(); activeCircleTimer = nil end
    if backupHideTimer then backupHideTimer:Cancel(); backupHideTimer = nil end
end

function addonTable.StartCircleTimerBySeconds(seconds, checkCast, PlayerIsSpellTarget)
    local duration = tonumber(seconds)
    if not duration or duration <= 0 then return end
    if PlayerIsSpellTarget == nil then PlayerIsSpellTarget = true end

    local startTime = GetTime()
    TargetEndTime = startTime + duration
    CurrentRingIsCastSensitive = checkCast

    UpdateRingColor(false)

    if DiGuaTimelineAudioHelper.ringEnabled then
        cd:SetCooldown(startTime, duration)
        RingFrame:Show()
    else
        RingFrame:Hide()
        return
    end

    RingFrame:SetAlphaFromBoolean(PlayerIsSpellTarget, 0.85, 0)

    if activeCircleTimer then activeCircleTimer:Cancel() end
    if backupHideTimer then backupHideTimer:Cancel() end

    activeCircleTimer = C_Timer.NewTimer(duration, ForceHideRingFrame)
    backupHideTimer = C_Timer.NewTimer(15, ForceHideRingFrame)
end


