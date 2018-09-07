local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end

local C = Engine.Config
local UI = Engine.UI

local PixelPerfect = Engine.PixelPerfect

--[[
frames (* = master anchor)
	[A        -2,0         ]
	[B    -1,0 ][   -1,1  C]
	[D*    1,0 ][   1,0   E]
	[F  2,0][G  2,1][H  2,2]
	[I         3,0         ]
list generated:
	[-2] = { min = 0, max = 0, count = 1, list = {[0] = {A}}}
	[-1] = { min = 0, max = 1, count = 2, list = {[0] = {B}, [1] = {C}}}
	[1] = { min = 0, max = 0, count = 2, list = {[0] = {D, E}}}
	[2] = { min = 0, max = 2, count = 3, list = {[0] = {F}, [1] = {G}, [2] = {H}}}
	[3] = { min = 0, max = 0, count = 1, list = {[0] = {I}}}

	master anchor is the lower positive vertical index if possible, highest negative otherwise
	autogridanchor, autogridwidth and autogridheight are added to settings if they don't exist
	plugin must use GetAnchor, GetWidth and GetHeight to get correct anchor, width and height
	frames with identical coordinates (verticalIndex and horizontalIndex are anchored at the same place) and frames with identical coordinates as master are anchored to master
--]]
function Engine:AutoGridAnchor(settings, globalWidth, globalHeight, verticalSpacing)
--print("AUTO GRID ANCHORING (experimental)...")
	-- build temporary list used to reorder frames + set default indices + get lower/upper bounds
	local vMin = 100
	local vMax = -100
	local list = {}
	local index = 0
	local master = nil
	local mover = nil
	for _, setting in pairs(settings) do
		if setting.kind ~= "MOVER" and setting.enabled == true and setting.__invalid ~= true and setting.__deleted ~= true then
			-- set default indices + get lower/upper bounds
			setting.verticalIndex = setting.verticalIndex or index
			setting.horizontalIndex = setting.horizontalIndex or 0
			if setting.verticalIndex < vMin then vMin = setting.verticalIndex end
			if setting.verticalIndex > vMax then vMax = setting.verticalIndex end
			index = index + 1
--print("SETTING: "..tostring(setting.name).."  "..tostring(setting.verticalIndex).."  "..tostring(setting.horizontalIndex).."  "..tostring(master and master.name or "NO MASTER"))
			-- check if master
			if not master then
				master = setting
			else
				local previousMaster = master
				-- master is lowest positive vertical index or highest negative vertical index if no positive vertical index
				-- if 2 or more identical vertical index, master is the lowest horizontal index
				if master.verticalIndex == setting.verticalIndex then
					if setting.horizontalIndex < master.horizontalIndex then
						master = setting
					end
				elseif master.verticalIndex < 0 then
					if setting.verticalIndex < 0 and setting.verticalIndex > master.verticalIndex then
						master = setting
					elseif setting.verticalIndex >= 0 then
						master = setting
					end
				else
					if setting.verticalIndex >= 0 and setting.verticalIndex < master.verticalIndex then
						master = setting
					end
				end
-- if previousMaster ~= master then
-- print("PREVIOUS MASTER:"..tostring(previousMaster.name).." "..tostring(previousMaster.verticalIndex).." "..tostring(previousMaster.horizontalIndex))
-- end
			end
			-- add setting to list
			list[setting.verticalIndex] = list[setting.verticalIndex] or {hMin = 9, hMax = 0, count = 0, list = {}}
			local vEntry = list[setting.verticalIndex]
			if setting.horizontalIndex < vEntry.hMin then vEntry.hMin = setting.horizontalIndex end
			if setting.horizontalIndex > vEntry.hMax then vEntry.hMax = setting.horizontalIndex end
			--vEntry.count = vEntry.count + 1
			if not vEntry.list[setting.horizontalIndex] then -- plugins in a same cell are not counted
				vEntry.list[setting.horizontalIndex] = {}
				vEntry.count = vEntry.count + 1
			end
			tinsert(vEntry.list[setting.horizontalIndex], setting)
--print("INSERTING "..tostring(setting.name).."  "..tostring(setting.verticalIndex).."  "..tostring(setting.horizontalIndex))
		end
		if setting.kind == "MOVER" and not mover then
			mover = setting
		end
	end

	if index == 0 then return end -- no valid plugin found

	assert(master and index ~= 0, "No master found. Impossible to perform auto-anchor")

	-- master is anchored on mover if it exists
	if mover then
