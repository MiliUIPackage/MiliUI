local Loc = LibStub("AceLocale-3.0"):NewLocale("Details_Threat", "enUS", true) 

if (not Loc) then
	return 
end 

Loc ["STRING_PLUGIN_NAME"] = "Tiny Threat"

Loc ["STRING_SLASH_ANIMATE"] = "animate"
Loc ["STRING_SLASH_SPEED"] = "speed"
Loc ["STRING_SLASH_AMOUNT"] = "amount"

Loc ["STRING_COMMAND_LIST"] = "Available Commands:"
Loc ["STRING_SLASH_SPEED_DESC"] = "Changes the frequency (in seconds) which the window is updated, allow values between 0.1 and 3.0"
Loc ["STRING_SLASH_SPEED_CHANGED"] = "Update Speed changed to "
Loc ["STRING_SLASH_SPEED_CURRENT"] = "Update Speed current value is "

-- 自行加入
Loc ["Small tool for track the threat you and other raid members have in your current target."] = "Small tool for track the threat you and other raid members have in your current target."
Loc ["/tt ot /tinythreat for options"] = "/tt ot /tinythreat for options"
Loc ["Tiny Threat"] = "Tiny Threat"
Loc ["Tiny Threat Options"] = "Tiny Threat Options"
Loc ["Do Animations"] = "Do Animations"
Loc ["Is the bars do animations"] = "Is the bars do animations"
Loc ["Update Speed"] = "Update Speed"
Loc ["How fast the window get updates."] = "How fast the window get updates."
Loc ["Show Amount of Threat"] = "Show Amount of Threat"
Loc ["If enabled shows the amount of threat each player has."] = "If enabled shows the amount of threat each player has."
Loc ["Player Color Enabled"] = "Player Color Enabled"
Loc ["When enabled, your bar get the following color."] = "When enabled, your bar get the following color."
Loc ["Player Color"] = "Player Color"
Loc ["Color"] = "Color"
Loc ["If Player Color is enabled, your bar have this color."] = "If Player Color is enabled, your bar have this color."
Loc ["Use Class Colors"] = "Use Class Colors"
Loc ["When enabled, threat bars uses the class color of the character."] = "When enabled, threat bars uses the class color of the character."
Loc ["Divide Threat by 100"] = "Divide Threat by 100"
Loc ["When enabled, threat is divided by 100."] = "When enabled, threat is divided by 100."
Loc ["Always Show Me"] = "Always Show Me"
Loc ["When enabled, your threat is always shown."] = "When enabled, your threat is always shown."
Loc ["Pull Aggro At"] = "Pull Aggro At"
Loc ["Details! Team"] = "Details! Team"
Loc ["Show threat for the focus target if there's one."] = "Show threat for the focus target if there's one."
Loc ["Track Focus Target (if any)"] = "Track Focus Target (if any)"
Loc ["Hide Pull Aggro Bar"] = "Hide Pull Aggro Bar"
Loc ["If this is disabled, you see weighted threat percentages – aggro switches at 100%.\nIf this is enabled, you see absolute threat percentages – aggro switches at 110% in melee, and 130% at range."] = "If this is disabled, you see weighted threat percentages – aggro switches at 100%.\nIf this is enabled, you see absolute threat percentages – aggro switches at 110% in melee, and 130% at range."
Loc ["Display absolute threat"] = "Display absolute threat"
Loc ["If this is enabled, certain bosses will show an additional threat threshold at 90.9% of the off-tank's threat. Any player above this threshold might be targeted after the Main Tank is incapacitated."] = "If this is enabled, certain bosses will show an additional threat threshold at 90.9% of the off-tank's threat. Any player above this threshold might be targeted after the Main Tank is incapacitated."
Loc ["Enable Gouge mode"] = "Enable Gouge mode"