------------------------------------------------------------
-- 對外入口：/miliui 指令、米利UI選單的「套組本體」項目
------------------------------------------------------------
local _, ns = ...

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 刻意不往 MiliUI_MenuEntries 塞「套組」項目：ESC 那顆「米利UI設定」按鈕
-- 點下去開的就是本體設定，選單裡再列一次是重複入口。

SLASH_MILIUIPACK1 = "/miliui"
SLASH_MILIUIPACK2 = "/mili"
SlashCmdList.MILIUIPACK = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "debug" then
        ns.Print("v" .. ns.VERSION)
        if #ns.errors == 0 then
            print("  沒有記錄到錯誤")
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end
    else
        ns.OpenOptions()
    end
end
