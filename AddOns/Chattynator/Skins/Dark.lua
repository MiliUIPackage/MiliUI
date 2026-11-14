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
    local buttonsAlpha = 1 - addonTable.Config.Get("skins.dark.buttons_transparency")
    local buttonsBackground = addonTable.Config.Get("skins.dark.buttons_hide_background") and 0 or buttonsAlpha
    
    table.insert(chatButtons, button)
    button:SetSize(26, 28)
    button:SetNormalTexture("Interface/AddOns/Chattynator/Assets/ChatButton.png")
    button:GetNormalTexture():SetVertexColor(0.15, 0.15, 0.15, buttonsBackground)
    button:GetNormalTexture():SetDrawLayer("BACKGROUND")
    button:SetPushedTexture("Interface/AddOns/Chattynator/Assets/ChatButton.png")
    button:GetPushedTexture():SetVertexColor(0.05, 0.05, 0.05)
    button:GetPushedTexture():SetDrawLayer("BACKGROUND")
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
      button.Icon:SetVertexColor(intensity, intensity, intensity)
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
        button:SetNormalTexture("Interface/AddOns/Chattynator/Assets/ChatButton.png")
        button:GetNormalTexture():SetVertexColor(0.15, 0.15, 0.15, buttonsBackground)
        button:GetNormalTexture():SetDrawLayer("BACKGROUND")
        button:SetPushedTexture("Interface/AddOns/Chattynator/Assets/ChatButton.png")
        button:GetPushedTexture():SetVertexColor(0.05, 0.05, 0.05)
        button:GetPushedTexture():SetDrawLayer("BACKGROUND")
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
        button:SetNormalTexture("Interface/AddOns/Chattynator/Assets/ChatButton.png")
        button:GetNormalTexture():SetVertexColor(0.15, 0.15, 0.15, buttonsBackground)
        button:GetNormalTexture():SetDrawLayer("BACKGROUND")
        button:SetPushedTexture("Interface/AddOns/Chattynator/Assets/ChatButton.png")
        button:GetPushedTexture():SetVertexColor(0.05, 0.05, 0.05)
        button:GetPushedTexture():SetDrawLayer("BACKGROUND")
        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("CENTER")
        end)
    elseif tags.menu then
      button.Icon = button:CreateTexture(nil, "ARTWORK")
      button.Icon:SetTexture("Interface/AddOns/Chattynator/Assets/ChatMenu.png")
      button.Icon:SetVertexColor(intensity, intensity, intensity)
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
    local alpha = 1 - addonTable.Config.Get("skins.dark.chat_transparency")
    local hideSeparator = addonTable.Config.Get("skins.dark.edit_box_separator_gap") and -1 or 0
    table.insert(chatFrames, frame)
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetPoint("TOP", frame.ScrollingMessagesWrapper, 0, 5)
    frame.background:SetPoint("LEFT")
    frame.background:SetPoint("BOTTOMRIGHT", frame.ScrollingMessagesWrapper, 0, -5 + hideSeparator)

    hooksecurefunc(frame, "SetBackgroundColor", function(_, r, g, b)
      alpha = 1 - addonTable.Config.Get("skins.dark.chat_transparency")
      if addonTable.Config.Get("skins.dark.solid_chat_background") then
        frame.background:SetColorTexture(r, g, b, alpha)
        frame.background:SetVertexColor(1, 1, 1, 1)
      else
        frame.background:SetTexture("Interface/AddOns/Chattynator/Assets/ChatBackground")
        frame.background:SetTexCoord(0, 1, 1, 0)
        frame.background:SetVertexColor(r, g, b, alpha)
      end
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
    local alpha = 1 - addonTable.Config.Get("skins.dark.edit_box_transparency")
    editBox.background = editBox:CreateTexture(nil, "BACKGROUND")
    local editBoxColor = addonTable.Config.Get("skins.dark.edit_box_bg_color")

    editBox.background:SetColorTexture(editBoxColor.r, editBoxColor.g, editBoxColor.b, alpha)
    editBox.background:SetPoint("TOPLEFT", editBox)
    editBox.background:SetPoint("BOTTOM", editBox)
    editBox.background:SetPoint("RIGHT", editBox)
  end,
  ChatTab = function(tab, tags)
    local alpha = 1 - addonTable.Config.Get("skins.dark.tab_transparency")
    table.insert(chatTabs, tab)
    tab:SetHeight(22)
    tab:SetAlpha(1)
    tab.Left = tab:CreateTexture(nil, "BACKGROUND")
    tab.Left:SetTexture("Interface/AddOns/Chattynator/Assets/ChatTabLeft")
    tab.Left:SetHeight(22)
    tab.Left:SetWidth(6)
    tab.Left:SetPoint("TOPLEFT")
    tab.Left:SetAlpha(alpha)
    tab.Right = tab:CreateTexture(nil, "BACKGROUND")
    tab.Right:SetTexture("Interface/AddOns/Chattynator/Assets/ChatTabRight")
    tab.Right:SetHeight(22)
    tab.Right:SetWidth(6)
    tab.Right:SetPoint("TOPRIGHT")
    tab.Right:SetAlpha(alpha)
    tab.Middle = tab:CreateTexture(nil, "BACKGROUND")
    tab.Middle:SetTexture("Interface/AddOns/Chattynator/Assets/ChatTabMiddle")
    tab.Middle:SetHeight(22)
    tab.Middle:SetPoint("LEFT", 6, 0)
    tab.Middle:SetPoint("RIGHT", -6, 0)
    tab.Middle:SetAlpha(alpha)
    tab.LeftFlash = tab:CreateTexture(nil, "BACKGROUND")
    tab.LeftFlash:SetTexture("Interface/AddOns/Chattynator/Assets/ChatTabLeft")
    tab.LeftFlash:SetHeight(24)
    tab.LeftFlash:SetWidth(8)
    tab.LeftFlash:SetPoint("BOTTOMLEFT", -1, 0)
    tab.LeftFlash:Hide()
    tab.LeftFlash:SetIgnoreParentAlpha(true)
    tab.LeftFlash:SetVertexColor(flashTabColor.r, flashTabColor.g, flashTabColor.b)
    tab.RightFlash = tab:CreateTexture(nil, "BACKGROUND")
    tab.RightFlash:SetTexture("Interface/AddOns/Chattynator/Assets/ChatTabRight")
    tab.RightFlash:SetHeight(24)
    tab.RightFlash:SetWidth(8)
    tab.RightFlash:SetPoint("BOTTOMRIGHT", 1, 0)
    tab.RightFlash:Hide()
    tab.RightFlash:SetIgnoreParentAlpha(true)
    tab.RightFlash:SetVertexColor(flashTabColor.r, flashTabColor.g, flashTabColor.b)
    tab.MiddleFlash = tab:CreateTexture(nil, "BACKGROUND")
    tab.MiddleFlash:SetTexture("Interface/AddOns/Chattynator/Assets/ChatTabMiddle")
    tab.MiddleFlash:SetHeight(24)
    tab.MiddleFlash:SetPoint("BOTTOMLEFT", 7, 0)
    tab.MiddleFlash:SetPoint("BOTTOMRIGHT", -7, 0)
    tab.MiddleFlash:Hide()
    tab.MiddleFlash:SetIgnoreParentAlpha(true)
    tab.MiddleFlash:SetVertexColor(flashTabColor.r, flashTabColor.g, flashTabColor.b)
    tab:SetNormalFontObject("GameFontNormalSmall")
    if tab:GetFontString() == nil then
      tab:SetText(" ")
    end    
    local tabTextColor = addonTable.Config.Get("skins.dark.tab_text_color")
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
      if tab.selected then
        tab.Left:SetAlpha(1)
        tab.Right:SetAlpha(1)
        tab.Middle:SetAlpha(1)
      else
        tab:SetAlpha(1)
        tab.Left:SetAlpha(0.8)
        tab.Right:SetAlpha(0.8)
        tab.Middle:SetAlpha(0.8)
      end
    end)
    local function SetSelected(_, state)
      alpha = 1 - addonTable.Config.Get("skins.dark.tab_transparency")
      if not tab:IsMouseMotionFocus() then
        tab.Left:SetAlpha(alpha)
        tab.Right:SetAlpha(alpha)
        tab.Middle:SetAlpha(alpha)
      end
      if state then
        tab:SetAlpha(1)
      else
        tab:SetAlpha(0.5)
      end
    end
    tab:HookScript("OnLeave", function()
      SetSelected(tab, tab.selected)
    end)
    hooksecurefunc(tab, "SetSelected", SetSelected)
    hooksecurefunc(tab, "SetColor", function(_, r, g, b)
      tab.Left:SetVertexColor(r, g, b)
      tab.Right:SetVertexColor(r, g, b)
      tab.Middle:SetVertexColor(r, g, b)
      tab.LeftFlash:SetVertexColor(r, g, b)
      tab.RightFlash:SetVertexColor(r, g, b)
      tab.MiddleFlash:SetVertexColor(r, g, b)
    end)
    if tab.color then
      tab:SetColor(tab.color.r, tab.color.g, tab.color.b)
    end
    if tab.selected ~= nil then
      tab:SetSelected(tab.selected)
    end

    tab.FlashAnimation = tab:CreateAnimationGroup()
    tab.FlashAnimation:SetLooping("BOUNCE")
    local alpha1 = tab.FlashAnimation:CreateAnimation("Alpha")
    alpha1:SetChildKey("LeftFlash")
    alpha1:SetFromAlpha(0)
    alpha1:SetToAlpha(1)
    alpha1:SetDuration(0.5)
    alpha1:SetOrder(1)
    local alpha2 = tab.FlashAnimation:CreateAnimation("Alpha")
    alpha2:SetChildKey("RightFlash")
    alpha2:SetFromAlpha(0)
    alpha2:SetToAlpha(1)
    alpha2:SetDuration(0.5)
    alpha2:SetOrder(1)
    local alpha3 = tab.FlashAnimation:CreateAnimation("Alpha")
    alpha3:SetChildKey("MiddleFlash")
    alpha3:SetFromAlpha(0)
    alpha3:SetToAlpha(1)
    alpha3:SetDuration(0.5)
    alpha3:SetOrder(1)
    hooksecurefunc(tab, "SetFlashing", function(_, state)
      tab:SetIgnoreParentAlpha(state)
      tab.FlashAnimation:SetPlaying(state)
      tab.LeftFlash:SetShown(state)
      tab.RightFlash:SetShown(state)
      tab.MiddleFlash:SetShown(state)
      if state then
        tab:SetHitRectInsets(0, 0, -2, 0)
      else
        tab:SetHitRectInsets(0, 0, 0, 0)
      end
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
    if settingName == "skins.dark.tab_transparency" then
      local alpha = 1 - addonTable.Config.Get(settingName)
      for _, tab in ipairs(chatTabs) do
        tab.Left:SetAlpha(alpha)
        tab.Right:SetAlpha(alpha)
        tab.Middle:SetAlpha(alpha)
      end
    elseif settingName == "skins.dark.chat_transparency" then
      for _, frame in ipairs(chatFrames) do
        frame:SetBackgroundColor(frame.backgroundColor.r, frame.backgroundColor.g, frame.backgroundColor.b)
      end
    elseif settingName == "skins.dark.edit_box_transparency" then
      local color = addonTable.Config.Get("skins.dark.edit_box_bg_color")
      local alpha = 1 - addonTable.Config.Get("skins.dark.edit_box_transparency")
      for _, frame in ipairs(editBoxes) do
        frame.background:SetColorTexture(color.r, color.g, color.b, alpha)
      end
    elseif settingName == "skins.dark.tab_text_color" then
      local color = addonTable.Config.Get(settingName)
      for _, tab in ipairs(chatTabs) do
        tab:GetFontString():SetTextColor(color.r, color.g, color.b)
      end
    elseif settingName == "skins.dark.edit_box_bg_color" then
      local color = addonTable.Config.Get(settingName)
      local alpha = 1 - addonTable.Config.Get("skins.dark.edit_box_transparency")
      for _, frame in ipairs(editBoxes) do
        frame.background:SetColorTexture(color.r, color.g, color.b, alpha)
      end
    elseif settingName == "skins.dark.solid_chat_background" then
      for _, frame in ipairs(chatFrames) do
        frame:SetBackgroundColor(frame.backgroundColor.r, frame.backgroundColor.g, frame.backgroundColor.b)
      end
    elseif settingName == "skins.dark.edit_box_separator_gap" then
      for _, frame in ipairs(chatFrames) do
        local hideSeparator = addonTable.Config.Get(settingName) and -1 or 0
        frame.background:SetPoint("BOTTOMRIGHT", frame.ScrollingMessagesWrapper, 0, -5 + hideSeparator)
      end
    elseif settingName == "skins.dark.buttons_transparency" then
      local alpha = 1 - addonTable.Config.Get(settingName)
      local hideBackground = addonTable.Config.Get("skins.dark.buttons_hide_background") and 0 or alpha
      for _, button in ipairs(chatButtons) do
        button:GetNormalTexture():SetVertexColor(0.15, 0.15, 0.15, hideBackground)
        if (button.FriendCount or FriendsMicroButtonCount) then
          (button.FriendCount or FriendsMicroButtonCount):SetTextColor(intensity, intensity, intensity, alpha)
        end
        button.Icon:SetVertexColor(intensity, intensity, intensity, alpha)
      end
    elseif settingName == "skins.dark.buttons_hide_background" then
      local alpha = 1 - addonTable.Config.Get("skins.dark.buttons_transparency")
      local hideBackground = addonTable.Config.Get(settingName) and 0 or alpha
      for _, button in ipairs(chatButtons) do
        button:GetNormalTexture():SetVertexColor(0.15, 0.15, 0.15, hideBackground)
      end
    end
  end)

  --[[local function UpdateHeader(editBox)
    if tIndexOf(editBoxes, editBox) ~= nil then
      local promptWidth = editBox.header:GetWidth() + (editBox.headerSuffix:IsShown() and editBox.headerSuffix:GetWidth() or 0) + (editBox.languageHeader and editBox.languageHeader:IsShown() and editBox.languageHeader:GetWidth() or 0)
      local wantedOffset = addonTable.Messages.inset
      local realPosition = math.max(5, 3 + addonTable.Messages.inset - promptWidth)
      if addonTable.Messages.timestampFormat == " " then
        realPosition = addonTable.Messages.inset + 2
      end
      editBox.prompt:SetPoint("LEFT", realPosition, 0)
      editBox.header:SetPoint("LEFT", realPosition, 0)
      editBox:SetTextInsets(promptWidth + realPosition, 13, 0, 0)
    end
  end
  if ChatFrame1EditBox.UpdateHeader then
    hooksecurefunc(ChatFrame1EditBox, "UpdateHeader", UpdateHeader)
  else
    hooksecurefunc("ChatEdit_UpdateHeader", UpdateHeader)
  end]]
