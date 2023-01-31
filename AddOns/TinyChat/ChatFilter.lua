
-------------------------------------
-- 過濾廣告
-- @Author: 彩虹ui
-------------------------------------

--廣告關鍵字
--每行一個關鍵字，用雙引號括起來，結尾加上逗號。
--最後一行結尾不要加逗號。
local keywords = {
 "微信",
 "加徽",
 "手工",
 "满级",
 "站樁",
 "躺过",
 "躺全程",
 "可躺",
 "消费",
 "散賣",
 "自由挑选",
 "自由選本",
 "茼甲"
}

local locale = GetLocale()
local L = {
    Trade = { zhTW = "交易", zhCN = "交易" }
}

--依照關鍵字來過濾訊息
local function hasKeyword(msg)
	for i = 1, #keywords do
		if string.find(msg, keywords[i], 1, true) then
			return true
		end
	end
	return false
end

--過濾器
local function filter(self, event, msg, ...)
    if (not TinyChatDB or not TinyChatDB.Spam) and hasKeyword(msg) then
		return true
	end
	return false, msg, ...
end

local function filterChannel(self, event, msg, ...)
local _, _, channelName = ...
    if (not TinyChatDB or not TinyChatDB.Spam) and string.find(channelName, L["Trade"][locale] or "Trade", 1, true) and hasKeyword(msg) then
		return true
	end
	return false, msg, ...
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_EMOTE", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filterChannel)


-- 自動開關聊天泡泡
-- local function OnEvent(self, event, ...)
-- 	if (not TinyChatDB or not TinyChatDB.Spam) then
-- 		if IsInInstance() then
-- 			C_CVar.SetCVar("ChatBubbles", 1)
-- 		else
-- 			C_CVar.SetCVar("ChatBubbles", 0)
-- 		end
-- 	end
-- end

local f = CreateFrame("Frame")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:SetScript("OnEvent", OnEvent)