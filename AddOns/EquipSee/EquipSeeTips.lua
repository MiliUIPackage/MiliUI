
-----------------------------------------

local tcolors = { "44AAFF", "CC66FF", "66FFFF", "FF6666", "66FF66", "9966FF", "44FFAA", "FFAA44" }

-----------------------------------------

local gIsClear = true;

local function Eqx_OnTooltipCleared()
   gIsClear = true
end

-----------------------------------------

local function Eqx_OnTooltipSetItem(tip)

	if gIsClear then

		local name, link = tip:GetItem();

		if (name and IsEquippableItem(link)) then

			local itemID = Eqx_ItemIDfromLink (link);
			itemID = tonumber (itemID);

			local newline = "";

			local numSets = GetNumEquipmentSets();
			local x, t, n, setname;

			for x = 1, numSets do
				setname = GetEquipmentSetInfo (x)
				t = GetEquipmentSetItemIDs (setname);

				for n = 1, #t do
					if (itemID == t[n]) then
						if (newline == "") then
							newline = " "
						else
							newline = newline..", ";
						end

						local m = math.min (#tcolors, x);

						newline = newline.."|cFF"..tcolors[m]..setname.."|cFFFFFFFF";
						break;
					end
				end

			end

			if (newline ~= "") then
				tip:AddLine (newline)
			end

			gIsClear = false;
		end
	end
end

-----------------------------------------

-- removed for now since Blizz added it

--GameTooltip:HookScript("OnTooltipCleared", Eqx_OnTooltipCleared)
--GameTooltip:HookScript("OnTooltipSetItem", Eqx_OnTooltipSetItem)
