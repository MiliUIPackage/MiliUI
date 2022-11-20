local addonName, addon = ...

addon.WQTU = LibStub("AceAddon-3.0"):NewAddon("WorldQuestTabUtilities");
addon.variables = {};
addon.debug = false;
local WQT_Utils = WQT_WorldQuestFrame.WQT_Utils;
local _L = addon.L;
local _V = addon.variables;
local WQTU = addon.WQTU;
local WQT_V = WQT_WorldQuestFrame.variables;

_V["HISTORY_SORT_FACTION"] = {
	[1] = _L["BOTH_FACTIONS"]
	,[2] = FACTION_ALLIANCE
	,[3] = FACTION_HORDE
}

_V["HISTORY_FILTER_SCOPE"] = {
	[1] = _L["ACCOUNT"]
	,[2] = _L["REALM"]
	,[3] = CHARACTER
}

_V["WQTU_SETTINGS_CATEGORIES"] = {
	{["id"]="WQTU_TALLIES", ["label"] = _L["TALLIES"], ["parentCategory"] = "WQTU", ["expanded"] = true}
}

_V["WQTU_SETTING_LIST"] = {
	{["type"] = WQT_V["SETTING_TYPES"].checkBox, ["categoryID"] = "WQTU", ["label"] = _L["DIRECTION_LINE"], ["tooltip"] = _L["DIRECTION_LINE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQTU.settings.directionLine = value;
				WQTU_DirectLineFrame:UpdatePlayerPosition();
			end
			,["getValueFunc"] = function() return WQTU.settings.directionLine end;
			}
	,{["type"] = WQT_V["SETTING_TYPES"].button, ["categoryID"] = "WQTU_TALLIES", ["label"] = CHECK_ALL
			, ["valueChangedFunc"] = function(value) 
				for k, v in pairs(WQTU.settings.tallies) do
					WQTU.settings.tallies[k] = true;
				end
				WQTU_TallyList:UpdateList();
			end
			}
	,{["type"] = WQT_V["SETTING_TYPES"].button, ["categoryID"] = "WQTU_TALLIES", ["label"] = UNCHECK_ALL
			, ["valueChangedFunc"] = function(value) 
				for k, v in pairs(WQTU.settings.tallies) do
					WQTU.settings.tallies[k] = false;
				end
				WQTU_TallyList:UpdateList();
			end
			}
}


-- This is just easier to maintain than changing the entire string every time
local _patchNotes = {
		{["version"] = "9.0.02"
			,["new"] = {
				"Added anima as a separate reward type, showing its full value rather than individual tokens."
			}
		}
		,{["version"] = "9.0.01"
			,["minor"] = 4
			,["intro"] = {"Compatibility update with new World Quest Tab update"}
		}
		,{["version"] = "9.0.01"
			,["minor"] = 3
			,["fixes"] = {
				"Fixed an error when completing a world quest with rewards that don't get tallied (i.e. armor)"
			}
		}
		,{["version"] = "9.0.01"
			,["minor"] = 2
			,["changes"] = {
				"Moved the patch notes and Reward Graph options to the new settings button."
			}
			,["fixes"] = {
				"Fixed some issues with distance sorting."
			}
		}
		,{["version"] = "9.0.01"
			,["intro"] = {"Update for the new 9.0 UI and compatibility with the latest WQT version"}
		}
	}

_V["LATEST_UPDATE"] = WQT_Utils:FormatPatchNotes(_patchNotes, "WQT Utilities");
WQT_Utils:DeepWipeTable(_patchNotes);


