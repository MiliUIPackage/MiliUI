---@class addonTablePlatynator
local addonTable = select(2, ...)

local customisers = {}

local function SetupGeneral(parent)
  local container = CreateFrame("Frame", nil, parent)

  local allFrames = {}
  local infoInset = CreateFrame("Frame", nil, container, "InsetFrameTemplate")
  do
    table.insert(allFrames, infoInset)
    infoInset:SetPoint("TOP")
    infoInset:SetPoint("LEFT", 20, 0)
    infoInset:SetPoint("RIGHT", -20, 0)
    infoInset:SetHeight(75)
    --addonTable.Skins.AddFrame("InsetFrame", infoInset)

    local logo = infoInset:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\Platynator\\Assets\\logo.png")
    logo:SetSize(52, 52)
    logo:SetPoint("LEFT", 8, 0)

    local name = infoInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    name:SetText(addonTable.Locales.PLATYNATOR)
    name:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, 0)

    local credit = infoInset:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    credit:SetText(addonTable.Locales.BY_PLUSMOUSE)
    credit:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 5, 0)

    local discordButton = CreateFrame("Button", nil, infoInset, "UIPanelDynamicResizeButtonTemplate")
    discordButton:SetText(addonTable.Locales.JOIN_THE_DISCORD)
    DynamicResizeButton_Resize(discordButton)
    discordButton:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 8, 0)
    discordButton:SetScript("OnClick", function()
      addonTable.Dialogs.ShowCopy("https://discord.gg/cUvDQT9JqK")
    end)
    --addonTable.Skins.AddFrame("Button", discordButton)
    local discordText = infoInset:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    discordText:SetPoint("LEFT", discordButton, "RIGHT", 10, 0)
    discordText:SetText(addonTable.Locales.DISCORD_DESCRIPTION)
  end

  do
    local header = addonTable.CustomiseDialog.Components.GetHeader(container, addonTable.Locales.DEVELOPMENT_IS_TIME_CONSUMING)
    header:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
    table.insert(allFrames, header)

    local donateFrame = CreateFrame("Frame", nil, container)
    donateFrame:SetPoint("LEFT")
    donateFrame:SetPoint("RIGHT")
    donateFrame:SetPoint("TOP", allFrames[#allFrames], "BOTTOM")
    donateFrame:SetHeight(40)
    local text = donateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("RIGHT", donateFrame, "CENTER", -50, 0)
    text:SetText(addonTable.Locales.DONATE)
    text:SetJustifyH("RIGHT")

    local button = CreateFrame("Button", nil, donateFrame, "UIPanelDynamicResizeButtonTemplate")
    button:SetText(addonTable.Locales.LINK)
    DynamicResizeButton_Resize(button)
    button:SetPoint("LEFT", donateFrame, "CENTER", -35, 0)
    button:SetScript("OnClick", function()
      addonTable.Dialogs.ShowCopy("https://linktr.ee/plusmouse")
    end)
    --addonTable.Skins.AddFrame("Button", button)
    table.insert(allFrames, donateFrame)
  end

  local globalScale = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.GLOBAL_SCALE, 1, 300, function(val) return ("%d%%"):format(val) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.GLOBAL_SCALE, value/100)
  end)
  globalScale:SetValue(addonTable.Config.Get(addonTable.Config.Options.GLOBAL_SCALE) * 100)

  globalScale:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  table.insert(allFrames, globalScale)

  local styleDropdown = addonTable.CustomiseDialog.GetStyleDropdown(container)
  styleDropdown:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  table.insert(allFrames, styleDropdown)

  local profileDropdown = addonTable.CustomiseDialog.Components.GetBasicDropdown(container, addonTable.Locales.PROFILES)
  do
    profileDropdown.SetValue = nil

    local clone = false
    local function ValidateAndCreate(profileName)
      if profileName ~= "" and PLATYNATOR_CONFIG.Profiles[profileName] == nil then
        local oldSkin = addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN)
        addonTable.Config.MakeProfile(profileName, clone)
        profileDropdown.DropDown:GenerateMenu()
        if addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN) ~= oldSkin then
          addonTable.Dialogs.ShowConfirm(addonTable.Locales.RELOAD_REQUIRED, YES, NO, function() ReloadUI() end)
        end
      end
    end
    profileDropdown:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, 0)
    profileDropdown.DropDown:SetupMenu(function(menu, rootDescription)
      local profiles = addonTable.Config.GetProfileNames()
      table.sort(profiles, function(a, b) return a:lower() < b:lower() end)
      for _, name in ipairs(profiles) do
        local button = rootDescription:CreateRadio(name ~= "DEFAULT" and name or LIGHTBLUE_FONT_COLOR:WrapTextInColorCode(DEFAULT), function()
          return PLATYNATOR_CURRENT_PROFILE == name
        end, function()
          addonTable.Config.ChangeProfile(name)
        end)
        if name ~= "DEFAULT" and name ~= PLATYNATOR_CURRENT_PROFILE then
          button:AddInitializer(function(button, description, menu)
            if InCombatLockdown() then
              return
            end
            local delete = MenuTemplates.AttachAutoHideButton(button, "transmog-icon-remove")
            delete:SetPoint("RIGHT")
            delete:SetSize(18, 18)
            delete.Texture:SetAtlas("transmog-icon-remove")
            delete:SetScript("OnClick", function()
              menu:Close()
              addonTable.Dialogs.ShowConfirm(addonTable.Locales.CONFIRM_DELETE_PROFILE_X:format(name), YES, NO, function()
                addonTable.Config.DeleteProfile(name)
              end)
            end)
            MenuUtil.HookTooltipScripts(delete, function(tooltip)
              GameTooltip_SetTitle(tooltip, DELETE)
            end)
          end)
        end
      end
      rootDescription:CreateButton(NORMAL_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.NEW_PROFILE_CLONE), function()
        clone = true
        addonTable.Dialogs.ShowEditBox(addonTable.Locales.ENTER_PROFILE_NAME, ACCEPT, CANCEL, ValidateAndCreate)
      end)
      rootDescription:CreateButton(NORMAL_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.NEW_PROFILE_BLANK), function()
        clone = false
        addonTable.Dialogs.ShowEditBox(addonTable.Locales.ENTER_PROFILE_NAME, ACCEPT, CANCEL, ValidateAndCreate)
      end)
      rootDescription:SetScrollMode(30 * 20)
    end)

    local function UpdateForRestrictions()
      if not profileDropdown:IsVisible() then
        return
      end
      profileDropdown.DropDown:SetEnabled(not addonTable.Utilities.IsChangesRestricted())
    end
    if C_Secrets and C_Secrets.HasSecretRestrictions() then
      local restrictionsMonitor = CreateFrame("Frame")
      restrictionsMonitor:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
      restrictionsMonitor:SetScript("OnEvent", function()
        C_Timer.After(0, UpdateForRestrictions)
      end)
      profileDropdown:SetScript("OnShow", UpdateForRestrictions)
    end
  end
  table.insert(allFrames, profileDropdown)

  do
    local exportButton = CreateFrame("Button", nil, container, "UIPanelDynamicResizeButtonTemplate")
    exportButton:SetPoint("TOPLEFT", allFrames[#allFrames], "BOTTOM", -33, -10)
    exportButton:SetText(addonTable.Locales.EXPORT)
    DynamicResizeButton_Resize(exportButton)
    exportButton:SetScript("OnClick", function()
      addonTable.Dialogs.ShowDualChoice(addonTable.Locales.WHAT_TO_EXPORT, addonTable.Locales.STYLE, addonTable.Locales.PROFILE,
        function()
          local design = CopyTable(addonTable.Core.GetDesignByName(addonTable.Config.Get(addonTable.Config.Options.STYLE)))
          design.addon = "Platynator"
          design.kind = "style"
          addonTable.Dialogs.ShowCopy("PLATY!1!" .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(design))))
        end, function()
          local options = addonTable.Config.DumpCurrentProfile()
          options.addon = "Platynator"
          options.version = 1
          options.kind = "profile"
          addonTable.Dialogs.ShowCopy("PLATY!1!" .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(options))))
        end
      )
    end)
    --addonTable.Skins.AddFrame("Button", exportButton)

    local importButton = CreateFrame("Button", nil, container, "UIPanelDynamicResizeButtonTemplate")
    importButton:SetPoint("TOPRIGHT", allFrames[#allFrames], "BOTTOM", -45, -10)
    importButton:SetText(addonTable.Locales.IMPORT)
    DynamicResizeButton_Resize(importButton)
    importButton:SetScript("OnClick", function()
      addonTable.CustomiseDialog.ShowImportDialog(function(text)
        local import
        if text:sub(1, 1) == "{" then
          local status
          status, import = pcall(C_EncodingUtil.DeserializeJSON, text)
          if not status or type(import) ~= "table" or import.addon ~= "Platynator" then
            addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.INVALID_IMPORT)
            return
          end
        else
          local prefix = text:match("^PLATY!1!")
          if not prefix then
            addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.INVALID_IMPORT)
            return
          end
          local status, decoded = pcall(C_EncodingUtil.DecodeBase64, text:sub(9))
          if not status then
            addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.INVALID_IMPORT)
            return
          end
          local status, decompressed = pcall(C_EncodingUtil.DecompressString, decoded)
          if not status then
            addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.INVALID_IMPORT)
            return
          end
          status, import = pcall(C_EncodingUtil.DeserializeCBOR, decompressed)
          if not status or type(import) ~= "table" or import.addon ~= "Platynator" then
            addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.INVALID_IMPORT)
            return
          end
        end
        if import.kind == nil or import.kind == "style" then
          addonTable.Dialogs.ShowEditBox(addonTable.Locales.ENTER_THE_NEW_STYLE_NAME, OKAY, CANCEL, function(value)
            local designs = addonTable.Config.Get(addonTable.Config.Options.DESIGNS)
            if designs[value] or value:match("^_") then
              addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.THAT_STYLE_NAME_ALREADY_EXISTS)
            else
              addonTable.CustomiseDialog.ImportData(import, value, false)
              styleDropdown.DropDown:GenerateMenu()
            end
          end)
        elseif import.kind == "profile" then
          addonTable.Dialogs.ShowDualChoice(addonTable.Locales.OVERWRITE_CURRENT_PROFILE, addonTable.Locales.OVERWRITE, addonTable.Locales.MAKE_NEW,
            function()
              addonTable.CustomiseDialog.ImportData(import, PLATYNATOR_CURRENT_PROFILE, true)
              profileDropdown.DropDown:GenerateMenu()
            end,
            function()
              addonTable.Dialogs.ShowEditBox(addonTable.Locales.ENTER_THE_NEW_PROFILE_NAME, OKAY, CANCEL, function(value)
                if PLATYNATOR_CONFIG.Profiles[value] == nil then
                  addonTable.CustomiseDialog.ImportData(import, value, false)
                  profileDropdown.DropDown:GenerateMenu()
                else
                  addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.THAT_PROFILE_NAME_ALREADY_EXISTS)
                end
              end)
            end
          )
        end
      end)
    end)
    --addonTable.Skins.AddFrame("Button", importButton)
  end

  local blizzardWidgetScale = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.BLIZZARD_EXTRA_WIDGETS_SCALE, 1, 300, function(val) return ("%d%%"):format(val) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.BLIZZARD_WIDGET_SCALE, value/100)
  end)
  blizzardWidgetScale:SetValue(addonTable.Config.Get(addonTable.Config.Options.BLIZZARD_WIDGET_SCALE) * 100)

  blizzardWidgetScale:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -70)
  table.insert(allFrames, blizzardWidgetScale)

  container:SetScript("OnShow", function()
    for _, f in ipairs(allFrames) do
      if f.SetValue and f.option then
        f:SetValue(addonTable.Config.Get(f.option))
      end
    end
    globalScale:SetValue(addonTable.Config.Get(addonTable.Config.Options.GLOBAL_SCALE) * 100)
    blizzardWidgetScale:SetValue(addonTable.Config.Get(addonTable.Config.Options.BLIZZARD_WIDGET_SCALE) * 100)
  end)

  return container
