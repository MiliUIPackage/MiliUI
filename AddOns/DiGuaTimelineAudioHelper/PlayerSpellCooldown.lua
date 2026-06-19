-- PlayerSpellCooldown.lua

local addonName, addonTable = ...

addonTable.PlayerSpellStatus = {
    spells = {} -- [spellID] = isAvailable
}

-- 重新把结构换回【种族 -> 技能组】的映射，方便直接用种族 Token 索引
local RACE_SPELL_CONFIG = {
    ["Dwarf"] = {
        [20594] = { name = "石像形态", cooldown = 120 },
    },
    -- ["DarkIronDwarf"] = {
    --     [273104] = { name = "烈火热血", cooldown = 120 }, -- 顺便帮黑铁矮人做个防御
    -- },
    ["NightElf"] = {
        [58984] = { name = "影遁", cooldown = 120 },
    },
}

-- 当前玩家角色真正需要监控的硬编码法术池
local myMonitoredSpells = {}
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

EventListener:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, raceFile = UnitRace("player")
        -- print(string.format("|cff00ff00[地瓜种族监控]|r 🌐 玩家登录！系统返回的你的种族 Token 是: 【%s】", tostring(raceFile)))
        
        local currentRaceSpells = RACE_SPELL_CONFIG[raceFile]
        
        if currentRaceSpells then
            -- print(string.format("|cff00ff00[地瓜种族监控]|r 🎯 成功匹配到该种族的硬编码表，开始注入..."))
            for spellID, config in pairs(currentRaceSpells) do
                myMonitoredSpells[spellID] = config
                UpdateSpellStatus(spellID, true)
                -- print(string.format("|cff00ff00[地瓜种族监控]|r ✅ 已载入: 【%s】(%d) CD: %d秒", config.name, spellID, config.cooldown))
            end
        else
            -- print(string.format("|cff00ff00[地瓜种族监控]|r ❌ 警告：配置表里【没有】写关于种族【%s】的配置！", tostring(raceFile)))
        end
        
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- 修正参数：正式服前三位分别是 unitTarget, castGUID, spellID
        local unitTarget, _, spellID = ...
        
        -- 强行拦截所有非玩家事件（不打印非玩家的，防止刷屏）
        if unitTarget ~= "player" then return end
        
        -- 【Debug 1】只要是玩家放的任何技能，统统打印出来！
        -- 如果你按了石像形态这里没打印，说明这个事件根本没抓到玩家放这个技能
        -- print(string.format("|cff00ff00[地瓜雷达]|r 🔮 玩家释放了法术，ID 为: 【%s】", tostring(spellID)))
        
        -- 3. 安全校验：只从当前种族的专属池里取配置
        local config = myMonitoredSpells[spellID]
        if config then
            -- print(string.format("|cff00ff00[地瓜种族监控]|r ⚡ 命中硬编码配置！检测到释放: 【%s】(%d)", config.name, spellID))
            
            if not addonTable.PlayerSpellStatus.spells[spellID] then 
                -- print(string.format("|cff00ff00[地瓜种族监控]|r ❌ 拦截：【%s】已经在倒计时 CD 中，忽略重复触发。", config.name))
                return 
            end
            
            UpdateSpellStatus(spellID, false)
            -- print(string.format("|cff00ff00[地瓜种族监控]|r ⏳ 【%s】进入硬编码倒计时: %d 秒", config.name, config.cooldown))
            
            if activeTimers[spellID] then
                activeTimers[spellID]:Cancel()
            end
            
            activeTimers[spellID] = C_Timer.After(config.cooldown, function()
                UpdateSpellStatus(spellID, true)
                activeTimers[spellID] = nil
                -- print(string.format("|cff00ff00[地瓜种族监控]|r 🎉 【%s】冷却恢复完毕！", config.name))
            end)
        else
            -- 【Debug 2】如果放了技能，但没有进上面的逻辑，说明在这里被过滤了
            -- 比如：放了石像形态，但由于上面登录时种族没对上，导致 myMonitoredSpells 里面是空的
            -- print(string.format("|cff00ff00[地瓜雷达]|r 💨 法术 %s 未在当前角色的种族监控池中，跳过。", tostring(spellID)))
        end
    end
end)