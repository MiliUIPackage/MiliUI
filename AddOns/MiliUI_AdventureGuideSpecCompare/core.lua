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

local function GetCurrentInstanceID()
    if EJ_GetCurrentInstance then
        local id = EJ_GetCurrentInstance()
        if id and id ~= 0 then return id end
    end
    return EncounterJournal and EncounterJournal.instanceID or nil
end

local function GetCurrentDifficultyID()
    if EJ_GetDifficulty then return EJ_GetDifficulty() end
    return nil
end

-- 判斷一筆 EJ loot 是否為「裝備相關」（含套裝兌換物 tier token）。
-- 依據實測資料（/agsc loot）：
--   * 可裝備物品 equipLoc = 真實欄位 (INVTYPE_HEAD / INVTYPE_TRINKET / INVTYPE_WEAPON...)
--   * 非裝備物品 equipLoc = "INVTYPE_NON_EQUIP_IGNORE"（注意：非空字串！）
--   * 公式/圖樣=class9、戰利品袋/材料=class20、tier token=class15
-- 規則：真實裝備欄位，或 class15(tier token，排除坐騎/寵物) → 視為裝備；其餘略過。
local function IsEquipment(info)
    if not info or not info.itemID then return false end
    local _, _, _, equipLoc, _, classID, subClassID = GetItemInfoInstant(info.itemID)

    -- 真實可裝備欄位（排除 INVTYPE_NON_EQUIP_IGNORE 這種「不可裝備」標記）
    if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
        return true
    end

    -- 套裝兌換物 (tier token)：Miscellaneous(15)，排除坐騎(5)/伴隨寵物(2)
    if classID == 15 and subClassID ~= 5 and subClassID ~= 2 then
        return true
    end

    return false
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
            if info and info.itemID and IsEquipment(info) then
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

    -- 只需要選了「職業」即可掃描；具體天賦(specID)不是必要——掃描時我們自己對
    -- 每個天賦切換 filter。specID 只用來決定預設基準天賦，0(所有天賦) 也 OK。
    local classID, specID = EJ_GetLootFilter()
    specID = specID or 0
    if not classID or classID == 0 then
        ns.enabled = false
        wipe(ns.itemSpecMap)
        wipe(ns.itemInfoCache)
        wipe(ns.currentItemIDs)
        ns.classID, ns.specID, ns.classFile = 0, 0, nil
        ns.encounterID, ns.difficultyID, ns.instanceID = nil, nil, nil
        fireList(ns.onScanned, "callback")
        return
    end

    local currentEncounter   = GetCurrentEncounterID()
    local currentInstance    = GetCurrentInstanceID()
    local currentDifficulty  = GetCurrentDifficultyID()
    local sameContext        = (ns.classID == classID
                            and ns.instanceID == currentInstance
                            and ns.encounterID == currentEncounter
                            and ns.difficultyID == currentDifficulty
                            and next(ns.itemSpecMap) ~= nil)

    ns.SCANNING = true

    if not sameContext then
        -- 完整掃描
        ns.classID       = classID
        ns.instanceID    = currentInstance
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
        AGSCDB.showPanel = nil  -- 已棄用
        if AGSCDB.featureEnabled == nil then AGSCDB.featureEnabled = true end       -- 主開關（右上按鈕）
        if AGSCDB.baselineShowShared == nil then AGSCDB.baselineShowShared = true end -- 對照欄顯示全系共用（預設開）
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
        print(string.format("|cff66ccff[AGSC]|r class=%d spec=%d inst=%s enc=%s diff=%s items=%d",
              ns.classID, ns.specID, tostring(ns.instanceID),
              tostring(ns.encounterID), tostring(ns.difficultyID), n))
    end,
    loot = function()
        -- 列出目前 filter 下每筆 loot 的 classID/subClassID/filterType，方便診斷過濾
        local num = EJ_GetNumLoot() or 0
        print(string.format("|cff66ccff[AGSC]|r 目前 loot 共 %d 筆：", num))
        for i = 1, num do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            if info and info.itemID then
                local _, _, _, equipLoc, _, classID, subClassID = GetItemInfoInstant(info.itemID)
                print(string.format("  [%d] %s | id=%d class=%s sub=%s ft=%s equip=%s",
                    i, tostring(info.name), info.itemID,
                    tostring(classID), tostring(subClassID),
                    tostring(info.filterType),
                    (equipLoc ~= "" and equipLoc) or "-"))
            end
        end
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
        print("|cff66ccff[AGSC]|r 指令：/agsc " .. table.concat({"rescan", "dump", "panel", "badges", "loot"}, " | "))
    end
end
