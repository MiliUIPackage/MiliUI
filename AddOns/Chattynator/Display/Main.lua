---@class addonTableChattynator
local addonTable = select(2, ...)

---@class ChatFrameMixin: Frame
addonTable.Display.ChatFrameMixin = {}

function addonTable.Display.ChatFrameMixin:OnLoad()
  self:SetHyperlinkPropagateToParent(true)
  self:SetMovable(true)
  self:SetResizable(true)
  self:SetResizeBounds(240, 140)
  self:SetClampedToScreen(true)

  self.editBoxBaseOffset = 6

  self:SetScript("OnSizeChanged", function()
    self.ButtonsBar:Update()
    self:SavePosition()
    self:SaveSize()
  end)

  self.ScrollingMessagesWrapper = CreateFrame("Frame", nil, self)
  self.ScrollingMessagesWrapper:SetHyperlinkPropagateToParent(true)
  self.ScrollingMessages = CreateFrame("Frame", nil, self.ScrollingMessagesWrapper)
  self.ScrollingMessages:SetPoint("TOPLEFT")
  self.ScrollingMessages:SetPoint("BOTTOMRIGHT", -5, 0)
  Mixin(self.ScrollingMessages, addonTable.Display.ScrollingMessagesMixin)
  self.ScrollingMessages:MyOnLoad()

  self.ScrollingMessagesWrapper:SetPoint("TOPLEFT", 34, -27)
  self.ScrollingMessagesWrapper:SetPoint("BOTTOMRIGHT", 0, 38)

  self.resizeWidget = CreateFrame("Button", nil, self)
  self.resizeWidget:SetSize(20, 22)
  self.resizeWidget:SetPoint("TOPRIGHT", self.ScrollingMessages, -5,  0)
  self.resizeWidget:RegisterForDrag("LeftButton")
  self.resizeWidget:SetScript("OnDragStart", function()
    self:StartSizing("TOPRIGHT")
  end)
  self.resizeWidget:SetScript("OnDragStop", function()
    self:StopMovingOrSizing()
    self:SaveSize()
  end)
  addonTable.Skins.AddFrame("ResizeWidget", self.resizeWidget)
  self.resizeWidget:SetShown(not addonTable.Config.Get(addonTable.Config.Options.LOCKED))

  self.TabsBar = CreateFrame("Frame", nil, self)
  Mixin(self.TabsBar, addonTable.Display.TabsBarMixin)
  self.TabsBar:OnLoad()
  self.TabsBar:SetPoint("TOPLEFT", 32, 0)
  self.TabsBar:SetPoint("TOPRIGHT")
  self.TabsBar:SetHeight(22)

  self.ButtonsBar = CreateFrame("Frame", nil, self)
  Mixin(self.ButtonsBar, addonTable.Display.ButtonsBarMixin)
  self.ButtonsBar:OnLoad()
  self.ButtonsBar:SetShown(addonTable.Config.Get(addonTable.Config.Options.SHOW_BUTTONS) ~= "never")

  addonTable.CallbackRegistry:RegisterCallback("Render", function(_, newMessages)
    if self:GetID() == 0 then
      return
    end
    self.TabsBar:ApplyFlashing(newMessages)
    self.ScrollingMessages:Render(newMessages)
  end, self)

  addonTable.CallbackRegistry:RegisterCallback("RefreshStateChange", function(_, refreshState)
    if self:GetID() ~= 0 and refreshState[addonTable.Constants.RefreshReason.Tabs] then
      self.TabsBar:RefreshTabs()
      self.ScrollingMessages:Render()
    end
    if refreshState[addonTable.Constants.RefreshReason.MessageWidget] then
      if self:GetID() ~= 0 then
        self.ScrollingMessages:Render()
      end
    end
    if refreshState[addonTable.Constants.RefreshReason.Locked] then
      self.resizeWidget:SetShown(not addonTable.Config.Get(addonTable.Config.Options.LOCKED))
    end
    if refreshState[addonTable.Constants.RefreshReason.MessageFont] then
      self:UpdateEditBox()
    end
  end)

  addonTable.CallbackRegistry:RegisterCallback("SettingChanged", function(_, settingName)
    if self:GetID() == 0 then
      return
    end
    if settingName == addonTable.Config.Options.WINDOWS then
      local ownWindowData = addonTable.Config.Get(addonTable.Config.Options.WINDOWS)[self:GetID()]
      if not ownWindowData then
        addonTable.Core.ReleaseClosedChatFrame(self:GetID())
      else
        self:ClearAllPoints()
        self:SetPoint(unpack(addonTable.Config.Get(addonTable.Config.Options.WINDOWS)[self:GetID()].position))
        self:SetSize(unpack(addonTable.Config.Get(addonTable.Config.Options.WINDOWS)[self:GetID()].size))
        self.ButtonsBar:Update()
      end
    elseif settingName == addonTable.Config.Options.BUTTON_POSITION then
      self.ButtonsBar:Update()
      self:ApplyButtonPositionAnchors()
      self:ApplyTabsShowing()
      self.ScrollingMessages:Render()
    elseif settingName == addonTable.Config.Options.SHOW_BUTTONS then
      self.ButtonsBar:SetShown(addonTable.Config.Get(addonTable.Config.Options.SHOW_BUTTONS) ~= "never")
      self.ButtonsBar:Update()
    elseif settingName == addonTable.Config.Options.EDIT_BOX_POSITION and self:GetID() == 1 then
      self:UpdateEditBox()
      self.ButtonsBar:Update()
    elseif settingName == addonTable.Config.Options.EDIT_BOX_WIDTH and self:GetID() == 1 then
      self:UpdateEditBox()
      self.ButtonsBar:Update()
    elseif settingName == addonTable.Config.Options.EDIT_BOX_HEIGHT and self:GetID() == 1 then
      self:UpdateEditBox()
      self.ButtonsBar:Update()
    elseif settingName == addonTable.Config.Options.EDIT_BOX_HORIZONTAL_OFFSET and self:GetID() == 1 then
      self:UpdateEditBox()
      self.ButtonsBar:Update()
    elseif settingName == addonTable.Config.Options.EDIT_BOX_VERTICAL_OFFSET and self:GetID() == 1 then
      self:UpdateEditBox()
      self.ButtonsBar:Update()
    elseif settingName == addonTable.Config.Options.SHOW_TABS then
      self:ApplyTabsShowing()
      self.ButtonsBar:Update()
    elseif settingName == addonTable.Config.Options.FADE_COMPLETELY then
      self.shouldFadeCompletely = addonTable.Config.Get(addonTable.Config.Options.FADE_COMPLETELY)
    elseif settingName == addonTable.Config.Options.FADED_ALPHA then
      self.fadedAlpha = addonTable.Config.Get(addonTable.Config.Options.FADED_ALPHA)
    end
  end)

  addonTable.Skins.AddFrame("ChatFrame", self)

  self.shouldFadeCompletely = addonTable.Config.Get(addonTable.Config.Options.FADE_COMPLETELY)
  self.fadedAlpha = addonTable.Config.Get(addonTable.Config.Options.FADED_ALPHA)

  local step = 0.08
  C_Timer.NewTicker(step, function()
    local alpha = self:GetAlpha()
    if not self.shouldFadeCompletely or self:IsMouseOver() or self.ButtonsBar:IsMouseOver() or ChatFrame1EditBox:HasFocus() or self.ScrollingMessages:IsAnyShown() or alpha < self.fadedAlpha or not self.ScrollingMessages:IsShown() then
      if alpha < 1 then
        local newAlpha = alpha + step * 8
        self:SetAlpha(newAlpha)
      end
    elseif self.shouldFadeCompletely then
      if alpha > 0 and not self.ScrollingMessages:IsAnyShown() then
        local newAlpha = math.max(self.fadedAlpha, alpha - 1/3 * step)
        self:SetAlpha(newAlpha)
      end
    end
    if self:GetID() == 1 then
      ChatFrame1EditBox:SetAlpha(self:GetAlpha())
    end
  end)
