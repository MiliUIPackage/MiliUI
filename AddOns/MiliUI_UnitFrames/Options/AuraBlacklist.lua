------------------------------------------------------------
-- 光環黑名單挑選視窗
--
-- 左邊列出「這個單位現在身上有什麼」，右邊是黑名單，按 ＋／－ 搬過去。
-- 名單存進 `udb.elements.<buffs|debuffs>.blacklist`（[spellID] = true），
-- 由 Elements/Auras.lua 交給引擎的 candidateFilters.excludeSpellIDs 過濾。
--
-- ⚠ 12.1 之後插件讀不到光環內容：在戰鬥／首領戰／M+／評分 PvP 裡，
-- 光環資料是秘密值，這裡會一顆都掃不到（不是壞掉，是規則）。所以掃描一律
-- 包 pcall，而且只取 spellId —— 名字與圖示改用 C_Spell.GetSpellInfo 查，
-- 那條路吃的是明文 ID，不受限制。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.AuraBlacklist = {}
local BL = ns.AuraBlacklist

local POPUP_W, POPUP_H = 560, 380
local LIST_W, LIST_H   = 258, 250
local ROW_H            = 24
local MAX_SCAN         = 40      -- 遠比任何單位身上的光環數多，掃到 nil 就停

local popup, leftList, rightList, hintText, idPopup
local ctxUnitKey, ctxElement
local ctxChanged        -- 表單那一列的「筆數變了」回呼（見 BL.Open）

------------------------------------------------------------
-- 讀一顆光環
--
-- 只要 spellId。整段包 pcall：受限情境下 GetAuraDataByIndex 會直接拋錯，
-- 而且回傳的表本身可能是秘密表，連 index 都不合法。
-- 第二個回傳值 = 「掃不下去了」。
------------------------------------------------------------
local function ReadSpellIDAt(unit, index, filter)
    local ok, id = pcall(function()
        local d = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        return d and d.spellId or nil
    end)
    if not ok then return nil, true end          -- 受限情境
    if id == nil then return nil, true end       -- 掃完了
    id = ns.Desecret(id)                          -- 秘密值不能當 key
    if id == nil then return nil, true end
    return id
end

