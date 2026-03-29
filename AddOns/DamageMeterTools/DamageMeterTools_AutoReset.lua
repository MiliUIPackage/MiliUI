if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end

local L = DamageMeterTools_L or function(s) return s end

local pendingReset = nil
local pendingNeedConfirm = false
local pendingConfirmReason = nil
local lastResetTime = 0
local lastInstanceID = 0
local lastInstanceType = "none"
local lastDifficultyID = 0

local function GetDB()
    DamageMeterToolsDB.autoreset = DamageMeterToolsDB.autoreset or {}
    return DamageMeterToolsDB
end

local function EnsureDB()
    local db = GetDB()
    db.autoreset = db.autoreset or {}
    if db.autoreset.combatStart == nil then db.autoreset.combatStart = false end
    if db.autoreset.bossStart == nil then db.autoreset.bossStart = false end
    if db.autoreset.mythicStart == nil then db.autoreset.mythicStart = false end
    if db.autoreset.mythicEnter == nil then db.autoreset.mythicEnter = false end
    if db.autoreset.instanceEnter == nil then db.autoreset.instanceEnter = false end
    if db.autoreset.notify == nil then db.autoreset.notify = true end
    if db.autoreset.confirmReset == nil then db.autoreset.confirmReset = true end

    -- ✅ 每條觸發的「是否彈窗確認」
    if db.autoreset.confirmCombatStart == nil then db.autoreset.confirmCombatStart = false end
    if db.autoreset.confirmBossStart == nil then db.autoreset.confirmBossStart = false end
    if db.autoreset.confirmMythicStart == nil then db.autoreset.confirmMythicStart = false end
    if db.autoreset.confirmMythicEnter == nil then db.autoreset.confirmMythicEnter = false end
    if db.autoreset.confirmInstanceEnter == nil then db.autoreset.confirmInstanceEnter = true end
end

local function IsEnabled()
    if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
        return DamageMeterTools:IsModuleEnabled("AutoReset", false)
    end
    return false
end

local function CanReset()
    return C_DamageMeter and C_DamageMeter.ResetAllCombatSessions
end

local function Print(msg)
    local db = GetDB()
    if db.autoreset and db.autoreset.notify == false then return end
    print("|cff66ccff[DMT]|r " .. tostring(msg))
end

local function DoReset(reason)
    if not CanReset() then
        Print(L("找不到 C_DamageMeter.ResetAllCombatSessions（可能內建傷害統計未啟用）"))
        return
    end

    local now = GetTime() or 0
    if now - lastResetTime < 2 then
        return
    end
    lastResetTime = now

    C_DamageMeter.ResetAllCombatSessions()
    Print((L("已重置傷害統計：") or "已重置傷害統計：") .. tostring(reason or "unknown"))
end

if StaticPopupDialogs and not StaticPopupDialogs["DMT_CONFIRM_AUTO_RESET"] then
    StaticPopupDialogs["DMT_CONFIRM_AUTO_RESET"] = {
        text = L("偵測到「%s」，是否要重置傷害統計？") or "偵測到「%s」，是否要重置傷害統計？",
        button1 = L("清空") or "清空",
        button2 = L("取消") or "取消",
        OnAccept = function()
            local r = pendingConfirmReason
            pendingConfirmReason = nil
            DoReset(r or "unknown")
        end,
        OnCancel = function()
            pendingConfirmReason = nil
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
end
local function RequestConfirmReset(reason)
    local r = tostring(reason or (L("未知原因") or "未知原因"))
    pendingConfirmReason = r
    if StaticPopup_Show then
        StaticPopup_Show("DMT_CONFIRM_AUTO_RESET", r)
    else
        DoReset(r)
    end
end
local function QueueReset(reason, allowCombat, needConfirm)
    if not IsEnabled() then return end
    if not CanReset() then return end

    local db = GetDB()
    if needConfirm == nil then
        needConfirm = (db.autoreset and db.autoreset.confirmReset ~= false)
    end

    if needConfirm then
        if InCombatLockdown and InCombatLockdown() then
            pendingReset = reason
            pendingNeedConfirm = true
            return
        end
        RequestConfirmReset(reason)
        return
    end

    if InCombatLockdown and InCombatLockdown() and not allowCombat then
        pendingReset = reason
        pendingNeedConfirm = false
        return
    end

    DoReset(reason)
end

local function IsMythicOrKey(difficultyID)
    return difficultyID == 23 or difficultyID == 8
end

local function CheckInstanceState()
    if not IsEnabled() then return end

    local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    difficultyID = difficultyID or 0
    instanceID = instanceID or 0

    local inInstance = instanceType ~= "none"

    -- 新副本進入
    if inInstance and instanceID ~= 0 and instanceID ~= lastInstanceID then
        local db = GetDB()
        if db.autoreset.instanceEnter then
            QueueReset(L("進入新副本") or "進入新副本", false, db.autoreset.confirmInstanceEnter)
        end
    end

    lastInstanceID = instanceID
    lastInstanceType = instanceType or "none"
    lastDifficultyID = difficultyID
end

local function ScheduleInstanceCheck()
    local delays = { 0, 0.3, 0.8, 1.5 }
    for _, d in ipairs(delays) do
        C_Timer.After(d, function()
            CheckInstanceState()
        end)
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("ZONE_CHANGED")
ev:RegisterEvent("ZONE_CHANGED_INDOORS")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("ENCOUNTER_START")
ev:RegisterEvent("CHALLENGE_MODE_START")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")

ev:SetScript("OnEvent", function(_, event)
    EnsureDB()

    if event == "PLAYER_REGEN_DISABLED" then
        local db = GetDB()
        if db.autoreset.combatStart then
            QueueReset(L("戰鬥開始") or "戰鬥開始", true, db.autoreset.confirmCombatStart)
        end

    elseif event == "ENCOUNTER_START" then
        local db = GetDB()
        if db.autoreset.bossStart then
            QueueReset(L("BOSS 開始") or "BOSS 開始", true, db.autoreset.confirmBossStart)
        end

    elseif event == "CHALLENGE_MODE_START" then
        local db = GetDB()
        if db.autoreset.mythicStart then
            QueueReset(L("M+ 開始") or "M+ 開始", true, db.autoreset.confirmMythicStart)
        end

    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS" then
        ScheduleInstanceCheck()

    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingReset then
            local r = pendingReset
            local needConfirm = pendingNeedConfirm
            pendingReset = nil
            pendingNeedConfirm = false

            if needConfirm then
                RequestConfirmReset(r or L("脫戰後補做") or "脫戰後補做")
            else
                DoReset(r or L("脫戰後補做") or "脫戰後補做")
            end
        end
    end
end)

if DamageMeterTools then
    DamageMeterTools:RegisterSettingsCallback("AutoReset", function()
        -- 設定變更立即套用
    end)
end