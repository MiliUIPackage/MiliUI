------------------------------------------------------------
-- 對外入口：/mfocus 指令、插件選單按鈕
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUIFocus_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "focus",
    text    = L["MiliUI Focus"],
    icon    = "Interface\\Icons\\ability_hunter_snipershot",
    order   = 60,
    OnClick = function() ns.OpenOptions() end,
}

------------------------------------------------------------
-- /mfocus check
--
-- 「Shift+點擊沒反應」有兩種完全不同的成因：屬性沒設上（時機問題），
-- 或設上了但點擊被別的框架吃掉。這裡只回答第一個，第二個要用
-- GetMouseFoci() 看焦點鏈。
------------------------------------------------------------
local issecret = issecretvalue or function() return false end

-- 只描述「有沒有標記」，不印值也不印單位名 —— 兩者在 12.1 都可能是秘密值
local function MarkDesc(unit)
    if not UnitExists(unit) then return L["no unit"] end
    local i = GetRaidTargetIndex(unit)
    if i == nil then return L["no marker"] end
    if issecret(i) then return L["marked (secret)"] end
    return L["marked"] .. " (" .. tostring(i) .. ")"
end

local function ReportFrames()
    local focuserButton, _, attr = ns.Focuser.GetDebugInfo()
    ns.Print(L["Enabled:"], tostring(ns.db.focus.enabled),
        L["Button:"], tostring(focuserButton ~= nil),
        L["Hotkey:"], tostring(ns.db.focus.hotkey or L["Not set"]))

    local missing, ok = {}, 0
    for _, name in ipairs(ns.Focuser.defaultFrameNames) do
        local f = _G[name]
        if not f then
            tinsert(missing, name .. " (" .. L["frame does not exist"] .. ")")
        elseif f:GetAttribute(attr) then
            ok = ok + 1
        else
            tinsert(missing, name .. " (" .. L["attribute not set"] .. ")")
        end
    end
    ns.Print(L["Hooked:"] .. " " .. ok .. "  " .. L["Not hooked:"] .. " " .. #missing)
    for _, m in ipairs(missing) do print("   " .. m) end

    local macro = focuserButton and focuserButton:GetAttribute("macrotext")
    ns.Print(L["Current macro:"])
    if macro then
        for line in tostring(macro):gmatch("[^\n]+") do print("   " .. line) end
    else
        print("   (" .. L["button not created yet"] .. ")")
    end
    print("   " .. L["Focus:"] .. " " .. MarkDesc("focus")
        .. "   " .. L["Mouseover:"] .. " " .. MarkDesc("mouseover"))
end

SLASH_MILIUIFOCUS1 = "/mfocus"
SLASH_MILIUIFOCUS2 = "/miliuifocus"
SlashCmdList.MILIUIFOCUS = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "reset" then
        ns.DB.ResetAll()
    elseif msg == "check" then
        ReportFrames()
    elseif msg == "migrate" then
        -- 補搬：第一次啟動時剛好沒開 MiliUI 的話，自動遷移那次會什麼都搬不到。
        -- 會覆蓋現有設定，所以只在明確下指令時跑。
        local ok, moved = ns.DB.RunMigration()
        if ok then
            ns.Print(L["Imported %d settings from the MiliUI package. Reloading..."]:format(moved))
            C_Timer.After(1, ReloadUI)
        else
            ns.Print(L["Nothing to import (the MiliUI package has no focus settings saved)."])
        end
    elseif msg == "debug" then
        ns.Print("v" .. ns.VERSION .. "  migration=" .. tostring(ns.db.miliuiMigration))
        if #ns.errors == 0 then
            print("  " .. L["No errors recorded"])
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end
    else
        ns.OpenOptions()
    end
end
