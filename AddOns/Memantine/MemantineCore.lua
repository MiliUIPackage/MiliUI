-- Data

-- journalId: The encounterId as used in the encounter journal.
-- engageId: The enounterId as sent in the ENCOUNTER_START event.
local Encounters = {
  -- Atal'Dazar
  { journalId = 2082, engageId = 2084 },
  { journalId = 2083, engageId = 2086 },
  { journalId = 2036, engageId = 2085 },
  { journalId = 2030, engageId = 2087 },
  -- Freehold
  { journalId = 2094, engageId = 2095 },
  { journalId = 2093, engageId = 2094 },
  { journalId = 2102, engageId = 2093 },
  { journalId = 2095, engageId = 2096 },
  -- King's Rest
  { journalId = 2170, engageId = 2140 },
  { journalId = 2172, engageId = 2143 },
  { journalId = 2165, engageId = 2139 },
  { journalId = 2171, engageId = 2142 },
  -- Shrine of the Strom
  { journalId = 2153, engageId = 2130 },
  { journalId = 2154, engageId = 2131 },
  { journalId = 2155, engageId = 2132 },
  { journalId = 2156, engageId = 2133 },
  -- Siege of Boralus
  { journalId = 2133, engageId = 2097 },
  { journalId = 2134, engageId = 2099 },
  { journalId = 2173, engageId = 2109 },
  { journalId = 2140, engageId = 2100 },
  -- Temple of Sethraliss
  { journalId = 2142, engageId = 2124 },
  { journalId = 2145, engageId = 2127 },
  { journalId = 2144, engageId = 2126 },
  { journalId = 2143, engageId = 2125 },
  -- The MOTHERLOAD!!
  { journalId = 2109, engageId = 2105 },
  { journalId = 2116, engageId = 2108 },
  { journalId = 2115, engageId = 2107 },
  { journalId = 2114, engageId = 2106 },
  -- Tol Dagor
  { journalId = 2098, engageId = 2102 },
  { journalId = 2096, engageId = 2104 },
  { journalId = 2097, engageId = 2101 },
  { journalId = 2099, engageId = 2103 },
  -- Underrot
  { journalId = 2158, engageId = 2123 },
  { journalId = 2131, engageId = 2118 },
  { journalId = 2157, engageId = 2111 },
  { journalId = 2130, engageId = 2112 },
  -- Waycrest Manor
  { journalId = 2126, engageId = 2114 },
  { journalId = 2129, engageId = 2117 },
  { journalId = 2125, engageId = 2113 },
  { journalId = 2127, engageId = 2115 },
  { journalId = 2128, engageId = 2116 },
  -- Uldir
  { journalId = 2146, engageId = 2128 },
  { journalId = 2147, engageId = 2122 },
  { journalId = 2167, engageId = 2141 },
  { journalId = 2194, engageId = 2135 },
  { journalId = 2168, engageId = 2144 },
  { journalId = 2166, engageId = 2134 },
  { journalId = 2169, engageId = 2136 },
  { journalId = 2195, engageId = 2145 },
}

EventToJournal = (function()
  local map = {}
  for _, encounter in pairs(Encounters) do
    map[encounter.engageId] = encounter.journalId
  end
  return map
end)()

JournalToEvent = (function()
  local map = {}
  for _, encounter in pairs(Encounters) do
    map[encounter.journalId] = encounter.engageId
  end
  return map
end)()

-- Addon

