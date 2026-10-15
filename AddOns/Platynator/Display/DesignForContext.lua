---@class addonTablePlatynator
local addonTable = select(2, ...)

local IsNeutral = addonTable.Display.Utilities.IsNeutralUnit
local IsInRelevantInstance = addonTable.Display.Utilities.IsInRelevantInstance
local GetEliteType = addonTable.Display.Utilities.GetEliteType
local GetDelveType = addonTable.Display.Utilities.GetDelveType

local IsPlayer
if UnitTreatAsPlayerForDisplay then
  IsPlayer = function(unit)
    return UnitIsPlayer(unit) or UnitTreatAsPlayerForDisplay(unit)
  end
else
  IsPlayer = function(unit)
    return UnitIsPlayer(unit)
  end
end

local IsMinion
if UnitIsMinion then
  IsMinion = function(unit)
    return UnitIsMinion(unit)
  end
else
  IsMinion = function(unit)
    return UnitIsOtherPlayersPet(unit) or UnitIsUnit(unit, "pet")
  end
end

local function IsNPC(unit)
  return not IsPlayer(unit) and not IsMinion(unit)
end

local function GetAlignment(unit)
  if IsNeutral(unit) then
    return "neutral"
  elseif UnitIsFriend("player", unit) then
    return "friend"
  else
    return "hostile"
  end
end

local assignmentsPossibilities = {
  ["can-attack"] = { frequent = true, updates = "canAttack", check = function(state) return state.canAttack end },
  ["cannot-attack"] = { frequent = true, updates = "canAttack", check = function(state) return not state.canAttack end },

  ["in-combat"] = { frequent = true, updates = "combat", check = function(state) return state.combat end },
  ["out-combat"] = { frequent = true, updates = "combat", check = function(state) return not state.combat end },

  ["is-target"] = { frequent = true, updates = "target", check = function(state) return state.target end },
  ["not-target"] = { frequent = true, updates = "target", check = function(state) return not state.target end },

  ["friend"] = { updates = "alignment", check = function(state) return state.alignment == "friend" end},
  ["hostile"] = { updates = "alignment", check = function(state) return state.alignment == "hostile" end},
  ["neutral"] = { updates = "alignment", check = function(state) return state.alignment == "neutral" end},

  ["player"] = { check = function(state) return state.isPlayer end },
  ["npc"] = { check = function(state) return state.isNPC end },
  ["minion"] = { check = function(state) return state.isMinion end },

  ["class-rare"] = { updates = "classification", check = function(state) local c = state.classification; return c == "rare" or c == "rareelite" end },
  ["class-elite"] = { updates = "classification", check = function(state) local c = state.classification; return c == "elite" or c == "rareelite" end },
  ["class-worldboss"] = { updates = "classification", check = function(state) return state.classification == "worldboss" end },
  ["class-normal"] = { updates = "classification", check = function(state) return state.classification == "normal" end },
  ["class-minor"] = { updates = "classification", check = function(state) return state.classification == "minus" end },
  ["class-trivial"] = { updates = "classification", check = function(state) return state.classification == "trivial" end },

  ["loc-world"] = { check = function(state) return state.location == "world" end },
  ["loc-dungeon"] = { check = function(state) return state.location == "dungeon" end },
  ["loc-raid"] = { check = function(state) return state.location == "raid" end },
  ["loc-pvp"] = { check = function(state) return state.location == "pvp" end },
  ["loc-delve"] = { check = function(state) return state.location == "delve" end },
  ["loc-resting"] = { updates = "resting", check = function(state) return state.resting end },

  ["elite-boss"] = { updates = "classification", check = function(state) return state.eliteType == "boss" end },
  ["elite-miniboss"] = { updates = "classification", check = function(state) return state.eliteType == "miniboss" end },
  ["elite-caster"] = { updates = "classification", check = function(state) return state.eliteType == "caster" end },
  ["elite-melee"] = { updates = "classification", check = function(state) return state.eliteType == "melee" end },
  ["elite-trivial"] = { updates = "classification", check = function(state) return state.eliteType == "trivial" end },

  ["delve-boss"] = { updates = "classification", check = function(state) return state.delveType == "boss" end },
  ["delve-elite"] = { updates = "classification", check = function(state) return state.delveType == "elite" end },
  ["delve-rare"] = { updates = "classification", check = function(state) return state.delveType == "rare" end },
  ["delve-caster"] = { updates = "classification", check = function(state) return state.delveType == "caster" end },
  ["delve-melee"] = { updates = "classification", check = function(state) return state.delveType == "melee" end },
  ["delve-trivial"] = { updates = "classification", check = function(state) return state.delveType == "trivial" end },
}

local location
local instanceTracker = CreateFrame("Frame")
instanceTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceTracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
instanceTracker:RegisterEvent("INSTANCE_GROUP_SIZE_CHANGED")
instanceTracker:SetScript("OnEvent", function()
  if not IsInRelevantInstance({dungeon = true, raid = true, pvp = true, delve = true}) then
    location = "world"
  elseif IsInRelevantInstance({dungeon = true}) then
    location = "dungeon"
  elseif IsInRelevantInstance({raid = true}) then
    location = "raid"
  elseif IsInRelevantInstance({pvp = true}) then
    location = "pvp"
  elseif IsInRelevantInstance({delve = true}) then
    location = "delve"
  end
end)

