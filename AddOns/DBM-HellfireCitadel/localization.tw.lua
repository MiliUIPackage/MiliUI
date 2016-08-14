if GetLocale() ~= "zhTW" then return end
local L

---------------
-- Hellfire Assault --
---------------
L= DBM:GetModLocalization(1426)

L:SetTimerLocalization({
	timerSiegeVehicleCD		= "下一個攻城載具-%s",
})

L:SetOptionLocalization({
	timerSiegeVehicleCD =	"為下一個攻城載具重生顯示計時器"
})

L:SetMiscLocalization({
	AddsSpawn1		=	"火力全開！",
	AddsSpawn2		=	"開火！",
	BossLeaving			=	"我會回來的…"
})

---------------------------
-- Iron Reaver --
---------------------------
L= DBM:GetModLocalization(1425)

---------------------------
-- Hellfire High Council --
---------------------------
L= DBM:GetModLocalization(1432)

L:SetWarningLocalization({
	reapDelayed =	"夢魘幻貌結束之後收割"
})

------------------
-- Kormrok --
------------------
L= DBM:GetModLocalization(1392)

L:SetMiscLocalization({
	ExRTNotice		= "%s 發送ExRT的位置分配。 你的位置: 橘:%s, 綠:%s, 紫:%s"
})

--------------
-- Kilrogg Deadeye --
--------------
L= DBM:GetModLocalization(1396)

L:SetMiscLocalization({
	BloodthirstersSoon	= "都給我上！盡你們的責任！"
})

--------------------
--Gorefiend --
--------------------
L= DBM:GetModLocalization(1372)

L:SetTimerLocalization({
	SoDDPS2			= "下一次死亡之影(%s)",
	SoDTank2		= "下一次死亡之影(%s)",
	SoDHealer2		= "下一次死亡之影(%s)"
})

L:SetOptionLocalization({
	SoDDPS2				= "計時條：下一次針對DPS的$spell:179864",
	SoDTank2			= "計時條：下一次針對坦克的$spell:179864",
	SoDHealer2			= "計時條：下一次針對治療的$spell:179864",
	ShowOnlyPlayer	= "只有在如果你也是$spell:179909的參與者時才顯示HudMap"
})

--------------------------
-- Shadow-Lord Iskar --
--------------------------
L= DBM:GetModLocalization(1433)

L:SetWarningLocalization({
	specWarnThrowAnzu =	"快傳安祖之眼給%s！"
})

L:SetOptionLocalization({
	specWarnThrowAnzu =	"特別警告：當你需要傳遞$spell:179202給他人時"
})

--------------------------
-- Fel Lord Zakuun --
--------------------------
L= DBM:GetModLocalization(1391)

L:SetOptionLocalization({
	SeedsBehavior		= "設定團隊的種子大喊方式(需要團長權限)",
	Iconed					= "星星,圈圈,鑽石,三角,月亮。適用於用於分散站位",
	Numbered			= "1, 2, 3, 4, 5。適用於分區站位",
	DirectionLine		= "左, 中偏左, 中間, 中偏右, 右。適用於直線站位",
	FreeForAll			= "自由模式。不指定站位，只使用普通的大喊"
})

L:SetMiscLocalization({
	DBMConfigMsg		= "團長已經將種子喊叫方式設定為 %s。",
	BWConfigMsg			= "團長在用Bigwigs, DBM將會使用數字來提示。"
})

--------------------------
-- Xhul'horac --
--------------------------
L= DBM:GetModLocalization(1447)

L:SetOptionLocalization({
	ChainsBehavior		= "設定魔化鎖鍊警告行為",
	Cast							= "只給原始目標施放開始時警告。計時器在施放開始時同步。",
	Applied					= "只會中招目標施放結束時警告。計時器在施放結束時同步。",
	Both							= "原始目標施放開始時和中招目標施放結束時警告。"
})

--------------------------
-- Socrethar the Eternal --
--------------------------
L= DBM:GetModLocalization(1427)

L:SetOptionLocalization({
	InterruptBehavior	= "設置團隊的打斷運作方式(需要團長權限)",
	Count3Resume		= "3人輪流打斷，魔化屏障消失後繼續計數",--Default
	Count3Reset			= "3人輪流打斷，魔化屏障消失後重設計數",
	Count4Resume		= "4人輪流打斷，魔化屏障消失後繼續計數",
	Count4Reset			= "4人輪流打斷，魔化屏障消失後重設計數"
})

--------------------------
-- Tyrant Velhari --
--------------------------
L= DBM:GetModLocalization(1394)

--------------------------
-- Mannoroth --
--------------------------
L= DBM:GetModLocalization(1395)

L:SetOptionLocalization({
	CustomAssignWrath	= "基於角色專精設置$spell:186348的團隊圖示(必須由團隊隊長開啟。可能會與BW或過期DBM衝突)"
})
L:SetMiscLocalization({
	felSpire		=	"開始強化惡魔尖塔！"
})

--------------------------
-- Archimonde --
--------------------------
L= DBM:GetModLocalization(1438)

L:SetWarningLocalization({
	specWarnBreakShackle	= "束縛折磨：拉斷%s!"
})

L:SetOptionLocalization({
	specWarnBreakShackle		= "當中了$spell:184964時顯示特別警告。此警告會自動分配拉斷順序將承受傷害最小化。",
	ExtendWroughtHud3			= "將HUD連線延長到中了$spell:185014的目標上。(可能會導致連線準確度下降)",
	AlternateHudLine					= "在$spell:185014的目標之間的HUD連線使用不同的線條材質 ",
	NamesWroughtHud			= "在HUD中顯示$spell:185014目標的玩家姓名",
	FilterOtherPhase					= "過濾掉與你不同階段的警告",
	MarkBehavior						= "設定燃燒軍團印記的喊叫方式（需要團長權限）",
	Numbered							= "星星、圈圈、鑽石、三角。適用任何站位的打法。",--Default
	LocSmallFront						= "近戰(左星、右圈)、遠程(左鑽、右三)。減益時間短的去近戰位",
	LocSmallBack						= "近戰(左星、右圈)、遠程(左鑽、右三)。減益時間短的去遠程位",
	NoAssignment						= "停用整個團隊所有站位大喊/訊息，還有HUD指示。",
	overrideMarkOfLegion		= "不允許團隊隊長覆蓋軍團印記的行為(只推薦給進階玩家使用)"
})

L:SetMiscLocalization({
	phase2point5		= "看看燃燒軍團的軍容有多壯盛，就知道你們無謂的抵抗有多愚蠢。",
	First						= "第一個",
	Second				= "第二個",
	Third					= "第三個"
})

-------------
--  Trash  --
-------------
L = DBM:GetModLocalization("HellfireCitadelTrash")

L:SetGeneralLocalization({
	name =	"地獄火堡壘小怪"
})
