local function miirgui_options()

	-- Creation of the options menu

	miirgui.panel = CreateFrame( "Frame", "miirguiPanel", UIParent)
	miirgui.panel.name = "MiirGui Texture Pack";
	InterfaceOptions_AddCategory(miirgui.panel);
	miirgui.childpanel = CreateFrame( "Frame", "miirguiChild", miirgui.panel)
	miirgui.childpanel:SetPoint("TOPLEFT",miirguiPanel,0,0)
	miirgui.childpanel:SetPoint("BOTTOMRIGHT",miirguiPanel,0,0)
	InterfaceOptions_AddCategory(miirgui.childpanel)

	-- TextFactory

	local function TextFactory(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8)
		arg1:SetFont("Fonts\\FRIZQT__.TTF", arg2,"OUTLINE")
		arg1:SetText(arg3)
		arg1:SetPoint(arg4,arg5,arg6,arg7)
		if arg8 == "color" then
			arg1:SetTextColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
		elseif arg8 == "white" then
			arg1:SetTextColor(1,1,1,1)
		elseif arg8 == "highlight" then
			arg1:SetTextColor(miirguiDB.color.hr,miirguiDB.color.hg,miirguiDB.color.hb,1)
		end
	end

	-- ButtonFactory

	local function ButtonFactory(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8)
		local arg1 = CreateFrame("Button",arg1,miirgui.childpanel,"UIPanelButtonTemplate")
		arg1:SetPoint(arg2,arg3,arg4,arg5)
		arg1:SetSize(arg6,arg7)
		arg1:SetText(arg8)
	end

	--- InputBox Factory

	local function InputFactory(arg1,arg2,arg3,arg4,arg5,arg6,arg7)
		local arg1 = CreateFrame("EditBox", arg1, arg2, "InputBoxTemplate");
		arg1:SetPoint(arg3,arg2,arg4,arg5);
		arg1:SetSize(arg6,arg7)
	end

	local version = GetAddOnMetadata("miirGui", "Version")

	local versiontext = miirgui.childpanel:CreateFontString()
	TextFactory(versiontext,14,"MiirGui Texture Pack Settings (Version "..version..")","TOPLEFT",miirguiChild,6,-10,"color")

	local colorsettings = miirgui.childpanel:CreateFontString()
	TextFactory(colorsettings,12,"+ Color Settings + (reload required)","TOPLEFT",miirguiChild,6,-26,"white")

	-- Blue & Grey Buttons

	ButtonFactory("blue","TOPLEFT",miirguiChild,6,-42,100,22,"Blue")
	ButtonFactory("grey","CENTER",blue,0,-20,100,22,"Grey")


	if miirguiDB.blue == true then
		blue:Disable()
	elseif miirguiDB.grey == true then
		grey:Disable()
	end

	blue:SetScript("OnClick", function()
		miirguiDB.color.enable = false
		miirguiDB.grey = false
		miirguiDB.blue = true
		blue:Disable()
		grey:Enable()
		misc:Enable()
		miirguiDB.color.r = 0.08
		miirguiDB.color.g = 0.342
		miirguiDB.color.b = 0.52
		miirguiDB.color.hr = 0.086
		miirguiDB.color.hg = 0.459
		miirguiDB.color.hb = 0.710
	end)

	blue:SetScript("OnEnter", function()
		GameTooltip:SetOwner(blue,"ANCHOR_TOP");
		GameTooltip:AddLine("Activate blue color scheme.")
		GameTooltip:Show()
	end)

	blue:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	grey:SetScript("OnClick", function()
		miirguiDB.color.enable = false
		miirguiDB.grey = true
		miirguiDB.blue = false
		blue:Enable()
		grey:Disable()
		misc:Enable()
		miirguiDB.color.r = 0.301
		miirguiDB.color.g = 0.301
		miirguiDB.color.b = 0.301
		miirguiDB.color.hr = 0.695
		miirguiDB.color.hg = 0.695
		miirguiDB.color.hb = 0.695
	end)

	grey:SetScript("OnEnter", function()
		GameTooltip:SetOwner(grey,"ANCHOR_TOP");
		GameTooltip:AddLine("Activate grey colors scheme.")
		GameTooltip:Show()
	end)

	grey:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local misc=CreateFrame("CheckButton", "misc", grey, "UICheckButtonTemplate")
	misc:SetPoint("LEFT", -3, -22)
	misc.text:SetText("Misc Color")
	m_fontify(misc.text,"white")

	-- Misc Main Color Inputs

	InputFactory("miscR",grey,"LEFT",8,-60,50,20)
	miscR:SetAutoFocus(false)
	miscR:SetNumber(miirguiDB.color.r)
	miscR:SetCursorPosition(0)

	InputFactory("miscG",miscR,"BOTTOM",0,-20,50,20)
	miscG:SetAutoFocus(false)
	miscG:SetNumber(miirguiDB.color.g)
	miscG:SetCursorPosition(0)

	InputFactory("miscB",miscG,"BOTTOM",0,-20,50,20)
	miscB:SetAutoFocus(false)
	miscB:SetNumber(miirguiDB.color.b)
	miscB:SetCursorPosition(0)

	miscR:SetScript("OnEditFocusLost",function()
		miscR:ClearFocus()
		miirguiDB.color.r = miscR:GetNumber()
	end)
	miscR:SetScript("OnEnterPressed",function()
		miscR:ClearFocus()
		miirguiDB.color.r = miscR:GetNumber()
	end)

	miscG:SetScript("OnEditFocusLost",function()
		miscG:ClearFocus()
		miirguiDB.color.g = miscG:GetNumber()
	end)
	miscG:SetScript("OnEnterPressed",function()
		miscG:ClearFocus()
		miirguiDB.color.g = miscG:GetNumber()
	end)

	miscB:SetScript("OnEditFocusLost",function()
		miscB:ClearFocus()
		miirguiDB.color.b = miscB:GetNumber()
	end)
	miscB:SetScript("OnEnterPressed",function()
		miscB:ClearFocus()
		miirguiDB.color.b = miscB:GetNumber()
	end)

	--Misc Highlight Inputs

	InputFactory("highR",grey,"LEFT",120,-60,50,20)
	highR:SetAutoFocus(false)
	highR:SetNumber(miirguiDB.color.hr)
	highR:SetCursorPosition(0)

	InputFactory("highG",highR,"BOTTOM",0,-20,50,20)
	highG:SetAutoFocus(false)
	highG:SetNumber(miirguiDB.color.hg)
	highG:SetCursorPosition(0)

	InputFactory("highB",highG,"BOTTOM",0,-20,50,20)
	highB:SetAutoFocus(false)
	highB:SetNumber(miirguiDB.color.hb)
	highB:SetCursorPosition(0)

	highR:SetScript("OnEditFocusLost",function()
		highR:ClearFocus()
		miirguiDB.color.hr = highR:GetNumber()
	end)
	highR:SetScript("OnEnterPressed",function()
		miscR:ClearFocus()
		miirguiDB.color.hr = highR:GetNumber()
	end)

	highG:SetScript("OnEditFocusLost",function()
		highG:ClearFocus()
		miirguiDB.color.hg = highG:GetNumber()
	end)
	highG:SetScript("OnEnterPressed",function()
		highG:ClearFocus()
		miirguiDB.color.hg = highG:GetNumber()
	end)

	highB:SetScript("OnEditFocusLost",function()
		highB:ClearFocus()
		miirguiDB.color.hb = highB:GetNumber()
	end)
	highB:SetScript("OnEnterPressed",function()
		highB:ClearFocus()
		miirguiDB.color.hb = highB:GetNumber()
	end)

	local maincolorstring = miirgui.childpanel:CreateFontString()
	TextFactory(maincolorstring,12,"Main Color","TOPLEFT",miscR,-5,14,"color")

	local highcolorstring = miirgui.childpanel:CreateFontString()
	TextFactory(highcolorstring,12,"Highlight Color","TOPLEFT",highR,-5,14,"highlight")

	local redr = miirgui.childpanel:CreateFontString()
	TextFactory(redr,12,"R","CENTER",miscR,55,0,"white")
	redr:SetTextColor(1,0,0,1)

	local greeng = miirgui.childpanel:CreateFontString()
	TextFactory(greeng,12,"G","CENTER",miscG,55,0,"white")
	greeng:SetTextColor(0,1,0,1)

	local blueb = miirgui.childpanel:CreateFontString()
	TextFactory(blueb,12,"B","CENTER",miscB,55,0,"white")
	blueb:SetTextColor(0,0,1,1)

	if miirguiDB.color.enable == true then
		misc:SetChecked(true)
		miscR:SetAlpha(1)
		highR:SetAlpha(1)
		redr:SetAlpha(1)
		blueb:SetAlpha(1)
		greeng:SetAlpha(1)
		maincolorstring:SetAlpha(1)
		highcolorstring:SetAlpha(1)
	else
		misc:SetChecked(false)
		miscR:Disable()
		miscG:Disable()
		miscB:Disable()
		highR:Disable()
		highG:Disable()
		highB:Disable()
		miscR:SetAlpha(0.2)
		highR:SetAlpha(0.2)
		redr:SetAlpha(0.2)
		blueb:SetAlpha(0.2)
		greeng:SetAlpha(0.2)
		maincolorstring:SetAlpha(0.2)
		highcolorstring:SetAlpha(0.2)
	end

	if misc:GetChecked() then
		blue:Disable()
		grey:Disable()
	end

	misc:SetScript("OnClick", function()
		if misc:GetChecked() then
			miirguiDB.color.enable = true
			miirguiDB.grey = false
			miirguiDB.blue = false
			blue:Disable()
			grey:Disable()
			miscR:Enable()
			miscG:Enable()
			miscB:Enable()
			highR:Enable()
			highG:Enable()
			highB:Enable()
			miscR:SetAlpha(1)
			highR:SetAlpha(1)
			redr:SetAlpha(1)
			blueb:SetAlpha(1)
			greeng:SetAlpha(1)
			maincolorstring:SetAlpha(1)
			highcolorstring:SetAlpha(1)
		else
			miirguiDB.color.enable = false
			miirguiDB.grey = false
			miirguiDB.blue = true
			blue:Disable()
			grey:Enable()
			miscR:Disable()
			miscG:Disable()
			miscB:Disable()
			highR:Disable()
			highG:Disable()
			highB:Disable()
			miscR:SetAlpha(0.2)
			highR:SetAlpha(0.2)
			redr:SetAlpha(0.2)
			blueb:SetAlpha(0.2)
			greeng:SetAlpha(0.2)
			maincolorstring:SetAlpha(0.2)
			highcolorstring:SetAlpha(0.2)
		end
	end)

	-- Misc Settings

	local miscsettings = miirgui.childpanel:CreateFontString()
	TextFactory(miscsettings,12,"+ Misc Settings + (reload required)","LEFT",misc,4,-100,"white")

	--cpu saver

	local outline = CreateFrame("CheckButton", "outline", misc, "UICheckButtonTemplate")
	outline:SetPoint("LEFT",0, -120)
	outline.text:SetText("Outline fonts")
	m_fontify(outline.text,"white")
	if miirguiDB.outline== true then
		outline:SetChecked(true)
	end
	outline:SetScript("OnClick", function()
		if outline:GetChecked() then
			miirguiDB.outline = true
		else
			miirguiDB.outline = false
		end
	end)

	--loot roll skinning

	local bonus = CreateFrame("CheckButton", "bonus", outline, "UICheckButtonTemplate")
	bonus:SetPoint("CENTER",0, -20)
	bonus.text:SetText("Skin lootroll frames (pass by right-clicking the rollbar)")
	m_fontify(bonus.text,"white")
	if miirguiDB.rolls == true then
		bonus:SetChecked(true)
	end
	bonus:SetScript("OnClick", function()
		if bonus:GetChecked() then
			miirguiDB.rolls = true
		else
			miirguiDB.rolls = false
		end
	end)

	--alertframe dummy & position

	if miirguiDB.alerpos.enable == true then
		AlertFrame:ClearAllPoints()
		AlertFrame:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB.alerpos.y)
	end


	local dummyalert = CreateFrame("FRAME","dummyalert",UIParent)
	dummyalert:SetSize(512,64)
	dummyalert:SetFrameStrata("DIALOG")
	dummyalert:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB.alerpos.y+51)
	dummyalert:SetBackdrop({
	bgFile = "Interface\\Achievementframe\\miirgui_ach.tga",
	})
	dummyalert:Hide()

	local alertpos = CreateFrame("CheckButton", "alertpos",bonus,"UICheckButtonTemplate")
	alertpos:SetPoint("CENTER",0,-20)
	alertpos.text:SetText("Move alertframes")
	m_fontify(alertpos.text,"white")
	if miirguiDB.alerpos.enable == true then
		alertpos:SetChecked(true)
	end
	alertpos:SetScript("OnClick", function()
		if alertpos:GetChecked() then
			miirguiDB.alerpos.enable = true
			alert_x:Show()
		else
			alert_x:Hide()
			miirguiDB.alerpos.enable =false
		end
	end)

	local alert_x = CreateFrame("EditBox", "alert_x", alertpos, "InputBoxTemplate");
	alert_x:SetAutoFocus(false)
	alert_x:SetPoint("LEFT", 144,0);
	alert_x:SetSize(40,20)
	alert_x:SetNumber(miirguiDB.alerpos.x)
	alert_x:SetCursorPosition(0)
	alert_x:SetScript("OnEditFocusLost",function()
		alert_x:ClearFocus()
		miirguiDB.alerpos.x = alert_x:GetNumber()
		dummyalert:ClearAllPoints()
		dummyalert:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB.alerpos.y+51)

	end)
	alert_x:SetScript("OnEnterPressed",function()
		alert_x:ClearFocus()
		miirguiDB.alerpos.x = alert_x:GetNumber()
		dummyalert:ClearAllPoints()
		dummyalert:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB["alerpos"].y+51)
	end)
	if miirguiDB.alerpos.enable == true then
		alert_x:Show()
	else
		alert_x:Hide()
	end

	local alert_y = CreateFrame("EditBox", "alert_y", alert_x, "InputBoxTemplate");
	alert_y:SetAutoFocus(false)
	alert_y:SetPoint("LEFT", 46,0);
	alert_y:SetSize(40,20)
	alert_y:SetNumber(miirguiDB.alerpos.y)
	alert_y:SetCursorPosition(0)
	alert_y:SetScript("OnEditFocusLost",function()
		alert_y:ClearFocus()
		miirguiDB.alerpos.y = alert_y:GetNumber()
		dummyalert:ClearAllPoints()
		dummyalert:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB.alerpos.y+51)

	end)
	alert_y:SetScript("OnEnterPressed",function()
		alert_y:ClearFocus()
		miirguiDB.alerpos.y = alert_y:GetNumber()
		dummyalert:ClearAllPoints()
		dummyalert:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB.alerpos.y+51)

	end)

	local dummyalerpos = CreateFrame("Button","dummyalerpos",alert_y,"UIPanelButtonTemplate")
	dummyalerpos:SetPoint("LEFT",46,0)
	dummyalerpos:SetSize(100,22)
	dummyalerpos:SetText("Show Dummy")
	dummyalerpos:SetScript("OnClick", function()
		if dummyalert:IsShown() then
			dummyalert:Hide()
		else
			dummyalert:Show()
		end
	end)

	-- skin minimap

	local skinminimap = CreateFrame("CheckButton", "skinminimap",alertpos,"UICheckButtonTemplate")
	skinminimap:SetPoint("CENTER",0,-20)
	skinminimap.text:SetText("Skin minimap (relogg required)")
	m_fontify(skinminimap.text,"white")
	if miirguiDB.skinminimap == true then
		skinminimap:SetChecked(true)
	end
	skinminimap:SetScript("OnClick", function()
		if skinminimap:GetChecked() then
			miirguiDB.skinminimap = true
		else
			miirguiDB.skinminimap = false
		end
	end)

	-- command bar

	local cbar = CreateFrame("CheckButton", "cbar", skinminimap, "UICheckButtonTemplate")
	cbar:SetPoint("CENTER",0, -20)
	cbar.text:SetText("Hide orderhall command bar")
	m_fontify(cbar.text,"white")
	if miirguiDB.cbar == true then
		cbar:SetChecked(true)
	end
	cbar:SetScript("OnClick", function()
		if cbar:GetChecked() then
			miirguiDB.cbar = true
			if OrderHallCommandBar then
				OrderHallCommandBar:SetAlpha(0)
			end
		else
			if OrderHallCommandBar then
				OrderHallCommandBar:SetAlpha(1)
			end
			miirguiDB.cbar = false
		end
	end)
	

	--reload button

	local reload = CreateFrame("Button","reload",cbar,"UIPanelButtonTemplate")
	reload:SetPoint("CENTER",37,-20)
	reload:SetSize(100,22)
	reload:SetText("Reload")
	reload:SetScript("OnClick", function()
		ReloadUI()
	end)

	-- F.A.Q
	--[[
	local faq = miirgui.childpanel:CreateFontString()
	TextFactory(faq,14,"Frequently asked questions","LEFT",reload,4,-20,"color")

	local faq2 = miirgui.childpanel:CreateFontString()
	TextFactory(faq2,12,"+ What is this CPU Saver ?","LEFT",reload,4,-40,"white")

	local faq3 = miirgui.childpanel:CreateFontString()
	TextFactory(faq3,12,"CPU Saver disables all font-outlines. This should allow a better performance on old machines.","LEFT",reload,4,-60,"white")
	]]
	-- SLASH  Command

	SLASH_MIIRGUI1 = "/miirgui"

	SlashCmdList["MIIRGUI"] = function()
		InterfaceOptionsFrame_OpenToCategory(miirguiPanel)
		InterfaceOptionsFrame_OpenToCategory(miirguiPanel)
	end

end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", miirgui_options)