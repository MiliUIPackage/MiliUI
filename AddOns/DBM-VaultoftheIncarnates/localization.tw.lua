if GetLocale() ~= "zhTW" then return end
local L

---------------------------
--  Eranog -- 艾拉諾格
---------------------------
--L= DBM:GetModLocalization(2480)

--L:SetWarningLocalization({
--})
--
--L:SetTimerLocalization{
--}
--
--L:SetOptionLocalization({
--})
--
--L:SetMiscLocalization({
--})

---------------------------
--  Terros -- 泰洛斯
---------------------------
--L= DBM:GetModLocalization(2500)

---------------------------
--  The Primalist Council -- 原始議會
---------------------------
--L= DBM:GetModLocalization(2486)

---------------------------
--  Sennarth, The Cold Breath -- 瑟娜爾絲，冰冷之息
---------------------------
--L= DBM:GetModLocalization(2482)

---------------------------
--  Dathea, Ascended -- 晉升者達瑟雅
---------------------------
--L= DBM:GetModLocalization(2502)

---------------------------
--  Kurog Grimtotem -- 庫洛格-恐怖圖騰
---------------------------
L= DBM:GetModLocalization(2491)

L:SetTimerLocalization({
	timerDamageCD = "攻擊階段 (%s)",
	timerAvoidCD = "防禦階段 (%s)",
	timerUltimateCD = "終極階段 (%s)"
})

L:SetOptionLocalization({
	timerDamageCD = "顯示攻擊階段的 $spell:382563, $spell:373678, $spell:391055, $spell:373487 的計時器",
	timerAvoidCD = "顯示防禦階段的 $spell:373329, $spell:391019, $spell:395893, $spell:390920 的計時器",
	timerUltimateCD = "顯示終極階段的 $spell:374022, $spell:372456, $spell:374691, $spell:374215 的計時器"
})

---------------------------
--  Broodkeeper Diurna -- 巢穴守護者迪烏爾娜
---------------------------
L= DBM:GetModLocalization(2493)

L:SetMiscLocalization({
	staff		= "巨杖",
	eStaff	= "強化巨杖"
})

---------------------------
--  Raszageth the Storm-Eater -- 萊薩傑絲，噬雷之龍
---------------------------
L= DBM:GetModLocalization(2499)

L:SetMiscLocalization({
	negative = "負極",
	positive = "正極"
})

-------------
--  Trash  --
-------------
L = DBM:GetModLocalization("VaultoftheIncarnatesTrash")

L:SetGeneralLocalization({
	name =	"洪荒化身牢獄小怪"
})