end

function addonTable.Display.ChatFrameMixin:Reset()
  local function SetPosition()
    self:SetPoint(unpack(addonTable.Config.Get(addonTable.Config.Options.WINDOWS)[self:GetID()].position))
  end
  local state = pcall(SetPosition)
  if not state then
    self:SetPoint("CENTER", UIParent)
  end
  self:SetSize(unpack(addonTable.Config.Get(addonTable.Config.Options.WINDOWS)[self:GetID()].size))

  self.filterFunc = nil

  self.tabIndex = 1

  self.TabsBar:Reset()

  self:RepositionBlizzardWidgets()
  if self:GetID() == 1 then
    self.ButtonsBar:AddBlizzardButtons()
  end
  self.ButtonsBar:AddButtons()
  self.ButtonsBar:Update()
  self:AdjustMessageAnchors()
  self:ApplyButtonPositionAnchors()
  self:ApplyTabsShowing()

  self.TabsBar:RefreshTabs()
end

function addonTable.Display.ChatFrameMixin:SavePosition()
  local point1, anchorFrame, point2, x, y = self:GetPoint(1)
  local anchorFrameName = anchorFrame and anchorFrame:GetName() or "UIParent"
  addonTable.Config.Get(addonTable.Config.Options.WINDOWS)[self:GetID()].position = {point1, anchorFrameName, point2, x, y}
