local _, core = ...; -- Namespace
-------------------------------------------------------------

SLASH_MCL1 = "/mcl";

SlashCmdList["MCL"] = function(msg)
    if msg:lower() == "help" then
        print("\n|cff00CCFFMount Collection Log\n指令:\n|cffFF0000Show:|cffFFFFFF 顯示您的坐騎收藏紀錄\n|cffFF0000Icon:|cffFFFFFF 切換小地圖圖示。\n|cffFF0000Config:|cffFFFFFF 開啟選項設定..\n|cffFF0000Help:|cffFFFFFF 顯示指令")
    end
    if msg:lower() == "show" then
        core.Main.Toggle();
    end
    if msg:lower() == "icon" then
        core.Function.MCL_MM();
    end        
    if msg:lower() == "" then
        core.Main.Toggle();
    end
    if msg:lower() == "compare" then
        core.Function:CompareMountJournal();
    end
    if msg:lower() == "debug" then
        core.Function:GetCollectedMounts();
    end
    if msg:lower() == "conifg" or msg == "settings" then
        core.Frames:openSettings();
    end    
 end 