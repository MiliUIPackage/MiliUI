------------------------------------------------------------
-- 對外入口：/miliui 指令、米利UI選單的「套組本體」項目
------------------------------------------------------------
local _, ns = ...

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 本體排最前（order = 0），開到「插件總覽」——它就是整包的控制台。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "pack",
    text    = "米利UI套組",
    icon    = "Interface\\AddOns\\MiliUI\\icon",
    order   = 0,
    OnClick = function() ns.OpenOptions("addons") end,
}

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
