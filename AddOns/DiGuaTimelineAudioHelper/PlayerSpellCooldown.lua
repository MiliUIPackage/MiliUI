-- PlayerSpellCooldown.lua

local addonName, addonTable = ...

addonTable.PlayerSpellStatus = {
    spells = {} -- [spellID] = isAvailable
}

-- ==================== 職業打斷技能 CD 表（按專精編號索引） ====================
-- 結構：[專精ID] = { [法術名] = { name = 中文名, spellID = 技能ID, cooldown = CD秒 } }
-- 每個專精編號單獨一組，放該專精可用的打斷技能（無通用組0）
addonTable.InterruptCooldowns = {
    -- ===== 盜賊（刺殺/狂徒/敏銳）=====
    [259] = { ["腳踢"] = { name = "腳踢", spellID = 1766, cooldown = 15 } },  -- 刺殺
    [260] = { ["腳踢"] = { name = "腳踢", spellID = 1766, cooldown = 15 } },  -- 狂徒
    [261] = { ["腳踢"] = { name = "腳踢", spellID = 1766, cooldown = 15 } },  -- 敏銳

    -- ===== 戰士（武器/狂暴/防護）=====
    [71] = { ["拳擊"] = { name = "拳擊", spellID = 6552, cooldown = 15 } },   -- 武器
    [72] = { ["拳擊"] = { name = "拳擊", spellID = 6552, cooldown = 15 } },   -- 狂暴
    [73] = { ["拳擊"] = { name = "拳擊", spellID = 6552, cooldown = 15 } },   -- 防護

    -- ===== 法師（奧術/火焰/冰霜）=====
    [62] = { ["法術反制"] = { name = "法術反制", spellID = 2139, cooldown = 25 } },  -- 奧術
    [63] = { ["法術反制"] = { name = "法術反制", spellID = 2139, cooldown = 25 } },  -- 火焰
    [64] = { ["法術反制"] = { name = "法術反制", spellID = 2139, cooldown = 25 } },  -- 冰霜

    -- ===== 獵人（獸王/射擊：反制射擊；生存：壓制）=====
    [253] = { ["反制射擊"] = { name = "反制射擊", spellID = 147362, cooldown = 24 } },  -- 獸王
    [254] = { ["反制射擊"] = { name = "反制射擊", spellID = 147362, cooldown = 24 } },  -- 射擊
    [255] = { ["壓制"] = { name = "壓制", spellID = 187707, cooldown = 15 } }, -- 生存

    -- ===== 薩滿（元素/增強 12s；恢復 30s）=====
    [262] = { ["風剪"] = { name = "風剪", spellID = 57994, cooldown = 12 } },  -- 元素
    [263] = { ["風剪"] = { name = "風剪", spellID = 57994, cooldown = 12 } },  -- 增強
    [264] = { ["風剪"] = { name = "風剪", spellID = 57994, cooldown = 30 } },  -- 恢復

    -- ===== 德魯伊（平衡額外有日光術）=====
    [102] = { ["日光術"] = { name = "日光術", spellID = 78675, cooldown = 60 } },  -- 平衡
    [103] = { ["迎頭痛擊"] = { name = "迎頭痛擊", spellID = 106839, cooldown = 15 } },  -- 野性
    [104] = { ["迎頭痛擊"] = { name = "迎頭痛擊", spellID = 106839, cooldown = 15 } },  -- 守護

    -- ===== 聖騎士（防護/懲戒）=====
    [66] = { ["責難"] = { name = "責難", spellID = 96231, cooldown = 15 } },   -- 防護
    [70] = { ["責難"] = { name = "責難", spellID = 96231, cooldown = 15 } },   -- 懲戒

    -- ===== 牧師（僅暗影有打斷）=====
    [258] = { ["沉默"] = { name = "沉默", spellID = 15487, cooldown = 30 } },  -- 暗影

    -- ===== 死亡騎士（鮮血/冰霜/邪惡）=====
    [250] = { ["心靈冰凍"] = { name = "心靈冰凍", spellID = 47528, cooldown = 15 } },  -- 鮮血
    [251] = { ["心靈冰凍"] = { name = "心靈冰凍", spellID = 47528, cooldown = 15 } },  -- 冰霜
    [252] = { ["心靈冰凍"] = { name = "心靈冰凍", spellID = 47528, cooldown = 15 } },  -- 邪惡

    -- ===== 惡魔獵手（浩劫/復仇/噬滅）=====
    [577] = { ["瓦解"] = { name = "瓦解", spellID = 183752, cooldown = 15 } },  -- 浩劫
    [581] = { ["瓦解"] = { name = "瓦解", spellID = 183752, cooldown = 15 } },  -- 復仇
    [1480] = { ["瓦解"] = { name = "瓦解", spellID = 183752, cooldown = 15 } }, -- 噬滅

    -- ===== 喚魔師（湮滅/增輝有 Quell；恩護無打斷）=====
    [1467] = { ["鎮壓"] = { name = "鎮壓", spellID = 351338, cooldown = 20 } },  -- 湮滅
    [1473] = { ["鎮壓"] = { name = "鎮壓", spellID = 351338, cooldown = 18 } },  -- 增輝

    -- ===== 術士（地獄獵犬/惡魔衛士：Spell Lock；惡魔學識另有 Axe Toss）=====
    [265] = { ["法術封鎖"] = { name = "法術封鎖", spellID = 119910, cooldown = 24 } },  -- 痛苦
    [266] = { ["法術封鎖"] = { name = "法術封鎖", spellID = 119910, cooldown = 24 }, ["投擲飛斧"] = { name = "投擲飛斧", spellID = 119914, cooldown = 30 } },  -- 惡魔學識
    [267] = { ["法術封鎖"] = { name = "法術封鎖", spellID = 119910, cooldown = 24 } },  -- 毀滅

    -- ===== 武僧（酒仙/踏風/織霧）=====
    [268] = { ["切喉手"] = { name = "切喉手", spellID = 116705, cooldown = 15 } },  -- 酒仙
    [269] = { ["切喉手"] = { name = "切喉手", spellID = 116705, cooldown = 15 } },  -- 踏風
}

