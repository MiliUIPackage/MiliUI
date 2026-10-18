------------------------------------------------------------
-- 外觀：滑鼠提示（從 Core/Decorate.lua 切出，2026-10-18；TOC 緊接在 Decorate_Rings.lua 之後載入）
--
-- 跨檔的幫手掛在 ns.Decorate 上（CurrentBarAlpha），這裡取回成 local。
-- 給 Decorate.lua 回頭叫的：D.ApplyTooltip（Apply）。
------------------------------------------------------------
local _, ns = ...

local D = ns.Decorate
local CurrentBarAlpha = D.CurrentBarAlpha

------------------------------------------------------------
-- 滑鼠提示
--
-- overlay 蓋在 item 上面（子框收到 OnEnter 之後父層就收不到）。它收不收滑鼠移動（D.TipPass）決定提示由誰畫：
--   * **讓給暴雪 item**（overlay 不收滑鼠）：提示開著、而且是暴雪的 item、看得到、暴雪自己沒關它的滑鼠。
--     暴雪 item 自己的 OnEnter 在安全環境裡跑：增益在身上時畫**光環本身**（SetUnitAuraByAuraInstanceID，有剩餘時間；
--     戰鬥中光環受限時 auraInstanceID 在我們這邊是秘密值、下面的 ShowAuraTip 畫不了），不在時畫飾品增益說明／法術提示
--     ——跟官方檢視器一模一樣。玩家 2026-10-16 回報 1.6.0「戰鬥外對了、戰鬥中還是描述」：overlay 一律搶走滑鼠、
--     永遠走 ShowTip，而 ShowTip 的光環路線戰鬥中拿到的是秘密 ID。
--   * **overlay 自己收**（ShowTip）：提示關著（什麼都不畫，順便把暴雪自己的提示擋掉，不用碰它的 SetTooltipsShown——
--     那會寫暴雪欄位）；自訂框（沒有暴雪的 OnEnter）；這格看不到（冷卻狀態藏了、整條 alpha 0：暴雪 item 不知道我們
--     把它藏了，會在空位冒提示）；暴雪自己的「顯示提示」關著（item 不收滑鼠，讓了也沒人畫）。
--   可點擊群組的 secure 鈕蓋在最上層時 hover 由它轉來（D.HoverEnter → ShowTip），跟 overlay 的旗標無關。
-- 一律不收點擊（SetMouseClickEnabled(false)），點擊照舊穿到底下。
------------------------------------------------------------
-- 光環在身上時改畫光環本身（照暴雪 RefreshTooltipInternal：aura instance 排在裝備欄／法術提示之前）。
-- 暴雪在安全端掃 player／target 的光環；我們是 tainted，只能走 spellID 路線（C_UnitAuras.GetPlayerAuraBySpellID／
-- GetUnitAuraBySpellID 是 AllowedWhenTainted），拿回來的 auraInstanceID 再交給 SetUnitAuraByAuraInstanceID。
-- 光環受限時（首領戰／M+／PvP）那個 ID 是秘密值、tooltip 那支不收（AllowedWhenUntainted）⇒ 先擋、退回原本的提示。
-- 這一格要問哪些法術（TipAuraIDs）照暴雪 GetAssociatedAuraSpellPriority 的順序：linkedSpellIDs → overrideTooltipSpellID →
-- overrideSpellID → spellID；飾品的增益格是那個增益的法術（Catalog.SlotBuffIDs）、飾品冷卻格是使用效果的增益
-- （SlotUseBuffIDs）、自訂物品是用掉之後的增益（ItemUseBuffIDs）。自訂法術不問（冷卻格，照舊畫法術）。
-- 2026-10-16 玩家回報「飾品增益的提示是效果說明、不是增益本身」
local TIP_AURA_UNITS = { "player", "target" }
local TIP_NO_IDS = {}
local function TipAuraIDs(rec)
    local C = ns.Catalog
    local out = {}
    local function Add(v) if type(v) == "number" and v > 0 then out[#out + 1] = v end end
    local function AddAll(list) for _, v in ipairs(type(list) == "table" and list or TIP_NO_IDS) do Add(v) end end
    if rec.custom then
        local sb = rec.slotBuff
        if type(sb) == "table" and type(sb.slot) == "number" and C.SlotBuffIDs then
            AddAll((C.SlotBuffIDs(sb.slot, sb.buff or 1)))
        elseif rec.kind == "slot" and rec.slot and C.SlotUseBuffIDs then
            AddAll((C.SlotUseBuffIDs(rec.slot)))
        elseif rec.kind == "item" and rec.itemID and C.ItemUseBuffIDs then
            AddAll((C.ItemUseBuffIDs({ rec.itemID })))
        end
        return out
    end
    local slot, buff = C.EquipTrackedOf(rec.cooldownID)
    if slot then
        if buff then
            AddAll((C.SlotBuffIDs(slot, buff)))
        else
            for _, n in ipairs(C.SlotBuffIndices(slot)) do AddAll((C.SlotBuffIDs(slot, n))) end
        end
        return out
    end
    local info = C.Info(rec.cooldownID)
    if info then
        AddAll(info.linkedSpellIDs)
        Add(info.overrideTooltipSpellID)
        Add(info.overrideSpellID)
        Add(info.spellID)
    end
    return out
end
D.TipAuraIDs = TipAuraIDs           -- 測試用

local function ShowAuraTip(tooltip, ids)
    local UA = C_UnitAuras
    if not (UA and tooltip.SetUnitAuraByAuraInstanceID) or #ids == 0 then return false end
    for _, unit in ipairs(TIP_AURA_UNITS) do
        local api = unit == "player" and UA.GetPlayerAuraBySpellID or UA.GetUnitAuraBySpellID
        for _, id in ipairs(ids) do
            local ok, aura
            if unit == "player" then ok, aura = pcall(api, id) else ok, aura = pcall(api, unit, id) end
            if ok and type(aura) == "table" then
                local aid = aura.auraInstanceID
                -- 秘密值先擋（連跟 nil 比都會拋錯）：受限時退回原本的提示
                if not ns.IsSecret(aid) and type(aid) == "number"
                    and pcall(tooltip.SetUnitAuraByAuraInstanceID, tooltip, unit, aid, "INCLUDE_NAME_PLATE_ONLY") then
                    return true
                end
            end
        end
    end
    return false
end

local function ShowTip(ov)
    local rec = ov.rec
    if not (rec and GameTooltip) then return end
    -- 冷卻狀態把這格藏起來了（明文判得出來的才算；秘密值路徑不知道，照舊顯示）：看不到的格不冒提示
    if rec.stateHidden then return end
    -- 整條被顯示條件藏起來（例如「只在戰鬥中」的脫戰時）：條是 SetAlpha(0) 不是 Hide，overlay 照樣收得到滑鼠 ⇒
    -- 要自己擋。淡出（alpha > 0）照舊顯示；編輯模式 Visibility 回全亮，不受影響
    if rec.claimKey and CurrentBarAlpha(rec.claimKey) <= 0 then return end
    -- 定位走預設錨點（跟暴雪 item 自己的 OnEnter 一樣：CooldownViewerItemDataMixin:SetTooltipAnchor）：
    -- 提示插件（MiliUI_Tooltip 等）掛在 GameTooltip_SetDefaultAnchor 上改位置，寫死 ANCHOR_RIGHT 會繞過它們
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, ov)
    else
        GameTooltip:SetOwner(ov, "ANCHOR_RIGHT")
    end
    local shown = false
    -- 飾品的增益（暴雪的裝備欄追蹤項目、自訂飾品欄增益）：照暴雪 RefreshTooltipInternal 的「增益不在身上」那一支
    -- （DisplayEquipSlotTrackedTooltip：飾品名＋每個連帶增益一段），走共用的 Catalog.SlotBuffTooltip。
    -- 增益在身上時要畫光環本身：暴雪 item 讓得了就讓它自己畫（D.TipPass，戰鬥中光環受限也畫得出來）。
    -- 走到這裡是讓不了的情況（自訂框、可點擊群組、暴雪關了 item 的滑鼠）：ShowAuraTip 走 spellID 路線拿 auraInstanceID
    -- （上面），受限時那個 ID 是秘密值 ⇒ 只能退回說明。
    -- 法術資料還沒載入：SlotBuffTooltip 先畫標題，載完在提示還開著、擁有者還是這顆 overlay、中間沒被蓋過時叫 refresh
    -- ⇒ 重跑一次 ShowTip（那時資料已經在快取，不會再等，不會無限重入）
    local function Refresh() if ov.tipOn then ShowTip(ov) end end
    -- 光環在身上：畫光環本身（剩餘時間跟著跑），拿不到才退回下面的裝備欄／法術提示
    if ShowAuraTip(GameTooltip, TipAuraIDs(rec)) then
        shown = true
    elseif rec.custom then
        local sb = rec.slotBuff
        if type(sb) == "table" and type(sb.slot) == "number" then
            ns.Catalog.SlotBuffTooltip(GameTooltip, sb.slot, sb.buff, Refresh)
            shown = true
        elseif rec.kind == "slot" and rec.slot then
            shown = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", rec.slot)
        elseif rec.kind == "item" and rec.itemID then
            shown = pcall(GameTooltip.SetItemByID, GameTooltip, rec.itemID)
        elseif rec.timerKey then
            -- 內建冷卻（Modules/Timers.lua）：畫天賦本身的說明（rec.spellID 刻意是 nil）
            local def = ns.Timers and ns.Timers.Def and ns.Timers.Def(rec.timerKey)
            if def then shown = pcall(GameTooltip.SetSpellByID, GameTooltip, def.talent) end
        elseif rec.spellID then
            shown = pcall(GameTooltip.SetSpellByID, GameTooltip, rec.overrideID or rec.spellID)
        end
    else
        local C = ns.Catalog
        -- 先判裝備欄追蹤（暴雪也是先走裝備欄那條、再看 spellID）；飾品的冷卻格（EquipSlotEssential）不算，照舊畫物品
        local slot, buff = C.EquipTrackedOf(rec.cooldownID)
        local info = C.Info(rec.cooldownID)
        local spellID = info and (info.overrideTooltipSpellID or info.overrideSpellID or info.spellID)
        if slot then
            C.SlotBuffTooltip(GameTooltip, slot, buff, Refresh)
            shown = true
        elseif type(spellID) == "number" then
            shown = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
        elseif info and type(info.equipSlot) == "number" then
            shown = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", info.equipSlot)
        end
    end
    if shown then GameTooltip:Show() else GameTooltip:Hide() end
