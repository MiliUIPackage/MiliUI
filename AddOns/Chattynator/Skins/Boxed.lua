---@class addonTableChattynator
local addonTable = select(2, ...)

local intensity = 0.8
local hoverColor = {r = 59/255, g = 210/255, b = 237/255}
local voiceActiveColor = {r = 33/255, g = 209/255, b = 45/255}
local flashTabColor = {r = 247/255, g = 222/255, b = 61/255}

local toUpdate = {}

local UIScaleMonitor = CreateFrame("Frame")
UIScaleMonitor:RegisterEvent("UI_SCALE_CHANGED")
UIScaleMonitor:SetScript("OnEvent", function()
  for _, func in ipairs(toUpdate) do
    func()
  end
end)

local chatTabs = {}
local chatFrames = {}
local editBoxes = {}
local chatButtons = {}

local skinners = {
  ChatButton = function(button, tags)
    local buttonsAlpha = 1 - addonTable.Config.Get("skins.boxed.buttons_transparency")
    table.insert(chatButtons, button)
    button:SetSize(26, 28)
    button:ClearNormalTexture()
    button:ClearPushedTexture()
    button:ClearHighlightTexture()

    button:HookScript("OnEnter", function()
      button.Icon:SetVertexColor(hoverColor.r, hoverColor.g, hoverColor.b)
    end)
    button:HookScript("OnLeave", function()
      button.Icon:SetVertexColor(intensity, intensity, intensity)
    end)

    button:HookScript("OnMouseDown", function()
      button.Icon:AdjustPointsOffset(2, -2)
    end)
    button:HookScript("OnMouseUp", function()
      button.Icon:AdjustPointsOffset(-2, 2)
    end)

    if tags.toasts then
      button.Icon = button.FriendsButton or button:CreateTexture(nil, "ARTWORK")
      button.Icon:SetTexture("Interface/AddOns/Chattynator/Assets/ChatSocial.png")
      button.Icon:SetVertexColor(intensity, intensity, intensity, buttonsAlpha)
      button.Icon:SetDrawLayer("ARTWORK")
      button.Icon:SetSize(12, 12)
      button.Icon:ClearAllPoints()
      button.Icon:SetPoint("TOP", 0, -2);
      (button.FriendCount or FriendsMicroButtonCount):SetTextColor(intensity, intensity, intensity, buttonsAlpha)
      button:HookScript("OnEnter", function()
        (button.FriendCount or FriendsMicroButtonCount):SetTextColor(hoverColor.r, hoverColor.g, hoverColor.b)
      end)
      button:HookScript("OnLeave", function()
        (button.FriendCount or FriendsMicroButtonCount):SetTextColor(intensity, intensity, intensity)
      end)
    elseif tags.channels then
      hooksecurefunc(button, "SetIconToState", function(self, state)
        button:ClearNormalTexture()
        button:ClearPushedTexture()
        button:ClearHighlightTexture()
        if state then
          button.Icon:SetTexture("Interface/Addons/Chattynator/Assets/ChatChannelsVC.png")
          button.Icon:SetVertexColor(voiceActiveColor.r, voiceActiveColor.g, voiceActiveColor.b)
        else
          button.Icon:SetTexture("Interface/Addons/Chattynator/Assets/ChatChannels.png")
          button.Icon:SetVertexColor(intensity, intensity, intensity, buttonsAlpha)
        end
        if button:IsMouseOver() then
          button:GetScript("OnEnter")(button)
        end
      end)
      button:HookScript("OnLeave", function()
        button:UpdateVisibleState()
      end)
      button:UpdateVisibleState()
    elseif tags.voiceChatNoAudio or tags.voiceChatMuteMic then
      hooksecurefunc(button, "SetIconToState", function(self, state)
        button:ClearNormalTexture()
        button:ClearPushedTexture()
        button:ClearHighlightTexture()
        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("CENTER")
      end)
    elseif tags.menu then
      button.Icon = button:CreateTexture(nil, "ARTWORK")
      button.Icon:SetTexture("Interface/AddOns/Chattynator/Assets/ChatMenu.png")
      button.Icon:SetVertexColor(intensity, intensity, intensity, buttonsAlpha)
      button.Icon:SetPoint("CENTER")
      button.Icon:SetSize(15, 15)
    else
      button.Icon = button:CreateTexture(nil, "OVERLAY")
      if tags.search then
        button.Icon:SetTexture("Interface/AddOns/Chattynator/Assets/Search.png")
      elseif tags.copy then
        button.Icon:SetTexture("Interface/AddOns/Chattynator/Assets/Copy.png")
      elseif tags.settings then
        button.Icon:SetTexture("Interface/AddOns/Chattynator/Assets/SettingsCog.png")
      elseif tags.scrollToEnd then
        button.Icon:SetTexture("Interface/AddOns/Chattynator/Assets/ScrollToBottom.png")
      end
      button.Icon:SetPoint("CENTER")
      button.Icon:SetSize(15, 15)
      button.Icon:SetVertexColor(intensity, intensity, intensity, buttonsAlpha)
    end
  end,
  ChatFrame = function(frame, tags)
    table.insert(chatFrames, frame)
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetPoint("TOP", frame, 0, 0)
    frame.background:SetPoint("LEFT")
    frame.background:SetPoint("BOTTOMRIGHT", frame.ScrollingMessagesWrapper, 0, -6)

    hooksecurefunc(frame, "SetBackgroundColor", function(_, r, g, b)
      frame.background:SetColorTexture(r, g, b, 1 - addonTable.Config.Get("skins.boxed.chat_transparency"))
    end)
    if frame.backgroundColor then
      frame:SetBackgroundColor(frame.backgroundColor.r, frame.backgroundColor.g, frame.backgroundColor.b)
    end
  end,
  ChatEditBox = function(editBox, tags)
    table.insert(editBoxes, editBox)
    for _, texName in ipairs({"Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid"}) do
      local tex = _G[editBox:GetName() .. texName]
      if tex then
        tex:SetParent(addonTable.hiddenFrame)
      end
    end
    local alpha = 1 - addonTable.Config.Get("skins.boxed.edit_box_transparency")
    editBox.background = editBox:CreateTexture(nil, "BACKGROUND")
    local editBoxColor = addonTable.Config.Get("skins.boxed.edit_box_bg_color")

    editBox.background:SetColorTexture(editBoxColor.r, editBoxColor.g, editBoxColor.b, alpha)
    editBox.background:SetPoint("TOPLEFT", editBox)
    editBox.background:SetPoint("BOTTOM", editBox)
    editBox.background:SetPoint("RIGHT", editBox)
  end,
  ChatTab = function(tab, tags)
    table.insert(chatTabs, tab)
    tab:SetHeight(22)
    tab:SetAlpha(1)
    tab.Base = tab:CreateTexture()
    tab.Base:SetPoint("BOTTOMLEFT", 2, 0)
    tab.Base:SetPoint("BOTTOMRIGHT", -2, 0)
    tab.Base:SetHeight(4)
    tab.Background = tab:CreateTexture(nil, "BACKGROUND")
    tab.Background:SetPoint("TOPLEFT", 2, 0)
    tab.Background:SetPoint("BOTTOMRIGHT", -2, 0)
    tab.Background:SetColorTexture(1, 1, 1, 0.1)
    tab.Background:Hide()
    tab:SetNormalFontObject("GameFontNormalSmall")
    if tab:GetFontString() == nil then
      tab:SetText(" ")
    end

    local tabTextColor = addonTable.Config.Get("skins.boxed.tab_text_color")
    tab:GetFontString():SetTextColor(tabTextColor.r, tabTextColor.g, tabTextColor.b)
    tab:GetFontString():SetWordWrap(false)
    tab:GetFontString():SetNonSpaceWrap(false)
    local fsWidth
    if tab.minWidth then
      fsWidth = tab:GetFontString():GetUnboundedStringWidth() + addonTable.Constants.TabPadding
    else
      fsWidth = math.max(tab:GetFontString():GetUnboundedStringWidth(), not tab:GetText():find("|K") and addonTable.Constants.MinTabWidth or 70) + addonTable.Constants.TabPadding
    end
    tab:GetFontString():SetWidth(fsWidth)
    tab:SetWidth(fsWidth)
    hooksecurefunc(tab, "SetText", function()
      if tab.minWidth then
        fsWidth = tab:GetFontString():GetUnboundedStringWidth() + addonTable.Constants.TabPadding
      else
        fsWidth = math.max(tab:GetFontString():GetUnboundedStringWidth(), not tab:GetText():find("|K") and addonTable.Constants.MinTabWidth or 70) + addonTable.Constants.TabPadding
      end
      tab:GetFontString():SetWidth(fsWidth)
      tab:SetWidth(fsWidth)
    end)
    table.insert(toUpdate, function()
      tab:SetText(tab:GetText())
    end)
    tab:GetFontString():SetPoint("TOP", 0, -5)
    tab:HookScript("OnEnter", function()
      tab.Background:Show()
      if tab.selected then
        tab.Base:SetAlpha(1)
      else
        tab.Base:SetAlpha(0.6)
      end
    end)
    local function SetSelected(_, state)
      if not tab:IsMouseMotionFocus() then
        tab.Background:Hide()
        if state then
          tab.Base:SetAlpha(0.9)
        else
          tab.Base:SetAlpha(0.2)
        end
      else
        tab.Background:Show()
        if state then
          tab.Base:SetAlpha(1)
        else
          tab.Base:SetAlpha(0.6)
        end
      end
    end
    tab:HookScript("OnLeave", function()
      SetSelected(tab, tab.selected)
    end)
    hooksecurefunc(tab, "SetSelected", SetSelected)
    hooksecurefunc(tab, "SetColor", function(_, r, g, b)
      tab.Base:SetShown(tab.isDraggable)
      tab.Base:SetColorTexture(r, g, b)
    end)
    if tab.color then
      tab:SetColor(tab.color.r, tab.color.g, tab.color.b)
    end
    if tab.selected ~= nil then
      tab:SetSelected(tab.selected)
    end

    tab.FlashAnimation = tab:CreateAnimationGroup()
    tab.FlashAnimation:SetLooping("BOUNCE")
    local alpha2 = tab.FlashAnimation:CreateAnimation("Alpha")
    alpha2:SetChildKey("Base")
    alpha2:SetFromAlpha(0.3)
    alpha2:SetToAlpha(1)
    alpha2:SetDuration(0.5)
    alpha2:SetOrder(1)
    hooksecurefunc(tab, "SetFlashing", function(_, state)
      tab:SetIgnoreParentAlpha(state)
      tab.FlashAnimation:SetPlaying(state)
    end)
  end,
  ResizeWidget = function(frame, tags)
    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetVertexColor(intensity, intensity, intensity)
    tex:SetTexture("Interface/AddOns/Chattynator/Assets/resize.png")
    tex:SetTexCoord(0, 1, 1, 0)
    tex:SetAllPoints()
    frame:SetScript("OnEnter", function()
      tex:SetVertexColor(hoverColor.r, hoverColor.g, hoverColor.b)
    end)
    frame:SetScript("OnLeave", function()
      tex:SetVertexColor(intensity, intensity, intensity)
    end)
    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", -6, -5)
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
  if addonTable.Constants.IsRetail or addonTable.Constants.IsForever then
    addonTable.Constants.ButtonFrameOffset = 5
  else
    addonTable.Constants.ButtonFrameOffset = 0
  end
end

local function LoadSkin()
  addonTable.CallbackRegistry:RegisterCallback("SettingChanged", function(_, settingName)
    if settingName == "skins.boxed.chat_transparency" then
      for _, frame in ipairs(chatFrames) do
        frame:SetBackgroundColor(frame.backgroundColor.r, frame.backgroundColor.g, frame.backgroundColor.b)
      end
    elseif settingName == "skins.boxed.edit_box_transparency" then
      local color = addonTable.Config.Get("skins.boxed.edit_box_bg_color")
      local alpha = 1 - addonTable.Config.Get("skins.boxed.edit_box_transparency")
      for _, frame in ipairs(editBoxes) do
        frame.background:SetColorTexture(color.r, color.g, color.b, alpha)
      end
    elseif settingName == "skins.boxed.tab_text_color" then
      local color = addonTable.Config.Get(settingName)
      for _, tab in ipairs(chatTabs) do
        tab:GetFontString():SetTextColor(color.r, color.g, color.b)
      end
    elseif settingName == "skins.boxed.edit_box_bg_color" then
      local color = addonTable.Config.Get(settingName)
      local alpha = 1 - addonTable.Config.Get("skins.boxed.edit_box_transparency")
      for _, frame in ipairs(editBoxes) do
        frame.background:SetColorTexture(color.r, color.g, color.b, alpha)
      end
    elseif settingName == "skins.boxed.buttons_transparency" then
      local alpha = 1 - addonTable.Config.Get(settingName)
      for _, button in ipairs(chatButtons) do
        if (button.FriendCount or FriendsMicroButtonCount) then
          (button.FriendCount or FriendsMicroButtonCount):SetTextColor(intensity, intensity, intensity, alpha)
        end
        button.Icon:SetVertexColor(intensity, intensity, intensity, alpha)
      end
    end
  end)
end

addonTable.Skins.RegisterSkin(addonTable.Locales.BOXED, "boxed", LoadSkin, SkinFrame, SetConstants, {
  {
    type = "slider",
    min = 0,
    max = 100,
    lowText = "0%",
    highText = "100%",
    scale = 100,
    text = addonTable.Locales.CHAT_TRANSPARENCY,
    valuePattern = "%s%%",
    option = "chat_transparency",
    default = 0,
  },
  { type = "spacer" },
  {
    type = "colorPicker",
    text = addonTable.Locales.TAB_TEXT_COLOR,
    default = {r=1,g=0.843,b=0},
    option = "tab_text_color"
  },
  { type = "spacer" },
  {
    type = "slider",
    min = 0,
    max = 100,
    lowText = "0%",
    highText = "100%",
    scale = 100,
    text = addonTable.Locales.EDIT_BOX_TRANSPARENCY,
    valuePattern = "%s%%",
    option = "edit_box_transparency",
    default = 0,
  },
  {
    type = "colorPicker",
    text = addonTable.Locales.EDIT_BOX_BG_COLOR,
    default = {r = 0.1, g = 0.1, b = 0.1},
    option = "edit_box_bg_color"
  },
  { type = "spacer" },
  {
    type = "slider",
    min = 0,
    max = 100,
    lowText = "0%",
    highText = "100%",
    scale = 100,
    text = addonTable.Locales.BUTTONS_TRANSPARENCY,
    valuePattern = "%s%%",
    option = "buttons_transparency",
    default = 0,
  },
})
