		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_LOGIN")
		f:SetScript("OnEvent", function()	

		-- This table defines the addon's default settings:
		local defaults = {
			["blue"] = true,
			["grey"] = false,
			["green"] = false,
			["savemode"] = false,
			["alerpos"]= 
					{
						x = 0,
						y = 0,
						enable = false,
					},
			["skinminimap"] = false,
			["cbar"] = false,
		}

		-- This function copies values from one table into another:
		local function copyDefaults(src, dst)
			-- If no source (defaults) is specified, return an empty table:
			if type(src) ~= "table" then return {} end
			-- If no target (saved variable) is specified, create a new table:
		if type(dst) ~= "table" then dst = { } end
			-- Loop through the source (defaults):
			for k, v in pairs(src) do
				-- If the value is a sub-table:
				if type(v) == "table" then
					-- Recursively call the function:
					dst[k] = copyDefaults(v, dst[k])
				-- Or if the default value type doesn't match the existing value type:
				elseif type(v) ~= type(dst[k]) then
					-- Overwrite the existing value with the default one:
					dst[k] = v
				end
			end
			-- Return the destination table:
			return dst
		end

		-- Copy the values from the defaults table into the saved variables table
		-- if it exists, and assign the result to the saved variable:
		miirguiDB = copyDefaults(defaults, miirguiDB)
		
		
		miirgui ={}
				
		if miirguiDB["blue"] == true then
			miirgui.Color = {1,0.690,0.007,1}
			miirgui.Highlight = {1, 0.819161, 0}
		elseif miirguiDB["grey"] == true then
			miirgui.Color = {0.301,0.301,0.301,1}
			miirgui.Highlight = {0.695, 0.695, 0.695,1}
		elseif miirguiDB["green"] == true then
			miirgui.Color = {0.118,0.278,0.157,1}
			miirgui.Highlight = {0.29, 0.65, 0.388,1}		
		end
			
		end) 