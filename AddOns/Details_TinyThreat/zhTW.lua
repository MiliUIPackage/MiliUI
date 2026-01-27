local Loc = LibStub("AceLocale-3.0"):NewLocale("Details_Threat", "zhTW") 

if (not Loc) then
	return 
end 

Loc ["STRING_PLUGIN_NAME"] = "仇恨值"

Loc ["STRING_SLASH_ANIMATE"] = "animate"
Loc ["STRING_SLASH_SPEED"] = "speed"
Loc ["STRING_SLASH_AMOUNT"] = "amount"

Loc ["STRING_COMMAND_LIST"] = "可用的指令:"
Loc ["STRING_SLASH_SPEED_DESC"] = "更改視窗的更新頻率 (以秒為單位)，允許 0.1 ~ 3.0 之間的數值。"
Loc ["STRING_SLASH_SPEED_CHANGED"] = "更新速度更改成 "
Loc ["STRING_SLASH_SPEED_CURRENT"] = "目前的更新速度為 "

-- 自行加入
Loc ["Small tool for track the threat you and other raid members have in your current target."] = "監控你和其他隊友對你的當前目標的仇恨值的小工具。"
Loc ["/tt ot /tinythreat for options"] = "輸入 /tt 或 /tinythreat 打開設定選項"
Loc ["Tiny Threat"] = "仇恨值"
Loc ["Tiny Threat Options"] = "仇恨值設定選項"
Loc ["Do Animations"] = "顯示動畫效果"
Loc ["Is the bars do animations"] = "計量條是否要顯示動畫效果。"
Loc ["Update Speed"] = "更新速度"
Loc ["How fast the window get updates."] = "視窗的更新頻率有多快。"
Loc ["Show Amount of Threat"] = "顯示仇恨值數值"
Loc ["If enabled shows the amount of threat each player has."] = "啟用時，會顯示每位玩家的仇恨值數值。"
Loc ["Player Color Enabled"] = "啟用玩家顏色"
Loc ["When enabled, your bar get the following color."] = "啟用時，你自己的計量條會顯示為下方的顏色。"
Loc ["Player Color"] = "玩家顏色"
Loc ["Color"] = "顏色"
Loc ["If Player Color is enabled, your bar have this color."] = "啟用玩家顏色時，你自己的計量條會顯示為這個的顏色。"
Loc ["Use Class Colors"] = "使用職業顏色"
Loc ["When enabled, threat bars uses the class color of the character."] = "啟用時，仇恨值計量條會顯示為角色的職業顏色。"
Loc ["Divide Threat by 100"] = "仇恨值除以 100"
Loc ["When enabled, threat is divided by 100."] = "啟用時，仇恨值會除以 100。"
Loc ["Always Show Me"] = "總是顯示自己"
Loc ["When enabled, your threat is always shown."] = "啟用時，會永遠顯示你自己的仇恨值。"
Loc ["Pull Aggro At"] = "拉怪仇恨值"
Loc ["Details! Team"] = "Details! 團隊"
Loc ["Show threat for the focus target if there's one."] = "顯示專注目標的目標的仇恨值 (如果有的話)。"
Loc ["Track Focus Target (if any)"] = "監控專注目標的目標 (如果有的話)"
Loc ["Show Pull Aggro Bar"] = "顯示拉怪仇恨條"
Loc ["If this is disabled, you see weighted threat percentages – aggro switches at 100%.\nIf this is enabled, you see absolute threat percentages – aggro switches at 110% in melee, and 130% at range."] = "停用時，會顯示計算過的仇恨百分比 - 在 100% 時切換仇恨對象。\n啟用時，會顯示絕對仇恨百分比 - 近戰在 110%、遠程在 130% 時切換仇恨對象。"
Loc ["Display absolute threat"] = "顯示絕對仇恨值"
Loc ["If this is enabled, certain bosses will show an additional threat threshold at 90.9% of the off-tank's threat. Any player above this threshold might be targeted after the Main Tank is incapacitated."] = "啟用時，某些首領在副坦克仇恨值 90.9% 時會顯示額外的仇恨關鍵值。任何高於這個關鍵值的玩家，在主坦克失去行為能力時會被選為目標。"
Loc ["Enable Gouge mode"] = "啟用鑿擊模式"