-- 1. 種族技能映射表
local RACE_SPELL_CONFIG = {
    ["Dwarf"] = {
        [20594] = { name = "石像形態", cooldown = 120 },
    },
    ["NightElf"] = {
        [58984] = { name = "影遁", cooldown = 120 },
    },
}

-- 2. 通用技能映射表（可直接在 ids 裡寫多個 ID）
local COMMON_SPELL_CONFIG = {
    {
        ids = { 1236616, 1236998, 1236994 },
        name = "爆發藥水",
        cooldown = 300,
        onReady = function()
            local keystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            -- 增加 nil 校驗，防止不在大秘境時報錯
            if keystoneLevel and keystoneLevel >= 2 then
                PlaySoundFile(addonTable.GetMediaPath() .. "BaoFaYaoShuiHaoLe.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end
        end
    },
}

-- 運行時數據池
local myMonitoredSpells = {} -- [spellID] = config
local activeTimers = {}

local function UpdateSpellStatus(spellID, isAvailable)
    addonTable.PlayerSpellStatus.spells[spellID] = isAvailable
    if addonTable.OnPlayerSpellStatusChanged then
        addonTable.OnPlayerSpellStatusChanged(spellID, isAvailable)
    end
end

-- ==================== 打斷技能注冊與查詢（聯動 FocusInterrupt） ====================
-- 已注冊的打斷技能（用於換專精時清理）
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

-- 按玩家當前專精，把可用打斷技能注冊進監控（施放後自動進入 CD 倒計時）
local function RegisterInterrupts()
    local specIndex = GetSpecialization()
    if not specIndex then return end
    local specID = select(1, GetSpecializationInfo(specIndex))
    local interruptSpells = addonTable.InterruptCooldowns[specID]
    if not interruptSpells then return end -- 該專精沒有打斷
    for _, cfg in pairs(interruptSpells) do
        local id = cfg.spellID
        if not registeredInterrupts[id] then
            registeredInterrupts[id] = true
            myMonitoredSpells[id] = { ids = { id }, cooldown = cfg.cooldown, name = cfg.name }
            UpdateSpellStatus(id, true)
        end
    end
end

-- 判斷當前專精的打斷是否全部在 CD（true=都在 CD，不該提醒打斷）
-- 專精無打斷 / 未注冊時返回 false（不攔截）
function addonTable.IsInterruptOnCooldown()
    local specIndex = GetSpecialization()
    if not specIndex then return false end
    local specID = select(1, GetSpecializationInfo(specIndex))
    local interruptSpells = addonTable.InterruptCooldowns[specID]
    if not interruptSpells then return false end
    for _, cfg in pairs(interruptSpells) do
        if addonTable.PlayerSpellStatus.spells[cfg.spellID] ~= false then
            return false -- 有至少一個打斷可用
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
        -- A. 注冊通用技能
        for _, config in ipairs(COMMON_SPELL_CONFIG) do
            for _, spellID in ipairs(config.ids) do
                myMonitoredSpells[spellID] = config
                UpdateSpellStatus(spellID, true)
            end
        end

        -- B. 注冊種族技能
        local _, raceFile = UnitRace("player")
        local currentRaceSpells = RACE_SPELL_CONFIG[raceFile]
        if currentRaceSpells then
            for spellID, config in pairs(currentRaceSpells) do
                config.ids = { spellID }
                myMonitoredSpells[spellID] = config
                UpdateSpellStatus(spellID, true)
            end
        end

        -- C. 注冊職業打斷技能（供 FocusInterrupt 判斷打斷是否在 CD）
        RegisterInterrupts()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- 切換專精：重新注冊打斷技能
        UnregisterInterrupts()
        RegisterInterrupts()

    elseif event == "CHALLENGE_MODE_START" then
        -- 大秘境開始：取消所有倒計時，並重置所有技能為可用
        for spellID, timer in pairs(activeTimers) do
            if timer and not timer:IsCancelled() then
                timer:Cancel() -- 現在這裡可以正確取消 NewTimer 了
            end
            activeTimers[spellID] = nil
        end
        for spellID in pairs(myMonitoredSpells) do
            UpdateSpellStatus(spellID, true)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, _, spellID = ...
        -- 允許寵物施放（術士打斷 Spell Lock / Axe Toss 由惡魔施放）
        if unitTarget ~= "player" and unitTarget ~= "pet" then return end

        local config = myMonitoredSpells[spellID]
        if config then
            -- 如果已在 CD 中則忽略
            if not addonTable.PlayerSpellStatus.spells[spellID] then return end

            -- 同步將組內所有 ID 置為 CD 狀態，並取消舊定時器
            for _, id in ipairs(config.ids) do
                UpdateSpellStatus(id, false)
                if activeTimers[id] then
                    activeTimers[id]:Cancel()
                    activeTimers[id] = nil
                end
            end

            -- 開啟統一倒計時（改用 C_Timer.NewTimer 支持主動 Cancel）
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