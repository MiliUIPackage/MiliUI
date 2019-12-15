if GetLocale() ~= "zhTW" then return end
local L

---------------------------
--  Ra'wani Kanae/Frida Ironbellows (Both) --
-- Same exact enoucnter, diff names
---------------------------
L= DBM:GetModLocalization(2344)--Ra'wani Kanae (Alliance)

L= DBM:GetModLocalization(2333)--Frida Ironbellows (Horde)

---------------------------
--  King Grong/Grong the Revenant (Both) --
---------------------------
L= DBM:GetModLocalization(2325)--King Grong (Horde)

L= DBM:GetModLocalization(2340)--Grong the Revenant (Alliance)

---------------------------
--  Grimfang and Firecaller/Flamefist and the Illuminated (Both) --
-- Same exact enoucnter, diff names
---------------------------
L= DBM:GetModLocalization(2323)--Grimfang and Firecaller (Alliance)

L= DBM:GetModLocalization(2341)--Flamefist and the Illuminated (Horde)

---------------------------
--  Opulence (Alliance) --
---------------------------
L= DBM:GetModLocalization(2342)

L:SetWarningLocalization({

})

L:SetTimerLocalization({

})

L:SetOptionLocalization({

})

L:SetMiscLocalization({
	Bulwark =	"壁壘",
	Hand	=	"手"
})

---------------------------
--  Loa Council (Alliance) --
---------------------------
L= DBM:GetModLocalization(2330)

L:SetMiscLocalization({
	BwonsamdiWrath =	"你要是這麼想找死，就應該早點來找我！",
	BwonsamdiWrath2 =	"你們遲早…都會像我臣服！",
	Bird			 =	"大鳥"
})

---------------------------
--  King Rastakhan (Alliance) --
---------------------------
L= DBM:GetModLocalization(2335)

L:SetOptionLocalization({
	AnnounceAlternatePhase	= "即使你不在對應位面也顯示階段轉換警告 (計時條不受影響)"
})

---------------------------
-- High Tinker Mekkatorgue (Horde) --
---------------------------
L= DBM:GetModLocalization(2332)

---------------------------
--  Sea Priest Blockade (Horde) --
---------------------------
L= DBM:GetModLocalization(2337)

---------------------------
--  Jaina Proudmoore (Horde) --
---------------------------
L= DBM:GetModLocalization(2343)

L:SetOptionLocalization({
	ShowOnlySummary2	= "隱藏玩家名稱在反距離監控而且只顯示總結訊息(附近玩家數量)",
	InterruptBehavior	= "設置水元素中斷行為 (如果你是團隊隊長會覆蓋所有其他人的設定)",
	Three				= "3人輪流",--Default
	Four				= "4人輪流",
	Five				= "5人輪流",
	SetWeather			= "當與首領開戰時自動將天氣密度轉為最低，並在戰鬥結束後恢復。",
})

L:SetMiscLocalization({
	Port			=	"左側船艦",
	Starboard		=	"右側船艦",
	Freezing		=	"%s秒後凍結"
})

-------------
--  Trash  --
-------------
L = DBM:GetModLocalization("ZuldazarRaidTrash")

L:SetGeneralLocalization({
	name =	"達薩亞洛小怪"
})