end

function addonTable.Display.ChatFrameMixin:SaveSize()
  local x, y = self:GetSize()
  addonTable.Config.Get(addonTable.Config.Options.WINDOWS)[self:GetID()].size = {x, y}
end

function addonTable.Display.ChatFrameMixin:RepositionBlizzardWidgets()
  if self:GetID() == 1 and not addonTable.Data.BlizzardEditBoxAssigned then
    addonTable.Data.BlizzardEditBoxAssigned = true

    -- We use the default edit box rather than instantiating our own so that the keyboard shortcuts to open it work
    self:UpdateEditBox()
    addonTable.Skins.AddFrame("ChatEditBox", ChatFrame1EditBox)
  end
end

function addonTable.Display.ChatFrameMixin:AdjustMessageAnchors()
  if self:GetID() == 1 then
    return
  end
  self.ScrollingMessagesWrapper:SetPoint("BOTTOMRIGHT", 0, 5)
end

function addonTable.Display.ChatFrameMixin:ApplyButtonPositionAnchors()
  local position = addonTable.Config.Get(addonTable.Config.Options.BUTTON_POSITION)
  if position:match("outside_left") then
    self.TabsBar:SetPoint("TOPLEFT", 32, 0)
  else
    self.TabsBar:SetPoint("TOPLEFT", 4, 0)
  end
end

function addonTable.Display.ChatFrameMixin:ApplyTabsShowing()
  local position = addonTable.Config.Get(addonTable.Config.Options.BUTTON_POSITION)
  self.ScrollingMessages:SetPoint("TOPRIGHT",position == "outside_right" and -34 or 0, 0)
  if addonTable.Config.Get(addonTable.Config.Options.SHOW_TABS) ~= "never" then
    self.ScrollingMessagesWrapper:SetPoint("TOPLEFT", position == "outside_left" and 34 or 2, -27)
  else
    self.ScrollingMessagesWrapper:SetPoint("TOPLEFT", position == "outside_left" and 34 or 2, -5)
  end
end

