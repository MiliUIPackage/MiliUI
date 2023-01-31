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
if Locale ~= "zhTW" then return end

local _, Shared = ...
local L = Shared.Locale

L["Action Bar 1"] = "快捷列 1"
L["Action Bar 2"] = "快捷列 2"
L["Action Bar 3"] = "快捷列 3"
L["Action Bar 4"] = "快捷列 4"
L["Action Bar 5"] = "快捷列 5"
L["Action Bar 6"] = "快捷列 6"
L["Action Bar 7"] = "快捷列 7"
L["Action Bar 8"] = "快捷列 8"
L["Extra Ability Buttons"] = "額外技能按鈕"
L["Notes"] = "請啟用 Masque 插件來更改遊戲內鍵快捷列的按鈕外觀。"
L["Pet Bar"] = "寵物列"
L["Pet Battle Bar"] = "寵物對戰列"
L["Possess Bar"] = "控制列"
L["Spell Flyouts"] = "技能彈出選單"
L["Stance Bar"] = "形態列"
L["This bar is shown when you enter a vehicle with abilities. The exit button is not currently able to be skinned."] = "上了有技能的載具時所顯示的快捷列，目前無法更改離開載具按鈕的外觀。"
L["This group includes all flyouts shown anywhere in the game, such as Action Bars and the Spellbook."] = "包含遊戲中所有會顯示彈出選單的技能群組，像是快捷列和法術書。"
L[ [=[This group includes the Extra Action Button shown during encounters and quests, and all Zone Ability Buttons shown for location-based abilities.

Some buttons have additional background images framing them, so square skins tend to work best.]=] ] = [=[包含首領戰和任務的額外技能按鈕，以及特定區域才會出現的區域技能。

有些技能會包圍著額外的背景圖案，所以方形的外觀似乎最適合。]=]
L["Vehicle Bar"] = "載具列"

-- 自行加入
L["Blizzard Action Bars"] = "遊戲內建快捷列"



