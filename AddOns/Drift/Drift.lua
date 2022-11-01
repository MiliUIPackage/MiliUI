local frames = {
	["CharacterFrame"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftTabs = {
			"CharacterFrameTab1",
			"CharacterFrameTab2",
			"CharacterFrameTab3"
		}
	},
	["TradeSkillFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["TradeSkillFrame.OptionalReagentList"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ProfessionsFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["CraftFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ArchaeologyFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["QuestLogPopupDetailFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["QuestLogFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["QuestFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["QuestChoiceFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["WarboardQuestChoiceFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GossipFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["CollectionsJournal"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftDelegate = "CollectionsJournalMover" -- This frame is created inside Drift code
	},
	["CommunitiesFrame"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftDelegate = "CommunitiesMover", -- This frame is created inside Drift code
		DriftTabs = {
			"CommunitiesFrame.MaximizeMinimizeFrame.MaximizeButton",
			"CommunitiesFrame.MaximizeMinimizeFrame.MinimizeButton",
			"CommunitiesFrame.ChatTab",
			"CommunitiesFrame.RosterTab",
			"ClubFinderCommunityAndGuildFinderFrame.ClubFinderPendingTab",
		}
	},
	["SpellBookFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ClassTalentFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["AchievementFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["AchievementFrame.Header"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftDelegate = "AchievementFrame"
	},
	["AchievementFrame.SearchResults"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["WorldMapFrame"] = {
		DriftDisabledBy = "windowsDisabled",
		-- TODO: Add scaling support for WorldMapFrame
		DriftUnscalable = true
	},
	["QuestScrollFrame"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftDelegate = "WorldMapFrame"
	},
	["LookingForGuildFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["PVEFrame"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftTabs = {
			"PVEFrameTab1",
			"PVEFrameTab2",
			"PVEFrameTab3",
			"PVPQueueFrameCategoryButton1",
			"PVPQueueFrameCategoryButton2",
			"PVPQueueFrameCategoryButton3"
		}
	},
	["EncounterJournal"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["FriendsFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["BNToastFrame"] = {
		DriftDisabledBy = "miscellaneousDisabled",
	},
	["QuickJoinToastButton"] = { -- Social
		DriftDisabledBy = "buttonsDisabled",
	},
	["QuickJoinToastButton.Toast"] = {
		DriftDisabledBy = "miscellaneousDisabled",
	},
	["QuickJoinToastButton.Toast2"] = {
		DriftDisabledBy = "miscellaneousDisabled",
	},
	["ReputationDetailFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["RecruitAFriendRewardsFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ChannelFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["RaidInfoFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["DressUpFrame"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftTabs = {
			"DressUpFrame.ToggleOutfitDetailsButton",
			"DressUpFrame.MaximizeMinimizeFrame.MinimizeButton",
			"DressUpFrame.MaximizeMinimizeFrame.MaximizeButton"
		}
	},
	["SideDressUpFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["AddonList"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["MerchantFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["MailFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["SendMailFrame"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftDelegate = "MailFrame"
	},
	["OpenMailFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["BankFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GameMenuFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["SettingsPanel"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["VideoOptionsFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["AudioOptionsFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["InterfaceOptionsFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["KeyBindingFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["HelpFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["HelpOpenWebTicketButton"] = {
		DriftDisabledBy = "buttonsDisabled",
	},
	["RaidParentFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["RaidBrowserFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["TradeFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["SUFWrapperFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["TimeManagerFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["TabardFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GuildBankFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GuildRegistrarFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GuildControlUI"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["PetitionFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ColorPickerFrame.Header"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftDelegate = "ColorPickerFrame"
	},
	["AzeriteEmpoweredItemUI"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["AzeriteEssenceUI"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["AzeriteRespecFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["InspectFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ItemSocketingFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["MacroFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["MacroPopupFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["VoidStorageFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["SplashFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["WardrobeFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["CalendarFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["CalendarViewEventFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["CalendarViewEventFrame.Header"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftDelegate = "CalendarViewEventFrame"
	},
	["CalendarViewEventFrame.HeaderFrame"] = {
		DriftDisabledBy = "windowsDisabled",
		DriftDelegate = "CalendarViewEventFrame"
	},
	["CalendarViewHolidayFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["CalendarViewRaidFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ClassTrainerFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["AuctionFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["AuctionHouseFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["BlackMarketFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ReforgingFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GarrisonBuildingFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GarrisonLandingPage"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GarrisonMissionFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GarrisonShipyardFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GarrisonMonumentFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GarrisonRecruiterFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GarrisonRecruitSelectFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GarrisonCapacitiveDisplayFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["GarrisonLandingPageMinimapButton"] = {
		DriftDisabledBy = "buttonsDisabled",
	},
	["ExpansionLandingPageMinimapButton"] = {
		DriftDisabledBy = "buttonsDisabled",
	},
	["OrderHallMissionFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["OrderHallTalentFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["BFAMissionFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ArtifactFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ItemTextFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["PetStableFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["TaxiFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["FlightMapFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["PVPMatchScoreboard"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["PVPMatchResults"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["AlliedRacesFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ChatConfigFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ScrappingMachineFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["IslandsQueueFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ItemUpgradeFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ItemInteractionFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ChallengesKeystoneFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["BonusRollFrame"] = {
		DriftDisabledBy = "miscellaneousDisabled",
	},
	["GhostFrame"] = {
		DriftDisabledBy = "buttonsDisabled",
	},
	["ObliterumForgeFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["PlayerChoiceFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["PlayerChoiceToggleButton"] = {
		DriftDisabledBy = "buttonsDisabled",
	},
	["CypherPlayerChoiceToggleButton"] = {
		DriftDisabledBy = "buttonsDisabled",
	},
	["ChromieTimeFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["WarfrontsPartyPoseFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["CovenantPreviewFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["CovenantRenownFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["CovenantSanctumFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["CovenantMissionFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["SoulbindViewer"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["TorghastLevelPickerFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["RuneforgeFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["WeeklyRewardsFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["AnimaDiversionFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
	["ContributionCollectionFrame"] = {
		DriftDisabledBy = "windowsDisabled",
	},
}

-- Frame for handling events
local Drift = CreateFrame("Frame")

local function eventHandler(self, event, ...)
	if event == "ADDON_LOADED" then
		DriftHelpers:ModifyFrames(frames)
	elseif event == "PLAYER_REGEN_ENABLED" then
		DriftHelpers:ModifyFrames(frames)
	elseif event == "VARIABLES_LOADED" then
		-- Config
		DriftHelpers:SetupConfig()

		-- Disable frames depending on DriftOptions
		for frameName, properties in pairs(frames) do
			local disabledBy = properties.DriftDisabledBy
			if disabledBy ~= nil and DriftOptions[disabledBy] then
				frames[frameName] = nil
			end
		end

		-- Modify pre-loaded frames
		DriftHelpers:ModifyFrames(frames)

		-- Talents
		Drift:RegisterEvent("PLAYER_TALENT_UPDATE")
		Drift:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
		Drift:RegisterEvent("PET_SPECIALIZATION_CHANGED")

		-- Azerite
		Drift:RegisterEvent("ITEM_LOCKED")
		Drift:RegisterEvent("ITEM_DATA_LOAD_RESULT")

		-- TODO: Remove LFG events once a better solution exists
		-- LFG
		Drift:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
		Drift:RegisterEvent("LFG_LIST_SEARCH_FAILED")
		Drift:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")

		-- Communities
		Drift:RegisterEvent("CLUB_FINDER_RECRUITMENT_POST_RETURNED")
		Drift:RegisterEvent("CVAR_UPDATE")

		-- Professions
		Drift:RegisterEvent("TRADE_SKILL_LIST_UPDATE")

		-- Modify frames after an addon loads
		DriftHelpers:Wait(1, Drift.RegisterEvent, Drift, "ADDON_LOADED")

		-- Modify frames after combat ends
		Drift:RegisterEvent("PLAYER_REGEN_ENABLED")
	else
		DriftHelpers:BroadcastReset(frames)
	end
end

-- Respond to events to fix frames
Drift:SetScript("OnEvent", eventHandler)
Drift:RegisterEvent("VARIABLES_LOADED")
