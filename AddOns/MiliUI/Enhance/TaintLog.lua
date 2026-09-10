------------------------------------------------------------
-- taintLog 常駐開關（/miliui taint on / off）
--
-- `taintLog` 是 CVar，但**不寫進 Config.WTF**：/reload 留得住，重開遊戲就歸零。
-- 所以「一直開著」沒辦法交給遊戲記，只能自己存旗標、每次載入重套一次。
--
-- 三件反直覺的事：
--
--   1. **SetCVar 對除錯類 CVar 不保證吃，而且失敗是靜默的。** 設完一定要讀回來驗，
--      不過就退到 ConsoleExec（等同玩家自己打 `/console taintLog 2`）再驗一次，
--      兩條都不過才明講「沒開成」——不要設完就當它開了。
--
--   2. **taintLog 只從「打開的那一刻」開始記。** 重開遊戲的那一輪，我們最早也只能在
--      MiliUI 自己的 ADDON_LOADED 才拿得到旗標（SavedVariables 那時候才在），
--      載入順序排在後面的插件記得到、前面的記不到。要連整個載入期一起抓，
--      就在遊戲裡 /reload 一次——CVar 那時還開著，那一輪從第一個插件就開始記。
--
--   3. **執行層級的污染 taintLog 是瞎的**（.claude/notes/wow-121-addon-code-in-secure-stack.md）。
--      log 裡乾乾淨淨不代表沒有污染：12.1 那種「自己的 Lua 跑在暴雪 secure 堆疊裡」
--      不會留下對應的行。它抓得到的是**變數層級**的污染（「Global variable X tainted by 誰」）。
--
-- 代價：一場 log 從 1MB 起跳，追久了幾十 MB，忘記關會一直長——所以每次登入都印一行。
-- log 在 Logs\taint.log，**/reload 會清空重寫**，要留存的先把檔案複製走再重載。
------------------------------------------------------------
local _, ns = ...

local ON, OFF = "2", "0"

local function Level()
    local v = GetCVar and GetCVar("taintLog")
    return v and tostring(v) or "?"
end

-- 回傳：是否套用成功, 走哪條路成功（失敗時是現在的值）
local function Apply(level)
    if Level() == level then return true, "本來就是" end
    pcall(SetCVar, "taintLog", level)
    if Level() == level then return true, "SetCVar" end
    pcall(ConsoleExec, "taintLog " .. level)
    if Level() == level then return true, "ConsoleExec" end
    return false, Level()
end

-- 檔案執行當下的值。已經是 2 表示這一輪從頭就在記（從 /reload 進來的）。
-- 必須在動它之前抓，之後就分不出來了。
local coveredFromStart = (Level() == ON)

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    return MiliUI_DB
end

local function IsEnabled()
    return MiliUI_DB and MiliUI_DB.taintLog == true
end

------------------------------------------------------------
-- 印狀態
------------------------------------------------------------
local function PrintScope()
    if coveredFromStart then
        print("  |cff999999這一輪|r|cffffd200含插件載入期|r|cff999999都有記。|r")
    else
        print("  |cff999999這一輪只記到米利UI載入之後；要連載入期一起抓就 |r|cffffd200/reload|r|cff999999 再重現一次。|r")
    end
end

local function PrintLogHint()
    print("  |cff999999log 在 Logs\\taint.log，|r|cffffd200/reload 會清空重寫|r|cff999999——要留存先把檔案複製走。|r")
end

local function ReportFailure(now)
    ns.Print(("taintLog |cffff4411沒開成|r（現在是 %s）—— 自己打一次 |cffffd200/console taintLog %s|r")
        :format(now, ON))
end

------------------------------------------------------------
-- 開 / 關
------------------------------------------------------------
local function Enable(quiet)
    GetDB().taintLog = true
    local ok, how = Apply(ON)
    if not ok then
        ReportFailure(how)
        return false
    end
    if not quiet then
        ns.Print(("taintLog=|cffffd200%s|r 已開啟，並且|cffffd200每次登入都會自動開|r（%s）。"):format(ON, how))
        PrintScope()
        PrintLogHint()
        print("  |cff999999不用了就打 |r|cffffd200/miliui taint off|r|cff999999。|r")
    end
    return true
end

local function Disable()
    GetDB().taintLog = nil
    local ok, how = Apply(OFF)
    if ok then
        ns.Print("taintLog 已關閉，之後登入也不再自動開。")
    else
        ns.Print(("taintLog 的自動開啟已取消，但這一輪關不掉（現在是 %s）—— 自己打一次 |cffffd200/console taintLog 0|r 或重開遊戲。")
            :format(how))
    end
end

local function Status()
    local on = IsEnabled()
    ns.Print(("taintLog：常駐開關 %s，目前 CVar = |cffffd200%s|r")
        :format(on and "|cff33ff66開|r" or "|cff999999關|r", Level()))
    if Level() == ON then PrintScope() end
    PrintLogHint()
    print("  |cff999999開：|r|cffffd200/miliui taint on|r|cff999999　關：|r|cffffd200/miliui taint off|r")
    print("  |cff999999抓得到的是變數層級的污染；「自己的 Lua 跑在暴雪堆疊裡」那種不會留下行。|r")
end

------------------------------------------------------------
-- 對內介面（Api.lua 的 /miliui taint 走這裡）
------------------------------------------------------------
ns.TaintLog = {
    IsEnabled = IsEnabled,
    SetEnabled = function(enabled)
        if enabled then Enable() else Disable() end
    end,
    Command = function(arg)
        arg = strtrim(arg or "")
        if arg == "on" or arg == "1" or arg == "開" then
            Enable()
        elseif arg == "off" or arg == "0" or arg == "關" then
            Disable()
        else
            Status()
        end
    end,
}

------------------------------------------------------------
-- 每次載入自動重套
------------------------------------------------------------
-- SavedVariables 若在檔案執行前就到位，這裡就能比 ADDON_LOADED 更早開起來
-- （早一點 = 多記到幾支插件的載入期）。只讀不寫：那個時間點 MiliUI_DB 還可能是
-- nil，建一張空表會被之後載進來的存檔蓋掉，反而製造疑點。
if IsEnabled() then Apply(ON) end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" then
        -- 自己的存檔進來的那一刻：這是我們拿得到旗標的最早時機
        if addon ~= "MiliUI" then return end
        self:UnregisterEvent("ADDON_LOADED")
        if IsEnabled() then Apply(ON) end
        return
    end

    self:UnregisterEvent("PLAYER_LOGIN")
    if not IsEnabled() then return end
    -- 提醒放在 PLAYER_LOGIN：ADDON_LOADED 當下聊天視窗還不一定收得到字。
    -- 每次登入都念一次是刻意的——log 會一直長，忘記關的代價是幾十 MB。
    if Level() ~= ON then
        local ok, how = Apply(ON)
        if not ok then
            ReportFailure(how)
            return
        end
    end
    ns.Print(("taintLog=|cffffd200%s|r 常駐開啟中。"):format(ON))
    PrintScope()
    print("  |cff999999關掉：|r|cffffd200/miliui taint off|r")
end)