end

local function SetupFont(parent)
  local container = CreateFrame("Frame", nil, parent)

  local allFrames = {}

  local styleDropdown = addonTable.CustomiseDialog.GetStyleDropdown(container)
  styleDropdown:SetPoint("TOP")
  table.insert(allFrames, styleDropdown)

  local fontDropdown = addonTable.CustomiseDialog.Components.GetBasicDropdown(container, addonTable.Locales.FONT)
  fontDropdown:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  table.insert(allFrames, fontDropdown)

  local outlineCheckbox = addonTable.CustomiseDialog.Components.GetCheckbox(container, addonTable.Locales.SHOW_OUTLINE, 28, function(value)
    local design = addonTable.CustomiseDialog.GetCurrentDesign()
    if value ~= design.font.outline then
      design.font.outline = value
      if addonTable.Config.Get(addonTable.Config.Options.STYLE):match("^_") then
        addonTable.Config.Set(addonTable.Config.Options.STYLE, addonTable.Constants.CustomName)
      end
      addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.Design] = true})
    end
  end)
  outlineCheckbox:SetPoint("TOP", allFrames[#allFrames], "BOTTOM")
  table.insert(allFrames, outlineCheckbox)

  local shadowCheckbox = addonTable.CustomiseDialog.Components.GetCheckbox(container, addonTable.Locales.SHOW_SHADOW, 28, function(value)
    local design = addonTable.CustomiseDialog.GetCurrentDesign()
    if value ~= design.font.shadow then
      design.font.shadow = value
      if addonTable.Config.Get(addonTable.Config.Options.STYLE):match("^_") then
        addonTable.Config.Set(addonTable.Config.Options.STYLE, addonTable.Constants.CustomName)
      end
      addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.Design] = true})
    end
  end)
  shadowCheckbox:SetPoint("TOP", allFrames[#allFrames], "BOTTOM")
  table.insert(allFrames, shadowCheckbox)

  local fontFixCheckbox = addonTable.CustomiseDialog.Components.GetCheckbox(container, addonTable.Locales.ENABLE_IF_LINES_FALLING_OFF_FONT, 28, function(value)
    local design = addonTable.CustomiseDialog.GetCurrentDesign()
    if value ~= not design.font.slug then
      design.font.slug = not value
      if addonTable.Config.Get(addonTable.Config.Options.STYLE):match("^_") then
        addonTable.Config.Set(addonTable.Config.Options.STYLE, addonTable.Constants.CustomName)
      end
      addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.Design] = true})
    end
  end)
  fontFixCheckbox:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  table.insert(allFrames, fontFixCheckbox)

  local function Update()
    local design = addonTable.CustomiseDialog.GetCurrentDesign()
    outlineCheckbox:SetValue(design.font.outline)
    shadowCheckbox:SetValue(design.font.shadow)
    fontFixCheckbox:SetValue(not design.font.slug)

    for _, f in ipairs(allFrames) do
      if f.DropDown then
        f:SetValue()
      end
    end

    local LibSharedMedia = LibStub("LibSharedMedia-3.0")
    local fonts = CopyTable(LibSharedMedia:List("font"))
    table.sort(fonts)

    fontDropdown.DropDown:SetupMenu(function(_, rootDescription)
      for index, label in ipairs(fonts) do
        local radio = rootDescription:CreateRadio(label,
          function()
            local asset = addonTable.CustomiseDialog.GetCurrentDesign().font.asset
            return asset == label or addonTable.Constants.OldFontMapping[asset] == label
          end,
          function()
            local design = addonTable.CustomiseDialog.GetCurrentDesign()
            local oldAsset = design.font.asset
            if label ~= oldAsset then
              design.font.asset = label
              if addonTable.Config.Get(addonTable.Config.Options.STYLE):match("^_") then
                addonTable.Config.Set(addonTable.Config.Options.STYLE, addonTable.Constants.CustomName)
              end
              addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.Design] = true})
            end
          end
        )
        radio:AddInitializer(function(button, elementDescription, menu)
          button.fontString:SetFontObject(addonTable.Core.GetFontByID(label))
        end)
      end
      rootDescription:SetScrollMode(30 * 20)
    end)
  end

  addonTable.CallbackRegistry:RegisterCallback("SettingChanged", function(_, name)
    if name == addonTable.Config.Options.STYLE and container:IsVisible() then
      Update()
    end
  end)

  container:SetScript("OnShow", Update)

  return container
