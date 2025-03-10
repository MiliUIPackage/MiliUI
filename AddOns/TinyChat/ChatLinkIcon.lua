
-------------------------------------
-- 聊天物品前增加ICON
-- @Author:M
-------------------------------------

--生成新的ICON超链接
local function GetHyperlink(Hyperlink, texture)
    if (not texture) then
        return Hyperlink
    else
        return " |T"..texture..":0|t" .. Hyperlink
    end
end

--等级图标显示
local function SetChatLinkIcon(Hyperlink)
    local schema, id = string.match(Hyperlink, "|H(%w+):(%d+):")
    local texture, castTime, minRange, maxRange
    if (schema == "item") then
        texture = select(10, C_Item.GetItemInfo(tonumber(id)))
    elseif (schema == "spell") then
		-- _, _, texture, castTime, minRange, maxRange = GetSpellInfo(tonumber(id))
		local spellInfo = C_Spell.GetSpellInfo(tonumber(id))
		if spellInfo then
			texture = spellInfo.iconID
			-- 簡單偵測是否為坐騎，坐騎不顯示圖示以免無法預覽外觀
			if spellInfo.castTime == 1500 and spellInfo.minRange == 0 and spellInfo.maxRange == 0 then
				texture = nil
			end
		else
			texture = nil
		end
		-- texture = select(3, GetSpellInfo(tonumber(id)))
    elseif (schema == "achievement") then
        texture = select(10, GetAchievementInfo(tonumber(id)))
    end
    return GetHyperlink(Hyperlink, texture)
end

--过滤器
local function filter(self, event, msg, ...)
    if (not TinyChatDB or not TinyChatDB.HideLinkIcon) then
		msg = msg:gsub("(|H%w+:%d+:.-|h.-|h)", SetChatLinkIcon)
	end
    return false, msg, ...
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BATTLEGROUND", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BATTLEGROUND_LEADER", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_COMMUNITIES_CHANNEL", filter)