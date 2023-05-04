--[[---------------------------------------------------------------------------
    Addon:  CursorTrail
    File:   CursorTrailShapes.lua
    Desc:   This file contains a list of shapes used by this addon.
-----------------------------------------------------------------------------]]

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Aliases to Globals                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local Globals = _G
local _  -- Prevent tainting global _ .
local pairs = _G.pairs
local print = _G.print
local table = _G.table
local tonumber = _G.tonumber

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Declare Namespace                                 ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local CursorTrail = _G.CursorTrail or {}
if (not _G.CursorTrail) then _G.CursorTrail = CursorTrail end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Remap Global Environment                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

setfenv(1, _G.CursorTrail)  -- Everything after this uses our namespace rather than _G.

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Functions                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function ShapeDropDown_AddLines(dropdown)
    local bRetailWoW = isRetailWoW()
    
    -- IMPORTANT!  Add new lines in alphabetical order (by display name).
    --                ---------------------------   ------------------------------
    --                       DISPLAY NAME                     FILE NAME
    --                ---------------------------   ------------------------------
    dropdown:AddItem( kStr_None,                    "" )
    dropdown:AddItem( "Circle 1",                   kMediaPath.."Circle 1.tga" )
    dropdown:AddItem( "Circle 2",                   kMediaPath.."Circle 2.tga" )
    dropdown:AddItem( "Cross 1",                    kMediaPath.."Cross 1.tga" )
    dropdown:AddItem( "Cross 2",                    kMediaPath.."Cross 2.tga" )
    dropdown:AddItem( "Cross 3",                    kMediaPath.."Cross 3.tga" )
    dropdown:AddItem( "Glow",                       kMediaPath.."Glow 1.tga" )
    dropdown:AddItem( "Glow (Reversed)",            kMediaPath.."Glow Reversed.tga" )
    dropdown:AddItem( "Ring - Arcane",              "Interface\\UnitPowerBarAlt\\Arcane_Circular_Frame" )
    dropdown:AddItem( "Ring - Fire",                "Interface\\UnitPowerBarAlt\\Fire_Circular_Frame" )
    dropdown:AddItem( "Ring 1",                     kMediaPath.."Ring 1.tga" )
    dropdown:AddItem( "Ring 1 (Soft)",              kMediaPath.."Ring Soft 1.tga" )
    dropdown:AddItem( "Ring 2",                     kMediaPath.."Ring 2.tga" )
    dropdown:AddItem( "Ring 2 (Soft)",              kMediaPath.."Ring Soft 2.tga" )
    dropdown:AddItem( "Ring 3",                     kMediaPath.."Ring 3.tga" )
    dropdown:AddItem( "Ring 3 (Soft)",              kMediaPath.."Ring Soft 3.tga" )
    dropdown:AddItem( "Ring 4",                     kMediaPath.."Ring 4.tga" )
    dropdown:AddItem( "Ring 4 (Soft)",              kMediaPath.."Ring Soft 4.tga" )
    dropdown:AddItem( "Sphere",                     kMediaPath.."Sphere Edge 2.tga" )
    dropdown:AddItem( "Star",                       kMediaPath.."Star 1.tga" )
    dropdown:AddItem( "Swirl",                      kMediaPath.."Swirl.tga" )
   
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    ----dropdown:AddItem( "Ring 2 (Black Edge)",        kMediaPath.."Ring Edge 2.tga" )
    ----dropdown:AddItem( "Test: NewCharacterNotification", "Interface\\GLUES\\CHARACTERCREATE\\NewCharacterNotification" )
    --dropdown:AddItem( "Test: EventNotificationGlow", "Interface\\Calendar\\EventNotificationGlow" )
    --dropdown:AddItem( "Test: Wisp", "Interface\\GLUES\\Models\\UI_DeathKnight\\Wisp" )
    --dropdown:AddItem( "Test: AzeriteGoldRingRanks", "Interface\\Azerite\\AzeriteGoldRingRanks" )
    --dropdown:AddItem( "Test: AzeriteGoldRingRank2", "Interface\\Azerite\\AzeriteGoldRingRank2" )
    --dropdown:AddItem( "Test: AzeriteTitanBGRank2", "Interface\\Azerite\\AzeriteTitanBGRank2" )
    --dropdown:AddItem( "Test: AzeriteTitanBGRank3", "Interface\\Azerite\\AzeriteTitanBGRank3" )
    --dropdown:AddItem( "Test: AzeriteTitanBGRank4", "Interface\\Azerite\\AzeriteTitanBGRank4" )
    --dropdown:AddItem( "Test: challenges-gold", "Interface\\Challenges\\challenges-gold" )
    --dropdown:AddItem( "Test: challenges-gold-sm", "Interface\\Challenges\\challenges-gold-sm" )
    --dropdown:AddItem( "Test: GoldRing", "Interface\\COMMON\\GoldRing" )
    --dropdown:AddItem( "Test: stormyellow-extrabutton", "Interface\\ExtraButton\\stormyellow-extrabutton" )
    --dropdown:AddItem( "Test: UI_Troll_sunglare", "Interface\\GLUES\\Models\\UI_Alliance\\UI_Troll_sunglare" )
    --dropdown:AddItem( "Test: UI_Goblin_sunglare", "Interface\\GLUES\\Models\\UI_Dwarf\\UI_Goblin_sunglare" )
    --dropdown:AddItem( "Test: glow_green", "Interface\\GLUES\\Models\\UI_MainMenu_BurningCrusade\\glow_green" )
    --dropdown:AddItem( "Test: HelpIcon-Bug", "Interface\\HELPFRAME\\HelpIcon-Bug" )
    --dropdown:AddItem( "Test: HelpIcon-Bug-Red", "Interface\\HELPFRAME\\HelpIcon-Bug-Red" )
    --dropdown:AddItem( "Test: UI-BonusObjectiveBlob-MinimapRing", "Interface\\MINIMAP\\UI-BonusObjectiveBlob-MinimapRing" )
    --dropdown:AddItem( "Ring - Gradient 01", "Interface\\Professions\\ProfessionSpecializationMiniDialArtAlchemy" )
    --dropdown:AddItem( "Ring - Gradient 02", "Interface\\Professions\\ProfessionSpecializationMiniDialArtBlacksmithing" )
    --dropdown:AddItem( "Ring - Gradient 03", "Interface\\Professions\\ProfessionSpecializationMiniDialArtEnchanting" )
    --dropdown:AddItem( "Ring - Gradient 04", "Interface\\Professions\\ProfessionSpecializationMiniDialArtEngineering" )
    --dropdown:AddItem( "Ring - Gradient 05", "Interface\\Professions\\ProfessionSpecializationMiniDialArtHerbalism" )
    --dropdown:AddItem( "Ring - Gradient 06", "Interface\\Professions\\ProfessionSpecializationMiniDialArtInscription" )
    --dropdown:AddItem( "Ring - Gradient 07", "Interface\\Professions\\ProfessionSpecializationMiniDialArtJewelcrafting" )
    --dropdown:AddItem( "Ring - Gradient 08", "Interface\\Professions\\ProfessionSpecializationMiniDialArtLeatherworking" )
    --dropdown:AddItem( "Ring - Gradient 09", "Interface\\Professions\\ProfessionSpecializationMiniDialArtMining" )
    --dropdown:AddItem( "Ring - Gradient 10", "Interface\\Professions\\ProfessionSpecializationMiniDialArtSkinning" )
    --dropdown:AddItem( "Ring - Gradient 11", "Interface\\Professions\\ProfessionSpecializationMiniDialArtTailoring" )
    --dropdown:AddItem( "Square - Art, Gold 3D", "Interface\\SPELLBOOK\\RotationIconFrame" )
    --dropdown:AddItem( "Square - Art, Gold", "Interface\\Vehicles\\UI-Vehicles-Button-Highlight" )
    --dropdown:AddItem( "Test: UI-GlyphFrame-Locked", "Interface\\SPELLBOOK\\UI-GlyphFrame-Locked" )
    --dropdown:AddItem( "Test: Spell-Shadow-Acceptable", "Interface\\SpellShadow\\Spell-Shadow-Acceptable" )
    --dropdown:AddItem( "Test: UI-TutorialFrame-AttackCursor", "Interface\\TutorialFrame\\UI-TutorialFrame-AttackCursor" )
    --dropdown:AddItem( "Test: Atramedes_Circular_Frame", "Interface\\UnitPowerBarAlt\\Atramedes_Circular_Frame" )
    --dropdown:AddItem( "Ring - Art, Fire", "Interface\\UnitPowerBarAlt\\Fire_Circular_Frame" )
    --dropdown:AddItem( "Ring - Art, Horde", "Interface\\UnitPowerBarAlt\\Horde_Circular_Frame" )
    --dropdown:AddItem( "Ring - Art, Ice", "Interface\\UnitPowerBarAlt\\Ice_Circular_Frame" )
    --dropdown:AddItem( "Ring - Art, Meat", "Interface\\UnitPowerBarAlt\\Meat_Circular_Frame" )
    --dropdown:AddItem( "Ring - Art, Gear", "Interface\\UnitPowerBarAlt\\Mechanical_Circular_Frame" )
    --dropdown:AddItem( "Ring - Art, Bronze", "Interface\\UnitPowerBarAlt\\MetalBronze_Circular_Frame" )
    --dropdown:AddItem( "Ring - Art, Eternium", "Interface\\UnitPowerBarAlt\\MetalEternium_Circular_Frame" )
    --dropdown:AddItem( "Ring - Art, Metal Yellow", "Interface\\UnitPowerBarAlt\\WowUI_Circular_Frame" )
    --dropdown:AddItem( "Test: Reticle2", "Interface\\Vehicles\\Reticle2" )
    --dropdown:AddItem( "Glow - Yellow",              "Interface\\Challenges\\challenges-metalglow" )
    --if bRetailWoW then
    --    dropdown:AddItem( "Ring - Art, Orange",         "Interface\\PVPFrame\\pvpqueue-sidebar-honorbar-fill" )
    --end
    
end

--- End of File ---