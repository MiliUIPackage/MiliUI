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
    frame.QuestMarker = frame:CreateTexture(nil, "ARTWORK")
    frame.QuestMarker:SetSize(22, 22)
    frame.QuestMarker:SetAtlas("Crosshair_Quest_64")
    frame.QuestMarker:SetPoint("BOTTOMLEFT", -3, 2)
    frame.QuestMarker:Hide()
    S.Button(frame, {"icon", "IconBorder", "ProfessionQualityOverlay", "IconOverlay", "searchOverlay", "ItemContextOverlay", "QuestMarker"})
    if frame.icon:GetMaskTexture(1) then
      frame.icon:RemoveMaskTexture(frame.icon:GetMaskTexture(1))
    end
    hooksecurefunc(frame, "SetItemButtonQuality", function(_, quality)
      frame.IconBorder:SetTexture("Interface/AddOns/Baganator/Assets/Skins/dark-icon-border")
      frame:ClearNormalTexture()
      local c = ITEM_QUALITY_COLORS[quality]
      if c then
        frame.IconBorder:SetVertexColor(c.r, c.g, c.b, 1)
        frame.IconBorder:Show()
      else
        frame.IconBorder:Hide()
      end
      frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end)
    if frame.BGRUpdateQuests then
      local questTexture = frame:GetName() and _G[frame:GetName() .. "IconQuestTexture"] or frame.IconQuestTexture
      hooksecurefunc(frame, "BGRUpdateQuests", function()
        frame.QuestMarker:Hide()
        if questTexture:IsShown() then
          local textureID = questTexture:GetTexture()
          if textureID == 368362 then -- quest border only
            frame.QuestMarker:Show()
          end
          frame.IconBorder:SetVertexColor(1, 0.82, 0)
        end
      end)
    end
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
