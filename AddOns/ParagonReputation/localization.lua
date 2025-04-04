		-------------------------------------------------
		-- Paragon Reputation 1.62 by Fail US-Ragnaros --
		-------------------------------------------------

		  --[[	  Special thanks to Ammako for
				  helping me with the vars and
				  the options.						]]--

local ADDON_NAME,ParagonReputation = ...
local PR = ParagonReputation

local LOCALE = GetLocale()
PR.L = {}

-- Chinese (Simplified) (Thanks dxlmike)
if LOCALE == "zhCN" then
	PR.L["PARAGON"] = "巅峰"
	PR.L["OPTIONDESC"] = "可以自定巅峰声望条的一些设定."
	PR.L["TOASTDESC"] = "切换获得巅峰奖励时是否弹出通知."
	PR.L["LABEL001"] = "声望条颜色"
	PR.L["LABEL002"] = "文字格式"
	PR.L["LABEL003"] = "弹出奖励通知"
	PR.L["BLUE"] = "巅峰蓝"
	PR.L["GREEN"] = "预设绿"
	PR.L["YELLOW"] = "中立黄"
	PR.L["ORANGE"] = "敌对橙"
	PR.L["RED"] = "淡红"
	PR.L["DEFICIT"] = "还需要多少声望"
	PR.L["SOUND"] = "音效通知"
	PR.L["ANCHOR"] = "锚点"
	
	-- 自行加入
	PR.L["Paragon Reputation"] = "声望"
	PR.L["|cff0088eeParagon|r Reputation |cff0088eev"] = "|cff0088ee巅峰|r声望 |cff0088eev"

-- Chinese (Traditional) (Thanks gaspy10 & BNSSNB)
elseif LOCALE == "zhTW" then
	PR.L["PARAGON"] = "巔峰"
	PR.L["OPTIONDESC"] = "這些選項可讓你自訂巔峰聲望條的一些設定。"
	PR.L["TOASTDESC"] = "啟用獲得巔峰聲望獎勵時彈出通知。"
	PR.L["LABEL001"] = "聲望條顏色"
	PR.L["LABEL002"] = "文字格式"
	PR.L["LABEL003"] = "彈出獎勵通知"
	PR.L["BLUE"] = "巔峰藍"
	PR.L["GREEN"] = "預設綠"
	PR.L["YELLOW"] = "中立黃"
	PR.L["ORANGE"] = "不友好橘"
	PR.L["RED"] = "淡紅色"
	PR.L["DEFICIT"] = "還需要多少聲望"
	PR.L["SOUND"] = "音效通知"
	PR.L["ANCHOR"] = "移動位置"
	
	-- 自行加入
	PR.L["Paragon Reputation"] = "聲望"
	PR.L["|cff0088eeParagon|r Reputation |cff0088eev"] = "|cff0088ee巔峰|r聲望 |cff0088eev"

-- English (DEFAULT)
else
	PR.L["PARAGON"] = "Paragon"
	PR.L["OPTIONDESC"] = "This options allow you to customize some settings of Paragon Reputation."
	PR.L["TOASTDESC"] = "Toggle a toast window that will warn you when you have a Paragon Reward."
	PR.L["LABEL001"] = "Bars Color"
	PR.L["LABEL002"] = "Text Format"
	PR.L["LABEL003"] = "Reward Toast"
	PR.L["BLUE"] = "Paragon Blue"
	PR.L["GREEN"] = "Default Green"
	PR.L["YELLOW"] = "Neutral Yellow"
	PR.L["ORANGE"] = "Unfriendly Orange"
	PR.L["RED"] = "Lightish Red"
	PR.L["DEFICIT"] = "Reputation Deficit"
	PR.L["SOUND"] = "Sound Warning"
	PR.L["ANCHOR"] = "Toggle Anchor"
	
	-- 自行加入
	PR.L["Paragon Reputation"] = "Paragon Reputation"
	PR.L["|cff0088eeParagon|r Reputation |cff0088eev"] = "|cff0088eeParagon|r Reputation |cff0088eev"
	
end