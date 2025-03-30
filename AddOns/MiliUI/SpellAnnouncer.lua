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

    -- TWW S1
    [445418] = "波拉勒斯圍城戰", -- 聯盟
    [464256] = "波拉勒斯圍城戰", -- 部落
    [354464] = "特那希迷霧",
    [354462] = "死靈戰地",
    [445269] = "石庫",
    [445416] = "蛛絲城",
    [445417] = "回音之城",
    [445414] = "破曉者號",
    [445424] = "格瑞姆巴托",

    -- TWW S2
    [467553] = "晶喜鎮！",
    [467555] = "晶喜鎮！",
    [373274] = "機械岡行動 - 工坊",
    [354467] = "苦痛劇場",
    [445444] = "聖焰隱修院",
    [445443] = "培育所",
    [445441] = "暗焰裂縫",
    [445440] = "燼釀酒莊",
    [1216786] = "水閘行動",
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
    local spellLink = C_Spell.GetSpellLink(spellID)
    local name, realm = UnitName(unit)
    local message = "正在施放" .. spellLink .. messagePrefix
    if not detectAsPlayer then
        message = name .. message
    end

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
        HandleSpellMessage(unit, spellID, "前往[" .. portalSpellMap[spellID] .. "]！", detectAsPlayer)
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
                spellCastTimer = C_Timer.NewTimer(0.2, function()
                    HandleSpellCast(unit, spellID, detectAsPlayer)
                end)
            elseif string.find(unit, "raid") then
                -- 如果計時器存在，則取消計時器
                if spellCastTimer then
                    spellCastTimer:Cancel()
                end
                -- HandleSpellCast(unit, spellID, detectAsPlayer)
            end
        end
    end
end)