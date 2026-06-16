-- RaceTraits.lua
-- ============================================================================
-- 1. 插件变量挂载与通用技能表（与 Core 通信）
-- ============================================================================
local addonName, addonTable = ...

-- 初始化私有表：现在改为存储所有已激活技能的状态大表
addonTable.RaceAuraStatus = {
    currentRace = "Unknown",
    skills = {} -- 核心：用来存放每个技能的独立状态，格式：[spellID] = isAvailable
}

-- 独立的技能配置表（以后想加任何技能，直接在这里加一行就行）
local RACES_AND_ABILITIES = {
    ["NightElf"] = {
        { spellID = 58984, cd = 120 }, -- 影遁
    },
    ["Dwarf"] = {
        { spellID = 20594, cd = 120 }, -- 石像形态
    },
    -- 预留扩展样例：
    -- ["BloodElf"] = {
    --     { spellID = 202719, cd = 90 }, -- 奥术洪流 (90秒)
    -- }
}

-- 运行时激活的监控映射表：[spellID] = cd_duration
local activeMonitoredSpells = {}
-- 运行时的定时器实例池：[spellID] = timer_handle
local activeTimers = {}

-- ============================================================================
-- 2. 状态更新与独立通知
-- ============================================================================
local function UpdateSkillStatus(spellID, isAvailable)
    addonTable.RaceAuraStatus.skills[spellID] = isAvailable
    
    -- 回调通知接口（Core.lua 挂载此函数可实时捕获是哪个技能变动了）
    if addonTable.OnRaceAuraStatusChanged then
        addonTable.OnRaceAuraStatusChanged(spellID, isAvailable)
    end
end

-- ============================================================================
-- 3. 事件驱动框架（支持多技能并行硬编码独立计时）
-- ============================================================================
local EventListener = CreateFrame("Frame")
EventListener:RegisterEvent("PLAYER_LOGIN")

EventListener:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- 1. 获取玩家种族
        local _, raceFile = UnitRace("player")
        addonTable.RaceAuraStatus.currentRace = raceFile
        
        -- 2. 解析当前种族需要监控的所有技能
        local raceSkills = RACES_AND_ABILITIES[raceFile]
        
        if raceSkills then
            hasSkillsToMonitor = false
            for _, skillInfo in ipairs(raceSkills) do
                local spellID = skillInfo.spellID
                local cdDuration = skillInfo.cd
                
                -- 将技能注册进激活池和外部通信表
                activeMonitoredSpells[spellID] = cdDuration
                UpdateSkillStatus(spellID, true) -- 默认全部可用
                hasSkillsToMonitor = true
            end
            
            -- 3. 只要该种族有需要监控的技能，就开启玩家自身施法事件
            if hasSkillsToMonitor then
                self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            end
        end
        
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- 4. 自身施法成功判定
        local _, _, _, _, spellID = ...
        
        -- 检查这个 spellID 是不是在我们的监控池里
        local cdDuration = activeMonitoredSpells[spellID]
        if cdDuration then
            -- 如果该技能已经在 CD 中，拦截防御
            if not addonTable.RaceAuraStatus.skills[spellID] then return end
            
            -- 触发该技能的独立硬编码 CD
            UpdateSkillStatus(spellID, false)
            
            -- 如果该技能之前有还没跑完的定时器，先取消它（防止连按导致计时重叠）
            if activeTimers[spellID] then
                activeTimers[spellID]:Cancel()
            end
            
            -- 5. 为该技能量身定制一个独立沙漏
            activeTimers[spellID] = C_Timer.After(cdDuration, function()
                UpdateSkillStatus(spellID, true) -- 时间到，仅将当前技能设为可用
                activeTimers[spellID] = nil
            end)
        end
    end
end)