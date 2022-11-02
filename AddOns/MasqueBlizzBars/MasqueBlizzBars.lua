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

local MSQ = LibStub("Masque")

-- Title will be used for the group name shown in Masque
-- Buttons should contain a list of frame names with an integer value
--  If  0, assume to be a singular button with that name
--  If >0, attempt to loop through frames with the name prefix suffixed with the integer range
local MasqueBlizzBars = {
	Groups = {
		ActionBar = {
			Title = "Action Bar 1",
			Buttons = {
				ActionButton = NUM_ACTIONBAR_BUTTONS
			}
		},
		MultiBarBottomLeft = {
			Title = "Action Bar 2",
			Buttons = {
				MultiBarBottomLeftButton = NUM_MULTIBAR_BUTTONS
			}
		},
		MultiBarBottomRight = {
			Title = "Action Bar 3",
			Buttons = {
				MultiBarBottomRightButton = NUM_MULTIBAR_BUTTONS
			}
		},
		MultiBarLeft = {
			Title = "Action Bar 4",
			Buttons = {
				MultiBarLeftButton = NUM_MULTIBAR_BUTTONS
			}
		},
		MultiBarRight = {
			Title = "Action Bar 5",
			Buttons = {
				MultiBarRightButton = NUM_MULTIBAR_BUTTONS
			}
		},
		-- Three new bars for 10.0.0
		MultiBar5 = {
			Title = "Action Bar 6",
			Buttons = {
				MultiBar5Button = NUM_MULTIBAR_BUTTONS
			}
		},
		MultiBar6 = {
			Title = "Action Bar 7",
			Buttons = {
				MultiBar6Button = NUM_MULTIBAR_BUTTONS
			}
		},
		MultiBar7 = {
			Title = "Action Bar 8",
			Buttons = {
				MultiBar7Button = NUM_MULTIBAR_BUTTONS
			}
		},
		PetBar = {
			Title = "Pet Bar",
			Buttons = {
				PetActionButton = NUM_PET_ACTION_SLOTS
			}
		},
		PossessBar = {
			Title = "Possess Bar",
			Buttons = {
				PossessButton = NUM_POSSESS_SLOTS
			}
		},
		-- Since 10.0.0 the value is in the XML frame definition
		StanceBar = {
			Title = "Stance Bar",
			Buttons = {
				StanceButton = StanceBar.numButtons
			}
		},
		-- SpellFlyout always has one button at UI init time
		SpellFlyout = {
			Title = "Spell Flyouts",
			Buttons = {
				SpellFlyoutButton = 1
			}
		}
	}
}

function MasqueBlizzBars:SpellFlyout_Toggle(flyoutID, ...)
	-- Determine how many buttons the flyout will actually have
	local _, _, numSlots, _ = GetFlyoutInfo(flyoutID)
	local activeSlots = 0
        for slot = 1, numSlots do
		local _, _, isKnown, _, _ = GetFlyoutSlotInfo(flyoutID, slot)
		if (isKnown) then
			activeSlots = activeSlots+1
		end
	end

	-- Skin any extra buttons found
	local flyoutGroup = MasqueBlizzBars.Groups.SpellFlyout
	local numButtons = flyoutGroup.Buttons.SpellFlyoutButton
        if (numButtons < activeSlots) then
		for i = numButtons+1, activeSlots do
			flyoutGroup.Group:AddButton(_G["SpellFlyoutButton"..i])
		end
		flyoutGroup.Buttons.SpellFlyoutButton = activeSlots
	end
end

function MasqueBlizzBars:Init()
	hooksecurefunc(SpellFlyout, "Toggle", MasqueBlizzBars.SpellFlyout_Toggle)

	for k, v in pairs(MasqueBlizzBars.Groups) do
		v.Group = MSQ:Group("Blizzard Action Bars", v.Title)
	end

	MasqueBlizzBars:UpdateActionBars()
end

function MasqueBlizzBars:UpdateActionBars()
	for k, v in pairs(MasqueBlizzBars.Groups) do
		for _k, _v in pairs(v.Buttons) do
			-- If the number is zero this is a singular button name
			if (_v == 0) then
				v.Group:AddButton(_G[_k])
			else
				for i = 1, _v do
					v.Group:AddButton(_G[_k..i])
				end
			end
		end
	end
end

MasqueBlizzBars:Init()
