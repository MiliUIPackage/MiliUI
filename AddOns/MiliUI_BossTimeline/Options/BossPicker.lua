------------------------------------------------------------
-- 選首領：資料片 → 副本 → 首領（冒險指南），自訂時間軸與首領技能兩個分頁共用
--
--   BossPicker.Open(onPick)   onPick(encounterID, name)
-- 預設停在「現在所在的副本」；不在副本裡就停在最新的資料片。
-- 冒險指南沒收的（世界首領的活動版、測試用）走底下的「手動輸入 ID」。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local J = ns.Journal

ns.BossPicker = {}
local BP = ns.BossPicker

local POP_W, POP_H = 420, 236
local popup, tierDD, instDD, bossDD, idPopup, onPick
local sel = {}

local function Label(text, y)
    local fs = popup:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    return fs
end

local function InstanceItems(tier)
    local items = {}
    for _, inst in ipairs(J.Instances(tier)) do
        items[#items + 1] = {
            text = (inst.isRaid and ("|cffff7f00" .. L["Raid"] .. "|r  ") or ("|cff66ccff" .. L["Dungeon"] .. "|r  ")) .. inst.text,
            value = inst.value,
        }
    end
    return items
end

local function SetBosses(instanceID)
    sel.instance = instanceID
    local items = J.Encounters(instanceID)
    bossDD:SetItems(items)
    sel.boss = items[1] and items[1].value
    sel.bossName = items[1] and items[1].text
    bossDD:SetSelectedValue(sel.boss)
end

local function SetInstances(tier, preferInstance)
    sel.tier = tier
    local items = InstanceItems(tier)
    instDD:SetItems(items)
    local pick = items[1] and items[1].value
    for _, it in ipairs(items) do
        if it.value == preferInstance then pick = it.value end
    end
    instDD:SetSelectedValue(pick)
    SetBosses(pick)
end

local function Build()
    local parent = ns.Options.panel
    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()

    popup = W.CreateFrame("MiliUIBT_BossPicker", parent, POP_W, POP_H)
    W.CloseOnEscape(popup)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function()
        mask:Hide()
        W.CloseDropdowns()
    end)

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Pick a boss"])

    Label(L["Expansion"], -48)
    tierDD = W.CreateDropdown(popup, 280, {}, function(v) SetInstances(v) end)
    tierDD:SetPoint("TOPLEFT", 110, -46)
    Label(L["Instance"], -80)
    instDD = W.CreateDropdown(popup, 280, {}, function(v) SetBosses(v) end)
    instDD:SetPoint("TOPLEFT", 110, -78)
    Label(L["Boss"], -112)
    bossDD = W.CreateDropdown(popup, 280, {}, function(v)
        sel.boss = v
        for _, it in ipairs(bossDD.items or {}) do
            if it.value == v then sel.bossName = it.text end
        end
    end)
    bossDD:SetPoint("TOPLEFT", 110, -110)

    local hint = popup:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("TOPLEFT", 16, -142)
    hint:SetWidth(POP_W - 32)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["From the Adventure Guide. Starts at the instance you're in."])

    -- 手動輸入 ID（冒險指南沒收的首領）
    idPopup = W.CreateInputPopup(parent, 380, L["Enter an encounter ID"], {
        { key = "id",   label = L["Encounter ID"],
          hint = L["The ID from the boss fight itself, not the Adventure Guide. After one pull the last boss you fought is filled in for you."] },
        { key = "name", label = L["Name"] },
    })
    local manual = W.CreateButton(popup, L["Enter an ID instead"], "normal", 110, 20)
    W.FitButton(manual, 110, 20)
    manual:SetPoint("TOPLEFT", 16, -164)
    manual:SetScript("OnClick", function()
        popup:Hide()
        local last = ns.db.lastEncounter
        idPopup:Open({ id = last and last.id or "", name = last and last.name or "" }, function(v)
            local id = tonumber(v.id)
            if not id or id <= 0 then
                ns.Print(L["Encounter ID must be a number."])
                return false
            end
            if onPick then onPick(id, v.name ~= "" and v.name or J.NameFor(id)) end
        end)
    end)

    local ok = W.CreateButton(popup, L["Okay"], "green", 80, 22)
    ok:SetPoint("BOTTOMLEFT", 26, 12)
    ok:SetScript("OnClick", function()
        if not sel.boss then return end
        popup:Hide()
        if onPick then onPick(sel.boss, sel.bossName) end
    end)
    local cancel = W.CreateButton(popup, L["Cancel"], "red", 80, 22)
    cancel:SetPoint("BOTTOMRIGHT", -26, 12)
    cancel:SetScript("OnClick", function() popup:Hide() end)
    popup:Hide()
end

function BP.Open(callback)
    if not popup then Build() end
    onPick = callback
    local tiers = J.Tiers()
    tierDD:SetItems(tiers)
    local cur = J.CurrentInstance()
    local tier = (cur and J.TierOf(cur)) or (tiers[1] and tiers[1].value)
    tierDD:SetSelectedValue(tier)
    if tier then SetInstances(tier, cur) end
    popup:Show()
end
