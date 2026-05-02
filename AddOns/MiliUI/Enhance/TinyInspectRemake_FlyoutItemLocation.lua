------------------------------------------------------------
-- MiliUI: 共用 EquipmentFlyout 按鈕裝等顯示補丁
--
-- 這些 UI 共用 EquipmentFlyoutFrameButtonN：
--   - 裝備管理員 (Equipment Manager): Blizzard 用 button.location 數字編碼
--   - 物品升級 (ItemUpgradeFrame): Blizzard 用 SetItemLocation/itemLocation
--   - 催化器・育籃 (ItemInteractionFrame): 同上
--
-- TinyInspect-Remake 透過 EquipmentFlyout_DisplayButton hook 處理 EM,
-- 但對 itemLocation table 型別與升級/育籃 UI 完全失效。
--
-- 共用按鈕導致狀態殘留：開過 EM 後 button.location (number) 仍在，
-- 開過育籃後 GetItemLocation()/itemLocation 仍在。所以要依當下哪個
-- UI 開著決定優先使用哪個 location 來源。
--
-- 自己建 ItemLevelFrame (schema 與 TinyInspect 相容)，並透過
-- LibEvent trigger ITEMLEVEL_FRAME_CREATED/SHOWN 讓 TrackColors 等
-- 模組接得上。
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

local DEBUG = false
local function dprint(...)
    if (not DEBUG) then return end
    print("|cff66ccff[MiliUI/FlyoutFix]|r", ...)
end

local LibEvent
local function GetLibEvent()
    if (LibEvent) then return LibEvent end
    if (LibStub and LibStub.GetLibrary) then
        local ok, lib = pcall(LibStub.GetLibrary, LibStub, "LibEvent.7000", true)
        if (ok and lib) then
            LibEvent = lib
            return LibEvent
        end
    end
end

------------------------------------------------------------
-- ItemLevelFrame (與 TinyInspect-Remake 結構一致)
------------------------------------------------------------
local function EnsureItemLevelFrame(button)
    if (button.ItemLevelFrame) then return button.ItemLevelFrame, false end

    local fontAdjust = GetLocale():sub(1,2) == "zh" and 0 or -3
    local anchor = button.IconBorder or button
    local w, h = button:GetSize()
    if (not w or w <= 0) then w = 32 end
    if (not h or h <= 0) then h = 32 end

    local frame = CreateFrame("Frame", nil, button)
    frame:SetScale(max(0.75, h<32 and h/32 or 1))
    frame:SetFrameLevel(110)
    frame:SetSize(w, h)
    frame:SetPoint("CENTER", anchor, "CENTER", 0, 0)

    frame.slotString = frame:CreateFontString(nil, "OVERLAY")
    frame.slotString:SetFont(STANDARD_TEXT_FONT, 10+fontAdjust, "OUTLINE")
    frame.slotString:SetPoint("BOTTOMRIGHT", 1, 2)
    frame.slotString:SetTextColor(1, 1, 1)
    frame.slotString:SetJustifyH("RIGHT")
    frame.slotString:SetWidth(30)
    frame.slotString:SetHeight(0)

    frame.levelString = frame:CreateFontString(nil, "OVERLAY")
    frame.levelString:SetFont(STANDARD_TEXT_FONT, 14+fontAdjust, "OUTLINE")
    frame.levelString:SetPoint("TOP")
    frame.levelString:SetTextColor(1, 0.82, 0)

    button.ItemLevelFrame = frame
    -- 標記成 AltEquipment category，讓 TinyInspect 的 SetItemButtonQuality
    -- hook 早退，不會清掉我們寫入的內容（避免裝備管理員 player slot 閃爍）。
    button.ItemLevelCategory = "AltEquipment"

    -- 通知 TinyInspect 的依賴模組 (TrackColors 等)
    local le = GetLibEvent()
    if (le) then
        pcall(le.trigger, le, "ITEMLEVEL_FRAME_CREATED", frame, button)
    end

    return frame, true
end

local function ApplyLevel(button, level, quality, equipSlot, link)
    local frame = button.ItemLevelFrame
    if (not frame) then return end

    -- 與上次寫入相同就跳過，避免輪詢造成閃爍
    if (button.MiliUILastLink == link and button.MiliUILastLevel == level) then
        return
    end
    button.MiliUILastLink = link
    button.MiliUILastLevel = level

    -- 讓 TrackColors 透過 button.OrigItemLink 找回 link
    button.OrigItemLink = link
    button.OrigItemLevel = level
    button.OrigItemQuality = quality
    button.OrigItemEquipSlot = equipSlot

    -- 重要：在 SetText 之前 trigger ITEMLEVEL_FRAME_SHOWN，讓 TrackColors
    -- 把 hook 掛上去 (HookLevelStringSetText)，後面的 SetText 才會被攔到上色。
    local le = GetLibEvent()
    if (le) then
        pcall(le.trigger, le, "ITEMLEVEL_FRAME_SHOWN", frame, button, "AltEquipment")
    end

    if (DEBUG) then dprint(button:GetName(), "ApplyLevel WRITE", level, link) end
    if (TinyInspectRemakeDB and TinyInspectRemakeDB.ShowColoredItemLevelString and quality) then
        local _, _, _, hex = GetItemQualityColor(quality)
        frame.levelString:SetText(format("|c%s%s|r", hex, tostring(level)))
    else
        frame.levelString:SetText(tostring(level))
    end
    if ((not TinyInspectRemakeDB or TinyInspectRemakeDB.ShowItemSlotString)
        and equipSlot and equipSlot:find("INVTYPE_")) then
        frame.slotString:SetText(_G[equipSlot] or "")
    else
        frame.slotString:SetText("")
    end