function addonTable.Display.ChatFrameMixin:UpdateEditBox()
  if self:GetID() ~= 1 then
    return
  end
  local position = addonTable.Config.Get(addonTable.Config.Options.EDIT_BOX_POSITION)
  local xOffset = addonTable.Config.Get(addonTable.Config.Options.EDIT_BOX_HORIZONTAL_OFFSET)
  local yOffset = addonTable.Config.Get(addonTable.Config.Options.EDIT_BOX_VERTICAL_OFFSET)
  local width = addonTable.Config.Get(addonTable.Config.Options.EDIT_BOX_WIDTH)/2
  ChatFrame1EditBox:ClearAllPoints()
  ChatFrame1EditBox:SetScale(addonTable.Core.GetFontScalingFactor())
  ChatFrame1EditBox:SetHeight(addonTable.Config.Get(addonTable.Config.Options.EDIT_BOX_HEIGHT))

  if position == "bottom" then
    local _, _, _, clampBottom = self:GetClampRectInsets()
    self.ScrollingMessagesWrapper:SetPoint("BOTTOMRIGHT", 0, 6 + ChatFrame1EditBox:GetHeight() * ChatFrame1EditBox:GetScale() - clampBottom)
    ChatFrame1EditBox:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, yOffset + ChatFrame1EditBox:GetHeight() - clampBottom * ChatFrame1EditBox:GetScale())
    ChatFrame1EditBox:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, ChatFrame1EditBox:GetHeight() - clampBottom * ChatFrame1EditBox:GetScale())
  elseif position == "top" then
    self.ScrollingMessagesWrapper:SetPoint("BOTTOMRIGHT", 0, 5)
    ChatFrame1EditBox:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0 + yOffset)
    ChatFrame1EditBox:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
  elseif position == "screenBottom" then
    self.ScrollingMessagesWrapper:SetPoint("BOTTOMRIGHT", 0, 5)
    ChatFrame1EditBox:SetPoint("BOTTOMLEFT", nil, "BOTTOM", -width + xOffset, 0 + yOffset)
    ChatFrame1EditBox:SetPoint("BOTTOMRIGHT", nil, "BOTTOM", width + xOffset, 0)
  elseif position == "screenCenter" then
    self.ScrollingMessagesWrapper:SetPoint("BOTTOMRIGHT", 0, 5)
    ChatFrame1EditBox:SetPoint("LEFT", nil, "CENTER", -width + xOffset, 0 + yOffset)
    ChatFrame1EditBox:SetPoint("RIGHT", nil, "CENTER", width + xOffset, 0)
  elseif position == "screenTop" then
    self.ScrollingMessagesWrapper:SetPoint("BOTTOMRIGHT", 0, 5)
    ChatFrame1EditBox:SetPoint("TOPLEFT", nil, "TOP", -width + xOffset, 0 + yOffset)
    ChatFrame1EditBox:SetPoint("TOPRIGHT", nil, "TOP", width + xOffset, 0)
  end

  local font = addonTable.Core.GetFontByID(addonTable.Config.Get(addonTable.Config.Options.MESSAGE_FONT))
  for _, r in pairs({ChatFrame1EditBox:GetRegions()}) do
    if r:IsObjectType("FontString") then
      r:SetFontObject(font)
    end
  end
end

function addonTable.Display.ChatFrameMixin:SetFilter(func)
  if addonTable.API.RejectionFilters[self:GetID()] and addonTable.API.RejectionFilters[self:GetID()][self.tabIndex] then
    local filters = addonTable.API.RejectionFilters[self:GetID()] and addonTable.API.RejectionFilters[self:GetID()][self.tabIndex]
    local oldFunc = func
    func = function(data)
      if not oldFunc(data) then
        return false
      end
      local copy = CopyTable(data)
      for _, f in ipairs(filters) do
        if not f(copy) then
          return false
        end
      end
      return true
    end
  end
  self.ScrollingMessages:SetFilter(func)
end

function addonTable.Display.ChatFrameMixin:SetBackgroundColor(r, g, b)
  self.backgroundColor = {r = r, g = g, b = b}
end

function addonTable.Display.ChatFrameMixin:SetTabSelectedOnly(index)
  self.tabIndex = index
end

function addonTable.Display.ChatFrameMixin:SetTabSelectedAndFilter(index, func)
  self.tabIndex = index
  self.ScrollingMessages:Reset()

  self:SetFilter(func)
end
