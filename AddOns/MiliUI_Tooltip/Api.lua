------------------------------------------------------------
-- 對外入口：/mtip 指令、插件選單按鈕
------------------------------------------------------------
local _, ns = ...

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUITip_OnAddonCompartmentClick()
    ns.OpenOptions()
end

SLASH_MILIUITIP1 = "/mtip"
SLASH_MILIUITIP2 = "/miliuitooltip"
SlashCmdList.MILIUITIP = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "reset" then
        ns.DB.ResetAll()
    elseif msg == "debug" then
        print("|cff4DD2FF[MiliUI Tooltip]|r v" .. ns.VERSION)
        if #ns.errors == 0 then
            print("  無錯誤紀錄")
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end
    else
        ns.OpenOptions()
    end
end