end

local function ClearLevel(button)
    local frame = button.ItemLevelFrame
    if (frame) then
        if (DEBUG and frame.levelString and (frame.levelString:GetText() or "") ~= "") then
            dprint(button:GetName(), "ClearLevel CLEAR (was:", frame.levelString:GetText(), ")")
        end
        if (frame.levelString) then frame.levelString:SetText("") end
        if (frame.slotString) then frame.slotString:SetText("") end
    end
    button.OrigItemLink = nil
    button.OrigItemLevel = nil
    button.OrigItemQuality = nil
    button.OrigItemEquipSlot = nil
    button.MiliUILastLink = nil
    button.MiliUILastLevel = nil
end

------------------------------------------------------------
-- Location 來源優先序 (依目前哪個 UI 開著決定)
------------------------------------------------------------
-- 判斷 EquipmentFlyoutFrame 當下是在服務 EM 還是 modern UI。
-- 不能用 ItemUpgradeFrame:IsShown() 因為兩種 UI 可能同時開著，但
-- EquipmentFlyoutFrame 一次只能 anchor 到一處。
-- EM/Inspect 模式下 anchor 到 CharacterXxxSlot/InspectXxxSlot；
-- modern UI 模式下 anchor 到別的（如 ItemInteractionFrame 的 "+" 按鈕），
-- 不一定包含 ItemUpgradeFrame/ItemInteractionFrame 名稱。
-- 因此預設視為 modern，只有偵測到 character/inspect slot 才判定 EM。
local function IsModernContext()
    local fly = _G.EquipmentFlyoutFrame
    if (not fly or not fly:IsShown()) then return false end
    local p = fly:GetParent()
    for i = 1, 8 do
        if (not p) then break end
        local name = p.GetName and p:GetName() or ""
        -- Midnight: EM 模式 parent = PaperDollFrame；舊版可能是 CharacterXxxSlot
        if (name == "PaperDollFrame"
            or name == "InspectPaperDollFrame"
            or name == "InspectFrame"
            or name:match("^Character%w+Slot$")
            or name:match("^Inspect%w+Slot$")) then
            return false
        end
        p = p.GetParent and p:GetParent() or nil
    end
    return true
end

local function DecodeNumberLocation(loc)
    local Unpack = _G.EquipmentManager_UnpackLocation
        or (C_EquipmentSet and C_EquipmentSet.UnpackLocation)
    if (not Unpack or not ItemLocation) then return end
    local player, bank, bags, voidStorage, slot, bag = Unpack(loc)
    if (voidStorage) then return end
    if (bags) then
        if (bag and slot and ItemLocation.CreateFromBagAndSlot) then
            return ItemLocation:CreateFromBagAndSlot(bag, slot)
        end
    elseif (player or bank) then
        if (slot and ItemLocation.CreateFromEquipmentSlot) then
            return ItemLocation:CreateFromEquipmentSlot(slot)
        end
    end
end

local function GetButtonLocation(button, modernFirst)
    if (modernFirst == nil) then modernFirst = IsModernContext() end

    local function tryModern()
        if (button.GetItemLocation) then
            local ok, loc = pcall(button.GetItemLocation, button)
            if (ok and loc and (not C_Item.DoesItemExist or C_Item.DoesItemExist(loc))) then
                return loc
            end
        end
        if (type(button.itemLocation) == "table") then
            local loc = button.itemLocation
            if (not C_Item.DoesItemExist or C_Item.DoesItemExist(loc)) then return loc end
        end
        if (type(button.location) == "table") then
            local loc = button.location
            if (not C_Item.DoesItemExist or C_Item.DoesItemExist(loc)) then return loc end
        end
    end

    local function tryLegacy()
        if (type(button.location) == "number") then
            local loc = DecodeNumberLocation(button.location)
            if (loc and (not C_Item.DoesItemExist or C_Item.DoesItemExist(loc))) then
                return loc
            end
        end
    end

    if (modernFirst) then
        return tryModern() or tryLegacy()
    else
        return tryLegacy() or tryModern()
    end
end