end

local function HideTip(ov)
    if GameTooltip and GameTooltip:IsOwned(ov) then GameTooltip:Hide() end
end

-- overlay 要不要把滑鼠讓給暴雪 item（判準見這一節的檔頭）。visible：這格看不看得到（nil ＝ 不知道，當看得到）。
-- 一開始（ApplyTooltip）與每次 ApplyItemAlpha（條的 alpha、冷卻狀態變了）都重判。
-- 讀暴雪 item 的 IsMouseMotionEnabled 是讀不是寫；overlay 是我們自己的框，旗標隨時能改
function D.TipPass(ov, visible)
    local rec = ov and ov.rec
    if not rec then return end
    local pass = ov.tipOn == true and not rec.custom and not rec.stateHidden and visible ~= false
    if pass then
        local item = ov:GetParent()
        local ok, motion = pcall(function() return item and item.IsMouseMotionEnabled and item:IsMouseMotionEnabled() end)
        pass = ok and motion == true
    end
    pcall(ov.SetMouseMotionEnabled, ov, not pass)
    ov.tipPassed = pass                    -- 測試／除錯用
end

local function ApplyTooltip(ov, rec, on)
    ov.rec = rec
    if not ov.tipWired then
        ov.tipWired = true
        ov:SetScript("OnEnter", function(self) if self.tipOn then ShowTip(self) end end)
        ov:SetScript("OnLeave", HideTip)
    end
    ov.tipOn = on
    D.TipPass(ov, not rec.stateHidden and (not rec.claimKey or CurrentBarAlpha(rec.claimKey) > 0))
    pcall(ov.SetMouseClickEnabled, ov, false)
end
D.ApplyTooltip = ApplyTooltip

-- 可點擊群組的 secure 鈕（Core/Clickable.lua）蓋在格子最上層時，hover 由它收、轉到這裡：
-- 提示照樣錨在 overlay 上（位置跟沒勾一樣），開關照 overlay 的 tipOn。
-- overlay 的滑鼠旗標不動：群組 strata 比檢視器低、item 反過來蓋在鈕上面時，hover 照舊由 overlay 收，
-- 點擊（overlay 不收）穿到底下的鈕。
function D.HoverEnter(rec)
    local ov = rec and rec.overlay
    if ov and ov.tipOn then ShowTip(ov) end
end

function D.HoverLeave(rec)
    local ov = rec and rec.overlay
    if ov then HideTip(ov) end
end
