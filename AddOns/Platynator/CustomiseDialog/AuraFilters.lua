---@class addonTablePlatynator
local addonTable = select(2, ...)

local function Announce()
  addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.Design] = true})
end

local function GetSettings(kind)
  return addonTable.Config.Get(addonTable.Config.Options.AURA_FILTERS)[addonTable.Display.Utilities.GetSpecializationID()][kind]
end

local function IsExcludedSpell(kind, spellID)
  return GetSettings(kind).exclude[spellID] ~= nil
end

local function IsIncludedSpell(kind, spellID)
  return GetSettings(kind).include[spellID] ~= nil
end

local function GetAuraOptions(parent, kind)
  local container = CreateFrame("Frame", nil, parent)

  local Refresh

  do
    local editBox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    editBox:SetNumeric(true)
    editBox:SetPoint("TOP", -90, 0)
    editBox:SetAutoFocus(false)
    editBox:SetSize(90, 22)
    local includeButton = CreateFrame("Button", nil, container, "UIPanelDynamicResizeButtonTemplate")
    includeButton:SetText(addonTable.Locales.INCLUDE)
    DynamicResizeButton_Resize(includeButton)
    local excludeButton = CreateFrame("Button", nil, container, "UIPanelDynamicResizeButtonTemplate")
    excludeButton:SetText(addonTable.Locales.EXCLUDE)
    DynamicResizeButton_Resize(excludeButton)
    includeButton:SetPoint("LEFT", editBox, "RIGHT", 5, 0)
    excludeButton:SetPoint("LEFT", includeButton, "RIGHT", 5, 0)

    editBox:SetScript("OnTextChanged", function()
      local spellID = tonumber(editBox:GetText()) or 0
      includeButton:SetEnabled(C_Spell.DoesSpellExist(spellID))
      excludeButton:SetEnabled(C_Spell.DoesSpellExist(spellID))
    end)

    includeButton:SetScript("OnClick", function()
      local spellID = tonumber(editBox:GetText()) or 0
      if not C_Spell.DoesSpellExist(spellID) then
        addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.THAT_SPELL_DOESNT_EXIST)
        return
      end
      GetSettings(kind).include[spellID] = 1
      GetSettings(kind).exclude[spellID] = nil
      Announce()
      Refresh()
    end)
    excludeButton:SetScript("OnClick", function()
      local spellID = tonumber(editBox:GetText()) or 0
      if not C_Spell.DoesSpellExist(spellID) then
        addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.THAT_SPELL_DOESNT_EXIST)
        return
      end
      GetSettings(kind).include[spellID] = nil
      GetSettings(kind).exclude[spellID] = true
      Announce()
      Refresh()
    end)
  end

  local ScrollBox = CreateFrame("Frame", nil, container, "WowScrollBox")
  ScrollBox:SetPoint("TOPLEFT", 0, -35)
  ScrollBox:SetPoint("BOTTOMRIGHT", 0, 10)
  local ScrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
  ScrollBar:SetPoint("TOPRIGHT", -10, -35)
  ScrollBar:SetPoint("BOTTOMRIGHT", -10, 10)
  --addonTable.Skins.AddFrame("TrimScrollBar", ScrollBar)
  local ScrollChild = CreateFrame("Frame", nil, ScrollBox)
  ScrollChild.scrollable = true
  ScrollUtil.InitScrollBoxWithScrollBar(ScrollBox, ScrollBar, CreateScrollBoxLinearView())
  ScrollUtil.AddManagedScrollBarVisibilityBehavior(ScrollBox, ScrollBar)
  ScrollBox:SetPanExtent(100)

  local pool = CreateFramePool("Frame", ScrollChild, nil,  nil, false, function(frame)
    frame:SetHeight(40)

    frame.Icon = frame:CreateTexture()
    frame.Icon:SetSize(25, 25)
    frame.Icon:SetPoint("LEFT", 10, 0)

    frame.Label = frame:CreateFontString(nil, nil, "GameFontHighlight")
    frame.Label:SetPoint("LEFT", frame.Icon, "RIGHT", 5, 0)
    frame.Label:SetWidth(160)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:SetWordWrap(false)

    frame.Dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    frame.Dropdown:SetWidth(100)
    frame.Dropdown:SetPoint("LEFT", frame.Label, "RIGHT", 10, 0)

    frame.Dropdown:SetupMenu(function(_, rootDescription)
      rootDescription:CreateRadio(addonTable.Locales.INCLUDE, function()
        return GetSettings(kind).include[frame.spellID] ~= nil
      end, function()
        local spellID = frame.spellID
        if not IsIncludedSpell(kind, frame.spellID) then
          GetSettings(kind).include[spellID] = 1
          GetSettings(kind).exclude[spellID] = nil
          Announce()
          Refresh()
        end
      end)
      rootDescription:CreateRadio(addonTable.Locales.EXCLUDE, function()
        return GetSettings(kind).exclude[frame.spellID] ~= nil
      end, function()
        local spellID = frame.spellID
        if not IsExcludedSpell(kind, frame.spellID) then
          GetSettings(kind).include[spellID] = nil
          GetSettings(kind).exclude[spellID] = true
          Announce()
          Refresh()
        end
      end)
    end)

    if addonTable.Constants.IsRetail then
      frame.prioritySlider = addonTable.CustomiseDialog.Components.GetSlider(frame, addonTable.Locales.PRIORITY, 1, 3, function(val)
        return val
      end, function(val)
        if IsIncludedSpell(kind, frame.spellID) and GetSettings(kind).include[frame.spellID] ~= val then
          GetSettings(kind).include[frame.spellID] = val
          Announce()
        end
      end)
      frame.prioritySlider:ClearAllPoints()
      frame.prioritySlider:SetPoint("LEFT", frame.Dropdown, "RIGHT", -20, 0)
      frame.prioritySlider:SetPoint("RIGHT", -45, 0)
    end

    frame.removeEntryButton = CreateFrame("Button", nil, frame)
    frame.removeEntryButton:SetSize(30, 30)
    frame.removeEntryButton:SetNormalAtlas("128-RedButton-Delete")
    frame.removeEntryButton:SetPushedAtlas("128-RedButton-Delete-Pressed")
    frame.removeEntryButton:SetHighlightAtlas("128-RedButton-Delete-Highlight")
    frame.removeEntryButton:SetPoint("RIGHT", -25, 0)
    frame.removeEntryButton:SetScript("OnClick", function()
      GetSettings(kind).include[frame.spellID] = nil
      GetSettings(kind).exclude[frame.spellID] = nil
      Announce()
      Refresh()
    end)

    function frame:Set(spellID)
      frame.spellID = spellID

      local settings = GetSettings(kind)
      if frame.prioritySlider then
        frame.prioritySlider:SetShown(settings.include[spellID] ~= nil)
        if settings.include[spellID] then
          frame.prioritySlider:SetValue(settings.include[spellID])
        end
      end
      frame.Icon:SetTexture(C_Spell.GetSpellTexture(spellID))
      if C_Spell.IsSpellDataCached(spellID) then
        frame.Label:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode(spellID) .. " " .. C_Spell.GetSpellName(spellID))
      elseif C_Spell.DoesSpellExist(spellID) then
        Spell:CreateFromSpellID(spellID):ContinueOnSpellLoad(function()
          frame.Label:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode(spellID) .. " " .. C_Spell.GetSpellName(spellID))
        end)
      else
        frame.Label:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode(spellID) .. " " .. NONE)
      end
    end
  end)

  Refresh = function()
    local settings = GetSettings(kind)
    local includeSpells = GetKeysArray(settings.include)
    local excludeSpells = GetKeysArray(settings.exclude)

    local list = includeSpells
    tAppendAll(includeSpells, excludeSpells)
    table.sort(list)

    pool:ReleaseAll()
    local offsetY = 0
    for _, spellID in ipairs(list) do
      local frame = pool:Acquire()
      frame:Set(spellID)
      frame:SetPoint("TOP", 0, offsetY)
      offsetY = offsetY - frame:GetHeight()
      frame:SetPoint("LEFT")
      frame:SetPoint("RIGHT")
      frame:Show()
    end
    ScrollChild:SetHeight(-offsetY)
    ScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
  end

  container:SetScript("OnShow", Refresh)

  return container
