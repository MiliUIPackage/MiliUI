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

---------------------------
-- Zek'vhozj --
---------------------------
L= DBM:GetModLocalization(2169)

L:SetTimerLocalization({
	timerOrbLands	= "球(%s) 落地"
})

L:SetOptionLocalization({
	timerOrbLands	 =	"顯示腐蝕之球落地時間的計時器"
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
	ShowHighestFirst2	 =	"將訊息框架中持續感染的層數從高往低顯示(預設從低到高)"
	ShowOnlyParty		 =	"只顯示你小隊中的動蕩感染"
})

L:SetMiscLocalization({
	BWIconMsg			 =	"DBM已經在團隊中將單位標記交給給有權限的BW使用者以避免圖示衝突，確認他們已啟用標記功能或取消他們的權限以啟用DBM標記"
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
	timerCallofCrawgCD		= "計時條：克洛格池開始生成時",
	timerCallofHexerCD 		= "計時條：血咒師池開始生成時",
	timerCallofCrusherCD	= "計時條：粉碎者池開始生成時",
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
	warnMatrixFail		= "能量矩陣出現了"
})

L:SetOptionLocalization({
	warnMatrixFail		= "當能量矩陣出現時顯示警報。"
})

L:SetMiscLocalization({
	CurrentMatrix		=	"當前矩陣：",--Mythic
	NextMatrix			=	"下一次矩陣：",--Mythic
	CurrentMatrixLong	=	"當前矩陣 (%s):",--Non Mythic
	NextMatrixLong		=	"下一次矩陣 (%s):"--Non Mythic
})

-------------
--  Trash  --
-------------
L = DBM:GetModLocalization("UldirTrash")

L:SetGeneralLocalization({
	name =	"奧迪爾小怪"
})
