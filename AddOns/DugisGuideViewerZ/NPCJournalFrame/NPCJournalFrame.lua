-------------------------- VARIABLES ---------------------------
local DGV = DugisGuideViewer

local NPCJournalFrame = DGV:RegisterModule("NPCJournalFrame")
DGV.NPCJournalFrame = NPCJournalFrame

function NPCJournalFrame:Initialize()

	----------- Initialize Module -------------
	--FRAMES 
	local NPC_JOURNAL_MODE = 1
	local MOUNT_MODE = 2
	local PET_MODE = 3
	local RAID_BOSS_MODE = 4
	local FOLLOWER_MODE = 5


	---- TABS -----
	--NPC JOURNAL FRAME
	local STRATEGY_TAB = 1
	local ABILITIES_TAB = 2
	local LOOT_TAB = 3

	--Companion & Mount Journal
	local GUIDE_TAB = 4
	local PET_ABILITIES_TAB = 5

	--Raid Boss Journal
	local DPS_TAB = 6
	local HEAL_TAB = 7
	local TANK_TAB = 8

	local amountOfTabs = 8

	-- Guide / target object
	local GUIDE_MODE = 1
	local TARGET_MODE = 2


	-------------------------- DOMAIN UTILS ---------------------------

	function NPCJournalFrame:GetItemColoredName(id)
		local text = GetItemInfo(id)
		local quality = select(3, GetItemInfo(id))
		local color = 'ffffffff'
		if quality ~= nil then
			color = select(4, GetItemQualityColor(quality))
		end
		if text ~= nil then
			return '|c'..color..''..text..'|r'
		end            
		return ''
	end

	--Result: name, ST, ABIL, NDIS, CSST, unitName, role
	function NPCJournalFrame:GetNPCData()
		if not DGV:IsModuleRegistered("NPCDataModule") then return end
		local NPCInfo = {}
		
		local targetClass = UnitClass("target")
		local targetName = UnitName("target")
		
		if targetName == nil then
			return nil
		end
		
		local friend = UnitIsFriend("player", "target")
		local guid = UnitGUID("target")
		local id = DGV:GuidToNpcId(guid)
		local role = UnitGroupRolesAssigned("target")

		NPCInfo.id = id
		NPCInfo.unitName = "target"
		NPCInfo.name = targetName
		NPCInfo.role = role
		
		if NPCObjects and NPCObjects[id] ~= nil then
			NPCInfo.ST = NPCObjects[id].ST
			NPCInfo.ABIL = NPCObjects[id].ABIL
			NPCInfo.NDIS = NPCObjects[id].NDIS
			NPCInfo.CSST = NPCObjects[id].CSST
			NPCInfo.hasData = true
		else
			NPCInfo.ST = ""
			NPCInfo.ABIL = {}
			NPCInfo.NDIS = {}
			NPCInfo.CSST = ""
			NPCInfo.hasData = false
		end
		
		--print("Target NPCID:"..NPCInfo.id)
		
		return NPCInfo
	end
  
    NPCJournalFrame.npcNameAlreadyExisting = {}
	function NPCJournalFrame:GetNPCDataById(id)
		local NPCInfo = {}

		NPCInfo.id = string.gsub(id, '-altcat', '')
		if DGV:UserSetting(DGV_ENABLEMODELDB) then
		NPCInfo.modelId = DugisGuideViewer.Modules.ModelViewer.npcDB[tostring(NPCInfo.id)]
		end
		NPCInfo.name = DugisGuideViewer:GetLocalizedNPC(NPCInfo.id)
        
        if NPCJournalFrame.npcNameAlreadyExisting[NPCInfo.name] ~= nil then
            NPCInfo.name = NPCInfo.name .. " "
        end
        
        NPCJournalFrame.npcNameAlreadyExisting[NPCInfo.name] = true
        
		if not NPCInfo.name then
			 NPCInfo.name = "ID"..id
		end
		
		if NPCObjects[id] ~= nil then
			NPCInfo.ST = NPCObjects[id].ST
			NPCInfo.ABIL = NPCObjects[id].ABIL
			NPCInfo.NDIS = NPCObjects[id].NDIS
			NPCInfo.CSST = NPCObjects[id].CSST
            NPCInfo.category = NPCObjects[id].category
		end
		
		return NPCInfo
	end

	function NPCJournalFrame:GetMountData()
		if not DGV:IsModuleRegistered("MountDataModule") then return end
		for i = 1, 1024 do
			local spellId = select(11, UnitBuff("target", i))
			if not spellId then break end
            if MountObjects then
                local mountInfo = MountObjects[tonumber(spellId)]
                if mountInfo then
                    mountInfo.spellId = spellId
                    self:SetInfoForMountData(spellId, mountInfo)
                    return mountInfo
                end
            end
		end
	end

	function NPCJournalFrame:GetPlayersAllMountIds()
		if not DGV:IsModuleRegistered("MountDataModule") then return end
		local result = {}
		
		local ids = C_MountJournal.GetMountIDs()

		LuaUtils:foreach(ids, function(id)
			local _, spellID, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(id)
			MountJournalIndices[spellID] = id
			if isCollected then
				result[spellID] = true 
			end
		end)
		
		return result
	end

	function NPCJournalFrame:GetPlayersAllPetIds()
		local result = {}

		for i=1,C_PetJournal.GetNumPets(false) do
			local _,speciesID,collected,_,_,_,_,speciesName,_,familyType,creatureID,_,flavorText =  C_PetJournal.GetPetInfoByIndex(i)
			
			if collected then
				result[creatureID] = true 
			end
		end
		
		return result
	end
    
	function NPCJournalFrame:GetPlayersAllFollowerIds()
		local result = {}

        local followers = C_Garrison.GetFollowers()
        if followers then 
            for i,foll in ipairs(followers) do
                if foll.isCollected  then
                    local decimalId = tonumber(foll.garrFollowerID, 16)
                    result[decimalId] = true 
                end
            end
		end
		return result
	end    
    
    NPCJournalFrame.mountNameAlreadyExisting = {}
	function NPCJournalFrame:GetMountDataById(id)
		local mountInfo = MountObjects[tonumber(id)]
		if mountInfo then
			mountInfo.spellId = id
            self:SetInfoForMountData(mountInfo.spellId, mountInfo)
            mountInfo.name = GetSpellInfo(mountInfo.spellId)
            
            if mountInfo.name == nil then
                mountInfo.name = "Mount: " .. mountInfo.spellId 
            end
            
            if NPCJournalFrame.mountNameAlreadyExisting[mountInfo.name] ~= nil then
                mountInfo.name = mountInfo.name .. " "
            end
            
            NPCJournalFrame.mountNameAlreadyExisting[mountInfo.name] = true
            
			return mountInfo
		end
	end
    
    function NPCJournalFrame:SetInfoForMountData(spellId, outMountData)
        local index = MountJournalIndices[spellId]
		if not index then return end
		--Legion beta cheap fix\
        local creatureDisplayID, descriptionText, sourceText, isSelfMount, mountType

        if index ~= nil then
            creatureDisplayID, descriptionText, sourceText, isSelfMount, mountType = C_MountJournal.GetMountInfoExtraByID(index)
        end

        outMountData.description = descriptionText
		if creatureDisplayID then 
			MountObjects[spellId].modelId = creatureDisplayID
		elseif MountObjects[spellId].displayId then 
			MountObjects[spellId].modelId = MountObjects[spellId].displayId
		else
			MountObjects[spellId].modelId = 65854  --Bunny placeholder
		end
	end

    NPCJournalFrame.petNameAlreadyExisting = {}
	function NPCJournalFrame:SetInfoForPetData(speciesId, outPetData, petDatabaseData)
		local speciesName, speciesIcon, petType, companionID, tooltipSource, tooltipDescription, isWild, canBattle, isTradeable, isUnique, obtainable, creatureDisplayID = C_PetJournal.GetPetInfoBySpeciesID(speciesId)
		outPetData.guide = petDatabaseData.guide
		outPetData.name = speciesName or ""
        
        if NPCJournalFrame.petNameAlreadyExisting[outPetData.name] ~= nil then
            outPetData.name = outPetData.name .. " "
        end
        
        NPCJournalFrame.petNameAlreadyExisting[outPetData.name] = true
        
		outPetData.description = tooltipDescription or ""
		outPetData.petType = petType
        --Lua error workaround
        if PetObjects[companionID] then
            PetObjects[companionID].modelId = creatureDisplayID
            local levels
            outPetData.abilities, levels = C_PetJournal.GetPetAbilityList(speciesId)
            outPetData.abilitiesLevels = {}
            LuaUtils:foreach(outPetData.abilities, function(_, _, index)
                outPetData.abilitiesLevels[outPetData.abilities[index]] = levels[index]
            end)
        end
	end

	function NPCJournalFrame:GetPetData()
		if not DGV:IsModuleRegistered("PetDataModule") then return end
		local petData = {}
		local speciesId = UnitBattlePetSpeciesID("target")
		
		if speciesId then
			local petId = select(4, C_PetJournal.GetPetInfoBySpeciesID(speciesId))
			local displayId = select(12, C_PetJournal.GetPetInfoBySpeciesID(speciesId))

			petData.unitName = "target"
			
			local petDatabaseData = PetObjects[tonumber(petId)]
			if petDatabaseData then
				--petData.modelId = DugisGuideViewer.Modules.ModelViewer.npcDB[tostring(petId)]
				petData.modelId = displayId
				self:SetInfoForPetData(speciesId, petData, petDatabaseData)
				return petData 
			end
		end
	end

	function NPCJournalFrame:GetPetDataById(id)
		local petData = {}
		local petDatabaseData = PetObjects[tonumber(id)]
		if petDatabaseData then
			self:SetInfoForPetData(petDatabaseData.speciesId, petData, petDatabaseData)  
			petData.guide = petDatabaseData.guide
			petData.modelId = petDatabaseData.modelId
			petData.category = petDatabaseData.category
			return petData 
		end

	end

	function NPCJournalFrame:GetBossData()
		if not DGV:IsModuleRegistered("BossDataModule") then return end
		local guid = UnitGUID("target")
		if guid then
			local bossId = DGV:GuidToNpcId(guid)
			
            if BossObjects then
                local bossData = BossObjects[tonumber(bossId)]
                if bossData then
                    bossData.unitName = "target"
                    return bossData 
                end
            end
		end
	end

    NPCJournalFrame.bossNameAlreadyExisting = {}
	function NPCJournalFrame:GetBossDataById(id)
		local bossData = BossObjects[tonumber(id)]
		if bossData then
			if DGV:UserSetting(DGV_ENABLEMODELDB) then 
			bossData.modelId = DugisGuideViewer.Modules.ModelViewer.npcDB[tostring(id)]
			end
            bossData.name = DugisGuideViewer:GetLocalizedNPC(tonumber(id))
            if bossData.name == nil then
            	bossData.name = tonumber(id)
            end
            
            if NPCJournalFrame.bossNameAlreadyExisting[bossData.name] ~= nil then
                bossData.name = bossData.name .. " "
            end
            
            NPCJournalFrame.bossNameAlreadyExisting[bossData.name] = true
            
			return bossData 
		end
	end
    
    NPCJournalFrame.followerNameAlreadyExisting = {}
	function NPCJournalFrame:GetFollowerDataById(id)
		local followerData = FollowerObjects[tonumber(id)]
		if followerData then
            local followerInfo = C_Garrison.GetFollowerInfo(tonumber(id))
			if DGV:UserSetting(DGV_ENABLEMODELDB) then 
			followerData.modelId = DugisGuideViewer.Modules.ModelViewer.npcDB[followerData.NPCID]
			end
           
            followerData.quality = followerInfo.quality
            local _, _, _, qualityColor = GetItemQualityColor(followerInfo.quality) 
            followerData.qualityColor = qualityColor
            followerData.name = followerInfo.name
            
            if NPCJournalFrame.followerNameAlreadyExisting[followerData.name] ~= nil then
                followerData.name = followerData.name .. " "
            end
            
            NPCJournalFrame.followerNameAlreadyExisting[followerData.name] = true            
            
            followerData.level = followerInfo.level
            followerData.formattedName = "|c"..qualityColor..followerInfo.name.." ("..followerData.level.."+)|r"
            followerData.classAtlas = followerInfo.classAtlas
            followerData.class = string.upper(LuaUtils:split(followerData.classAtlas,"-")[2])
            followerData.displayID = followerInfo.displayID
            
            if followerInfo.displayIDs and #followerInfo.displayIDs > 0 then
                followerData.displayID = followerInfo.displayIDs[1].id
            end
            
            followerData.className = followerInfo.className
            
			return followerData 
		end
	end    

	function NPCJournalFrame:GetQuestInfo(questid)
		  GameTooltip:SetOwner(UIParent, _G.ANCHOR_NONE)
		  GameTooltip:SetHyperlink(("quest:%s"):format(tostring(questid)))
		 
		  local name = _G["GameTooltipTextLeft1"]:GetText()
		  
		  if LuaUtils:IsNilOrEmpty(name) then 
			self.needToUpdateTexts = true
			GameTooltip:Hide()
			return nil
		  else
			local result = {}
			result.name = name
			result.description = ""
			LuaUtils:loop(25, function(i)
				if i > 1 then
					local lineName = "GameTooltipTextLeft"..i
					if _G[lineName] then
						local lineText = _G[lineName]:GetText()
						if not LuaUtils:IsNilOrEmpty(lineText) then
							if lineText == "Requirements:" then
								lineText = "|cffffffff"..lineText.."|r"
							end
							result.description = result.description.."\n"..lineText
						end
					end
				end
			end)

			GameTooltip:Hide()
			return result
		  end
	end

	function NPCJournalFrame:ReplaceWaypointTags(text, smallframe, forWhatsNew)
			local buttonId = 0

			-- greendot waypoints:   (x.x, y.y, mapid) 
			local result = string.gsub(text, "%([%s]*[0-9%.]+[%s]*,[%s]*[0-9%.]+[%s]*,[%s]*[0-9]+[%s]*,[%s]*\"[^%(]*\"[^%(]*%)", function(location)
				
			buttonId = buttonId + 1
			location = string.gsub(location, '%(', '')
			location = string.gsub(location, '%)', '')
			local x_y_mapId_description_floor = LuaUtils:split(location, ',')
	   
			local x = LuaUtils:trim(x_y_mapId_description_floor[1])
			local y = LuaUtils:trim(x_y_mapId_description_floor[2])
			local mapId = LuaUtils:trim(x_y_mapId_description_floor[3])
			local description = x_y_mapId_description_floor[4]
			description = string.gsub(description, "\"", "")
			description = LuaUtils:trim(description)
			local floorId = 0
			if x_y_mapId_description_floor[5] then
				floorId = LuaUtils:trim(x_y_mapId_description_floor[5])
			end
			
			local buttonImage = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\|NORMAL"..buttonId.."|IDwaypoint_16|e|HOVER"..buttonId.."|IDwaypoint_y_16|e|EMPTY"..buttonId.."|IDwaypoint_16_t|e.tga"
            
            if smallframe or forWhatsNew then 
                buttonImage = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\waypoint_16.tga"
            end
            
            if smallframe then 
				return '|Hwaypoint:'..x..':'..y..':'..mapId..':'..description..':'..floorId..':'..buttonId..'|h|T'..buttonImage..':11:11:0:-2|t|h|r'
			else
                if forWhatsNew then
                    return '|Hwaypoint:'..x..':'..y..':'..mapId..':'..description..':'..floorId..':'..(buttonId + 1000)..'|h|T'..buttonImage..':11:11:0:-3|t|h|r'
                else
                    return '|Hwaypoint:'..x..':'..y..':'..mapId..':'..description..':'..floorId..':'..buttonId..'|h|T'..buttonImage..':11:11:0:-3|t|h|r'
                end
			end
		end) 
		
		return result
	end

	function NPCJournalFrame:ReplaceSpellTags(text, smallframe, guideIndex, title)
		
		-- example:  text text (spell:39207) text (spell:39207) text text

		local result = string.gsub(text, '%([%s]*spell:[%s]*[0-9]*[%s]*%)', function(spell) 
		
			local spell = string.gsub(spell, '%)', '')
			spell = string.gsub(spell, '%(', '')
			local tag_id = LuaUtils:split(spell, ':')
			local spellId = LuaUtils:trim(tag_id[2])

			local icon = select(3, GetSpellInfo(tonumber(spellId)))
			local link = GetSpellLink(spellId)
			local spellName = select(1, GetSpellInfo(tonumber(spellId)))
			if icon and guideIndex and NPCJournalFrame:RowButtonExists(guideIndex) then 	
				DGV.visualRows[guideIndex].Button:SetNormalTexture(icon)
				DGV.visualRows[guideIndex].Button.validTexture = icon
				DGV.visualRows[guideIndex].Button.tag_id = tag_id[2]
				DGV.visualRows[guideIndex].Button.tagType = "spell"
			end		
			
			if icon == nil and link then 
				return link
			elseif link and title then 
				return '|cff71d5ff'..spellName..'|r'
			elseif link and smallframe then
				return '|T'..icon..':13:13:2:0|t '..link
			elseif link then
				return '|T'..icon..':13:13:2:-2|t '..link		
			elseif icon and spellName then 
				return '|T'..icon..':13:13:2:-2|t |cff71d5ff'..spellName..'|r' --back up sometime GetSpellLink returns nil even thou the spellID exist
			end
		end) 
		
		return result
	end
	
	function NPCJournalFrame:ReplaceAbilTags(text, smallframe, guideIndex, title)
		
		-- example:  text text (abil:39207) text (abil:39207) text text

		local result = string.gsub(text, '%([%s]*abil:[%s]*[0-9]*[%s]*%)', function(abil) 
		
			local abil = string.gsub(abil, '%)', '')
			abil = string.gsub(abil, '%(', '')
			local tag_id = LuaUtils:split(abil, ':')
			local abilId = LuaUtils:trim(tag_id[2])

			local icon = C_Garrison.GetFollowerAbilityIcon(abilId)
			local link = C_Garrison.GetFollowerAbilityLink(abilId)
			local abilName = C_Garrison.GetFollowerAbilityName(abilId)
			if icon and guideIndex and NPCJournalFrame:RowButtonExists(guideIndex) then 
				DGV.visualRows[guideIndex].Button:SetNormalTexture(icon)
				DGV.visualRows[guideIndex].Button.validTexture = icon
				DGV.visualRows[guideIndex].Button.tag_id = tag_id[2]
				DGV.visualRows[guideIndex].Button.tagType = "garrfollowerability"
			end		
			
			if icon == nil and link then 
				return link
			elseif link and title then 
				return '|cff71d5ff'..abilName..'|r'
			elseif link and smallframe then
				return '|T'..icon..':13:13:2:0|t '..link
			elseif link then
				return '|T'..icon..':13:13:2:-2|t '..link		
			elseif icon and abilName then 
				return '|T'..icon..':13:13:2:-2|t |cff4783d7'..abilName..'|r' --back up sometime GetSpellLink returns nil even thou the spellID exist
			end
		end) 
		
		return result
	end	
	
	function NPCJournalFrame:ReplaceCounterTags(text, smallframe, guideIndex, title)
		
		-- example:  text text (counter:39207) text (counter:39207) text text

		local result = string.gsub(text, '%([%s]*counter:[%s]*[0-9]*[%s]*%)', function(counter) 
		
			local counter = string.gsub(counter, '%)', '')
			counter = string.gsub(counter, '%(', '')
			local tag_id = LuaUtils:split(counter, ':')
			local counterId = LuaUtils:trim(tag_id[2])

			local _, counterName, icon = C_Garrison.GetFollowerAbilityCounterMechanicInfo(counterId)
			if icon and guideIndex and NPCJournalFrame:RowButtonExists(guideIndex) then 
				DGV.visualRows[guideIndex].Button:SetNormalTexture(icon)
				DGV.visualRows[guideIndex].Button.validTexture = icon
				DGV.visualRows[guideIndex].Button.tag_id = tag_id[2]
				DGV.visualRows[guideIndex].Button.tagType = "counter"
			end		
			
			if icon == nil and counterName then 
				return counterName
			elseif counterName and title then 
				return counterName
			elseif counterName and smallframe then
				return '|T'..icon..':13:13:2:0|t '..counterName
			elseif icon and counterName then 
				return '|T'..icon..':13:13:2:-2|t '..counterName
			end
		end) 
		
		return result
	end		
	
	function NPCJournalFrame:ReplaceBuildingTags(text, smallframe, guideIndex, title)
		
		-- example:  text text (building:39207) text (building:39207) text text

		local result = string.gsub(text, '%([%s]*building:[%s]*[0-9]*[%s]*%)', function(building) 
		
			local building = string.gsub(building, '%)', '')
			building = string.gsub(building, '%(', '')
			local tag_id = LuaUtils:split(building, ':')
			local buildingId = LuaUtils:trim(tag_id[2])

			local _, buildingName, _, icon, description, rank = C_Garrison.GetBuildingInfo(buildingId)
			if icon and guideIndex and NPCJournalFrame:RowButtonExists(guideIndex) then 
				DGV.visualRows[guideIndex].Button:SetNormalTexture(icon)
				DGV.visualRows[guideIndex].Button.validTexture = icon
				DGV.visualRows[guideIndex].Button.tag_id = tag_id[2]
				DGV.visualRows[guideIndex].Button.tagType = "building"
			end		
			
			if icon == nil and buildingName then 
				return '|cffffd200'..LEVEL..' '..rank..' '..buildingName..'|r'
			elseif buildingName and title then 
				return buildingName
			elseif buildingName and smallframe then
				return '|T'..icon..':13:13:2:0|t |cffffd200'..LEVEL..' '..rank..' '..buildingName..'|r'
			elseif icon and buildingName then 
				return '|T'..icon..':13:13:2:-2|t |cffffd200'..LEVEL..' '..rank..' '..buildingName..'|r'
			end
		end) 
		
		return result
	end	
	
	function NPCJournalFrame:ReplaceMissionTags(text, smallframe, guideIndex, title)
		
		-- example:  text text (building:39207) text (building:39207) text text

		local result = string.gsub(text, '%([%s]*mission:[%s]*[0-9]*[%s]*%)', function(mission) 
		
			local mission = string.gsub(mission, '%)', '')
			mission = string.gsub(mission, '%(', '')
			local tag_id = LuaUtils:split(mission, ':')
			local missionId = LuaUtils:trim(tag_id[2])

			local name = C_Garrison.GetMissionName(missionId)		
			
			if name then 
				return "|c99aaff00"..name.."|r"
			end
		end) 
		
		return result
	end		
    
    function NPCJournalFrame:GetAllChoicesFromText(text)
        local allChoices = {}
        
        if text then
            for match_ in string.gmatch(text, '%([%s]*choice:[%s]*[^%)]*[%s]*%)') do 
                table.insert(allChoices, match_) 
            end
            
            if #allChoices > 0 then
                LuaUtils:foreach(allChoices, function(choice, index)
                    local choice = string.gsub(choice, '%)', '')
                    choice = string.gsub(choice, '%(', '')
                    local tag_id_description = LuaUtils:split(choice, ':')
                    local choiceId = LuaUtils:trim(tag_id_description[2])
                    
                    allChoices[index] = choiceId
                end)
            end
        end
        
        return allChoices
    end

	function NPCJournalFrame:ReplaceChoiceTags(text)
        local allChoices = NPCJournalFrame:GetAllChoicesFromText(text)
        local allChoicesText = ""
      
        if #allChoices > 0 then
            allChoicesText = ":"..table.concat(allChoices, ":")
        end
        
		local result = string.gsub(text, '%([%s]*choice:[%s]*[^%)]*[%s]*%)', function(choice) 
			local choice = string.gsub(choice, '%)', '')
			choice = string.gsub(choice, '%(', '')
			local tag_id_description = LuaUtils:split(choice, ':')
			local choiceId = LuaUtils:trim(tag_id_description[2])
			local choiceDescription = LuaUtils:trim(tag_id_description[3])
			
			return '|Hchoice:'..choiceId..allChoicesText..'|h|TInterface\\Tooltips\\ReforgeGreenArrow:14:14:0:-1|t|cff66ff00 '..LuaUtils:trim(choiceDescription)..'|r|h'
		end) 
        
        local extraAddon = ""
        
        if #allChoices > 0 then
            extraAddon = '|HALLCHOICES'..table.concat(allChoices, ":")..'END|h |h'
        end
		
        return result .. extraAddon
	end
	
	function NPCJournalFrame:RowButtonExists(guideIndex)
		return DGV.visualRows[guideIndex] and DGV.visualRows[guideIndex].Button
	end

	function NPCJournalFrame:ReplaceItemTags(text, smallframe, guideIndex, title)
		
		-- example:  text text (item:39207) text (item:39207) text text
		local result = string.gsub(text, '%([%s]*item:[%s]*[0-9]*[%s]*%)', function(item) 
		
			item = string.gsub(item, '%)', '')
			item = string.gsub(item, '%(', '')
			local tag_id = LuaUtils:split(item, ':')
			local icon 
			if not tag_id[2] then return result end
			icon = select(10, GetItemInfo(tag_id[2]))
			local isCollect
			
			if icon and guideIndex and NPCJournalFrame:RowButtonExists(guideIndex) then 
				isCollect = DGV.visualRows[guideIndex].Button.validTexture == "Interface\\Minimap\\TRACKING\\Banker" or DGV.visualRows[guideIndex].Button.validTexture == "Interface\\Minimap\\TRACKING\\Auctioneer"
				if not isCollect then
					DGV.visualRows[guideIndex].Button:SetNormalTexture(icon)
					DGV.visualRows[guideIndex].Button.validTexture = icon
					DGV.visualRows[guideIndex].Button.tag_id = tag_id[2]
					DGV.visualRows[guideIndex].Button.tagType = "item"
				end
			end		
			
			local link = select(2, GetItemInfo(tag_id[2]))

			if icon == nil and link then 
				return link
			elseif link and title and isCollect then 
				return '|T'..icon..':18:18:-1:-1|t'..link
			elseif link and title then 
				return link			
			elseif link and smallframe then
				return '|T'..icon..':13:13:2:0|t '..link
			elseif link then
				return '|T'..icon..':13:13:2:-2|t '..link		
			end
		end) 
		
		return result
	end

	function NPCJournalFrame:ReplaceNPCTags(text)
		
        --Expand waypoint names
		-- example:  text text "(npc:39207)" text text
		local result = string.gsub(text, '"%([%s]*npc:[%s]*[0-9]*[%s]*%)"', function(npc) 
			local npcText = string.gsub(npc, '%)"', '')
			npcText = string.gsub(npcText, '"%(', '')
			local tag_id = LuaUtils:split(npcText, ':')
			local npcId = tag_id[2]
			local npcName = DugisGuideViewer:GetLocalizedNPC(npcId)
			if npcName then
				return '"'..LuaUtils:trim(npcName)..'"'
			else
				return npc
			end
		end) 
        
        
        --Expanding npcs to link
		-- example:  text text (npc:39207) text (npc:39207) text text
		result = string.gsub(result, '%([%s]*npc:[%s]*[0-9]*[%s]*%)', function(npc) 
		
			local npcText = string.gsub(npc, '%)', '')
			npcText = string.gsub(npcText, '%(', '')
			local tag_id = LuaUtils:split(npcText, ':')
			local npcId = tag_id[2]
			local npcName = DugisGuideViewer:GetLocalizedNPC(npcId)
			if npcName then
				return '|Hnpc:'..npcId..'|h|cffffe8aa'..LuaUtils:trim(npcName)..'|r|h'
			else
				return npc
			end
		end) 
		
		return result
	end

	function NPCJournalFrame:ReplaceAchievementTags(text, smallframe, guideIndex, title)
		-- example:  text text (aid:39207) text (aid:39207) text text
		local result = string.gsub(text, '%([%s]*aid:[%s]*[0-9]*[%s]*%)', function(textFound) 
		
			local newText = string.gsub(textFound, '%)', '')
			newText = string.gsub(newText, '%(', '')
			local tag_id = LuaUtils:split(newText, ':')
			local id = tag_id[2]
			local icon = select(10, GetAchievementInfo(id))
			if icon and guideIndex and NPCJournalFrame:RowButtonExists(guideIndex) then 
				DGV.visualRows[guideIndex].Button:SetNormalTexture(icon)
				DGV.visualRows[guideIndex].Button.validTexture = icon
				DGV.visualRows[guideIndex].Button.tag_id = tag_id[2]
				DGV.visualRows[guideIndex].Button.tagType = "aid"
			end
			
			local link = GetAchievementLink(tag_id[2])

			if icon == nil and link then 
				return link
			elseif link and title then 
				return link			
			elseif link and smallframe then
				return '|T'..icon..':13:13:2:0|t '..link			
			elseif link then
				return '|T'..icon..':13:13:2:-2|t '..link
			end
		end) 
		return result
	end

	function NPCJournalFrame:ReplaceSpeciesTags(text, smallframe, guideIndex, title)
		-- example:  text text (aid:39207) text (aid:39207) text text
		local result = string.gsub(text, '%([%s]*species:[%s]*[0-9]*[%s]*%)', function(textFound) 
		
			local newText = string.gsub(textFound, '%)', '')
			newText = string.gsub(newText, '%(', '')
			local tag_id = LuaUtils:split(newText, ':')
			local id = tag_id[2]
			local npcName = select(1, C_PetJournal.GetPetInfoBySpeciesID(id))
			local icon = select(2, C_PetJournal.GetPetInfoBySpeciesID(id))
			local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(id))
			if icon and guideIndex and NPCJournalFrame:RowButtonExists(guideIndex) then 
				DGV.visualRows[guideIndex].Button:SetNormalTexture(icon)
				DGV.visualRows[guideIndex].Button.validTexture = icon
				DGV.visualRows[guideIndex].Button.tag_id = tag_id[2]
				DGV.visualRows[guideIndex].Button.tagType = "species"			
			end

			if icon == nil and npcName then 
				return '|Hnpc:'..npcId..'|h|cffffe8aa'..npcName..'|r|h'
			elseif npcName and title then 
				return '|Hnpc:'..npcId..'|h|cffffe8aa'..npcName..'|r|h'			
			elseif npcName and smallframe then
				return '|T'..icon..':13:13:2:0|t '..'|Hnpc:'..npcId..'|h|cffffe8aa'..npcName..'|r|h'						
			elseif link then
				return '|T'..icon..':13:13:2:-2|t '..'|Hnpc:'..npcId..'|h|cffffe8aa'..npcName..'|r|h'			
			end
		end) 
		return result
	end

	function NPCJournalFrame:ReplaceQuestTags(text, smallframe, guideIndex, title)
		-- example:  text text (qid:39207) text (qid:39207) text text
		local result = string.gsub(text, '%([%s]*qid:[%s]*[0-9]*[%s]*%)', function(textFound) 
			local newText = string.gsub(textFound, '%)', '')
			newText = string.gsub(newText, '%(', '')
			local tag_id = LuaUtils:split(newText, ':')
			local id = tag_id[2]
			local questInfo = self:GetQuestInfo(id)
			
			if questInfo and smallframe then
				return '|TInterface\\GossipFrame\\AvailableQuestIcon:12:12:0.5:0|t|Hquest:'..id..'|h|cffffff00'..LuaUtils:trim(questInfo.name)..'|r|h'
			elseif questInfo then
				return '|TInterface\\GossipFrame\\AvailableQuestIcon:12:12:1:-2|t|Hquest:'..id..'|h|cffffff00'..LuaUtils:trim(questInfo.name)..'|r|h'
			else
				return textFound
			end
		end) 
		return result
	end
    
	function NPCJournalFrame:ReplaceGuideTags(text, smallframe, guideIndex, title, forWhatsNew)
        local uniqueGuideLinkID = 0
        local forWhatsNewText = ""
        
        if forWhatsNew then
            forWhatsNewText = ":whatsnew"
        end
        
		local result = string.gsub(text, '%([%s]*guide:[%s]*["][^"]*["][%s]*%)', function(textFound) 
            uniqueGuideLinkID = uniqueGuideLinkID + 1
        
			local newText = string.gsub(textFound, '%)$', '')
			newText = string.gsub(newText, '^%(', '')
			newText = string.gsub(newText, '["]', '')
			local tag_id = LuaUtils:split(newText, ':')
			local guideRawTitle = tag_id[2]

			local color = "ff44ff44"		

            local formattedTitle = DugisGuideViewer:GetFormattedTitle(guideRawTitle)
            
			return '|Hguide:'..guideRawTitle..forWhatsNewText..":"..uniqueGuideLinkID..'|h|c'..color..'['..formattedTitle..']|r|h'

		end) 
		return result
	end

	function NPCJournalFrame:ReplaceCurrencyTags(text, smallframe)
		-- example:  text text (cur:392) 
		local result = string.gsub(text, '%([%s]*cur:[%s]*[0-9]*[%s]*%)', function(textFound) 
		
			local newText = string.gsub(textFound, '%)', '')
			newText = string.gsub(newText, '%(', '')
			local tag_id = LuaUtils:split(newText, ':')
			local id = tag_id[2]
			--local name = GetCurrencyInfo(id)
			local icon = select(3, GetCurrencyInfo(id))
			local link = GetCurrencyLink(id, 1)
			
			if icon == nil and link then 
				return link
			elseif link and smallframe then
				return '|T'..icon..':13:13:2:0|t '..link			
			elseif link then
				return '|T'..icon..':13:13:2:-2|t '..link
			end

		end) 
		return result
	end

	function NPCJournalFrame:ReplaceFactionTags(text)
		-- example:  text text (fac:392) 
		local result = string.gsub(text, '%([%s]*fac:[%s]*[0-9]*[%s]*%)', function(textFound) 
		
			local newText = string.gsub(textFound, '%)', '')
			newText = string.gsub(newText, '%(', '')
			local tag_id = LuaUtils:split(newText, ':')
			local id = tag_id[2]
			local name = GetFactionInfoByID(id)
			if name then
				return '|Hfaction:'..id..'|h|cffffd200'..LuaUtils:trim(name)..'|r|h'
			else
				 return textFound
			 end
		 end) 
		 return result
	end

	function NPCJournalFrame:ReplaceMapTags(text, token, noColoring)
        if token == nil then
            token = "map"
        end
        
		-- example:  text text (cur:392) 
		local result = string.gsub(text, '%([%s]*'..token..':[%s]*[0-9]*[%s]*%)', function(textFound) 
		
			local newText = string.gsub(textFound, '%)', '')
			newText = string.gsub(newText, '%(', '')
			local tag_id = LuaUtils:split(newText, ':')
			local id = tag_id[2]
			
			local UiMapID = DGV:OldMapId2UiMapID(id)
			local name = DGV:GetMapNameFromID(id) 
			if name then
                if noColoring == true then
                    return LuaUtils:trim(name)
                else
                    return '|cffffffff'..LuaUtils:trim(name)..'|r'
                end
			else
				return textFound
			end
		end) 
		return result
	end

	function NPCJournalFrame:ReplaceSpecialTags(text, smallframe, guideIndex, title, forWhatsNew)
		if not text then
			return text
		end
		
		local result = self:ReplaceSpellTags(text, smallframe, guideIndex, title)
		result = self:ReplaceItemTags(result, smallframe, guideIndex, title)
		result = self:ReplaceNPCTags(result)
		result = self:ReplaceChoiceTags(result)
		result = self:ReplaceWaypointTags(result, smallframe, forWhatsNew)
		result = self:ReplaceAchievementTags(result, smallframe, guideIndex, title)
		result = self:ReplaceSpeciesTags(result, smallframe, guideIndex, title)
		result = self:ReplaceQuestTags(result, smallframe, guideIndex, title)
		result = self:ReplaceGuideTags(result, smallframe, guideIndex, title, forWhatsNew)
		result = self:ReplaceCurrencyTags(result, smallframe, guideIndex, title)
		result = self:ReplaceFactionTags(result)
		result = self:ReplaceMapTags(result)
		result = self:ReplaceAbilTags(result, smallframe, guideIndex, title)
		result = self:ReplaceCounterTags(result, smallframe, guideIndex, title)
		result = self:ReplaceBuildingTags(result, smallframe, guideIndex, title)
		result = self:ReplaceMissionTags(result)
		if smallframe then 
			result = string.gsub(result, "<g>", "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:1:0|t")
			result = string.gsub(result, "<s>", "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:1:0|t")
			result = string.gsub(result, "<c>", "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:1:0|t")
			result = string.gsub(result, "<alliance>", "|TInterface\\\WorldStateFrame\\AllianceIcon:14:14:1:0|t")
			result = string.gsub(result, "<horde>", "|TInterface\\\WorldStateFrame\\HordeIcon:14:14:1:0|t")
			result = string.gsub(result, "<heroic>", "|TInterface\\EncounterJournal\\UI-EJ-HeroicTextIcon:14:14:1:0|t")		
			result = string.gsub(result, "<br/><b>", "|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\blank:18:1:0:0|t\n|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\bullet:11:11:0:0|t ") --ghetto bullet spacing
			result = string.gsub(result, "<b>", "|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\bullet:11:11:0:0|t ") --ghetto bullet spacing
		else
			result = string.gsub(result, "<g>", "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:1:-2|t")
			result = string.gsub(result, "<s>", "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:1:-2|t")
			result = string.gsub(result, "<c>", "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:1:-2|t")		
			result = string.gsub(result, "<alliance>", "|TInterface\\\WorldStateFrame\\AllianceIcon:14:14:1:-2|t")
			result = string.gsub(result, "<horde>", "|TInterface\\\WorldStateFrame\\HordeIcon:14:14:1:-2|t")
			result = string.gsub(result, "<heroic>", "|TInterface\\EncounterJournal\\UI-EJ-HeroicTextIcon:14:14:1:-2|t")		
			result = string.gsub(result, "<br/><b>", "|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\blank:18:1:0:0|t\n|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\bullet:10:10:2:-3|t ") --ghetto bullet spacing
			result = string.gsub(result, "<b>", "|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\bullet:10:10:2:-3|t ") --ghetto bullet spacing
		end
		result = string.gsub(result, "<br/>", "\n")
		result = string.gsub(result, "{(.*)}", "|cffff0000%1|r")	
		return result
	end

    local function CategoryName2Table(categoryName)
        local result = LuaUtils:split(categoryName, '->')
        if #result == 1 then
            return result[1]
        end
        return result
    end

	-------------------------- DATABASE TRANSFORMATION ---------------------------
    
    
    function NPCJournalFrame:InitializeData(threading)
        ------- NPC Data -------
        if DGV:IsModuleRegistered("NPCDataModule") then 
            local NPCDataTable = LuaUtils:split(DGV:GetData("NPCData"), '\n')
            
            NPCObjects = {}
            NPCIds = {}
            
            local currentCategory = nil
            
            local lastCategory = "Elites"
            local j = 1
            for i, content in ipairs(NPCDataTable) do
                currentCategory = content:match("|CAT|([^|]*)|")
                
                if currentCategory ~= nil then
                    lastCategory = CategoryName2Table(NPCJournalFrame:ReplaceMapTags(currentCategory, "mapid", true))
                end
            
                if currentCategory == nil then
                    local NPCID = tonumber(content:match("|NPCID|([^|]*)|"))
                    
                    --Creating indices for alternative categories. Later on the -altcat will be removed to get NPC id
                    while NPCObjects[NPCID] ~= nil do
                        NPCID = NPCID .. "-altcat"
                    end
					
					LuaUtils:RestIfNeeded(threading)
                    
                    NPCObjects[NPCID] = {}
                    NPCObjects[NPCID].Name = LuaUtils:matchString(content, "|Name|([^|]*)|")
                    NPCObjects[NPCID].LVL =  LuaUtils:matchString(content, "|LVL|([^|]*)|")
                    NPCObjects[NPCID].ABIL =  LuaUtils:matchString(content, "|ABIL|([^|]*)|")
                    NPCObjects[NPCID].ABIL =  LuaUtils:split(NPCObjects[NPCID].ABIL, ',')
                    
                    --Prevented game crash/stack overflow
                    content = content:gsub("|NDIS| |", "|NDIS||")
                    NPCObjects[NPCID].NDIS =  LuaUtils:matchString(content, "|NDIS|([^|]*)|")
                    NPCObjects[NPCID].NDIS =  LuaUtils:split(NPCObjects[NPCID].NDIS, ',')
                    NPCObjects[NPCID].ST =  LuaUtils:matchString(content, "|ST|([^|]*)|")
                    
                    NPCObjects[NPCID].CSST =  LuaUtils:matchString(content, "|CSST|([^|]*)|")
                    NPCObjects[NPCID].category = lastCategory
                    NPCIds[j] = NPCID
                    j = j+1
                end
            end
            
            NPCDataTable = {}
        end

        ------- Mount Data -------
        if DGV:IsModuleRegistered("MountDataModule") then
            local MountDataTable = LuaUtils:split(DGV:GetData("MountData"), '\n')
            
            MountObjects = {}
            MountDataIds = {}
            MountJournalIndices = {}
            
            local lastCategory = "Mounts"
            
            local j = 1
            for i, content in ipairs(MountDataTable) do
                currentCategory = content:match("|CAT|([^|]*)|")
                
                if currentCategory ~= nil then
                    lastCategory = CategoryName2Table(NPCJournalFrame:ReplaceMapTags(currentCategory, "mapid", true))
                end
				
				LuaUtils:RestIfNeeded(threading)
                
                if currentCategory == nil then
                    local MSID = tonumber(content:match("|MSID|([^|]*)|"))
                    
                    MountObjects[MSID] = {}
                    MountObjects[MSID].guide =  LuaUtils:matchString(content, "|GUIDE|([^|]*)|")
                    MountObjects[MSID].displayId =  LuaUtils:matchString(content, "|DID|([^|]*)|")
                    MountObjects[MSID].faction =  LuaUtils:matchString(content, "|FAC|([^|]*)|")
                    MountObjects[MSID].category = lastCategory
                    MountDataIds[j] = MSID
                    j = j + 1
                end
            end
            --Legion beta cheap fix
            local ids = C_MountJournal.GetMountIDs()

            LuaUtils:foreach(ids, function(id)
                local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected = C_MountJournal.GetMountInfoByID(id)
                MountJournalIndices[spellID] = id
            end)
            
            MountDataTable = {}
        end

        ------- Pet Data -------
        if DGV:IsModuleRegistered("PetDataModule") then
            local PetDataTable = LuaUtils:split(DGV:GetData("PetData"), '\n')
            
            PetObjects = {}
            PetDataIds = {}
            
            local lastCategory = "Pets"
            
            local j = 1
            for i, content in ipairs(PetDataTable) do
                currentCategory = content:match("|CAT|([^|]*)|")
                
                if currentCategory ~= nil then
                    lastCategory = CategoryName2Table(NPCJournalFrame:ReplaceMapTags(currentCategory, "mapid", true))
                end
				
				LuaUtils:RestIfNeeded(threading)
                
                if currentCategory == nil then
                    local PID = tonumber(content:match("|PID|([^|]*)|"))
                    
                    PetObjects[PID] = {}
                    PetObjects[PID].guide =  LuaUtils:matchString(content, "|GUIDE|([^|]*)|")
                    PetObjects[PID].speciesId =  LuaUtils:matchString(content, "|SID|([^|]*)|")
                    PetObjects[PID].faction =  LuaUtils:matchString(content, "|FAC|([^|]*)|")
                    PetObjects[PID].category = lastCategory
                    PetDataIds[j] = PID 
                    j = j + 1
                end
            end
            
            PetDataTable = {}
        end

        ------- Boss Data -------
        if DGV:IsModuleRegistered("BossDataModule") then
            local BossDataTable = LuaUtils:split(DGV:GetData("BossData"), '\n')
            
            BossObjects = {}
            BossDataIds = {}
            
            local i = 1
            
            --Auto means "map name"
            local lastCategory = "Auto"
            
            local j = 1
            for _, content in ipairs(BossDataTable) do
                currentCategory = content:match("|CAT|([^|]*)|")
                
                if currentCategory ~= nil then
                    lastCategory = CategoryName2Table(NPCJournalFrame:ReplaceMapTags(currentCategory, "mapid", true))
                end
				
				LuaUtils:RestIfNeeded(threading)
            
                if currentCategory == nil then
                
                    local BOSSIDText = content:match("|BOSSID|([^|]*)|")
                    local versions = LuaUtils:split(BOSSIDText, ",")
                    
                    local versionIndex = 1
                    LuaUtils:foreach(versions, function(BOSSID)
                        BOSSID = tonumber(BOSSID)
                        BossObjects[BOSSID] = {}
                        BossObjects[BOSSID].Strategy = LuaUtils:matchString(content, "|ST|([^|]*)|")
                        BossObjects[BOSSID].DPSText = LuaUtils:matchString(content, "|DPS|([^|]*)|")
                        BossObjects[BOSSID].HEALText = LuaUtils:matchString(content, "|HEAL|([^|]*)|")
                        BossObjects[BOSSID].TANKText = LuaUtils:matchString(content, "|TANK|([^|]*)|")
                        BossObjects[BOSSID].MAPID =  LuaUtils:matchString(content, "|MAPID|([^|]*)|")
                        BossObjects[BOSSID].category = lastCategory
                        BossDataIds[j] = BOSSID  
                        if versionIndex > 1 then
                            BossObjects[BOSSID].alternative = true
                        end
                        i = i + 1
                        versionIndex = versionIndex + 1
                    end) 
                    j = j + 1
                    
                end
            end
            
            BossDataTable = {}
        end
        
        ------- Follower Data -------
        if DGV:IsModuleRegistered("FollowerDataModule") then
        
            local FollowerDataTable
            local englishFaction, _ = UnitFactionGroup("Player")
            
            if englishFaction == "Alliance" then
                FollowerDataTable = LuaUtils:split(DGV:GetData("FollowerData_A"), '\n')
            else
                FollowerDataTable = LuaUtils:split(DGV:GetData("FollowerData_H"), '\n')
            end
            
            FollowerObjects = {}
            FollowerDataIds = {}
            
            local lastCategory = "Followers"
            
            local j = 1
            for i, content in ipairs(FollowerDataTable) do
                currentCategory = content:match("|CAT|([^|]*)|")
                
                if currentCategory ~= nil then
                    lastCategory = CategoryName2Table(NPCJournalFrame:ReplaceMapTags(currentCategory, "mapid", true))
                end
                
				LuaUtils:RestIfNeeded(threading)
				
                if currentCategory == nil then
                    local FID = tonumber(content:match("|FID|([^|]*)|"))
                    FollowerObjects[FID] = {}
                    FollowerObjects[FID].guide = LuaUtils:matchString(content, "|GUIDE|([^|]*)|")
                    FollowerObjects[FID].NPCID = LuaUtils:matchString(content, "|NPCID|([^|]*)|")
                    FollowerObjects[FID].category = lastCategory
                    FollowerDataIds[j] = FID 
                    j = j + 1
                end
            end
            
            FollowerDataTable = {}
        end
    end


	----------------------- GUIDES ---------------------------
	function NPCJournalFrame:BuildGuidesData()
		if not DGV.guides or self.guidesData then
			return
		end

		local OnGuideItemClick = function(guide)
			--self.modelAngle = 0.0
			self:SetGuideData(guide.guideType, guide.objectId, true)
		end 
        
        NPCJournalFrame.OnGuideItemClick = OnGuideItemClick

		self.guidesData = {}
		local guidesData = self.guidesData

		-- NPCs
		if DGV:IsModuleRegistered("NPCDataModule") then 
			guidesData[#guidesData + 1] = {guideType = "NPC", titles = {}, tabId = 12} 
			local postFix = "|Htype:"..guidesData[#guidesData].guideType.."|h |h"
			LuaUtils:foreach(NPCIds, function(item)
				local nPC = NPCObjects[item]
				local level = NPCObjects[item].LVL
				local title = DugisGuideViewer:GetLocalizedNPC(item)
				if not title then
					title = "NPC: "..item
				end
				--trick to make titles unique
				title = level..": "..title..postFix
				
				guidesData[#guidesData].titles[#guidesData[#guidesData].titles + 1] = title
				DGV.guides[title] = {OnGuideItemClick = OnGuideItemClick, objectId = item, guideType = guidesData[#guidesData].guideType}
				DGV.headings[title] = "" -- custom search text (not visible - only for search purposes)
			end)
		end 
		
		-- Mounts
		if DGV:IsModuleRegistered("MountDataModule") then 
			guidesData[#guidesData + 1] = {guideType = "Mounts", titles = {}, tabId = 13} 
			local postFix = "|Htype:"..guidesData[#guidesData].guideType.."|h |h"
			LuaUtils:foreach(MountDataIds, function(item)
				local mount = MountObjects[item]
				local title = GetSpellInfo(item) 
				local faction = MountObjects[item].faction
				if not title then
					title = "Mount: "..item               
				end
				--trick to make titles unique
				if faction ~= "" then 
					title = title.." - "..faction..postFix
				else
					title = title..postFix
				end
				
				guidesData[#guidesData].titles[#guidesData[#guidesData].titles + 1] = title
				DGV.guides[title] = {OnGuideItemClick = OnGuideItemClick, objectId = item, guideType = guidesData[#guidesData].guideType}
				DGV.headings[title] = "" -- custom search text (not visible - only for search purposes)
			end) 
		end
		
		-- Pets
		if DGV:IsModuleRegistered("PetDataModule") then
			guidesData[#guidesData + 1] = {guideType = "Pets", titles = {}, tabId = 14} 
			local postFix = "|Htype:"..guidesData[#guidesData].guideType.."|h |h"
			LuaUtils:foreach(PetDataIds, function(item)
				local pet = PetObjects[item].speciesId
				local title = C_PetJournal.GetPetInfoBySpeciesID(pet)
				local faction = PetObjects[item].faction
				if not title then
					title = "Pet: "..item
				end
				--trick to make titles unique
				if faction ~= "" then 
					title = title.." - "..faction..postFix
				else
					title = title..postFix
				end
				
				guidesData[#guidesData].titles[#guidesData[#guidesData].titles + 1] = title
				DGV.guides[title] = {OnGuideItemClick = OnGuideItemClick, objectId = item, guideType = guidesData[#guidesData].guideType}
				DGV.headings[title] = "" -- custom search text (not visible - only for search purposes)
			end) 
		end
		
		-- Boss
		if DGV:IsModuleRegistered("BossDataModule") then 
			guidesData[#guidesData + 1] = {guideType = "Bosses", titles = {}, tabId = 15} 
			local postFix = "|Htype:"..guidesData[#guidesData].guideType.."|h |h"
			LuaUtils:foreach(BossDataIds, function(item)
				local boss = BossObjects[item]
                if not boss.alternative then
                    local title = DugisGuideViewer:GetLocalizedNPC(item)
				--print("x", tonumber(BossObjects[item].MAPID))
					local UiMapID = DGV:OldMapId2UiMapID(tonumber(BossObjects[item].MAPID))
                    local map = DGV:GetMapNameFromID(UiMapID)
                    if not title then
                        title = "Boss: "..item
                    end
                    --trick to make titles unique
                    title = map..": "..title..postFix
                    
                    guidesData[#guidesData].titles[#guidesData[#guidesData].titles + 1] = title
                    DGV.guides[title] = {OnGuideItemClick = OnGuideItemClick, objectId = item, guideType = guidesData[#guidesData].guideType}
                    DGV.headings[title] = "" -- custom search text (not visible - only for search purposes)
                end
			end) 
		end   

        -- Follower
		if DGV:IsModuleRegistered("FollowerDataModule") then 
			guidesData[#guidesData + 1] = {guideType = "Followers", titles = {}, tabId = 18} 
			local postFix = "|Htype:"..guidesData[#guidesData].guideType.."|h |h"
			LuaUtils:foreach(FollowerDataIds, function(item)
                local followerData = NPCJournalFrame:GetFollowerDataById(item)
                local title = followerData.name.." ("..followerData.level.."+)"
                if not title then
                    title = "Follower: "..item
                end
                
                guidesData[#guidesData].titles[#guidesData[#guidesData].titles + 1] = title
                DGV.guides[title] = {OnGuideItemClick = OnGuideItemClick, objectId = item, guideType = guidesData[#guidesData].guideType}
                DGV.headings[title] = ""
			end) 
		end        
	  
	end


	-------------------------- GUI - LAYOUT ---------------------------
	GUIUtils:SetBaseFrameLevel(10)

	local mainFrame = CreateFrame("Frame", "DragrFrame2", UIParent)
	NPCJournalFrame.mainFrame = mainFrame

	function NPCJournalFrame:CreateGUI()
        if self.scrollframe ~= nil then
            self:RegisterEvents()
            return
        end
        
		GUIUtils:SetNextFrameLevel(mainFrame)

		mainFrame:SetMovable(true)
		mainFrame:EnableMouse(true)
		mainFrame:SetClampedToScreen(true)
		mainFrame:RegisterForDrag("LeftButton")
		mainFrame:SetFrameStrata("DIALOG")

		mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
		mainFrame:SetScript("OnDragStop", function(...)
			mainFrame.StopMovingOrSizing(...)

			DugisNPCFrameDB['point'], relativeTo, DugisNPCFrameDB['relativePoint'], DugisNPCFrameDB['mainFrameLastX'], DugisNPCFrameDB['mainFrameLastY'] 
			= mainFrame:GetPoint(1)
		end)

		if DugisNPCFrameDB['mainFrameLastX'] then
			mainFrame:SetPoint(DugisNPCFrameDB['point'], nil, DugisNPCFrameDB['relativePoint']
			, DugisNPCFrameDB['mainFrameLastX'], DugisNPCFrameDB['mainFrameLastY'])
		else
			mainFrame:SetPoint("CENTER")
		end

		mainFrame:SetWidth(326) 
		mainFrame:SetHeight(399)
		
		mainFrame:Hide()

		mainFrame:SetBackdrop({bgFile = [[Interface\AddOns\DugisGuideViewerZ\Artwork\NPCViewer\npc_journal_background.tga]]
		, edgeFile =  DugisGuideViewer:GetBorderPath(), 
												tile = false, tileSize = 32, edgeSize = 32, 
												insets = { left = 10, right = -207, top = 11, bottom = -131 }});
												
		DugisGuideViewer.ApplyElvUIColor(mainFrame)								
																
												
		local scrollframe = GUIUtils:CreateScrollFrame(mainFrame)
		
		mainFrame:EnableMouseWheel(true)
		mainFrame:SetScript("OnMouseWheel", function(self, delta)
			scrollframe.scrollBar:SetValue(scrollframe.scrollBar:GetValue() - delta * 24)  
		end)  

		local contents =
			LuaUtils:loop(amountOfTabs, 
				function(i) 
					return CreateFrame("Frame", nil, scrollframe.frame) 
				end)

		LuaUtils:foreach(contents, function(item)
			GUIUtils:SetNextFrameLevel(item)
			item:SetSize(128, 128)
			item:CreateTexture():SetAllPoints()
		end)    

		-- NPC--------
		local npcModelContainer = CreateFrame("Frame", "npcModelContainer", contents[STRATEGY_TAB])

		GUIUtils:SetNextFrameLevel(npcModelContainer)

		npcModelContainer:SetMovable(false)
		npcModelContainer:EnableMouse(false)

		npcModelContainer:SetPoint("TOPLEFT", contents[STRATEGY_TAB], "TOPLEFT", 4, 0)
		npcModelContainer:SetWidth(283) 
		npcModelContainer:SetHeight(135)

		local npcModelContainertex = npcModelContainer:CreateTexture(nil, "BACKGROUND")
		
		npcModelContainertex:SetAllPoints()
		npcModelContainertex:SetTexture(0.15, 0.15, 0.15, 0.8)    
		
		
		-- Mount---------
		local guideModelContainer = CreateFrame("Frame", "guideModelContainer", contents[GUIDE_TAB])

		GUIUtils:SetNextFrameLevel(guideModelContainer)

		guideModelContainer:SetMovable(false)
		guideModelContainer:EnableMouse(false)

		guideModelContainer:SetPoint("TOPLEFT", contents[GUIDE_TAB], "TOPLEFT", 4, 0)
		guideModelContainer:SetWidth(283) 
		guideModelContainer:SetHeight(135)

		local guideModelContainertex = guideModelContainer:CreateTexture(nil, "BACKGROUND")
		
		guideModelContainertex:SetAllPoints()
		guideModelContainertex:SetTexture(0.15, 0.15, 0.15, 0.8)      
		
		
		-------------------- Tabs -------------------------------
		local x = 24
		local y = -17
		local w = 47.0
		local xGap = 25.0

		self.tabButtons = {}
		LuaUtils:foreach({{buttonName = "tab1Button", text = "Guide", tab = STRATEGY_TAB},
						  {buttonName = "tab2Button", text = "Abilities", tab = ABILITIES_TAB},
						  {buttonName = "tab3Button", text = "Loot", tab = LOOT_TAB},
						  {buttonName = "tab4Button", text = "Guide", tab = GUIDE_TAB},
						  {buttonName = "tab5Button", text = "Damage", tab = DPS_TAB},
						  {buttonName = "tab6Button", text = "Healer", tab = HEAL_TAB},
						  {buttonName = "tab7Button", text = "Tank", tab = TANK_TAB},
						  {buttonName = "tab8Button", text = "Abilities", tab = PET_ABILITIES_TAB}}, function(item, k, i)
			self[item.buttonName] = GUIUtils:AddButtonCoord(NPCJournalFrame.mainFrame, item.text, 0, 0, w, 23.0, 0.00000000, 1.00000000, 0.67382813, 0.74414063, 
			function(self) 
				NPCJournalFrame:SetTab(item.tab);
			end
			,nil ,nil ,nil ,nil ,"TopTabTemplate" ) 
			self.tabButtons[item.tab] = self[item.buttonName]
		end)  

		x = 24
		LuaUtils:foreach({"tab1Button", "tab2Button", "tab3Button"}, function(item)
			self[item].button:SetPoint("TOPLEFT", NPCJournalFrame.mainFrame, "TOPLEFT", x, y)
			x = x + w + xGap
		end)  
		
		x = 24
		LuaUtils:foreach({"tab4Button", "tab8Button"}, function(item)
			self[item].button:SetPoint("TOPLEFT", NPCJournalFrame.mainFrame, "TOPLEFT", x, y)
			x = x + w + xGap
		end)   

		x = 24
		LuaUtils:foreach({"tab5Button", "tab6Button", "tab7Button"}, function(item)
			x = x + w + xGap
			self[item].button:SetPoint("TOPLEFT", NPCJournalFrame.mainFrame, "TOPLEFT", x, y)
		end)         
		

		GUIUtils:AddButton(NPCJournalFrame.mainFrame, "", 296, y + 8, 25.0, 25.0, 25, 25, function() NPCJournalFrame.mainFrame:Hide() end
		, [[Interface/Buttons/UI-Panel-Button-Up]]
		, [[Interface/Buttons/UI-Panel-Button-Highlight]]
		, [[Interface/Buttons/UI-Panel-Button-Down]]
		, true

		)
		
		LuaUtils:foreach(self.tabButtons, function(item)
			item.button.selectedGlow:SetVertexColor(1.0, 0.8, 0, 0.5); 
		end)
			
		
		-------------------- Hint frame -------------------------
		local hintFrame = GUIUtils:CreateHintFrame(0, 0, 256, 150)
		hintFrame.frame:SetClampedToScreen(true)
		hintFrame.frame:Hide()   
		
		
		--------------- Strategy tab ------------------------    
		self.strategyTitle = npcModelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")

		self.strategyTitle:SetPoint("LEFT")
		self.strategyTitle:SetText("|cffffffff ".."Strategy".."|r")
		self.strategyTitle:SetFontObject(QuestTitleFontBlackShadow)
		self.strategyTitle:SetJustifyH("LEFT")
		self.strategyTitle:SetWidth(225)
		self.strategyTitle:SetHeight(125)
		self.strategyTitle:SetPoint("TOPLEFT", npcModelContainer, "TOPLEFT", -5, -90)

		self.strategyContent = CreateFrame("SimpleHTML",nil, contents[STRATEGY_TAB], "InteractiveSimpleHTML")

		self.strategyContent:SetFontObject(GameFontHighlight)
		self.strategyContent:SetWidth(282)
		self.strategyContent:SetHeight(510)
		self.strategyContent:SetJustifyH("LEFT")
		self.strategyContent:SetJustifyV("TOP")    
		self.strategyContent:SetPoint("TOPLEFT", npcModelContainer, "TOPLEFT", 0, -170) 
		self.strategyContent:SetSpacing(2)
		 
		--------------- Guide tab ------------------------    
		self.guideTitle = guideModelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")

		self.guideTitle:SetText("|cffffffff ".."Guide".."|r")
		self.guideTitle:SetFontObject(QuestTitleFontBlackShadow)
		self.guideTitle:SetJustifyH("LEFT")
		self.guideTitle:SetWidth(125)
		self.guideTitle:SetHeight(125)
		self.guideTitle:SetPoint("TOPLEFT", guideModelContainer, "TOPLEFT", -5, -90)
		
		self.guideTitleRight = CreateFrame("SimpleHTML",nil, guideModelContainer)

		self.guideTitleRight:SetFontObject(GameFontNormal)
		self.guideTitleRight:SetWidth(282)
		self.guideTitleRight:SetHeight(510)
		self.guideTitleRight:SetPoint("TOPLEFT", guideModelContainer, "TOPLEFT", -5, -140)    
		self.guideTitleRight:SetText('<html><body><p align="right"></p></body></html>')
		
		GUIUtils:SetNextFrameLevel(self.guideTitleRight)
		
		self.guideTitleRight:SetScript("OnHyperlinkEnter", function(self, linkData, link, button)
			local tag = LuaUtils:split(linkData, ':')
			local tagType = tag[1]
			local petType= tag[2]

			local passiveId = PET_BATTLE_PET_TYPE_PASSIVES[tonumber(petType)]
			if PetJournal_ShowAbilityTooltip then
				PetJournal_ShowAbilityTooltip(_, tonumber(passiveId))
				PetJournalPrimaryAbilityTooltip:ClearAllPoints();
				PetJournalPrimaryAbilityTooltip:SetPoint("TOPRIGHT", NPCJournalFrame.mainFrame, "TOPLEFT", 0, -83);
			else
				UIParentLoadAddOn("Blizzard_Collections") 
			end
		end) 
		
		self.guideTitleRight:SetScript("OnHyperlinkLeave", function(self, linkData, link, button)
			PetJournalPrimaryAbilityTooltip:Hide() 
		end) 

		self.guideContent = CreateFrame("SimpleHTML",nil, contents[GUIDE_TAB], "InteractiveSimpleHTML")

		self.guideContent:SetFontObject(GameFontHighlight)
		self.guideContent:SetWidth(282)
		self.guideContent:SetHeight(510)
		self.guideContent:SetJustifyH("LEFT")
		self.guideContent:SetJustifyV("TOP")    
		self.guideContent:SetPoint("TOPLEFT", guideModelContainer, "TOPLEFT", 0, -170) 
		self.guideContent:SetSpacing(2)
		
		--------------- DPS tab ------------------------    
		LuaUtils:foreach({{name = "dPSContent", tab = DPS_TAB},
						 {name = "healContent", tab = HEAL_TAB},
						 {name = "tankContent", tab = TANK_TAB}}, function(item)
			self[item.name] = CreateFrame("SimpleHTML",nil, contents[item.tab], "InteractiveSimpleHTML")
			self[item.name]:SetFontObject(GameFontHighlight)
			self[item.name]:SetWidth(282)
			self[item.name]:SetHeight(510)
			self[item.name]:SetJustifyH("LEFT")
			self[item.name]:SetJustifyV("TOP")    
			self[item.name]:SetPoint("TOPLEFT", contents[item.tab], "TOPLEFT", 7, -40) 
			self[item.name]:SetSpacing(2)  
		end)
		
	 
		-------------- Events -------------------
        function WasWaypointHoveredLastTimeOnTextChange()
            local x, y = GetCursorPosition()
            local a = NPCJournalFrame.lastTextChangeX - x
            local b = NPCJournalFrame.lastTextChangeY - y
            return math.sqrt(a*a + b*b) < 2
        end
        
        
        local function SetTooltipOwner(tooltipFrame, smallFrameAsOwner, stickyFrameAsOwner, dugisMainAsOwner)
        
            if type(smallFrameAsOwner) == "number" then
                smallFrameAsOwner = false
            end            
            
            if type(stickyFrameAsOwner) == "number" then
                stickyFrameAsOwner = false
            end  
            
            if type(dugisMainAsOwner) == "number" then
                dugisMainAsOwner = false
            end
            
        
            if smallFrameAsOwner then
                tooltipFrame:SetOwner(DGV.SmallFrame.Frame, "ANCHOR_LEFT", 0, -100)
                return
            end

            if stickyFrameAsOwner then
                tooltipFrame:ClearAllPoints();
                tooltipFrame:SetOwner(DugisGuideViewer.Modules.StickyFrame.Frame, "ANCHOR_LEFT", 0, -100)
                return
            end

            if dugisMainAsOwner then
                tooltipFrame:SetOwner(DugisMain, "ANCHOR_BOTTOMRIGHT", 10, 380)
                return
            end

            tooltipFrame:SetOwner(NPCJournalFrame.mainFrame, "ANCHOR_LEFT", 0, -200)
        end
        
        function NPCJournalFrame:UpdateWaypointHighlights()
            LuaUtils:foreach({
              NPCJournalFrame.strategyContent
            , NPCJournalFrame.guideContent
            , NPCJournalFrame.dPSContent
            , NPCJournalFrame.healContent
            , NPCJournalFrame.tankContent}, function(item)
                if item:IsVisible() then
                    item:HighlightElement(NPCJournalFrame.currentHoveredWaypointButtonId, true)
                end
            end)  
        end
        
		NPCJournalFrame.OnHyperlinkEnter = function(self, linkData, link, button, smallFrameAsOwner, stickyFrameAsOwner, dugisMainAsOwner)
			local tag = LuaUtils:split(linkData, ':')
			local tagType = tag[1]
            
            if WasWaypointHoveredLastTimeOnTextChange() and tagType ~= "waypoint" then
                return
            end
            
            if type(smallFrameAsOwner) == "number" then
                smallFrameAsOwner = false
            end            
            
            if type(stickyFrameAsOwner) == "number" then
                stickyFrameAsOwner = false
            end  
            
            if type(dugisMainAsOwner) == "number" then
                dugisMainAsOwner = false
            end            

			hintFrame:SetMode(GUIUtils.HINT_WINDOW_TEXT_WITH_ICON_MODE)
			
			if tagType == "spell" then
            
                SetTooltipOwner(DugisGuideTooltip, smallFrameAsOwner, stickyFrameAsOwner, dugisMainAsOwner)
				DugisGuideTooltip:SetSpellByID(tag[2])
			end
			
			if tagType == "garrfollowerability" then
            
                GarrisonFollowerAbilityTooltip:ClearAllPoints()
            
				if smallFrameAsOwner then
					GarrisonFollowerAbilityTooltip:SetPoint("TOPRIGHT", DGV.SmallFrame.Frame, "TOPLEFT", 0, 0)
				else
                    if not stickyFrameAsOwner then
                        if dugisMainAsOwner then
                            GarrisonFollowerAbilityTooltip:SetPoint("TOPLEFT", DugisMain, "TOPRIGHT", 10, -20)
                        else                        
                            GarrisonFollowerAbilityTooltip:SetPoint("TOPRIGHT", NPCJournalFrame.mainFrame, "TOPLEFT", 0, -100)
                        end
                    else
                        GarrisonFollowerAbilityTooltip:SetPoint("TOPRIGHT", DugisGuideViewer.Modules.StickyFrame.Frame, "TOPLEFT", 0, 0)
                    end                    
				end  
				GarrisonFollowerAbilityTooltip_Show(GarrisonFollowerAbilityTooltip, tonumber(tag[2]))
			end
			
			if tagType == "garrmission" then
				if smallFrameAsOwner then
					FloatingGarrisonMissionTooltip:ClearAllPoints()
					FloatingGarrisonMissionTooltip:SetPoint("TOPRIGHT", DGV.SmallFrame.Frame, "TOPLEFT", 0, 0)
				else
					FloatingGarrisonMissionTooltip:ClearAllPoints()
                    if not stickyFrameAsOwner then
                        if dugisMainAsOwner then
                            FloatingGarrisonMissionTooltip:SetPoint("TOPLEFT", DugisMain, "TOPRIGHT", 10, -20)
                        else
                            FloatingGarrisonMissionTooltip:SetPoint("TOPRIGHT", NPCJournalFrame.mainFrame, "TOPLEFT", 0, -100)
                        end
                    else
                        FloatingGarrisonMissionTooltip:SetPoint("TOPRIGHT", DugisGuideViewer.Modules.StickyFrame.Frame, "TOPLEFT", 0, 0)
                    end  
				end  
				FloatingGarrisonMission_Show(tonumber(tag[2]))
			end				
			
			if tagType == "item" then
                SetTooltipOwner(DugisGuideTooltip, smallFrameAsOwner, stickyFrameAsOwner, dugisMainAsOwner)
				DugisGuideTooltip:SetItemByID(tag[2])
			end
			
			if tagType == "waypoint" then
				NPCJournalFrame.currentHoveredWaypointButtonId = tonumber(tag[7]) 
                NPCJournalFrame:UpdateWaypointHighlights()
			end
			
			if tagType == "npc" then
				NPCJournalFrame.hintFrameModelAngle = 0
				hintFrame:SetMode(GUIUtils.HINT_WINDOW_NPC_MODE)
				local content = "|cffffd200"..DugisGuideViewer:GetLocalizedNPC(tag[2]).."|r"
				local displayId = DugisGuideViewer.Modules.ModelViewer.npcDB[tag[2]]
				hintFrame:SetText("")
				hintFrame:SetTitle(content)
				
                hintFrame.frame:ClearAllPoints()
				if smallFrameAsOwner then
					hintFrame.frame:SetPoint("TOPRIGHT", DGV.SmallFrame.Frame, "TOPLEFT", 3, 12)
				else
                    if not stickyFrameAsOwner then
                        if dugisMainAsOwner then
                            hintFrame.frame:SetPoint("TOPLEFT", DugisMain, "TOPRIGHT", 10, -20)
                        else                    
                            hintFrame.frame:SetPoint("TOPRIGHT", NPCJournalFrame.mainFrame, "TOPLEFT", 0, -83)
                        end
                    else
                        hintFrame.frame:SetPoint("TOPRIGHT", DugisGuideViewer.Modules.StickyFrame.Frame, "TOPLEFT", 0, 27)
                    end                 
				end
				hintFrame.frame:SetWidth(179)
				hintFrame.frame:SetHeight(184)
				
				
				hintFrame:SetModel(displayId, content, tag[2])
                
                if DugisGuideViewer:IsModuleLoaded("ModelViewer") and DugisGuideViewer.Modules.ModelViewer.Frame:IsShown() then
                    hintFrame:Show(true, true, {0,0,0.4, 1}) 
                else
                    hintFrame:Show(true, true, {0,0,0.4, 0.6}) 
                end

			end
			
			if tagType == "achievement" then
                SetTooltipOwner(DugisGuideTooltip, smallFrameAsOwner, stickyFrameAsOwner, dugisMainAsOwner)
				DugisGuideTooltip:SetAchievementByID(tag[2]) 
			end
			
			if tagType == "quest" then
                SetTooltipOwner(DugisGuideTooltip, smallFrameAsOwner, stickyFrameAsOwner, dugisMainAsOwner)
				DugisGuideTooltip:SetHyperlink(("quest:%s"):format(tostring(tag[2])))
			end
			
			if tagType == "guide" then
            
                SetTooltipOwner(DugisGuideTooltip, smallFrameAsOwner, stickyFrameAsOwner, dugisMainAsOwner)
                
				local guideTitle = tag[2]
				local uniqueGuideLinkID = tag[3]
				guideTitle = DGV:GetFormattedTitle(guideTitle)

                NPCJournalFrame.hoveredGuideLinkId = uniqueGuideLinkID
 
				local DGV_SmallFrameFontSize = DGV:GetDB(DGV_SMALLFRAMEFONTSIZE)
				local filename, _, _ = GameTooltipTextLeft1:GetFont()	
				--Please uncomment those lines if you want to the tooltip to be sticked to cursor
				--GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
				--GameTooltip:SetAnchorType("ANCHOR_CURSOR")
				DugisGuideTooltip:ClearLines()
				DugisGuideTooltip:AddLine("Click here to load the guide\n|cff44ff44"..guideTitle.."|r", 1, 1, 1)
				DugisGuideTooltipTextLeft1:SetFont(filename, DGV_SmallFrameFontSize)
				DugisGuideTooltip:Show()
			end	

			if tagType == "faction" then
				--hintFrame:SetMode(GUIUtils.HINT_WINDOW_TEXT_WITH_NO_ICON_MODE)
				local name, description, standingID  = GetFactionInfoByID(tag[2])
				DugisGuideTooltip:ClearAllPoints() 
                
                SetTooltipOwner(DugisGuideTooltip, smallFrameAsOwner, stickyFrameAsOwner, dugisMainAsOwner)
                
				--hintFrame:SetTitle("|cffffd200"..name.."|r")
				
				local text = ""
				
				if standingID then 
					standingID = getglobal("FACTION_STANDING_LABEL"..standingID)
					local standing = getglobal("STANDING")
					text = text.."\n|cffffffff"..standing..":|r |cff66bbff"..standingID.."|r"
				end
				
				if not LuaUtils:IsNilOrEmpty(description) then
					text = text.."\n\n|cffffffff"..description.."|r"
				end

				local DGV_SmallFrameFontSize = DGV:GetDB(DGV_SMALLFRAMEFONTSIZE)
				local filename, _, _ = DugisGuideTooltipTextLeft1:GetFont()				
				
				DugisGuideTooltip:ClearLines()
				DugisGuideTooltip:AddLine("|cffffd200"..name.."|r"..text, 1, 1, 1, true)
				DugisGuideTooltipTextLeft1:SetFont(filename, DGV_SmallFrameFontSize)
				DugisGuideTooltip:Show()				
				DugisGuideTooltip:SetWidth(250)
				
				--[[
				hintFrame:SetText(text)
				  
                hintFrame.frame:ClearAllPoints()
				if smallFrameAsOwner then
					hintFrame.frame:SetPoint("TOPRIGHT", DGV.SmallFrame.Frame, "TOPLEFT", 0, -33) 
				else
					hintFrame.frame:SetPoint("TOPRIGHT", NPCJournalFrame.mainFrame, "TOPLEFT", 0, -83) 
				end  
				
				hintFrame:Show(true)]]
			end

			if tagType == "currency" then
                SetTooltipOwner(DugisGuideTooltip, smallFrameAsOwner, stickyFrameAsOwner, dugisMainAsOwner)
				DugisGuideTooltip:SetCurrencyByID(tag[2])
			end			
						
		end
		
		NPCJournalFrame.OnHyperlinkLeave = function(self, linkData, link, button)
            linkData = linkData or ""
            local tag = LuaUtils:split(linkData, ':')
			local tagType = tag[1]
            
            NPCJournalFrame.hoveredGuideLinkId = nil
            
            if WasWaypointHoveredLastTimeOnTextChange() and tagType ~= "waypoint" then
                return
            end

            hintFrame.frame:Hide()
            DugisGuideTooltip:Hide()
			GarrisonFollowerAbilityTooltip:Hide()
			FloatingGarrisonMissionTooltip:Hide()
            hintFrame:SetMode(GUIUtils.HINT_WINDOW_TEXT_WITH_ICON_MODE)
            NPCJournalFrame.currentHoveredWaypointButtonId = nil
            NPCJournalFrame:UpdateWaypointHighlights()        
		end
		
		NPCJournalFrame.OnHyperlinkClick = function(self, linkData, link, button)
			local tag = LuaUtils:split(linkData, ':')
			local tagType = tag[1]
			local x = tag[2]
			local y = tag[3]
			local mapId = tag[4]
			local description = tag[5]
			local floorId = tag[6]

			if tagType == "waypoint" and DugisGuideUser.PetBattleOn == false then
				if not IsShiftKeyDown() then DugisGuideViewer:RemoveAllWaypoints() end
				DugisGuideViewer:AddCustomWaypoint(x/100, y/100, description, tonumber(mapId), tonumber(floorId))
				DugisGuideViewer.MapPreview:FadeInMap()
			elseif DugisGuideUser.PetBattleOn == true then
				print("|cff11ff11Dugi Guides: |rUnable to place waypoint during pet battle.")
			end
			
			if IsShiftKeyDown() then
				if tagType ~= "waypoint" and tagType ~= "npc" then
					ChatEdit_InsertLink(link)
				elseif tagType == "npc" then 
					 local content = DugisGuideViewer:GetLocalizedNPC(tag[2])
					 ChatEdit_InsertLink(content)
				end
				return;
			end			

			if tagType == "achievement" then
				local id = tonumber(tag[2])
				if ( not AchievementFrame ) then
					AchievementFrame_LoadUI();
				end
				if ( not AchievementFrame:IsShown() ) then
					AchievementFrame_ToggleAchievementFrame();
					AchievementFrame_SelectAchievement(id);
				else
					if ( AchievementFrameAchievements.selection ~= id ) then
						AchievementFrame_SelectAchievement(id);
					else
						AchievementFrame_ToggleAchievementFrame();
					end
				end    
				return;
			end
            
			if tagType == "guide" then
				local guideTitle = tag[2]
                local forWhatsNew = tag[3]
                
                if forWhatsNew == "whatsnew" then
                    DugisGuideViewer:DisplayViewTab(guideTitle, true)
                    if CurrentTitle == guideTitle then
                        DugisMainCurrentGuideTab:Click()
                    end
                else
                    DugisGuideViewer:DisplayViewTab(guideTitle, true)
                end
                
                if DugisGuideTooltip then
                    DugisGuideTooltip:Hide()
                end

				print("|cff11ff11Dugi Guides: |r"..DGV:GetFormattedTitle(guideTitle).."|cff11ff11 selected.|r")
				
				DugisGuideViewer:SetPercentComplete()
				
				return;
			end        
            
			if tagType == "choice" then
				local choiceId = tag[2]
                
                local allChoices = {select(3, unpack(tag))}
                
                LuaUtils:foreach(allChoices, function(choiceId_)
                    if choiceId_ ~= choiceId then
                        DGV:MarkStepsByChoiceId(choiceId_, true)
                    end
                end)
                
                DGV:GoToChoice(choiceId)
				return
			end            
		end
		
		LuaUtils:foreach({self.strategyContent, self.guideContent, self.dPSContent, self.healContent, self.tankContent}, function(item)
			item:SetScript("OnHyperlinkClick", NPCJournalFrame.OnHyperlinkClick)    
			item:SetScript("OnHyperlinkEnter", NPCJournalFrame.OnHyperlinkEnter)
			item:SetScript("OnHyperlinkLeave", NPCJournalFrame.OnHyperlinkLeave)    

		end)    
		--------------- Titles ------------------------
		local titles =
			LuaUtils:foreach({ABILITIES_TAB, LOOT_TAB, DPS_TAB, HEAL_TAB, TANK_TAB, PET_ABILITIES_TAB}, function(tab) 
					contents[tab].title = contents[tab]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				end)    

		
		LuaUtils:foreach({{text = "Abilities", tab = ABILITIES_TAB},
						  {text = "Abilities", tab = PET_ABILITIES_TAB},
						  {text = "Loot", tab = LOOT_TAB},
						  {text = "|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\dps:22:22:-6:6|tDamage Dealer", tab = DPS_TAB},
						  {text = "|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\heal:22:22:-6:6|tHealer", tab = HEAL_TAB},
						  {text = "|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\tank:22:22:-6:6|tTank", tab = TANK_TAB}}, function(item)
				local content = contents[item.tab]
				content.title:SetPoint("LEFT")
				content.title:SetWidth(282)
				content.title:SetHeight(55)
				content.title:SetFontObject(QuestTitleFontBlackShadow)
				content.title:SetText("|cffffffff "..item.text.."|r")
				content.title:SetJustifyH("LEFT")
				content.title:SetJustifyV("TOP")
				content.title:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -10)
			end)      
		
		
		--------------------------- NPC Model frame -------------------------------------  
		local modelFrame = GUIUtils:CreateModelFrame(npcModelContainer)
		
		--------------------------- Guide Model frame -------------------------------------  
		local guideFrame = GUIUtils:CreateModelFrame(guideModelContainer)    
		
		
		-------------------- Sidebar icon -------------------------
		local sidebarButtonFrame = GUIUtils:CreateSidebarIcon(function()
			NPCJournalFrame.guideTargetMode = TARGET_MODE
			self.mainFrame:Show() 
			self:UpdateBorders()
			self:SetTab(self.currentTab)
			self:UpdateTarget(true, true)
		end)


		-------------------- Borders -------------------------
		self.UpdateBorders = function(self) 
			self.mainFrame:SetBackdrop({bgFile = [[Interface\AddOns\DugisGuideViewerZ\Artwork\NPCViewer\npc_journal_background.tga]]
			, edgeFile = DugisGuideViewer:GetBorderPath(), 
			tile = false, tileSize = 32, edgeSize = 32, 
			insets = { left = 10, right = -207, top = 11, bottom = -131 }});
			
			DugisGuideViewer.ApplyElvUIColor(self.mainFrame)		
			
			local border = DugisGuideViewer:UserSetting(DGV_LARGEFRAMEBORDER)
			
			local shiftX = 
			{
				 Default         = 0  
				,BlackGold       = 2
				,Bronze          = 0
				,DarkWood        = 0
				,ElvUI           = 3
				,Eternium        = 0
				,Gold            = 0
				,Metal           = 0
				,MetalRust       = 0
				,OnePixel        = 2
				,Stone           = 0
				,StonePattern    = 0
				,Thin            = 2
				,Wood            = 0 
			}
			
			self.scrollframe.scrollBar:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 300 + shiftX[border], -61)
		end
			   
		
		--------------- ON UPDATE -----------------
		self.modelAngle = 0.0
		self.hintFrameModelAngle = 0.0

		function Frame_OnUpdate(frame, elapsed)
			modelFrame:SetFacing(self.modelAngle)
			guideFrame:SetFacing(self.modelAngle)
			hintFrame.modelFrame:SetFacing(self.hintFrameModelAngle)
			self.modelAngle = self.modelAngle + 0.004  
			self.hintFrameModelAngle = self.hintFrameModelAngle + 0.004 
			
			if NPCJournalFrame.needToUpdateTexts then
				NPCJournalFrame.needToUpdateTexts = false
				NPCJournalFrame:ReplaceQuestTagsInTexts()
			end
			
			if NPCJournalFrame.needToUpdateGuide  then
			   NPCJournalFrame.needToUpdateGuide = false
			   NPCJournalFrame.guideTitleRight:SetText(NPCJournalFrame.guideTitleRight.text)
			end
		end

		mainFrame:SetScript("OnUpdate", Frame_OnUpdate)  
		
		self.mainFrame = mainFrame
		self.scrollframe = scrollframe
		self.titles = titles
		self.contents = contents
		self.sidebarButtonFrame = sidebarButtonFrame
		self.modelFrame = modelFrame
		self.guideFrame = guideFrame
		self.hintFrame = hintFrame
		self.roleTexture = roleTexture
		self.roleCoords = roleCoords
		
		self:SetTab(STRATEGY_TAB) 
		self:SetMode(NPC_JOURNAL_MODE)
	end


	-------------------------- GUI - OPERATIONS --------------------------- 

	function NPCJournalFrame:UpdateScrollRange(content)
		local maxY  = 700
		
		if content:GetRegions() then
			maxY = content:GetRegions():GetHeight()
		end

		self.scrollframe.scrollBar:SetMinMaxValues(1, maxY)
	end

	function NPCJournalFrame:UpdateStrategyScroll()
		self:UpdateScrollRange(self.strategyContent)
	end

	function NPCJournalFrame:SetTab(tabIndex)
		self.currentTab = tabIndex
		self.scrollframe.scrollBar:SetValue(0)
		
		LuaUtils:foreach(self.tabButtons, function(item)
			item.button:UnlockHighlight()
			item.button:Enable()
			item.button.selectedGlow:Hide()
			item.button:SetText("|cffffffff "..item.text.."|r", 1, 1, 1,  1, 0.5)
			item.button:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT",  select(4, item.button:GetPoint(1)) , -17)
			item.button:SetHeight(24)  
		end)   

		LuaUtils:foreach(self.contents, function(item)
			item:Hide()
		end)     

		local currentButton = self.tabButtons[tabIndex]
		local currentContent = self.contents[tabIndex]

		if tabIndex == STRATEGY_TAB then
			self:UpdateStrategyScroll()
		end
		
		if tabIndex == DPS_TAB then
			self:UpdateScrollRange(self.dPSContent)
		end
		
		if tabIndex == HEAL_TAB then
			self:UpdateScrollRange(self.healContent)
		end
		
		if tabIndex == TANK_TAB then
			self:UpdateScrollRange(self.tankContent)
		end
		
		if tabIndex == GUIDE_TAB then
			self:UpdateScrollRange(self.guideContent)
		end
		
		if tabIndex == ABILITIES_TAB then
			if (currentContent.maxY ~= nil and currentContent.maxY ~= 0) then
				self.scrollframe.scrollBar:SetMinMaxValues(1, currentContent.maxY)
			end       
		end
		
		if tabIndex == PET_ABILITIES_TAB then
			if (currentContent.maxY ~= nil and currentContent.maxY ~= 0) then
				self.scrollframe.scrollBar:SetMinMaxValues(1, currentContent.maxY)
			end       
		end

		if tabIndex == LOOT_TAB then    
			if (currentContent.maxY ~= nil and currentContent.maxY ~= 0) then
				self.scrollframe.scrollBar:SetMinMaxValues(1, currentContent.maxY)
			end
		end
		
		currentContent:Show() 
		self.scrollframe.frame.content = currentContent
		self.scrollframe.frame:SetScrollChild(currentContent) 

		currentButton.button:Disable()    
		currentButton.button.selectedGlow:Show()
		currentButton.button:SetText("|cffffd200 "..currentButton.text.."|r", 1, 1, 1,  1, 0.5)  
		currentButton.button:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT",  select(4, currentButton.button:GetPoint(1)) , -14)
		currentButton.button:SetHeight(27)
		LuaUtils:PlaySound("igCharacterInfoTab");
	end


	function NPCJournalFrame:SetMode(frame)
		LuaUtils:foreach(self.tabButtons, function(item)
			item.button:Hide() 
		end) 
		
		local visibleTabButtons = { [NPC_JOURNAL_MODE] = {STRATEGY_TAB, ABILITIES_TAB, LOOT_TAB},
									[MOUNT_MODE] = {GUIDE_TAB},
									[PET_MODE] = {GUIDE_TAB, PET_ABILITIES_TAB},
                                    [FOLLOWER_MODE] = {GUIDE_TAB},
									[RAID_BOSS_MODE] = {STRATEGY_TAB, DPS_TAB, HEAL_TAB, TANK_TAB}}

		LuaUtils:foreach(visibleTabButtons[frame], function(item)
			self.tabButtons[item].button:Show() 
		end) 
	end


	NPCJournalFrame.abilities = {}  
	function NPCJournalFrame:UpdateAbilitiesList(abilitiesData)
		GUIUtils:UpdateOrCreateList(
			  self.contents[ABILITIES_TAB]
			, self.abilities
			, abilitiesData --{33860, 11831}
			, function (id)  
				return select(3, GetSpellInfo(id))
			  end
			, function (id) 
				local name = GetSpellInfo(id)
				if not name then
					return nil
				end
				return '|cffffffff'..name..'|r'
			  end
			, nil
			, self.hintFrame
			, function (id)
				GameTooltip:SetOwner(NPCJournalFrame.mainFrame, "ANCHOR_LEFT", 0, -200)
				GameTooltip:SetSpellByID(id)
			  end
			, function (id)
				GameTooltip:Hide()
			end
			
		)
	end

	local PET_INFO = {}

	LuaUtils:foreach({"GetCooldown", "GetRemainingDuration", "GetHealth", "GetMaxHealth"
		, "GetAttackStat", "GetSpeedStat", "GetState", "GetWeatherState", "GetPadState", "GetPetOwner", "HasAura", "GetPetType"  }, function(item)
		PET_INFO[item] = DEFAULT_PET_BATTLE_ABILITY_INFO[item]
	end)

	function PET_INFO:GetAbilityID() return NPCJournalFrame.currentPetAbilityIdForHintWindow end
	function PET_INFO:IsInBattle() return false; end

	NPCJournalFrame.petAbilities = {}  
	function NPCJournalFrame:UpdatePetAbilitiesList(petData)
        if petData == nil or petData.abilities == nil then
            return
        end
		GUIUtils:UpdateOrCreateList(
			  self.contents[PET_ABILITIES_TAB]
			, self.petAbilities
			, petData.abilities --{33860, 11831}
			, function (id)  
				return select(2, C_PetJournal.GetPetAbilityInfo(id))
			  end
			, function (id) 
				local name = C_PetJournal.GetPetAbilityInfo(id)
				if not name then
					return nil
				end
				return '|cffffffff'..name..'|r'
			  end
			, nil
			, self.hintFrame
			, function(id)
				if PetJournal_ShowAbilityTooltip then
					PetJournal_ShowAbilityTooltip(_, id)
					PetJournalPrimaryAbilityTooltip:ClearAllPoints();
					PetJournalPrimaryAbilityTooltip:SetPoint("TOPRIGHT", NPCJournalFrame.mainFrame, "TOPLEFT", 0, -83);
				else
					UIParentLoadAddOn("Blizzard_Collections") 
				end
			end
			, function()
				PetJournalPrimaryAbilityTooltip:Hide()
			end
			
			
		)
	end

	NPCJournalFrame.loots = {}
	function NPCJournalFrame:UpdateLootsList(lootsData)
		GUIUtils:UpdateOrCreateList(
			  self.contents[LOOT_TAB]
			, self.loots
			, lootsData --{31243, 31244, 31242, 31246,31243, 31244, 31242, 31246, 31243, 31244, 31242, 31246,31243, 31244, 31242, 31246}
			, function (id) 
				return select(10, GetItemInfo(id))
			  end
			, function (id) 
				return self:GetItemColoredName(id)
			  end
			, nil
			, self.hintFrame
			, function (id)
				GameTooltip:SetOwner(NPCJournalFrame.mainFrame, "ANCHOR_LEFT", 0, -200)
                if id ~= nil and id ~= "" and id ~= " " then
                    GameTooltip:SetItemByID(id)
                end
			  end
			, function (id)
				GameTooltip:Hide()
			  end
		)
	end

    NPCJournalFrame.lastTextChangeX, NPCJournalFrame.lastTextChangeY = GetCursorPosition()
    function UpdateLastTextChangePosition()
        NPCJournalFrame.lastTextChangeX, NPCJournalFrame.lastTextChangeY = GetCursorPosition()
    end
		
	function NPCJournalFrame:UpdateGuideTab(data, isMount, npcData, updateModel, isFollower, followerId)
        if data == nil then
            return
        end
		self.modelFrame:Show()
		self.modelFrame:ClearModel() 
			
		if isMount then
			local spellName = GetSpellInfo(data.spellId)
			self.guideFrame.title:SetText(spellName)
			if updateModel then
				self.guideFrame:SetDisplayInfo(data.modelId)
			end
			self.guideTitle:SetText("|cffffffff ".."Mount - Guide".."|r")
			self.guideTitle:SetWidth(340)
			self.guideTitleRight:Hide()
		else
            if isFollower then
                local followerData = self:GetFollowerDataById(followerId)
                
                self.guideFrame:SetModelOrNothing(nil, followerData.displayID)
                self.guideTitle:SetText("|cffffffff Follower|r")
                self.guideTitle:SetWidth(340)
                
                self.guideFrame.title:SetText(followerData.formattedName) 
                
                local content = followerData.className.." |T".."Interface/Glues/CharacterCreate/UI-CharacterCreate-Classes:25:25:2:0:256:256:"
                ..(CLASS_ICON_TCOORDS[followerData.class][1]*256)..":"..(CLASS_ICON_TCOORDS[followerData.class][2]*256)..":"..(CLASS_ICON_TCOORDS[followerData.class][3]*256)..":"..(CLASS_ICON_TCOORDS[followerData.class][4]*256).."|t|h "
                
                local text = '<html><body><p align="right">'..content..'</p></body></html>'
                self.guideTitleRight:SetText(text)
                self.guideTitleRight.text = text
                self.needToUpdateGuide = true
                self.guideTitleRight:Show()
            else
                self.guideFrame.title:SetText(data.name)
                if updateModel then
                    self.guideFrame:SetModelOrNothing(npcData.unitName, npcData.modelId)
                end
                
                self.guideTitle:SetText("|cffffffff ".."Pet - Guide".."|r")

                local content = "|Hpettype:"..data.petType.."|h"..PET_TYPE_SUFFIX[data.petType].."|T".."Interface/PetBattles/PetIcon-"..PET_TYPE_SUFFIX[data.petType]..".png:25:25:2:0:128:256:60:100:130:170:255:255:255|t|h "
                local text = '<html><body><p align="right">'..content..'</p></body></html>'
                self.guideTitleRight:SetText(text)
                self.guideTitleRight.text = text
                self.needToUpdateGuide = true
                self.guideTitleRight:Show()
            end
		end
		
        --guide
		local guideText = self:ReplaceSpecialTags(data.guide)
		if isMount then
			local newText
			if data.description ~= "" then 
				newText = data.description.."\n\n"..guideText
			else
				newText = guideText
			end 
            if self.guideContent.text ~= newText then
				self.guideContent.text = newText
				self.guideContent:SetNewText(self.guideContent.text)   
				UpdateLastTextChangePosition()
            end
		else
            if isFollower then
                local newText = self:ReplaceSpecialTags(FollowerObjects[followerId].guide)   
                if self.guideContent.text ~= newText then
                    self.guideContent.text = newText
                    self.guideContent:SetNewText(newText) 
                    UpdateLastTextChangePosition()
                end
            else
                local newText
				if data.description ~= "" then 
					newText = data.description.."\n\n"..guideText
				else
					newText = guideText
				end
                if self.guideContent.text ~= newText then
                    self.guideContent.text = newText
                    self.guideContent:SetNewText(newText) 
                    UpdateLastTextChangePosition()
                end
            end
		end
		local filename, _, _ = self.guideContent:GetFont()
		self.guideContent:SetFont(filename, DGV:UserSetting(DGV_SMALLFRAMEFONTSIZE)) 
	end

	function NPCJournalFrame:UpdateRaidTab(data, npcName, updateModel)
		if updateModel then
			self.modelFrame:SetModelOrNothing(data.unitName, data.modelId)
		end
		self.modelFrame.title:SetText(npcName)
		self.strategyTitle:SetText("|cffffffff ".."Overview".."|r")

		local strategy = "|cffffffff"..data.Strategy.."|r"

		strategy = self:ReplaceSpecialTags(strategy)

		self.strategyContent:SetNewText(strategy)
		self.strategyContent.text = strategy

		self.dPSContent.text = self:ReplaceSpecialTags(data.DPSText)
		self.dPSContent:SetNewText(self.dPSContent.text)
		self.healContent.text = self:ReplaceSpecialTags(data.HEALText)
		self.healContent:SetNewText(self.healContent.text)
		self.tankContent.text = self:ReplaceSpecialTags(data.TANKText)
		self.tankContent:SetNewText(self.tankContent.text)
		
		local filename, _, _ = self.strategyContent:GetFont()
		self.strategyContent:SetFont(filename, DGV:UserSetting(DGV_SMALLFRAMEFONTSIZE)) 
		self.dPSContent:SetFont(filename, DGV:UserSetting(DGV_SMALLFRAMEFONTSIZE)) 
		self.healContent:SetFont(filename, DGV:UserSetting(DGV_SMALLFRAMEFONTSIZE)) 
		self.tankContent:SetFont(filename, DGV:UserSetting(DGV_SMALLFRAMEFONTSIZE)) 
	end

	function NPCJournalFrame:UpdateStrategyTab(npcData, updateModel)
		self.modelFrame:SetModelOrNothing(npcData.unitName, npcData.modelId)

		self.modelFrame.title:SetText(npcData.name)
		self.strategyTitle:SetText("|cffffffff ".."Overview".."|r")

		local content = npcData.ST
		
		if npcData.CSST ~= "" then
			content = content..'\n\n'..npcData.CSST
		end

		local strategy = "|cffffffff"..content.."|r"

		strategy = self:ReplaceSpecialTags(strategy)

        local newText = strategy
        if self.strategyContent.text ~= newText then
            self.strategyContent.text = newText
            self.strategyContent:SetNewText(newText) 
            UpdateLastTextChangePosition()
        end        
        
		local filename, _, _ = self.strategyContent:GetFont()
		self.strategyContent:SetFont(filename, DGV:UserSetting(DGV_SMALLFRAMEFONTSIZE))

	end
		
	function NPCJournalFrame:UpdateAbilitiesTab(npcData)
		self.contents[ABILITIES_TAB].title:SetText("|cffffffff|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\abilities:24:24:0:8|t Abilities|r")
		self:UpdateAbilitiesList(npcData.ABIL)
	end

	function NPCJournalFrame:UpdatePetAbilitiesTab(petData)
		self.contents[PET_ABILITIES_TAB].title:SetText("|cffffffff|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\abilities:24:24:0:8|t Abilities|r")
		self:UpdatePetAbilitiesList(petData)
	end

	function NPCJournalFrame:UpdateLootTab(npcData)
		self.contents[LOOT_TAB].title:SetText("|cffffffff|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\loot:24:24:0:8|t Notable Loot|r")
		self:UpdateLootsList(npcData.NDIS)
	end

	function NPCJournalFrame:ShowMainFrame()
		self.mainFrame:Show() 
		self:UpdateBorders()    
	end

	function NPCJournalFrame:ReplaceQuestTagsInTexts()
		LuaUtils:foreach({self.strategyContent, self.dPSContent, self.healContent, self.tankContent, self.guideContent}, function(item)
			item:SetNewText(NPCJournalFrame:ReplaceSpecialTags(item.text))
		end)
	end
    
    local function OnTargetChanged(npcData, mountData, petData, bossData)
        if (not DugisGuideViewer:UserSetting(DGV_ENABLED_JOURNAL_NOTIFICATIONS)) or (not DugisGuideViewer:NotificationsEnabled()) then
            return
        end
    
        local title
        local guideType
        local guideObjectId
        
        if petData and npcData then
            title = petData.name
            guideObjectId = npcData.id
            guideType = "Pets"
        end
        
        if mountData and npcData then
            title = mountData.name
            guideObjectId = mountData.spellId
            guideType = "Mounts"
        end
    
        if bossData and npcData then
            title = bossData.name
            guideObjectId = npcData.id
            guideType = "Bosses"
        end
    
        if title and guideType and guideObjectId then
            local icons = { 
                Pets = "|TInterface\\Icons\\Ability_racial_bearform:18:18:-1:0|t ",
                Mounts = "|TInterface\\Icons\\Ability_mount_ridingelekk:18:18:-1:0|t ",
                Bosses = "|TInterface\\Icons\\Achievement_Dungeon_ClassicDungeonMaster:18:18:-1:0|t "
            }
        
            local notification = DugisGuideViewer:AddNotification({
              title = (icons[guideType] or "") .. title
            , notificationType = "journal-frame-notification"
            , guideType = guideType
            , guideObjectId = guideObjectId
            }, 5)
        
            DugisGuideViewer:ShowNotifications()   
            DugisGuideViewer.RefreshMainMenu()
        end
    end

	function NPCJournalFrame:UpdateTarget(setTab, onClick, updateItems, updateWaypoints)
	
		--Waiting for data initialization
		LuaUtils:invokeWhen(function()
			return NPCObjects ~= nil
		end, function()
		
	
		local npcData = self:GetNPCData()
		local mountData = self:GetMountData()
		local petData = self:GetPetData()
		local bossData = self:GetBossData()
		
		if (npcData and npcData.hasData) or mountData or petData or bossData then
			if self.sidebarButtonFrame then
				self.sidebarButtonFrame:Show()
                OnTargetChanged(npcData, mountData, petData, bossData)
			end    
		else
			if self.sidebarButtonFrame then
				self.sidebarButtonFrame:Hide()
			end
			--self.mainFrame:Hide()    
		end
		
		if onClick == true or updateItems or updateWaypoints then 
			if mountData then
				self:UpdateGuideTab(mountData, true, npcData, setTab)
				if setTab then
					self:SetTab(GUIDE_TAB)
					self:SetMode(MOUNT_MODE)
				end
				return 
			end
			
			if petData then
				self:UpdateGuideTab(petData, false, petData, setTab)
				self:UpdatePetAbilitiesTab(petData)
				if setTab then
					self:SetTab(GUIDE_TAB)
					self:SetMode(PET_MODE)
				end
				return 
			end
			
			if bossData then
				self:UpdateRaidTab(bossData, npcData.name, setTab)
				if setTab then
					self:SetTab(STRATEGY_TAB)
					self:SetMode(RAID_BOSS_MODE)
				end
				return 
			end
		
			if npcData and npcData.hasData then
				self:UpdateStrategyTab(npcData, setTab)
				self:UpdateAbilitiesTab(npcData)
				self:UpdateLootTab(npcData)
				if setTab then
					self:SetTab(STRATEGY_TAB)
					self:SetMode(NPC_JOURNAL_MODE)
				end
				return 
			end 
		end
		
		end)
	end

	function NPCJournalFrame:Update()
		if DGV:UserSetting(DGV_JOURNALFRAME) ~= true then
			self.sidebarButtonFrame:Hide()
			self.mainFrame:Hide()
			return
		end
		self:UpdateTarget(true, false)
	end

	------------------------------ EVENTS -------------------------------
    
    local queuedItems = 0
    
	function EventHandler(self, event, ...)
		if event == "GET_ITEM_INFO_RECEIVED" then
			local npcData = NPCJournalFrame:GetNPCData()
			if NPCJournalFrame.guideTargetMode == TARGET_MODE then
				NPCJournalFrame:UpdateTarget(false, nil, true) 
			else
				NPCJournalFrame:RefreshGuideData(true) 
			end
            
            --Refreshing tooltip
            if DugisWaypointTooltip:IsShown() then
                DugisWaypointTooltip:updateDugisWaypointTooltipLines()
                DugisWaypointTooltip:updateModel()
            end
            
            queuedItems = queuedItems + 1
            
            LuaUtils:Delay(2, function()
                queuedItems = queuedItems - 1
                if queuedItems == 0 then
                    DugisGuideViewer:RefreshReplacedTags()
                end
            end)
		end
		
		if event == 'PLAYER_TARGET_CHANGED' then
			NPCJournalFrame.guideTargetMode = TARGET_MODE    
			NPCJournalFrame:Update()
		end 
	end

	function NPCJournalFrame.RegisterEvents(self)
		self.mainFrame:SetScript("OnEvent", EventHandler)
		LuaUtils:foreach({"PLAYER_TARGET_CHANGED", "GET_ITEM_INFO_RECEIVED"}, function(item)
			self.mainFrame:RegisterEvent(item)
		end)  
	end

	NPCJournalFrame:RegisterEvents()


	----------------- SETTINGS ---------------------
	function NPCJournalFrame:Enable()
		self:Update()
	end

	function NPCJournalFrame:Disable()
		self:Update()
	end

	----------------- Guides ---------------------
	function NPCJournalFrame:SetGuideData(guideType, objectId, setModel, dontShowFrame)

		if not (guideType and objectId)then
			guideType = self.currentGuideType
			objectId = self.currentGuideObjectId    
		else
			 self.currentGuideType = guideType
			 self.currentGuideObjectId = objectId   
		end

		self.guideTargetMode = GUIDE_MODE
		if guideType == "NPC" then
			
			local npcData = self:GetNPCDataById(objectId)
            if not dontShowFrame then
                self:ShowMainFrame()
            end
			self:UpdateStrategyTab(npcData, setModel)
			self:UpdateAbilitiesTab(npcData)
			self:UpdateLootTab(npcData)
			if setModel then
				self:SetTab(STRATEGY_TAB)
				self:SetMode(NPC_JOURNAL_MODE) 
			end
		end
		
		if guideType == "Mounts" then
			local mountData = self:GetMountDataById(objectId)
            if not dontShowFrame then
                self:ShowMainFrame()
            end
			self:UpdateGuideTab(mountData, true, nil, setModel)
			if setModel then        
				self:SetTab(GUIDE_TAB)
				self:SetMode(MOUNT_MODE)      
			end
		end
		
		if guideType == "Pets" then
			local petData = self:GetPetDataById(objectId)
            if not dontShowFrame then
                self:ShowMainFrame()
            end
			self:UpdateGuideTab(petData, false, petData, setModel)
			self:UpdatePetAbilitiesTab(petData)
			if setModel then          
				self:SetTab(GUIDE_TAB)
				self:SetMode(PET_MODE) 
			end
		end
		
		if guideType == "Bosses" then
			local bossData = self:GetBossDataById(objectId)
			local npcData = self:GetNPCDataById(objectId)
            if not dontShowFrame then
                self:ShowMainFrame()
            end
			self:UpdateRaidTab(bossData, npcData.name, setModel)
			if setModel then             
				self:SetTab(STRATEGY_TAB)
				self:SetMode(RAID_BOSS_MODE)
			end            
		end
        
        if guideType == "Followers" then
			local followerData = self:GetFollowerDataById(objectId)
            self:UpdateGuideTab(followerData, false, nil, true, true, objectId)
            if not dontShowFrame then
                self:ShowMainFrame()
            end
			if setModel then             
				self:SetTab(GUIDE_TAB)
				self:SetMode(FOLLOWER_MODE)
			end            
		end
	end

	function NPCJournalFrame:RefreshGuideData(dontShowFrame)
		self:SetGuideData(nil, nil, false, dontShowFrame)

	end

	function NPCJournalFrame:ShowGuideObjectPreview(name, displayId)
        local hintFrame = NPCJournalFrame.hintFrame
        hintFrame:SetMode(GUIUtils.HINT_WINDOW_NPC_MODE, true)
        local content = "|cffffd200"..name.."|r"
        hintFrame:SetText("")
        hintFrame:SetTitle(content)
        
        local x, y = GetCursorPosition();
        
        hintFrame.frame:ClearAllPoints()
        hintFrame.frame:SetPoint("TOPLEFT", DugisMain, "TOPRIGHT", 8, 12) 
        
        hintFrame:SetModel(displayId, content)
		hintFrame.modelFrame:SetFacing(0.55)
        hintFrame:Show(true) 
        hintFrame.modelFrame.title:SetWidth(205)  
        hintFrame.modelFrame:SetPoint("TOPLEFT", hintFrame.frame, "TOPLEFT", 9, -35)
        hintFrame.frame:SetWidth(220)  
	end
    
    
    local function OnGuideRowMouseLeave()        
        local hintFrame = NPCJournalFrame.hintFrame
        hintFrame.frame:Hide()         
    end

	function NPCJournalFrame:Load(threading)
        if self.scrollframe ~= nil then
            self:RegisterEvents()
        else
            NPCJournalFrame:CreateGUI()
        end
		
		if NPCJournalFrame.sidebarButtonFrame then
			NPCJournalFrame.sidebarButtonFrame:RestoreSidebarIconPosition()
		end
        
        NPCJournalFrame:InitializeData(threading)
	end

	function NPCJournalFrame:Unload()
		LuaUtils:foreach({"PLAYER_TARGET_CHANGED", "GET_ITEM_INFO_RECEIVED"}, function(item)
			NPCJournalFrame.mainFrame:UnregisterEvent(item)
		end) 
		
		NPCJournalFrame.mainFrame:Hide()
		NPCJournalFrame.sidebarButtonFrame:Hide()
        
        if DGV:UserSetting(DGV_UNLOADMODULES) then
            --Release data
            wipe(NPCObjects           )
            wipe(NPCIds               )
            wipe(MountObjects         )
            wipe(MountDataIds         )
            wipe(MountJournalIndices  )
            wipe(PetObjects           )
            wipe(PetDataIds           )
            wipe(BossObjects          )
            wipe(BossDataIds          )
            wipe(FollowerObjects      )
            wipe(FollowerDataIds      )
        end
	end 
	function NPCJournalFrame:ShouldLoad()
		if NPCJournalFrame.loaded then
			return false
		else
			return DugisGuideViewer:GuideOn() and true
		end
	end 

    function DGV.ProcessNPCLeafColor(oryginalText, guideType)
        if NPCJournalFrame.playersMounts == nil then
            NPCJournalFrame.playersMounts = NPCJournalFrame:GetPlayersAllMountIds()
            NPCJournalFrame.playersPets = NPCJournalFrame:GetPlayersAllPetIds()
            NPCJournalFrame.playersFollowers = NPCJournalFrame:GetPlayersAllFollowerIds()
        end 

        local guidemetadata 
        local objectId
        
        if guideType == "Followers" or guideType == "Pets" or guideType == "Mounts" then
            if oryginalText then
                guidemetadata = DugisGuideViewer.guidemetadata[oryginalText]
                
                local color 
                if guidemetadata then
                    objectId = tonumber(guidemetadata.objectId)
                   
                    if guideType == "Followers" then
                        if NPCJournalFrame.playersFollowers[objectId] then
                            color = "ffffff"
                        else
                            color = "999999"
                        end
                    end
                    
                    if guideType == "Pets" then
                        if NPCJournalFrame.playersPets[objectId] then
                            color = "ffffff"
                        else
                            color = "999999"
                        end
                    end  
                    
                    if guideType == "Mounts" then
                        if NPCJournalFrame.playersMounts[objectId] then
                            color = "ffffff"
                        else
                            color = "999999"
                        end
                    end
                else
                    color = "999999"
                end
                
                return "|cff"..color..oryginalText.."|r"
            end
        end
        
        
        if guideType == "Followers" and guidemetadata then
            local rawText = control.rawText
            
            --Workaround for cached follower names returned by GetFollowerInfo function
            local followerId = guidemetadata.objectId
            local postFix = "|Htype:".."Followers".."|h |h"
            local followerData = NPCJournalFrame:GetFollowerDataById(followerId)

            local faction = UnitFactionGroup("Player")

            --pandaren is neutral						
            if faction == "Neutral" then return end						
            
            --[faction][followerId] => followerName
            if FollowersCache == nil then
                FollowersCache = {}
                FollowersCache["Horde"] = {}
                FollowersCache["Alliance"] = {}
            end  
            
            FollowersCache[faction][followerId] = {}
            FollowersCache[faction][followerId].name = followerData.name
            FollowersCache[faction][followerId].level = followerData.level

            local title = followerData.name .. " ("..followerData.level.."+)"
            title = title..postFix
            local finalText = title
            
            local color = "|cff999999"
            if NPCJournalFrame.playersFollowers[tonumber(followerId)] then
                color = "|cffffffff"
            else
                color = "|cff999999"
            end
            
            return color..finalText
         end
       
       return oryginalText
    end
end

function NPCJournalFrame:OnGuideRowClick(title, objectId, clickedType)
    NPCJournalFrame:SetGuideData(clickedType, objectId, true)
end

function NPCJournalFrame:OnGuideRowMouseEnter(title, objectId, clickedType)
    if clickedType == "Followers" then
        local objectData = NPCJournalFrame:GetFollowerDataById(objectId)
        NPCJournalFrame:ShowGuideObjectPreview(objectData.name, objectData.displayID)
    end  
    
    if clickedType == "Pets" then
        local objectData = NPCJournalFrame:GetPetDataById(objectId)
        NPCJournalFrame:ShowGuideObjectPreview(objectData.name, objectData.modelId)
    end    
    
    if clickedType == "Mounts" then
        local objectData = NPCJournalFrame:GetMountDataById(objectId)
        NPCJournalFrame:ShowGuideObjectPreview(objectData.name, objectData.modelId)
    end    
    
    if clickedType == "Bosses" then
        local objectData = NPCJournalFrame:GetBossDataById(objectId)
        NPCJournalFrame:ShowGuideObjectPreview(objectData.name, objectData.modelId)
    end  
    
    if clickedType == "NPC" then
        local objectData = NPCJournalFrame:GetNPCDataById(objectId)
        NPCJournalFrame:ShowGuideObjectPreview(objectData.name, objectData.modelId)
    end
end
    
----------------- GUIDES - EXTENSIONS ----------------------------------
function DGV.GuidesOnModulesLoadedExtension()
	if NPCJournalFrame then
		NPCJournalFrame:BuildGuidesData()
	end
end