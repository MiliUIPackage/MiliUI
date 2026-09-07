local addonTable = select(2, ...)

local E
local S
local LSM

local function ConvertTags(tags)
  local res = {}
  for _, tag in ipairs(tags) do
    res[tag] = true
  end
  return res
end

local skinners = {
  Button = function(frame)
    S:HandleButton(frame)
  end,
  IconButton = function(frame, tags)
    S:HandleButton(frame)
    if tags["delete"] then
      local t = frame:CreateTexture()
      t:SetTexture("Interface/AddOns/Platynator/Assets/Trash_Icon")
      t:SetSize(15, 15)
      t:SetPoint("CENTER")
    end
  end,
  ButtonFrame = function(frame)
    S:HandlePortraitFrame(frame)
  end,
  SearchBox = function(frame)
    S:HandleEditBox(frame)
  end,
  EditBox = function(frame)
    S:HandleEditBox(frame)
  end,
  TabButton = function(frame)
    S:HandleTab(frame)
  end,
  TopTabButton = function(frame)
    S:HandleTab(frame)
  end,
  TrimScrollBar = function(frame)
    S:HandleTrimScrollBar(frame)
  end,
  ScrollButton = function(button, tags)
    button:ClearNormalTexture()
    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(E.Media.Textures.ArrowUp)
    tex:SetSize(16, 16)
    button:SetSize(16, 16)
    button:SetAlpha(1)
    if tags.left then
      tex:SetPoint("RIGHT")
      tex:SetRotation(math.pi/2)
    elseif tags.right then
      tex:SetPoint("LEFT")
      tex:SetRotation(-math.pi/2)
    end
    button.__texture = tex
    button:SetScript("OnEnter", function()
      tex:SetVertexColor(unpack(E.media.rgbvaluecolor))
    end)
    button:SetScript("OnLeave", function()
      tex:SetVertexColor(1, 1, 1)
    end)
  end,
  CheckBox = function(frame)
    S:HandleCheckBox(frame)
  end,
  InsetFrame = function(frame)
    if frame.NineSlice then
      frame.NineSlice:SetTemplate("Transparent")
    else
      S:HandleInsetFrame(frame)
    end
  end,
  Dropdown = function(button)
    local w = button:GetWidth()
    S:HandleDropDownBox(button)
    button:SetWidth(w)
  end,
  Divider = function(tex)
    tex:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    tex:SetPoint("TOPLEFT", 0, 0)
    tex:SetPoint("TOPRIGHT", 0, 0)
    tex:SetHeight(1)
    tex:SetColorTexture(1, 0.93, 0.73, 0.45)
  end,
  Dialog = function(frame)
    frame:StripTextures()
    frame:SetTemplate('Transparent')
  end,
  MinMaxFrame = function(frame)
    S:HandleMaxMinFrame(frame)
  end,
}

local function SkinFrame(details)
  local func = skinners[details.regionType]
  if func then
    func(details.region, details.tags and ConvertTags(details.tags) or {})
  end
end

local function SetConstants()
  addonTable.Constants.ButtonFrameOffset = 0
end

local function LoadSkin()
  E = unpack(ElvUI)
  S = E:GetModule("Skins")
  LSM = E.Libs.LSM
end

if addonTable.Skins.IsAddOnLoading("ElvUI") then
  addonTable.Skins.RegisterSkin(addonTable.Locales.ELVUI, "elvui", LoadSkin, SkinFrame, SetConstants, {
  }, 20)
end
