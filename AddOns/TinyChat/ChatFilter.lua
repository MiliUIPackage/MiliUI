
-------------------------------------
-- 過濾廣告
-- @Author: 彩虹ui
-------------------------------------

--廣告關鍵字
--每行一個關鍵字，用雙引號括起來，結尾加上逗號。
--最後一行結尾不要加逗號。
local defaultKeywords = {
    "加V",
	"賣金",
    "卖金",
    "賣G",
    "卖G",
    "团本",
    "团木",
    "團本",
    "團木",
    "團長",
    "团长",
    "秘境",
    "大秘",
    "大米",
    "大密",
    "秘境",
    "密境",
    "秘镜",
    "密镜",
    "米镜",
    "米境",
    "消费",
    "消費",
    "专车",
    "專車",
    "化身巨龙牢窟",
    "清水",
    "躺尸",
    "可躺",
    "30人",
    "微信",
    "v信",
    "v:",
    "v：",
    "wei信",
    "wei:",
    "wei：",
    "微:",
    "微：",
    "散买",
    "散買",
    "散賣",
    "散卖",
    "面前",
    "效率",
    "手工",
    "开打",
    "開打",
    "躺全程",
    "包團",
    "包团",
    "大團",
    "大团",
    "2O層",
    "20層",
    "2O层",
    "20层",
    "20M",
    "M20",
    "M2O",
    "血腥",
    "上號",
    "上号",
    "詢價",
    "詢价",
    "询价",
    "询價",
    "童鉀",
    "童钾",
    "童甲",
    "铜钾",
    "铜鉀",
    "散嘪",
    "散唛",
    "两件",
    "兩件",
    "全交",
    "购",
    "T.B",
    "親自",
    "亲自",
    "亲手",
    "親手",
    "淘",
    "陪玩",
    "业务",
    "新新",
    "第1赛季",
    "靜思",
    "静思"
}

local Channels = {
    "^交易",
    "^綜合",
    "^尋求組隊$",
	"^組隊頻道$",
	"新手頻道",
	"^Trade",
	"^General",
	"Newcommer Chat",
	"^综合",
	"新人频道",
}

local keywords = {}
local filterCache = {} -- 快取功能，參考 Wind Chat Filter 插件。
local isTinyChatEnabled
local isInInstance
local locale = GetLocale()
local L = {
	TotalKeywords = { zhTW = "目前共有 ", zhCN = "目前共有" },
	TotalKeywords2 = { zhTW = " 個過濾關鍵字:", zhCN = " 个过滤关键字:" },
	NeedWord = { zhTW = "請輸入要新增的關鍵字。", zhCN = "请输入要新增的关键字。" },
	NeedWordOrIndex = { zhTW = "請輸入要刪除的關鍵字或編號。", zhCN = "请输入要删除的关键字或编号。" },
	WordAdded = { zhTW = "已新增關鍵字", zhCN = "已新增关键字" },
	WordDeleted = { zhTW = "已刪除關鍵字", zhCN = "已删除关键字" },
	InvalidIndex = { zhTW = "沒有這個編號!", zhCN = "没有这个编号!" },
	InvalidWord = { zhTW = "沒有找到關鍵字", zhCN = "没有找到关键字" },
	IndexChanged = { zhTW = "提醒: 編號已經變動。", zhCN = "提醒: 编号已经变动。" },
	ResetDone = { zhTW = "已恢復成預設的過濾關鍵字。", zhCN = "已恢复成预设的过滤关键字。" },
	HelpTitle = { zhTW = "TinyChat 聊天按鈕和功能增強|n過濾垃圾訊息 - 自訂關鍵字指令用法:", zhCN = "TinyChat 聊天按钮和功能增强|n过滤垃圾讯息 - 自订关键字指令用法:" },
	HelpList = { zhTW = "  |cffFFFF00/tc 關鍵字|r - 列出所有過濾關鍵字。", zhCN = "/tc listwords - 列出所有过滤关键字。" },
	HelpAdd = { zhTW = "  |cffFFFF00/tc 新增|r |cffFF0000文字|r - 新增過濾關鍵字，一次只能新增一個。", zhCN = "/tc addword 文字 - 新增过滤关键字，一次只能新增一个。" },
	HelpDel = { zhTW = "  |cffFFFF00/tc 刪除|r |cffFF0000文字(或編號)|r - 刪除過濾關鍵字或用 '/tc 關鍵字' 指令列出的編號。", zhCN = "/tc delword 文字(或编号) - 删除过滤关键字或用 listwords 指令列出的编号。" },
	HelpReset = { zhTW = "  |cffFFFF00/tc 重置關鍵字|r - 恢復成預設的過濾關鍵字。", zhCN = "/tc resetwords - 恢复成预设的过滤关键字。" },
	Yell = { zhTW = "大喊", zhCN = "大喊" },
}

--依照關鍵字來過濾訊息
local function hasKeyword(msg)
	for _, v in ipairs(keywords) do
		if string.find(msg, v, 1, true) then
			return true
		end
	end
	return false
end

-- 是否為熊貓人DK
local function isPandaDK(guid)
	local ok, _, englishClass, _, englishRace = pcall(GetPlayerInfoByGUID, guid)
	if ok and englishClass and englishRace then
		if englishClass == "DEATHKNIGHT" and englishRace == "Pandaren" then
			return true
		end
	end
	return false
end

