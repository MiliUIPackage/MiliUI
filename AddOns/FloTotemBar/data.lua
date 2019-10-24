-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.

if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
	FLO_TOTEM_SPELLS = {
		["HUNTER"] = {
			["TRAP"] = {
				{ id = 187650, algo = 2 }, -- Freezing trap
				{ id = 162488, algo = 2 }, -- Steel trap
				{ id = 187698, algo = 3 }, -- Tar trap
				{ id = 1543, duration = 20, algo = 4 }, -- Flare
				{ id = 109248, duration = 10, algo = 4 }
			}
		},
		["SHAMAN"] = {
			["EARTH"] = {
				{ id = 2484, duration = 20 }, -- 8 Earthbind Totem
				{ id = 5394, duration = 15, talented = 157153 }, -- 13 Healing Stream Totem / Cloudburst Totem
				{ id = 210643, duration = 120, talented = 262395 }, -- 15 Totem Mastery
				{ id = 192077, duration = 15 }, -- 30 Wind Rush Totem
				{ id = 51485, duration = 20 }, -- 45 Earthgrab Totem
				{ id = 192058, duration = 2 }, -- 45 Lightning Surge Totem
				{ id = 196932, duration = 10 }, -- 45 Voodoo Totem
				{ id = 61882, duration = 10 }, -- 52 Earthquake Totem
				{ id = 108280, duration = 10 }, -- 54 Healing Tide Totem
				{ id = 8143, duration = 10 }, -- 58 Tremor Totem
				{ id = 98008, duration = 6 }, -- 62 Spirit Link Totem
				{ id = 207399, duration = 30 }, -- 75 Ancestral Protection Totem
				{ id = 198838, duration = 15 }, -- 75 Earthen Shield Totem
				{ id = 192222, duration = 15 }, -- 100 Liquid Magma Totem
			}
		}
	};
elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	FLO_TOTEM_SPELLS = {
		["HUNTER"] = {
			["TRAP"] = {
				{ id = 13795, algo = 1 }, -- Immolation trap
				{ id = 1499, algo = 1 }, -- Freezing trap
				{ id = 13809, algo = 1 }, -- Frost trap
				{ id = 13813, algo = 1 } -- Explosive trap
			}
		},
		["SHAMAN"] = {
			["EARTH"] = {
				{ id = 8071, duration = 120 }, -- Earth skin
				{ id = 2484, duration = 45 }, -- Earth bind
				{ id = 5730, duration = 15 }, -- Stoneclaw
				{ id = 8075, duration = 120 }, -- Strenght of Earth
				{ id = 8143, duration = 120 }, -- Tremor
			},
			["FIRE"] = {
				{ id = 3599, duration = 30 }, -- Searing
				{ id = 1535, duration = 5 }, -- nova
				{ id = 8181, duration = 120 }, -- frost resistance
				{ id = 8190, duration = 20 }, -- magma
				{ id = 8227, duration = 120 }, -- flametongue
			},
			["WATER"] = {
				{ id = 5394, duration = 60 }, -- healing stream
				{ id = 8166, duration = 120 }, -- poison cleansing
				{ id = 5675, duration = 60 }, -- manaspring
				{ id = 8184, duration = 120 }, -- fire resistance
				{ id = 8170, duration = 120 }, -- disease cleansing
				{ id = 16190, duration = 12 } -- mana tide
			},
			["AIR"] = {
				{ id = 8177, duration = 45 }, -- grounding
				{ id = 10595, duration = 120 }, -- nature resistance
				{ id = 8512, duration = 120 }, -- windfury
				{ id = 6495, duration = 300 }, -- sentry
				{ id = 15107, duration = 120 }, -- windwall
				{ id = 8835, duration = 120 }, -- grace of air
				{ id = 25908, duration = 120 }, -- tranquil air
			}
		}
	};
	FLO_TOTEM_LAYOUTS = {
		["1row"] = { label = FLO_TOTEM_1ROW, offset = 0,
			["FloBarFIRE"] = { "LEFT", "FloBarEARTH", "RIGHT", 3, 0 },
			["FloBarWATER"] = { "LEFT", "FloBarFIRE", "RIGHT", 3, 0 },
			["FloBarAIR"] = { "LEFT", "FloBarWATER", "RIGHT", 3, 0 },
		},
		["2rows"] = { label = FLO_TOTEM_2ROWS, offset = 1,
			["FloBarFIRE"] = { "LEFT", "FloBarEARTH", "RIGHT", 3, 0 },
			["FloBarWATER"] = { "TOPLEFT", "FloBarEARTH", "BOTTOMLEFT", 0, 0 },
			["FloBarAIR"] = { "LEFT", "FloBarWATER", "RIGHT", 3, 0 },
		},
		["4rows"] = { label = FLO_TOTEM_4ROWS, offset = 3,
			["FloBarFIRE"] = { "TOPLEFT", "FloBarEARTH", "BOTTOMLEFT", 0, 0 },
			["FloBarWATER"] = { "TOPLEFT", "FloBarFIRE", "BOTTOMLEFT", 0, 0 },
			["FloBarAIR"] = { "TOPLEFT", "FloBarWATER", "BOTTOMLEFT", 0, 0 },
		},
		["2rows-reverse"] = { label = FLO_TOTEM_2ROWS_REVERSE, offset = 0,
			["FloBarFIRE"] = { "LEFT", "FloBarEARTH", "RIGHT", 3, 0 },
			["FloBarWATER"] = { "BOTTOMLEFT", "FloBarEARTH", "TOPLEFT", 0, 0 },
			["FloBarAIR"] = { "LEFT", "FloBarWATER", "RIGHT", 3, 0 },
		},
		["4rows-reverse"] = { label = FLO_TOTEM_4ROWS_REVERSE, offset = 0,
			["FloBarFIRE"] = { "BOTTOMLEFT", "FloBarEARTH", "TOPLEFT", 0, 0 },
			["FloBarWATER"] = { "BOTTOMLEFT", "FloBarFIRE", "TOPLEFT", 0, 0 },
			["FloBarAIR"] = { "BOTTOMLEFT", "FloBarWATER", "TOPLEFT", 0, 0 },
		},
	}
	FLO_TOTEM_LAYOUTS_ORDER = {
		"1row",
		"2rows",
		"4rows",
		"2rows-reverse",
		"4rows-reverse"
	}
end
