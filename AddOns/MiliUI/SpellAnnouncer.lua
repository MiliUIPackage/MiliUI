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

local needToHelp = {
    698, -- 術士傳送門
}

local needToTake = {
    29893, -- 製造靈魂之井
    190336 -- 召喚餐點
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

-- 增加計時器
local spellCastTimer

-- 施法通報
local function HandleSpellMessage(unit, spellID, messagePrefix, detectAsPlayer)
    local spellLink = GetSpellLink(spellID)
    local name, realm = UnitName(unit)
    local message = name .. "正在施放" .. spellLink .. messagePrefix

    if (detectAsPlayer) then
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

local function HandleSpellCast(unit, spellID, detectAsPlayer)
    if portalSpellMap[spellID] then
        HandleSpellMessage(unit, spellID, "傳送到" .. portalSpellMap[spellID] .. "！", detectAsPlayer)
    end

    if table.contains(needToHelp, spellID) then
        HandleSpellMessage(unit, spellID, "，請協助點門。", detectAsPlayer)
    end

    if table.contains(needToTake, spellID) then
        HandleSpellMessage(unit, spellID, "，請記得拿取。", detectAsPlayer)
    end

end

-- 
local detectAsPlayer = false

-- 監聽事件
SpellAnnouncer:SetScript("OnEvent", function(self, event, ...)
    if (event == "UNIT_SPELLCAST_START") or (event == "UNIT_SPELLCAST_CHANNEL_START") then
        if (not IsInCombat()) and (IsInGroup() or IsInRaid()) then
            local unit, spellGUID, spellID = ...
            if unit == "player" or string.find(unit, "party") then
                if unit == "player" then
                    detectAsPlayer = true
                else
                    detectAsPlayer = false
                end

                -- 設置計時器，延遲處理
                spellCastTimer = C_Timer.NewTimer(0.1, function()
                    HandleSpellCast(unit, spellID, detectAsPlayer)
                end)
            elseif string.find(unit, "raid") then
                -- 如果計時器存在，則取消計時器
                if spellCastTimer then
                    spellCastTimer:Cancel()
                end
                HandleSpellCast(unit, spellID, detectAsPlayer)
            end
        end
    end
end)