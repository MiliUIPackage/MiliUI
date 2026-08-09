---@class addonTablePlatynator
local addonTable = select(2, ...)

local function GetCommonOptions(parent)
  local container = CreateFrame("Frame", nil, parent)

  local allFrames = {}

  local showNameplatesWhenNeededCheckbox = addonTable.CustomiseDialog.Components.GetCheckbox(container, addonTable.Locales.SHOW_NAMEPLATES_ONLY_IF_NEEDED, 28, function(value)
    if InCombatLockdown() then
      return
    end
    addonTable.Config.Set(addonTable.Config.Options.SHOW_NAMEPLATES_ONLY_NEEDED, value)
  end)
  showNameplatesWhenNeededCheckbox.option = addonTable.Config.Options.SHOW_NAMEPLATES_ONLY_NEEDED
  showNameplatesWhenNeededCheckbox:SetPoint("TOP")
  table.insert(allFrames, showNameplatesWhenNeededCheckbox)

  local applyNameplatesDropdown = addonTable.CustomiseDialog.Components.GetBasicDropdown(container, addonTable.Locales.USE_NAMEPLATES_FOR)
  applyNameplatesDropdown:SetPoint("TOP", allFrames[#allFrames], "BOTTOM")
  do
    local function GetCheckbox(rootDescription, label, value)
      return rootDescription:CreateCheckbox(label, function()
        return addonTable.Config.Get(addonTable.Config.Options.SHOW_NAMEPLATES)[value]
      end, function()
        if InCombatLockdown() then
          return
        end
        local current = addonTable.Config.Get(addonTable.Config.Options.SHOW_NAMEPLATES)[value]
        addonTable.Config.Get(addonTable.Config.Options.SHOW_NAMEPLATES)[value] = not current
        addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.ShowBehaviour] = true})
      end)
    end

    applyNameplatesDropdown.DropDown:SetDefaultText(NONE)
    applyNameplatesDropdown.DropDown:SetupMenu(function(_, rootDescription)
      if C_CVar.GetCVarInfo("nameplateShowFriendlyPlayers") ~= nil then
        local friendlyPlayer = GetCheckbox(rootDescription, addonTable.Locales.FRIENDLY_PLAYERS, "friendlyPlayer")
        local friendlyMinions = GetCheckbox(friendlyPlayer, addonTable.Locales.MINIONS, "friendlyMinion")
        GetCheckbox(friendlyMinions, addonTable.Locales.GUARDIANS, "friendlyMinionGuardian")
        GetCheckbox(friendlyMinions, addonTable.Locales.PETS, "friendlyMinionPet")
        GetCheckbox(friendlyMinions, addonTable.Locales.TOTEMS, "friendlyMinionTotem")
        GetCheckbox(rootDescription, addonTable.Locales.FRIENDLY_NPCS, "friendlyNPC")
        local enemies = GetCheckbox(rootDescription, addonTable.Locales.ENEMIES, "enemy")
        local enemyMinions = GetCheckbox(enemies, addonTable.Locales.MINIONS, "enemyMinion")
        GetCheckbox(enemyMinions, addonTable.Locales.GUARDIANS, "enemyMinionGuardian")
        GetCheckbox(enemyMinions, addonTable.Locales.PETS, "enemyMinionPet")
        GetCheckbox(enemyMinions, addonTable.Locales.TOTEMS, "enemyMinionTotem")
        GetCheckbox(enemies, addonTable.Locales.MINORS, "enemyMinor")
      else
        local friendlyPlayer = GetCheckbox(rootDescription, addonTable.Locales.PLAYERS_AND_FRIENDS, "friendlyPlayer")
        GetCheckbox(friendlyPlayer, addonTable.Locales.FRIENDLY_NPCS, "friendlyNPC")
        local friendlyMinions = GetCheckbox(friendlyPlayer, addonTable.Locales.MINIONS, "friendlyMinion")
        GetCheckbox(friendlyMinions, addonTable.Locales.GUARDIANS, "friendlyMinionGuardian")
        GetCheckbox(friendlyMinions, addonTable.Locales.PETS, "friendlyMinionPet")
        GetCheckbox(friendlyMinions, addonTable.Locales.TOTEMS, "friendlyMinionTotem")
        local enemies = GetCheckbox(rootDescription, addonTable.Locales.ENEMIES, "enemy")
        local enemyMinions = GetCheckbox(enemies, addonTable.Locales.MINIONS, "enemyMinion")
        GetCheckbox(enemyMinions, addonTable.Locales.GUARDIANS, "enemyMinionGuardian")
        GetCheckbox(enemyMinions, addonTable.Locales.PETS, "enemyMinionPet")
        GetCheckbox(enemyMinions, addonTable.Locales.TOTEMS, "enemyMinionTotem")
        GetCheckbox(enemies, addonTable.Locales.MINORS, "enemyMinor")
      end
    end)
  end
  applyNameplatesDropdown.DropDown:SetSelectionText(function(selections)
    local result = {}
    local current = addonTable.Config.Get(addonTable.Config.Options.SHOW_NAMEPLATES)
    if current.friendlyPlayer then
      if C_CVar.GetCVarInfo("nameplateShowFriendlyPlayers") ~= nil then
        table.insert(result, addonTable.Locales.FRIENDLY_PLAYERS)
      else
        table.insert(result, addonTable.Locales.PLAYERS_AND_FRIENDS)
      end
      if current.friendlyMinion then
        table.insert(result, addonTable.Locales.MINIONS)
      end
    end
    if current.friendlyNPC then
      table.insert(result, addonTable.Locales.FRIENDLY_NPCS)
    end
    if current.enemy then
      table.insert(result, addonTable.Locales.ENEMIES)
      if current.enemyMinion then
        table.insert(result, addonTable.Locales.MINIONS)
      end
      if current.enemyMinor then
        table.insert(result, addonTable.Locales.MINORS)
      end
    end

    return table.concat(result, ", ")
  end)
  table.insert(allFrames, applyNameplatesDropdown)

  local friendlyInInstancesDropdown = addonTable.CustomiseDialog.Components.GetBasicDropdown(container, addonTable.Locales.SHOW_FRIENDLY_IN_INSTANCES, function(value)
    return addonTable.Config.Get(addonTable.Config.Options.SHOW_FRIENDLY_IN_INSTANCES) == value
  end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.SHOW_FRIENDLY_IN_INSTANCES, value)
    addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {
      [addonTable.Constants.RefreshReason.ShowBehaviour] = true,
      --[addonTable.Constants.RefreshReason.Design] = true,
    })
  end)
  friendlyInInstancesDropdown:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  do
    local values = {
      "never",
      "always",
    }
    local labels = {
      addonTable.Locales.NEVER,
      addonTable.Locales.ALWAYS_ALL,
    }
    if C_CVar.GetCVarInfo("nameplateShowOnlyNameForFriendlyPlayerUnits") then
      table.insert(values, 2, "name_only")
      table.insert(labels, 2, addonTable.Locales.NAME_ONLY_PLAYERS)
    end
    friendlyInInstancesDropdown:Init(labels, values)
  end
  table.insert(allFrames, friendlyInInstancesDropdown)

  if C_CVar.GetCVarInfo("nameplateShowOnlyNameForFriendlyPlayerUnits") then
    local nameOnlySizeSlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.INSTANCES_NAME_ONLY_SIZE, 1, 5, function(value) return ("%d"):format(value) end, function(value)
      addonTable.Config.Set(addonTable.Config.Options.INSTANCES_NAME_ONLY_SIZE, value)
    end)
    nameOnlySizeSlider.option = addonTable.Config.Options.INSTANCES_NAME_ONLY_SIZE
    nameOnlySizeSlider:SetPoint("TOP", allFrames[#allFrames], "BOTTOM")
    table.insert(allFrames, nameOnlySizeSlider)
  end

  local clickableNameplatesDropdown = addonTable.CustomiseDialog.Components.GetBasicDropdown(container, addonTable.Locales.CLICKABLE_NAMEPLATES)
  clickableNameplatesDropdown:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  local values = {
    "friend",
    "enemy",
  }
  local labels = {
    addonTable.Locales.FRIENDLY,
    addonTable.Locales.ENEMY,
  }
  clickableNameplatesDropdown.DropDown:SetDefaultText(NONE)
  clickableNameplatesDropdown.DropDown:SetupMenu(function(_, rootDescription)
    for index, l in ipairs(labels) do
      rootDescription:CreateCheckbox(l, function()
        return addonTable.Config.Get(addonTable.Config.Options.CLICKABLE_NAMEPLATES)[values[index]]
      end, function()
        local current = addonTable.Config.Get(addonTable.Config.Options.CLICKABLE_NAMEPLATES)[values[index]]
        addonTable.Config.Get(addonTable.Config.Options.CLICKABLE_NAMEPLATES)[values[index]] = not current
        addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.Clickable] = true})
      end)
    end
  end)
  table.insert(allFrames, clickableNameplatesDropdown)

  local stackingNameplatesDropdown = addonTable.CustomiseDialog.Components.GetBasicDropdown(container, addonTable.Locales.STACKING_NAMEPLATES)
  stackingNameplatesDropdown:SetPoint("TOP", allFrames[#allFrames], "BOTTOM")
  local values = {
    "friend",
    "enemy",
  }
  local labels = {
    addonTable.Locales.FRIENDLY,
    addonTable.Locales.ENEMY,
  }
  stackingNameplatesDropdown.DropDown:SetDefaultText(NONE)
  stackingNameplatesDropdown.DropDown:SetupMenu(function(_, rootDescription)
    for index, l in ipairs(labels) do
      rootDescription:CreateCheckbox(l, function()
        return addonTable.Config.Get(addonTable.Config.Options.STACKING_NAMEPLATES)[values[index]]
      end, function()
        local current = addonTable.Config.Get(addonTable.Config.Options.STACKING_NAMEPLATES)[values[index]]
        addonTable.Config.Get(addonTable.Config.Options.STACKING_NAMEPLATES)[values[index]] = not current
        addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.StackingBehaviour] = true})
      end)
    end
  end)
  table.insert(allFrames, stackingNameplatesDropdown)

  local placeNameplatesAtDropdown = addonTable.CustomiseDialog.Components.GetBasicDropdown(
    container,
    addonTable.Locales.PLACE_ENEMY_NAMEPLATES_AT,
    function(value)
      return addonTable.Config.Get(addonTable.Config.Options.NAMEPLATE_POSITION) == value
    end,
    function (value)
      addonTable.Config.Set(addonTable.Config.Options.NAMEPLATE_POSITION, value)
    end
  )
  placeNameplatesAtDropdown:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  placeNameplatesAtDropdown:Init({
    addonTable.Locales.TOP,
    addonTable.Locales.BOTTOM,
  }, {
    "top",
    "bottom",
  })
  table.insert(allFrames, placeNameplatesAtDropdown)


  local castInterruptedTimeoutSlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.CAST_INTERRUPTED_TIMEOUT, 0, 50, function(value) return ("%.1fs"):format(value/10) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.CAST_INTERRUPTED_TIMEOUT, value / 10)
  end)
  castInterruptedTimeoutSlider:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  table.insert(allFrames, castInterruptedTimeoutSlider)

  local applyCvarsCheckbox = addonTable.CustomiseDialog.Components.GetCheckbox(container, addonTable.Locales.APPLY_OTHER_CVARS, 28, function(value)
    if InCombatLockdown() then
      return
    end
    addonTable.Config.Set(addonTable.Config.Options.APPLY_CVARS, value)
  end)
  applyCvarsCheckbox.option = addonTable.Config.Options.APPLY_CVARS
  applyCvarsCheckbox:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  table.insert(allFrames, applyCvarsCheckbox)

  container:SetScript("OnShow", function()
    castInterruptedTimeoutSlider:SetValue(addonTable.Config.Get(addonTable.Config.Options.CAST_INTERRUPTED_TIMEOUT) * 10)

    for _, f in ipairs(allFrames) do
      if f.SetValue then
        if f.option then
          f:SetValue(addonTable.Config.Get(f.option))
        elseif f.DropDown then
          f:SetValue()
        end
      end
    end
  end)

  return container
