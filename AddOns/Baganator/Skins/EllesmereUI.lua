---@class addonTableBaganator
local addonTable = select(2, ...)
local addonName = ...

local S

local function ConvertTags(tags)
  local res = {}
  for _, tag in ipairs(tags) do
    res[tag] = true
  end
  return res
end

local hidden = CreateFrame("Frame")
hidden:Hide()
local skinners = {
  ItemButton = function(frame, tags)
    S.Button(frame, {"icon", "ProfessionQualityOverlay", "IconOverlay", "searchOverlay", "ItemContextOverlay"})
    S.SquareIcon(GetItemButtonIconTexture(frame), frame, true)
  end,
  IconButton = function(frame)
    S.Button(frame, {"Icon"})
  end,
  Button = function(frame)
    S.Button(frame)
    S.StateButtonLabel(frame)
  end,
  ButtonFrame = function(frame)
    S.Shell(frame)
    S.CloseButton(frame.CloseButton)
  end,
  SearchBox = function(frame)
    S.EditBox(frame)
  end,
  EditBox = function(frame)
    S.EditBox(frame)
  end,
  TabButton = function(frame)
    frame:HookScript("OnEnable", function()
      frame.isSelected = false
      S.Tab(frame)
    end)
    frame:HookScript("OnDisable", function()
      frame.isSelected = true
      S.Tab(frame)
    end)
    S.Tab(frame)
  end,
  TopTabButton = function(frame)
    frame:HookScript("OnEnable", function()
      frame.isSelected = false
      S.Tab(frame)
    end)
    frame:HookScript("OnDisable", function()
      frame.isSelected = true
      S.Tab(frame)
    end)
    S.Tab(frame)
  end,
  SideTabButton = function(frame)
    S.Button(frame)
    S.SquareIcon(frame.Icon, frame)
  end,
  TrimScrollBar = function(frame)
  end,
  ScrollButton = function(button, tags)
  end,
  CheckBox = function(frame)
    S.Checkbox(frame)
  end,
  Slider = function(frame)
  end,
  InsetFrame = function(frame)
    S.Panel(frame)
  end,
  CornerWidget = function(frame)
    if frame:IsObjectType("FontString") then
      S.Font(frame)
    end
  end,
  Dropdown = function(button)
    S.Dropdown(button)
  end,
  Divider = function(tex)
    tex:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    tex:SetPoint("TOPLEFT", 0, 0)
    tex:SetPoint("TOPRIGHT", 0, 0)
    tex:SetHeight(1)
    tex:SetColorTexture(1, 0.93, 0.73, 0.45)
  end,
  Dialog = function(frame)
    S.Panel(frame)
  end,
}

local function SkinFrameInternal(details)
  local func = skinners[details.regionType]
  if func then
    func(details.region, details.tags and ConvertTags(details.tags) or {})
  end
end
local function SkinFrame(details)
  if S then
    SkinFrameInternal(details)
  else
    C_Timer.After(0, function()
      if S then
        SkinFrameInternal(details)
      end
    end)
  end
end

local function SetConstants()
  addonTable.Constants.ButtonFrameOffset = 0
  addonTable.Constants.ButtonFrameOffsetTop = 0
end

local function LoadSkin()
  EllesmereUI.RegisterSkin(addonName, function(handle) S = handle end)

  if addonTable.API.IsMasqueApplying() then
    skinners.ItemButton = nil
  end
end

if addonTable.Skins.IsAddOnLoading("EllesmereUI") then
  addonTable.Skins.RegisterSkin("Ellesmere UI", "ellesmereui", LoadSkin, SkinFrame, SetConstants, {}, true)
end
