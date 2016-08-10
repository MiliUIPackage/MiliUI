		MiirGui, miirgui = ...

		miirgui.Color = {1.0, 0.745, 0,1}
		miirgui.Highlight = {0.695, 0.695, 0.695,1}
	
		function m_icon(arg1, arg2, arg3, arg4, arg5)
			local f = CreateFrame("Frame",nil,arg1)
			f:SetFrameStrata(arg5)
			f:SetSize(64,64)
			local t = f:CreateTexture(nil,"BACKGROUND")
			t:SetTexture("Interface\\AddOns\\miirGui\\gfx\\"..arg2)
			t:SetAllPoints(f)
			f.texture = t
			f:SetPoint("Topleft",arg3,arg4)
			f:Show() 
		end
		
		function m_border(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8)
			if arg1:GetName() == nil then
				local Border = CreateFrame("Frame", "border_has_no_name", arg1)
				Border:SetSize(arg2, arg3)
				Border:SetPoint(arg4,arg5,arg6)
				Border:SetBackdrop({
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
				edgeSize = arg7})
				Border:SetBackdropBorderColor(1, 1, 1)
				Border:SetFrameStrata(arg8)
			elseif arg1:GetName() ~= nil and _G["m_border_"..arg1:GetName()] == nil then
				local FrameName = "m_border_" .. arg1:GetName()
				local Border = CreateFrame("Frame", FrameName, arg1)
				Border:SetSize(arg2, arg3)
				Border:SetPoint(arg4,arg5,arg6)
				Border:SetBackdrop({
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
				edgeSize = arg7})
				Border:SetBackdropBorderColor(1, 1, 1)
				Border:SetFrameStrata(arg8)
			elseif arg1:GetName() ~= nil and _G["m_border_"..arg1:GetName()] ~= nil then
				--Debug and Spam Stop
				--print("Double border found: "..arg1:GetName())
			end
		end 
	
		function m_fontify(arg1,arg2,arg3)
			-- arg 1 is the stringname, arg3 is the color, arg3 is optional for font-size
			local fontName, fontHeight = arg1:GetFont()
			if arg2 == "color" then
				arg1:SetTextColor(unpack(miirgui.Color))
			elseif arg2 == "highlight" then
				arg1:SetTextColor(unpack(miirgui.Highlight))
			elseif arg2 == "white" then
				arg1:SetTextColor(1,1,1,1)
			elseif arg2 == "green" then
				arg1:SetTextColor(0, 1, 0.5, 1)
			elseif arg2 == "grey" then
				arg1:SetTextColor(0.5, 0.5, 0.5, 1)
			elseif arg2 == "same" then --keep the original
				arg1:SetTextColor(arg1:GetTextColor())
			else 
			-- misc color, code needs to be {r,g,b,a} in call -- example m_fontiy(frame,{r,g,b,a})
				arg1:SetTextColor(unpack(arg2))
			end

			if arg3 then -- custom height
				--print(arg3)
				arg1:SetFont(fontName, arg3, "OUTLINE")
			else
				arg1:SetFont(fontName, fontHeight, "OUTLINE")
			end		
			arg1:SetShadowColor(0,0,0,0)
		end