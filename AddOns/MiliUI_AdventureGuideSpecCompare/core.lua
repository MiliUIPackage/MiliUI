-- MiliUI_AdventureGuideSpecCompare/core.lua
-- 主邏輯：監聽冒險指南 loot 更新，掃描同職業其他天賦的 loot，建立比對資料
--
-- 設計重點：
-- * 掃描資料（itemSpecMap）是「整個職業」的，跟 specID 無關。所以同職業換天賦時
--   不需要重掃，只要更新 ns.specID + 觸發 callbacks。
-- * 觸發掃描的條件：classID / encounterID / difficultyID 任一改變。
-- * EJ_LOOT_DATA_RECIEVED 在資料 async 抵達時補一次掃描。

local addonName, ns = ...

-- ============================================================
-- 共享狀態
-- ============================================================
ns.SCANNING       = false
ns.enabled        = false
ns.classID        = 0
ns.specID         = 0
ns.encounterID    = nil
ns.difficultyID   = nil
ns.classFile      = nil
ns.specList       = {}     -- 該職業所有天賦 { {id, name, icon, role, index}, ... }
ns.itemSpecMap    = {}     -- itemID -> { [specID] = true }
ns.itemInfoCache  = {}     -- itemID -> snapshot
ns.currentItemIDs = {}     -- set: 目前 filter 下出現的 itemID

-- ============================================================
-- 回呼註冊 (取代舊的 ns.OnEJLoaded 鏈)
-- ============================================================
ns.onEJLoaded = {}   -- list of fn() called once after Blizzard_EncounterJournal loads
ns.onScanned  = {}   -- list of fn() called after each scan / spec change

function ns.RegisterOnEJLoaded(fn) tinsert(ns.onEJLoaded, fn) end
function ns.RegisterOnScanned(fn)  tinsert(ns.onScanned,  fn) end

local function fireList(list, label)
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn)
        if not ok then
            print("|cffff5555[AGSC]|r " .. label .. " error:", err)
        end
    end
end

-- ============================================================
-- 工具
-- ============================================================
local function GetClassSpecs(classID)
    local out = {}
    local num = GetNumSpecializationsForClassID(classID) or 0
    for i = 1, num do
        local specID, name, _desc, icon, role = GetSpecializationInfoForClassID(classID, i)
        if specID then
            tinsert(out, { id = specID, name = name, icon = icon, role = role, index = i })
        end
    end
    return out
end

local function GetCurrentEncounterID()
    return EncounterJournal and EncounterJournal.encounterID or nil
end

local function GetCurrentDifficultyID()
    if EJ_GetDifficulty then return EJ_GetDifficulty() end
    return nil
end

-- 只保留可裝備的武器/護甲；過濾掉圖紙、家具、坐騎、寵物蛋、消耗品等
-- GetItemInfoInstant 同步回傳，class 2=Weapon、4=Armor
local function IsEquipment(itemID)
    if not itemID then return false end
    local _, _, _, _, _, classID = GetItemInfoInstant(itemID)
    return classID == 2 or classID == 4
end

-- ============================================================
-- 掃描
-- ============================================================
local function DoFullScan(classID)
    ns.specList = GetClassSpecs(classID)
    wipe(ns.itemSpecMap)
    wipe(ns.itemInfoCache)

    for _, spec in ipairs(ns.specList) do
        EJ_SetLootFilter(classID, spec.id)
        local numLoot = EJ_GetNumLoot() or 0
        for i = 1, numLoot do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            if info and info.itemID and IsEquipment(info.itemID) then
                local itemID = info.itemID
                local m = ns.itemSpecMap[itemID]
                if not m then
                    m = {}
                    ns.itemSpecMap[itemID] = m
                end
                m[spec.id] = true

                if not ns.itemInfoCache[itemID] then
                    ns.itemInfoCache[itemID] = {
                        itemID    = itemID,
                        name      = info.name,
                        icon      = info.icon,
                        slot      = info.slot,
                        armorType = info.armorType,
                        link      = info.link,
                        quality   = info.itemQuality,
                    }
                end
            end
        end
    end
end

local function UpdateCurrentItemIDs(classID, specID)
    EJ_SetLootFilter(classID, specID)
    wipe(ns.currentItemIDs)
    local numLoot = EJ_GetNumLoot() or 0
    for i = 1, numLoot do
        local info = C_EncounterJournal.GetLootInfoByIndex(i)
        if info and info.itemID then
            ns.currentItemIDs[info.itemID] = true
        end
    end
end

