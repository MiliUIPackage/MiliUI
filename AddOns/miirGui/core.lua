local function miirgui_defaults()
	-- This table defines the addon's default settings:

	local defaults = {
		["color"] =
			{
				r=1,
				g=0.690,
				b=0.007,
				hr=1,
				hg=0.819161,
				hb=0,
				enable=false,
			},
		["blue"] = true,
		["grey"] = false,
		["savemode"] = true,
		["outline"] = true,
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

end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", miirgui_defaults)