------------------------------------------------------------
-- 處理單一按鈕
------------------------------------------------------------
local function FixButton(button, modernHint)
    if (not button) then return end
    -- EM 模式下 TinyInspect 自己處理就夠了，雙寫會跟 Blizzard 重繪打架造成閃爍。
    -- 只有在升級/育籃 (modern UI) 開著時才介入。modernHint 由呼叫端傳入，
    -- 避免每個按鈕都重爬一次 parent chain。
    if (modernHint == nil) then modernHint = IsModernContext() end
    if (not modernHint) then return end
    EnsureItemLevelFrame(button)

    local loc = GetButtonLocation(button, modernHint)
    if (not loc) then
        ClearLevel(button)
        return
    end

    local link = C_Item.GetItemLink and C_Item.GetItemLink(loc)
    if (not link) then
        if (Item and Item.CreateFromItemLocation) then
            local item = Item:CreateFromItemLocation(loc)
            item:ContinueOnItemLoad(function() FixButton(button) end)
        end
        return
    end

    local level = C_Item.GetCurrentItemLevel and C_Item.GetCurrentItemLevel(loc)
    if (not level or level <= 0) then
        ClearLevel(button)
        return
    end

    local _, _, quality, _, _, _, _, _, equipSlot = GetItemInfo(link)
    ApplyLevel(button, level, quality, equipSlot, link)
end

------------------------------------------------------------
-- 掃描所有共用按鈕
-- 用 cached button list 避免每次重複拼字串查 _G。
------------------------------------------------------------
local cachedButtons = nil

local function GetButtons()
    if (cachedButtons) then return cachedButtons end
    cachedButtons = {}
    for i = 1, 80 do
        local b = _G["EquipmentFlyoutFrameButton" .. i]
        if (not b) then break end
        cachedButtons[#cachedButtons + 1] = b
    end
    return cachedButtons
end

-- Blizzard 是按需建立按鈕的，新按鈕出現時要重建快取
local function RefreshButtonCache()
    cachedButtons = nil
    return GetButtons()
end

local function ScanAll(clearHidden)
    local modern = IsModernContext()
    -- modern 模式不必開時也不該介入；EM 模式下我們不該寫任何按鈕。
    -- clearHidden 仍要對隱藏按鈕清乾淨（避免共用殘留）。
    local buttons = GetButtons()
    for i = 1, #buttons do
        local b = buttons[i]
        if (b:IsShown()) then
            if (modern) then FixButton(b, true) end
        elseif (clearHidden) then
            ClearLevel(b)
        end
    end
end

local function ClearAll()
    -- 只清自己畫的字串，不要動 Blizzard 的 button.location/itemLocation
    -- (動了會干擾 Blizzard 內部狀態，造成 EM 閃爍)
    -- 跨 UI 殘留問題由 GetButtonLocation 的 modernFirst 優先序解決。
    local buttons = GetButtons()
    for i = 1, #buttons do
        ClearLevel(buttons[i])
    end
end

------------------------------------------------------------
-- 觸發點
-- 換頁等情況不會 OnShow 但內容變了，需要輪詢。
-- pollFrame 的 OnUpdate 只在 flyout 顯示期間掛上，平時不消耗每幀資源。
------------------------------------------------------------
local pollFrame = CreateFrame("Frame")
pollFrame.acc = 0

local function PollUpdate(self, elapsed)
    self.acc = self.acc + elapsed
    if (self.acc < 0.25) then return end
    self.acc = 0
    if (IsModernContext()) then
        ScanAll(false)
    end
end

local function HookFlyoutShow()
    if (not EquipmentFlyoutFrame or EquipmentFlyoutFrame.MiliUIFlyoutHooked) then return end
    EquipmentFlyoutFrame.MiliUIFlyoutHooked = true
    EquipmentFlyoutFrame:HookScript("OnShow", function()
        dprint("OnShow")
        RefreshButtonCache()  -- 新按鈕可能在這次 show 才建立
        C_Timer.After(0, function() ScanAll(true) end)
        C_Timer.After(0.1, function() ScanAll(true) end)
        C_Timer.After(0.3, function() ScanAll(true) end)
        -- 顯示期間才掛 OnUpdate，閒置不消耗
        pollFrame.acc = 0
        pollFrame:SetScript("OnUpdate", PollUpdate)
    end)
    EquipmentFlyoutFrame:HookScript("OnHide", function()
        dprint("OnHide")
        pollFrame:SetScript("OnUpdate", nil)
        ClearAll()
    end)
end

-- EquipmentFlyout_DisplayButton 只會被 EM (裝備管理員) 流程呼叫；modern UI
-- 不走這條。在 TinyInspect 的 hook 之前先清掉 button.itemLocation，避免
-- modern UI 留下的 stale table 讓 TinyInspect 走錯路徑拿到舊資料。
--
-- 重要：hooksecurefunc 依註冊順序，所以這個 hook 必須在「檔案載入」時
-- 註冊（先於 TinyInspect-Remake 在 ItemLevel.lua 頂層註冊的 hook）。
-- 不能放到 PLAYER_LOGIN，那時 TinyInspect 早就註冊了。
if (_G.EquipmentFlyout_DisplayButton) then
    hooksecurefunc("EquipmentFlyout_DisplayButton", function(button)
        if (button) then button.itemLocation = nil end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    self:SetScript("OnEvent", nil)
    HookFlyoutShow()
end)