Memantine = LibStub("AceAddon-3.0"):NewAddon("Memantine", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
local AceGui = LibStub("AceGUI-3.0")

local Gui = nil
local EncounterId = nil

function Memantine:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("Memantine")
  self:RegisterEvent("ADDON_LOADED")
  self:RegisterEvent("ENCOUNTER_START")
  self:RegisterChatCommand("memantine", "ChatCommand")
end

function Memantine:ChatCommand(command)

  local parts = {}
  for part in string.gmatch(command, "%S+") do
    parts[#parts + 1] = part
  end

  self:ENCOUNTER_START("ENCOUNTER_START", tonumber(parts[1]), "TEST", tonumber(parts[2]), nil)
end

function Memantine:ADDON_LOADED(eventName, addonName)
  if addonName == "Blizzard_EncounterJournal" then
    self:GuiInitialize()
  end
end

function Memantine:GetLootSpecializations()
  local specializations = {}
  specializations[-1] = "Do not change"
  specializations[0] = "Current Specialization"
  for i = 1, GetNumSpecializations() do
    local id, name = GetSpecializationInfo(i)
    specializations[id] = name
  end
  return specializations
end

function Memantine:GetSpecializationIndex(lootSpecializationId)
  for i = 1, GetNumSpecializations() do
    local id, name = GetSpecializationInfo(i)
    if id == lootSpecializationId then
      return i
    end
  end
  return nil
end

function Memantine:GuiInitialize()

  Gui = AceGui:Create("Frame")
  Gui:SetTitle("Memantine")
  Gui:SetPoint("TOPLEFT", EncounterJournal, "TOPRIGHT", 32, 0)
  Gui:SetWidth(200)
  Gui:SetHeight(355)
  Gui:SetParent(EncounterJournal)
  Gui:SetLayout("List")
  -- Hide status bar
  Gui.statustext:Hide()
  Gui.statustext:GetParent():Hide()
  -- Hide close button
  local children = { Gui.frame:GetChildren() }
  children[1]:Hide()

  -- Handle clicking home in the navbar
  self:Hook("EJSuggestFrame_OpenFrame", function() self:SetEncounterId(nil) end, true)
  self:Hook("EncounterJournal_ListInstances", function() self:SetEncounterId(nil) end, true)
  -- Handle tab switching
  self:Hook("EncounterJournal_SetTab", function(tabType) self:SetTab(tabType) end, true)
  -- Handle open/close of adventure guide
  self:Hook(EncounterJournal, "Hide", function() self:SetEncounterId(nil) end, true)
  self:Hook(EncounterJournal, "Show", function() self:SetEncounterId(nil) end, true)
  -- Handle boss/dungeon/etc changes
  self:Hook("EncounterJournal_LootUpdate", function()
    self:GuiUpdateDifficulties()
    self:SetTab()
  end, true)
  -- Handle encounterId tracking
  self:Hook("EncounterJournal_DisplayEncounter", function(encounterId) self:SetEncounterId(encounterId) end, true)
end

function Memantine:SetEncounterId(encounterId)
  --self:Print(encounterId)
  EncounterId = encounterId
  if encounterId then
    local encounterName = EJ_GetEncounterInfo(encounterId);
    Gui:SetTitle(encounterName)
  end
  self:SetTab()
end

function Memantine:SetTab(tabType)
  --self:Print("GuiToggle")
  local tabType = tabType or EncounterJournal and EncounterJournal.encounter and EncounterJournal.encounter.info and EncounterJournal.encounter.info.tab
  local show = EncounterId and JournalToEvent[EncounterId] and tabType == 2
  if (show) then
    Gui:Show()
  else
    Gui:Hide()
  end
end

function Memantine:GuiUpdateDifficulties()
  --Memantine:Print("GuiUpdateDifficulties")
  if not EncounterId then
    return
  end

  Gui:SetWidth(200)
  Gui:SetHeight(355)
  Gui:ReleaseChildren()

  local lootSpecializations = self:GetLootSpecializations()

  -- Create difficulty dropdowns
  local difficultyDropdowns = {}
  for difficultyId = 1, 34 do
    if EJ_IsValidInstanceDifficulty(difficultyId) then
      local difficultyName = GetDifficultyInfo(difficultyId)
      local difficultyDropdown = AceGui:Create("Dropdown")
      difficultyDropdown.encounterId = EncounterId
      difficultyDropdown.difficultyId = difficultyId
      difficultyDropdown:SetRelativeWidth(1)
      difficultyDropdown:SetLabel(difficultyName)
      difficultyDropdown:SetList(lootSpecializations)
      local lootSpecializationId = self:LoadLootSpecializationId(difficultyDropdown.encounterId, difficultyDropdown.difficultyId)
      difficultyDropdown:SetValue(lootSpecializationId)
      difficultyDropdown:SetCallback("OnValueChanged", function(info, name, key)
        self:SaveLootSpecializationId(difficultyDropdown.encounterId, difficultyDropdown.difficultyId, key)
      end)
      table.insert(difficultyDropdowns, difficultyDropdown)
    end
  end

  -- Create set all dropdown
  local difficultyDropdown = AceGui:Create("Dropdown")
  difficultyDropdown:SetRelativeWidth(1)
  difficultyDropdown:SetLabel("All")
  difficultyDropdown:SetList(lootSpecializations)
  difficultyDropdown:SetCallback("OnValueChanged", function(info, name, key)
    if key ~= nil then
      for i = 1, #difficultyDropdowns do
        difficultyDropdowns[i]:SetValue(key)
        self:SaveLootSpecializationId(difficultyDropdowns[i].encounterId, difficultyDropdowns[i].difficultyId, key)
      end
      difficultyDropdown:SetValue(nil)
    end
  end)

  Gui:AddChild(difficultyDropdown)
  for i = 1, #difficultyDropdowns do
    Gui:AddChild(difficultyDropdowns[i])
  end
end

function Memantine:SaveLootSpecializationId(encounterId, difficultyId, lootSpecializationId)
  --self:Print("Saving value "..encounterId.." "..difficultyId.." "..lootSpecializationId)
  self.db.char[encounterId] = self.db.char[encounterId] or {}
  self.db.char[encounterId][difficultyId] = lootSpecializationId
end

function Memantine:LoadLootSpecializationId(encounterId, difficultyId)
  return self.db.char[encounterId] and self.db.char[encounterId][difficultyId] or -1
end

function Memantine:ENCOUNTER_START(eventName, encounterId, encounterName, difficultyId, groupSize)
  --self:Print(eventName)
  --self:Print(encounterId)
  --self:Print(encounterName)
  --self:Print(difficultyId)
  --self:Print(groupSize)
  local journalId = EventToJournal[encounterId]
  local journalEncounterName = EJ_GetEncounterInfo(journalId);
  --self:Print(journalId or "nil")
  local lootSpecializationId = self:LoadLootSpecializationId(journalId, difficultyId)
  --self:Print(lootSpecializationId or "nil")
  local specializationIndex = self:GetSpecializationIndex(lootSpecializationId)
  local difficultyName = GetDifficultyInfo(difficultyId)
  if (lootSpecializationId >= 0) then
    local _, lootSpecializationName = GetSpecializationInfo(specializationIndex)
    self:Print("Encounter "..journalEncounterName.." "..difficultyName.." started. Setting loot specialization to "..lootSpecializationName)
    SetLootSpecialization(lootSpecializationId)
  else
    self:Print("Encounter "..journalEncounterName.." "..difficultyName.." started. Not changing loot specialization.")
  end
end
