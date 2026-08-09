---@class addonTableBaganator
local addonTable = select(2, ...)

-- Modified to remove portrait in top left
local layout = {
  disableSharpening = true,
  TopLeftCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopLeft", x = -13, y = 16, },
  TopRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 4, y = 16, },
  BottomLeftCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -13, y = -3, },
  BottomRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3, },
  TopEdge = { layer="OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", x = 0, y = 0, x1 = 0, y1 = 0, },
  BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0, },
  LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0 },
  RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0, },
}

local showSlots = true
local allItemButtons = {}
local allButtonFrames = {}

local skinners = {
  ItemButton = function(frame, tags)
    if not tags.containerBag then
      frame.SlotBackground:SetShown(showSlots)
      table.insert(allItemButtons, frame)
    end
  end,
  ButtonFrame = function(frame, tags)
    table.insert(allButtonFrames, frame)
    frame.Bg:Hide()
    frame.Bg = CreateFrame("Frame", nil, frame, "FlatPanelBackgroundTemplate")
    frame.Bg:SetFrameStrata("LOW")
    frame.Bg:SetPoint("TOPLEFT", 2, -3)
    frame.Bg:SetPoint("BOTTOMRIGHT", -2, 3)
		NineSliceUtil.ApplyLayout(frame.NineSlice, layout, frame.NineSlice:GetFrameLayoutTextureKit());
  end,
}

local function ConvertTags(tags)
  local res = {}
  for _, tag in ipairs(tags) do
    res[tag] = true
  end
  return res
end

local function SkinFrame(details)
  local func = skinners[details.regionType]
  if func then
    func(details.region, details.tags and ConvertTags(details.tags) or {})
  end
end

local function SetConstants()
  if addonTable.Constants.IsRetail then
    addonTable.Constants.ButtonFrameOffset = 1
  end
  if addonTable.Constants.IsClassic then
    addonTable.Constants.ButtonFrameOffset = 0
  end
end

local function LoadSkin()
  showSlots = not addonTable.Config.Get("skins.blizzard_black.empty_slot_background")

  addonTable.CallbackRegistry:RegisterCallback("SettingChanged", function(_, settingName)
    if settingName == "skins.blizzard_black.empty_slot_background" then
      showSlots = not addonTable.Config.Get("skins.blizzard_black.empty_slot_background")
      for _, button in ipairs(allItemButtons) do
        button.SlotBackground:SetShown(showSlots)
      end
    end
  end)
end

addonTable.Skins.RegisterSkin(addonTable.Locales.BLIZZARD_BLACK, "blizzard_black", LoadSkin, SkinFrame, SetConstants, {
  {
    type = "checkbox",
    text = addonTable.Locales.HIDE_ICON_BACKGROUNDS,
    option = "empty_slot_background",
    default = false,
  },
}, false, addonTable.Skins.ImmediateLoadingTrigger)
