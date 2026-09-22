------------------------------------------------------------
-- 對外入口：/mmp 指令、插件選單按鈕、米利UI選單那一筆、資訊列的「M+結算」方塊
-- （小地圖按鈕是自己的框，住 UI/MinimapButton.lua）
--
-- 這支檔案是**唯一**往全域寫東西的地方（外加 Core/Init.lua 尾端那一行）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

function ns.OpenOptions(tabId)
    ns.Options.Open(tabId)
end

-- 插件選單（小地圖旁的收納選單）：點了開結算面板 —— 那才是這支插件的主角，
-- 設定走 /mmp config
function _G.MiliUIMythicPlus_OnAddonCompartmentClick()
    ns.Panel.Toggle()
end

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫套組本體的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有套組本體。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "mythicplus",
    text    = L["MiliUI Mythic Plus"],
    icon    = "Interface\\Icons\\INV_Relics_Hourglass",
    order   = 88,
    OnClick = function() ns.OpenOptions() end,
}

-- 米利的資訊列（MiliUI_InfoBar）上的一顆「M+結算」方塊。接口說明見
-- MiliUI_InfoBar/Core/Plugins.lua；同樣是塞全域表 —— 沒裝資訊列就只是一張沒人讀的表，
-- 資訊列那邊也是「有人塞才有方塊」，所以沒裝這支時不會出現。
-- ⚠ key 是資訊列存檔的鍵（玩家排過的位置、開關都掛在上面），發佈後別改名。
MiliUI_InfoBarPlugins = MiliUI_InfoBarPlugins or {}
MiliUI_InfoBarPlugins[#MiliUI_InfoBarPlugins + 1] = {
    key     = "mythicplus",
    text    = L["M+ Summary"],
    desc    = L["Toggles the settlement panel of MiliUI Mythic Plus. Right-click opens its settings."],
    order   = 58,     -- 確認倒數（57）後面
    OnClick = function(_, button)
        if button == "RightButton" then
            ns.OpenOptions()
        else
            ns.Panel.Toggle()
        end
    end,
    OnTooltip = function(tip)
        tip:AddLine(L["Left-click: toggle the settlement panel"], 0.8, 0.8, 0.8)
        tip:AddLine(L["Right-click: open the settings"], 0.8, 0.8, 0.8)
    end,
}

local function Usage()
    ns.Print(L["Commands:"])
    print("  |cffffd200/mmp|r — " .. L["toggle the settlement panel"])
    print("  |cffffd200/mmp config|r — " .. L["open the settings"])
    print("  |cffffd200/mmp test|r — " .. L["show a sample run without saving it"])
    print("  |cffffd200/mmp preview|r — " .. L["print what publishing would send, without sending it"])
    print("  |cffffd200/mmp probe on|off|dump|clear|r — " .. L["the in-game API probe"])
end

SLASH_MILIUIMYTHICPLUS1 = "/mmp"
SLASH_MILIUIMYTHICPLUS2 = "/miliuimythicplus"
SlashCmdList.MILIUIMYTHICPLUS = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "" then
        ns.Panel.Toggle()

    elseif msg == "config" or msg == "options" then
        ns.OpenOptions()

    elseif msg:match("^test") then
        local variant = tonumber(msg:match("^test%s+(%d+)$")) or 1
        -- ⚠ **不存檔**：假場次只是拿來看版面的，進了歷史就會污染真的記錄
        ns.Panel.SetRun(ns.History.MakeFake(variant))
        ns.Panel.Show()

    elseif msg == "preview" then
        -- 發佈的原文印在自己的聊天框、**不送出**，每行附上估算的寬度與位元組數：
        -- 給玩家在遊戲裡對照「這一行會不會折行」用的（預算是內容 ≤ 19 格、≤ 255B）。
        -- 假場次也可以看（只是不能送）。面板還沒開過就看最新那一場 —— 開面板時顯示的也是它
        local Pub = ns.Publish
        local run = ns.Panel.CurrentRun() or ns.History.Latest()
        if not run then
            ns.Print(L["No run to publish."])
        else
            for _, line in ipairs(Pub.CurrentLines(run)) do
                local w = Pub.ChatWidth(line)
                local wText = (w == math.floor(w)) and ("%d"):format(w) or ("%.1f"):format(w)
                ns.Print(line .. "  |cff888888"
                    .. L["(width %s · %dB)"]:format(wText, #line) .. "|r")
            end
        end

    elseif msg:match("^probe") then
        local arg = msg:match("^probe%s+(%S+)$")
        if arg == "on" then
            ns.Probe.SetEnabled(true)
            ns.Print(L["Probe: on"])
        elseif arg == "off" then
            ns.Probe.SetEnabled(false)
            ns.Print(L["Probe: off"])
        elseif arg == "dump" then
            ns.Probe.Dump()
        elseif arg == "clear" then
            ns.Probe.Clear()
            ns.Print(L["Probe log cleared."])
        else
            ns.Print(ns.Probe.IsEnabled() and L["Probe: on"] or L["Probe: off"])
            print("  |cffffd200/mmp probe on|off|dump|clear|r")
        end

    elseif msg:match("^debug") then
        -- 一次把「插件現在到底在幹嘛」全部印出來
        local db = ns.db
        ns.Print("v" .. ns.VERSION)
        print(("  %s  runs=%d  cap=%d"):format(
            ns.Recorder.StatusText(), ns.History.Count(), db and db.historyCap or -1))
        local n, lo, hi = ns.Snapshot.SessionRange()
        print(("  damageMeterAPI=%s  sessions=%d min=%s max=%s"):format(
            tostring(ns.HAS_DM_API), n, tostring(lo), tostring(hi)))
        if db and db.active then
            print(("  active: mapID=%s level=%s baseline=%s"):format(
                tostring(db.active.mapID), tostring(db.active.level),
                tostring(db.active.baselineSessionID)))
        end
        local restrictions = {}
        for _, name in ipairs(ns.RESTRICTION_TYPES) do
            restrictions[#restrictions + 1] = ("%s=%s"):format(name, ns.RestrictionActive(name) and "1" or "0")
        end
        print("  " .. table.concat(restrictions, " "))
        if #ns.errors == 0 then
            print("  " .. L["No errors recorded"])
        else
            for i, err in ipairs(ns.errors) do
                print(("  %d. %s"):format(i, err))
            end
        end

    else
        Usage()
    end
end
