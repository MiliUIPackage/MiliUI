local AtlasLoot = _G.AtlasLoot
local AL = AtlasLoot.Locales

-- lua
local assert, type = assert, type
local next = next

-- WoW
-- DisableAddOn

local EventFrame = CreateFrame("FRAME")
EventFrame:RegisterEvent("ADDON_LOADED")

local function EventFrame_OnEvent(frame, event, arg1, ...)
	if event == "ADDON_LOADED" and arg1 and AtlasLoot.Init[arg1] then
		AtlasLoot:OnInitialize()
		-- init all other things
		if AtlasLoot.Init then
			for i = 1, #AtlasLoot.Init[arg1] do
				local func = AtlasLoot.Init[arg1][i]
				if func and type(func) == "function" then
					func()
				end
			end
			AtlasLoot.Init[arg1] = nil
		end
		if not next(AtlasLoot.Init) then
			EventFrame:UnregisterEvent("ADDON_LOADED")
		end
	end
end
EventFrame:SetScript("OnEvent", EventFrame_OnEvent)

function AtlasLoot:Print(msg)
	print("|cff33ff99AtlasLoot|r: "..(msg or ""))
end

function AtlasLoot:OnInitialize()
	if not AtlasLootCharDB.__addonrevision then --or AtlasLootDB.__addonrevision < AtlasLoot.__addonrevision then
		wipe(AtlasLootCharDB)
		AtlasLootCharDB.__addonrevision = AtlasLoot.__addonrevision
	end
	--[[
	self.db = LibStub("AceDB-3.0"):New("AtlasLootDB")
	self.db:RegisterDefaults(AtlasLoot.AtlasLootDBDefaults)
	self.chardb = LibStub("AceDB-3.0"):New("AtlasLootCharDB")
	self.chardb:RegisterDefaults(AtlasLoot.AtlasLootDBDefaults)
	]]--
	self.db = LibStub("ALDB-1.0"):Register(AtlasLootCharDB, AtlasLootDB, AtlasLoot.AtlasLootDBDefaults)
	
	
	-- bindings
	BINDING_HEADER_ATLASLOOT = AL["AtlasLoot"]
	BINDING_NAME_ATLASLOOT_TOGGLE = AL["Toggle AtlasLoot"]
	
	
	local _, _, _, _, reason = GetAddOnInfo("AtlasLoot_Loader")
	if reason ~=  "MISSING" then 
		DisableAddOn("AtlasLoot_Loader") 
		StaticPopupDialogs["ATLASLOOT_LOADER_ADDON_ERROR"] = {
			text = AL["AtlasLoot_Loader is no longer in use.\nDelete it from your AddOns folder"],
			button1 = OKAY,
			timeout = 0,
			exclusive = 1,
			whileDead = 1,
		}
		StaticPopup_Show("ATLASLOOT_LOADER_ADDON_ERROR")
	end

	
	--[[ scan for pet IDs
	self.db.PETINFO = {}
	local petID, speciesID, owned, customName, level, favorite, isRevoked, speciesName
	local numPets = C_PetJournal.GetNumPets()
	
	for i=1,numPets do
		petID, speciesID, owned, customName, level, favorite, isRevoked, speciesName = C_PetJournal.GetPetInfoByIndex(i)
		if speciesName and speciesID then
			self.db.PETINFO[speciesName] = speciesID
		end
	end
	]]--
	

	--self.db.MOUNTINFO = {}
	--local numMounts = C_MountJournal.GetNumMounts()
	
	--for i=1,numMounts do
		--print(C_MountJournal.GetMountInfo(i))
		
		
	
		--petID, speciesID, owned, customName, level, favorite, isRevoked, speciesName = C_PetJournal.GetPetInfoByIndex(i)
		--if speciesName and speciesID then
		--	self.db.PETINFO[speciesName] = speciesID
		--end
	--end

	
	
	
end

