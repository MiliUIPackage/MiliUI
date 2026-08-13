-- PlayerSpellCooldown.lua

local addonName, addonTable = ...

addonTable.PlayerSpellStatus = {
    spells = {} -- [spellID] = isAvailable
}

-- 1. 种族技能映射表
local RACE_SPELL_CONFIG = {
    ["Dwarf"] = {
        [20594] = { name = "石像形态", cooldown = 120 },
    },
    ["NightElf"] = {
        [58984] = { name = "影遁", cooldown = 120 },
    },
}

-- 2. 通用技能映射表（可直接在 ids 里写多个 ID）
local COMMON_SPELL_CONFIG = {
    {
        ids = { 1236616, 1236998, 1236994 },
        name = "爆发药水",
        cooldown = 300,
        onReady = function()
            local keystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            -- 增加 nil 校验，防止不在大秘境时报错
            if keystoneLevel and keystoneLevel >= 2 then
                PlaySoundFile(addonTable.GetMediaPath() .. "BaoFaYaoShuiHaoLe.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end
        end
    },
}

-- 运行时数据池
local myMonitoredSpells = {} -- [spellID] = config
local activeTimers = {}

local function UpdateSpellStatus(spellID, isAvailable)
    addonTable.PlayerSpellStatus.spells[spellID] = isAvailable
    if addonTable.OnPlayerSpellStatusChanged then
        addonTable.OnPlayerSpellStatusChanged(spellID, isAvailable)
    end
end

local EventListener = CreateFrame("Frame")
EventListener:RegisterEvent("PLAYER_LOGIN")
EventListener:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
EventListener:RegisterEvent("CHALLENGE_MODE_START")

EventListener:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- A. 注册通用技能
        for _, config in ipairs(COMMON_SPELL_CONFIG) do
            for _, spellID in ipairs(config.ids) do
                myMonitoredSpells[spellID] = config
                UpdateSpellStatus(spellID, true)
            end
        end

        -- B. 注册种族技能
        local _, raceFile = UnitRace("player")
        local currentRaceSpells = RACE_SPELL_CONFIG[raceFile]
        if currentRaceSpells then
            for spellID, config in pairs(currentRaceSpells) do
                config.ids = { spellID }
                myMonitoredSpells[spellID] = config
                UpdateSpellStatus(spellID, true)
            end
        end

    elseif event == "CHALLENGE_MODE_START" then
        -- 大秘境开始：取消所有倒计时，并重置所有技能为可用
        for spellID, timer in pairs(activeTimers) do
            if timer and not timer:IsCancelled() then
                timer:Cancel() -- 现在这里可以正确取消 NewTimer 了
            end
            activeTimers[spellID] = nil
        end
        for spellID in pairs(myMonitoredSpells) do
            UpdateSpellStatus(spellID, true)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, _, spellID = ...
        if unitTarget ~= "player" then return end

        local config = myMonitoredSpells[spellID]
        if config then
            -- 如果已在 CD 中则忽略
            if not addonTable.PlayerSpellStatus.spells[spellID] then return end

            -- 同步将组内所有 ID 置为 CD 状态，并取消旧定时器
            for _, id in ipairs(config.ids) do
                UpdateSpellStatus(id, false)
                if activeTimers[id] then
                    activeTimers[id]:Cancel()
                    activeTimers[id] = nil
                end
            end

            -- 开启统一倒计时（改用 C_Timer.NewTimer 支持主动 Cancel）
            local primaryID = config.ids[1]
            activeTimers[primaryID] = C_Timer.NewTimer(config.cooldown, function()
                for _, id in ipairs(config.ids) do
                    UpdateSpellStatus(id, true)
                    activeTimers[id] = nil
                end

                if config.onReady then
                    config.onReady()
                end
            end)
        end
    end
end)