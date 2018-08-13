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

L:SetMiscLocalization({ --以下為暫譯
	CThunDisc 			= 	"檢索圓盤成功。正在讀取克蘇恩數據。",
	YoggDisc 				= 	"檢索圓盤成功。正在讀取尤格-薩倫數據。",
	CorruptedDisc 		= 	"檢索圓盤成功。正在讀取損壞數據。"
})

---------------------------
-- Vectis --
---------------------------
L= DBM:GetModLocalization(2166)

L:SetOptionLocalization({
	ShowHighestFirst	 =	"將訊息框架中持續感染的層數從高往低顯示(預設從低到高)"
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
	timerCallofCrawgCD		= "下一次克洛格 (%s)",
	timerCallofHexerCD 		= "下一次血咒師 (%s)",
	timerCallofCrusherCD	= "下一次粉碎者 (%s)",
	timerAddIncoming		= DBM_INCOMING
})

L:SetOptionLocalization({
	timerAddIncoming		= "計時條：當小怪可以攻擊時"
})

L:SetMiscLocalization({
	Crusher			=	"粉碎者",
	Bloodhexer		=	"血咒師",
	Crawg			=	"克洛格"
})

------------------
-- G'huun --
------------------
L= DBM:GetModLocalization(2147)

-------------
--  Trash  --
-------------
L = DBM:GetModLocalization("UldirTrash")

L:SetGeneralLocalization({
	name =	"奧迪爾小怪"
})
