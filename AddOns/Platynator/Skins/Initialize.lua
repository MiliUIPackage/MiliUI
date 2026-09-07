---@class addonTableBaganator
local addonTable = select(2, ...)

addonTable.Skins.availableSkins = {}
addonTable.Skins.skinListeners = {}
addonTable.Skins.allFrames = {}

local currentSkinner = function() end

function addonTable.Skins.Initialize()
  local keys = GetKeysArray(addonTable.Skins.availableSkins)
  table.sort(keys, function(a, b)
    return addonTable.Skins.availableSkins[a].autoEnablePriority < addonTable.Skins.availableSkins[b].autoEnablePriority
  end)

  local currentSkinKey = keys[1]
  local currentSkin = addonTable.Skins.availableSkins[currentSkinKey]

  local function Generate()
    currentSkin.constants()
    xpcall(currentSkin.initializer, CallErrorHandler)
    currentSkinner = currentSkin.skinner
  end

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:SetScript("OnEvent", function()
    frame:UnregisterEvent("PLAYER_LOGIN")
    Generate()
  end)
end

function addonTable.Skins.AddFrame(regionType, region, tags)
  if not region.added then
    local details = {regionType = regionType, region = region, tags = tags}
    table.insert(addonTable.Skins.allFrames, details)
    xpcall(currentSkinner, CallErrorHandler, details)
    if addonTable.Skins.skinListeners then
      for _, listener in ipairs(addonTable.Skins.skinListeners) do
        xpcall(listener, CallErrorHandler, details)
      end
    end
    region.added = true
  end
end

function addonTable.Skins.RegisterSkin(label, key, initializer, skinner, constants, options, autoEnablePriority)
  addonTable.Skins.availableSkins[key] = {
    label = label,
    key = key,
    initializer = initializer,
    skinner = skinner,
    constants = constants,
    options = options or {},
    autoEnablePriority = autoEnablePriority,
  }
end
