-- 1. 定义技能表（变量名修改为 LINDORMIS_GLOW_BUFFS）
local LINDORMIS_GLOW_BUFFS = {
    [1295927] = true,
}

-- 2. 严格照抄、一字不改的你的核心函数（仅修改函数名与表名）
local function HasLindormisGlow()
    for spellID in pairs(LINDORMIS_GLOW_BUFFS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then
            return true
        end
    end
    return false
end

-- 3. 创建驱动 Frame 并直接注册事件
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_AURA")

-- 4. 凡是触发事件，就用你的新函数检测并打印
eventFrame:SetScript("OnEvent", function(self, event, unit)
    -- 依然只看玩家自己
    if unit == "player" then
        if HasLindormisGlow() then
            print("|cff00ff00[监控提示]|r 成功监控到 Lindormi's Glow (1295927)！")
        else
            print("|cffff0000[监控提示]|r 未检测到 Lindormi's Glow。")
        end
    end
end)