--print("REANCHORING MASTER:"..tostring(master.name))
		master.__autogridanchor = {"TOPLEFT", mover.name, "TOPLEFT", 0, 0}
	end

--[[
	every plugin in the same cell must be anchored to the same plugin
	first cell of line must be anchored to first of previous cell (TOPLEFT, BOTTOMLEFT, 0, v)
	not first cell of line must be anchored to previous cell (TOPLEFT, TOPRIGHT, h, 0)
	every plugin the same cell than master must be anchored to master (TOPLEFT, TOPLEFT, 0, 0)
--]]

--print("MASTER:"..tostring(master.name))

	-- compute auto anchoring + update plugins
	-- 0 -> vMin step -1
	do
		firstPluginOfFirstCellOfPreviousLine = master -- starts with master
		for v = 0, vMin, -1 do
			local vEntry = list[v]
			if vEntry then -- may have gaps
				-- new line
				local count = vEntry.count
				local width, spacing = PixelPerfect(globalWidth, count)
				local firstPluginOfPreviousCellOfCurrentLine = nil
				local firstPluginOfFirstCellOfCurrentLine = nil
				for h = vEntry.hMin, vEntry.hMax do
					local hEntry = vEntry.list[h]
					if hEntry then -- may have gaps
						-- new cell
						local firstPluginOfCurrentCellOfCurrentLine = nil -- keep first plugin of current cell
						for _, setting in pairs(hEntry) do
							-- each plugin in one cell
							setting.__autogridwidth = width -- new width
							setting.__autogridheight = globalHeight -- same height for each plugin
							if setting ~= master then
								if setting.verticalIndex == master.verticalIndex and setting.horizontalIndex == master.horizontalIndex then
--print("SAME AS MASTER:"..tostring(setting.name))
									setting.__autogridanchor = {"TOPLEFT", master.name, "TOPLEFT", 0, 0} -- every plugin in master cell must be anchored to master (if not master itself)
								elseif not firstPluginOfPreviousCellOfCurrentLine then -- no previous cell -> first cell
--print("FIRST CELL OF LINE:"..tostring(setting.name))
									setting.__autogridanchor = {"BOTTOMLEFT", firstPluginOfFirstCellOfPreviousLine.name, "TOPLEFT", 0, verticalSpacing} -- every plugins in first cell must be anchored to first of previous line
								else
--print("NEXT CELL OF LINE:"..tostring(setting.name))
									setting.__autogridanchor = {"TOPLEFT", firstPluginOfPreviousCellOfCurrentLine.name, "TOPRIGHT", spacing, 0} -- every plugins in next cells must be anchored to previous cell
								end
							end
							if not firstPluginOfCurrentCellOfCurrentLine then firstPluginOfCurrentCellOfCurrentLine = setting end -- store first plugin of current cell
							-- update plugin
							Engine:UpdatePluginInstance(setting.kind, setting.name)
						end
						firstPluginOfPreviousCellOfCurrentLine = firstPluginOfCurrentCellOfCurrentLine -- store first plugin of previous cell
						if not firstPluginOfFirstCellOfCurrentLine then firstPluginOfFirstCellOfCurrentLine = firstPluginOfPreviousCellOfCurrentLine end -- store first plugin of first cell
					end
				end
				firstPluginOfFirstCellOfPreviousLine = firstPluginOfFirstCellOfCurrentLine
			end
		end
	end

	-- 0 -> vMax step +1
	do
		firstPluginOfFirstCellOfPreviousLine = master -- starts with master
		for v = 0, vMax, 1 do
			local vEntry = list[v]
			if vEntry then -- may have gaps
				-- new line
				local count = vEntry.count
				local width, spacing = PixelPerfect(globalWidth, count)
				local firstPluginOfPreviousCellOfCurrentLine = nil
				local firstPluginOfFirstCellOfCurrentLine = nil
				for h = vEntry.hMin, vEntry.hMax do
					local hEntry = vEntry.list[h]
					if hEntry then -- may have gaps
						-- new cell
						local firstPluginOfCurrentCellOfCurrentLine = nil -- keep first plugin of current cell
						for _, setting in pairs(hEntry) do
							-- each plugin in one cell
							setting.__autogridwidth = width -- new width
							setting.__autogridheight = globalHeight -- same height for each plugin
							if setting ~= master then
								if setting.verticalIndex == master.verticalIndex and setting.horizontalIndex == master.horizontalIndex then
