--暫翻自簡中
if GetLocale() ~= "zhTW" then return end
local L

---------------------------
--  The Tarragrue 塔拉格魯--
---------------------------
L= DBM:GetModLocalization(2435)

L:SetOptionLocalization({
	warnRemnant	= "通告個人殘渣層數"
})

L:SetMiscLocalization({
	Remnant	= "殘渣"
})

---------------------------
--  The Eye of the Jailer 典獄長之眼--
---------------------------
L= DBM:GetModLocalization(2442)

L:SetOptionLocalization({
	ContinueRepeating	= "重復蔑視和憤怒的標記喊話，直到減益消失"
})

---------------------------
--  The Nine 九武神--
---------------------------
L= DBM:GetModLocalization(2439)

L:SetMiscLocalization({
	--AgathaBlade		= "倒在我的劍下吧！",
	--AradneStrike	= "你們絕無勝算！",
	--Fragment		= "殘片 "--Space is intentional, leave a space to add a number after it
})

---------------------------
--  Remnant of Ner'zhul 耐奧祖--
---------------------------
--L= DBM:GetModLocalization(2444)

---------------------------
--  Soulrender Dormazain 多爾瑪贊--
---------------------------
--L= DBM:GetModLocalization(2445)

---------------------------
--  Painsmith Raznal 萊茲納爾--
---------------------------
--L= DBM:GetModLocalization(2443)

---------------------------
--  Guardian of the First Ones 初誕者的衛士--
---------------------------
L= DBM:GetModLocalization(2446)

L:SetMiscLocalization({
	--Dissection	= "解剖！",
	--Dismantle	= "分解"
})

---------------------------
--  Fatescribe Roh-Kalo 卡洛--
---------------------------
--L= DBM:GetModLocalization(2447)

---------------------------
--  Kel'Thuzad 克爾蘇加德--
---------------------------
--L= DBM:GetModLocalization(2440)

---------------------------
--  Sylvanas Windrunner 希爾瓦娜斯--
---------------------------
--L= DBM:GetModLocalization(2441)

-------------
--  Trash  --
-------------
L = DBM:GetModLocalization("SanctumofDomTrash")

L:SetGeneralLocalization({
	name =	"統御聖所小怪"
})