end

local function GetFadingOptions(parent)
  local container = CreateFrame("Frame", nil, parent)

  local allFrames = {}

  local mouseoverTransparencySlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.ON_MOUSEOVER_TRANSPARENCY, 0, 100, function(value) return ("%d%%"):format(value) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.MOUSEOVER_ALPHA, 1 - value / 100)
  end)
  mouseoverTransparencySlider:SetPoint("TOP")
  table.insert(allFrames, mouseoverTransparencySlider)

  local castTransparencySlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.ON_CAST_TRANSPARENCY, 0, 100, function(value) return ("%d%%"):format(value) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.CAST_ALPHA,  1 - value / 100)
  end)
  castTransparencySlider:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, 0)
  table.insert(allFrames, castTransparencySlider)

  local notTargetTransparencySlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.ON_NOT_TARGET_TRANSPARENCY, 0, 100, function(value) return ("%d%%"):format(value) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.NOT_TARGET_ALPHA, 1 - value / 100)
  end)
  notTargetTransparencySlider:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, 0)
  table.insert(allFrames, notTargetTransparencySlider)

  local obscuredTransparencySlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.OBSCURED_TRANSPARENCY, 0, 100, function(value) return ("%d%%"):format(value) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.OBSCURED_ALPHA, 1 - value / 100)
  end)
  obscuredTransparencySlider:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  table.insert(allFrames, obscuredTransparencySlider)

  local obscuredCombatTransparencySlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.COMBAT_OBSCURED_TRANSPARENCY, 0, 100, function(value) return ("%d%%"):format(value) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.OBSCURED_COMBAT_ALPHA, 1 - value / 100)
  end)
  obscuredCombatTransparencySlider:SetPoint("TOP", allFrames[#allFrames], "BOTTOM")
  table.insert(allFrames, obscuredCombatTransparencySlider)

  local outOfRangeTransparencySlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.OUT_OF_RANGE_TRANSPARENCY, 0, 100, function(value) return ("%d%%"):format(value) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.OUT_OF_RANGE_ALPHA, 1 - value / 100)
  end)
  outOfRangeTransparencySlider:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  table.insert(allFrames, outOfRangeTransparencySlider)

  local notInPullTransparencySlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.NOT_IN_PULL_TRANSPARENCY, 0, 100, function(value) return ("%d%%"):format(value) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.NOT_IN_PULL_ALPHA, 1 - value / 100)
  end)
  notInPullTransparencySlider:SetPoint("TOP", allFrames[#allFrames], "BOTTOM")
  table.insert(allFrames, notInPullTransparencySlider)

  container:SetScript("OnShow", function()
    castTransparencySlider:SetValue(100 - addonTable.Config.Get(addonTable.Config.Options.CAST_ALPHA) * 100)
    notTargetTransparencySlider:SetValue(100 - addonTable.Config.Get(addonTable.Config.Options.NOT_TARGET_ALPHA) * 100)
    mouseoverTransparencySlider:SetValue(100 - addonTable.Config.Get(addonTable.Config.Options.MOUSEOVER_ALPHA) * 100)
    obscuredTransparencySlider:SetValue(100 - addonTable.Config.Get(addonTable.Config.Options.OBSCURED_ALPHA) * 100)
    obscuredCombatTransparencySlider:SetValue(100 - addonTable.Config.Get(addonTable.Config.Options.OBSCURED_COMBAT_ALPHA) * 100)
    outOfRangeTransparencySlider:SetValue(100 - addonTable.Config.Get(addonTable.Config.Options.OUT_OF_RANGE_ALPHA) * 100)
    notInPullTransparencySlider:SetValue(100 - addonTable.Config.Get(addonTable.Config.Options.NOT_IN_PULL_ALPHA) * 100)
  end)

  return container
end

local function GetSizingOptions(parent)
  local container = CreateFrame("Frame", nil, parent)

  local allFrames = {}

  local simplifiedScaleSlider
  if addonTable.Constants.IsSimplifiedAvailable then
    if C_CVar.GetCVarInfo("nameplateSimplifiedScale") then
      simplifiedScaleSlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.SIMPLIFIED_SCALE, 1, 100, function(value) return ("%d%%"):format(value) end, function(value)
        addonTable.Config.Set(addonTable.Config.Options.SIMPLIFIED_SCALE, value / 100)
      end)
      simplifiedScaleSlider:SetPoint("TOP")
      table.insert(allFrames, simplifiedScaleSlider)
    end
  end

  local targetScaleSlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.ON_TARGET_SCALE, 1, 500, function(value) return ("%d%%"):format(value) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.TARGET_SCALE, value / 100)
  end)
  if #allFrames > 0 then
    targetScaleSlider:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
  else
    targetScaleSlider:SetPoint("TOP")
  end
  table.insert(allFrames, targetScaleSlider)

  local castScaleSlider = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.ON_CAST_SCALE, 1, 500, function(value) return ("%d%%"):format(value) end, function(value)
    addonTable.Config.Set(addonTable.Config.Options.CAST_SCALE, value / 100)
  end)
  castScaleSlider:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, 0)
  table.insert(allFrames, castScaleSlider)

  if C_CVar.GetCVarInfo("nameplateOtherTopInset") then
    local closerToScreenEdgesCheckbox = addonTable.CustomiseDialog.Components.GetCheckbox(container, addonTable.Locales.CLOSER_TO_SCREEN_EDGES, 28, function(value)
      if InCombatLockdown() then
        return
      end
      addonTable.Config.Set(addonTable.Config.Options.CLOSER_TO_SCREEN_EDGES, value)
    end)
    closerToScreenEdgesCheckbox.option = addonTable.Config.Options.CLOSER_TO_SCREEN_EDGES
    closerToScreenEdgesCheckbox:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, 0)
    table.insert(allFrames, closerToScreenEdgesCheckbox)
  end

  local clickRegionSliderX, clickRegionSliderY, stackRegionSliderX, stackRegionSliderY
  if not addonTable.Constants.IsHitTestPointsAvailable then
    clickRegionSliderX = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.CLICK_REGION_WIDTH, 1, 300, function(value) return ("%d%%"):format(value) end, function(value)
      addonTable.Config.Set(addonTable.Config.Options.CLICK_REGION_SCALE_X, value / 100)
    end)
    clickRegionSliderX:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
    clickRegionSliderX:SetScript("OnEnter", function()
      addonTable.CallbackRegistry:TriggerEvent("ShowRegion", "click", true)
    end)
    clickRegionSliderX:SetScript("OnLeave", function()
      addonTable.CallbackRegistry:TriggerEvent("ShowRegion", "click", false)
    end)
    table.insert(allFrames, clickRegionSliderX)

    clickRegionSliderY = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.CLICK_REGION_HEIGHT, 1, 500, function(value) return ("%d%%"):format(value) end, function(value)
      addonTable.Config.Set(addonTable.Config.Options.CLICK_REGION_SCALE_Y, value / 100)
    end)
    clickRegionSliderY:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, 0)
    clickRegionSliderY:SetScript("OnEnter", function()
      addonTable.CallbackRegistry:TriggerEvent("ShowRegion", "click", true)
    end)
    clickRegionSliderY:SetScript("OnLeave", function()
      addonTable.CallbackRegistry:TriggerEvent("ShowRegion", "click", false)
    end)
    table.insert(allFrames, clickRegionSliderY)

    stackRegionSliderX = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.STACKING_REGION_WIDTH, 1, 300, function(value) return ("%d%%"):format(value) end, function(value)
      addonTable.Config.Set(addonTable.Config.Options.STACK_REGION_SCALE_X, value / 100)
    end)
    stackRegionSliderX:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
    stackRegionSliderX:SetScript("OnEnter", function()
      addonTable.CallbackRegistry:TriggerEvent("ShowRegion", "stack", true)
    end)
    stackRegionSliderX:SetScript("OnLeave", function()
      addonTable.CallbackRegistry:TriggerEvent("ShowRegion", "stack", false)
    end)
    table.insert(allFrames, stackRegionSliderX)

    stackRegionSliderY = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.STACKING_REGION_HEIGHT, 1, 500, function(value) return ("%d%%"):format(value) end, function(value)
      addonTable.Config.Set(addonTable.Config.Options.STACK_REGION_SCALE_Y, value / 100)
    end)
    stackRegionSliderY:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, 0)
    stackRegionSliderY:SetScript("OnEnter", function()
      addonTable.CallbackRegistry:TriggerEvent("ShowRegion", "stack", true)
    end)
    stackRegionSliderY:SetScript("OnLeave", function()
      addonTable.CallbackRegistry:TriggerEvent("ShowRegion", "stack", false)
    end)
    table.insert(allFrames, stackRegionSliderY)
  else
    local wrapper = CreateFrame("Frame", nil, container)
    wrapper:SetPoint("LEFT")
    wrapper:SetPoint("RIGHT")
    wrapper:SetHeight(40)
    local label = wrapper:CreateFontString(nil, nil, "GameFontHighlight")
    label:SetText(addonTable.Locales.STACK_CLICK_SETTINGS_HAVE_MOVED_X)
    label:SetPoint("CENTER", 0, 0)
    label:SetPoint("LEFT", 30, 0)
    label:SetPoint("RIGHT", -30, 0)
    wrapper:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
    table.insert(allFrames, wrapper)
  end

  local verticalOffset
  if addonTable.Constants.IsHitTestPointsAvailable then
    verticalOffset = addonTable.CustomiseDialog.Components.GetSlider(container, addonTable.Locales.VERTICAL_OFFSET, 0, 500, function(value) return ("%d%%"):format(value) end, function(value)
      addonTable.Config.Set(addonTable.Config.Options.VERTICAL_OFFSET, value / 100)
    end)
    verticalOffset:SetPoint("TOP", allFrames[#allFrames], "BOTTOM", 0, -30)
    table.insert(allFrames, verticalOffset)
  end

  container:SetScript("OnShow", function()
    targetScaleSlider:SetValue(addonTable.Config.Get(addonTable.Config.Options.TARGET_SCALE) * 100)
    if simplifiedScaleSlider then
      simplifiedScaleSlider:SetValue(addonTable.Config.Get(addonTable.Config.Options.SIMPLIFIED_SCALE) * 100)
    end

    castScaleSlider:SetValue(addonTable.Config.Get(addonTable.Config.Options.CAST_SCALE) * 100)
    if addonTable.Constants.IsHitTestPointsAvailable then
      verticalOffset:SetValue(addonTable.Config.Get(addonTable.Config.Options.VERTICAL_OFFSET) * 100)
    else
      clickRegionSliderX:SetValue(addonTable.Config.Get(addonTable.Config.Options.CLICK_REGION_SCALE_X) * 100)
      clickRegionSliderY:SetValue(addonTable.Config.Get(addonTable.Config.Options.CLICK_REGION_SCALE_Y) * 100)
      stackRegionSliderX:SetValue(addonTable.Config.Get(addonTable.Config.Options.STACK_REGION_SCALE_X) * 100)
      stackRegionSliderY:SetValue(addonTable.Config.Get(addonTable.Config.Options.STACK_REGION_SCALE_Y) * 100)
    end

    for _, f in ipairs(allFrames) do
      if f.SetValue and f.option then
        f:SetValue(addonTable.Config.Get(f.option))
      end
    end
  end)

  return container
end

function addonTable.CustomiseDialog.GetBehaviour(parent)
  local container = CreateFrame("Frame", nil, parent)

  local defaultContainer = GetCommonOptions(container)
  local fadingContainer = GetFadingOptions(container)
  local sizingContainer = GetSizingOptions(container)

  local tabContainers = {
    {name = addonTable.Locales.COMMON, container = defaultContainer},
    {name = addonTable.Locales.FADING, container = fadingContainer},
    {name = addonTable.Locales.SIZING, container = sizingContainer},
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