local function ScanIfNeeded()
    if ns.SCANNING then return end
    if not EncounterJournal then return end

    local classID, specID = EJ_GetLootFilter()
    if not classID or classID == 0 or not specID or specID == 0 then
        ns.enabled = false
        wipe(ns.itemSpecMap)
        wipe(ns.itemInfoCache)
        wipe(ns.currentItemIDs)
        ns.classID, ns.specID, ns.classFile = 0, 0, nil
        ns.encounterID, ns.difficultyID = nil, nil
        fireList(ns.onScanned, "callback")
        return
    end

    local currentEncounter   = GetCurrentEncounterID()
    local currentDifficulty  = GetCurrentDifficultyID()
    local sameContext        = (ns.classID == classID
                            and ns.encounterID == currentEncounter
                            and ns.difficultyID == currentDifficulty
                            and next(ns.itemSpecMap) ~= nil)

    ns.SCANNING = true

    if not sameContext then
        -- 完整掃描
        ns.classID       = classID
        ns.encounterID   = currentEncounter
        ns.difficultyID  = currentDifficulty
        local classInfo  = C_CreatureInfo and C_CreatureInfo.GetClassInfo
                           and C_CreatureInfo.GetClassInfo(classID) or nil
        ns.classFile     = classInfo and classInfo.classFile or nil
        DoFullScan(classID)
    end

    -- 不管有沒有重掃，都要更新 currentItemIDs 並還原 filter
    ns.specID  = specID
    ns.enabled = true
    UpdateCurrentItemIDs(classID, specID)

    ns.SCANNING = false
    fireList(ns.onScanned, "callback")
end
ns.ScanIfNeeded = ScanIfNeeded

-- 對外保留舊名（給除錯指令用）
ns.ScanAllSpecs = function()
    -- 強制重掃：清掉 context 再 scan
    ns.classID, ns.encounterID, ns.difficultyID = 0, nil, nil
    ScanIfNeeded()
end

-- ============================================================
-- Hook EJ
-- ============================================================
local function OnLootUpdate()
    if ns.SCANNING then return end
    ScanIfNeeded()
end

local function InitEJ()
    if ns._ejInited then return end
    ns._ejInited = true

    if type(_G.EncounterJournal_LootUpdate) == "function" then
        hooksecurefunc("EncounterJournal_LootUpdate", OnLootUpdate)
    end

    -- async loot data 抵達時強制補掃（可能是同一個 encounter 但資料變多了）
    local evt = CreateFrame("Frame")
    evt:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
    evt:SetScript("OnEvent", function() ns.ScanAllSpecs() end)

    fireList(ns.onEJLoaded, "init")
end

local function IsEJLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal")
    elseif _G.IsAddOnLoaded then
        return _G.IsAddOnLoaded("Blizzard_EncounterJournal")
    end
    return false
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == "Blizzard_EncounterJournal" then
        InitEJ()
    elseif event == "ADDON_LOADED" and name == addonName then
        AGSCDB = AGSCDB or { showBadges = true }
        ns.db = AGSCDB
        AGSCDB.showPanel = nil  -- 已棄用，面板改成永遠強制顯示；清掉殘留值
        if IsEJLoaded() then InitEJ() end
    elseif event == "PLAYER_LOGIN" then
        if IsEJLoaded() then InitEJ() end
    end
end)

-- ============================================================
-- 除錯指令
-- ============================================================
local commands = {
    rescan = function()
        ns.ScanAllSpecs()
        print("|cff66ccff[AGSC]|r 已強制重掃")
    end,
    dump = function()
        local n = 0
        for _ in pairs(ns.itemSpecMap) do n = n + 1 end
        print(string.format("|cff66ccff[AGSC]|r class=%d spec=%d enc=%s diff=%s items=%d",
              ns.classID, ns.specID,
              tostring(ns.encounterID), tostring(ns.difficultyID), n))
    end,
    panel = function()
        if ns.TogglePanel then ns.TogglePanel() end
    end,
    badges = function()
        ns.db.showBadges = not ns.db.showBadges
        print("|cff66ccff[AGSC]|r 徽章:", ns.db.showBadges and "開" or "關")
        fireList(ns.onScanned, "callback")
    end,
}

SLASH_AGSC1 = "/agsc"
SlashCmdList["AGSC"] = function(msg)
    msg = (msg or ""):lower():gsub("%s+", "")
    local fn = commands[msg]
    if fn then
        fn()
    else
        print("|cff66ccff[AGSC]|r 指令：/agsc " .. table.concat({"rescan", "dump", "panel", "badges"}, " | "))
    end
end