local function ScanUnit(unit, filter)
    local out = {}
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return out end
    if not UnitExists(unit) then return out end
    for i = 1, MAX_SCAN do
        local id, stop = ReadSpellIDAt(unit, i, filter)
        if stop then break end
        out[#out + 1] = id
    end
    return out
end

-- 名字與圖示一律從 spellID 查，不碰光環資料裡的欄位
local function SpellDisplay(id)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    return (info and info.name) or ("spell:" .. id), (info and info.iconID) or 134400
end

------------------------------------------------------------
-- 目前的設定表
------------------------------------------------------------
local function CurrentEDB()
    if not ctxUnitKey then return nil end
    local udb = ns.GetUnitDB(ctxUnitKey)
    return udb and udb.elements and udb.elements[ctxElement]
end

local function CurrentBlacklist()
    local edb = CurrentEDB()
    if not edb then return nil end
    edb.blacklist = edb.blacklist or {}      -- 預設沒有這一格，第一次用才長出來
    return edb.blacklist
end

-- 這個單位在遊戲裡的 token（設定用的 key 跟 token 只有首領不一樣）
local function UnitToken(unitKey)
    if unitKey == "boss" then return "boss1" end
    return unitKey
end

local function Apply()
    if ctxUnitKey then ns.ApplySettings(ctxUnitKey) end
    -- 表單上那顆按鈕寫著筆數，ApplySettings 不會重整它（那條路只重建文字分頁）
    if ctxChanged then ctxChanged() end
end

------------------------------------------------------------
-- 兩張清單
------------------------------------------------------------
-- ⚠ 列會回收再用，所以 handler 一律讀 row.spellID（更新時才填），
-- 不要在 buildRow 裡把 ID 抓進 closure —— 那樣捲動幾次之後就會搬到別顆。
local function MakeRow(row, actionText, onAction)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.btn = W.CreateButton(row, actionText, "normal", 22, 18)
    row.btn:SetPoint("RIGHT", -6, 0)
    row.btn:SetScript("OnClick", function()
        if row.spellID then onAction(row.spellID) end
    end)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(W.fontNormal)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row.btn, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not row.spellID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(row.spellID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
end

local function UpdateRow(row, id)
    row.spellID = id
    local name, icon = SpellDisplay(id)
    row.icon:SetTexture(icon)
    row.name:SetText(name)
end

local Refresh   -- 前向宣告（下面兩個 handler 互相呼叫）

local function AddToBlacklist(id)
    local bl = CurrentBlacklist()
    if not bl then return end
    bl[id] = true
    Apply()
    Refresh()
end

local function RemoveFromBlacklist(id)
    local bl = CurrentBlacklist()
    if not bl then return end
    bl[id] = nil
    Apply()
    Refresh()
end

Refresh = function()
    if not (popup and popup:IsShown()) then return end
    local bl = CurrentBlacklist() or {}

    -- 左：現在身上有的，扣掉已經在名單裡的
    local filter = ctxElement == "debuffs" and "HARMFUL" or "HELPFUL"
    local live, seen = {}, {}
    for _, id in ipairs(ScanUnit(UnitToken(ctxUnitKey), filter)) do
        if not bl[id] and not seen[id] then      -- 同一顆疊很多層只列一次
            seen[id] = true
            live[#live + 1] = id
        end
    end
    leftList:Update(live, UpdateRow)

    -- 右：黑名單。排序過，不然每次開啟順序都不一樣
    local banned = {}
    for id, on in pairs(bl) do
        if on then banned[#banned + 1] = id end
    end
    table.sort(banned)
    rightList:Update(banned, UpdateRow)

    hintText:SetText(#live == 0 and L["Aura details are hidden in combat, encounters, Mythic+ and rated PvP, so nothing can be listed there. Step outside to pick."] or "")
end

------------------------------------------------------------
-- 手動輸入法術 ID
--
-- 敵方減益幾乎都是戰鬥中才看得到，而戰鬥中光環是秘密值、左邊那張清單一定是空的
-- ⇒ 沒有這條路的話，最需要擋的東西反而加不進來。
-- ID 從工具提示（CVar tooltipShowAuraSpellIDs）或網站抄，貼法術連結也認得。
------------------------------------------------------------
local function OpenIDEntry()
    if not idPopup then
        idPopup = W.CreateInputPopup(ns.Options.panel, 400, L["Add by spell ID"], {
            { key = "id", label = L["Spell ID"], maxLetters = 40,
              hint = L["Type a spell ID, or paste a spell link. Aura details are hidden in combat, so this is the only way to add something you only ever see mid-fight."] },
        })
    end
    idPopup:Open(nil, function(values)
        local text = values.id or ""
        local id = tonumber(text) or tonumber(text:match("spell:(%d+)") or "")
        if not id or not (C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)) then
            print("|cff4DD2FF" .. L["[MiliUI UF]"] .. "|r " .. L["No spell with that ID."])
            return false          -- 不關窗，讓玩家直接改
        end
        AddToBlacklist(id)
    end)
end

------------------------------------------------------------
-- 視窗
------------------------------------------------------------
local function CreatePopup()
    if popup then return end

    local parent = ns.Options and ns.Options.panel
    if not parent then return end

    popup = W.CreateFrame(nil, parent, POPUP_W, POPUP_H)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup:Hide()

    -- 背後的遮罩，跟共用層的確認彈窗同一套（擋掉點到底下控制項）
    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function() mask:Hide() end)

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Blacklist"])

    local leftLabel = W.CreateGroupLabel(popup, L["Auras on this unit"])
    leftLabel:SetPoint("TOPLEFT", 16, -38)
    local rightLabel = W.CreateGroupLabel(popup, L["Blacklisted"])
    rightLabel:SetPoint("TOPLEFT", 16 + LIST_W + 12, -38)

    leftList  = W.CreateRowList(popup, LIST_W, LIST_H, ROW_H, function(row)
        MakeRow(row, "+", AddToBlacklist)
    end)
    leftList:SetPoint("TOPLEFT", 16, -56)

    rightList = W.CreateRowList(popup, LIST_W, LIST_H, ROW_H, function(row)
        MakeRow(row, "-", RemoveFromBlacklist)
    end)
    rightList:SetPoint("TOPLEFT", 16 + LIST_W + 12, -56)

    hintText = popup:CreateFontString(nil, "OVERLAY")
    hintText:SetFontObject(W.fontSmall)
    hintText:SetPoint("TOPLEFT", 16, -(56 + LIST_H + 8))
    hintText:SetPoint("RIGHT", popup, "RIGHT", -16, 0)
    hintText:SetJustifyH("LEFT")
    hintText:SetSpacing(2)

    local rescan = W.CreateButton(popup, L["Rescan"], "normal", 100, 22)
    rescan:SetPoint("BOTTOMLEFT", 16, 12)
    rescan:SetScript("OnClick", Refresh)

    local byID = W.CreateButton(popup, L["Add by spell ID"], "normal", 150, 22)
    byID:SetPoint("LEFT", rescan, "RIGHT", 8, 0)
    byID:SetScript("OnClick", OpenIDEntry)

    local close = W.CreateButton(popup, L["Okay"], "accent", 100, 22)
    close:SetPoint("BOTTOMRIGHT", -16, 12)
    close:SetScript("OnClick", function() popup:Hide() end)
end

function BL.Open(unitKey, elementName, onChanged)
    ctxUnitKey, ctxElement, ctxChanged = unitKey, elementName, onChanged
    CreatePopup()
    if not popup then return end
    popup:Show()
    Refresh()
end

-- 表單那一列要顯示筆數
function BL.Count(edb)
    local bl = edb and edb.blacklist
    if type(bl) ~= "table" then return 0 end
    local n = 0
    for _, on in pairs(bl) do
        if on then n = n + 1 end
    end
    return n
end
