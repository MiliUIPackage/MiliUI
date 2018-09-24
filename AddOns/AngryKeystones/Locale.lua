local ADDON, Addon = ...
local Locale = Addon:NewModule('Locale')

local default_locale = "enUS"
local current_locale = GetLocale()

local langs = {}
langs.enUS = {
	config_characterConfig = "Per-character configuration",
	config_progressTooltip = "Show progress each enemy gives on their tooltip",
	config_progressFormat = "Enemy Forces Format",
	config_progressFormat_1 = "24.19%",
	config_progressFormat_2 = "90/372",
	config_progressFormat_3 = "24.19% - 90/372",
	config_progressFormat_4 = "24.19% (75.81%)",
	config_progressFormat_5 = "90/372 (282)",
	config_progressFormat_6 = "24.19% (75.81%) - 90/372 (282)",
	config_splitsFormat = "Objective Splits Display",
	config_splitsFormat_1 = "Disabled",
	config_splitsFormat_2 = "Time from start",
	config_splitsFormat_3 = "Relative to previous",
	config_autoGossip = "Automatically select gossip entries during Mythic Keystone dungeons (ex: Odyn)",
	config_silverGoldTimer = "Show timer for both 2 and 3 bonus chests at same time",
	config_completionMessage = "Show message with final times on completion of a Mythic Keystone dungeon",
	config_showSplits = "Show split time for each objective in objective tracker",
	keystoneFormat = "[Keystone: %s - Level %d]",
	completion0 = "Timer expired for %s with %s, you were %s over the time limit.",
	completion1 = "Beat the timer for %s in %s. You were %s ahead of the timer, and missed +2 by %s.",
	completion2 = "Beat the timer for +2 %s in %s. You were %s ahead of the +2 timer, and missed +3 by %s.",
	completion3 = "Beat the timer for +3 %s in %s. You were %s ahead of the +3 timer.",
	completionSplits = "Split timings were: %s.",
	timeLost = "Time Lost",
	config_smallAffixes = "Reduce the size of affix icons on timer frame",
	config_deathTracker = "Show death tracker on timer frame",
	config_persistTracker = "Show objective tracker after Mythic Keystone completion (requires Reload UI to take effect)",
	scheduleTitle = "Schedule",
	scheduleWeek1 = "This week",
	scheduleWeek2 = "Next week",
	scheduleWeek3 = "In two weeks",
	scheduleWeek4 = "In three weeks",
	scheduleMissingKeystone = "Requires a level 7+ Mythic Keystone in your inventory to display.",
	config_exclusiveTracker = "Hide quest and achievement trackers during Mythic Keystones (requires Reload UI to take effect)",
	config_hideTalkingHead = "Hide Talking Head dialog during a Mythic Keystone dungeon",
	config_resetPopup = "Show popup to reset instances upon leaving a completed Mythic Keystone dungeon",
	partyKeysTitle = "Party Keystones",
	newKeystoneAnnounce = "New Keystone: %s",
	currentKeystoneText = "Current: |cFFFFFFFF%s|r",
	config_announceKeystones = "Announce newly acquired Mythic Keystones to your party",
}
langs.enGB = langs.enUS

