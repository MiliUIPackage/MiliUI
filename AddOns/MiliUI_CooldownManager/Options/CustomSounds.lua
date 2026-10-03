------------------------------------------------------------
-- 「自訂語音」編輯器（主題頁音效那一節的「自訂語音｜編輯清單（N）」開的彈窗）
--
--   ns.CustomSounds.Open(changedCallback)
--   ns.CustomSounds.Count()
--
-- 一列一筆：上移／下移 ＋ 名稱（下一行灰字是路徑，找不到檔案標紅）＋ 試聽／編輯／刪除；底下「新增語音」。
-- 資料與規則在 Core/Sound.lua（帳號層 customSounds、逐法術存代號 "custom:<id>"）；
-- 這裡排的順序就是逐法術音效下拉裡的順序（自訂語音排在最前面）。
-- 照 Options/StackColors.lua 的彈窗版面做；新增／編輯與刪除確認是疊在這個彈窗上的第二層。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.CustomSounds = {}
local CS = ns.CustomSounds

local POPUP_W   = 520
local LIST_W    = POPUP_W - 32
local ROW_H     = 36
local VISIBLE   = 7
local PAD       = 16
local ARROW_TEX = "Interface\\ChatFrame\\ChatFrameExpandArrow"

local popup, list, hint, empty
local editPopup, delPopup, pendingDelete
local onChanged

local function S() return ns.Sound end

local Refresh   -- 前向宣告

local function Changed()
    Refresh()
    if onChanged then onChanged() end
end

-- 第二層彈窗（編輯、刪除確認）要壓在這個彈窗上面：預設層級跟這個彈窗一樣是 410／400
local function RaiseAbove(p)
    p:SetFrameLevel(430)
    if p.mask then p.mask:SetFrameLevel(420) end
end

------------------------------------------------------------
-- 新增／編輯
------------------------------------------------------------
local function EnsureEditPopup()
    if editPopup then return editPopup end
    editPopup = W.CreateInputPopup(ns.Options.panel, 460, L["Add sound"], {
        { key = "name", label = L["Name"], maxLetters = 60 },
        { key = "path", label = L["File path"], maxLetters = 260,
          hint = L["The path after the Interface folder, e.g. AddOns\\MyVoice\\kick.ogg or Sounds\\kick.ogg. Only .ogg and .mp3 files play."] },
    })
    RaiseAbove(editPopup)
    return editPopup
end

local WHY = {
    empty = L["Enter the file path."],
    ext   = L["Only .ogg and .mp3 files can be played."],
}

-- index 為 nil ＝ 新增
local function OpenEditor(index)
    local e = index and S().CustomList()[index]
    EnsureEditPopup():Open(e and { name = e.name, path = e.path } or nil, function(values)
        local ok, why
        if index then
            ok, why = S().CustomEdit(index, values.name, values.path)
        else
            ok, why = S().CustomAdd(values.name, values.path)
        end
        if not ok then
            ns.Print(WHY[why] or WHY.empty)
            return false                        -- 不關窗，讓玩家改
        end
        Changed()
    end, index and L["Edit sound"] or L["Add sound"])
end

local function EnsureDelPopup()
    if delPopup then return delPopup end
    delPopup = W.CreateConfirmPopup(ns.Options.panel, 340, "", function()
        if pendingDelete then
            S().CustomRemove(pendingDelete)
            pendingDelete = nil
            Changed()
        end
    end)
    RaiseAbove(delPopup)
    return delPopup
end

------------------------------------------------------------
-- 一列
-- ⚠ 列會回收再用：handler 一律讀 row.index（Update 時才填），不把索引抓進 closure
------------------------------------------------------------
local function ArrowButton(row, up)
    local b = W.CreateButton(row, "", "normal", 20, 18)
    local t = b:CreateTexture(nil, "OVERLAY")
    t:SetTexture(ARROW_TEX)
    t:SetRotation(math.rad(up and 90 or -90))
    t:SetSize(12, 12)
    t:SetPoint("CENTER")
    t:SetDesaturated(true)
    b.arrow = t
    return b
end

local function SetArrowEnabled(b, on)
    b:SetEnabled(on)
    b.arrow:SetAlpha(on and 1 or 0.3)
end

