local DGV = DugisGuideViewer
if not DGV then return end

local Ants = DGV:RegisterModule("Ants")

local HBD = LibStub("HereBeDragons-2.0-Dugis", true)

Ants.essential = true
local _
local DebugPrint = DGV.DebugPrint

local AntsConfig = {
    solidLine = function()
		return DugisGuideViewer:GetDB(DGV_ROUTE_STYLE) == "Solid"
	end,
    solidLineWidth = 14,
    solidLineTexture = "Interface/AddOns/DugisGuideViewerZ/Artwork/wayline_white.tga"
}

function Ants:GetWaySegmentColor()
	return DugisGuideUser.DGV_WAY_SEGMENT_COLOR or DugisGuideViewer.defaultWaySegmentColor()
end

function Ants:Initialize()
	DGV.Ants = Ants

	Ants.ant_dots = {}
	Ants.ant_dotsGPSArrow = {}
	Ants.miniant_dots= {}
	Ants.ant_phase = 0.0
	Ants.ant_cleared = true

	function Ants:Debugz()
		local dot
		DebugPrint("***********Debug***************")
		DebugPrint("MiniMap dots:")
		for _, dot in pairs(self.miniant_dots) do
			local point, relativeTo, relativePoint, xOffset, yOffset = dot:GetPoint(1)
			DebugPrint("point:"..point.."relativeTo"..relativeTo:GetName().."relativePoint"..relativePoint.."xOffset"..xOffset.."yOffset"..yOffset)
		end
		DebugPrint("Map dots:")
		for _, dot in pairs(self.ant_dots) do
			local point, relativeTo, relativePoint, xOffset, yOffset = dot:GetPoint(1)
			DebugPrint("point:"..point.."relativeTo"..relativeTo:GetName().."relativePoint"..relativePoint.."xOffset"..xOffset.."yOffset"..yOffset)
		end

		DebugPrint("***********End Debug***************")
	end



	---------------------------------------------------------------------------------------------
	-- Ant Trail Functions
	---------------------------------------------------------------------------------------------
	function Ants:ClampLine(x1, y1, x2, y2)
	
		if x1 and y1 and x2 and y2 --[[and x1~=x2 and y1~=y2]] then
			if y1 > 1 and y2 > 1 then return end
			if x1 > 1 and x2 > 1 then return end
			if y1 < 0 and y2 < 0 then return end
			if x1 < 0 and x2 < 0 then return end
			
			local x_div, y_div = (x2-x1), (y2-y1)
			if x_div == 0 or y_div == 0 then return end
			local x_0 = y1-x1/x_div*y_div
			local x_1 = y1+(1-x1)/x_div*y_div
			local y_0 = x1-y1/y_div*x_div
			local y_1 = x1+(1-y1)/y_div*x_div

			if y1 < 0 then
				x1 = y_0
				y1 = 0
			end

			if y2 < 0 then
				x2 = y_0
				y2 = 0
			end

			if y1 > 1 then
				x1 = y_1
				y1 = 1
			end

			if y2 > 1 then
				x2 = y_1
				y2 = 1
			end

			if x1 < 0 then
				y1 = x_0
				x1 = 0
			end

			if x2 < 0 then
				y2 = x_0
				x2 = 0
			end

			if x1 > 1 then
				y1 = x_1
				x1 = 1
			end

			if x2 > 1 then
				y2 = x_1
				x2 = 1
			end

			if x1 >= 0 and x2 >= 0 and y1 >= 0 and y2 >= 0 and x1 <= 1 and x2 <= 1 and y1 <= 1 and y2 <= 1 then
				return x1, y1, x2, y2
			end
		end
	end

	function Ants:ClearAntTrail()

		if not self.ant_cleared then
			for index, dot in ipairs(self.ant_dots) do
				dot:ClearAllPoints()
				dot:Hide()
			end			
            
            for index, dot in ipairs(self.ant_dotsGPSArrow) do
				dot:ClearAllPoints()
				dot:Hide()
			end

			for index, dot in ipairs(self.miniant_dots) do
				dot:ClearAllPoints()
				dot:Hide()
			end
		end
	end

	local function CreateDotTexture(parent, dim)

		local icon = parent:CreateTexture()
		icon:SetTexture([[Interface\AddOns\DugisGuideViewerZ\Artwork\Indicator-White.tga]])
		icon:ClearAllPoints()
		icon:SetDrawLayer("ARTWORK", 0)
		icon:SetWidth(8)
		icon:SetHeight(8)
		icon:Show()

		return icon
	end
	
	local function SetWaypointDotTextureAlpha(waypoint, element, playerFloor)
		if WorldMapFrame:GetMapID() == 947 then
			element:SetAlpha(0.90)
			return
		end
		local floor = UiMapId2Floor(waypoint.map)
		element:SetAlpha((floor~=playerFloor and .35) or 0.90)
	end
	
	Ants.miniant_points = {}
	
	if not AntUpdateDelay then
		AntUpdateDelay = CreateFrame("Frame")
		AntUpdateDelay:Hide()
	end
	
	function Ants:UpdateAntTrailDot(delay, func)
		AntUpdateDelay.func = func
		AntUpdateDelay.delay = delay
		AntUpdateDelay:Show()
		ChangeAntTrailColor = true
	end
	
	AntUpdateDelay:SetScript("OnUpdate", function(self, elapsed)
		self.delay = self.delay - elapsed
		if self.delay <= 0 then
			self:Hide()
			ChangeAntTrailColor = false
		end
end)

    local list = {"WorldMapFrame", "Minimap", "GPSArrow"}
	function Ants:UpdateAntTrail(elapsed)

		local self = Ants
		local index, objective
        
        if DGV:IsPlayerPosAvailable() then
            DGV.DugisArrow.minimap_overlay:Show()
        else
            DGV.DugisArrow.minimap_overlay:Hide()
        end
        
        LuaUtils.StartChangingLinesPositions(list)

		if DGV.DugisArrow.waypoints and not DugisGuideViewer.carboniteloaded then

			-- Clear Ant Trail
			Ants:ClearAntTrail()
			Ants.ant_cleared = false;

			-- Update Phase
			Ants.ant_phase = Ants.ant_phase + elapsed + 0.005
			while Ants.ant_phase > 1 do Ants.ant_phase = Ants.ant_phase - 1 end
			local remainder = self.ant_phase
			local mm_remainder = self.ant_phase

			-- Minimap Initialization
			local out2 = 1
			local mw, mh = DGV.DugisArrow.minimap_overlay:GetWidth(), DGV.DugisArrow.minimap_overlay:GetHeight()

			-- World Map Info
			local w, h = DGV.DugisArrow.map_overlay:GetWidth(), -DGV.DugisArrow.map_overlay:GetHeight()
            
            local wGPS, hGPS
			
			if GPSArrow then
				 wGPS, hGPS = GPSArrow.map_overlay:GetWidth(), -GPSArrow.map_overlay:GetHeight()
			end
            
			local m =  DGV:GetDisplayedOrPlayerMapId()
			local mapDotScale = DGV:GetAntScale(m)
            local last_x, last_y = DGV:GetPlayerPositionOnMap(m, true)
			
			local f = GetCurrentMapDungeonLevel_dugi()
			local out = 1
			local outGPSArrow = 1
            
			-- Get Player Position
			local last_mx, last_my = mw/2, -mh/2
			
			local color = Ants:GetWaySegmentColor() 

			-- Draw Trails To Each Objective
			for index, waypoint in ipairs(DGV.DugisArrow.waypoints) do
				local new_x, new_y = DugisGuideViewer:TranslateWorldMapPositionGlobal(waypoint.map, waypoint.x/100, waypoint.y/100, m)
                
				if not (new_x == last_x and new_y == last_y) then
					local x1, y1, x2, y2 = Ants:ClampLine(last_x, last_y, new_x, new_y)
					last_x, last_y = new_x, new_y

					--Minimap
					local mx2, my2 = Ants:GetIconCoordinate(waypoint)
					local mx1, my1 = last_mx or 0, last_my or 0
					last_mx, last_my = mx2, my2

					if x1 --[[and x1~=x2 and y1~=y2]] then
						local len = math.sqrt((x1-x2)*(x1-x2)*16/9+(y1-y2)*(y1-y2))
						if len == 0 then len = 0.0000001 end 
						local interval = .025/len
						local p = remainder*interval

						if DugisGuideViewer:UserSetting(DGV_SHOWANTS) and not DugisGuideViewer.WrongInstanceFloor and len > 0.0001 then

							-- World Map
							--todo: check this out
							--if WorldMapFrame:IsVisible() then
                                if AntsConfig.solidLine() then
                                    local visualLine = LuaUtils:GetNextVisualLine("WorldMapFrame", DGV.DugisArrow.map_overlay, AntsConfig.solidLineTexture)
                                    LuaUtils:DrawLineDugi(visualLine, DGV.DugisArrow.map_overlay, x1 * w, y1 * h, x2 * w, y2 * h, AntsConfig.solidLineWidth * mapDotScale, 32/30, "TOPLEFT")
                                    visualLine:Show()
                                    visualLine:SetDrawLayer("ARTWORK", 0)
									visualLine:SetDesaturated(true)
									visualLine:SetVertexColor(unpack(color))	
									
									SetWaypointDotTextureAlpha(waypoint, visualLine, f)
                                else
                                    while p < 1 do
                                        local dot = self.ant_dots[out]
                                        if not dot or ChangeAntTrailColor == true then
                                            -- Create New Dot
                                            dot = CreateDotTexture(DGV.DugisArrow.map_overlay)
                                            dot:SetDrawLayer("ARTWORK", 0)
                                            self.ant_dots[out] = dot
                                        end
                                        SetWaypointDotTextureAlpha(waypoint, dot, f)
                                        dot:Show();
										dot:SetDesaturated(true)
										dot:SetVertexColor(unpack(color))
										
										dot:SetWidth(8 * mapDotScale)
										dot:SetHeight(8 * mapDotScale)
                                        dot:ClearAllPoints()
                                        dot:SetPoint("CENTER", DGV.DugisArrow.map_overlay, "TOPLEFT", x1*w*(1-p)+x2*w*p, y1*h*(1-p)+y2*h*p)
                                        out = out + 1
                                        p = p + interval
                                    end
                                end
						--	end	

                            if GPSArrow and GPSArrow:IsVisible() then
                                if AntsConfig.solidLine() then
                                    local visualLine = LuaUtils:GetNextVisualLine("GPSArrow", GPSArrow.map_overlay, AntsConfig.solidLineTexture)
                                    LuaUtils:DrawLineDugi(visualLine, GPSArrow.map_overlay, x1 * wGPS, y1 * hGPS, x2 * wGPS, y2 * hGPS, AntsConfig.solidLineWidth / GPSArrow.scale, 32/30, "TOPLEFT")
                                    visualLine:Show()
                                    visualLine:SetDrawLayer("ARTWORK", 0)
									visualLine:SetDesaturated(true)
									visualLine:SetVertexColor(unpack(color))	
									
									SetWaypointDotTextureAlpha(waypoint, visualLine, f)
                                else
									local progressStep = 3 * interval / GPSArrow.scale
									local progress = 3 * (remainder * interval) / GPSArrow.scale
								
                                    while progress < 1 do
                                        local dot = self.ant_dotsGPSArrow[outGPSArrow]
                                        if not dot or ChangeAntTrailColor == true then
                                            -- Create New Dot
                                            dot = CreateDotTexture(GPSArrow.map_overlay)
                                            dot:SetDrawLayer("ARTWORK", 0)
                                            self.ant_dotsGPSArrow[outGPSArrow] = dot
                                        end
                                        SetWaypointDotTextureAlpha(waypoint, dot, f)
                                        dot:Show();
										dot:SetDesaturated(true)
										dot:SetVertexColor(unpack(color))	
                                        dot:SetWidth(8 / (GPSArrow.scale or 1))
                                        dot:SetHeight(8 / (GPSArrow.scale or 1))
                                        
                                        dot:ClearAllPoints()
                                        dot:SetPoint("CENTER", GPSArrow.map_overlay, "TOPLEFT", x1*wGPS*(1-progress)+x2*wGPS*progress, y1*hGPS*(1-progress)+y2*hGPS*progress)
                                        outGPSArrow = outGPSArrow + 1
                                        progress = progress + progressStep
                                    end
                                end
							end
							
							--For Minimap
							if mx2 then
								local mlen = math.sqrt( (mx1-mx2)*(mx1-mx2) + (my1-my2)*(my1-my2) )
								if mlen == 0 then mlen = 0.000001 end 
								local mm_interval = 15/mlen
								local mm_p = mm_remainder*mm_interval
                            
                                if AntsConfig.solidLine() then
								
									--Condition for first line. Moving the first point with 5
									if index == 1 then
										local dX = mx2 - mx1
										local dY = my2 - my1
										dX = dX / mlen
										dY = dY / mlen
										
										dX = dX * 6
										dY = dY * 6
										
										mx1 = mx1 + dX
										my1 = my1 + dY
									end
									
                                    local visualLine = LuaUtils:GetNextVisualLine("Minimap", DGV.DugisArrow.minimap_overlay, AntsConfig.solidLineTexture)
                                    LuaUtils:DrawLineDugi(visualLine, DGV.DugisArrow.minimap_overlay, mx1, my1, mx2, my2, AntsConfig.solidLineWidth, 32/30, "TOPLEFT")
                                    visualLine:Show()
                                    visualLine:SetDrawLayer("ARTWORK", 0)
									visualLine:SetDesaturated(true)
									visualLine:SetVertexColor(unpack(color))	

									waypoint.minimapVisualLine = visualLine
									
									SetWaypointDotTextureAlpha(waypoint, visualLine, f)
                                else
                                    while mm_p < 1 and not waypoint.hiddenRestOnMinimap do
                                        -- Minimap
                                        local minimapdot = self.miniant_dots[out2]
                                        if not minimapdot or ChangeAntTrailColor == true then
                                            -- Create New Dot
                                            minimapdot = CreateDotTexture(DGV.DugisArrow.minimap_overlay)
                                            minimapdot:SetDrawLayer("ARTWORK", 7)
                                            self.miniant_dots[out2] = minimapdot
                                        end
                                        SetWaypointDotTextureAlpha(waypoint, minimapdot, f)
										
                                        minimapdot:Show()
										minimapdot:SetWidth(8)
										minimapdot:SetHeight(8)
										minimapdot:SetDesaturated(true)
										minimapdot:SetVertexColor(unpack(color))	
                                        minimapdot:ClearAllPoints()
                                        minimapdot:SetPoint("CENTER", DGV.DugisArrow.minimap_overlay, "TOPLEFT", mx1*(1-mm_p)+mx2*mm_p, my1*(1-mm_p)+my2*mm_p)
                                        out2 = out2 + 1
                                        mm_p = mm_p + mm_interval
                                    end
                                    mm_remainder = (mm_p-1)/mm_interval
                                end
							end
							
							DGV.DugisArrow.UpdateWaypointsVisibility()
							
						end
					end
				end
			end
		else
			-- Clear Ant Trail
			self:ClearAntTrail()
			self.ant_cleared = true
		end
        
        LuaUtils:StopChangingLinesPositions(list)
		
	end

	function Ants:GetIconCoordinate(objective)
		--[[
		if DugisGuideViewer:UserSetting("TomTomArrow") then
			local title = unpack(objective.tomtom[5]).title
			DebugPrint("TITLE:"..title)
		else

		end
		--]]
		--local dist = TomTom:GetDistanceToWaypoint(objective.tomtom)
		--DebugPrint("dist="..dist)
		--if objective.minimap:IsShown() then DebugPrint("is shown") else DebugPrint("NOT shown") end
		local _, _, _, x, y = objective.minimap:GetPoint()
		if x and y then
			return x+DGV.DugisArrow.minimap_overlay:GetWidth()/2, y-DGV.DugisArrow.minimap_overlay:GetHeight()/2
		end
	end

	function Ants:Load()
	end

	function Ants:Unload()
	end
end