end

function addonTable.CustomiseDialog.GetStyleDropdown(parent)
  local styleDropdown = addonTable.CustomiseDialog.Components.GetBasicDropdown(parent, addonTable.Locales.STYLE)
  styleDropdown.option = addonTable.Config.Options.STYLE

  styleDropdown.DropDown:SetupMenu(function(_, rootDescription)
    local currentStyle = addonTable.Config.Get(addonTable.Config.Options.STYLE)
    local styles = {}
    for key, value in pairs(addonTable.Config.Get(addonTable.Config.Options.DESIGNS)) do
      if key ~= addonTable.Constants.CustomName then
        table.insert(styles, {label = key, value = key})
      end
    end
    table.sort(styles, function(a, b) return a.label < b.label end)
    for _, entry in ipairs(styles) do
      local button = rootDescription:CreateRadio(entry.label, function()
        return entry.value == currentStyle
      end, function()
          addonTable.Config.Set(addonTable.Config.Options.STYLE, entry.value)
      end)

      button:AddInitializer(function(button, description, menu)
        if InCombatLockdown() then
          return
        end
        local delete = MenuTemplates.AttachAutoHideButton(button, "transmog-icon-remove")
        delete:SetPoint("RIGHT")
        delete:SetSize(18, 18)
        delete.Texture:SetAtlas("transmog-icon-remove")
        delete:SetScript("OnClick", function()
          menu:Close()
          addonTable.Dialogs.ShowConfirm(addonTable.Locales.CONFIRM_DELETE_STYLE_X:format(entry.label), YES, NO, function()
            addonTable.Config.Get(addonTable.Config.Options.DESIGNS)[entry.value] = nil
            ---@type table
            local assignments = addonTable.Config.Get(addonTable.Config.Options.DESIGN_ASSIGNMENTS)
            for _, a in ipairs(assignments) do
              if a.style == entry.value then
                if a.simplified then
                  a.style = "_hare_simplified"
                else
                  a.style = addonTable.Constants.CustomName
                end
              end
            end
            if addonTable.Config.Get(addonTable.Config.Options.STYLE) == entry.value then
              addonTable.Config.Set(addonTable.Config.Options.STYLE, addonTable.Constants.CustomName)
            end
            addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.Design] = true})
          end)
        end)
        MenuUtil.HookTooltipScripts(delete, function(tooltip)
          GameTooltip_SetTitle(tooltip, DELETE)
        end)
      end)
    end

    local button = rootDescription:CreateRadio(addonTable.Locales.CUSTOM, function()
      return addonTable.Constants.CustomName == currentStyle
    end, function()
      addonTable.Config.Set(addonTable.Config.Options.STYLE, addonTable.Constants.CustomName)
    end)

    do
      rootDescription:CreateDivider()
      local createButton = rootDescription:CreateButton(GREEN_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.SAVE_AS), function()
        addonTable.Dialogs.ShowEditBox(addonTable.Locales.ENTER_THE_NEW_STYLE_NAME, OKAY, CANCEL, function(value)
          local allDesigns = addonTable.Config.Get(addonTable.Config.Options.DESIGNS)
          if allDesigns[value] or value:match("^_") then
            addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.THAT_STYLE_NAME_ALREADY_EXISTS)
          else
            allDesigns[value] = CopyTable(addonTable.Core.GetDesignByName(currentStyle))
            addonTable.Config.Set(addonTable.Config.Options.STYLE, value) 
          end
        end)
      end)
      rootDescription:CreateDivider()
    end

    rootDescription:CreateTitle(addonTable.Locales.IMPORT_DEFAULT_STYLE)

    local stylesBuiltIn = {}
    for key, label in pairs(addonTable.Design.NameMap) do
      if key ~= addonTable.Constants.CustomName then
        table.insert(stylesBuiltIn, {label = label, value = key})
      end
    end
    table.sort(stylesBuiltIn, function(a, b) return a.label < b.label end)

    for _, entry in ipairs(stylesBuiltIn) do
      local button = rootDescription:CreateRadio(entry.label, function()
        return entry.value == currentStyle
      end, function()
        addonTable.Dialogs.ShowDualChoice(addonTable.Locales.THIS_WILL_OVERWRITE_STYLE_CUSTOM, addonTable.Locales.OVERWRITE, addonTable.Locales.SAVE_CUSTOM_AS, function()
          addonTable.Config.Set(addonTable.Config.Options.STYLE, entry.value)
        end, function()
          addonTable.Dialogs.ShowEditBox(addonTable.Locales.ENTER_THE_CUSTOM_STYLE_NAME, OKAY, CANCEL, function(value)
            local allDesigns = addonTable.Config.Get(addonTable.Config.Options.DESIGNS)
            if allDesigns[value] or value:match("^_") then
              addonTable.Dialogs.ShowAcknowledge(addonTable.Locales.THAT_STYLE_NAME_ALREADY_EXISTS)
            else
              allDesigns[value] = CopyTable(addonTable.Core.GetDesignByName(addonTable.Constants.CustomName))
              addonTable.Config.Set(addonTable.Config.Options.STYLE, entry.value)
            end
          end)
        end)
      end)
    end

    rootDescription:SetScrollMode(30 * 20)
  end)

  styleDropdown:SetPoint("TOP")

  addonTable.CallbackRegistry:RegisterCallback("SettingChanged", function(_, name)
    if name == addonTable.Config.Options.STYLE then
      styleDropdown:SetValue()
    end
  end)

  return styleDropdown
