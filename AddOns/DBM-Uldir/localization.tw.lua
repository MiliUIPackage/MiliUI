if GetLocale() ~= "zhTW" then return end
local L

---------------------------
-- Taloc the Corrupted --
---------------------------
L= DBM:GetModLocalization(2168)

L:SetMiscLocalization({
	Aggro	 =	"有仇恨"
})

---------------------------
-- MOTHER --
---------------------------
L= DBM:GetModLocalization(2167)

---------------------------
-- Fetid Devourer --
---------------------------
L= DBM:GetModLocalization(2146)

L:SetWarningLocalization({
	addsSoon		= "滑道已開啟 - 小怪來了"
})

L:SetOptionLocalization({
	addsSoon		= "當滑道開啟和小怪準備出現時顯示預先警告"
})

---------------------------
-- Zek'vhozj --
---------------------------
L= DBM:GetModLocalization(2169)

L:SetTimerLocalization({
	timerOrbLands	= "下次球落地 (%s)"
})

L:SetOptionLocalization({
	timerOrbLands	 =	"計時條：下一次腐化之球落地",
	EarlyTankSwap	 =	"碎擊斬後馬上顯示換坦警告而不是等到第二個虛無鞭笞"
})

L:SetMiscLocalization({ --以下為暫譯
	CThunDisc 		= 	"檢索圓盤成功。正在讀取克蘇恩數據。",
	YoggDisc 		= 	"檢索圓盤成功。正在讀取尤格-薩倫數據。",
	CorruptedDisc 		= 	"檢索圓盤成功。正在讀取損壞數據。"
})

---------------------------
-- Vectis --
---------------------------
L= DBM:GetModLocalization(2166)

L:SetOptionLocalization({
	ShowHighestFirst2	 =	"在訊息框架中從最高層數開始排序慢性感染(而非從最低)",
	ShowOnlyParty		 =	"只顯示你隊伍中的慢性感染",
	SetIconsRegardless	 =	"不管BigWigs玩家是否有權限都設置標記(進階)"
})

L:SetMiscLocalization({
	BWIconMsg			 =	"DBM已經將單位交給有權限的BigWigs使用者標記以避免圖示混亂，確認他們已啟用標記功能或降級他們以啟用DBM標記，或啟用維克提斯選項中的覆蓋選項。"
})

---------------
-- Mythrax the Unraveler --
---------------
L= DBM:GetModLocalization(2194)

---------------------------
-- Zul --
---------------------------
L= DBM:GetModLocalization(2195)

L:SetTimerLocalization({
	timerCallofCrawgCD		= "下一次克洛格池 (%s)",
	timerCallofHexerCD 		= "下一次血咒師池 (%s)",
	timerCallofCrusherCD		= "下一次粉碎者池 (%s)",
	timerAddIncoming		= DBM_INCOMING
})

L:SetOptionLocalization({
	timerCallofCrawgCD		= "計時條：克洛格池開始成形時",
	timerCallofHexerCD 		= "計時條：血咒師池開始成形時",
	timerCallofCrusherCD	= "計時條：粉碎者池開始成形時",
	timerAddIncoming		= "計時條：當小怪可以攻擊時",
	TauntBehavior			= "設置換坦嘲諷規則",
	TwoHardThreeEasy		= "英雄/傳奇模式2層換，其他模式3層換",--Default
	TwoAlways				= "總是2層換",
	ThreeAlways				= "總是3層換"
})

L:SetMiscLocalization({
	Crusher		=	"粉碎者",
	Bloodhexer		=	"血咒師",
	Crawg			=	"克洛格"
})

------------------
-- G'huun --
------------------
L= DBM:GetModLocalization(2147)

L:SetWarningLocalization({
	warnMatrixFail		= "能量矩陣掉落"
})

L:SetOptionLocalization({
	warnMatrixFail		= "當能量矩陣掉落時顯示警報。"
})

L:SetMiscLocalization({
	CurrentMatrix		=	"當前矩陣：",--Mythic
	NextMatrix			=	"下次矩陣：",--Mythic
	CurrentMatrixLong	=	"當前矩陣(%s)：",--Non Mythic
	NextMatrixLong		=	"下次矩陣(%s)："--Non Mythic
})

-------------
--  Trash  --
-------------
L = DBM:GetModLocalization("UldirTrash")

L:SetGeneralLocalization({
	name =	"奧迪爾小怪"
})
