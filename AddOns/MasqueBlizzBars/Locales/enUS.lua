--
-- Masque Blizzard Bars
--
-- Locales\enUS.lua -- enUS Localization File
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by the
-- Free Software Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
-- or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
-- more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program. If not, see <https://www.gnu.org/licenses/>.
--

-- Please use CurseForge to submit localization content for another language:
-- https://www.curseforge.com/wow/addons/masque-blizz-bars-revived/localization

local Locale = GetLocale()
if Locale ~= "enUS" then return end

local _, Shared = ...
local L = Shared.Locale

-- These are the names of the bars in game. Try to label them the way Blizzard refers to them.
L["Action Bar 1"] = "Action Bar 1"
L["Action Bar 2"] = "Action Bar 2"
L["Action Bar 3"] = "Action Bar 3"
L["Action Bar 4"] = "Action Bar 4"
L["Action Bar 5"] = "Action Bar 5"
L["Action Bar 6"] = "Action Bar 6"
L["Action Bar 7"] = "Action Bar 7"
L["Action Bar 8"] = "Action Bar 8"
L["Pet Bar"] = "Pet Bar"
L["Possess Bar"] = "Possess Bar"
L["Stance Bar"] = "Stance Bar"

-- This is only referred to in code. It refers to popup menus of abilities in the Spellbook that can be placed on action bars.
L["Spell Flyouts"] = "Spell Flyouts"
L["This group includes all flyouts shown anywhere in the game, such as Action Bars and the Spellbook."] = "This group includes all flyouts shown anywhere in the game, such as Action Bars and the Spellbook."

-- This is sometimes called the Override Bar and isn't really referred to in the game
L["Vehicle Bar"] = "Vehicle Bar"
L["This bar is shown when you enter a vehicle with abilities. The exit button is not currently able to be skinned."] = "This bar is shown when you enter a vehicle with abilities. The exit button is not currently able to be skinned."

-- This refers to the two types of large buttons.  In Edit Mode, it's referred to as Extra Abilities.
L["Extra Ability Buttons"] = "Extra Ability Buttons"
L["This group includes the Extra Action Button shown during encounters and quests, and all Zone Ability Buttons shown for location-based abilities.\n\nSome buttons have additional background images framing them, so square skins tend to work best."] = "This group includes the Extra Action Button shown during encounters and quests, and all Zone Ability Buttons shown for location-based abilities.\n\nSome buttons have additional background images framing them, so square skins tend to work best."

-- This is not really referred to in the game.
L["Pet Battle Bar"] = "Pet Battle Bar"

