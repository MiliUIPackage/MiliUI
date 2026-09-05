------------------------------------------------------------
-- MiliUI: 舊插件善後
--
-- 套組移除一個插件時，git 這邊是刪乾淨了，但玩家更新套組的方式通常是
-- 「解壓縮覆蓋」—— 舊資料夾不會自己消失，會繼續被遊戲載入。
-- 插件沒有權限刪除硬碟上的資料夾，能做的只有停用與提醒。
--
-- 兩類舊插件，處理方式不同：
--
--   REPLACED  被套組內建功能「取代」的。留著會兩套疊在一起，所以在取代者
--             真的有在跑的前提下自動停用，並跳視窗說明。每次登入都檢查，
--             玩家手動重開也會再被關掉 —— 除非在設定面板取消勾選。
--
--   REMOVED   從套組移除、但不打算替玩家決定去留的。不去碰它的啟用狀態，
--             只在聊天視窗提醒一次可以刪掉。
--
-- 停用狀態寫在 WTF 的 AddOns.txt，跟 SavedVariables 無關；因此額外把
-- 「哪些是我們關掉的」記在 MiliUI_DB.legacyAddonDisabled，玩家關掉這個功能時
-- 才有辦法幫他重新啟用回去。
------------------------------------------------------------

local C_AddOns = C_AddOns

-- 被套組內建功能取代 → 自動停用
-- folders 順序 = 停用順序，主插件放最後，避免相依插件先失去依賴
local REPLACED = {
    {
        label   = "Stuf",
        folders = { "Stuf_Options", "Stuf_Range", "Stuf" },
        -- 取代者：只有它真的在跑才算衝突。玩家若刻意停用米利的單位框架改用 Stuf，
        -- 這裡就不該多管閒事。
        replacement      = "MiliUI_UnitFrames",
        replacementLabel = "米利的單位框架",
    },
    {
        label   = "TinyTooltip",
        folders = { "TinyTooltip-Remake" },
        replacement      = "MiliUI_Tooltip",
        replacementLabel = "米利的滑鼠提示",
    },
}

-- 已從套組移除 → 不動它的啟用狀態，只提醒可以刪掉
-- WarpDeplete 的計時面板已由米利的任務追蹤器內建（Modules/MythicPlus.lua），
-- 但停用與否交給玩家決定，所以放這裡而不是 REPLACED。
local REMOVED = {
    { label = "MiniCC",      folders = { "MiniCC" } },
    { label = "WarpDeplete", folders = { "WarpDeplete" } },
}

------------------------------------------------------------
-- 工具
------------------------------------------------------------
local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    return MiliUI_DB
end

local function IsGuardEnabled()
    return GetDB().legacyAddonGuard ~= false   -- 預設開啟
end

-- 掃一次插件清單，回傳 { [插件名] = true }。
-- 用掃描而不是 GetAddOnInfo(name)：未安裝的名字丟進去行為不保證，掃描一定安全。
local function GetInstalledAddOns()
    local installed = {}
    local total = C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
    for i = 1, total do
        local name = C_AddOns.GetAddOnInfo(i)
        if name then installed[name] = true end
    end
    return installed
end

local function IsEnabled(name)
    if not (C_AddOns.GetAddOnEnableState and Enum and Enum.AddOnEnableState) then return false end
    local state = C_AddOns.GetAddOnEnableState(name, UnitName("player"))
    return state ~= Enum.AddOnEnableState.None
end

local function AnyInstalled(entry, installed)
    for _, name in ipairs(entry.folders) do
        if installed[name] then return true end
    end
    return false
end

local function Print(msg)
    print("|cff00ff00[MiliUI]|r " .. msg)
end