--過濾器
local function filter(_, event, msg, sender, _, _, _, _, _, _, channelName, _, _, guid)
	if (not TinyChatDB or not TinyChatDB.Spam) and guid then
		-- 已經在快取中直接判斷
		if type(filterCache[guid]) == "boolean" then
				return filterCache[guid]
		end
		
		if event == "CHAT_MSG_CHANNEL" then
			-- 頻道，檢查頻道名稱
			for _, v in ipairs(Channels) do
                if string.find(channelName, v) then
					if isPandaDK(guid) or hasKeyword(msg) then
						-- 加入快取
						filterCache[guid] = true
						return true
					else
						filterCache[guid] = false
						return false
					end
                end
            end
		elseif event == "CHAT_MSG_WHISPER" then
			if C_BattleNet.GetAccountInfoByGUID(guid) or C_FriendList.IsFriend(guid) then
				-- 好友密語不過濾
				filterCache[guid] = false
				return false
			elseif isPandaDK(guid) or hasKeyword(msg) then
				-- 其他人有關鍵字
				filterCache[guid] = true
				return true
			else
				-- 其他人沒關鍵字
				filterCache[guid] = false
				return false
			end
			
		else
			-- 對話，副本中不過濾
			if isInInstance then return false end

			if isPandaDK(guid) or hasKeyword(msg) then
				filterCache[guid] = true
				return true
			else
				filterCache[guid] = false
				return false
			end
		end
	end
	return false
end

local function OnEvent(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		isTinyChatEnabled = IsAddOnLoaded("TinyChat")
		if not TinyChatDB then TinyChatDB = {} end
		if not TinyChatDB.FilterKeywords or #TinyChatDB.FilterKeywords == 0 then 
			-- 還沒有關鍵字時使用預設的
			TinyChatDB.FilterKeywords = defaultKeywords
		end
		keywords = TinyChatDB.FilterKeywords
	else
		isInInstance = IsInInstance()
		if not TinyChatDB.BubbleManually then -- event == "ZONE_CHANGED_NEW_AREA"
			-- 進出副本自動開關聊天泡泡
			if isInInstance then
				if tonumber(C_CVar.GetCVar("ChatBubbles")) == 0 then
					C_CVar.SetCVar("ChatBubbles", 1)
					print(ENABLE..CHAT_BUBBLES_TEXT)
				end
			else
				if tonumber(C_CVar.GetCVar("ChatBubbles")) == 1 then
					C_CVar.SetCVar("ChatBubbles", 0)
					print(DISABLE..CHAT_BUBBLES_TEXT)
				end
			end
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:SetScript("OnEvent", OnEvent)

ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_EMOTE", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filter)

------------------------
--自訂關鍵字相關功能
------------------------

local function listKeywords()
	print((L["TotalKeywords"][locale] or "Total Keywords: ").. #keywords .. (L["TotalKeywords2"][locale] or ""))
	for i = 1, #keywords do
		print(i .. ". " .. keywords[i])
	end
	return
end

local function addKeyword(key)
	if not key then
		print(L["NeedWord"][locale] or "Need a word.")
		return
	end
	table.insert(keywords, key)
	print((L["WordAdded"][locale] or "Keyword added") .. ": " .. key)
end

local isInt = function(n)
  return (type(n) == "number") and (math.floor(n) == n)
end

local function delKeyword(key)
	if not key then
		print(L["NeedWordOrIndex"][locale] or "Need a word or index number.")
		return
	end
	local j, n = 1, #keywords;
	local isDeleted = false
	
	-- 檢查是否是編號
	if isInt(tonumber(key)) then
		key = keywords[tonumber(key)]
		if not key then
			print(L["InvalidIndex"][locale] or "Invalid index number!")
			return
		end
	end

    for i=1,n do
        if (keywords[i] ~= key) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                keywords[j] = keywords[i];
                keywords[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            keywords[i] = nil;
			print((L["WordDeleted"][locale] or "Keyword deleted") .. ": " .. key)
			print(L["IndexChanged"][locale] or "Index changed!")
			isDeleted = true
        end
    end
	if not isDeleted then
		print((L["InvalidWord"][locale] or "Keyword not found") .. ": " .. key)
	end
	return
end

SLASH_TinyChat1 = "/tinychat"
SLASH_TinyChat2 = "/tc"
function SlashCmdList.TinyChat(msg)
    local cmd, cmdarg = strsplit(" ", msg, 2)
	if (cmd == "關鍵字" or cmd == "listwords") then
		listKeywords()
	elseif (cmd == "新增" or cmd == "addword") then
		addKeyword(cmdarg)
	elseif (cmd == "刪除" or cmd == "delword") then
		delKeyword(cmdarg)
	elseif (cmd == "重置關鍵字" or cmd == "resetwords") then
		TinyChatDB.FilterKeywords = defaultKeywords
		keywords = TinyChatDB.FilterKeywords
		print((L["ResetDone"][locale] or "All Keywords reseted."))
	else
		print(L["HelpTitle"][locale] or "TinyChat - Spam Filtering Keyword Command Usage:")
		print(L["HelpList"][locale] or "  /tc listwords - List all filtering keywords.")
		print(L["HelpAdd"][locale] or "  /tc addword [keyword] - Add keyword.")
		print(L["HelpDel"][locale] or "  /tc delword [keyword|index] - Delete by keyword or by index number.")
		print(L["HelpReset"][locale] or "  /tc resetwords - Reset to default keywords.")
    end
end