end

addonTable.Skins.RegisterSkin(addonTable.Locales.DARK, "dark", LoadSkin, SkinFrame, SetConstants, {
  {
    type = "checkbox",
    text = addonTable.Locales.SOLID_CHAT_BACKGROUND,
    option = "solid_chat_background",
    default = true,
  },
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
    default = 0.2,
  },
  { type = "spacer" },
  {
    type = "slider",
    min = 0,
    max = 100,
    lowText = "0%",
    highText = "100%",
    scale = 100,
    text = addonTable.Locales.TAB_TRANSPARENCY,
    valuePattern = "%s%%",
    option = "tab_transparency",
    default = 0,
  },
  {
    type = "colorPicker",
    text = addonTable.Locales.TAB_TEXT_COLOR,
    default = {r=1,g=215/255,b=0},
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
    default = 0.4,
  },
  {
    type = "colorPicker",
    text = addonTable.Locales.EDIT_BOX_BG_COLOR,
    default = {r = 0.1, g = 0.1, b = 0.1},
    option = "edit_box_bg_color"
  },
  {
    type = "checkbox",
    text = addonTable.Locales.EDIT_BOX_SEPARATOR_GAP,
    option = "edit_box_separator_gap",
    default = false,
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
  {
    type = "checkbox",
    text = addonTable.Locales.BUTTONS_HIDE_BACKGROUND,
    option = "buttons_hide_background",
    default = false,
  },
})