end

function addonTable.CustomiseDialog.GetCurrentDesign()
  local currentStyle = addonTable.Config.Get(addonTable.Config.Options.STYLE)
  if currentStyle == addonTable.Constants.CustomName or not currentStyle:match("^_") then
    return addonTable.Config.Get(addonTable.Config.Options.DESIGNS)[currentStyle]
  else
    return addonTable.Config.Get(addonTable.Config.Options.DESIGNS)[addonTable.Constants.CustomName]
  end
end

local TabSetups = {
  {callback = SetupGeneral, name = addonTable.Locales.GENERAL, include = true},
  {callback = addonTable.CustomiseDialog.GetMainDesigner, name = addonTable.Locales.DESIGNER, include = true},
  {callback = addonTable.CustomiseDialog.GetStyleSelection, name = addonTable.Locales.STYLE_SELECT, restricted = true, include = true},
  {callback = addonTable.CustomiseDialog.GetBehaviour, name = addonTable.Locales.BEHAVIOUR, include = true},
  {callback = addonTable.CustomiseDialog.GetAuraFilters, name = addonTable.Locales.AURAS, include = addonTable.Constants.IsMidnightNext},
  {callback = SetupFont, name = addonTable.Locales.FONT, include = true},
}

TabSetups = tFilter(TabSetups, function(a) return a.include end,  true)