function AtlasLoot:AddInitFunc(func, module)
	assert(type(func) == "function", "'func' must be a function.")
	if not EventFrame:IsEventRegistered("ADDON_LOADED") then
		EventFrame:RegisterEvent("ADDON_LOADED")
	end
	module = module or "AtlasLoot"
	if not AtlasLoot.Init[module] then AtlasLoot.Init[module] = {} end
	AtlasLoot.Init[module][#AtlasLoot.Init[module]+1] = func
end


AtlasLoot.DEV = {}
local EJ_DIFFICULTIES =  
{
	{ size = "5", prefix = PLAYER_DIFFICULTY1, difficultyID = 1 },
	{ size = "5", prefix = PLAYER_DIFFICULTY2, difficultyID = 2 },
	{ size = "5", prefix = PLAYER_DIFFICULTY6, difficultyID = 23 },
	{ size = "5", prefix = PLAYER_DIFFICULTY_TIMEWALKER, difficultyID = 24 },
	{ size = "25", prefix = PLAYER_DIFFICULTY3, difficultyID = 7 },
	{ size = "10", prefix = PLAYER_DIFFICULTY1, difficultyID = 3 },
	{ size = "10", prefix = PLAYER_DIFFICULTY2, difficultyID = 5 },
	{ size = "25", prefix = PLAYER_DIFFICULTY1, difficultyID = 4 },
	{ size = "25", prefix = PLAYER_DIFFICULTY2, difficultyID = 6 },
	{ prefix = PLAYER_DIFFICULTY3, difficultyID = 17 },
	{ prefix = PLAYER_DIFFICULTY1, difficultyID = 14 },
	{ prefix = PLAYER_DIFFICULTY2, difficultyID = 15 },
	{ prefix = PLAYER_DIFFICULTY6, difficultyID = 16 },
}

function AtlasLoot:DEV_ScanEJ(givenTierId)
	self.db.DEV_ScanEJ = {}
	local db = self.db.DEV_ScanEJ
	if EncounterJournal then
		EncounterJournal:UnregisterEvent("EJ_DIFFICULTY_UPDATE")
	end
	
	for tier = 1,EJ_GetNumTiers() do		-- scan tiers Classic, bc, ...
		if givenTierId and givenTierId ~= tier then
			-- Do nothing
		else
			EJ_SelectTier(tier)
			local tierName = EJ_GetTierInfo(tier)
			db[tierName] = {
				info = {
					tierID = tier,
				},
				dungeons = {},
				raids = {},
			}
			local loopKill = 0
			local showRaid = false
			local index = 1
			local instanceID, name, description, bgImage, buttonImage, loreImage, dungeonAreaMapID, link
			while true do
				loopKill = loopKill + 1
				if loopKill > 300 then print"ouch loop break" break end
				instanceID, name, description, bgImage, buttonImage, loreImage, dungeonAreaMapID, link = EJ_GetInstanceByIndex(index, showRaid)
				if not instanceID and showRaid then	
					break
				elseif not instanceID then
					index = 1
					showRaid = true
				else
					local curDb = showRaid and db[tierName].raids or db[tierName].dungeons
					
					curDb[name] = {
						info = {
							instanceID = instanceID,
							name = name,
							description = description,
							bgImage = bgImage,
							buttonImage = buttonImage,
							loreImage = loreImage,
							dungeonAreaMapID = dungeonAreaMapID,
							link = link,
						},
						bosses = {},
					}
					curDb = curDb[name].bosses
					
					EJ_SelectInstance(instanceID)	-- select instance..
					
					local bossIndex = 1
					local encounterName, encounterDescription, encounterID, rootSectionID, encounterLink = EJ_GetEncounterInfoByIndex(bossIndex)
					local loopProtectEncount = 0
					
					while encounterID do
						loopProtectEncount = loopProtectEncount +1
						if loopProtectEncount > 500 then print("ouch encounterLoop break"..loopProtectEncount) break end
						EJ_SelectEncounter(encounterID)
						curDb[encounterName] = {
							info = {
								name = encounterName,
								description = description,
								encounterID = encounterID,
								rootSectionID = rootSectionID,
								link = link,
							},
							items = {},
						}
						for diffIndex = 1,#EJ_DIFFICULTIES do
							local entry = EJ_DIFFICULTIES[diffIndex];
							if EJ_IsValidInstanceDifficulty(entry.difficultyID) then
								EJ_SetDifficulty(entry.difficultyID)
								local diffName, groupType, isHeroic, isChallengeMode, displayHeroic, displayMythic, toggleDifficultyID = GetDifficultyInfo(entry.difficultyID)
								curDb[encounterName].items[diffName] = {}
								--print(diffName, groupType, isHeroic, isChallengeMode, displayHeroic, displayMythic, toggleDifficultyID)
								local lootDb = curDb[encounterName].items[diffName] 
								local itemName, _, itemID
								for itemIndex = 1, EJ_GetNumLoot() do
									itemID, _, itemName	= EJ_GetLootInfoByIndex(itemIndex)
									if itemID then
										lootDb[itemID] = itemName
										print(itemName)
									end
								end
							end
						end
						
						bossIndex = bossIndex + 1
						encounterName, encounterDescription, encounterID, rootSectionID, encounterLink = EJ_GetEncounterInfoByIndex(bossIndex)
					end
					
					index = index +1
				end
				
				
			end

		end
	end
	
	if EncounterJournal then
		EncounterJournal:RegisterEvent("EJ_DIFFICULTY_UPDATE")
	end
end
--[[
local db 
local ORIGetItemInfo = GetItemInfo
function GetItemInfo(xxx)
	if not db then 
		if not AtlasLoot.db.itemInfo then
			AtlasLoot.db.itemInfo = {}
		end
		db = AtlasLoot.db.itemInfo
	end
	local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemCount, itemEquipLoc, itemTexture, vendorPrice = ORIGetItemInfo(xxx)
	if itemSubType and itemType then
		if not db[itemType] then
			db[itemType] = {}
		end
		db[itemType][itemSubType] = true
	end
	if itemEquipLoc then
		if not db.slot then db.slot = {} end
		db[itemEquipLoc] = nil
		db.slot[itemEquipLoc] = true
	end
	return itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemCount, itemEquipLoc, itemTexture, vendorPrice
end
]]--

-- ################
-- DEV !!! remove later only for tests
-- ################
local GUIDS = {
	["Player-1097-040A43FC"] = "author",	-- shijera@ysera-eu
	["Player-1097-0444710C"] = "author",	-- lag@ysera-eu
	["Player-1097-044F8D64"] = "author",
	["Player-1097-047418F7"] = "author",	-- schoko!
	["Player-1097-045D6B65"] = "author", 	-- Cali
	["Player-1097-00490D06"] = true,		-- meena@ysera-eu
	["Player-1097-0212CAC6"] = true,		-- xyriana@ysera-eu
	["Player-612-0566C578"] = "author",		-- Dynaletik@nerathor-eu
	["Player-612-05667280"] = "author",		-- Dynarix@nerathor-eu
	["Player-612-0566725A"] = "author",		-- Dynalowtik@nerathor-eu
}
local AUTHOR_STRING = "AtlasLoot Author |T"..AtlasLoot.IMAGE_PATH.."gold:0|t"
local FRIEND_STRING = "AtlasLoot Friend |T"..AtlasLoot.IMAGE_PATH.."silver:0|t"
function hookUnitTarget(self)
	local name, unit = self:GetUnit()
	if name and unit then
		local guid = UnitGUID(unit)
		if guid and GUIDS[guid] then
			self:AddLine(GUIDS[guid] == "author" and AUTHOR_STRING or FRIEND_STRING, 0, 1, 0 )
		end
	end
end
GameTooltip:HookScript("OnTooltipSetUnit", hookUnitTarget)