local function BuildRow(row)
    row.up = ArrowButton(row, true)
    row.up:SetPoint("LEFT", 6, 0)
    row.up:SetScript("OnClick", function()
        if row.index and S().CustomMove(row.index, -1) then Changed() end
    end)
    row.down = ArrowButton(row, false)
    row.down:SetPoint("LEFT", row.up, "RIGHT", 2, 0)
    row.down:SetScript("OnClick", function()
        if row.index and S().CustomMove(row.index, 1) then Changed() end
    end)

    row.del = W.CreateButton(row, "X", "red", 20, 18)
    row.del:SetPoint("RIGHT", -6, 0)
    row.del:SetScript("OnClick", function()
        local e = row.index and S().CustomList()[row.index]
        if not e then return end
        pendingDelete = row.index
        local p = EnsureDelPopup()
        p.text:SetText(L["Delete the sound \"%s\"? Spells using it go back to no sound."]:format(e.name or ""))
        p:Show()
    end)

    row.edit = W.CreateButton(row, L["Edit"], "normal", 44, 18)
    W.FitButton(row.edit, 44, 18)
    row.edit:SetPoint("RIGHT", row.del, "LEFT", -4, 0)
    row.edit:SetScript("OnClick", function()
        if row.index then OpenEditor(row.index) end
    end)

    row.listen = W.CreateButton(row, L["Listen"], "normal", 44, 18)
    W.FitButton(row.listen, 44, 18)
    row.listen:SetPoint("RIGHT", row.edit, "LEFT", -4, 0)
    row.listen:SetScript("OnClick", function()
        local e = row.index and S().CustomList()[row.index]
        if e then S().Preview(S().Logic.CustomValue(e.id)) end
    end)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(W.fontNormal)
    row.name:SetPoint("TOPLEFT", row.down, "TOPRIGHT", 8, 6)
    row.name:SetPoint("RIGHT", row.listen, "LEFT", -8, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.path = row:CreateFontString(nil, "OVERLAY")
    row.path:SetFontObject(W.fontSmall)
    row.path:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.path:SetPoint("RIGHT", row.listen, "LEFT", -8, 0)
    row.path:SetJustifyH("LEFT")
    row.path:SetWordWrap(false)
end

local function UpdateRow(row, e, index)
    row.index = index
    row.name:SetText(e.name or "")
    local known = S().CustomFileKnown(e)
    if known == false then
        row.path:SetText(L["%s (file not found)"]:format(e.path or ""))
        row.path:SetTextColor(1, 0.3, 0.3)
    else
        row.path:SetText(e.path or "")
        row.path:SetTextColor(0.6, 0.6, 0.6)
    end
    local n = #S().CustomList()
    SetArrowEnabled(row.up, index > 1)
    SetArrowEnabled(row.down, index < n)
end

Refresh = function()
    if not (popup and popup:IsShown()) then return end
    local items = S().CustomList()
    list:Update(items, UpdateRow)
    empty:SetShown(#items == 0)
end

------------------------------------------------------------
-- 視窗
------------------------------------------------------------
local function CreatePopup()
    if popup then return end
    local parent = ns.Options and ns.Options.panel
    if not parent then return end

    popup = W.CreateFrame(nil, parent, POPUP_W, 300)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup:Hide()
    W.CloseOnEscape(popup)

    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function()
        mask:Hide()
        if editPopup then editPopup:Hide() end
        if delPopup then delPopup:Hide() end
    end)

    popup.title = popup:CreateFontString(nil, "OVERLAY")
    popup.title:SetFontObject(W.fontTitle)
    popup.title:SetPoint("TOP", 0, -12)
    popup.title:SetText(L["Custom sounds"])

    hint = popup:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetTextColor(0.6, 0.6, 0.6)
    hint:SetPoint("TOPLEFT", PAD, -34)
    hint:SetWidth(POPUP_W - PAD * 2)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetSpacing(2)
    hint:SetText(L["Put .ogg or .mp3 files in any folder under Interface (a folder inside AddOns works too) and enter the path after Interface. The game only sees files that were there when it started: after adding one, restart the game (/reload isn't enough). These sounds are listed first in every spell's sound menu, in this order."])

    list = W.CreateRowList(popup, LIST_W, ROW_H * VISIBLE + 4, ROW_H, BuildRow)

    empty = popup:CreateFontString(nil, "OVERLAY")
    empty:SetFontObject(W.fontSmall)
    empty:SetTextColor(0.6, 0.6, 0.6)
    empty:SetPoint("TOP", list, "TOP", 0, -24)
    empty:SetText(L["No custom sounds yet."])

    local addBtn = W.CreateButton(popup, L["Add sound"], "normal", 120, 22)
    W.FitButton(addBtn, 120, 22)
    addBtn:SetPoint("BOTTOMLEFT", PAD, 12)
    addBtn:SetScript("OnClick", function() OpenEditor(nil) end)

    local close = W.CreateButton(popup, L["Okay"], "primary", 100, 22)
    close:SetPoint("BOTTOMRIGHT", -PAD, 12)
    close:SetScript("OnClick", function() popup:Hide() end)

    ns.RegisterCallback("OptionsHidden", "customsounds", function() popup:Hide() end)
end

-- 說明字換行後的高度量得到時（顯示之後）才排清單與視窗高度
local function Relayout()
    local hh = hint:GetStringHeight()
    hh = (type(hh) == "number" and hh > 0) and hh or 42
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", PAD, -34 - hh - 10)
    ns.P.Height(popup, 34 + hh + 10 + ROW_H * VISIBLE + 4 + 12 + 22 + 12)
end

-- changedCallback：增刪改排序時叫（主題頁那顆按鈕的筆數）
function CS.Open(changedCallback)
    CreatePopup()
    if not popup then return end
    onChanged = changedCallback
    popup:Show()
    Relayout()
    Refresh()
end

function CS.Close()
    if popup then popup:Hide() end
end

function CS.Count()
    return #ns.Sound.CustomList()
end