end

function addonTable.CustomiseDialog.GetAuraFilters(parent)
  local container = CreateFrame("Frame", nil, parent)

  local tabContainers = {
    {name = addonTable.Locales.DEBUFFS_ENEMY, container = GetAuraOptions(container, "debuffs")},
    {name = addonTable.Locales.BUFFS_FRIENDLY, container = GetAuraOptions(container, "buffs")},
    {name = addonTable.Locales.CROWD_CONTROL_ENEMY, container = GetAuraOptions(container, "crowdControl")},
  }

  local Tabs = {}
  local lastTab
  for _, setup in ipairs(tabContainers) do
    local tabContainer = setup.container
    tabContainer:SetPoint("TOPLEFT", addonTable.Constants.ButtonFrameOffset, -45)
    tabContainer:SetPoint("BOTTOMRIGHT")

    local tabButton = addonTable.CustomiseDialog.Components.GetTab(container, setup.name)
    if lastTab then
      tabButton:SetPoint("LEFT", lastTab, "RIGHT", 5, 0)
    else
      tabButton:SetPoint("TOPLEFT", 0 + addonTable.Constants.ButtonFrameOffset + 5, 0)
    end
    lastTab = tabButton
    tabContainer.button = tabButton
    tabButton:SetScript("OnClick", function()
      for _, c in ipairs(tabContainers) do
        PanelTemplates_DeselectTab(c.container.button)
        c.container:Hide()
      end
      PanelTemplates_SelectTab(tabButton)
      tabContainer:Show()
    end)
    tabContainer:Hide()

    table.insert(Tabs, tabButton)
  end
  container.Tabs = Tabs
  PanelTemplates_SetNumTabs(container, #container.Tabs)

  container:SetScript("OnShow", function()
    Tabs[1]:Click()
  end)

  return container
end
