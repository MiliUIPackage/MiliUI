local SpellAnnouncer = CreateFrame("Frame", "SpellAnnouncerFrame")
SpellAnnouncer:RegisterEvent("UNIT_SPELLCAST_START")

local spellMap = {
    -- Dragonflight S3
    159901, -- 永茂林地
    424142, -- 海潮王座
    424153, -- 玄鴉堡
    424163, -- 暗心灌木林
    424167, -- 威奎斯特莊園
    424187, -- 阿塔達薩
    424197, -- 恆龍黎明
}

-- 判斷表格是否包含特定值
function table.contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- 是否在戰鬥中
function IsInCombat()
    return InCombatLockdown()
end

-- 監聽施法成功事件
SpellAnnouncer:SetScript("OnEvent", function(self, event, ...)
    local unit, spellGUID, spellID = ...
    -- 檢查是否在隊伍中
    -- 檢查施法者是否為玩家或隊伍成員
    if not IsInCombat() and IsInGroup() and (unit == "player" or string.find(unit, "party")) then
        -- 檢查是否施放的是指定的法術
        if table.contains(spellMap, spellID) then
            local spellDescription = GetSpellDescription(spellID)
            -- 取隊友技能的 GetSpellDescription 第一次有時候會出現空白
            -- 如果 spellDescription 為空白，再次執行一次
            if spellDescription == "" or spellDescription == nil then
                spellDescription = GetSpellDescription(spellID)
            end
            -- local location = string.match(spellDescription, "傳送至%s*(.-)入口")
            local spellLink = GetSpellLink(spellID)
            local name, realm = UnitName(unit)

            SendChatMessage(name .. "正在施放" .. spellLink .. spellDescription, "PARTY")
        end

    end
end)