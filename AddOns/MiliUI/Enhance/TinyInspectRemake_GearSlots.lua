
---------------------------------------------------------------
-- MiliUI Enhance: TinyInspect-Remake Gear Slots
-- PaperDoll / Inspect 裝備格上的物品等級文字使用粗外框
-- 並修正 EquipmentFlyout 「忽略此欄位」/「移除」特殊按鈕
-- 殘留前一項物品的裝等與部位文字 (TinyInspect-Remake 未清除)
-- Author: Mili
---------------------------------------------------------------

local LEVEL_FONT_SIZE_ADJUST = 0
local LEVEL_FONT_OUTLINE_OVERRIDE = "THICKOUTLINE"

local SLOT_BASE_NAMES = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist",
    "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1",
    "Trinket0", "Trinket1", "MainHand", "SecondaryHand",
}
local SLOT_PREFIXES = { "Character", "Inspect" }

local function AdjustLevelString(frame)
    if (not frame or not frame.levelString or frame.MiliUILevelAdjusted) then return end
    local path, size, flags = frame.levelString:GetFont()
    if (not path or not size) then return end
    local newSize = size + LEVEL_FONT_SIZE_ADJUST
    local newFlags = LEVEL_FONT_OUTLINE_OVERRIDE or flags or "OUTLINE"
    frame.levelString:SetFont(path, newSize, newFlags)
    frame.MiliUILevelAdjusted = true
end

local FIRST_SPECIAL_LOCATION = EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION or 0xFFFFFFFD

local function ClearTinyInspectStrings(button)
    local frame = button and button.ItemLevelFrame
    if (not frame) then return end
    if (frame.levelString) then frame.levelString:SetText("") end
    if (frame.slotString)  then frame.slotString:SetText("")  end
    button.OrigItemLink = nil
    button.OrigItemLevel = ""
    button.OrigItemQuality = nil
    button.OrigItemClass = nil
    button.OrigItemEquipSlot = nil
    button.PendingItemLevelLink = nil
end

local function HookEquipmentFlyout()
    if (not EquipmentFlyout_DisplayButton) then return end
    hooksecurefunc("EquipmentFlyout_DisplayButton", function(button)
        local location = button and button.location
        if (location and location >= FIRST_SPECIAL_LOCATION) then
            ClearTinyInspectStrings(button)
        end
    end)
end

local function Setup()
    if (not C_AddOns or not C_AddOns.IsAddOnLoaded or not C_AddOns.IsAddOnLoaded("TinyInspect-Remake")) then
        return
    end
    local LibEvent = _G.LibStub and _G.LibStub:GetLibrary("LibEvent.7000", true)
    if (not LibEvent) then return end

    LibEvent:attachTrigger("ITEMLEVEL_FRAME_CREATED", function(self, frame, parent)
        AdjustLevelString(frame)
    end)

    for _, base in ipairs(SLOT_BASE_NAMES) do
        for _, prefix in ipairs(SLOT_PREFIXES) do
            local slot = _G[prefix .. base .. "Slot"]
            if (slot and slot.ItemLevelFrame) then
                AdjustLevelString(slot.ItemLevelFrame)
            end
        end
    end

    HookEquipmentFlyout()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", Setup)
