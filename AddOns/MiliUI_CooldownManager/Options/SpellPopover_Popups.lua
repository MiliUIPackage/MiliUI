------------------------------------------------------------
-- 逐法術面板的彈窗：複製到其他專精、自訂圖示的輸入
-- （從 Options/SpellPopover.lua 切出，2026-10-18；TOC 緊接在 SpellPopover_Tabs.lua 之後載入）
--
-- 共用的常數與幫手掛在 ns.SpellPopover 上，這裡取回成 local；目前那一格讀 Pop.cur。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P
local Pop = ns.SpellPopover

local PAD = Pop.PAD
local Note, Changed = Pop.Note, Pop.Changed

------------------------------------------------------------
-- 複製到其他專精（自訂項目）：每個其他專精一個勾選框，已有的勾著並停用、標「已有」；
-- 確定後逐個 DB.CopyCustomEntry（連同覆寫），彈窗關掉即可，不印聊天框
------------------------------------------------------------
local COPY_W = 320
local copyPopup

local function BuildCopyPopup()
    local f = W.CreateFrame(nil, ns.Options.panel, COPY_W, 160)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(410)
    f:SetBackdropBorderColor(W.Accent(1))
    f:SetPoint("CENTER")
    W.CloseOnEscape(f)
    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFontObject(W.fontNormal)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(true)
    f.title:SetWidth(COPY_W - PAD * 2)
    f.title:SetPoint("TOPLEFT", PAD, -12)
    f.note = Note(f)
    f.note:SetWidth(COPY_W - PAD * 2)
    f.note:SetWordWrap(true)
    f.boxes = {}
    f.ok = W.CreateButton(f, L["Copy"], "primary", 90, 22)
    W.FitButton(f.ok, 90, 22)
    f.cancel = W.CreateButton(f, L["Cancel"], "normal", 90, 22)
    W.FitButton(f.cancel, 90, 22)
    f.cancel:SetPoint("BOTTOMRIGHT", -PAD, 12)
    f.ok:SetPoint("RIGHT", f.cancel, "LEFT", -6, 0)
    f.cancel:SetScript("OnClick", function() f:Hide() end)
    f.ok:SetScript("OnClick", function()
        local id = f.id
        for _, cb in ipairs(f.boxes) do
            if cb:IsShown() and cb.specID and not cb.exists and cb:GetChecked() then
                ns.DB.CopyCustomEntry(id, cb.specID)
            end
        end
        f:Hide()
    end)
    f:Hide()
    ns.RegisterCallback("OptionsHidden", "popover_copy", function() f:Hide() end)
    ns.RegisterCallback("SpecChanged", "popover_copy", function() f:Hide() end)
    ns.RegisterCallback("ProfileChanged", "popover_copy", function() f:Hide() end)
    return f
end

-- 「複製」只有在至少勾了一個還沒有的專精時能按
local function SyncCopyOK(f)
    local any = false
    for _, cb in ipairs(f.boxes) do
        if cb:IsShown() and not cb.exists and cb:GetChecked() then any = true break end
    end
    f.ok:SetEnabled(any)
end

local function CopyBox(f, i)
    local cb = f.boxes[i]
    if cb then return cb end
    cb = W.CreateCheckButton(f, "", function() SyncCopyOK(f) end)
    f.boxes[i] = cb
    return cb
end

function Pop.AskCopy(id)
    local e = ns.DB.CustomEntry(id)
    if not e then return end
    copyPopup = copyPopup or BuildCopyPopup()
    local f = copyPopup
    f.id = id
    local info = ns.Catalog.Info(id)
    f.title:SetText(L["Copy \"%s\" to these specializations:"]:format((info and info.name) or ("#" .. tostring(id))))
    local y = -(12 + (f.title:GetStringHeight() or 14) + 10)
    local n = 0
    for _, spec in ipairs(ns.DB.ClassSpecs()) do
        if spec.id ~= ns.specID then
            n = n + 1
            local cb = CopyBox(f, n)
            local exists = ns.DB.FindCustomLike(e, spec.id) ~= nil
            cb.specID, cb.exists = spec.id, exists
            cb.label:SetText(exists and (spec.name .. "  " .. L["(already there)"]) or spec.name)
            cb:SetHitRectInsets(0, -((cb.label:GetStringWidth() or 0) + 8), 0, 0)   -- 點標籤也能勾
            cb:SetChecked(true)                      -- 已有的勾著（停用）；其餘預設勾，不要的自己取消
            cb:SetEnabled(not exists)
            cb:SetAlpha(exists and 0.5 or 1)
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
            cb:Show()
            y = y - 18 - 8
        end
    end
    for i = n + 1, #f.boxes do f.boxes[i]:Hide() end
    f.note:SetShown(n == 0)
    if n == 0 then
        f.note:SetText(L["Couldn't read your specializations."])
        f.note:ClearAllPoints()
        f.note:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        y = y - (f.note:GetStringHeight() or 14) - 8
    end
    SyncCopyOK(f)
    P.Height(f, -y + 22 + 12 + 6)
    f:Show()
end

------------------------------------------------------------
-- 自訂圖示的輸入彈窗：圖示編號（貼圖檔案編號）；Shift 點法術書／天賦／背包裡的法術或物品 ⇒ 填它的圖示
-- （Picker.WatchInput 的 "icon" 模式，同一個連結掛勾）
------------------------------------------------------------
local iconPopup

function Pop.AskIcon(id)
    local Picker = ns.Picker
    if not iconPopup then
        iconPopup = W.CreateInputPopup(ns.Options.panel, Picker.INPUT_W, L["Custom icon"], {
            { key = "id", label = L["Icon ID"], maxLetters = 10,
              hint = L["The icon's file ID, from a database site. Or Shift-click a spell or an item in your spellbook, talents or bags to use its icon."] },
        })
        Picker.AddSpellsOpener(iconPopup)
    end
    Picker.SetInputError(iconPopup, nil)
    Picker.WatchInput(iconPopup, "icon")
    local now = ns.SpellSetting(nil, id, "customIcon")
    iconPopup:Open({ id = ns.Decorate.ValidIcon(now) and tostring(now) or nil }, function(values)
        local n = Picker.ParseID(values.id)
        if not n then
            Picker.SetInputError(iconPopup, L["Enter a number."])
            return false
        end
        Picker.SetInputError(iconPopup, nil)
        ns.DB.SetOverride(id, "customIcon", n)
        if Pop.cur then Changed() end
    end, L["Custom icon"])
end