local function GenerateState(unit)
  local isMinion = IsMinion(unit)
  return {
    canAttack = addonTable.Cache:Get(unit, "canAttack"),
    combat = addonTable.Cache:Get(unit, "combat"),
    target = addonTable.Cache:Get(unit, "target"),
    alignment = GetAlignment(unit),
    isPlayer = IsPlayer(unit),
    isNPC = IsNPC(unit),
    isMinion = isMinion,
    classification = UnitClassification(unit),
    location = location,
    eliteType = GetEliteType(unit),
    delveType = GetDelveType(unit),
    resting = IsResting(),

    unit = unit,
    updates = {},
  }
end

addonTable.Display.DesignForContextMixin = {}
function addonTable.Display.DesignForContextMixin:OnLoad()
  addonTable.CallbackRegistry:RegisterCallback("CustomiseDesignsAssigned", function()
    addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.DesignSelection] = true})
    local units = GetKeysArray(self.unitStates)
    for _, u in ipairs(units) do
      addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", u)
    end
  end)

  self.unitStates = {}
  self.unitsListening = {}

  self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
  self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
  self:RegisterEvent("PLAYER_UPDATE_RESTING")
  self:SetScript("OnEvent", self.OnEvent)
end

function addonTable.Display.DesignForContextMixin:OnEvent(event, ...)
  if event == "UNIT_CLASSIFICATION_CHANGED" then
    local unit = ...
    if self.unitStates[unit] then
      local changes = self.unitStates[unit].updates.classification
      self.unitStates[unit].classification = UnitClassification(unit)
      if changes then
        addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", unit)
      end
    end
  elseif event == "UNIT_FACTION" then
    local unit = ...
    local state = self.unitStates[unit]
    if state then
      local changes = state.updates.alignment
      local oldAlignment = self.unitStates[unit].alignment
      state.alignment = GetAlignment(unit)
      if changes and state.alignment ~= oldAlignment then
        addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", unit)
      end
    end
  elseif event == "PLAYER_UPDATE_RESTING" then
    local resting = IsResting()
    for unit, state in pairs(self.unitStates) do
      local changes = state.updates.resting
      local oldResting = state.resting
      state.resting = resting
      if changes and oldResting ~= state.resting then
        addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", unit)
      end
    end
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local unit = ...
    self.unitStates[unit] = nil
    self.unitsListening[unit] = nil
  end
end

function addonTable.Display.DesignForContextMixin:RevokedUnitListeners(unit)
  self.unitsListening[unit] = nil
end

function addonTable.Display.DesignForContextMixin:GetAssignedDesign(unit)
  if not self.unitsListening[unit] then
    self.unitStates[unit] = GenerateState(unit) -- Necessary to trigger registration
    self.unitsListening[unit] = {}
  end
  if not self.unitStates[unit] then
    self.unitStates[unit] = GenerateState(unit)
  end
  local state = self.unitStates[unit]
  state.updates = {}

  return self:GetDesignFromState(state)
end

function addonTable.Display.DesignForContextMixin:GetDefaultEnemyNPCDesign()
  return self:GetDesignFromState({
    canAttack = true,
    combat = true,
    alignment = "hostile",
    isPlayer = false,
    isNPC = true,
    isMinion = false,
    classification = "normal",
    location = "world",
    eliteType = "trival",
    delveType = "melee",
    isResting = false,

    updates = {},
  })
end

function addonTable.Display.DesignForContextMixin:GetDefaultFriendlyPlayerDesign()
  return self:GetDesignFromState({
    canAttack = false,
    combat = false,
    alignment = "friend",
    isPlayer = true,
    isNPC = false,
    isMinion = false,
    classification = "normal",
    location = "dungeon",
    eliteType = nil,
    delveType = nil,
    isResting = false,

    updates = {},
  })
end

function addonTable.Display.DesignForContextMixin:AddUpdate(originState, updates)
  if not originState.unit then
    return
  end

  originState.updates[updates] = true
  local unit = originState.unit
  if (updates == "combat" or updates == "canAttack" or updates == "target") and not self.unitsListening[unit][updates] then
    self.unitsListening[unit][updates] = true
    addonTable.Cache:RegisterCallback(unit, updates, function(newValue)
      local state = self.unitStates[unit]
      if state then
        state[updates] = newValue
        if state.updates[updates] then
          C_Timer.After(0, function()
            addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", unit)
          end)
        end
      end
    end)
  end
end

function addonTable.Display.DesignForContextMixin:GetDesignFromState(state)
  local assignments = addonTable.Config.Get(addonTable.Config.Options.DESIGN_ASSIGNMENTS)
  for index, settings in ipairs(assignments) do
    local hit = true
    for _, criteria in ipairs(settings.criteria) do
      local details = assignmentsPossibilities[criteria]
      if details.updates then
        self:AddUpdate(state, details.updates)
      end
      if not details.check(state) then
        hit = false
        break
      end
    end

    if hit then
      return settings.style, settings.scale, settings.simplified or false, settings
    end
  end

  return "_deer", 1, false, nil
end

function addonTable.Display.DesignForContextMixin:GetClickRegion(unit)
  if not self.unitStates[unit] then
    self.unitStates[unit] = GenerateState(unit)
  end
  local state = self.unitStates[unit]

  local tmp = CopyTable(state)
  tmp.canAttack = tmp.canAttack or tmp.alignment ~= "friend"
  tmp.combat = true

  if tmp.alignment == "neutral" then
    tmp.alignment = "hostile"
  end

  local style, scale = self:GetDesignFromState(tmp)

  local design = addonTable.Core.GetDesignByName(style)

  return design.regions.click, scale, design.scale
end
