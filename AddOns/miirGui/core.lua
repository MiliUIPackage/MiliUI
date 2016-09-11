		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_LOGIN")
		f:SetScript("OnEvent", function()	
			
			if not miirguiDB then		
				miirguiDB = 
				{
					["blue"] = true,
					["grey"] = false,
					["green"] = false,
					["savemode"] = false
				}
			end
			
			miirgui ={}
				
			if miirguiDB["blue"] == true then
				miirgui.Color = {0.08,0.342,0.52,1}
				miirgui.Highlight = {0.086, 0.459, 0.710,1}
			elseif miirguiDB["grey"] == true then
				miirgui.Color = {0.301,0.301,0.301,1}
				miirgui.Highlight = {0.695, 0.695, 0.695,1}
			elseif miirguiDB["green"] == true then
				miirgui.Color = {0.118,0.278,0.157,1}
				miirgui.Highlight = {0.29, 0.65, 0.388,1}		
			end
		end) 