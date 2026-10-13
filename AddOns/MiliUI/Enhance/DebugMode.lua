------------------------------------------------------------
-- 除錯模式：一鍵只留套組本體與錯誤收集，再一鍵還原
--
-- 給玩家回報問題用：先排除「是不是別的插件害的」。進入時停用除了
-- KEEP 以外所有對目前角色啟用中的插件（自製的 MiliUI_* 也停——目的就是排除），
-- 把原本的清單記進 MiliUI_DB.debugMode（帳號層級），打開 scriptErrors，然後重載。
-- 離開時照記下的清單重新啟用、scriptErrors 還原，再重載。
--
-- 入口：/miliui debug on|off、設定視窗「插件總覽」分頁標題列右邊那顆按鈕。
--
-- ⚠ 開關的範圍（角色參數）：
--   插件總覽分頁的批次開關是「不帶角色參數＝所有角色一起」。這裡沿用，但多分一種情況：
--   * 對所有角色都啟用（GetAddOnEnableState 不帶角色 = All）→ 停用／還原都不帶角色參數。
--   * 只對部分角色啟用（= Some，玩家自己按角色設過）→ 停用／還原都只動目前這隻角色，
--     不然還原時會把它擴散成全角色啟用、或把別隻角色的設定一起清掉。
--
-- ⚠ 記錄只在「進入」時寫一次。已經在除錯模式中再按「進入」不覆蓋——
--   覆蓋的話記到的就是「已經被停光」的清單，原本的設定再也找不回來。
--
-- ⚠ 還原「以記下的清單為準」：除錯中玩家手動又開了別的插件，離開時也一併關回去
--   （只對目前角色），最後的狀態＝進入前的狀態。
--
-- 確認框不走 StaticPopup（從插件 Lua 開會把共用彈窗框寫髒，見 BonusRoll_Confirm.lua 檔頭）：
-- 設定視窗用自己的確認框，斜線指令本身就是明確的指令，直接做。
------------------------------------------------------------
local _, ns = ...

-- 進入除錯模式時保留的插件。自己（本體）一定要在，不然離開的入口就不見了。
local KEEP = {
    ["MiliUI"]       = true,
    ["!BugGrabber"]  = true,
    ["BugSack"]      = true,
}

local IS_ZH = GetLocale() == "zhTW" or GetLocale() == "zhCN"

local function Me()
    return (UnitName("player"))
end

local function EnableState(name, character)
    if not (C_AddOns.GetAddOnEnableState and Enum and Enum.AddOnEnableState) then return nil end
    return C_AddOns.GetAddOnEnableState(name, character)
end

-- 跟插件總覽分頁的 IsFolderEnabled 同一個判準：對目前角色不是 None 就算啟用
local function EnabledForMe(name)
    local s = EnableState(name, Me())
    if s == nil then return true end
    return s ~= Enum.AddOnEnableState.None
end