------------------------------------------------------------
-- 停用 / 還原
------------------------------------------------------------
-- 回傳實際被停用的插件名稱清單（沒動到任何東西時回傳空表）
local function DisableReplaced(installed)
    local db = GetDB()
    db.legacyAddonDisabled = db.legacyAddonDisabled or {}

    local disabled = {}
    for _, group in ipairs(REPLACED) do
        if C_AddOns.IsAddOnLoaded(group.replacement) then
            for _, name in ipairs(group.folders) do
                if installed[name] and IsEnabled(name) then
                    -- 不帶 character 參數 = 所有角色都停用，免得換小號又冒出來
                    C_AddOns.DisableAddOn(name)
                    db.legacyAddonDisabled[name] = true
                    disabled[#disabled + 1] = name
                end
            end
            -- 視窗裡已經寫了刪除方式，就別再另外用聊天訊息念一次
            if #disabled > 0 then
                db.legacyAddonHinted = db.legacyAddonHinted or {}
                db.legacyAddonHinted[group.label] = true
            end
        end
    end
    return disabled
end

-- 玩家選擇「保留」時，把我們關掉的重新打開
local function RestoreDisabled()
    local db = GetDB()
    local record = db.legacyAddonDisabled
    if not record then return 0 end

    local installed = GetInstalledAddOns()
    local count = 0
    for name in pairs(record) do
        if installed[name] then
            C_AddOns.EnableAddOn(name)
            count = count + 1
        end
    end
    db.legacyAddonDisabled = nil
    return count
end

------------------------------------------------------------
-- 提示視窗
------------------------------------------------------------
StaticPopupDialogs["MILIUI_LEGACY_ADDON_DISABLED"] = {
    text = "偵測到 %s 同時啟用，兩套功能會互相重疊。\n\n"
        .. "已自動停用（重新載入介面後生效）：\n|cffffd200%s|r\n\n"
        .. "|cff999999若要徹底移除，請先離開遊戲，\n"
        .. "再刪掉 Interface\\AddOns 底下的同名資料夾。|r",
    button1 = "重新載入介面",
    button2 = "稍後",
    button3 = "保留舊插件",
    OnAccept = function()
        ReloadUI()
    end,
    OnAlt = function()
        local count = RestoreDisabled()
        GetDB().legacyAddonGuard = false
        Print("已保留舊插件，不再自動停用（重新啟用 " .. count .. " 個，需 /reload 生效）。"
            .. "\n|cff999999可在「米利UI設定 → 插件強化 → 舊插件相容」重新開啟。|r")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function ShowDisabledPopup(disabled)
    -- 目前 REPLACED 只有 Stuf 一組，訊息用它的名稱；未來多組時再拆
    local group = REPLACED[1]
    local subject = ("|cffff8800%s|r 與 |cff33CCFF%s|r"):format(group.label, group.replacementLabel)
    StaticPopup_Show("MILIUI_LEGACY_ADDON_DISABLED", subject, table.concat(disabled, "、"))
end

------------------------------------------------------------
-- 「還躺在硬碟上」的提醒（每個插件只念一次）
------------------------------------------------------------
local function HintRemoval(installed)
    local db = GetDB()
    db.legacyAddonHinted = db.legacyAddonHinted or {}

    local pending = {}
    local function collect(entry)
        if db.legacyAddonHinted[entry.label] then return end
        if not AnyInstalled(entry, installed) then return end
        db.legacyAddonHinted[entry.label] = true
        pending[#pending + 1] = entry
    end

    for _, group in ipairs(REPLACED) do collect(group) end
    for _, entry in ipairs(REMOVED) do collect(entry) end
    if #pending == 0 then return end

    local names = {}
    for _, entry in ipairs(pending) do
        for _, folder in ipairs(entry.folders) do
            if installed[folder] then names[#names + 1] = folder end
        end
    end

    Print("偵測到已經不屬於米利UI套組的舊插件：|cffff8800" .. table.concat(names, "、") .. "|r"
        .. "\n|cff999999更新套組時舊資料夾不會自動消失。可以在插件清單取消勾選，"
        .. "或離開遊戲後刪掉 Interface\\AddOns 底下的同名資料夾。|r")
end

------------------------------------------------------------
-- 登入檢查
------------------------------------------------------------
local function RunGuard()
    local installed = GetInstalledAddOns()

    if IsGuardEnabled() then
        local disabled = DisableReplaced(installed)
        if #disabled > 0 then
            ShowDisabledPopup(disabled)
        end
    end

    HintRemoval(installed)
end

------------------------------------------------------------
-- 對外介面（設定面板用）
------------------------------------------------------------
MiliUI_LegacyAddons = {
    IsEnabled = IsGuardEnabled,

    -- 設定面板的勾選框：關掉時順手把我們停用的插件還原回去
    SetEnabled = function(enabled)
        GetDB().legacyAddonGuard = enabled and true or false
        if enabled then
            local disabled = DisableReplaced(GetInstalledAddOns())
            if #disabled > 0 then
                ShowDisabledPopup(disabled)
            end
        else
            local count = RestoreDisabled()
            if count > 0 then
                Print("已重新啟用 " .. count .. " 個舊插件，需 /reload 生效。")
            end
        end
    end,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    -- 延後幾秒：讓 Core.lua 的歡迎訊息先印完，也避開登入當下的載入畫面
    C_Timer.After(4, RunGuard)
end)
