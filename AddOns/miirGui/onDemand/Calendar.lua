local function skin_Blizzard_Calendar()

	local function miirgui_CalendarFrame_SetToday(dayButton)
		CalendarTodayFrame:ClearAllPoints()
		CalendarTodayFrame:SetPoint("CENTER", dayButton, "CENTER",0,-0.5)
	end

	hooksecurefunc("CalendarFrame_SetToday",miirgui_CalendarFrame_SetToday)

	CalendarMonthBackground:Hide()

	for i = 1,42 do
		local point, relativeTo, relativePoint, xOfs, yOfs = _G["CalendarDayButton"..i.."OverlayFrameTexture"]:GetPoint()
		_G["CalendarDayButton"..i.."OverlayFrameTexture"]:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs-2)
	end

end


local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_Calendar" then
		skin_Blizzard_Calendar()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_Calendar") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_Calendar()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)