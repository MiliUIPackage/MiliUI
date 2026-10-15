---@class addonTablePlatynator
local addonTable = select(2, ...)

local function GetColor(rgb)
  local color = CreateColorFromRGBHexString(rgb)
  return {r = color.r, g = color.g, b = color.b}
end

local function Announce()
  addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.Design] = true})
end

local function GetSettings(kind)
  return addonTable.Config.Get(addonTable.Config.Options.AURA_HIGHLIGHTS)[addonTable.Display.Utilities.GetSpecializationID()][kind]
end

local function GetAuraOptions(parent, kind)
  local container = CreateFrame("Frame", nil, parent)

  local Refresh
  local function GetStaticRow(frame)
    frame:SetHeight(40)

    frame.Icon = frame:CreateTexture()
    frame.Icon:SetSize(25, 25)
    frame.Icon:SetPoint("LEFT", 10, 0)

    frame.Label = frame:CreateFontString(nil, nil, "GameFontHighlight")
    frame.Label:SetPoint("LEFT", frame.Icon, "RIGHT", 5, 0)
    frame.Label:SetWidth(160)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:SetWordWrap(false)

    frame.enabledCheckbox = addonTable.CustomiseDialog.Components.GetCheckbox(frame, addonTable.Locales.ENABLE, -30, function(value)
      if frame.setup.enabled ~= value then
        frame.setup.enabled = value
        Announce()
      end
    end)

    frame.enabledCheckbox:ClearAllPoints()
    frame.enabledCheckbox:SetPoint("TOP", frame, 0, 0)
    frame.enabledCheckbox:SetPoint("LEFT", frame.Label, "RIGHT", 10, 0)
    frame.enabledCheckbox:SetPoint("RIGHT", frame, -180, 0)

    frame.colorPicker = addonTable.CustomiseDialog.Components.GetColorPicker(frame, addonTable.Locales.COLOR, 3, function(newColor)
      frame.setup.color = newColor
      Announce()
    end)
    frame.colorPicker:SetPoint("LEFT", frame.enabledCheckbox, "RIGHT", 0, 0)
    frame.colorPicker:SetPoint("RIGHT", frame, -25, 0)

    function frame:Set(setup)
      frame.setup = setup

      frame.colorPicker:SetValue(setup.color)
      frame.enabledCheckbox:SetValue(setup.enabled)
    end

    return frame
  end

  local function GetDynamicRow(frame)
    frame:SetHeight(40)

    frame.Icon = frame:CreateTexture()
    frame.Icon:SetSize(25, 25)
    frame.Icon:SetPoint("LEFT", 40, 0)

    frame.Label = frame:CreateFontString(nil, nil, "GameFontHighlight")
    frame.Label:SetPoint("LEFT", frame.Icon, "RIGHT", 5, 0)
    frame.Label:SetWidth(200)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:SetWordWrap(false)

    frame.shiftUp = CreateFrame("Button", nil, frame)
    frame.shiftUp:SetSize(16, 20)
    frame.shiftUp:SetNormalAtlas("bag-arrow")
    frame.shiftUp:GetNormalTexture():SetRotation(- math.pi / 2)
    frame.shiftUp:GetNormalTexture():SetSize(16, 10)
    frame.shiftUp:SetScript("OnEnter", function()
      frame.shiftUp:GetNormalTexture():SetAlpha(0.5)
    end)
    frame.shiftUp:SetScript("OnLeave", function()
      frame.shiftUp:GetNormalTexture():SetAlpha(1)
    end)
    frame.shiftDown = CreateFrame("Button", nil, frame)
    frame.shiftDown:SetSize(16, 20)
    frame.shiftDown:SetNormalAtlas("bag-arrow")
    frame.shiftDown:GetNormalTexture():SetRotation(math.pi / 2)
    frame.shiftDown:GetNormalTexture():SetSize(16, 10)
    frame.shiftDown:SetScript("OnEnter", function()
      frame.shiftDown:GetNormalTexture():SetAlpha(0.5)
    end)
    frame.shiftDown:SetScript("OnLeave", function()
      frame.shiftDown:GetNormalTexture():SetAlpha(1)
    end)
    frame.shiftUp:SetPoint("TOPLEFT", 5, 0)
    frame.shiftDown:SetPoint("TOPLEFT", 5, -20)

    frame.shiftUp:SetScript("OnClick", function()
      local all = GetSettings(kind).auras
      local index = tIndexOf(all, frame.setup)
      all[index] = all[index - 1]
      all[index - 1] = frame.setup
      Announce()
      Refresh()
    end)
    frame.shiftDown:SetScript("OnClick", function()
      local all = GetSettings(kind).auras
      local index = tIndexOf(all, frame.setup)
      all[index] = all[index + 1]
      all[index + 1] = frame.setup
      Announce()
      Refresh()
    end)

    frame.colorPicker = addonTable.CustomiseDialog.Components.GetColorPicker(frame, addonTable.Locales.COLOR, -80, function(newColor)
      frame.setup.color = newColor
      Announce()
    end)
    frame.colorPicker:SetPoint("LEFT", frame.Label, "RIGHT", 0, 0)
    frame.colorPicker:SetPoint("RIGHT", frame, -55, 0)

    frame.removeEntryButton = CreateFrame("Button", nil, frame)
    frame.removeEntryButton:SetSize(30, 30)
    frame.removeEntryButton:SetNormalAtlas("128-RedButton-Delete")
    frame.removeEntryButton:SetPushedAtlas("128-RedButton-Delete-Pressed")
    frame.removeEntryButton:SetHighlightAtlas("128-RedButton-Delete-Highlight")
    frame.removeEntryButton:SetPoint("RIGHT", -25, 0)
    frame.removeEntryButton:SetScript("OnClick", function()
      local all = GetSettings(kind).auras
      local index = tIndexOf(all, frame.setup)
      if index then
        table.remove(all, index)
      end
      Announce()
      Refresh()
    end)
    addonTable.Skins.AddFrame("IconButton", frame.removeEntryButton, {"delete"})

    function frame:Set(setup)
      frame.setup = setup

      frame.colorPicker:SetValue(setup.color)

      frame.Icon:SetTexture(C_Spell.GetSpellTexture(setup.spellID))
      if C_Spell.IsSpellDataCached(setup.spellID) then
        frame.Label:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode(setup.spellID) .. " " .. C_Spell.GetSpellName(setup.spellID))
      elseif C_Spell.DoesSpellExist(setup.spellID) then
        Spell:CreateFromSpellID(setup.spellID):ContinueOnSpellLoad(function()
          frame.Label:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode(setup.spellID) .. " " .. C_Spell.GetSpellName(setup.spellID))
        end)
      else
        frame.Label:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode(setup.spellID) .. " " .. NONE)
      end

      local all = GetSettings(kind).auras
      local index = tIndexOf(all, frame.setup)
      frame.shiftUp:SetShown(index > 1)
      frame.shiftDown:SetShown(index < #all)
    end
  end
  local pool = CreateFramePool("Frame", container, nil, nil, false, GetDynamicRow)

  local staticRows = {
    GetStaticRow(CreateFrame("Frame", nil, container)),
    GetStaticRow(CreateFrame("Frame", nil, container)),
  }
  staticRows[1].Label:SetText(addonTable.Locales.WHEN_ALL_APPLIED)
  staticRows[2].Label:SetText(addonTable.Locales.WHEN_NONE_APPLIED)

  do
    local editBox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    editBox:SetNumeric(true)
    editBox:SetPoint("TOP", -90, -90)
    editBox:SetAutoFocus(false)
    editBox:SetSize(90, 22)
    addonTable.Skins.AddFrame("EditBox", editBox)
    local addForColor = CreateFrame("Button", nil, container, "UIPanelDynamicResizeButtonTemplate")
    addForColor:SetText(addonTable.Locales.COLOR)
    DynamicResizeButton_Resize(addForColor)
    addForColor:SetPoint("LEFT", editBox, "RIGHT", 10, 0)
    addonTable.Skins.AddFrame("Button", addForColor)

    editBox:SetScript("OnTextChanged", function()
      local spellID = tonumber(editBox:GetText()) or 0
      addForColor:SetEnabled(C_Spell.DoesSpellExist(spellID))
    end)

    addForColor:SetScript("OnClick", function()
      local spellID = tonumber(editBox:GetText()) or 0
      if not C_Spell.DoesSpellExist(spellID) then
        addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.THAT_SPELL_DOESNT_EXIST)
        return
      end
      table.insert(GetSettings(kind).auras, {spellID = spellID, color = GetColor("ffffff"), enabled = true})
      Announce()
      Refresh()
    end)

    local tooltipsCheckbox = addonTable.CustomiseDialog.Components.GetCheckbox(container, addonTable.Locales.ID_IN_TOOLTIPS, -30, function(value)
      C_CVar.SetCVar("tooltipShowAuraSpellIDs", value and 1 or 0)
    end)
    tooltipsCheckbox:SetPoint("LEFT", addForColor, "RIGHT", 10, 0)
    tooltipsCheckbox:SetPoint("RIGHT")
    tooltipsCheckbox:SetScript("OnShow", function()
      tooltipsCheckbox:SetValue(C_CVar.GetCVarBool("tooltipShowAuraSpellIDs"))
    end)
  end

  local individualColors = addonTable.CustomiseDialog.Components.GetCheckbox(container, addonTable.Locales.SHOW_INDIVIDUAL_COLORS, 28, function(newValue)
    local settings = GetSettings(kind)
    if settings.showIndividualColors ~= newValue then
      settings.showIndividualColors = newValue
      Announce()
    end
  end)
  individualColors:SetPoint("BOTTOM", 0, 60)
  local modeDropdown = addonTable.CustomiseDialog.Components.GetBasicDropdown(container, addonTable.Locales.DISPLAY_MODE, function(value)
    return value == GetSettings(kind).mode
  end, function(value)
    local settings = GetSettings(kind)
    if settings.mode ~= value then
      GetSettings(kind).mode = value
      Announce()
    end
  end)
  modeDropdown:Init({
    addonTable.Locales.HEALTH_BAR,
    addonTable.Locales.AURA_HIGHLIGHT,
  }, {
      "health",
      "highlight"
  })
  modeDropdown:SetPoint("BOTTOM", 0, 20)

  Refresh = function()
    staticRows[1]:SetPoint("TOP", container)
    staticRows[2]:SetPoint("TOP", staticRows[1], "BOTTOM")
    local settings = GetSettings(kind)
    local rows = {}
    local lastRow
    tAppendAll(rows, staticRows)
    pool:ReleaseAll()
    for _, details in ipairs(settings.auras) do
      local row = pool:Acquire()
      row:Show()
      if lastRow then
        row:SetPoint("TOP", lastRow, "BOTTOM")
      else
        row:SetPoint("TOP", container, 0, -120)
      end
      table.insert(rows, row)
      lastRow = row
      row:Set(details)
    end

    rows[1]:Set(settings.showAll)
    rows[2]:Set(settings.showNone)
    for index, row in ipairs(rows) do
      row:SetPoint("LEFT")
      row:SetPoint("RIGHT")
    end
    individualColors:SetValue(settings.showIndividualColors)
    modeDropdown:SetValue(settings.mode)
  end

  container:SetScript("OnShow", Refresh)

  return container
end

function addonTable.CustomiseDialog.GetAuraHighlights(parent)
  local container = CreateFrame("Frame", nil, parent)

  local tabContainers = {
    {name = addonTable.Locales.DEBUFFS_ENEMY, container = GetAuraOptions(container, "debuffs")},
    {name = addonTable.Locales.BUFFS_FRIENDLY, container = GetAuraOptions(container, "buffs")},
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
