-- 文件名：BloodlustDetector.lua
-- 功能：监测10分钟嗜血开启与结束，并播放对应的提示音（通过副本唯一ID精准锁定，团本中不生效）

local addonName, addonTable = ...

local frame = CreateFrame("Frame")

-- ==================== 嗜血DEBUFF列表 ====================
local BLOODLUST_DEBUFFS = {
    [57723] = true,  -- 饱足 (萨满)
    [57724] = true,  -- 心满意足 (法师)
    [80354] = true,  -- 时空错乱 (时空扭曲)
    [95809] = true,  -- 衰竭 (猎人)
    [160455] = true, -- 疲倦
    [264689] = true, -- 疲倦 (鼓)
    [390435] = true, -- 消耗殆尽 (龙希尔)
}

-- ==================== 核心控制变量 ====================
local isBloodlustActive = false 
local savedInstanceID = nil -- 记录开启嗜血时，玩家所在的那个绝对唯一的副本ID

-- ==================== 核心检测逻辑 ====================
local function CheckPlayerHasDebuff()
    for spellID in pairs(BLOODLUST_DEBUFFS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then
            return true
        end
    end
    return false
end

-- ==================== 事件处理 ====================
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("CHALLENGE_MODE_START") 
frame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED") -- 新增：难度或副本状态切换时安全重置

frame:SetScript("OnEvent", function(self, event, ...)
    -- 【防御核心】如果是团本，直接拦截，且如果在团本里，必须保持状态清空
    local _, instanceType = GetInstanceInfo()
    if instanceType == "raid" then
        if isBloodlustActive or savedInstanceID then
            isBloodlustActive = false
            savedInstanceID = nil
        end
        return 
    end

    if event == "UNIT_AURA" then
        local unit = ...
        if unit ~= "player" then return end
        
        local hasDebuffRightNow = CheckPlayerHasDebuff()
        
        -- 获取主文件的路径与声道配置
        local MEDIA_PATH = addonTable.GetMediaPath and addonTable.GetMediaPath() or ""
        local audioChannel = DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master"
        
        -- 【功能1】开启嗜血：现在身上有Debuff，且我们之前没记录过
        if hasDebuffRightNow and not isBloodlustActive then
            isBloodlustActive = true
            -- 只有在真正获得 Debuff 的瞬间，才去获取并绑定副本唯一 ID
            local _, _, _, _, _, _, _, currentInstanceID = GetInstanceInfo()
            savedInstanceID = currentInstanceID
            -- 开启提示音（需要可自行取消注释）
            -- PlaySoundFile(MEDIA_PATH .. "ShiXueKaiQi.ogg", audioChannel)
            
        -- 【功能2】嗜血结束：延迟 0.4 秒，用来吃掉插钥匙或切地图带来的瞬间清除
        elseif not hasDebuffRightNow and isBloodlustActive then
            C_Timer.After(0.4, function()
                -- 安全保护：防蓝条导致的短暂消失
                if CheckPlayerHasDebuff() then return end
                
                -- 再次确认状态，防止多重异步回调冲突
                if isBloodlustActive then
                    -- 再次做一次团本拦截，防止延迟回调在出副本/进团本后触发
                    local _, freshInstanceType, _, _, _, _, _, freshInstanceID = GetInstanceInfo()
                    if freshInstanceType == "raid" then return end
                    
                    -- 【精准播报】只有当 当前副本ID 与 开启时的副本ID 完全一致时，才播放声音
                    if savedInstanceID == freshInstanceID and C_ChallengeMode.GetActiveKeystoneInfo() and C_ChallengeMode.GetActiveKeystoneInfo() >= 2 then
                        PlaySoundFile(MEDIA_PATH .. "ShiXueHaoLe.ogg", audioChannel)
                    end
                    
                    -- 【核心修复】闭环清空状态
                    isBloodlustActive = false
                    savedInstanceID = nil 
                end
            end)
        end

    -- 大秘境插钥匙的瞬间，或者由于各种意外触发了重置机制
    elseif event == "CHALLENGE_MODE_START" or event == "PLAYER_DIFFICULTY_CHANGED" then
        isBloodlustActive = false
        savedInstanceID = nil
        
    elseif event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then return end
        
        -- 首次加载初始化
        if CheckPlayerHasDebuff() then
            isBloodlustActive = true
            local _, _, _, _, _, _, _, currentInstanceID = GetInstanceInfo()
            savedInstanceID = currentInstanceID
        else
            isBloodlustActive = false
            savedInstanceID = nil
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)