function addonTable.CustomiseDialog.Toggle()
  if customisers[addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN)] then
    local frame = customisers[addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN)]
    frame:SetShown(not frame:IsVisible())
    return
  end

  local frame = CreateFrame("Frame", "PlatynatorCustomiseDialog" .. addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN), UIParent, "ButtonFrameTemplate")
  frame:SetToplevel(true)
  customisers[addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN)] = frame
  table.insert(UISpecialFrames, frame:GetName())
  frame:SetSize(600, 830)
  frame:SetPoint("CENTER")
  frame:Hide()

  if frame:GetHeight() >= UIParent:GetHeight() then
    frame:SetScale(UIParent:GetHeight() / frame:GetHeight() * 0.99)
  end

  frame.CloseButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function()
    frame:StartMoving()
    frame:SetUserPlaced(false)
  end)
  frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    frame:SetUserPlaced(false)
  end)

  ButtonFrameTemplate_HidePortrait(frame)
  ButtonFrameTemplate_HideButtonBar(frame)
  frame.Inset:Hide()
  frame:EnableMouse(true)
  frame:SetScript("OnMouseWheel", function() end)

  frame:SetTitle(addonTable.Locales.CUSTOMISE_PLATYNATOR)

  local containers = {}
  local lastTab
  local Tabs = {}
  local UpdateForRestrictions
  for _, setup in ipairs(TabSetups) do
    local tabContainer = setup.callback(frame)
    tabContainer:SetPoint("TOPLEFT", addonTable.Constants.ButtonFrameOffset, -65)
    tabContainer:SetPoint("BOTTOMRIGHT")

    local tabButton = addonTable.CustomiseDialog.Components.GetTab(frame, setup.name)
    if lastTab then
      tabButton:SetPoint("LEFT", lastTab, "RIGHT", 5, 0)
    else
      tabButton:SetPoint("TOPLEFT", 0 + addonTable.Constants.ButtonFrameOffset + 5, -25)
    end
    lastTab = tabButton
    tabContainer.button = tabButton
    tabButton:SetScript("OnClick", function()
      for _, c in ipairs(containers) do
        PanelTemplates_DeselectTab(c.button)
        c:Hide()
      end
      PanelTemplates_SelectTab(tabButton)
      tabContainer:Show()
      UpdateForRestrictions()
    end)
    tabContainer:Hide()

    table.insert(Tabs, tabButton)
    table.insert(containers, tabContainer)
  end
  frame.Tabs = Tabs
  PanelTemplates_SetNumTabs(frame, #frame.Tabs)

  frame:SetScript("OnShow", function()
    local tabsWidth = frame.Tabs[#frame.Tabs]:GetRight() - frame.Tabs[1]:GetLeft()
    frame:SetWidth(math.max(frame:GetWidth(), tabsWidth + 20))

    local shownContainer = FindValueInTableIf(containers, function(c) return c:IsShown() end)
    if shownContainer then
      PanelTemplates_SetTab(frame, tIndexOf(containers, shownContainer))
    end

    UpdateForRestrictions()
  end)

  UpdateForRestrictions = function()
    if not frame:IsVisible() then
      return
    end

    if addonTable.Utilities.IsChangesRestricted() then
      for index, tab in ipairs(Tabs) do
        local details = TabSetups[index]
        local container = containers[index]
        if details.restricted then
          if container:IsShown() then
            Tabs[1]:Click()
          end
          tab:Disable()
          tab:SetAlpha(0.5)
        else
          if not container:IsShown() then
            tab:Enable()
          else
            PanelTemplates_SetTab(frame, index)
          end
          tab:SetAlpha(1)
        end
      end
    else
      for index, tab in ipairs(Tabs) do
        local container = containers[index]
        if not container:IsShown() then
          tab:Enable()
        else
          PanelTemplates_SetTab(frame, index)
        end
        tab:SetAlpha(1)
      end
    end
  end

  containers[1].button:Click()

  if C_Secrets and C_Secrets.HasSecretRestrictions() then
    local restrictionsMonitor = CreateFrame("Frame")
    restrictionsMonitor:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    restrictionsMonitor:SetScript("OnEvent", function()
      C_Timer.After(0, UpdateForRestrictions)
    end)
  end

  frame:Show()

  --addonTable.Skins.AddFrame("ButtonFrame", frame, {"customise"})
end