--print("SAME AS MASTER:"..tostring(setting.name))
									setting.__autogridanchor = {"TOPLEFT", master.name, "TOPLEFT", 0, 0} -- every plugin in master cell must be anchored to master (if not master itself)
								elseif not firstPluginOfPreviousCellOfCurrentLine then -- no previous cell -> first cell
--print("FIRST CELL OF LINE:"..tostring(setting.name))
									setting.__autogridanchor = {"TOPLEFT", firstPluginOfFirstCellOfPreviousLine.name, "BOTTOMLEFT", 0, -verticalSpacing} -- every plugins in first cell must be anchored to first of previous line
								else
--print("NEXT CELL OF LINE:"..tostring(setting.name))
									setting.__autogridanchor = {"TOPLEFT", firstPluginOfPreviousCellOfCurrentLine.name, "TOPRIGHT", spacing, 0} -- every plugins in next cells must be anchored to previous cell
								end
							end
							if not firstPluginOfCurrentCellOfCurrentLine then firstPluginOfCurrentCellOfCurrentLine = setting end -- store first plugin of current cell
							-- update plugin
							Engine:UpdatePluginInstance(setting.kind, setting.name)
						end
						firstPluginOfPreviousCellOfCurrentLine = firstPluginOfCurrentCellOfCurrentLine -- store first plugin of previous cell
						if not firstPluginOfFirstCellOfCurrentLine then firstPluginOfFirstCellOfCurrentLine = firstPluginOfPreviousCellOfCurrentLine end -- store first plugin of first cell
					end
				end
				firstPluginOfFirstCellOfPreviousLine = firstPluginOfFirstCellOfCurrentLine
			end
		end
	end

	-- DUMP
--[[
	print("MIN: "..tostring(vMin).."  MAX: "..tostring(vMax).."  master: "..tostring(master and master.name or ""))
	for v = vMin, vMax do
		local vEntry = list[v]
		if vEntry then -- may have gaps
			print("["..tostring(v).."] = {min="..tostring(vEntry.hMin)..",max="..tostring(vEntry.hMax)..",count="..tostring(vEntry.count)..", list={")
			for h = vEntry.hMin, vEntry.hMax do
				print(" ["..tostring(h).."] = {")
				local hEntry = vEntry.list[h]
				if hEntry then -- may have gaps
					for _, setting in pairs(hEntry) do
						print("  "..tostring(setting.name).." w:"..tostring(setting.__autogridwidth or setting.width).." h:"..tostring(setting.__autogridheight or setting.height).." a:"..tostring(setting.__autogridanchor and setting.__autogridanchor[1])..","..tostring(setting.__autogridanchor and setting.__autogridanchor[2])..","..tostring(setting.__autogridanchor and setting.__autogridanchor[3])..","..tostring(setting.__autogridanchor and setting.__autogridanchor[4])..","..tostring(setting.__autogridanchor and setting.__autogridanchor[5]))
					end
				end
				print("}")
			end
			print("}}")
		end
	end
--]]
	-- clean up
	wipe(list)
end


-- local settings = {
	-- { name = "A", enable = true, verticalIndex = -2, horizontalIndex = 0 },
	-- { name = "B", enable = true, verticalIndex = -1, horizontalIndex = 1 },
	-- { name = "C", enable = true, verticalIndex = -1, horizontalIndex = 0 },
	-- { name = "D", enable = true, verticalIndex = 1, horizontalIndex = 0 },
	-- { name = "E", enable = true, verticalIndex = 1, horizontalIndex = 0 },
	-- { name = "F", enable = true, verticalIndex = 2, horizontalIndex = 0 },
	-- { name = "G", enable = true, verticalIndex = 2, horizontalIndex = 1 },
	-- { name = "H", enable = true, verticalIndex = 2, horizontalIndex = 2 },
	-- { name = "I", enable = true, verticalIndex = 3, horizontalIndex = 0 },
-- }

-- Engine:AutoGridAnchor(settings, 300, 16, 3)

-- Engine:AutoGridAnchor = nil -- Desactivate for testing    TODO: remove