langs.zhCN = {
	config_characterConfig = "为角色进行独立的配置",
	config_progressTooltip = "聊天窗口的史诗钥石显示副本名称和等级",
	config_progressFormat = "敌方部队进度格式",
	config_splitsFormat = "进度分割显示方式",
	config_splitsFormat_1 = "禁用",
	config_splitsFormat_2 = "从头计时",
	config_splitsFormat_3 = "与之前关联",
	config_autoGossip = "在史诗钥石副本中自动对话交互（如奥丁）",
	config_silverGoldTimer = "同时显示2箱和3箱的计时",
	config_completionMessage = "副本完成时在聊天窗口显示总耗时",
	config_showSplits = "在任务列表的进度上显示单独的进度计时",
	keystoneFormat = "[%s（%d级）]",
	forcesFormat = " - 敌方部队 %s",
	completion0 = "你超时完成了 %s 的战斗。共耗时 %s，超出规定时间 %s。",
	completion1 = "你在规定时间内完成了 %s 的战斗！共耗时 %s，剩余时间 %s，2箱奖励超时 %s。",
	completion2 = "你在规定时间内获得了 %s 的2箱奖励！共耗时 %s，2箱奖励剩余时间 %s，3箱奖励超时 %s。",
	completion3 = "你在规定时间内获得了 %s 的3箱奖励！共耗时 %s，3箱奖励剩余时间 %s。",
	timeLost = "损失时间",
	config_smallAffixes = "缩小进度条上的光环图标大小",
	config_deathTracker = "在进度条上显示死亡统计",
	config_persistTracker = "副本完成后继续显示任务追踪（重载插件后生效）",
	scheduleTitle = "日程表",
	scheduleWeek1 = "本周",
	scheduleWeek2 = "下周",
	scheduleWeek3 = "两周后",
	scheduleWeek4 = "三周后",
	scheduleMissingKeystone = "你需要一把7级以上的钥石才可激活此项功能。",
	config_exclusiveTracker = "在副本中隐藏任务和成就追踪（重载插件后生效）",
	config_hideTalkingHead = "在史诗钥石副本中隐藏NPC情景对话窗口",
	config_resetPopup = "离开已完成的副本后提示是否重置",
	partyKeysTitle = "队伍钥石信息",
	newKeystoneAnnounce = "新钥石：%s",
	currentKeystoneText = "当前钥石：|cFFFFFFFF%s|r",
	config_announceKeystones = "在队伍里通报获得的新钥石",
}
langs.zhTW = {
	config_characterConfig = "為角色進行獨立的配置",
	config_progressTooltip = "聊天視窗的傳奇鑰石顯示副本名稱和等級",
	config_progressFormat = "敵方部隊進度格式",
	config_splitsFormat = "進度分割顯示方式",
	config_splitsFormat_1 = "禁用",
	config_splitsFormat_2 = "從頭計時",
	config_splitsFormat_3 = "與之前關聯",
	config_autoGossip = "在傳奇鑰石副本中自動進行對話互動（如歐丁）",
	config_silverGoldTimer = "同時顯示2箱及3箱的計時",
	config_completionMessage = "副本完成時在聊天窗口顯示總耗時",
	config_showSplits = "在任務列表的進度上顯示單獨的進度計時",
	keystoneFormat = "[%s（%d級）]",
	forcesFormat = " - 敵方部隊 %s",
	completion0 = "你超時完成了 %s 的戰鬥。共耗時 %s，超出規定時間 %s。",
	completion1 = "你在規定時間內完成了 %s 的戰鬥！共耗時 %s，剩餘時間 %s，2箱獎勵超時 %s。",
	completion2 = "你在規定時間內獲得了 %s 的2箱獎勵！共耗時 %s，2箱獎勵剩餘時間 %s，3箱獎勵超時 %s。",
	completion3 = "你在規定時間內獲得了 %s 的3箱獎勵！共耗時 %s，3箱獎勵剩餘時間 %s。",
	timeLost = "損失時間",
	config_smallAffixes = "縮小計時器上的光環圖標大小",
	config_deathTracker = "在計時器上顯示死亡統計",
	config_persistTracker = "副本完成後繼續顯示任務追蹤（重載插件後生效）",
	scheduleTitle = "日程表",
	scheduleWeek1 = "本周",
	scheduleWeek2 = "下周",
	scheduleWeek3 = "兩周後",
	scheduleWeek4 = "三周後",
	scheduleMissingKeystone = "你需要一把7級以上的鑰石來啟動此項功能。",
	config_exclusiveTracker = "在副本中隱藏成就和任務追蹤（重載插件後生效）",
	config_hideTalkingHead = "在傳奇鑰石副本中隱藏NPC情景對話視窗",
	config_resetPopup = "離開已完成的副本後提示是否重置",
	partyKeysTitle = "隊伍鑰石資訊",
	newKeystoneAnnounce = "新鑰石：%s",
	currentKeystoneText = "目前鑰石：|cFFFFFFFF%s|r",
	config_announceKeystones = "向你的隊伍通報新獲得的傳奇鑰石",
}

function Locale:Get(key)
	if langs[current_locale] and langs[current_locale][key] ~= nil then
		return langs[current_locale][key]
	else
		return langs[default_locale][key]
	end
end

function Locale:Local(key)
	return langs[current_locale] and langs[current_locale][key]
end

function Locale:Exists(key)
	return langs[default_locale][key] ~= nil
end

setmetatable(Locale, {__index = Locale.Get})
