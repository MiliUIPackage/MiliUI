------------------------------------------------------------
-- 對外入口：/dermo 指令、插件選單按鈕
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUICrusadingStrikes_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "crusadingstrikes",
    text    = L["MiliUI Crusading Strikes"],
    icon    = "Interface\\Icons\\spell_holy_crusaderstrike",
    order   = 65,
    OnClick = function() ns.OpenOptions() end,
}

------------------------------------------------------------
-- /dermo check
--
-- 「條沒出來」有六種成因，而且彼此看起來一模一樣。這裡把每一段都印成「有／沒有」。
-- ⚠ 一個可能是秘密的值都不印（cooldownID 只回報「是不是秘密」），也不印單位名。
------------------------------------------------------------
local function YesNo(v)
    return v and "|cff55ff55" .. L["yes"] .. "|r" or "|cffff5555" .. L["no"] .. "|r"
end

local function ListedText(listed)
    if listed == "yes" then return L["In the Tracked Bars row"] end
    if listed == "no" then return L["Not found"] end
    if listed == "combat" then return L["Can't check during combat"] end
    return L["Unknown"]
end

local function Report()
    local s = ns.Source.Status()
    local b = ns.Bar.GetDebugInfo()

    ns.Print("v" .. ns.VERSION)
    print("  " .. L["Paladin:"] .. " " .. YesNo(s.isPaladin)
        .. "   " .. L["Enabled:"] .. " " .. YesNo(ns.db and ns.db.enabled))
    print("  " .. L["Platynator loaded:"] .. " " .. YesNo(s.platynator)
        .. "   " .. L["Cooldown Manager:"] .. " " .. YesNo(s.cdmEnabled and s.viewer))
    print("  " .. L["Crusading Strikes tracking:"] .. " " .. ListedText(s.listed)
        .. "   " .. L["bar found"] .. ": " .. YesNo(s.item)
        .. "   " .. L["active"] .. ": " .. YesNo(s.active)
        .. "   " .. L["secret id"] .. ": " .. YesNo(s.secretID))
    print("  " .. L["Attached:"] .. " " .. YesNo(b.attached)
        .. "   " .. L["Health bar:"] .. " " .. YesNo(b.health)
        .. "   " .. L["Cast bar:"] .. " " .. YesNo(b.cast)
        .. "   " .. L["cast bar sits below:"] .. " " .. YesNo(b.castBelow)
        .. "   " .. L["mirroring:"] .. " " .. YesNo(b.running))

    if ns.errors and #ns.errors > 0 then
        print("  " .. L["Errors:"])
        for i, err in ipairs(ns.errors) do
            print(("   %d. %s"):format(i, err))
        end
    end
end

SLASH_MILIUICSAA1 = "/dermo"
SLASH_MILIUICSAA2 = "/crusadingstrikes"
SlashCmdList.MILIUICSAA = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "reset" then
        ns.DB.ResetAll()
    elseif msg == "check" then
        Report()
    else
        ns.OpenOptions()
    end
end
