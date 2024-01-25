local SpellAnnouncer = CreateFrame("Frame", "SpellAnnouncerFrame")
SpellAnnouncer:RegisterEvent("UNIT_SPELLCAST_START")
SpellAnnouncer:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")

-- 傳送門法術
local portalSpellMap = {
    -- Dragonflight S3
    [159901] = "永茂林地",
    [424142] = "海潮王座",
    [424153] = "玄鴉堡",
    [424163] = "暗心灌木林",
    [424167] = "威奎斯特莊園",
    [424187] = "阿塔達薩",
    [424197] = "恆龍黎明",
}

-- 術士傳送門
local ritualOfSummoning = {
    698,
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

-- 監聽事件
SpellAnnouncer:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_START" or "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, spellGUID, spellID = ...
        -- 檢查是否不在戰鬥中以及在隊伍中
        -- 檢查施法者是否為玩家或隊伍成員
        if not IsInCombat() and IsInGroup() and (unit == "player" or string.find(unit, "party")) then
            -- 檢查是否施放的是傳送門法術
            if portalSpellMap[spellID] then
                local spellLink = GetSpellLink(spellID)
                local name, realm = UnitName(unit)
                local location = portalSpellMap[spellID]
                local message = name .. "正在施放" .. spellLink .. "傳送到" .. location .. "！"
                if unit == "player" then
                    SendChatMessage(message, "PARTY")
                else
                    DEFAULT_CHAT_FRAME:AddMessage(string.rep("-", 50), 1, 0.64, 0)
                    print(' ')
                    print('|cfffdcb3b' .. message ..'|r')
                    print(' ')
                    DEFAULT_CHAT_FRAME:AddMessage(string.rep("-", 50), 1, 0.64, 0)
                end
            end

            if table.contains(ritualOfSummoning, spellID) then
                local spellLink = GetSpellLink(spellID)
                local name, realm = UnitName(unit)
                local message = name .. "正在進行" .. spellLink .. "，請協助點門。"
                if unit == "player" then
                    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
                        SendChatMessage(message, "INSTANCE_CHAT")
                    elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
                        SendChatMessage(message, "RAID")
                    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
                        SendChatMessage(message, "PARTY")
                    end
                else
                    DEFAULT_CHAT_FRAME:AddMessage(string.rep("-", 50), 1, 0.64, 0)
                    print(' ')
                    print('|cfffdcb3b' .. message ..'|r')
                    print(' ')
                    DEFAULT_CHAT_FRAME:AddMessage(string.rep("-", 50), 1, 0.64, 0)
                end
            end
        end
    end
end)