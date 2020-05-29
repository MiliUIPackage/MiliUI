local _, ns = ...

if ns:IsSameLocale("zhTW") then
	local L = ns.L or ns:NewLocale()

	L.LOCALE_NAME = "zhTW"

	L["completion1"] = "傳奇+ 挑戰完成時間：|cff8787ED[%s (%s)]|r +1 使用了 |cff00ffff%s|r。比 +1 提早 %s，再快 %s 可以 +2。"
	L["completion2"] = "傳奇+ 挑戰完成時間：|cff8787ED[%s (%s)]|r +2 使用了 |cff00ffff%s|r。比 +2 提早 %s，再快 %s 可以 +3。"
	L["completion3"] = "傳奇+ 挑戰完成時間：|cff8787ED[%s (%s)]|r +3 使用了 |cff00ffff%s|r，比 +3 提早 %s。"
	L["completion0"] = "傳奇+ 挑戰失敗時間：|cff8787ED[%s (%s)]|r 使用了 |cffff0000%s|r，超過 %s。"

	L["Schedule"] 	= "時程表"
	L["Rewards"] 	= "獎勵"
	L["WeekLeader"] = "本週公會最佳"
	
	L["|cffffc300Level  Reward   Week Azer|r\n"] = "|cffffc300  等級  獎勵  每週寶箱|r\n"
	L["|cffff0000%5s|r|cff00ffff%10d%10d/|cffff9900%d\n"] = "|cffff0000%7s|r|cff00ffff%6s%9s\n"

	ns[1] = L
end
