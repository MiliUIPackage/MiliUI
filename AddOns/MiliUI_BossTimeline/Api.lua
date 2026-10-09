------------------------------------------------------------
-- 對外入口：/mbt 指令、插件選單按鈕
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local S = ns.Secret

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）
function _G.MiliUIBossTimeline_OnAddonCompartmentClick()
    ns.OpenOptions()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "bosstimeline",
    text    = L["MiliUI Boss Timeline"],
    icon    = "Interface\\Icons\\Spell_Holy_BorrowedTime",
    order   = 66,
    OnClick = function() ns.OpenOptions() end,
}

------------------------------------------------------------
-- /mbt check：時間軸上現在有什麼、各是誰加的
-- ⚠ 暴雪首領事件的名稱是秘密值，一個都不印（只印條數）
------------------------------------------------------------
local function Report()
    ns.Print("v" .. ns.VERSION)
    local counts = { blizzard = 0, mine = 0, other = 0, editmode = 0 }
    for id, rec in ns.Events.Iterate() do
        counts[rec.kind] = (counts[rec.kind] or 0) + 1
        if rec.kind == "blizzard" and rec.ident then
            print(("  #%d  %s  %s  (%s)"):format(id, L["Blizzard"], rec.ident.name, rec.ident.source))
        elseif rec.kind == "other" or rec.kind == "mine" then
            local rem = S.PlainNumber(S.SafeCall(C_EncounterTimeline.GetEventTimeRemaining, id))
            local who = rec.kind == "mine" and L["My custom timeline"] or ns.Owners.Label(rec.owner)
            print(("  #%d  %s  %s  %s"):format(id, who, S.PlainText(rec.name) or "?",
                rem and ("%.1fs"):format(rem) or "-"))
        end
    end
    print(("  %s %d   %s %d   %s %d"):format(L["Blizzard"], counts.blizzard,
        L["Mine"], counts.mine, L["Other addons"], counts.other))
    print("  " .. L["Hiding Blizzard's timeline:"] .. " " .. (ns.BlizzardView.IsHiding() and L["yes"] or L["no"])
        .. "   DBM: " .. (ns.Identify.DBMHooked() and L["yes"] or L["no"])
        .. "   MRT: " .. (ns.MRTData.Available() and L["yes"] or L["no"]))

    if ns.errors and #ns.errors > 0 then
        print("  " .. L["Errors:"])
        for i, err in ipairs(ns.errors) do
            print(("   %d. %s"):format(i, err))
        end
    end
end

SLASH_MILIUIBT1 = "/mbt"
SLASH_MILIUIBT2 = "/bosstimeline"
SlashCmdList.MILIUIBT = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "reset" then
        ns.DB.ResetAll()
    elseif msg == "check" then
        Report()
    elseif msg == "stop" then
        ns.Scheduler.Stop()
    else
        ns.OpenOptions()
    end
end
