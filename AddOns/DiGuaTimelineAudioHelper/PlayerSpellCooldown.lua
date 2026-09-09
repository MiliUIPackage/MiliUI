-- PlayerSpellCooldown.lua

local addonName, addonTable = ...

addonTable.PlayerSpellStatus = {
    spells = {} -- [spellID] = isAvailable
}

-- ==================== 职业打断技能 CD 表（按专精编号索引） ====================
-- 结构：[专精ID] = { [法术名] = { name = 中文名, spellID = 技能ID, cooldown = CD秒 } }
-- 每个专精编号单独一组，放该专精可用的打断技能（无通用组0）
addonTable.InterruptCooldowns = {
    -- ===== 盗贼（刺杀/狂徒/敏锐）=====
    [259] = { ["脚踢"] = { name = "脚踢", spellID = 1766, cooldown = 15 } },  -- 刺杀
    [260] = { ["脚踢"] = { name = "脚踢", spellID = 1766, cooldown = 15 } },  -- 狂徒
    [261] = { ["脚踢"] = { name = "脚踢", spellID = 1766, cooldown = 15 } },  -- 敏锐

    -- ===== 战士（武器/狂暴/防护）=====
    [71] = { ["拳击"] = { name = "拳击", spellID = 6552, cooldown = 15 } },   -- 武器
    [72] = { ["拳击"] = { name = "拳击", spellID = 6552, cooldown = 15 } },   -- 狂暴
    [73] = { ["拳击"] = { name = "拳击", spellID = 6552, cooldown = 15 } },   -- 防护

    -- ===== 法师（奥术/火焰/冰霜）=====
    [62] = { ["法术反制"] = { name = "法术反制", spellID = 2139, cooldown = 25 } },  -- 奥术
    [63] = { ["法术反制"] = { name = "法术反制", spellID = 2139, cooldown = 25 } },  -- 火焰
    [64] = { ["法术反制"] = { name = "法术反制", spellID = 2139, cooldown = 25 } },  -- 冰霜

    -- ===== 猎人（兽王/射击：反制射击；生存：压制）=====
    [253] = { ["反制射击"] = { name = "反制射击", spellID = 147362, cooldown = 24 } },  -- 兽王
    [254] = { ["反制射击"] = { name = "反制射击", spellID = 147362, cooldown = 24 } },  -- 射击
    [255] = { ["压制"] = { name = "压制", spellID = 187707, cooldown = 15 } }, -- 生存

    -- ===== 萨满（元素/增强 12s；恢复 30s）=====
    [262] = { ["风剪"] = { name = "风剪", spellID = 57994, cooldown = 12 } },  -- 元素
    [263] = { ["风剪"] = { name = "风剪", spellID = 57994, cooldown = 12 } },  -- 增强
    [264] = { ["风剪"] = { name = "风剪", spellID = 57994, cooldown = 30 } },  -- 恢复

    -- ===== 德鲁伊（平衡额外有日光术）=====
    [102] = { ["日光术"] = { name = "日光术", spellID = 78675, cooldown = 60 } },  -- 平衡
    [103] = { ["迎头痛击"] = { name = "迎头痛击", spellID = 106839, cooldown = 15 } },  -- 野性
    [104] = { ["迎头痛击"] = { name = "迎头痛击", spellID = 106839, cooldown = 15 } },  -- 守护

    -- ===== 圣骑士（防护/惩戒）=====
    [66] = { ["责难"] = { name = "责难", spellID = 96231, cooldown = 15 } },   -- 防护
    [70] = { ["责难"] = { name = "责难", spellID = 96231, cooldown = 15 } },   -- 惩戒

    -- ===== 牧师（仅暗影有打断）=====
    [258] = { ["沉默"] = { name = "沉默", spellID = 15487, cooldown = 30 } },  -- 暗影

    -- ===== 死亡骑士（鲜血/冰霜/邪恶）=====
    [250] = { ["心灵冰冻"] = { name = "心灵冰冻", spellID = 47528, cooldown = 15 } },  -- 鲜血
    [251] = { ["心灵冰冻"] = { name = "心灵冰冻", spellID = 47528, cooldown = 15 } },  -- 冰霜
    [252] = { ["心灵冰冻"] = { name = "心灵冰冻", spellID = 47528, cooldown = 15 } },  -- 邪恶

    -- ===== 恶魔猎手（浩劫/复仇/噬灭）=====
    [577] = { ["瓦解"] = { name = "瓦解", spellID = 183752, cooldown = 15 } },  -- 浩劫
    [581] = { ["瓦解"] = { name = "瓦解", spellID = 183752, cooldown = 15 } },  -- 复仇
    [1480] = { ["瓦解"] = { name = "瓦解", spellID = 183752, cooldown = 15 } }, -- 噬灭

    -- ===== 唤魔师（湮灭/增辉有 Quell；恩护无打断）=====
    [1467] = { ["镇压"] = { name = "镇压", spellID = 351338, cooldown = 20 } },  -- 湮灭
    [1473] = { ["镇压"] = { name = "镇压", spellID = 351338, cooldown = 18 } },  -- 增辉

    -- ===== 术士（地狱猎犬/恶魔卫士：Spell Lock；恶魔学识另有 Axe Toss）=====
    [265] = { ["法术封锁"] = { name = "法术封锁", spellID = 119910, cooldown = 24 } },  -- 痛苦
    [266] = { ["法术封锁"] = { name = "法术封锁", spellID = 119910, cooldown = 24 }, ["投掷飞斧"] = { name = "投掷飞斧", spellID = 119914, cooldown = 30 } },  -- 恶魔学识
    [267] = { ["法术封锁"] = { name = "法术封锁", spellID = 119910, cooldown = 24 } },  -- 毁灭

    -- ===== 武僧（酒仙/踏风/织雾）=====
    [268] = { ["切喉手"] = { name = "切喉手", spellID = 116705, cooldown = 15 } },  -- 酒仙
    [269] = { ["切喉手"] = { name = "切喉手", spellID = 116705, cooldown = 15 } },  -- 踏风
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
        name = "爆發藥水",
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

-- ==================== 打断技能注册与查询（联动 FocusInterrupt） ====================
-- 已注册的打断技能（用于换专精时清理）
local registeredInterrupts = {} -- [spellID] = true

local function UnregisterInterrupts()
    for spellID in pairs(registeredInterrupts) do
        registeredInterrupts[spellID] = nil
        myMonitoredSpells[spellID] = nil
        if activeTimers[spellID] then
            activeTimers[spellID]:Cancel()
            activeTimers[spellID] = nil
        end
        UpdateSpellStatus(spellID, true)
    end
end

-- 按玩家当前专精，把可用打断技能注册进监控（施放后自动进入 CD 倒计时）
local function RegisterInterrupts()
    local specIndex = GetSpecialization()
    if not specIndex then return end
    local specID = select(1, GetSpecializationInfo(specIndex))
    local interruptSpells = addonTable.InterruptCooldowns[specID]
    if not interruptSpells then return end -- 该专精没有打断
    for _, cfg in pairs(interruptSpells) do
        local id = cfg.spellID
        if not registeredInterrupts[id] then
            registeredInterrupts[id] = true
            myMonitoredSpells[id] = { ids = { id }, cooldown = cfg.cooldown, name = cfg.name }
            UpdateSpellStatus(id, true)
        end
    end
end

-- 判断当前专精的打断是否全部在 CD（true=都在 CD，不该提醒打断）
-- 专精无打断 / 未注册时返回 false（不拦截）
function addonTable.IsInterruptOnCooldown()
    local specIndex = GetSpecialization()
    if not specIndex then return false end
    local specID = select(1, GetSpecializationInfo(specIndex))
    local interruptSpells = addonTable.InterruptCooldowns[specID]
    if not interruptSpells then return false end
    for _, cfg in pairs(interruptSpells) do
        if addonTable.PlayerSpellStatus.spells[cfg.spellID] ~= false then
            return false -- 有至少一个打断可用
        end
    end
    return true
end

local EventListener = CreateFrame("Frame")
EventListener:RegisterEvent("PLAYER_LOGIN")
EventListener:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
EventListener:RegisterEvent("CHALLENGE_MODE_START")
EventListener:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

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

        -- C. 注册职业打断技能（供 FocusInterrupt 判断打断是否在 CD）
        RegisterInterrupts()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- 切换专精：重新注册打断技能
        UnregisterInterrupts()
        RegisterInterrupts()

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
        -- 允许宠物施放（术士打断 Spell Lock / Axe Toss 由恶魔施放）
        if unitTarget ~= "player" and unitTarget ~= "pet" then return end

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