local function AllInstalled()
    local list = {}
    local total = C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
    for i = 1, total do
        local name = C_AddOns.GetAddOnInfo(i)
        if name then list[#list + 1] = name end
    end
    return list
end

local function Record()
    local db = MiliUI_DB
    local rec = db and db.debugMode
    if type(rec) == "table" and type(rec.addons) == "table" then return rec end
end

local DM = {}
ns.DebugMode = DM

function DM.IsActive()
    return Record() ~= nil
end

-- 除錯模式中停用了幾支（給設定視窗顯示）
function DM.DisabledCount()
    local rec = Record()
    if not rec then return 0 end
    local n = 0
    for _ in pairs(rec.addons) do n = n + 1 end
    return n
end

-- 進入時會停用幾支（確認框用）
function DM.PendingCount()
    local n = 0
    for _, name in ipairs(AllInstalled()) do
        if not KEEP[name] and EnabledForMe(name) then n = n + 1 end
    end
    return n
end

-- 回傳 true＝有改動、需要重載
function DM.Enter()
    if DM.IsActive() then
        ns.Print(IS_ZH and "已經在除錯模式中。輸入 /miliui debug off 離開。"
            or "Already in debug mode. Type /miliui debug off to leave.")
        return false
    end
    if not MiliUI_DB then MiliUI_DB = {} end

    local me = Me()
    local all = Enum.AddOnEnableState and Enum.AddOnEnableState.All
    local rec = {
        char         = me,
        scriptErrors = C_CVar.GetCVar("scriptErrors") or "0",
        addons       = {},   -- name -> "all"｜"char"（還原時用同一個範圍）
        keepEnabled  = {},   -- 原本沒開、為了除錯才打開的保留插件（離開時關回去）
        time         = time(),
    }

    for _, name in ipairs(AllInstalled()) do
        if KEEP[name] then
            if name ~= "MiliUI" and not EnabledForMe(name) then
                C_AddOns.EnableAddOn(name, me)
                rec.keepEnabled[name] = true
            end
        elseif EnabledForMe(name) then
            if EnableState(name) == all then
                C_AddOns.DisableAddOn(name)
                rec.addons[name] = "all"
            else
                C_AddOns.DisableAddOn(name, me)
                rec.addons[name] = "char"
            end
        end
    end

    C_CVar.SetCVar("scriptErrors", "1")
    MiliUI_DB.debugMode = rec
    return true
end

-- 回傳 true＝有改動、需要重載
function DM.Leave()
    local rec = Record()
    if not rec then
        ns.Print(IS_ZH and "目前不在除錯模式中。" or "Not in debug mode.")
        return false
    end

    local me = Me()
    local char = rec.char or me
    local installed = {}
    for _, name in ipairs(AllInstalled()) do installed[name] = true end

    for name, scope in pairs(rec.addons) do
        if installed[name] then
            if scope == "all" then
                C_AddOns.EnableAddOn(name)
            else
                C_AddOns.EnableAddOn(name, char)
            end
        end
    end

    -- 除錯中手動開的、不在記錄裡的：關回去（以記下的清單為準）
    for name in pairs(installed) do
        if not KEEP[name] and rec.addons[name] == nil and EnabledForMe(name) then
            C_AddOns.DisableAddOn(name, me)
        end
    end

    if type(rec.keepEnabled) == "table" then
        for name in pairs(rec.keepEnabled) do
            if installed[name] then C_AddOns.DisableAddOn(name, char) end
        end
    end

    C_CVar.SetCVar("scriptErrors", tostring(rec.scriptErrors or "0"))
    MiliUI_DB.debugMode = nil
    return true
end

local function PrintUsage()
    if IS_ZH then
        ns.Print("除錯模式：")
        print("  /miliui debug on  — 只留米利UI套組本體、!BugGrabber、BugSack，其餘插件全部停用並重載")
        print("  /miliui debug off — 重新啟用進入前的插件並重載")
        print("  /miliui debug     — 顯示本體記錄到的錯誤")
    else
        ns.Print("Debug mode:")
        print("  /miliui debug on  — keep only MiliUI, !BugGrabber and BugSack, disable everything else and reload")
        print("  /miliui debug off — re-enable the addons from before and reload")
        print("  /miliui debug     — show errors recorded by MiliUI")
    end
end

-- 斜線指令：arg 是 "debug" 後面那一段
function DM.Command(arg)
    arg = strtrim(strlower(arg or ""))
    if arg == "on" or arg == "1" then
        if DM.Enter() then ReloadUI() end
    elseif arg == "off" or arg == "0" then
        if DM.Leave() then ReloadUI() end
    else
        PrintUsage()
    end
end

------------------------------------------------------------
-- 除錯模式中每次登入提醒一次（含怎麼離開）
------------------------------------------------------------
local function Remind()
    if not DM.IsActive() then return end
    local n = DM.DisabledCount()
    if IS_ZH then
        ns.Print(("|cffff9900目前在除錯模式中|r：已停用 %d 個插件，只留套組本體與 BugSack。"):format(n))
        print("  回報完問題後輸入 |cffffd200/miliui debug off|r，或到設定視窗「插件總覽」按「離開除錯模式」，就會把插件還原。")
    else
        ns.Print(("|cffff9900Debug mode is ON|r: %d addons disabled, only MiliUI and BugSack are loaded."):format(n))
        print("  Type |cffffd200/miliui debug off|r (or use the Addons tab in /miliui) to restore your addons.")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(2, function() xpcall(Remind, ns.ReportError) end)
end)
