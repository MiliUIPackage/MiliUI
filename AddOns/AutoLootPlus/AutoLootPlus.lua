local addon = CreateFrame("Frame")
local epoch = 0

local LOOT_DELAY = 0.3

-- NOTE The event triggers twice upon opening a lootable container
addon:RegisterEvent("LOOT_READY")

--[[
Attempts to loot items from a container.

Looting occurs only if auto loot is enabled xor its toggle key is pressed. In
addition, enough time must elapse after a LOOT_READY event to prevent possible
disconnections.
]]--
addon:SetScript("OnEvent", function ()
	if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
		-- Verify that enough time has passed
		if (GetTime() - epoch) >= LOOT_DELAY then
			for i = GetNumLootItems(), 1, -1 do
				LootSlot(i)
			end
			
			epoch = GetTime()
		end
	end
end)
