local ADDON_NAME, Engine = ...
local L = Engine.Locales
local UI = Engine.UI

if Engine.Enabled then return end -- UI already found

if not Tukui then return end -- no Tukui detected

Engine.Enabled = true -- Tukui found

------------
--- Tukui
------------
local T, C, _ = unpack(Tukui)


UI.BorderColor = C["Medias"]["BorderColor"]
UI.NormTex = C["Medias"]["Normal"]
UI.MyClass = T.MyClass
UI.MyName = T.MyName
UI.Colors = T["Colors"]

local petBattleHider = CreateFrame("Frame", "ClassMonitorPetBattleHider", UIParent, "SecureHandlerStateTemplate")
petBattleHider:SetAllPoints(UIParent)
RegisterStateDriver(petBattleHider, "visibility", "[petbattle] hide; show")

UI.PetBattleHider = petBattleHider

UI.SetFontString = function(parent, fontHeight, fontStyle)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(C.Medias.Font, fontHeight, fontStyle)
	fs:SetJustifyH("LEFT")
	fs:SetShadowColor(0, 0, 0)
	fs:SetShadowOffset(1.25, -1.25)
	return fs
end

------ Reset popup
local function Reset()
	-- delete data per char
	for k, v in pairs(ClassMonitorDataPerChar) do
		ClassMonitorDataPerChar[k] = nil
	end
	-- delete data per realm
	for k, v in pairs(ClassMonitorData) do
		ClassMonitorData[k] = nil
	end
	-- reload
	ReloadUI()
end

T["Popups"].Popup["CLASSMONITOR_RESET"] = {
	Question = L.classmonitor_command_reset,
	Answer1 = ACCEPT,
	Answer2 = CANCEL,
	Function1 = function(self)
		Reset()
	end,
}

UI.StaticPopup_Reset_show = function() T["Popups"].ShowPopup("CLASSMONITOR_RESET") end
------

UI.ClassColor = function(className)
	return className and UI.Colors.class[className] or UI.Colors.class[UI.MyClass]
end

UI.PowerColor = function(resourceName)
--print(tostring(resourceName).."  "..tostring(UI.Colors.power[resourceName]))
	return UI.Colors.power[resourceName]
end

UI.HealthColor = function(unit)
	local color = {1, 1, 1, 1}
	-- if UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
		-- color = T.UnitColor.tapped
	if not UnitIsConnected(unit) then
		color = UI.Colors.disconnected
	elseif UnitIsPlayer(unit) or (UnitPlayerControlled(unit) and not UnitIsPlayer(unit)) then
		local class = select(2, UnitClass(unit))
		color = UI.Colors.class[class]
	elseif UnitReaction(unit, "player") then
		color = UI.Colors.reaction[UnitReaction(unit, "player")]
	end
	return color
end

UI.CreateMover = function(name, width, height, anchor, text)
	local mover = CreateFrame("Frame", name, UIParent)
	mover:SetTemplate()
	mover:SetBackdropBorderColor(1, 0, 0, 1)
	mover:SetFrameStrata("HIGH")
	mover:SetMovable(true)
	mover:Size(width, height)
	mover:Point(unpack(anchor))

	mover.text = T.FontString(mover, "clm", C.Medias.Font, 12)
	mover.text:SetPoint("CENTER")
	mover.text:SetText(text)
	mover.text.Show = function() mover:Show() end
	mover.text.Hide = function() mover:Hide() end
	mover:Hide()

	--tinsert(T["Movers"], mover)
	--T:Movers(mover)
	T["Movers"]:RegisterFrame(mover)
	
	return mover
end

UI.Move = function()
	T["Movers"]:StartOrStopMoving()
	return true
end