---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.CallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
addonTable.CallbackRegistry:OnLoad()
addonTable.CallbackRegistry:GenerateCallbackEvents(addonTable.Constants.Events)

local hidden = CreateFrame("Frame")
hidden:Hide()
addonTable.hiddenFrame = hidden

local offscreen = CreateFrame("Frame")
offscreen:SetPoint("TOPLEFT", UIParent, "TOPRIGHT")
addonTable.offscreenFrame = hidden

local function SetStyle(isInit)
  local styleName = addonTable.Config.Get(addonTable.Config.Options.STYLE)
  if styleName:match("^_") then
    local designs = addonTable.Config.Get(addonTable.Config.Options.DESIGNS)
    designs[addonTable.Constants.CustomName] = CopyTable(addonTable.Core.GetDesignByName(styleName))
  end

  if isInit then
    return
  end

  if addonTable.CustomiseDialog.IsUsingDefaultStyleSelect() then
    local assigments = addonTable.Config.Get(addonTable.Config.Options.DESIGN_ASSIGNMENTS)
    local enemyStyle = assigments[#assigments].style
    local toChange = {}
    local alreadySet = false
    for _, a in ipairs(assigments) do
      if a.style == styleName then
        alreadySet = true
      end
      if a.style == enemyStyle then
        table.insert(toChange, a)
      end
    end
    if not alreadySet then
      for _, a in ipairs(toChange) do
        a.style = styleName
      end
    end
    addonTable.CallbackRegistry:TriggerEvent("CustomiseDesignsAssigned")
  end
  addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.Design] = true})
end

function addonTable.Core.GetDesignByName(name)
  if addonTable.Design.Defaults[name] then
    if not addonTable.Design.ParsedDefaults[name] then
      local design = C_EncodingUtil.DeserializeJSON(addonTable.Design.Defaults[name])
      design.kind = nil
      design.addon = nil
      addonTable.Core.UpgradeDesign(design)
      addonTable.Design.ParsedDefaults[name] = design
    end
    return addonTable.Design.ParsedDefaults[name]
  else
    return addonTable.Config.Get(addonTable.Config.Options.DESIGNS)[name]
  end
end

function addonTable.Core.GetDesignScale(isSimplified)
  if isSimplified and addonTable.Constants.IsSimplifiedAvailable then
    return addonTable.Config.Get(addonTable.Config.Options.SIMPLIFIED_SCALE)
  else
    return 1
  end
end

function addonTable.Core.Initialize()
  addonTable.Config.InitializeData()

  -- MiliUI Profile (版本檢查：無版本記錄或有新版本時強制更新)
  if MiliUI_PlatynatorProfile then
    local needsImport = false
    local profileExists = PLATYNATOR_CONFIG and PLATYNATOR_CONFIG.Profiles and PLATYNATOR_CONFIG.Profiles["MiliUI"]

    if not profileExists then
      needsImport = true
    elseif MiliUI_PlatynatorForceUpdate and MiliUI_PlatynatorVersion then
      -- 開關開啟時：內建版本較新則強制覆蓋匯入（預設關閉，見 MiliUI/Config/Luxthos_Platynator.lua）
      local storedVersion = PLATYNATOR_CONFIG.MiliUI_Version or 0
      if MiliUI_PlatynatorVersion > storedVersion then
        needsImport = true
      end
    end

    if needsImport then
      addonTable.CustomiseDialog.ImportData(MiliUI_PlatynatorProfile, "MiliUI", true)
      addonTable.Config.ChangeProfile("MiliUI")
      if MiliUI_PlatynatorVersion then
        PLATYNATOR_CONFIG.MiliUI_Version = MiliUI_PlatynatorVersion
      end
    elseif PLATYNATOR_CURRENT_PROFILE == "DEFAULT" and profileExists then
      -- 新角色首次登入：自動切換到 MiliUI profile
      addonTable.Config.ChangeProfile("MiliUI")
    end
  end

  addonTable.SlashCmd.Initialize()

  addonTable.Assets.ApplyScale()

  addonTable.Core.MigrateSettings()

  SetStyle(true)
  addonTable.CallbackRegistry:RegisterCallback("SettingChanged", function(_, name)
    if name == addonTable.Config.Options.STYLE then
      SetStyle()
    end
  end)

  addonTable.CustomiseDialog.Initialize()

  addonTable.Display.Initialize()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, eventName, data)
  if eventName == "ADDON_LOADED" and data == "Platynator" then
    addonTable.Core.Initialize()
  end
end)
