-- MiliUI_AdventureGuideSpecCompare/looted.lua
-- 顯示「哪些裝備我有骰出來過」——資料【完全來自 KeystoneLoot】，本插件不自行偵測/記錄。
--
-- 背景：WoW 沒有任何 API 可回讀歷史取得記錄。KeystoneLoot 會自行記錄「虛空核心額外擲骰」
-- 骰到的物品，存在每角色 SavedVariable：
--     KeystoneLootCharDB.voidcore = { [itemID] = true, ... }   -- 扁平布林、僅額外擲骰、無難度/天賦
-- 我們直接讀它（read-only）。沒裝 KeystoneLoot（或它停用）→ 沒有資料 → 不顯示任何骰子。
--
-- 限制（已知並接受）：只涵蓋額外擲骰、無難度/天賦明細。
-- 若未來賽季 KeystoneLoot 不再提供，再回頭自行用事件（ENCOUNTER_LOOT_RECEIVED /
-- BONUS_ROLL_RESULT）+ 抓 difficulty(GetInstanceInfo) / lootspec(GetLootSpecialization)
-- 記錄——做法見 git 歷史 v1.1 的 looted.lua。

local addonName, ns = ...

local Looted = {}
ns.Looted = Looted

local CHECK_SIZE  = 16
local CHECK_ATLAS = "lootroll-toast-icon-need-up"   -- 骰子（與 KeystoneLoot 一致，直覺表示「骰到過」）

-- ============================================================
-- 資料來源：KeystoneLoot（read-only）
-- ============================================================
local function GetKSLVoidcore()
    if KeystoneLootCharDB and type(KeystoneLootCharDB.voidcore) == "table" then
        return KeystoneLootCharDB.voidcore
    end
    return nil
end

function Looted:IsAvailable()
    return GetKSLVoidcore() ~= nil
end

function Looted:HasAny(itemID)
    local ksl = GetKSLVoidcore()
    return ksl ~= nil and ksl[itemID] == true
end

-- tooltip 用：標註來源（KeystoneLoot 無難度/天賦，所以只有一行）
function Looted:GetSummaryLines(itemID)
    if self:HasAny(itemID) then
        return { "來自 KeystoneLoot（額外擲骰）" }
    end
    return nil
end

function Looted:PrintStats()
    local ksl = GetKSLVoidcore()
    if not ksl then
        print("|cff66ccff[AGSC]|r 未偵測到 KeystoneLoot 紀錄（未安裝或停用）；目前無「已取得」資料")
        return
    end
    local n = 0
    for _, v in pairs(ksl) do if v == true then n = n + 1 end end
    print(string.format("|cff66ccff[AGSC]|r 採用 KeystoneLoot 紀錄：%d 件（額外擲骰，無難度/天賦）", n))
end

-- ============================================================
-- 顯示：冒險指南 loot row 的「已取得」骰子
-- ============================================================
local function GetCheck(row)
    local c = row.AGSC_lootedCheck
    if not c then
        -- sublevel 7：OVERLAY 最上層（上限就是 7，設更大會無效→看不到），壓在圖示/品質框之上
        c = row:CreateTexture(nil, "OVERLAY", nil, 7)
        c:SetAtlas(CHECK_ATLAS)
        c:SetSize(CHECK_SIZE, CHECK_SIZE)
        -- 錨在物品圖示左下角，往左下挪一點露出來，不與右上的天賦徽章衝突
        if row.icon then
            c:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMLEFT", -2, -2)
        else
            c:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 2)
        end
        row.AGSC_lootedCheck = c
    end
    return c
end

local function ApplyLootedMark(row, elementData)
    local c = row.AGSC_lootedCheck

    -- index 來源：優先用 elementData（Init hook 提供），否則用 row.index（EJ row Init 後會設）。
    local index = (elementData and elementData.index) or row.index
    local isHeader = elementData and elementData.header

    if not ns.db or ns.db.featureEnabled == false or ns.db.showLooted == false
       or isHeader or not index or not row.icon then
        if c then c:Hide() end
        return
    end

    local info = C_EncounterJournal.GetLootInfoByIndex(index)
    if not info or not info.itemID or not Looted:HasAny(info.itemID) then
        if c then c:Hide() end
        return
    end

    GetCheck(row):Show()
end
ns.ApplyLootedMark = ApplyLootedMark

-- 對所有目前可見的 loot row 重新套用骰子
local function RefreshLootedMarks()
    if not EncounterJournal or not EncounterJournal.encounter then return end
    local lc = EncounterJournal.encounter.info
               and EncounterJournal.encounter.info.LootContainer
    local scrollBox = lc and lc.ScrollBox
    if not scrollBox or not scrollBox.ForEachFrame then return end
    scrollBox:ForEachFrame(ApplyLootedMark)
end
ns.RefreshLootedMarks = RefreshLootedMarks

-- ============================================================
-- 註冊到 EJ：掛 row Init 與每次掃描後重畫
-- ============================================================
ns.RegisterOnEJLoaded(function()
    if _G.EncounterJournalItemMixin and not ns._lootedHooked then
        ns._lootedHooked = true
        hooksecurefunc(EncounterJournalItemMixin, "Init", ApplyLootedMark)
    end
end)

ns.RegisterOnScanned(RefreshLootedMarks)
