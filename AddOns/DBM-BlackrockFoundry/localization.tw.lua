if GetLocale() ~= "zhTW" then return end
local L

---------------
-- Gruul --
---------------
L= DBM:GetModLocalization(1161)

L:SetOptionLocalization({
	MythicSoakBehavior	= "特別警告：吸收傷害的分組方式 (傳奇模式)",
	ThreeGroup			= "分3組1層就換",
	TwoGroup			= "分2組2層後換" 
})

---------------------------
-- Oregorger, The Devourer --
---------------------------
L= DBM:GetModLocalization(1202)

L:SetOptionLocalization({
	InterruptBehavior	= "設置中斷警告的運作方式",
	Smart				= "根據首領的脊刺層數發出中斷警告",
	Fixed				= "固定使用5或3的中斷輪換(即使首領什麼也沒做)"
})

---------------------------
-- The Blast Furnace --
---------------------------
L= DBM:GetModLocalization(1154)

L:SetWarningLocalization({
	warnRegulators			= "熱能調節閥剩餘:%d",
	warnBlastFrequency		= "爆炸施放頻率增加：大約每%d秒一次",
	specWarnTwoVolatileFire	= "你中了兩個烈性之火！"
})

L:SetOptionLocalization({
	warnRegulators			= "提示熱能調節閥還剩多少血量",
	warnBlastFrequency		= "提示$spell:155209施放頻率增加",
	specWarnTwoVolatileFire	= "當你中了兩個$spell:176121時顯示特別警告",
	InfoFrame				= "顯示$spell:155192與$spell:155196的訊息框架",
	VFYellType2				= "設定烈性之火的大喊方式 (只有傳奇模式)",
	Countdown				= "倒數直到消失",
	Apply					= "只有中了時候"
})

L:SetMiscLocalization({
	heatRegulator		= "熱能調節閥",
	Regulator			= "調節閥%d",
	bombNeeded			= "%d炸彈"
})

------------------
-- Hans'gar And Franzok --
------------------
L= DBM:GetModLocalization(1155)

--------------
-- Flamebender Ka'graz --
--------------
L= DBM:GetModLocalization(1123)

--------------------
--Kromog, Legend of the Mountain --
--------------------
L= DBM:GetModLocalization(1162)

L:SetMiscLocalization({
	ExRTNotice		= "%s發送ExRT的符文位置分配。你的位置為:%s"
})

--------------------------
-- Beastlord Darmac --
--------------------------
L= DBM:GetModLocalization(1122)

--------------------------
-- Operator Thogar --
--------------------------
L= DBM:GetModLocalization(1147)

L:SetWarningLocalization({
	specWarnSplitSoon	= "10秒後團隊分開"
})

L:SetOptionLocalization({
	specWarnSplitSoon	= "團隊分開10秒前顯示特別警告",
	InfoFrameSpeed		= "設定何時訊息框架顯示下一次列車的資訊",
	Immediately			= "車門一開後立即顯示此班列車",
	Delayed				= "在此班列車出現之後" ,
	HudMapUseIcons		= "為HudMap使用團隊圖示而非綠圈",
	TrainVoiceAnnounce	= "設置列車語音警告的訊息類型",
	LanesOnly			= "僅包含軌道訊息",
	MovementsOnly		= "僅包含走位訊息 (傳奇模式)",
	LanesandMovements	= "同時包含軌道訊息和走位訊息 (傳奇模式)"
})

L:SetMiscLocalization({
	Train			= GetSpellInfo(174806),
	lane			= "軌道",
	oneTrain		= "一個隨機軌道快車",
	oneRandom		= "隨機出現在一個軌道上",
	threeTrains		= "三個隨機軌道快車",
	threeRandom		= "隨機出現在三個軌道上",
	helperMessage	= "在這戰鬥推薦搭配協力插件索加爾助手'Thogar Assist'或是新版本的DBM語音包。可從Curse下載 "
})

--------------------------
-- The Iron Maidens --
--------------------------
L= DBM:GetModLocalization(1203)

L:SetWarningLocalization({
	specWarnReturnBase	= "快回到碼頭！"
})

L:SetOptionLocalization({
	specWarnReturnBase	= "當船上玩家可以安全回到碼頭時顯示特別警告",
	filterBladeDash3	= "當中了$spell:170395的時候不顯示$spell:155794的特別警告",
	filterBloodRitual3	= "當中了$spell:170405的時候不顯示$spell:158078的特別警告"
})

L:SetMiscLocalization({
	shipMessage		= "準備裝填無畏號的主砲了！",
	EarlyBladeDash	= "太慢了!"
})

--------------------------
-- Blackhand --
--------------------------
L= DBM:GetModLocalization(959)

L:SetWarningLocalization({
	specWarnMFDPosition		= "死亡標記站位：%s",
	specWarnSlagPosition	= "裝置熔渣彈站位: %s"
})

L:SetOptionLocalization({
	PositionsAllPhases	= "在所有階段中了$spell:156096時位置喊話 (原來只在第三階段喊。這主要是用於測試確保功能正常，此選項並非實際需要。)",
	InfoFrame			= "顯示$spell:155992與$spell:156530的訊息框架"
})

L:SetMiscLocalization({
	customMFDSay	= "%2$s中了死亡標記(%1$s)",
	customSlagSay	= "%2$s中了裝置熔渣彈(%1$s)"
})

-------------
--  Trash  --
-------------
L = DBM:GetModLocalization("BlackrockFoundryTrash")

L:SetGeneralLocalization({
	name =	"黑石鑄造場小怪"
})
